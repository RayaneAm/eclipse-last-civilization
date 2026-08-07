--!strict
-- Phase 4A: the Base Management panel — Overview/Storage/Production/Power/
-- Trader/Defense Reserve/Permissions tabs, opened via the Civilization
-- Core's or the Trader Terminal's ProximityPrompt (BaseCoreTerminal/
-- BaseTraderTerminal tags, set by PersonalBaseGenerator). Foundation-phase
-- scope: only the LOCAL player's own base (visiting-another-base management
-- UI is a future addition) — see the Phase 4A plan's foundation scoping.
--
-- Building placement itself (ghost preview, grid-snap, rotation) is a
-- separate 3D-world-space system (BasePlacementController), not a tab in
-- this 2D panel — the "Build" tab here just opens that mode and closes this
-- panel, since you need to see the actual plot to place something in it.

local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local Trove = require(ReplicatedStorage.Shared.Modules.Trove)
local BuildingConfig = require(ReplicatedStorage.Shared.Config.BuildingConfig)
local ProductionRecipeConfig = require(ReplicatedStorage.Shared.Config.ProductionRecipeConfig)
local TraderConfig = require(ReplicatedStorage.Shared.Config.TraderConfig)
local DefenseReserveConfig = require(ReplicatedStorage.Shared.Config.DefenseReserveConfig)
local PersonalBaseConfig = require(ReplicatedStorage.Shared.Config.PersonalBaseConfig)
local BlueprintLayoutConfig = require(ReplicatedStorage.Shared.Config.BlueprintLayoutConfig)

local Theme = require(script.Parent.Parent.UI.Theme)
local Motion = require(script.Parent.Parent.UI.Motion)
local GamepadNav = require(script.Parent.Parent.UI.GamepadNav)
local GlassPanel = require(script.Parent.Parent.UI.Components.GlassPanel)
local Surface = require(script.Parent.Parent.UI.Components.Surface)
local Button = require(script.Parent.Parent.UI.Components.Button)
local CloseButton = require(script.Parent.Parent.UI.Components.CloseButton)
local TabStrip = require(script.Parent.Parent.UI.Components.TabStrip)
local ConfirmDialog = require(script.Parent.Parent.UI.Components.ConfirmDialog)
local ItemIcon = require(script.Parent.Parent.UI.Components.ItemIcon)
local EmptyState = require(script.Parent.Parent.UI.Components.EmptyState)

local BasePlacementController = require(script.Parent.BasePlacementController)
local NotificationController = require(script.Parent.NotificationController)

local BaseUIController = {}

local isOpen = false
local previousSelection: GuiObject? = nil
local currentSession: any = nil
local pendingPadBuild = false

-- Maps every EXPECTED RequestBuildBlueprint rejection reason to a player-
-- facing message — mirrors BasePlacementController's own REJECTION_MESSAGES
-- table for the freeform path, just for the pad-build path instead.
local BLUEPRINT_REJECTION_MESSAGES: { [string]: string } = {
	AlreadyBuilt = "This pad has already been built",
	CannotAfford = "Not enough materials",
	BuildingLimitReached = "Base building limit reached",
	UnknownPad = "Unknown blueprint pad",
	UnknownBuilding = "Unknown building type",
	BaseNotReady = "Base is not ready yet",
	ProtectedZone = "This pad is blocked",
	Overlap = "This pad is blocked",
}

local function clearScroll(scroll: ScrollingFrame)
	for _, child in scroll:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
end

