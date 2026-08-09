--!strict
-- The Daily Quests panel. Purely a renderer: it asks the server for today's
-- DailyQuestState once, then re-renders on every DailyQuestsUpdated push. It
-- holds no counters of its own and has no way to report progress — every
-- number on screen came from DailyQuestService, which derived it from real
-- gameplay Signals (see that service's header).
--
-- Every row is built from DailyQuestConfig, never hardcoded, so retuning an
-- amount or adding a pool entry needs no change in this file. The reset
-- countdown is likewise read from DailyQuestConfig so the client can't drift
-- from the server's own day bucketing.
--
-- Structurally modeled on DailyRewardsController (backdrop + centered
-- GlassPanel + Motion open/close + GamepadNav) so the two daily-cadence
-- screens read as the same screen family.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local Trove = require(ReplicatedStorage.Shared.Modules.Trove)
local DailyQuestConfig = require(ReplicatedStorage.Shared.Config.DailyQuestConfig)
local PlayerSessionTypes = require(ReplicatedStorage.Shared.Config.PlayerSessionTypes)

local Theme = require(script.Parent.Parent.UI.Theme)
local Motion = require(script.Parent.Parent.UI.Motion)
local GamepadNav = require(script.Parent.Parent.UI.GamepadNav)
local GlassPanel = require(script.Parent.Parent.UI.Components.GlassPanel)
local Surface = require(script.Parent.Parent.UI.Components.Surface)
local CloseButton = require(script.Parent.Parent.UI.Components.CloseButton)
local ProgressBar = require(script.Parent.Parent.UI.Components.ProgressBar)
local StatusBadge = require(script.Parent.Parent.UI.Components.StatusBadge)
local EmptyState = require(script.Parent.Parent.UI.Components.EmptyState)

local HUDController = require(script.Parent.HUDController)
local NotificationController = require(script.Parent.NotificationController)

local PANEL_WIDTH = 460
local ROW_HEIGHT = 84
local COUNTDOWN_REFRESH_SECONDS = 30

local DailyQuestsController = {}

local isOpen = false
local previousSelection: GuiObject? = nil

local function worldBoardSurface(): SurfaceGui?
	local haven = Workspace:FindFirstChild("SurvivorHaven_Generated")
	local board = if haven then haven:FindFirstChild("DailyQuestBoard") else nil
	local display = if board then board:FindFirstChild("QuestDisplay", true) else nil
	local surface = if display then display:FindFirstChild("QuestDisplaySurface") else nil
	return if surface and surface:IsA("SurfaceGui") then surface else nil
end

local function childText(parent: Instance, name: string): TextLabel?
	local child = parent:FindFirstChild(name)
	return if child and child:IsA("TextLabel") then child else nil
end

local function renderWorldBoard(state: PlayerSessionTypes.DailyQuestState?)
	local surface = worldBoardSurface()
	if not surface then
		return
	end
	local resetTimer = childText(surface, "ResetTimer")
	if resetTimer then
		resetTimer.Text = `Refreshing in {DailyQuestConfig.DescribeTimeUntilReset()}`
	end

	local entries = if state then state.Quests else {}
	local fallbackIds = DailyQuestConfig.SharedDailyIds()
	for index = 1, DailyQuestConfig.QUESTS_PER_DAY do
		local row = surface:FindFirstChild(`QuestRow{index}`)
		if not row or not row:IsA("Frame") then
			continue
		end
		local entry = entries[index]
		local id = if entry then entry.Id else fallbackIds[index]
		local definition = DailyQuestConfig.Get(id)
		if not definition then
			continue
		end
		local progress = if entry then entry.Progress else 0
		local completed = if entry then entry.Completed else false
		local name = childText(row, "QuestName")
		local objective = childText(row, "Objective")
		local reward = childText(row, "Reward")
		local status = childText(row, "Status")
		if name then
			name.Text = definition.name
		end
		if objective then
			objective.Text = DailyQuestConfig.DescribeProgress(definition, progress)
		end
		if reward then
			reward.Text = `+{definition.rewardScrap} SCRAP`
		end
		if status then
			status.Text = if completed then "COMPLETE" else "INCOMPLETE"
			status.TextColor3 = if completed then Color3.fromRGB(104, 214, 145) else Color3.fromRGB(230, 219, 202)
		end
		local track = row:FindFirstChild("ProgressTrack")
		local fill = if track then track:FindFirstChild("ProgressFill") else nil
		if fill and fill:IsA("Frame") then
			fill.Size = UDim2.fromScale(math.clamp(progress / definition.amount, 0, 1), 1)
			fill.BackgroundColor3 = if completed then Color3.fromRGB(104, 214, 145) else Color3.fromRGB(229, 176, 54)
		end
	end
end

-- One row per quest. Rebuilt wholesale on every state push rather than
-- diffed in place — a set is at most DailyQuestConfig.QUESTS_PER_DAY rows and
-- only changes on a real gameplay event, so the simpler code wins.
local function buildRow(parent: Instance, entry: PlayerSessionTypes.DailyQuestEntry, layoutOrder: number): Frame?
	local definition = DailyQuestConfig.Get(entry.Id)
	if not definition then
		return nil -- pool entry retired since this set was rolled; the server re-rolls it out on the next reset
	end

	-- DropShadow off deliberately: Shadow.Attach parents a same-size SIBLING
	-- Frame, which a UIListLayout would lay out as an extra blank row between
	-- every quest. The rows still read as nested cards via CardBackground,
	-- which is the primary signal Theme's art-direction header calls for.
	local row = Surface.new({
		Name = entry.Id,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		LayoutOrder = layoutOrder,
		DropShadow = false,
		Parent = parent,
	})

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, Theme.Spacing.M)
	padding.PaddingRight = UDim.new(0, Theme.Spacing.M)
	padding.PaddingTop = UDim.new(0, Theme.Spacing.S)
	padding.PaddingBottom = UDim.new(0, Theme.Spacing.S)
	padding.Parent = row

	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.Size = UDim2.fromOffset(38, 38)
	icon.Position = UDim2.fromOffset(0, 4)
	icon.BackgroundTransparency = 1
	icon.Font = Enum.Font.GothamBold
	icon.TextSize = 26
	icon.TextColor3 = Theme.Colors.TextPrimary
	icon.Text = definition.icon
	icon.Parent = row

	local name = Instance.new("TextLabel")
	name.Name = "Name"
	name.Size = UDim2.new(1, -150, 0, 18)
	name.Position = UDim2.fromOffset(46, 2)
	name.BackgroundTransparency = 1
	name.Font = Theme.Font.Heading.Font
	name.TextSize = Theme.Font.Heading.Size
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextColor3 = if entry.Completed then Theme.Colors.Success else Theme.Colors.TextPrimary
	name.Text = definition.name
	name.Parent = row

	-- The objective line and its counter come from DailyQuestConfig, so the
	-- panel and any future tracker can never word the same objective
	-- differently.
	local objective = Instance.new("TextLabel")
	objective.Name = "Objective"
	objective.Size = UDim2.new(1, -150, 0, 16)
	objective.Position = UDim2.fromOffset(46, 22)
	objective.BackgroundTransparency = 1
	objective.Font = Theme.Font.Body.Font
	objective.TextSize = Theme.Font.Body.Size
	objective.TextXAlignment = Enum.TextXAlignment.Left
	objective.TextColor3 = Theme.Colors.TextSecondary
	objective.Text = DailyQuestConfig.DescribeProgress(definition, entry.Progress)
	objective.Parent = row

	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.Size = UDim2.new(1, -150, 0, 14)
	hint.Position = UDim2.fromOffset(46, 40)
	hint.BackgroundTransparency = 1
	hint.Font = Theme.Font.Caption.Font
	hint.TextSize = Theme.Font.Caption.Size
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.TextTruncate = Enum.TextTruncate.AtEnd
	hint.TextColor3 = Theme.Colors.TextMuted
	hint.Text = definition.hint
	hint.Parent = row

	local _bar, setProgress = ProgressBar.new({
		Name = "Progress",
		Size = UDim2.new(1, -46, 0, 6),
		Position = UDim2.new(0, 46, 1, -10),
		AccentColor = if entry.Completed then Theme.Colors.Success else Theme.Colors.Brand,
		Parent = row,
	})
	setProgress(math.min(entry.Progress, definition.amount) / definition.amount, false)

	local reward = Instance.new("TextLabel")
	reward.Name = "Reward"
	reward.Size = UDim2.fromOffset(96, 18)
	reward.AnchorPoint = Vector2.new(1, 0)
	reward.Position = UDim2.new(1, 0, 0, 2)
	reward.BackgroundTransparency = 1
	reward.Font = Theme.Font.Stat.Font
	reward.TextSize = Theme.Font.Label.Size
	reward.TextXAlignment = Enum.TextXAlignment.Right
	reward.TextColor3 = Theme.Colors.BrandLight
	reward.Text = `+{definition.rewardScrap} ◆`
	reward.Parent = row

	StatusBadge.new({
		Text = if entry.Completed then "Done" else "In Progress",
		Variant = if entry.Completed then "Available" else "Locked",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 24),
		Parent = row,
	})

	return row
