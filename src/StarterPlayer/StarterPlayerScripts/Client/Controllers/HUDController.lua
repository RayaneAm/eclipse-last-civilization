--!strict
-- Persistent premium HUD: currency + tier readout, a non-intrusive quest
-- tracker, and the one menu button that opens InventoryController's panel.
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
local MOBILE_HUD_SCALE = 0.85
local STATUS_PANEL_HEIGHT = 60

local HUDController = {}

-- Fired when the player activates the HUD menu button. InventoryController
-- listens for this to toggle its panel — a plain client-side Signal keeps
-- the two Controllers decoupled (neither needs the other's Init order).
HUDController.MenuOpenRequested = Signal.new()

-- Phase 3B: same decoupled pattern for the 2 new left-middle monetization
-- buttons — ShopController listens for these.
HUDController.ShopOpenRequested = Signal.new()
HUDController.StarterPackOpenRequested = Signal.new()

-- Phase 4A: 2 new right-middle buttons (mirroring the left-middle Shop/
-- Starter Pack column) — PlayerMarketController/SupplyShopController listen
-- for these. Kept visually/functionally separate from the Shop
-- (Robux/Season Pass) button above.
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
	screenGui.Parent = playerGui
	self._trove:Add(screenGui)

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.Parent = screenGui

	local hudScale = Instance.new("UIScale")
	hudScale.Name = "HUDScale"
	hudScale.Parent = root
	self._hudScale = hudScale

	-- Currency + tier readout, top-left. Rebuilt as a tight two-row card
	-- (was two side-by-side Pills with the XP bar squeezed into an 11px-tall
	-- sliver at the bottom) — Row 1 is Tier/Currency via a space-between
	-- layout, Row 2 is a real XP bar with a numeric caption.
	local statusPanel = GlassPanel.new({
		Name = "StatusPanel",
		Size = UDim2.fromOffset(216, STATUS_PANEL_HEIGHT),
		Position = UDim2.fromOffset(Theme.Spacing.L, Theme.Spacing.L),
		CornerRadius = Theme.Corner.Large,
		Gradient = false,
		Parent = root,
	})
	local statusLayout = Instance.new("UIListLayout")
	statusLayout.FillDirection = Enum.FillDirection.Vertical
	statusLayout.Padding = UDim.new(0, Theme.Spacing.XXS)
	statusLayout.Parent = statusPanel
	local statusPadding = Instance.new("UIPadding")
	statusPadding.PaddingLeft = UDim.new(0, Theme.Spacing.M)
	statusPadding.PaddingRight = UDim.new(0, Theme.Spacing.M)
	statusPadding.PaddingTop = UDim.new(0, Theme.Spacing.S)
	statusPadding.PaddingBottom = UDim.new(0, Theme.Spacing.S)
	statusPadding.Parent = statusPanel

	local statusRow1 = Instance.new("Frame")
	statusRow1.Name = "Row1"
	statusRow1.Size = UDim2.new(1, 0, 0, 20)
	statusRow1.LayoutOrder = 1
	statusRow1.BackgroundTransparency = 1
	statusRow1.Parent = statusPanel

	local statusRow1Layout = Instance.new("UIListLayout")
	statusRow1Layout.FillDirection = Enum.FillDirection.Horizontal
	statusRow1Layout.HorizontalFlex = Enum.UIFlexAlignment.SpaceBetween
	statusRow1Layout.VerticalAlignment = Enum.VerticalAlignment.Center
	statusRow1Layout.Parent = statusRow1

	local tierLabel = Instance.new("TextLabel")
	tierLabel.Name = "Tier"
	tierLabel.AutomaticSize = Enum.AutomaticSize.X
	tierLabel.Size = UDim2.new(0, 0, 1, 0)
	tierLabel.BackgroundTransparency = 1
	tierLabel.Font = Theme.Font.Label.Font
	tierLabel.TextSize = Theme.Font.Label.Size
	tierLabel.TextColor3 = Theme.Colors.BrandLight
	tierLabel.TextXAlignment = Enum.TextXAlignment.Left
	tierLabel.Text = "TIER 0"
	tierLabel.Parent = statusRow1

	local currencyLabel = Instance.new("TextLabel")
	currencyLabel.Name = "Currency"
	currencyLabel.AutomaticSize = Enum.AutomaticSize.X
	currencyLabel.Size = UDim2.new(0, 0, 1, 0)
	currencyLabel.BackgroundTransparency = 1
	currencyLabel.Font = Theme.Font.Stat.Font
	currencyLabel.TextSize = Theme.Font.Stat.Size
	currencyLabel.TextColor3 = Theme.Colors.TextPrimary
	currencyLabel.TextXAlignment = Enum.TextXAlignment.Right
	currencyLabel.Text = "◆ 0"
	currencyLabel.Parent = statusRow1

	self._currencyLabel = currencyLabel
	self._tierLabel = tierLabel
	self._tierPill = tierLabel

	local statusRow2 = Instance.new("Frame")
	statusRow2.Name = "Row2"
	statusRow2.Size = UDim2.new(1, 0, 0, 22)
	statusRow2.LayoutOrder = 2
	statusRow2.BackgroundTransparency = 1
	statusRow2.Parent = statusPanel

	local statusRow2Layout = Instance.new("UIListLayout")
	statusRow2Layout.FillDirection = Enum.FillDirection.Vertical
	statusRow2Layout.Padding = UDim.new(0, Theme.Spacing.XXS)
	statusRow2Layout.Parent = statusRow2

	local _xpBar, setXPProgress = ProgressBar.new({
		Name = "XPBar",
		Size = UDim2.new(1, 0, 0, 8),
		AccentColor = Theme.Colors.BrandLight,
		LayoutOrder = 1,
		Parent = statusRow2,
	})
	self._setXPProgress = setXPProgress

	local xpCaption = Instance.new("TextLabel")
	xpCaption.Name = "XPCaption"
	xpCaption.Size = UDim2.new(1, 0, 0, 12)
	xpCaption.LayoutOrder = 2
	xpCaption.BackgroundTransparency = 1
	xpCaption.Font = Theme.Font.Caption.Font
	xpCaption.TextSize = Theme.Font.Caption.Size
	xpCaption.TextColor3 = Theme.Colors.TextMuted
	xpCaption.TextXAlignment = Enum.TextXAlignment.Left
	xpCaption.Text = "0 XP"
	xpCaption.Parent = statusRow2
	self._xpCaption = xpCaption

	-- Quest tracker, top area (offset right of the status panel so the two
	-- never overlap regardless of status panel width). True content-driven
	-- height: a short objective hugs its text instead of always reserving a
	-- fixed 64px, and a long/wrapped one grows instead of clipping.
	local questPanel = GlassPanel.new({
		Name = "QuestTracker",
		Size = UDim2.new(0, 260, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.new(0, Theme.Spacing.L, 0, Theme.Spacing.L + STATUS_PANEL_HEIGHT + Theme.Spacing.S),
		Parent = root,
	})
	local questPadding = Instance.new("UIPadding")
	questPadding.PaddingLeft = UDim.new(0, Theme.Spacing.M)
	questPadding.PaddingRight = UDim.new(0, Theme.Spacing.M)
	questPadding.PaddingTop = UDim.new(0, Theme.Spacing.S)
	questPadding.PaddingBottom = UDim.new(0, Theme.Spacing.S)
	questPadding.Parent = questPanel

	local questLayout = Instance.new("UIListLayout")
	questLayout.FillDirection = Enum.FillDirection.Vertical
	questLayout.Padding = UDim.new(0, Theme.Spacing.XS)
	questLayout.Parent = questPanel

	local questLabel = Instance.new("TextLabel")
	questLabel.Name = "Objective"
	questLabel.BackgroundTransparency = 1
	questLabel.Size = UDim2.new(1, 0, 0, 0)
	questLabel.AutomaticSize = Enum.AutomaticSize.Y
	questLabel.LayoutOrder = 1
	questLabel.Font = Theme.Font.Label.Font
	questLabel.TextSize = Theme.Font.Label.Size
	questLabel.TextXAlignment = Enum.TextXAlignment.Left
	questLabel.TextYAlignment = Enum.TextYAlignment.Top
	questLabel.TextWrapped = true
	questLabel.TextColor3 = Theme.Colors.TextSecondary
	questLabel.Text = "..."
	questLabel.Parent = questPanel
	self._questLabel = questLabel

	local _questBar, setQuestProgress = ProgressBar.new({
		Name = "ObjectiveProgress",
		Size = UDim2.new(1, 0, 0, 6),
		LayoutOrder = 2,
		AccentColor = Theme.Colors.Brand,
		Parent = questPanel,
	})
	self._questPanel = questPanel
	self._setQuestProgress = setQuestProgress

	-- "Where do I go for this step" — always reflects only the current step
	-- (derived fresh from QuestConfig.DescribeCurrentObjectiveHint), so a
	-- completed step's hint is never shown.
	local questHintLabel = Instance.new("TextLabel")
	questHintLabel.Name = "Hint"
	questHintLabel.BackgroundTransparency = 1
	questHintLabel.Size = UDim2.new(1, 0, 0, 0)
	questHintLabel.AutomaticSize = Enum.AutomaticSize.Y
	questHintLabel.LayoutOrder = 3
	questHintLabel.Font = Theme.Font.Caption.Font
	questHintLabel.TextSize = Theme.Font.Caption.Size
	questHintLabel.TextXAlignment = Enum.TextXAlignment.Left
	questHintLabel.TextYAlignment = Enum.TextYAlignment.Top
	questHintLabel.TextWrapped = true
	questHintLabel.TextColor3 = Theme.Colors.TextMuted
	questHintLabel.Text = ""
	questHintLabel.Visible = false
	questHintLabel.Parent = questPanel
	self._questHintLabel = questHintLabel

	-- Menu button, bottom-right (one-thumb mobile reach). Icon-only, no
	-- label pill (was 64px + label, ~92px total footprint) — unlabeled
	-- corner nav buttons are the norm in top Roblox games, and the 🎒 glyph
	-- is unambiguous alone.
	local _menuContainer, menuButton = HudIconButton.new({
		Name = "MenuButton",
		Icon = "🎒",
		AccentColor = Theme.Colors.Brand,
		Size = UDim2.fromOffset(56, 56),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -Theme.Spacing.L, 1, -Theme.Spacing.L),
		OnActivated = function()
			HUDController.MenuOpenRequested:Fire()
		end,
		Parent = root,
	})
	self._menuButton = menuButton

	-- Phase 3B: 2 monetization entry points, left-middle of the screen —
	-- "easy to notice but not intrusive" per the brief, mirroring the
	-- bottom-right menu button's unlabeled-icon-tile treatment but with a
	-- label pill since these are less universally self-explanatory than a
	-- backpack glyph.
	local _shopContainer, shopButton = HudIconButton.new({
		Name = "ShopButton",
		Icon = "🛒",
		Label = "Shop",
		AccentColor = Theme.Colors.Teal, -- economy/trade accent — distinguishes Shop from the Brand-purple Menu button
		Size = UDim2.fromOffset(56, 56),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, Theme.Spacing.L, 0.5, -40),
		OnActivated = function()
			HUDController.ShopOpenRequested:Fire()
		end,
		Parent = root,
	})
	self._shopButton = shopButton

	-- Hidden until Start() confirms eligibility (< 30 total hours played) —
	-- defaults hidden rather than flashing visible-then-hidden.
	local starterPackContainer, starterPackButton = HudIconButton.new({
		Name = "StarterPackButton",
		Icon = "🎁",
		Label = "New Survivor Offer",
		AccentColor = Theme.Colors.Gold,
		-- The whole button only ever becomes visible once Start() confirms
		-- eligibility (below), so a static "!" badge here is only ever seen
		-- by an eligible player — no separate dynamic toggle needed.
		Badge = "!",
		Size = UDim2.fromOffset(56, 56),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, Theme.Spacing.L, 0.5, 40),
		Pulse = true, -- the one "meaningfully special" case Theme.Motion.Pulse's doc comment calls out — a limited-time new-survivor offer
		OnActivated = function()
			HUDController.StarterPackOpenRequested:Fire()
		end,
		Parent = root,
	})
	starterPackContainer.Visible = false
	self._starterPackContainer = starterPackContainer
	self._starterPackButton = starterPackButton

	-- Phase 4A: 2 new entry points, right-middle — mirrors the left-middle
	-- Shop/Starter Pack column's unlabeled-tile-with-pill treatment, kept on
	-- the opposite side so neither column crowds the other.
	local _marketplaceContainer, marketplaceButton = HudIconButton.new({
		Name = "MarketplaceButton",
		Icon = "🔁",
		Label = "Marketplace",
		AccentColor = Theme.Colors.Brand,
		Size = UDim2.fromOffset(56, 56),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -Theme.Spacing.L, 0.5, -40),
		OnActivated = function()
			HUDController.MarketplaceOpenRequested:Fire()
		end,
		Parent = root,
	})
	self._marketplaceButton = marketplaceButton

	local _supplyShopContainer, supplyShopButton = HudIconButton.new({
		Name = "SupplyShopButton",
		Icon = "📦",
		Label = "Supply Shop",
		AccentColor = Theme.Colors.Teal:Lerp(Color3.new(0, 0, 0), 0.25), -- darker teal, paired with Shop as "economy" without being identical to it

		Size = UDim2.fromOffset(56, 56),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -Theme.Spacing.L, 0.5, 40),
		OnActivated = function()
			HUDController.SupplyShopOpenRequested:Fire()
		end,
		Parent = root,
	})
	self._supplyShopButton = supplyShopButton

	-- Mobile-first scaling: shrink the whole HUD on narrow viewports, and
	-- keep it correct across device rotation / window resize.
	local camera = Workspace.CurrentCamera
	local function applyViewportScale()
		if not camera then
			return
		end
		local isNarrow = camera.ViewportSize.X < MOBILE_VIEWPORT_WIDTH_THRESHOLD
		hudScale.Scale = if isNarrow then MOBILE_HUD_SCALE else 1
	end
	applyViewportScale()
	if camera then
		self._trove:Add(camera:GetPropertyChangedSignal("ViewportSize"):Connect(applyViewportScale))
	end
end

function HUDController:_updateXPCaption(xp: number, xpToNextTier: number?)
	self._xpCaption.Text = if xpToNextTier then `{xp}/{xpToNextTier} XP` else `{xp} XP (MAX)`
end

function HUDController:_refreshQuestTracker(state: PlayerSessionTypes.QuestState)
	local text, current, target = QuestConfig.DescribeCurrentObjective(state)
	self._questLabel.Text = text
	if current and target and target > 0 then
		self._setQuestProgress(current / target)
	else
		self._setQuestProgress(0, false)
	end

	local hint = QuestConfig.DescribeCurrentObjectiveHint(state)
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
	self._currencyLabel.Text = `◆ {session.Currencies.Scrap}`
	self._tierLabel.Text = `TIER {session.Progression.Tier}`

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
		self._currencyLabel.Text = `◆ {newScrap}`
	end))
	self._trove:Add(Net.GetEvent("ProgressionChanged").OnClientEvent:Connect(function(newTier: number)
		self._tierLabel.Text = `TIER {newTier}`
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
	self._starterPackContainer.Visible = eligibleOk and eligible == true
end

return HUDController