local function buildQuantityRow(parent: Instance, layoutOrder: number, labelText: string, buttonText: string, defaultQuantity: number, onSubmit: (quantity: number) -> (), itemId: string?)
	local row = Surface.new({
		Size = UDim2.new(1, 0, 0, 44),
		LayoutOrder = layoutOrder,
		Parent = parent,
	})
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, Theme.Spacing.M)
	padding.PaddingRight = UDim.new(0, Theme.Spacing.M)
	padding.Parent = row

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalFlex = Enum.UIFlexAlignment.SpaceBetween
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = row

	local labelGroup = Instance.new("Frame")
	labelGroup.AutomaticSize = Enum.AutomaticSize.X
	labelGroup.Size = UDim2.new(0, 0, 0, 26)
	labelGroup.BackgroundTransparency = 1
	labelGroup.Parent = row
	local labelGroupLayout = Instance.new("UIListLayout")
	labelGroupLayout.FillDirection = Enum.FillDirection.Horizontal
	labelGroupLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	labelGroupLayout.Padding = UDim.new(0, Theme.Spacing.XS)
	labelGroupLayout.Parent = labelGroup

	if itemId then
		ItemIcon.new({ ItemId = itemId, Size = UDim2.fromOffset(24, 24), LayoutOrder = 1, Parent = labelGroup })
	end

	local label = Instance.new("TextLabel")
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.new(0, 0, 0, 20)
	label.LayoutOrder = 2
	label.BackgroundTransparency = 1
	label.Font = Theme.Font.Body.Font
	label.TextSize = Theme.Font.Body.Size
	label.TextColor3 = Theme.Colors.TextPrimary
	label.Text = labelText
	label.Parent = labelGroup

	local controls = Instance.new("Frame")
	controls.AutomaticSize = Enum.AutomaticSize.X
	controls.Size = UDim2.new(0, 0, 0, 30)
	controls.BackgroundTransparency = 1
	controls.Parent = row
	local controlsLayout = Instance.new("UIListLayout")
	controlsLayout.FillDirection = Enum.FillDirection.Horizontal
	controlsLayout.Padding = UDim.new(0, Theme.Spacing.XS)
	controlsLayout.Parent = controls

	local textBox = Instance.new("TextBox")
	textBox.Size = UDim2.fromOffset(50, 30)
	textBox.BackgroundColor3 = Theme.Colors.PanelBackground
	textBox.BackgroundTransparency = Theme.Transparency.PanelBackground
	textBox.TextColor3 = Theme.Colors.TextPrimary
	textBox.Font = Theme.Font.Body.Font
	textBox.TextSize = Theme.Font.Body.Size
	textBox.Text = tostring(defaultQuantity)
	textBox.ClearTextOnFocus = false
	local boxCorner = Instance.new("UICorner")
	boxCorner.CornerRadius = Theme.Corner.Small
	boxCorner.Parent = textBox
	textBox.Parent = controls

	Button.new({
		Text = buttonText,
		Variant = "Secondary",
		Size = UDim2.fromOffset(90, 30),
		OnActivated = function()
			local quantity = math.max(1, math.floor(tonumber(textBox.Text) or defaultQuantity))
			onSubmit(quantity)
		end,
		Parent = controls,
	})
end

-- ---------------------------------------------------------------------
-- Overview
-- ---------------------------------------------------------------------

