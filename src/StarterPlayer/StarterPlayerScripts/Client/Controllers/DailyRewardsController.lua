--!strict
-- Phase 3B: the Daily Rewards case-opening-style reveal UI. The server
-- result is fetched and known FIRST (DailyRewardsService.Claim already
-- picked and durably recorded the reward before this ever returns) — this
-- controller never picks or previews an outcome itself, it only builds a
-- strip that ends on the already-decided result and animates a reveal.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local Trove = require(ReplicatedStorage.Shared.Modules.Trove)
local DailyRewardConfig = require(ReplicatedStorage.Shared.Config.DailyRewardConfig)

local Theme = require(script.Parent.Parent.UI.Theme)
local Motion = require(script.Parent.Parent.UI.Motion)
local GamepadNav = require(script.Parent.Parent.UI.GamepadNav)
local GlassPanel = require(script.Parent.Parent.UI.Components.GlassPanel)
local Button = require(script.Parent.Parent.UI.Components.Button)
local CloseButton = require(script.Parent.Parent.UI.Components.CloseButton)

local NotificationController = require(script.Parent.NotificationController)

local TILE_WIDTH = 96
local TILE_HEIGHT = 110
local TILE_GAP = 10
local TILE_STRIDE = TILE_WIDTH + TILE_GAP
local STRIP_TILE_COUNT = 26 -- last tile is always the real, server-picked result
local VIEWPORT_WIDTH = 420
local ROLL_TWEEN = TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

local DailyRewardsController = {}

local isOpen = false
local previousSelection: GuiObject? = nil

local function buildStripTile(parent: Instance, reward: DailyRewardConfig.RewardEntry, x: number): Frame
	local tile = Instance.new("Frame")
	tile.Name = "Tile"
	tile.Size = UDim2.fromOffset(TILE_WIDTH, TILE_HEIGHT)
	tile.Position = UDim2.fromOffset(x, 0)
	tile.BackgroundColor3 = Theme.Colors.PanelBackground
	tile.BackgroundTransparency = Theme.Transparency.PanelBackground
	tile.BorderSizePixel = 0
	tile.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.Corner.Medium
	corner.Parent = tile

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Colors.Brand
	stroke.Thickness = 1.5
	stroke.Transparency = Theme.Transparency.StrokeSubtle
	stroke.Parent = tile

	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.new(1, 0, 0, 54)
	icon.Position = UDim2.new(0, 0, 0, 8)
	icon.Font = Enum.Font.GothamBold
	icon.TextSize = 32
	icon.TextColor3 = Theme.Colors.TextPrimary
	icon.Text = reward.Icon
	icon.Parent = tile

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -8, 0, 30)
	label.Position = UDim2.new(0, 4, 0, 64)
	label.Font = Theme.Font.Caption.Font
	label.TextSize = Theme.Font.Caption.Size
	label.TextWrapped = true
	label.TextColor3 = Theme.Colors.TextSecondary
	label.Text = reward.Label
	label.Parent = tile

	return tile
end