end

function DailyQuestsController:_refreshCountdown()
	self._countdownLabel.Text = `Refreshing in {DailyQuestConfig.DescribeTimeUntilReset()}`
	renderWorldBoard(self._lastState)
end

function DailyQuestsController:_render(state: PlayerSessionTypes.DailyQuestState?)
	self._rowTrove:Clean()
	self:_refreshCountdown()
	renderWorldBoard(state)

	local quests = if state then state.Quests else {}
	if #quests == 0 then
		self._rowTrove:Add(EmptyState.new({
			Icon = "📋",
			Text = "No daily quests yet",
			-- Kept short on purpose: EmptyState's subtext uses AutomaticSize.X,
			-- so a long line grows the label instead of wrapping it.
			Subtext = "Finish your first steps with the Survivor Guide.",
			Size = UDim2.new(1, 0, 0, 110),
			LayoutOrder = 1,
			Parent = self._questList,
		}))
		self._bonusLabel.Text = ""
		return
	end

	local completed = 0
	for index, entry in quests do
		local row = buildRow(self._questList, entry, index)
		if row then
			self._rowTrove:Add(row)
		end
		if entry.Completed then
			completed += 1
		end
	end

	if state and state.BonusGranted then
		self._bonusLabel.Text = `All-clear bonus claimed: +{DailyQuestConfig.ALL_COMPLETE_BONUS_SCRAP} ◆`
		self._bonusLabel.TextColor3 = Theme.Colors.Success
	else
		self._bonusLabel.Text = `Finish all {#quests} for a +{DailyQuestConfig.ALL_COMPLETE_BONUS_SCRAP} ◆ bonus  ({completed}/{#quests})`
		self._bonusLabel.TextColor3 = Theme.Colors.TextMuted
	end