local function renderOverview(scroll: ScrollingFrame, session: any)
	clearScroll(scroll)
	if not session then
		return
	end

	local capacity = PersonalBaseConfig.BuildingCapacityForLevel(session.Level)
	local structureCount = 0
	for _ in session.Structures do
		structureCount += 1
	end
	local storageUsed = 0
	for _, amount in session.Storage do
		storageUsed += amount
	end

	local totalPads = #BlueprintLayoutConfig.All
	local builtPads = 0
	for _, structure in session.Structures do
		if structure.PadId then
			builtPads += 1
		end
	end

	local lines = {
		`Base Level: {session.Level}`,
		`Investment Score: {session.InvestmentScore}`,
		`Structures: {structureCount} / {capacity}`,
		`Blueprint Pads: {builtPads} / {totalPads} built`,
		`Storage: {storageUsed} / {session.StorageCapacity}`,
		`Generator Fuel: {session.Power.GeneratorFuel}`,
		"Eclipse Readiness: Foundation only — no assault system active yet.",
	}

	for i, text in lines do
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, 0, 0, 26)
		label.LayoutOrder = i
		label.Font = Theme.Font.Body.Font
		label.TextSize = Theme.Font.Body.Size
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextColor3 = Theme.Colors.TextSecondary
		label.Text = text
		label.Parent = scroll
	end

	-- Phase 4A.1: guided blueprint pads are now the PRIMARY build path —
	-- "Build" closes the panel and points the player at an in-world pad
	-- (walking up to one shows its own cost-preview/confirm, wired in
	-- Start() below) rather than immediately dropping them into freeform
	-- placement mode. Freeform stays available as a clearly secondary,
	-- explicitly-optional action for the one marked Freeform Zone.
	local buildRow = Instance.new("Frame")
	buildRow.AutomaticSize = Enum.AutomaticSize.Y
	buildRow.Size = UDim2.new(1, 0, 0, 0)
	buildRow.LayoutOrder = #lines + 1
	buildRow.BackgroundTransparency = 1
	buildRow.Parent = scroll

	local buildRowLayout = Instance.new("UIListLayout")
	buildRowLayout.FillDirection = Enum.FillDirection.Horizontal
	buildRowLayout.Padding = UDim.new(0, Theme.Spacing.S)
	buildRowLayout.Parent = buildRow

	Button.new({
		Text = "Build",
		Variant = "Primary",
		Size = UDim2.new(0.65, 0, 0, 40),
		LayoutOrder = 1,
		OnActivated = function()
			BaseUIController.Close()
			NotificationController.Toast("ObjectiveAdvanced", "Walk to a glowing blueprint pad in your base to build it")
		end,
		Parent = buildRow,
	})

	Button.new({
		Text = "Freeform (Optional)",
		Variant = "Secondary",
		Size = UDim2.new(0.35, 0, 0, 40),
		LayoutOrder = 2,
		OnActivated = function()
			BaseUIController.Close()
			BasePlacementController.EnterBuildMode()
		end,
		Parent = buildRow,
	})
end

-- ---------------------------------------------------------------------
-- Storage
-- ---------------------------------------------------------------------

local function renderStorage(scroll: ScrollingFrame, session: any)
	clearScroll(scroll)
	if not session then
		return
	end
	local order = 1
	for itemId, amount in session.Storage do
		local reserved = session.Reserved[itemId] or 0
		buildQuantityRow(scroll, order, `{amount} (Reserved {reserved})`, "Withdraw", math.min(10, amount), function(quantity)
			local ok, reason = Net.GetFunction("RequestWithdrawStorage"):InvokeServer({ ItemId = itemId, Amount = quantity })
			if not ok then
				warn(`BaseUIController: withdraw failed: {tostring(reason)}`)
			end
		end, itemId)
		order += 1
	end
	if order == 1 then
		EmptyState.new({ Icon = "📦", Text = "Storage is empty", Parent = scroll })
	end
end

-- ---------------------------------------------------------------------
-- Production
-- ---------------------------------------------------------------------

