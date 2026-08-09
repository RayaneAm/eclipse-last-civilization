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
local BaseActionDialog = require(script.Parent.Parent.UI.Components.BaseActionDialog)
local ItemIcon = require(script.Parent.Parent.UI.Components.ItemIcon)
local EmptyState = require(script.Parent.Parent.UI.Components.EmptyState)

local BasePlacementController = require(script.Parent.BasePlacementController)
local NotificationController = require(script.Parent.NotificationController)

local BaseUIController = {}

local isOpen = false
local previousSelection: GuiObject? = nil
local currentSession: any = nil
local currentPlayerSession: any = nil
local pendingBaseAction = false

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
	MissingPrerequisite = "Build the required settlement structure first",
}

local UPGRADE_REJECTION_MESSAGES: { [string]: string } = {
	CannotAfford = "Not enough materials for this upgrade",
	NoUpgradeAvailable = "This defense is already at its highest tier",
	InvalidUpgradePath = "This upgrade is not valid for this perimeter socket",
	UnknownStructure = "This structure no longer exists",
	BaseNotReady = "Base is not ready yet",
}

local DISTRICT_ACCENTS = {
	Entrance = Color3.fromRGB(196, 158, 91),
	Logistics = Color3.fromRGB(91, 181, 184),
	Production = Color3.fromRGB(203, 137, 67),
	Support = Color3.fromRGB(114, 169, 103),
	Perimeter = Color3.fromRGB(179, 94, 76),
}

local function scrapBalance(): number
	if currentPlayerSession and currentPlayerSession.Currencies then
		return currentPlayerSession.Currencies.Scrap or 0
	end
	return 0
end

local function ownerUserId(instance: Instance): number?
	local cursor: Instance? = instance
	while cursor do
		local value = cursor:GetAttribute("OwnerUserId")
		if typeof(value) == "number" then
			return value
		end
		cursor = cursor.Parent
	end
	return nil
