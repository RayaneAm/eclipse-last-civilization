--!strict
-- Persistent gameplay-first HUD: one combined player/objective card and a
-- consistent right-side action stack for inventory and economy screens.
-- First client consumer of CurrencyChanged/ProgressionChanged (zero listeners
-- existed before this) and a second, additive consumer of QuestUpdated
-- alongside QuestGiverController's existing billboard label.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local Trove = require(ReplicatedStorage.Shared.Modules.Trove)
local Signal = require(ReplicatedStorage.Shared.Modules.Signal)
local QuestConfig = require(ReplicatedStorage.Shared.Config.QuestConfig)
local XPConfig = require(ReplicatedStorage.Shared.Config.XPConfig)
local PlayerSessionTypes = require(ReplicatedStorage.Shared.Config.PlayerSessionTypes)

local Theme = require(script.Parent.Parent.UI.Theme)
local Motion = require(script.Parent.Parent.UI.Motion)
local GlassPanel = require(script.Parent.Parent.UI.Components.GlassPanel)
local HudIconButton = require(script.Parent.Parent.UI.Components.HudIconButton)
local ProgressBar = require(script.Parent.Parent.UI.Components.ProgressBar)

local NotificationController = require(script.Parent.NotificationController)

local MOBILE_VIEWPORT_WIDTH_THRESHOLD = 700
local INFO_PANEL_WIDTH = 260
local MOBILE_INFO_PANEL_WIDTH = 220
local MENU_CARD_MIN_READABLE_WIDTH = 156
local MENU_WINDOW_WIDTH = 1030
local MENU_WINDOW_SCALE_MIN = 0.34
local MENU_WINDOW_SCALE_MAX = 0.94
local MENU_WINDOW_SCALE_VIEWPORT_WIDTH = 1120
local MENU_WINDOW_SCALE_VIEWPORT_HEIGHT = 690
local MENU_WINDOW_VERTICAL_RESERVE = 48
local MENU_CARD_WINDOW_GAP = 12
local ACTION_BUTTON_WIDTH = 152
local ACTION_BUTTON_HEIGHT = 52
local SUBACTION_BUTTON_WIDTH = 136
local SUBACTION_BUTTON_HEIGHT = 44
local MOBILE_ACTION_BUTTON_SIZE = 52

local HUDController = {}

local function formatScrap(value: number): string
	if value >= 1_000_000 then
		return string.format("%.1fM", value / 1_000_000)
	elseif value >= 1_000 then
		return string.format("%.1fK", value / 1_000)
	end
	return tostring(value)
end

-- The round HUD buttons are the only navigation for the unified menu suite.
-- They intentionally bypass the old panel signals so duplicate UIs cannot open.
local function openUnifiedMenu(screenName: string)
	local eclipseUI = (_G :: any).EclipseUI
	if eclipseUI and type(eclipseUI.Open) == "function" then
		eclipseUI.Open(screenName)
	else
		warn(`HUDController: unified menu is not ready for {screenName}`)
	end
end

-- Compatibility signals retained for non-HUD callers of the legacy panels.
-- The round buttons below open the unified menu directly.
HUDController.MenuOpenRequested = Signal.new()

HUDController.ShopOpenRequested = Signal.new()
HUDController.StarterPackOpenRequested = Signal.new()

HUDController.MarketplaceOpenRequested = Signal.new()
HUDController.SupplyShopOpenRequested = Signal.new()