local function renderProduction(scroll: ScrollingFrame, session: any)
	clearScroll(scroll)
	if not session then
		return
	end
	local order = 1

	for structureId, structure in session.Structures do
		local definition = BuildingConfig.Get(structure.BuildingId)
		if definition and definition.Category == "Production" then
			local activeJob = nil
			for _, job in session.ProductionJobs do
				if job.MachineStructureId == structureId and not job.Collected then
					activeJob = job
					break
				end
			end

			if activeJob then
				local remaining = math.max(0, activeJob.CompletesAt - os.time())
				local row = Surface.new({ Size = UDim2.new(1, 0, 0, 40), LayoutOrder = order, Parent = scroll })
				local label = Instance.new("TextLabel")
				label.BackgroundTransparency = 1
				label.Size = UDim2.fromScale(0.6, 1)
				label.Font = Theme.Font.Body.Font
				label.TextSize = Theme.Font.Body.Size
				label.TextXAlignment = Enum.TextXAlignment.Left
				label.TextColor3 = Theme.Colors.TextSecondary
				label.Text = if remaining > 0 then `{activeJob.RecipeId}: {remaining}s remaining` else `{activeJob.RecipeId}: ready to collect`
				label.Parent = row
				Button.new({
					Text = if remaining > 0 then "Cancel" else "Collect",
					Variant = if remaining > 0 then "Danger" else "Primary",
					Size = UDim2.fromOffset(110, 32),
					Position = UDim2.new(1, -110, 0.5, -16),
					AnchorPoint = Vector2.new(0, 0),
					OnActivated = function()
						if remaining > 0 then
							Net.GetFunction("RequestCancelProduction"):InvokeServer({ JobId = activeJob.Id })
						else
							Net.GetFunction("RequestCollectProduction"):InvokeServer({ JobId = activeJob.Id })
						end
					end,
					Parent = row,
				})
				order += 1
			else
				for _, recipe in ProductionRecipeConfig.ForMachine(structure.BuildingId) do
					local row = Surface.new({ Size = UDim2.new(1, 0, 0, 40), LayoutOrder = order, Parent = scroll })
					local label = Instance.new("TextLabel")
					label.BackgroundTransparency = 1
					label.Size = UDim2.fromScale(0.6, 1)
					label.Font = Theme.Font.Body.Font
					label.TextSize = Theme.Font.Body.Size
					label.TextXAlignment = Enum.TextXAlignment.Left
					label.TextColor3 = Theme.Colors.TextSecondary
					label.Text = `{recipe.Name} (◆{recipe.Scrap}, {recipe.DurationSeconds}s)`
					label.Parent = row
					Button.new({
						Text = "Start",
						Variant = "Primary",
						Size = UDim2.fromOffset(90, 32),
						Position = UDim2.new(1, -90, 0.5, -16),
						OnActivated = function()
							local ok, reason = Net.GetFunction("RequestStartProduction"):InvokeServer({ MachineStructureId = structureId, RecipeId = recipe.Id })
							if not ok then
								warn(`BaseUIController: start production failed: {tostring(reason)}`)
							end
						end,
						Parent = row,
					})
					order += 1
				end
			end
		end
	end

	if order == 1 then
		EmptyState.new({ Icon = "⚙", Text = "No production yet", Subtext = "Build a Resource Processor to start production.", Parent = scroll })
	end
end

-- ---------------------------------------------------------------------
-- Power
-- ---------------------------------------------------------------------

local function renderPower(scroll: ScrollingFrame, session: any)
	clearScroll(scroll)
	if not session then
		return
	end
	local order = 1
	for structureId, structure in session.Structures do
		local definition = BuildingConfig.Get(structure.BuildingId)
		if definition and definition.PowerDraw > 0 then
			local enabled = session.Power.Enabled[structureId] == true
			local row = Surface.new({ Size = UDim2.new(1, 0, 0, 40), LayoutOrder = order, Parent = scroll })
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Size = UDim2.fromScale(0.6, 1)
			label.Font = Theme.Font.Body.Font
			label.TextSize = Theme.Font.Body.Size
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.TextColor3 = Theme.Colors.TextSecondary
			label.Text = `{definition.Name} — {definition.PowerDraw} power`
			label.Parent = row
			Button.new({
				Text = if enabled then "Disable" else "Enable",
				Variant = if enabled then "Danger" else "Primary",
				Size = UDim2.fromOffset(100, 32),
				Position = UDim2.new(1, -100, 0.5, -16),
				OnActivated = function()
					local ok, reason = Net.GetFunction("RequestSetPowerEnabled"):InvokeServer({ StructureId = structureId, Enabled = not enabled })
					if not ok then
						warn(`BaseUIController: power toggle failed: {tostring(reason)}`)
					end
				end,
				Parent = row,
			})
			order += 1
		end
	end
	if order == 1 then
		EmptyState.new({ Icon = "⚡", Text = "No powered structures yet", Parent = scroll })
	end