end

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
	local storageUsed = 0
	for _, amount in session.Storage do
		storageUsed += amount
	end
	local builtPads = 0
	local builtIds: { [string]: boolean } = {}
	local structureByPad: { [string]: any } = {}
	for _, structure in session.Structures do
		structureCount += 1
		builtIds[structure.BuildingId] = true
		if structure.PadId then
			builtPads += 1
			structureByPad[structure.PadId] = structure
		end
	end
	local order = 1
	local function heading(text: string, color: Color3)
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, 0, 0, 24)
		label.LayoutOrder = order
		label.Font = Theme.Font.Heading.Font
		label.TextSize = Theme.Font.Heading.Size
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextColor3 = color
		label.Text = string.upper(text)
		label.Parent = scroll
		order += 1
	end
	local function card(text: string, height: number)
		local surface = Surface.new({ Size = UDim2.new(1, 0, 0, height), LayoutOrder = order, Parent = scroll })
		order += 1
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromOffset(12, 7)
		label.Size = UDim2.new(1, -24, 1, -14)
		label.Font = Theme.Font.Body.Font
		label.TextSize = Theme.Font.Body.Size
		label.TextColor3 = Theme.Colors.TextSecondary
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Top
		label.TextWrapped = true
		label.Text = text
		label.Parent = surface
	end

	heading("Settlement Summary", Theme.Colors.BrandLight)
	card(`LEVEL {session.Level}  •  {session.InvestmentScore} INVESTMENT\nSTRUCTURES {structureCount}/{capacity}  •  NODES {builtPads}/{#BlueprintLayoutConfig.All}\nSTORAGE {storageUsed}/{session.StorageCapacity}`, 72)

	local powerCapacity = 0
	local powerUsed = 0
	for structureId, structure in session.Structures do
		if structure.BuildingId == "Generator" then
			powerCapacity = 10 + (structure.Level - 1) * 4
		end
		if session.Power.Enabled[structureId] then
			local definition = BuildingConfig.Get(structure.BuildingId)
			powerUsed += if definition then definition.PowerDraw else 0
		end
	end
	local runningJobs, readyJobs = 0, 0
	for _, job in session.ProductionJobs do
		if not job.Collected then
			if os.time() < job.CompletesAt then
				runningJobs += 1
				local recipe = ProductionRecipeConfig.Get(job.RecipeId)
				powerUsed += if recipe then recipe.PowerDraw else 0
			else
				readyJobs += 1
			end
		end
	end
	heading("Operations", Theme.Colors.Teal)
	card(`POWER {powerUsed}/{powerCapacity}  •  FUEL {session.Power.GeneratorFuel}\nPRODUCTION {runningJobs} RUNNING  •  {readyJobs} READY`, 52)

	heading("Perimeter Defense", Color3.fromRGB(194, 112, 91))
	for _, groupName in { "Front", "Left", "Right", "Back", "Gate" } do
		local socketCount, builtCount, minimumTier = 0, 0, 4
		for _, pad in BlueprintLayoutConfig.All do
			if pad.DefenseGroup == groupName then
				socketCount += 1
				local structure = structureByPad[pad.PadId]
				if structure then
					builtCount += 1
					local definition = BuildingConfig.Get(structure.BuildingId)
					minimumTier = math.min(minimumTier, if definition and definition.DefenseTier then definition.DefenseTier else 1)
				else
					minimumTier = 0
				end
			end
		end
		local row = Surface.new({ Size = UDim2.new(1, 0, 0, 38), LayoutOrder = order, Parent = scroll })
		order += 1
		local rowLabel = Instance.new("TextLabel")
		rowLabel.BackgroundTransparency = 1
		rowLabel.Position = UDim2.fromOffset(12, 0)
		rowLabel.Size = UDim2.new(0.42, 0, 1, 0)
		rowLabel.Font = Theme.Font.Body.Font
		rowLabel.TextSize = Theme.Font.Body.Size
		rowLabel.TextColor3 = Theme.Colors.TextSecondary
		rowLabel.TextXAlignment = Enum.TextXAlignment.Left
		rowLabel.Text = `{string.upper(groupName)}  {builtCount}/{socketCount}`
		rowLabel.Parent = row
		local segments = Instance.new("Frame")
		segments.BackgroundTransparency = 1
		segments.Position = UDim2.new(0.45, 0, 0.5, -5)
		segments.Size = UDim2.new(0.38, 0, 0, 10)
		segments.Parent = row
		local segmentLayout = Instance.new("UIListLayout")
		segmentLayout.FillDirection = Enum.FillDirection.Horizontal
		segmentLayout.Padding = UDim.new(0, 4)
		segmentLayout.Parent = segments
		for tier = 1, 4 do
			local segment = Instance.new("Frame")
			segment.Size = UDim2.new(0.25, -3, 1, 0)
			segment.BackgroundColor3 = if tier <= minimumTier then Color3.fromRGB(194, 112, 91) else Color3.fromRGB(61, 58, 65)
			segment.BorderSizePixel = 0
			segment.Parent = segments
			local corner = Instance.new("UICorner")
			corner.CornerRadius = Theme.Corner.Pill
			corner.Parent = segment
		end
		local tierLabel = Instance.new("TextLabel")
		tierLabel.BackgroundTransparency = 1
		tierLabel.Position = UDim2.new(0.84, 0, 0, 0)
		tierLabel.Size = UDim2.new(0.16, -12, 1, 0)
		tierLabel.Font = Theme.Font.Heading.Font
		tierLabel.TextSize = Theme.Font.Body.Size
		tierLabel.TextColor3 = if minimumTier > 0 then Theme.Colors.TextPrimary else Theme.Colors.Danger
		tierLabel.TextXAlignment = Enum.TextXAlignment.Right
		tierLabel.Text = if minimumTier > 0 then `T{minimumTier}` else "OPEN"
		tierLabel.Parent = row
	end

	local suggestions = {}
	for _, buildingId in { "Storage", "Generator", "ResourceProcessor", "SurvivorQuarters", "DefenseControl" } do
		if not builtIds[buildingId] and #suggestions < 4 then
			local definition = BuildingConfig.Get(buildingId)
			table.insert(suggestions, `Build {if definition then definition.Name else buildingId}`)
		end
	end
	if #suggestions < 4 then
		for _, pad in BlueprintLayoutConfig.All do
			if pad.DefenseGroup and not structureByPad[pad.PadId] then
				table.insert(suggestions, `Close the {string.lower(pad.DefenseGroup)} perimeter`)
				break
			end
		end
	end
	if #suggestions < 4 then
		for _, structure in session.Structures do
			local definition = BuildingConfig.Get(structure.BuildingId)
			if definition and definition.DefenseTier and definition.NextTierBuildingId then
				table.insert(suggestions, `Upgrade {definition.Name} to tier {definition.DefenseTier + 1}`)
				break
			end
		end
	end
	if #suggestions == 0 then
		table.insert(suggestions, "Deposit expedition materials and keep production moving")
	end
	heading("Suggested Next Actions", Theme.Colors.Success)
	for suggestionIndex, suggestion in suggestions do
		if suggestionIndex > 4 then
			break
		end
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, 0, 0, 24)
		label.LayoutOrder = order
		label.Font = Theme.Font.Body.Font
		label.TextSize = Theme.Font.Body.Size
		label.TextColor3 = Theme.Colors.TextSecondary
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Text = `•  {suggestion}`
		label.Parent = scroll
		order += 1
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
	buildRow.LayoutOrder = order
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
			NotificationController.Toast("ObjectiveAdvanced", "Walk to a nearby construction beacon in your base to build")
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
	local depositHeader = Instance.new("TextLabel")
	depositHeader.BackgroundTransparency = 1
	depositHeader.Size = UDim2.new(1, 0, 0, 26)
	depositHeader.LayoutOrder = order
	depositHeader.Font = Theme.Font.Heading.Font
	depositHeader.TextSize = Theme.Font.Heading.Size
	depositHeader.TextXAlignment = Enum.TextXAlignment.Left
	depositHeader.TextColor3 = Theme.Colors.TextPrimary
	depositHeader.Text = "DEPOSIT FROM BACKPACK"
	depositHeader.Parent = scroll
	order += 1
	local carriedCount = 0
	if currentPlayerSession then
		for itemId, amount in currentPlayerSession.Inventory do
			if amount > 0 then
				carriedCount += 1
				buildQuantityRow(scroll, order, tostring(amount), "Deposit", math.min(10, amount), function(quantity)
					local ok, reason = Net.GetFunction("RequestDepositStorage"):InvokeServer({ ItemId = itemId, Amount = quantity })
					if not ok then
						warn(`BaseUIController: deposit failed: {tostring(reason)}`)
					end
				end, itemId)
				order += 1
			end
		end
	end
	if carriedCount == 0 then
		local empty = Instance.new("TextLabel")
		empty.BackgroundTransparency = 1
		empty.Size = UDim2.new(1, 0, 0, 28)
		empty.LayoutOrder = order
		empty.Font = Theme.Font.Body.Font
		empty.TextSize = Theme.Font.Body.Size
		empty.TextXAlignment = Enum.TextXAlignment.Left
		empty.TextColor3 = Theme.Colors.TextSecondary
		empty.Text = "Your backpack has no materials to deposit."
		empty.Parent = scroll
		order += 1
	end
	local storageHeader = depositHeader:Clone()
	storageHeader.LayoutOrder = order
	storageHeader.Text = "BASE STORAGE"
	storageHeader.Parent = scroll
	order += 1
	local storedCount = 0
	for itemId, amount in session.Storage do
		if amount > 0 then
			storedCount += 1
			local reserved = session.Reserved[itemId] or 0
			buildQuantityRow(scroll, order, `{amount} (Reserved {reserved})`, "Withdraw", math.min(10, amount), function(quantity)
				local ok, reason = Net.GetFunction("RequestWithdrawStorage"):InvokeServer({ ItemId = itemId, Amount = quantity })
				if not ok then
					warn(`BaseUIController: withdraw failed: {tostring(reason)}`)
				end
			end, itemId)
			order += 1
		end
	end
	if storedCount == 0 then
		local empty = Instance.new("TextLabel")
		empty.BackgroundTransparency = 1
		empty.Size = UDim2.new(1, 0, 0, 28)
		empty.LayoutOrder = order
		empty.Font = Theme.Font.Body.Font
		empty.TextSize = Theme.Font.Body.Size
		empty.TextXAlignment = Enum.TextXAlignment.Left
		empty.TextColor3 = Theme.Colors.TextSecondary
		empty.Text = "Base Storage is empty. Deposit expedition materials above."
		empty.Parent = scroll
	end