function DailyRewardsController:_playRoll(rewardIndex: number)
	for _, child in self._strip:GetChildren() do
		child:Destroy()
	end

	local rng = Random.new()
	for i = 1, STRIP_TILE_COUNT - 1 do
		local randomIndex = rng:NextInteger(1, #DailyRewardConfig.Rewards)
		buildStripTile(self._strip, DailyRewardConfig.Rewards[randomIndex], (i - 1) * TILE_STRIDE)
	end
	-- The last tile is always the real, server-picked result — the strip
	-- can only ever land here, never on one of the decorative tiles above.
	buildStripTile(self._strip, DailyRewardConfig.Rewards[rewardIndex], (STRIP_TILE_COUNT - 1) * TILE_STRIDE)

	self._strip.Size = UDim2.fromOffset(STRIP_TILE_COUNT * TILE_STRIDE, TILE_HEIGHT)

	local viewportCenterX = VIEWPORT_WIDTH / 2
	local finalTileCenterX = (STRIP_TILE_COUNT - 1) * TILE_STRIDE + TILE_WIDTH / 2
	local targetX = viewportCenterX - finalTileCenterX

	-- Start a handful of tiles further along than the target so it visibly
	-- rolls backward into place, then settle exactly on the real result.
	self._strip.Position = UDim2.fromOffset(targetX + 6 * TILE_STRIDE, 0)
	Motion.Tween(self._strip, "Roll", ROLL_TWEEN, { Position = UDim2.fromOffset(targetX, 0) })
end

function DailyRewardsController:_claim()
	if self._claiming then
		return
	end
	self._claiming = true
	Button.SetDisabled(self._claimButton, true)

	local ok, result = pcall(function()
		return Net.GetFunction("RequestDailyRewardRoll"):InvokeServer()
	end)

	self._claiming = false

	if ok and result and not result.Rejected and result.RewardIndex then
		local reward = DailyRewardConfig.Rewards[result.RewardIndex]
		self._streakLabel.Text = `Streak: {result.Streak} day{if result.Streak == 1 then "" else "s"}`
		self:_playRoll(result.RewardIndex)
		NotificationController.Toast("DailyRewardClaimed", `You got {reward.Label}!`, { Icon = reward.Icon })
	else
		self._streakLabel.Text = "Already claimed today — come back tomorrow."
		Button.SetDisabled(self._claimButton, false)
	end
end

function DailyRewardsController:Init()
	self._trove = Trove.new()

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "DailyRewardsUI"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = playerGui
	self._trove:Add(screenGui)

	local backdrop = Instance.new("CanvasGroup")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.5
	backdrop.GroupTransparency = 1
	backdrop.Visible = false
	backdrop.Parent = screenGui
	self._backdrop = backdrop

	local backdropButton = Instance.new("TextButton")
	backdropButton.Name = "BackdropCatcher"
	backdropButton.Size = UDim2.fromScale(1, 1)
	backdropButton.BackgroundTransparency = 1
	backdropButton.Text = ""
	backdropButton.AutoButtonColor = false
	backdropButton.Parent = backdrop
	self._trove:Add(backdropButton.Activated:Connect(function()
		DailyRewardsController.Close()
	end))

	local panel = GlassPanel.new({
		Name = "Panel",
		Size = UDim2.fromOffset(VIEWPORT_WIDTH + 2 * Theme.Spacing.L, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = backdrop,
	})
	self._panel = panel

	local panelScale = Instance.new("UIScale")
	panelScale.Name = "PanelScale"
	panelScale.Scale = 0.94
	panelScale.Parent = panel
	self._panelScale = panelScale

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, Theme.Spacing.L)
	padding.PaddingRight = UDim.new(0, Theme.Spacing.L)
	padding.PaddingTop = UDim.new(0, Theme.Spacing.L)
	padding.PaddingBottom = UDim.new(0, Theme.Spacing.L)
	padding.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, Theme.Spacing.M)
	layout.Parent = panel

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -52, 0, 28)
	title.LayoutOrder = 1
	title.Font = Theme.Font.Title.Font
	title.TextSize = Theme.Font.Title.Size
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Theme.Colors.TextPrimary
	title.Text = "DAILY REWARDS"
	title.Parent = panel

	local closeButton = CloseButton.new({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		OnActivated = function()
			DailyRewardsController.Close()
		end,
		Parent = panel,
	})

	local streakLabel = Instance.new("TextLabel")
	streakLabel.Name = "StreakLabel"
	streakLabel.BackgroundTransparency = 1
	streakLabel.Size = UDim2.new(1, 0, 0, 18)
	streakLabel.LayoutOrder = 2
	streakLabel.Font = Theme.Font.Label.Font
	streakLabel.TextSize = Theme.Font.Label.Size
	streakLabel.TextXAlignment = Enum.TextXAlignment.Left
	streakLabel.TextColor3 = Theme.Colors.TextMuted
	streakLabel.Text = "Streak: —"
	streakLabel.Parent = panel
	self._streakLabel = streakLabel

	local viewport = Instance.new("Frame")
	viewport.Name = "StripViewport"
	viewport.Size = UDim2.fromOffset(VIEWPORT_WIDTH, TILE_HEIGHT)
	viewport.LayoutOrder = 3
	viewport.ClipsDescendants = true
	viewport.BackgroundColor3 = Theme.Colors.PanelBackground
	viewport.BackgroundTransparency = 0.55
	viewport.BorderSizePixel = 0
	viewport.Parent = panel

	local viewportCorner = Instance.new("UICorner")
	viewportCorner.CornerRadius = Theme.Corner.Medium
	viewportCorner.Parent = viewport

	local strip = Instance.new("Frame")
	strip.Name = "Strip"
	strip.Size = UDim2.fromOffset(STRIP_TILE_COUNT * TILE_STRIDE, TILE_HEIGHT)
	strip.BackgroundTransparency = 1
	strip.Parent = viewport
	self._strip = strip

	local pointer = Instance.new("Frame")
	pointer.Name = "Pointer"
	pointer.Size = UDim2.new(0, 3, 1, 0)
	pointer.Position = UDim2.new(0.5, -1, 0, 0)
	pointer.BackgroundColor3 = Theme.Colors.Danger
	pointer.BorderSizePixel = 0
	pointer.ZIndex = 5
	pointer.Parent = viewport

	local claimButton = Button.new({
		Text = "Claim",
		Variant = "Primary",
		Size = UDim2.new(1, 0, 0, 44),
		LayoutOrder = 4,
		OnActivated = function()
			self:_claim()
		end,
		Parent = panel,
	})
	self._claimButton = claimButton

	GamepadNav.LinkChain({ closeButton, claimButton })
end

function DailyRewardsController.Open()
	if isOpen then
		return
	end
	isOpen = true

	local self = DailyRewardsController
	self._backdrop.Visible = true
	Motion.Tween(self._backdrop, "Fade", Theme.Motion.PanelOpen, { GroupTransparency = 0 })
	Motion.Tween(self._panelScale, "Scale", Theme.Motion.PanelOpen, { Scale = 1 })

	previousSelection = GuiService.SelectedObject
	GamepadNav.FocusFirst(self._panel)
end

function DailyRewardsController.Close()
	if not isOpen then
		return
	end
	isOpen = false

	local self = DailyRewardsController
	local tween = Motion.Tween(self._backdrop, "Fade", Theme.Motion.PanelClose, { GroupTransparency = 1 })
	Motion.Tween(self._panelScale, "Scale", Theme.Motion.PanelClose, { Scale = 0.94 })
	tween.Completed:Once(function()
		if not isOpen then
			self._backdrop.Visible = false
		end
	end)

	GamepadNav.Restore(previousSelection)
end

function DailyRewardsController:Start() end

return DailyRewardsController