function HUDController:Init()
	self._trove = Trove.new()

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "EclipseHUD"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = false -- top-anchored elements clear Roblox's own topbar inset automatically
	screenGui.DisplayOrder = 90 -- stays navigable above the unified menu at DisplayOrder 80
	screenGui.Parent = playerGui
	self._trove:Add(screenGui)

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.Parent = screenGui

	-- Scrap is global player state, not panel-specific information. Keep one
	-- persistent readout in the HUD instead of repeating it in every menu.
	local scrapPanel = GlassPanel.new({
		Name = "PersistentScrap",
		Size = UDim2.fromOffset(176, 44),
		Position = UDim2.new(1, -Theme.Spacing.S, 0, Theme.Spacing.S),
		AnchorPoint = Vector2.new(1, 0),
		AccentColor = Theme.Colors.Gold,
		CornerRadius = Theme.Corner.Pill,
		Gradient = false,
		DropShadow = false,
		Parent = root,
	})

	local scrapCoin = Instance.new("TextLabel")
	scrapCoin.Name = "Coin"
	scrapCoin.Size = UDim2.fromOffset(32, 32)
	scrapCoin.Position = UDim2.fromOffset(6, 6)
	scrapCoin.BackgroundColor3 = Theme.Colors.Gold
	scrapCoin.BackgroundTransparency = 0.08
	scrapCoin.BorderSizePixel = 0
	scrapCoin.Font = Enum.Font.GothamBlack
	scrapCoin.TextSize = 15
	scrapCoin.TextColor3 = Theme.Colors.PanelBackground
	scrapCoin.Text = "S"
	scrapCoin.Parent = scrapPanel

	local scrapCoinCorner = Instance.new("UICorner")
	scrapCoinCorner.CornerRadius = Theme.Corner.Pill
	scrapCoinCorner.Parent = scrapCoin

	local persistentCurrencyLabel = Instance.new("TextLabel")
	persistentCurrencyLabel.Name = "Amount"
	persistentCurrencyLabel.Size = UDim2.new(1, -50, 0, 24)
	persistentCurrencyLabel.Position = UDim2.fromOffset(46, 2)
	persistentCurrencyLabel.BackgroundTransparency = 1
	persistentCurrencyLabel.Font = Theme.Font.Stat.Font
	persistentCurrencyLabel.TextSize = Theme.Font.Stat.Size
	persistentCurrencyLabel.TextColor3 = Theme.Colors.TextPrimary
	persistentCurrencyLabel.TextXAlignment = Enum.TextXAlignment.Left
	persistentCurrencyLabel.Text = "0"
	persistentCurrencyLabel.Parent = scrapPanel

	local scrapCaption = Instance.new("TextLabel")
	scrapCaption.Name = "Caption"
	scrapCaption.Size = UDim2.new(1, -50, 0, 14)
	scrapCaption.Position = UDim2.fromOffset(46, 25)
	scrapCaption.BackgroundTransparency = 1
	scrapCaption.Font = Theme.Font.Caption.Font
	scrapCaption.TextSize = Theme.Font.Caption.Size
	scrapCaption.TextColor3 = Theme.Colors.TextMuted
	scrapCaption.TextXAlignment = Enum.TextXAlignment.Left
	scrapCaption.Text = "SCRAP"
	scrapCaption.Parent = scrapPanel
	self._currencyLabel = persistentCurrencyLabel

	local gameplayInfoGroup = Instance.new("CanvasGroup")
	gameplayInfoGroup.Name = "GameplayInfo"
	gameplayInfoGroup.Size = UDim2.fromScale(1, 1)
	gameplayInfoGroup.BackgroundTransparency = 1
	gameplayInfoGroup.GroupTransparency = 0
	gameplayInfoGroup.Parent = root

	-- One compact information hierarchy: player progress first, then the
	-- current objective. The objective lives inside this same surface so it
	-- reads as gameplay guidance instead of a disconnected secondary widget.
	local statusPanel = GlassPanel.new({
		Name = "PlayerAndObjective",
		Size = UDim2.new(0, INFO_PANEL_WIDTH, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.fromOffset(Theme.Spacing.L, Theme.Spacing.L),
		CornerRadius = Theme.Corner.Large,
		Gradient = false,
		Parent = gameplayInfoGroup,
	})
	local statusLayout = Instance.new("UIListLayout")
	statusLayout.FillDirection = Enum.FillDirection.Vertical
	statusLayout.SortOrder = Enum.SortOrder.LayoutOrder
	statusLayout.Padding = UDim.new(0, Theme.Spacing.XS)
	statusLayout.Parent = statusPanel
	local statusPadding = Instance.new("UIPadding")
	statusPadding.PaddingLeft = UDim.new(0, Theme.Spacing.M)
	statusPadding.PaddingRight = UDim.new(0, Theme.Spacing.M)
	statusPadding.PaddingTop = UDim.new(0, Theme.Spacing.S)
	statusPadding.PaddingBottom = UDim.new(0, Theme.Spacing.S)
	statusPadding.Parent = statusPanel

	local statusRow1 = Instance.new("Frame")
	statusRow1.Name = "Row1"
	statusRow1.Size = UDim2.new(1, 0, 0, 16)
	statusRow1.LayoutOrder = 1
	statusRow1.BackgroundTransparency = 1
	statusRow1.Parent = statusPanel

	local statusRow1Layout = Instance.new("UIListLayout")
	statusRow1Layout.FillDirection = Enum.FillDirection.Horizontal
	statusRow1Layout.SortOrder = Enum.SortOrder.LayoutOrder
	statusRow1Layout.HorizontalFlex = Enum.UIFlexAlignment.SpaceBetween
	statusRow1Layout.VerticalAlignment = Enum.VerticalAlignment.Center
	statusRow1Layout.Parent = statusRow1

	local levelLabel = Instance.new("TextLabel")
	levelLabel.Name = "Level"
	levelLabel.AutomaticSize = Enum.AutomaticSize.X
	levelLabel.Size = UDim2.new(0, 0, 1, 0)
	levelLabel.BackgroundTransparency = 1
	levelLabel.Font = Theme.Font.Label.Font
	levelLabel.TextSize = Theme.Font.Label.Size
	levelLabel.TextColor3 = Theme.Colors.BrandLight
	levelLabel.TextXAlignment = Enum.TextXAlignment.Left
	levelLabel.LayoutOrder = 1
	levelLabel.Text = "◆  LEVEL 0"
	levelLabel.Parent = statusRow1
	self._levelLabel = levelLabel

	local tierLabel = Instance.new("TextLabel")
	tierLabel.Name = "Tier"
	tierLabel.AutomaticSize = Enum.AutomaticSize.X
	tierLabel.Size = UDim2.new(0, 0, 1, 0)
	tierLabel.BackgroundTransparency = 1
	tierLabel.Font = Theme.Font.Label.Font
	tierLabel.TextSize = Theme.Font.Label.Size
	tierLabel.TextColor3 = Theme.Colors.BrandLight
	tierLabel.TextXAlignment = Enum.TextXAlignment.Left
	tierLabel.LayoutOrder = 2
	tierLabel.Text = "TIER 0"
	tierLabel.Parent = statusRow1

	self._tierLabel = tierLabel
	self._tierPill = tierLabel

	local statusRow2 = Instance.new("Frame")
	statusRow2.Name = "Row2"
	statusRow2.Size = UDim2.new(1, 0, 0, 20)
	statusRow2.LayoutOrder = 2
	statusRow2.BackgroundTransparency = 1
	statusRow2.Parent = statusPanel

	local statusRow2Layout = Instance.new("UIListLayout")
	statusRow2Layout.FillDirection = Enum.FillDirection.Vertical
	statusRow2Layout.SortOrder = Enum.SortOrder.LayoutOrder
	statusRow2Layout.Padding = UDim.new(0, Theme.Spacing.XXS)
	statusRow2Layout.Parent = statusRow2

	local _xpBar, setXPProgress = ProgressBar.new({
		Name = "XPBar",
		Size = UDim2.new(1, 0, 0, 6),
		AccentColor = Theme.Colors.BrandLight,
		LayoutOrder = 1,
		Parent = statusRow2,
	})
	_xpBar.BackgroundColor3 = Theme.Colors.CardBackground:Lerp(Theme.Colors.TextMuted, 0.22)
	_xpBar.BackgroundTransparency = 0
	local xpTrackStroke = _xpBar:FindFirstChildOfClass("UIStroke")
	if xpTrackStroke then
		xpTrackStroke.Transparency = 0.42
	end
	self._setXPProgress = setXPProgress

	local xpCaption = Instance.new("TextLabel")
	xpCaption.Name = "XPCaption"
	xpCaption.Size = UDim2.new(1, 0, 0, 12)
	xpCaption.LayoutOrder = 2
	xpCaption.BackgroundTransparency = 1
	xpCaption.Font = Theme.Font.Caption.Font
	xpCaption.TextSize = Theme.Font.Caption.Size
	xpCaption.TextColor3 = Theme.Colors.TextSecondary
	xpCaption.TextXAlignment = Enum.TextXAlignment.Left
	xpCaption.Text = "0 / 100 XP"
	xpCaption.Parent = statusRow2
	self._xpCaption = xpCaption

	-- Borderless quest section nested inside the player card.
	local questPanel = GlassPanel.new({
		Name = "QuestTracker",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
		BackgroundTransparency = 1,
		Gradient = false,
		Stroke = false,
		DropShadow = false,
		Parent = statusPanel,
	})
	local questPadding = Instance.new("UIPadding")
	questPadding.PaddingTop = UDim.new(0, 0)
	questPadding.Parent = questPanel

	local questLayout = Instance.new("UIListLayout")
	questLayout.FillDirection = Enum.FillDirection.Vertical
	questLayout.SortOrder = Enum.SortOrder.LayoutOrder
	questLayout.Padding = UDim.new(0, Theme.Spacing.XS)
	questLayout.Parent = questPanel

	local questDivider = Instance.new("Frame")
	questDivider.Name = "Divider"
	questDivider.Size = UDim2.new(1, 0, 0, 1)
	questDivider.LayoutOrder = 1
	questDivider.BackgroundColor3 = Theme.Colors.BrandDim
	questDivider.BackgroundTransparency = 0.45
	questDivider.BorderSizePixel = 0
	questDivider.Parent = questPanel

	local questHeader = Instance.new("Frame")
	questHeader.Name = "Header"
	questHeader.Size = UDim2.new(1, 0, 0, 18)
	questHeader.LayoutOrder = 2
	questHeader.BackgroundTransparency = 1
	questHeader.Parent = questPanel

	local questHeaderLayout = Instance.new("UIListLayout")
	questHeaderLayout.FillDirection = Enum.FillDirection.Horizontal
	questHeaderLayout.SortOrder = Enum.SortOrder.LayoutOrder
	questHeaderLayout.HorizontalFlex = Enum.UIFlexAlignment.SpaceBetween
	questHeaderLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	questHeaderLayout.Parent = questHeader

	local questTitleLabel = Instance.new("TextLabel")
	questTitleLabel.Name = "QuestTitle"
	questTitleLabel.AutomaticSize = Enum.AutomaticSize.X
	questTitleLabel.Size = UDim2.new(0, 0, 1, 0)
	questTitleLabel.BackgroundTransparency = 1
	questTitleLabel.Font = Theme.Font.Label.Font
	questTitleLabel.TextSize = Theme.Font.Label.Size
	questTitleLabel.TextColor3 = Theme.Colors.BrandLight
	questTitleLabel.TextXAlignment = Enum.TextXAlignment.Left
	questTitleLabel.LayoutOrder = 1
	questTitleLabel.Text = "FIRST STEPS"
	questTitleLabel.Parent = questHeader
	self._questTitleLabel = questTitleLabel

	local questProgressLabel = Instance.new("TextLabel")
	questProgressLabel.Name = "Progress"
	questProgressLabel.AutomaticSize = Enum.AutomaticSize.X
	questProgressLabel.Size = UDim2.new(0, 0, 1, 0)
	questProgressLabel.BackgroundTransparency = 1
	questProgressLabel.Font = Theme.Font.Label.Font
	questProgressLabel.TextSize = Theme.Font.Label.Size
	questProgressLabel.TextColor3 = Theme.Colors.TextSecondary
	questProgressLabel.TextXAlignment = Enum.TextXAlignment.Right
	questProgressLabel.LayoutOrder = 2
	questProgressLabel.Text = "0 / 1"
	questProgressLabel.Parent = questHeader
	self._questProgressLabel = questProgressLabel

	local questLabel = Instance.new("TextLabel")
	questLabel.Name = "Objective"
	questLabel.BackgroundTransparency = 1
	questLabel.Size = UDim2.new(1, 0, 0, 0)
	questLabel.AutomaticSize = Enum.AutomaticSize.Y
	questLabel.LayoutOrder = 3
	questLabel.Font = Enum.Font.GothamBold
	questLabel.TextSize = 18
	questLabel.TextXAlignment = Enum.TextXAlignment.Left
	questLabel.TextYAlignment = Enum.TextYAlignment.Top
	questLabel.TextWrapped = true
	questLabel.TextColor3 = Theme.Colors.TextPrimary
	questLabel.Text = "..."
	questLabel.Parent = questPanel
	self._questLabel = questLabel

	self._questPanel = statusPanel

	-- "Where do I go for this step" — always reflects only the current step
	-- (derived fresh from QuestConfig.DescribeCurrentObjectiveHint), so a
	-- completed step's hint is never shown.
	local questHintLabel = Instance.new("TextLabel")
	questHintLabel.Name = "Hint"
	questHintLabel.BackgroundTransparency = 1
	questHintLabel.Size = UDim2.new(1, 0, 0, 0)
	questHintLabel.AutomaticSize = Enum.AutomaticSize.Y
	questHintLabel.LayoutOrder = 4
	questHintLabel.Font = Theme.Font.Caption.Font
	questHintLabel.TextSize = Theme.Font.Caption.Size
	questHintLabel.TextXAlignment = Enum.TextXAlignment.Left
	questHintLabel.TextYAlignment = Enum.TextYAlignment.Top
	questHintLabel.TextWrapped = true
	questHintLabel.TextColor3 = Theme.Colors.TextMuted:Lerp(Theme.Colors.TextPrimary, 0.18)
	questHintLabel.Text = ""
	questHintLabel.Visible = false
	questHintLabel.Parent = questPanel
	self._questHintLabel = questHintLabel

	-- Menu mode keeps only the active quest identity and progress. It is a
	-- separate surface rather than a dimmed copy of the full HUD, so the
	-- Backpack/Shop header never has to compete with XP and currency details.
	local compactQuestGroup = Instance.new("CanvasGroup")
	compactQuestGroup.Name = "CompactQuest"
	compactQuestGroup.Size = UDim2.fromOffset(232, 32)
	compactQuestGroup.Position = UDim2.fromOffset(Theme.Spacing.L, Theme.Spacing.L - 6)
	compactQuestGroup.BackgroundTransparency = 1
	compactQuestGroup.GroupTransparency = 1
	compactQuestGroup.Visible = false
	compactQuestGroup.Parent = root

	local compactQuestPanel = GlassPanel.new({
		Name = "QuestChip",
		Size = UDim2.fromScale(1, 1),
		CornerRadius = Theme.Corner.Pill,
		Gradient = false,
		DropShadow = false,
		Parent = compactQuestGroup,
	})

	local compactPadding = Instance.new("UIPadding")
	compactPadding.PaddingLeft = UDim.new(0, Theme.Spacing.M)
	compactPadding.PaddingRight = UDim.new(0, Theme.Spacing.M)
	compactPadding.Parent = compactQuestPanel

	local compactQuestTitle = Instance.new("TextLabel")
	compactQuestTitle.Name = "QuestTitle"
	compactQuestTitle.Size = UDim2.new(1, -58, 1, 0)
	compactQuestTitle.BackgroundTransparency = 1
	compactQuestTitle.Font = Theme.Font.Label.Font
	compactQuestTitle.TextSize = Theme.Font.Caption.Size
	compactQuestTitle.TextColor3 = Theme.Colors.BrandLight
	compactQuestTitle.TextXAlignment = Enum.TextXAlignment.Left
	compactQuestTitle.TextTruncate = Enum.TextTruncate.AtEnd
	compactQuestTitle.LayoutOrder = 1
	compactQuestTitle.Text = "FIRST STEPS"
	compactQuestTitle.Parent = compactQuestPanel
	self._compactQuestTitle = compactQuestTitle

	local compactQuestProgress = Instance.new("TextLabel")
	compactQuestProgress.Name = "Progress"
	compactQuestProgress.AutomaticSize = Enum.AutomaticSize.X
	compactQuestProgress.Size = UDim2.new(0, 0, 1, 0)
	compactQuestProgress.AnchorPoint = Vector2.new(1, 0)
	compactQuestProgress.Position = UDim2.fromScale(1, 0)
	compactQuestProgress.BackgroundTransparency = 1
	compactQuestProgress.Font = Theme.Font.Label.Font
	compactQuestProgress.TextSize = Theme.Font.Caption.Size
	compactQuestProgress.TextColor3 = Theme.Colors.TextSecondary
	compactQuestProgress.TextXAlignment = Enum.TextXAlignment.Right
	compactQuestProgress.LayoutOrder = 2
	compactQuestProgress.Text = "0 / 1"
	compactQuestProgress.Parent = compactQuestPanel
	self._compactQuestProgress = compactQuestProgress

	-- Only three actions stay visible by default. Economy destinations live
	-- behind the Shops disclosure so gameplay keeps visual priority.
	local actionStack = Instance.new("Frame")
	actionStack.Name = "ActionStack"
	actionStack.Size = UDim2.new(0, ACTION_BUTTON_WIDTH, 0, 0)
	actionStack.AutomaticSize = Enum.AutomaticSize.Y
	actionStack.AnchorPoint = Vector2.new(1, 0.5)
	actionStack.Position = UDim2.new(1, -Theme.Spacing.L, 0.5, 0)
	actionStack.BackgroundTransparency = 1
	actionStack.SelectionGroup = true
	actionStack.Parent = root

	local actionLayout = Instance.new("UIListLayout")
	actionLayout.FillDirection = Enum.FillDirection.Vertical
	actionLayout.SortOrder = Enum.SortOrder.LayoutOrder
	actionLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	actionLayout.Padding = UDim.new(0, 9)
	actionLayout.Parent = actionStack

	local backpackContainer, menuButton = HudIconButton.new({
		Name = "MenuButton",
		Icon = "🎒",
		Label = "Backpack",
		AccentColor = Theme.Colors.Brand,
		Size = UDim2.fromOffset(ACTION_BUTTON_WIDTH, ACTION_BUTTON_HEIGHT),
		LayoutOrder = 1,
		OnActivated = function()
			openUnifiedMenu("Inventory")
		end,
		Parent = actionStack,
	})
	self._menuButton = menuButton

	local shopsMenu = Instance.new("CanvasGroup")
	shopsMenu.Name = "ShopsMenu"
	shopsMenu.Size = UDim2.new(0, ACTION_BUTTON_WIDTH, 0, 0)
	shopsMenu.LayoutOrder = 3
	shopsMenu.BackgroundTransparency = 1
	shopsMenu.GroupTransparency = 0
	shopsMenu.Visible = false
	shopsMenu.Parent = actionStack

	local shopsMenuLayout = Instance.new("UIListLayout")
	shopsMenuLayout.FillDirection = Enum.FillDirection.Vertical
	shopsMenuLayout.SortOrder = Enum.SortOrder.LayoutOrder
	shopsMenuLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	shopsMenuLayout.Padding = UDim.new(0, Theme.Spacing.S)
	shopsMenuLayout.Parent = shopsMenu

	type DisclosureEntry = {
		Container: Frame,
		Group: CanvasGroup,
		Scale: UIScale,
	}

	local disclosureEntries: { DisclosureEntry } = {}
	local function registerDisclosureEntry(container: Frame)
		local group = container:FindFirstChild("VisualGroup")
		if not group or not group:IsA("CanvasGroup") then
			return
		end

		local scale = Instance.new("UIScale")
		scale.Name = "DisclosureScale"
		scale.Parent = group
		table.insert(disclosureEntries, {
			Container = container,
			Group = group,
			Scale = scale,
		})
	end

	local shopsOpen = false
	local activePanel: string? = nil
	local shopsAnimationToken = 0
	local shopsButton: TextButton? = nil
	local function isShopPanel(panelName: string?): boolean
		return panelName == "Marketplace" or panelName == "Supply" or panelName == "Shop"
	end
	local function setShopsOpen(open: boolean)
		if not open and isShopPanel(activePanel) then
			open = true
		end
		shopsOpen = open
		shopsAnimationToken += 1
		local token = shopsAnimationToken

		if shopsButton then
			HudIconButton.SetActive(shopsButton, open or isShopPanel(activePanel))
			local label = shopsButton:FindFirstChild("Label")
			if label and label:IsA("TextLabel") then
				label.Text = if open then "Shops  v" else "Shops  >"
			end
		end

		local visibleEntries: { DisclosureEntry } = {}
		for _, entry in disclosureEntries do
			if entry.Container.Visible then
				table.insert(visibleEntries, entry)
			end
		end

		local entryCount = #visibleEntries
		local menuHeight = if entryCount > 0
			then entryCount * SUBACTION_BUTTON_HEIGHT + (entryCount - 1) * Theme.Spacing.S
			else 0

		if open then
			local wasVisible = shopsMenu.Visible
			shopsMenu.Visible = true
			Motion.Tween(
				shopsMenu,
				"DisclosureHeight",
				TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Size = UDim2.fromOffset(ACTION_BUTTON_WIDTH, menuHeight) }
			)

			for index, entry in visibleEntries do
				if not wasVisible then
					entry.Group.GroupTransparency = 1
					entry.Group.Position = UDim2.fromOffset(0, -10)
					entry.Scale.Scale = 0.9
				end

				task.delay((index - 1) * 0.05, function()
					if token ~= shopsAnimationToken or not shopsOpen then
						return
					end
					Motion.Tween(entry.Group, "DisclosureFade", TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { GroupTransparency = 0 })
					Motion.Tween(entry.Group, "DisclosureSlide", TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0, 0) })
					Motion.Tween(entry.Scale, "DisclosureScale", TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 })
				end)
			end
		else
			if not shopsMenu.Visible then
				shopsMenu.Size = UDim2.fromOffset(ACTION_BUTTON_WIDTH, 0)
				return
			end

			Motion.Tween(
				shopsMenu,
				"DisclosureHeight",
				TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Size = UDim2.fromOffset(ACTION_BUTTON_WIDTH, 0) }
			)

			for index = entryCount, 1, -1 do
				local entry = visibleEntries[index]
				local delaySeconds = (entryCount - index) * 0.04
				task.delay(delaySeconds, function()
					if token ~= shopsAnimationToken or shopsOpen then
						return
					end
					Motion.Tween(entry.Group, "DisclosureFade", TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { GroupTransparency = 1 })
					Motion.Tween(entry.Group, "DisclosureSlide", TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.fromOffset(0, -10) })
					Motion.Tween(entry.Scale, "DisclosureScale", TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.9 })
				end)
			end

			local closeDuration = 0.2 + math.max(0, entryCount - 1) * 0.04
			task.delay(closeDuration, function()
				if token == shopsAnimationToken and not shopsOpen then
					shopsMenu.Visible = false
				end
			end)
		end
	end

	local shopsContainer, createdShopsButton = HudIconButton.new({
		Name = "ShopsButton",
		Icon = "🛍",
		Label = "Shops  >",
		AccentColor = Theme.Colors.Teal,
		Size = UDim2.fromOffset(ACTION_BUTTON_WIDTH, ACTION_BUTTON_HEIGHT),
		LayoutOrder = 2,
		OnActivated = function()
			setShopsOpen(not shopsOpen)
		end,
		Parent = actionStack,
	})
	shopsButton = createdShopsButton

	local marketplaceContainer, marketplaceButton = HudIconButton.new({
		Name = "MarketplaceButton",
		Icon = "↔",
		Label = "Marketplace",
		AccentColor = Theme.Colors.Trade,
		Size = UDim2.fromOffset(SUBACTION_BUTTON_WIDTH, SUBACTION_BUTTON_HEIGHT),
		LayoutOrder = 1,
		OnActivated = function()
			openUnifiedMenu("Marketplace")
		end,
		Parent = shopsMenu,
	})
	registerDisclosureEntry(marketplaceContainer)
	self._marketplaceButton = marketplaceButton

	local supplyShopContainer, supplyShopButton = HudIconButton.new({
		Name = "SupplyShopButton",
		Icon = "📦",
		Label = "Supply Shop",
		AccentColor = Theme.Colors.Teal,
		Size = UDim2.fromOffset(SUBACTION_BUTTON_WIDTH, SUBACTION_BUTTON_HEIGHT),
		LayoutOrder = 2,
		OnActivated = function()
			openUnifiedMenu("Supply")
		end,
		Parent = shopsMenu,
	})
	registerDisclosureEntry(supplyShopContainer)
	self._supplyShopButton = supplyShopButton

	local shopContainer, shopButton = HudIconButton.new({
		Name = "ShopButton",
		Icon = "🛒",
		Label = "Shop",
		AccentColor = Theme.Colors.Teal,
		Size = UDim2.fromOffset(SUBACTION_BUTTON_WIDTH, SUBACTION_BUTTON_HEIGHT),
		LayoutOrder = 3,
		OnActivated = function()
			openUnifiedMenu("Shop")
		end,
		Parent = shopsMenu,
	})
	registerDisclosureEntry(shopContainer)
	self._shopButton = shopButton

	-- Hidden until Start() confirms eligibility (< 30 total hours played) —
	-- defaults hidden rather than flashing visible-then-hidden.
	local starterPackContainer, starterPackButton = HudIconButton.new({
		Name = "StarterPackButton",
		Icon = "🎁",
		Label = "Offer",
		AccentColor = Theme.Colors.Gold,
		-- The whole button only ever becomes visible once Start() confirms
		-- eligibility (below), so a static "!" badge here is only ever seen
		-- by an eligible player — no separate dynamic toggle needed.
		Badge = "!",
		Size = UDim2.fromOffset(ACTION_BUTTON_WIDTH, ACTION_BUTTON_HEIGHT),
		LayoutOrder = 4,
		Pulse = true, -- the one "meaningfully special" case Theme.Motion.Pulse's doc comment calls out — a limited-time new-survivor offer
		OnActivated = function()
			openUnifiedMenu("Offer")
		end,
		Parent = actionStack,
	})
	starterPackContainer.Visible = false
	self._starterPackContainer = starterPackContainer
	self._starterPackButton = starterPackButton

	local mobileOfferContainer, mobileOfferButton = HudIconButton.new({
		Name = "MobileOfferButton",
		Icon = "🎁",
		Label = "Offer",
		AccentColor = Theme.Colors.Gold,
		Badge = "!",
		Size = UDim2.fromOffset(SUBACTION_BUTTON_WIDTH, SUBACTION_BUTTON_HEIGHT),
		LayoutOrder = 4,
		OnActivated = function()
			setShopsOpen(false)
			openUnifiedMenu("Offer")
		end,
		Parent = shopsMenu,
	})
	mobileOfferContainer.Visible = false
	registerDisclosureEntry(mobileOfferContainer)

	local starterPackEligible = false
	local isNarrow = false
	local currentEdgeSpacing = Theme.Spacing.L
	local menuModeOpen = false
	local menuModeToken = 0

	-- Match the unified menu's responsive scale closely enough to reserve the
	-- lane to its left. The quest card can stay fully visible when that lane
	-- is readable; narrower viewports fall back to the compact quest chip.
	local function getMenuSafeCardWidth(): number
		local camera = Workspace.CurrentCamera
		if not camera then
			return INFO_PANEL_WIDTH
		end

		local viewport = camera.ViewportSize
		local menuScale = math.clamp(
			math.min(
				viewport.X / MENU_WINDOW_SCALE_VIEWPORT_WIDTH,
				(viewport.Y - MENU_WINDOW_VERTICAL_RESERVE) / MENU_WINDOW_SCALE_VIEWPORT_HEIGHT
			),
			MENU_WINDOW_SCALE_MIN,
			MENU_WINDOW_SCALE_MAX
		)
		local menuLeftEdge = (viewport.X - MENU_WINDOW_WIDTH * menuScale) * 0.5
		return math.floor(menuLeftEdge - currentEdgeSpacing - MENU_CARD_WINDOW_GAP)
	end

	local function useCompactQuestInMenu(): boolean
		return isNarrow or getMenuSafeCardWidth() < MENU_CARD_MIN_READABLE_WIDTH
	end

	local function getStatusPanelWidth(): number
		local normalWidth = if isNarrow then MOBILE_INFO_PANEL_WIDTH else INFO_PANEL_WIDTH
		if menuModeOpen and not useCompactQuestInMenu() then
			return math.min(normalWidth, getMenuSafeCardWidth())
		end
		return normalWidth
	end

	local function updateOfferVisibility()
		starterPackContainer.Visible = starterPackEligible and not isNarrow
		mobileOfferContainer.Visible = starterPackEligible and isNarrow
		if shopsOpen then
			setShopsOpen(true)
		end
	end
	self._setStarterPackEligible = function(eligible: boolean)
		starterPackEligible = eligible
		updateOfferVisibility()
	end

	local function setRootButtonCompact(container: Frame, button: TextButton, compact: boolean)
		local width = if compact then MOBILE_ACTION_BUTTON_SIZE else ACTION_BUTTON_WIDTH
		container.Size = UDim2.fromOffset(width, ACTION_BUTTON_HEIGHT)

		local label = button:FindFirstChild("Label")
		if label and label:IsA("TextLabel") then
			label.Visible = not compact
		end
	end

	local function applyResponsiveLayout(narrow: boolean)
		isNarrow = narrow
		setShopsOpen(false)

		local edgeSpacing = if narrow then Theme.Spacing.M else Theme.Spacing.L
		currentEdgeSpacing = edgeSpacing
		local actionButtonWidth = if narrow then MOBILE_ACTION_BUTTON_SIZE else ACTION_BUTTON_WIDTH

		statusPanel.Size = UDim2.new(0, getStatusPanelWidth(), 0, 0)
		statusPanel.Position = UDim2.fromOffset(edgeSpacing, edgeSpacing)
		scrapPanel.Position = UDim2.new(1, -Theme.Spacing.S, 0, Theme.Spacing.S)
		scrapPanel.Size = UDim2.fromOffset(if narrow then 134 else 176, if narrow then 38 else 44)
		scrapCoin.Size = UDim2.fromOffset(if narrow then 26 else 32, if narrow then 26 else 32)
		persistentCurrencyLabel.Position = UDim2.fromOffset(if narrow then 36 else 46, 2)
		persistentCurrencyLabel.Size = UDim2.new(1, if narrow then -40 else -50, 0, 21)
		scrapCaption.Position = UDim2.fromOffset(if narrow then 36 else 46, if narrow then 21 else 25)
		compactQuestGroup.Size = UDim2.fromOffset(if narrow then 158 else 232, 32)
		compactQuestGroup.Position = UDim2.fromOffset(
			edgeSpacing,
			if menuModeOpen then edgeSpacing else edgeSpacing - 6
		)

		if menuModeOpen then
			local compactMenuMode = useCompactQuestInMenu()
			gameplayInfoGroup.Visible = not compactMenuMode
			gameplayInfoGroup.GroupTransparency = 0
			gameplayInfoGroup.Position = UDim2.fromScale(0, 0)
			compactQuestGroup.Visible = compactMenuMode
			compactQuestGroup.GroupTransparency = if compactMenuMode then 0 else 1
		else
			gameplayInfoGroup.Visible = true
			gameplayInfoGroup.GroupTransparency = 0
			gameplayInfoGroup.Position = UDim2.fromScale(0, 0)
			compactQuestGroup.Visible = false
			compactQuestGroup.GroupTransparency = 1
		end

		actionStack.Size = UDim2.new(0, actionButtonWidth, 0, 0)
		actionStack.Position = UDim2.new(1, -edgeSpacing, 0.5, 0)
		setRootButtonCompact(backpackContainer, menuButton, narrow)
		setRootButtonCompact(shopsContainer, createdShopsButton, narrow)
		setRootButtonCompact(starterPackContainer, starterPackButton, narrow)

		local shopsIconPlate = createdShopsButton:FindFirstChild("IconPlate")
		local shopsIcon = shopsIconPlate and shopsIconPlate:FindFirstChild("Icon")
		if shopsIcon and shopsIcon:IsA("TextLabel") then
			shopsIcon.Text = if narrow then "☰" else "🛍"
		end

		updateOfferVisibility()
	end

	local function setMenuMode(open: boolean)
		if menuModeOpen == open then
			return
		end

		local wasCompactMenu = compactQuestGroup.Visible
		menuModeOpen = open
		menuModeToken += 1
		local token = menuModeToken

		if open then
			if not useCompactQuestInMenu() then
				gameplayInfoGroup.Visible = true
				compactQuestGroup.Visible = false
				compactQuestGroup.GroupTransparency = 1
				local keepFull = TweenInfo.new(0.04, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
				Motion.Tween(gameplayInfoGroup, "MenuModeFade", keepFull, { GroupTransparency = 0 })
				Motion.Tween(gameplayInfoGroup, "MenuModeSlide", keepFull, { Position = UDim2.fromScale(0, 0) })
				Motion.Tween(
					statusPanel,
					"MenuModeWidth",
					TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Size = UDim2.new(0, getStatusPanelWidth(), 0, 0) }
				)
				return
			end

			gameplayInfoGroup.Visible = true
			compactQuestGroup.Visible = false
			compactQuestGroup.GroupTransparency = 1
			compactQuestGroup.Position = UDim2.fromOffset(currentEdgeSpacing, currentEdgeSpacing - 6)

			local fullExit = TweenInfo.new(0.04, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			Motion.Tween(gameplayInfoGroup, "MenuModeFade", fullExit, { GroupTransparency = 1 })
			Motion.Tween(gameplayInfoGroup, "MenuModeSlide", fullExit, { Position = UDim2.fromOffset(0, -8) })

			task.delay(0.04, function()
				if token == menuModeToken and menuModeOpen then
					gameplayInfoGroup.Visible = false
					compactQuestGroup.Visible = true
					compactQuestGroup.GroupTransparency = 1
					local chipEnter = TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
					Motion.Tween(compactQuestGroup, "MenuModeFade", chipEnter, { GroupTransparency = 0 })
					Motion.Tween(
						compactQuestGroup,
						"MenuModeSlide",
						chipEnter,
						{ Position = UDim2.fromOffset(currentEdgeSpacing, currentEdgeSpacing) }
					)
				end
			end)
		elseif wasCompactMenu then
			gameplayInfoGroup.Visible = false
			compactQuestGroup.Visible = true
			local chipExit = TweenInfo.new(0.04, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			Motion.Tween(compactQuestGroup, "MenuModeFade", chipExit, { GroupTransparency = 1 })
			Motion.Tween(
				compactQuestGroup,
				"MenuModeSlide",
				chipExit,
				{ Position = UDim2.fromOffset(currentEdgeSpacing, currentEdgeSpacing - 6) }
			)

			task.delay(0.04, function()
				if token == menuModeToken and not menuModeOpen then
					compactQuestGroup.Visible = false
					gameplayInfoGroup.Visible = true
					gameplayInfoGroup.GroupTransparency = 1
					gameplayInfoGroup.Position = UDim2.fromOffset(0, -8)
					statusPanel.Size = UDim2.new(0, getStatusPanelWidth(), 0, 0)
					local fullEnter = TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
					Motion.Tween(gameplayInfoGroup, "MenuModeFade", fullEnter, { GroupTransparency = 0 })
					Motion.Tween(gameplayInfoGroup, "MenuModeSlide", fullEnter, { Position = UDim2.fromScale(0, 0) })
				end
			end)
		else
			gameplayInfoGroup.Visible = true
			compactQuestGroup.Visible = false
			compactQuestGroup.GroupTransparency = 1
			local restoreFull = TweenInfo.new(0.04, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			Motion.Tween(gameplayInfoGroup, "MenuModeFade", restoreFull, { GroupTransparency = 0 })
			Motion.Tween(gameplayInfoGroup, "MenuModeSlide", restoreFull, { Position = UDim2.fromScale(0, 0) })
			Motion.Tween(
				statusPanel,
				"MenuModeWidth",
				TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Size = UDim2.new(0, getStatusPanelWidth(), 0, 0) }
			)
		end
	end

	local function applyActivePanel(panelName: string?)
		local wasShopPanel = isShopPanel(activePanel)
		activePanel = panelName
		local panelIsOpen = panelName ~= nil
		setMenuMode(panelIsOpen)

		HudIconButton.SetActive(menuButton, panelName == "Inventory")
		HudIconButton.SetActive(marketplaceButton, panelName == "Marketplace")
		HudIconButton.SetActive(supplyShopButton, panelName == "Supply")
		HudIconButton.SetActive(shopButton, panelName == "Shop")
		HudIconButton.SetActive(starterPackButton, panelName == "Offer")
		HudIconButton.SetActive(mobileOfferButton, panelName == "Offer")
		HudIconButton.SetActive(createdShopsButton, shopsOpen or isShopPanel(panelName))

		if isShopPanel(panelName) then
			setShopsOpen(true)
		elseif panelName ~= nil or wasShopPanel then
			setShopsOpen(false)
		end

		if panelName == nil and UserInputService.GamepadEnabled then
			task.defer(function()
				GuiService.SelectedObject = if wasShopPanel then createdShopsButton else menuButton
			end)
		end
	end

	-- Mobile swaps the persistent cards for two icon-only controls; the Shops
	-- control expands the labelled destinations only when requested.
	local camera = Workspace.CurrentCamera
	local function applyViewportScale()
		if not camera then
			return
		end
		applyResponsiveLayout(camera.ViewportSize.X < MOBILE_VIEWPORT_WIDTH_THRESHOLD)
	end
	applyViewportScale()
	if camera then
		self._trove:Add(camera:GetPropertyChangedSignal("ViewportSize"):Connect(applyViewportScale))
	end

	self._trove:Add(UserInputService.InputBegan:Connect(function(input, gameProcessed)
		local isBackInput = input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB
		if isBackInput and shopsOpen and activePanel == nil then
			setShopsOpen(false)
			return
		end
		if gameProcessed or UserInputService:GetFocusedTextBox() then
			return
		end

		if input.KeyCode == Enum.KeyCode.M then
			setShopsOpen(not shopsOpen)
			if UserInputService.GamepadEnabled then
				GuiService.SelectedObject = createdShopsButton
			end
		end
	end))

	task.spawn(function()
		while screenGui.Parent do
			local eclipseUI = (_G :: any).EclipseUI
			if eclipseUI and typeof(eclipseUI.PanelChanged) == "RBXScriptSignal" then
				if type(eclipseUI.GetActiveScreen) == "function" then
					applyActivePanel(eclipseUI.GetActiveScreen())
				end
				self._trove:Add(eclipseUI.PanelChanged:Connect(function(panelName)
					applyActivePanel(panelName)
				end))
				return
			end
			task.wait()
		end
	end)
end

function HUDController:_updateXPCaption(xp: number, xpToNextTier: number?)
	self._xpCaption.Text = if xpToNextTier then `{xp} / {xpToNextTier} XP` else `{xp} XP (MAX)`
end

function HUDController:_refreshQuestTracker(state: PlayerSessionTypes.QuestState)
	local text, current, target = QuestConfig.DescribeCurrentObjective(state)
	local objectiveText = string.gsub(text, " %(%d+/%d+%)$", "")
	self._questLabel.Text = objectiveText

	local quest = if state.ActiveQuestId then QuestConfig.Get(state.ActiveQuestId) else QuestConfig.TutorialQuest
	local questName = if quest then quest.name else "Current Objective"
	local questTitle = string.upper(questName)
	self._questTitleLabel.Text = questTitle
	self._compactQuestTitle.Text = questTitle

	if current and target and target > 0 then
		self._questProgressLabel.Text = `{current} / {target}`
		self._compactQuestProgress.Text = `{current} / {target}`
		self._questProgressLabel.Visible = true
	else
		self._compactQuestProgress.Text = "--"
		self._questProgressLabel.Visible = false
	end

	local hint = QuestConfig.DescribeCurrentObjectiveHint(state)
	if not state.ActiveQuestId and current == 0 and target == 1 then
		hint = "Onboarding District"
	end
	self._questHintLabel.Text = hint or ""
	self._questHintLabel.Visible = hint ~= nil
end

-- Chained Quad/Out scale overshoot (1 -> 1.35 -> 1) on the tier pill — stays
-- within the project's Quad/Out-only motion vocabulary rather than reaching
-- for a Back/Bounce/Elastic easing style for the "celebration" feel.
function HUDController:_playLevelUpPop()
	local scale = self._tierPill:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Parent = self._tierPill
	end
	Motion.Tween(scale, "LevelUpPop", TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.35 })
	task.delay(0.18, function()
		Motion.Tween(scale, "LevelUpPop", TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 })
	end)