end

-- ---------------------------------------------------------------------
-- Production
-- ---------------------------------------------------------------------

local function recipeSummary(recipe: ProductionRecipeConfig.ProductionRecipe): string
	local itemIds = {}
	for itemId in recipe.Materials do
		table.insert(itemIds, itemId)
	end
	table.sort(itemIds)
	local inputs = {}
	for _, itemId in itemIds do
		table.insert(inputs, `{recipe.Materials[itemId]} {itemId}`)
	end
	if recipe.Scrap > 0 then
		table.insert(inputs, `{recipe.Scrap} Scrap`)
	end
	return `{table.concat(inputs, " + ")}  →  {recipe.OutputQuantity} {recipe.OutputItemId}  •  {recipe.DurationSeconds}s`
end

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
					local row = Surface.new({ Size = UDim2.new(1, 0, 0, 54), LayoutOrder = order, Parent = scroll })
					local label = Instance.new("TextLabel")
					label.BackgroundTransparency = 1
					label.Size = UDim2.fromScale(0.6, 1)
					label.Font = Theme.Font.Body.Font
					label.TextSize = Theme.Font.Body.Size
					label.TextXAlignment = Enum.TextXAlignment.Left
					label.TextColor3 = Theme.Colors.TextSecondary
					label.TextWrapped = true
					label.Text = `{recipe.Name}\n{recipeSummary(recipe)}`
					label.Parent = row
					Button.new({
						Text = "Start",
						Variant = "Primary",
						Size = UDim2.fromOffset(90, 32),
						Position = UDim2.new(1, -90, 0.5, -16),
						OnActivated = function()
							local ok, reason = Net.GetFunction("RequestStartProduction"):InvokeServer({ MachineStructureId = structureId, RecipeId = recipe.Id })
							if not ok then
								local messages = {
									InsufficientMaterials = "Deposit more input materials into Base Storage",
									InsufficientPower = "Build or upgrade power capacity",
									InsufficientScrap = "Not enough Scrap",
									MachineBusy = "This machine is already running",
								}
								NotificationController.Toast("BuildRejected", messages[tostring(reason)] or `Production failed: {tostring(reason)}`)
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
	sizeConstraint.MinSize = Vector2.new(300, 420)
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
	self._currentTab = currentTab
	local tabsScroller = Instance.new("ScrollingFrame")
	tabsScroller.Name = "TabsScroller"
	tabsScroller.Position = UDim2.new(0, 0, 0, 36)
	tabsScroller.Size = UDim2.new(1, 0, 0, 36)
	tabsScroller.BackgroundTransparency = 1
	tabsScroller.BorderSizePixel = 0
	tabsScroller.AutomaticCanvasSize = Enum.AutomaticSize.X
	tabsScroller.CanvasSize = UDim2.new()
	tabsScroller.ScrollBarThickness = 0
	tabsScroller.ScrollingDirection = Enum.ScrollingDirection.X
	tabsScroller.Parent = panel

	local tabStrip, selectTab, tabButtons = TabStrip.new({
		Name = "Tabs",
		Size = UDim2.new(0, 0, 1, 0),
		Tabs = tabDefs,
		InitialTabId = currentTab,
		OnTabSelected = function(tabId: string)
			currentTab = tabId
			self._currentTab = tabId
			local renderer = TAB_RENDERERS[tabId]
			if renderer then
				renderer(scroll, currentSession)
			end
		end,
		Parent = tabsScroller,
	})
	tabStrip.AutomaticSize = Enum.AutomaticSize.X
	self._selectTab = selectTab

	GamepadNav.LinkChain({ closeButton, table.unpack(tabButtons) })
end

function BaseUIController:_refresh()
	local player = Players.LocalPlayer
	local ok, result = pcall(function()
		return Net.GetFunction("RequestBaseState"):InvokeServer(player.UserId)
	end)
	currentSession = if ok and result then result.Session else nil
	local playerOk, playerResult = pcall(function()
		return Net.GetFunction("RequestPlayerSession"):InvokeServer()
	end)
	currentPlayerSession = if playerOk then playerResult else currentPlayerSession
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
	local ownerId = ownerUserId(instance)
	if ownerId and ownerId ~= Players.LocalPlayer.UserId then
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

local function setupProductionMachine(instance: Instance, trove: any)
	if not instance:IsA("BasePart") or ownerUserId(instance) ~= Players.LocalPlayer.UserId then
		return
	end
	local prompt = instance:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		return
	end
	trove:Add(prompt.Triggered:Connect(function()
		BaseUIController:_refresh()
		local structureId = instance:GetAttribute("StructureId")
		if instance:GetAttribute("ProductionState") == "Ready" and typeof(structureId) == "string" and currentSession then
			for _, job in currentSession.ProductionJobs do
				if job.MachineStructureId == structureId and not job.Collected and os.time() >= job.CompletesAt then
					local ok, reason = Net.GetFunction("RequestCollectProduction"):InvokeServer({ JobId = job.Id })
					if ok then
						NotificationController.Toast("BuildConfirmed", "Production collected into Base Storage")
					else
						NotificationController.Toast("BuildRejected", if reason == "StorageFull" then "Base Storage is full" else `Collect failed: {tostring(reason)}`)
					end
					return
				end
			end
		end
		BaseUIController.Open("Production")
	end))
end

-- Phase 4A.1: the primary guided-progression build path — walking up to a
-- pad's ghost and interacting shows a cost preview + confirm, then calls
-- RequestBuildBlueprint(padId) server-side (the pad's transform is fixed
-- and server-authored, so this can never produce OutOfBounds). Mirrors
-- setupTerminal's own tag-listening pattern so newly (re)created ghosts —
-- e.g. PersonalBaseGenerator.RestoreBlueprintPad after a dismantle — are
-- picked up automatically via the InstanceAdded signal below, not just at
-- Start() time.
local setupUpgradeableStructure: (Instance, any) -> ()

local function setupBlueprintPad(instance: Instance, trove: any)
	if not instance:IsA("BasePart") then
		return
	end
	if ownerUserId(instance) ~= Players.LocalPlayer.UserId then
		return
	end
	local prompt = instance:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		return
	end
	trove:Add(prompt.Triggered:Connect(function()
		BaseUIController:_refresh()
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

		BaseActionDialog.Show({
			Title = `Build {definition.Name}`,
			Eyebrow = `{string.upper(pad.District)} BUILD NODE`,
			Description = definition.Description or "Add this structure to your settlement.",
			Detail = "Materials are taken from Base Storage.",
			Cost = definition.Cost,
			Storage = if currentSession then currentSession.Storage else {},
			Scrap = scrapBalance(),
			AccentColor = DISTRICT_ACCENTS[pad.District],
			ConfirmText = "Build",
			OnConfirm = function()
				if pendingBaseAction then
					return
				end
				pendingBaseAction = true
				local ok, reason = Net.GetFunction("RequestBuildBlueprint"):InvokeServer({ PadId = padId })
				pendingBaseAction = false

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

	for _, instance in CollectionService:GetTagged("BaseStorageTerminal") do
		setupTerminal(instance, self._trove, "Storage")
	end
	CollectionService:GetInstanceAddedSignal("BaseStorageTerminal"):Connect(function(instance)
		setupTerminal(instance, self._trove, "Storage")
	end)

	for _, instance in CollectionService:GetTagged("BaseProductionMachine") do
		setupProductionMachine(instance, self._trove)
	end
	CollectionService:GetInstanceAddedSignal("BaseProductionMachine"):Connect(function(instance)
		setupProductionMachine(instance, self._trove)
	end)

	for _, instance in CollectionService:GetTagged("BaseBlueprintPad") do
		setupBlueprintPad(instance, self._trove)
	end
	CollectionService:GetInstanceAddedSignal("BaseBlueprintPad"):Connect(function(instance)
		setupBlueprintPad(instance, self._trove)
	end)

	for _, instance in CollectionService:GetTagged("BaseUpgradeableStructure") do
		setupUpgradeableStructure(instance, self._trove)
	end
	self._trove:Add(CollectionService:GetInstanceAddedSignal("BaseUpgradeableStructure"):Connect(function(instance)
		setupUpgradeableStructure(instance, self._trove)
	end))

	self._trove:Add(Net.GetEvent("BaseStateChanged").OnClientEvent:Connect(function(session: any)
		currentSession = session
		if isOpen then
			local renderer = TAB_RENDERERS[self._currentTab or "Overview"]
			if renderer then
				renderer(self._scroll, currentSession)
			end
		end
	end))

	self._trove:Add(Net.GetEvent("InventoryChanged").OnClientEvent:Connect(function(inventory: { [string]: number })
		if currentPlayerSession then
			currentPlayerSession.Inventory = inventory
		end
		if isOpen and self._currentTab == "Storage" then
			renderStorage(self._scroll, currentSession)
		end
	end))
end

setupUpgradeableStructure = function(instance: Instance, trove: any)
	if not instance:IsA("BasePart") or ownerUserId(instance) ~= Players.LocalPlayer.UserId then
		return
	end
	local prompt = instance:FindFirstChild("UpgradePrompt")
	if not prompt or not prompt:IsA("ProximityPrompt") then
		return
	end
	trove:Add(prompt.Triggered:Connect(function()
		BaseUIController:_refresh()
		local structureId = instance:GetAttribute("StructureId")
		if typeof(structureId) ~= "string" or not currentSession then
			return
		end
		local structure = currentSession.Structures[structureId]
		local currentDefinition = structure and BuildingConfig.Get(structure.BuildingId)
		local nextDefinition = currentDefinition and currentDefinition.NextTierBuildingId and BuildingConfig.Get(currentDefinition.NextTierBuildingId)
		if not structure or not currentDefinition or not nextDefinition then
			NotificationController.Toast("BuildRejected", "This defense is already at its highest tier")
			return
		end
		local currentTier = currentDefinition.DefenseTier or structure.Level
		local nextTier = nextDefinition.DefenseTier or (currentTier + 1)
		BaseActionDialog.Show({
			Title = `Upgrade to {nextDefinition.Name}`,
			Eyebrow = `PERIMETER TIER {currentTier}  →  {nextTier}`,
			Description = currentDefinition.UpgradeSummary or nextDefinition.Description or "Strengthen this structure.",
			Detail = `{currentDefinition.TierLabel or "CURRENT"}  •  {structure.Health}/{BuildingConfig.GetMaxHealth(currentDefinition.Id)} health\n{nextDefinition.TierLabel or "NEXT"}  •  {BuildingConfig.GetMaxHealth(nextDefinition.Id)} max health`,
			Cost = nextDefinition.Cost,
			Storage = currentSession.Storage,
			Scrap = scrapBalance(),
			AccentColor = DISTRICT_ACCENTS.Perimeter,
			ConfirmText = `Upgrade to T{nextTier}`,
			OnConfirm = function()
				if pendingBaseAction then
					return
				end
				pendingBaseAction = true
				local ok, reason = Net.GetFunction("RequestUpgradeBuilding"):InvokeServer({ StructureId = structureId })
				pendingBaseAction = false
				if ok then
					NotificationController.Toast("BuildConfirmed", `{nextDefinition.Name} upgrade complete`)
				else
					local message = UPGRADE_REJECTION_MESSAGES[tostring(reason)]
					NotificationController.Toast("BuildRejected", message or `Upgrade failed: {tostring(reason)}`)
				end
			end,
		})
	end))
end

return BaseUIController