end

-- ---------------------------------------------------------------------
-- Trader
-- ---------------------------------------------------------------------

local function renderTrader(scroll: ScrollingFrame)
	clearScroll(scroll)
	local order = 1

	Button.new({
		Text = "Sell Junk",
		Variant = "Secondary",
		Size = UDim2.new(1, 0, 0, 34),
		LayoutOrder = order,
		OnActivated = function()
			Net.GetFunction("RequestTraderSellJunk"):InvokeServer()
		end,
		Parent = scroll,
	})
	order += 1

	for itemId, entry in TraderConfig.All do
		buildQuantityRow(scroll, order, `Sell ◆{entry.SellPrice} / Buy ◆{entry.BuyPrice}`, "Sell", 1, function(quantity)
			local ok, reasonOrPayout, extra = Net.GetFunction("RequestTraderSell"):InvokeServer({ ItemId = itemId, Amount = quantity })
			if not ok and reasonOrPayout == "BelowReserve" and extra then
				ConfirmDialog.Show({
					Title = "Sell Below Reserve",
					Message = `{itemId} is reserved for base upgrades. Selling this amount will leave you with {extra.Remaining} / {extra.Reserved}. Sell anyway?`,
					ConfirmText = "Sell Anyway",
					Danger = true,
					OnConfirm = function()
						Net.GetFunction("RequestTraderSell"):InvokeServer({ ItemId = itemId, Amount = quantity, ConfirmOverride = true })
					end,
				})
			elseif not ok then
				warn(`BaseUIController: sell failed: {tostring(reasonOrPayout)}`)
			end
		end, itemId)
		order += 1
	end
end

-- ---------------------------------------------------------------------
-- Defense Reserve
-- ---------------------------------------------------------------------

local function renderDefenseReserve(scroll: ScrollingFrame, session: any)
	clearScroll(scroll)
	if not session then
		return
	end
	local order = 1
	for _, item in DefenseReserveConfig.ApprovedItems do
		local reserved = session.DefenseReserve[item.ItemId] or 0
		local inStorage = session.Storage[item.ItemId] or 0
		buildQuantityRow(scroll, order, `{item.Name} — Reserve: {reserved} (Storage: {inStorage})`, "Allocate", math.min(10, inStorage), function(quantity)
			local ok, reason = Net.GetFunction("RequestAllocateDefenseReserve"):InvokeServer({ ItemId = item.ItemId, Amount = quantity })
			if not ok then
				warn(`BaseUIController: allocate failed: {tostring(reason)}`)
			end
		end, item.ItemId)
		order += 1
	end
end

-- ---------------------------------------------------------------------
-- Panel shell
-- ---------------------------------------------------------------------

local TAB_RENDERERS = {
	Overview = renderOverview,
	Storage = renderStorage,
	Production = renderProduction,
	Power = renderPower,
	Trader = function(scroll: ScrollingFrame, _session: any)
		renderTrader(scroll)
	end,
	DefenseReserve = renderDefenseReserve,
}