end

-- Diffs the incoming state against the last one to celebrate completions,
-- guarded by _hasHydrated so the very first snapshot (which may already
-- contain quests finished earlier today) never replays old banners. Same
-- pattern HUDController._handleQuestUpdate already uses for the tutorial.
function DailyQuestsController:_handleUpdate(state: PlayerSessionTypes.DailyQuestState)
	local previous = self._lastState
	if previous and self._hasHydrated then
		local wasCompleted: { [string]: boolean } = {}
		for _, entry in previous.Quests do
			wasCompleted[entry.Id] = entry.Completed
		end
		for _, entry in state.Quests do
			if entry.Completed and not wasCompleted[entry.Id] then
				local definition = DailyQuestConfig.Get(entry.Id)
				if definition then
					NotificationController.Banner(
						"QuestCompleted",
						"Daily Quest Complete",
						`{definition.name} — +{definition.rewardScrap} Scrap`
					)
				end
			end
		end
		if state.BonusGranted and not previous.BonusGranted then
			NotificationController.Banner(
				"QuestCompleted",
				"All Dailies Cleared",
				`+{DailyQuestConfig.ALL_COMPLETE_BONUS_SCRAP} bonus Scrap`
			)
		end
	end

	self._lastState = state
	self._hasHydrated = true
	self:_render(state)
end