end

-- Diffs the incoming QuestState against the last one seen to detect
-- mid-quest objective advances and full quest completion, pushing the
-- appropriate notification. Guarded by self._hasHydrated so this never
-- false-fires off the very first session hydrate (there is no "previous"
-- live state at that point, only the one-time initial snapshot).
function HUDController:_handleQuestUpdate(state: PlayerSessionTypes.QuestState)
	local previous = self._lastQuestState
	if previous and self._hasHydrated then
		if #state.CompletedQuestIds > #previous.CompletedQuestIds then
			local completedId = state.CompletedQuestIds[#state.CompletedQuestIds]
			local quest = QuestConfig.Get(completedId)
			NotificationController.Banner("QuestCompleted", "Quest Complete", if quest then quest.name else nil)
		elseif not previous.ActiveQuestId and state.ActiveQuestId then
			local quest = QuestConfig.Get(state.ActiveQuestId)
			NotificationController.Toast("ObjectiveAdvanced", if quest then `{quest.name} started` else "Quest started")
		elseif previous.ActiveQuestId == state.ActiveQuestId and state.ObjectiveIndex > previous.ObjectiveIndex then
			local quest = state.ActiveQuestId and QuestConfig.Get(state.ActiveQuestId)
			local nextObjective = quest and quest.objectives[state.ObjectiveIndex]
			if nextObjective then
				NotificationController.Toast("ObjectiveAdvanced", nextObjective.description)
			end
		end
	end

	self._lastQuestState = state
	self:_refreshQuestTracker(state)
end

function HUDController:_applySession(session: PlayerSessionTypes.PlayerSessionData)
	self._currencyLabel.Text = formatScrap(session.Currencies.Scrap)
	self._tierLabel.Text = `TIER {session.Progression.Tier}`
	self._levelLabel.Text = `◆  LEVEL {session.Progression.Tier}`

	local threshold = XPConfig.ThresholdForTier(session.Progression.Tier)
	self._setXPProgress(if threshold then session.Progression.XP / threshold else 1, false)
	self:_updateXPCaption(session.Progression.XP, threshold)

	self._lastQuestState = session.Quest
	self._hasHydrated = true
	self:_refreshQuestTracker(session.Quest)
end

function HUDController:Start()
	local ok, session = pcall(function()
		return Net.GetFunction("RequestPlayerSession"):InvokeServer()
	end)
	if ok and session then
		self:_applySession(session :: PlayerSessionTypes.PlayerSessionData)
	else
		warn("HUDController: failed to fetch initial session", session)
	end

	self._trove:Add(Net.GetEvent("CurrencyChanged").OnClientEvent:Connect(function(newScrap: number)
		self._currencyLabel.Text = formatScrap(newScrap)
	end))
	self._trove:Add(Net.GetEvent("ProgressionChanged").OnClientEvent:Connect(function(newTier: number)
		self._tierLabel.Text = `TIER {newTier}`
		self._levelLabel.Text = `◆  LEVEL {newTier}`
	end))
	self._trove:Add(Net.GetEvent("QuestUpdated").OnClientEvent:Connect(function(state: PlayerSessionTypes.QuestState)
		self:_handleQuestUpdate(state)
	end))
	self._trove:Add(Net.GetEvent("XPChanged").OnClientEvent:Connect(function(payload: { AmountGained: number, XP: number, XPToNextTier: number?, Tier: number, TierUp: boolean })
		self._setXPProgress(if payload.XPToNextTier then payload.XP / payload.XPToNextTier else 1)
		self:_updateXPCaption(payload.XP, payload.XPToNextTier)
		if payload.AmountGained > 0 then
			NotificationController.Toast("XPGained", `+{payload.AmountGained} XP`)
		end
		if payload.TierUp then
			self._tierLabel.Text = `TIER {payload.Tier}`
			self._levelLabel.Text = `◆  LEVEL {payload.Tier}`
			self:_playLevelUpPop()
			NotificationController.Banner("LevelUp", `Tier {payload.Tier} Reached`, "New areas may now be available.")
		end
	end))

	self._trove:Add(UserInputService.GamepadConnected:Connect(function()
		GuiService.SelectedObject = self._menuButton
	end))

	local eligibleOk, eligible = pcall(function()
		return Net.GetFunction("RequestStarterPackEligible"):InvokeServer()
	end)
	self._setStarterPackEligible(eligibleOk and eligible == true)
end

return HUDController