function BaseUIController:_buildPanel()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "BaseUI"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = playerGui
	self._trove:Add(screenGui)

	local backdrop = Instance.new("CanvasGroup")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 1
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
		BaseUIController.Close()
	end))

	local panel = GlassPanel.new({
		Name = "Panel",
		Size = UDim2.new(0.75, 0, 0.8, 0),
		Position = UDim2.fromScale(0.5, 0.46),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = backdrop,
	})
	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = Vector2.new(380, 460)
	sizeConstraint.MaxSize = Vector2.new(600, 640)
	sizeConstraint.Parent = panel
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

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -52, 0, 28)
	title.Font = Theme.Font.Title.Font
	title.TextSize = Theme.Font.Title.Size
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Theme.Colors.TextPrimary
	title.Text = "BASE MANAGEMENT"
	title.Parent = panel

	local closeButton = CloseButton.new({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		OnActivated = function()
			BaseUIController.Close()
		end,
		Parent = panel,
	})

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "TabContent"
	scroll.Size = UDim2.new(1, 0, 1, -80)
	scroll.Position = UDim2.new(0, 0, 0, 80)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = 6
	scroll.Parent = panel
	self._scroll = scroll

	local scrollLayout = Instance.new("UIListLayout")
	scrollLayout.Padding = UDim.new(0, Theme.Spacing.S)
	scrollLayout.Parent = scroll

	local currentTab = "Overview"
	local tabDefs = { { Id = "Overview", Label = "Overview" }, { Id = "Storage", Label = "Storage" }, { Id = "Production", Label = "Production" }, { Id = "Power", Label = "Power" }, { Id = "Trader", Label = "Trader" }, { Id = "DefenseReserve", Label = "Defense" } }

	local _tabStrip, selectTab, tabButtons = TabStrip.new({
		Name = "Tabs",
		Position = UDim2.new(0, 0, 0, 36),
		Size = UDim2.new(1, 0, 0, 36),
		Tabs = tabDefs,
		InitialTabId = currentTab,
		OnTabSelected = function(tabId: string)
			currentTab = tabId
			local renderer = TAB_RENDERERS[tabId]
			if renderer then
				renderer(scroll, currentSession)
			end
		end,
		Parent = panel,
	})
	self._selectTab = selectTab

	GamepadNav.LinkChain({ closeButton, table.unpack(tabButtons) })
end

function BaseUIController:_refresh()
	local player = Players.LocalPlayer
	local ok, result = pcall(function()
		return Net.GetFunction("RequestBaseState"):InvokeServer(player.UserId)
	end)
	currentSession = if ok and result then result.Session else nil
end

function BaseUIController:Init()
	self._trove = Trove.new()
	self:_buildPanel()
end

function BaseUIController.Open(initialTab: string?)
	if isOpen then
		return
	end
	isOpen = true

	local self = BaseUIController
	self:_refresh()
	if initialTab then
		self._selectTab(initialTab)
	else
		self._selectTab("Overview")
	end

	self._backdrop.Visible = true
	Motion.Tween(self._backdrop, "Fade", Theme.Motion.PanelOpen, { GroupTransparency = 0 })
	Motion.Tween(self._panelScale, "Scale", Theme.Motion.PanelOpen, { Scale = 1 })

	previousSelection = GuiService.SelectedObject
	GamepadNav.FocusFirst(self._panel)
end

function BaseUIController.Close()
	if not isOpen then
		return
	end
	isOpen = false

	local self = BaseUIController
	local tween = Motion.Tween(self._backdrop, "Fade", Theme.Motion.PanelClose, { GroupTransparency = 1 })
	Motion.Tween(self._panelScale, "Scale", Theme.Motion.PanelClose, { Scale = 0.94 })
	tween.Completed:Once(function()
		if not isOpen then
			self._backdrop.Visible = false
		end
	end)
	GamepadNav.Restore(previousSelection)
end

local function setupTerminal(instance: Instance, trove: any, initialTab: string)
	if not instance:IsA("BasePart") then
		return
	end
	local prompt = instance:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		return
	end
	trove:Add(prompt.Triggered:Connect(function()
		BaseUIController.Open(initialTab)
	end))
end