function DailyQuestsController:Init()
	self._trove = Trove.new()
	self._rowTrove = Trove.new()
	self._trove:Add(self._rowTrove)

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "DailyQuestsUI"
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
		DailyQuestsController.Close()
	end))

	local panel = GlassPanel.new({
		Name = "Panel",
		Size = UDim2.fromOffset(PANEL_WIDTH + 2 * Theme.Spacing.L, 0),
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
	layout.SortOrder = Enum.SortOrder.LayoutOrder
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
	title.Text = "DAILY QUESTS"
	title.Parent = panel

	-- No GamepadNav.LinkChain here: this panel is read-only, so Close is its
	-- only focusable control and Open's FocusFirst already lands on it.
	CloseButton.new({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		OnActivated = function()
			DailyQuestsController.Close()
		end,
		Parent = panel,
	})

	local countdownLabel = Instance.new("TextLabel")
	countdownLabel.Name = "Countdown"
	countdownLabel.BackgroundTransparency = 1
	countdownLabel.Size = UDim2.new(1, 0, 0, 16)
	countdownLabel.LayoutOrder = 2
	countdownLabel.Font = Theme.Font.Label.Font
	countdownLabel.TextSize = Theme.Font.Label.Size
	countdownLabel.TextXAlignment = Enum.TextXAlignment.Left
	countdownLabel.TextColor3 = Theme.Colors.TextMuted
	countdownLabel.Text = ""
	countdownLabel.Parent = panel
	self._countdownLabel = countdownLabel

	local questList = Instance.new("Frame")
	questList.Name = "QuestList"
	questList.Size = UDim2.new(1, 0, 0, 0)
	questList.AutomaticSize = Enum.AutomaticSize.Y
	questList.BackgroundTransparency = 1
	questList.LayoutOrder = 3
	questList.Parent = panel
	self._questList = questList

	local questListLayout = Instance.new("UIListLayout")
	questListLayout.FillDirection = Enum.FillDirection.Vertical
	questListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	questListLayout.Padding = UDim.new(0, Theme.Spacing.S)
	questListLayout.Parent = questList

	local bonusLabel = Instance.new("TextLabel")
	bonusLabel.Name = "Bonus"
	bonusLabel.BackgroundTransparency = 1
	bonusLabel.Size = UDim2.new(1, 0, 0, 16)
	bonusLabel.LayoutOrder = 4
	bonusLabel.Font = Theme.Font.Label.Font
	bonusLabel.TextSize = Theme.Font.Label.Size
	bonusLabel.TextXAlignment = Enum.TextXAlignment.Left
	bonusLabel.TextColor3 = Theme.Colors.TextMuted
	bonusLabel.Text = ""
	bonusLabel.Parent = panel
	self._bonusLabel = bonusLabel
end

function DailyQuestsController.Open()
	if isOpen then
		return
	end
	isOpen = true

	local self = DailyQuestsController
	self:_refreshCountdown()
	self._backdrop.Visible = true
	Motion.Tween(self._backdrop, "Fade", Theme.Motion.PanelOpen, { GroupTransparency = 0 })
	Motion.Tween(self._panelScale, "Scale", Theme.Motion.PanelOpen, { Scale = 1 })

	previousSelection = GuiService.SelectedObject
	GamepadNav.FocusFirst(self._panel)
end

function DailyQuestsController.Close()
	if not isOpen then
		return
	end
	isOpen = false

	local self = DailyQuestsController
	local tween = Motion.Tween(self._backdrop, "Fade", Theme.Motion.PanelClose, { GroupTransparency = 1 })
	Motion.Tween(self._panelScale, "Scale", Theme.Motion.PanelClose, { Scale = 0.94 })
	tween.Completed:Once(function()
		if not isOpen then
			self._backdrop.Visible = false
		end
	end)

	GamepadNav.Restore(previousSelection)
end

function DailyQuestsController:Start()
	self._trove:Add(HUDController.DailyQuestsOpenRequested:Connect(function()
		DailyQuestsController.Open()
	end))

	self._trove:Add(Net.GetEvent("DailyQuestsUpdated").OnClientEvent:Connect(function(state: PlayerSessionTypes.DailyQuestState)
		self:_handleUpdate(state)
	end))

	local ok, state = pcall(function()
		return Net.GetFunction("RequestDailyQuests"):InvokeServer()
	end)
	if ok then
		self._lastState = state
		self._hasHydrated = true
		self:_render(state)
	else
		warn("DailyQuestsController: failed to fetch daily quests", state)
		self:_render(nil)
	end

	-- The header countdown is derived, not pushed — refresh it on a slow timer
	-- so a panel left open doesn't sit on a stale "Refreshing in 6 hours".
	task.spawn(function()
		while true do
			task.wait(COUNTDOWN_REFRESH_SECONDS)
			self:_refreshCountdown()
		end
	end)
end

return DailyQuestsController