-- Builds a plain-text cost breakdown ("◆ 40 Scrap", "Stone x20") for the
-- ConfirmDialog cost preview — ConfirmDialog is text-only (Title/Message),
-- so this stays consistent with every other confirmation in the project
-- rather than extending that shared component just for this one caller.
local function costPreviewText(cost: BuildingConfig.BuildingCost): string
	local parts = {}
	if cost.Scrap > 0 then
		table.insert(parts, `◆ {cost.Scrap} Scrap`)
	end
	for itemId, amount in cost.Materials do
		table.insert(parts, `{itemId} x{amount}`)
	end
	if #parts == 0 then
		return "No cost."
	end
	return table.concat(parts, "\n")
end

-- Phase 4A.1: the primary guided-progression build path — walking up to a
-- pad's ghost and interacting shows a cost preview + confirm, then calls
-- RequestBuildBlueprint(padId) server-side (the pad's transform is fixed
-- and server-authored, so this can never produce OutOfBounds). Mirrors
-- setupTerminal's own tag-listening pattern so newly (re)created ghosts —
-- e.g. PersonalBaseGenerator.RestoreBlueprintPad after a dismantle — are
-- picked up automatically via the InstanceAdded signal below, not just at
-- Start() time.
local function setupBlueprintPad(instance: Instance, trove: any)
	if not instance:IsA("BasePart") then
		return
	end
	local prompt = instance:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		return
	end
	trove:Add(prompt.Triggered:Connect(function()
		local padId = instance:GetAttribute("PadId")
		if typeof(padId) ~= "string" then
			return
		end
		local pad = BlueprintLayoutConfig.Get(padId)
		if not pad then
			return
		end
		local definition = BuildingConfig.Get(pad.BuildingId)
		if not definition then
			return
		end

		ConfirmDialog.Show({
			Title = `Build {definition.Name}`,
			Message = `Cost:\n{costPreviewText(definition.Cost)}`,
			ConfirmText = "Build",
			OnConfirm = function()
				if pendingPadBuild then
					return
				end
				pendingPadBuild = true
				local ok, reason = Net.GetFunction("RequestBuildBlueprint"):InvokeServer({ PadId = padId })
				pendingPadBuild = false

				if ok then
					NotificationController.Toast("BuildConfirmed", `{definition.Name} built`)
				else
					local message = BLUEPRINT_REJECTION_MESSAGES[tostring(reason)]
					NotificationController.Toast("BuildRejected", message or `Build failed: {tostring(reason)}`)
				end
			end,
		})
	end))
end

function BaseUIController:Start()
	for _, instance in CollectionService:GetTagged("BaseCoreTerminal") do
		setupTerminal(instance, self._trove, "Overview")
	end
	CollectionService:GetInstanceAddedSignal("BaseCoreTerminal"):Connect(function(instance)
		setupTerminal(instance, self._trove, "Overview")
	end)

	for _, instance in CollectionService:GetTagged("BaseTraderTerminal") do
		setupTerminal(instance, self._trove, "Trader")
	end
	CollectionService:GetInstanceAddedSignal("BaseTraderTerminal"):Connect(function(instance)
		setupTerminal(instance, self._trove, "Trader")
	end)

	for _, instance in CollectionService:GetTagged("BaseBlueprintPad") do
		setupBlueprintPad(instance, self._trove)
	end
	CollectionService:GetInstanceAddedSignal("BaseBlueprintPad"):Connect(function(instance)
		setupBlueprintPad(instance, self._trove)
	end)

	self._trove:Add(Net.GetEvent("BaseStateChanged").OnClientEvent:Connect(function(session: any)
		currentSession = session
		if isOpen then
			-- Re-render whichever tab is active with fresh data.
			local activeTabId = "Overview"
			for _, child in self._panel:FindFirstChild("Tabs"):GetChildren() do
				if child:IsA("TextButton") then
					local underline = child:FindFirstChild("Underline")
					if underline and (underline :: Frame).BackgroundTransparency == 0 then
						activeTabId = child.Name
					end
				end
			end
			local renderer = TAB_RENDERERS[activeTabId]
			if renderer then
				renderer(self._scroll, currentSession)
			end
		end
	end))
end

return BaseUIController
