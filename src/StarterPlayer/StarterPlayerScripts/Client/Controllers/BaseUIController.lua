--!strict
-- BASE MANAGEMENT — the central strategic screen, opened from the
-- Civilization Core's ProximityPrompt (BaseCoreTerminal tag).
--
-- This is the "how is my settlement doing" view, not the place you perform
-- every base action. Each individual facility now has its own focused screen
-- (Production at the processor, Storage at the crate, Power at the
-- generator, Defense at the control mast, Upgrades at the workbench, Trade
-- at the terminal), and this screen summarizes them and routes to them via
-- FacilityRouter. That split is why the old single 6-tab panel — which tried
-- to be every base UI at once and rendered raw text rows for all of them —
-- is gone.
--
-- Everything shown here is derived from real replicated session state
-- (BaseSessionController). Nothing on this screen is illustrative.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage.Shared.Modules.Trove)
local BuildingConfig = require(ReplicatedStorage.Shared.Config.BuildingConfig)
local BlueprintLayoutConfig = require(ReplicatedStorage.Shared.Config.BlueprintLayoutConfig)
local PersonalBaseConfig = require(ReplicatedStorage.Shared.Config.PersonalBaseConfig)
local ProductionRecipeConfig = require(ReplicatedStorage.Shared.Config.ProductionRecipeConfig)

local Theme = require(script.Parent.Parent.UI.Theme)
local FacilityStyle = require(script.Parent.Parent.UI.FacilityStyle)
local FacilityRouter = require(script.Parent.Parent.UI.FacilityRouter)
local FacilityPrompts = require(script.Parent.Parent.UI.FacilityPrompts)
local FacilityModal = require(script.Parent.Parent.UI.Components.FacilityModal)
local FacilityCard = require(script.Parent.Parent.UI.Components.FacilityCard)
local SectionHeader = require(script.Parent.Parent.UI.Components.SectionHeader)
local MeterRow = require(script.Parent.Parent.UI.Components.MeterRow)
local StatusChip = require(script.Parent.Parent.UI.Components.StatusChip)
local TierPips = require(script.Parent.Parent.UI.Components.TierPips)
local RecommendationRow = require(script.Parent.Parent.UI.Components.RecommendationRow)
local EmptyState = require(script.Parent.Parent.UI.Components.EmptyState)
local Button = require(script.Parent.Parent.UI.Components.Button)
local ItemIcon = require(script.Parent.Parent.UI.Components.ItemIcon)

local BaseSessionController = require(script.Parent.BaseSessionController)
local NotificationController = require(script.Parent.NotificationController)
local BasePlacementController = require(script.Parent.BasePlacementController)

local BaseUIController = {}

local IDENTITY = FacilityStyle.Facilities.BaseManagement

local TABS = {
	{ Id = "Overview", Label = "OVERVIEW" },
	{ Id = "Production", Label = "PRODUCTION" },
	{ Id = "Defense", Label = "DEFENSE" },
	{ Id = "Power", Label = "POWER" },
	{ Id = "Storage", Label = "STORAGE" },
}

local modal: FacilityModal.FacilityModal? = nil
local currentTab = "Overview"

-- ---------------------------------------------------------------------
-- Shared render helpers
-- ---------------------------------------------------------------------

local function order(): () -> number
	local next = 0
	return function()
		next += 1
		return next
	end
end

-- A "go to the real screen" button, only rendered when that screen actually
-- registered itself. A dead link is worse than no link.
local function routeButton(parent: Instance, routeId: string, text: string, accent: Color3, layoutOrder: number)
	if not FacilityRouter.Has(routeId) then
		return
	end
	Button.new({
		Text = text,
		Variant = "Secondary",
		AccentColor = accent,
		Size = UDim2.new(1, 0, 0, 38),
		LayoutOrder = layoutOrder,
		OnActivated = function()
			FacilityRouter.Open(routeId)
		end,
		Parent = parent,
	})
end

-- ---------------------------------------------------------------------
-- Suggestions
-- ---------------------------------------------------------------------

type Suggestion = { Glyph: string, Title: string, Detail: string?, Accent: Color3?, Route: string? }

-- At most four, ordered by how much they actually matter right now. These
-- are advice, never objectives — nothing tracks or rewards completing one.
local function buildSuggestions(): { Suggestion }
	local suggestions: { Suggestion } = {}
	local session = BaseSessionController.GetSession()
	if not session then
		return suggestions
	end

	local function add(suggestion: Suggestion)
		if #suggestions < 4 then
			table.insert(suggestions, suggestion)
		end
	end

	-- 1. Anything ready to collect is free value sitting idle.
	local production = BaseSessionController.GetProductionSummary()
	if production.Ready > 0 then
		add({
			Glyph = "Production",
			Title = `{production.Ready} production job{if production.Ready == 1 then "" else "s"} ready`,
			Detail = "Collect the output into Base Storage",
			Accent = FacilityStyle.Accents.Production,
			Route = "Production",
		})
	end

	-- 2. An open perimeter socket is the largest single defensive gap.
	for _, group in BaseSessionController.GetDefenseSummary() do
		if group.Built < group.Sockets then
			add({
				Glyph = "Defense",
				Title = `Close the {string.lower(group.Group)} perimeter`,
				Detail = `{group.Built} / {group.Sockets} sockets built`,
				Accent = FacilityStyle.Accents.Defense,
				Route = "Defense",
			})
			break
		end
	end

	-- 3. Storage nearly full stalls both collecting and depositing.
	local storage = BaseSessionController.GetStorageSummary()
	if storage.Capacity > 0 and storage.Used / storage.Capacity >= 0.85 then
		add({
			Glyph = "Storage",
			Title = "Storage almost full",
			Detail = `{storage.Used} / {storage.Capacity}`,
			Accent = FacilityStyle.Accents.Storage,
			Route = "Storage",
		})
	end

	-- 4. An idle machine with a recipe it can already afford.
	if production.IdleMachines > 0 then
		add({
			Glyph = "Production",
			Title = "Processor idle",
			Detail = "Start a production job",
			Accent = FacilityStyle.Accents.Production,
			Route = "Production",
		})
	end

	-- 5. The best affordable upgrade.
	local candidates = BaseSessionController.GetUpgradeCandidates()
	local best = candidates[1]
	if best and best.Affordable then
		add({
			Glyph = "Upgrade",
			Title = `Upgrade {best.Current.Name}`,
			Detail = `{best.Current.TierLabel or "CURRENT"} → {best.Next.TierLabel or "NEXT"}`,
			Accent = FacilityStyle.Accents.UpgradeStation,
			Route = "UpgradeStation",
		})
	end

	-- 6. Core structures that simply aren't built yet.
	for _, buildingId in { "Storage", "Generator", "ResourceProcessor", "DefenseControl", "SurvivorQuarters" } do
		if #suggestions >= 4 then
			break
		end
		if not BaseSessionController.HasBuilding(buildingId) then
			local definition = BuildingConfig.Get(buildingId)
			add({
				Glyph = "Build",
				Title = `Build {if definition then definition.Name else buildingId}`,
				Detail = "Find its construction beacon in your base",
				Accent = FacilityStyle.Accents.Build,
			})
		end
	end

	return suggestions
end

-- ---------------------------------------------------------------------
-- Tab: Overview
-- ---------------------------------------------------------------------

local function renderOverview(content: GuiObject)
	local session = BaseSessionController.GetSession()
	local nextOrder = order()

	if not session then
		EmptyState.new({
			Glyph = "Base",
			Text = "Base not ready",
			Subtext = "Your settlement is still loading.",
			Card = true,
			LayoutOrder = nextOrder(),
			Parent = content,
		})
		return
	end

	local capacity = PersonalBaseConfig.BuildingCapacityForLevel(session.Level)
	local structureCount = 0
	local builtPads = 0
	for _, structure in session.Structures do
		structureCount += 1
		if structure.PadId then
			builtPads += 1
		end
	end
	local totalPads = #BlueprintLayoutConfig.All

	-- SETTLEMENT: how much of the authored settlement actually exists.
	SectionHeader.new({
		Text = "Settlement",
		Value = `LEVEL {session.Level}`,
		Accent = IDENTITY.Accent,
		LayoutOrder = nextOrder(),
		Parent = content,
	})

	local _settlementCard, settlementContent = FacilityCard.new({
		Name = "Settlement",
		LayoutOrder = nextOrder(),
		Parent = content,
	})

	FacilityCard.Text({
		Text = `{structureCount} / {capacity} structures · {session.InvestmentScore} investment`,
		Color = Theme.Colors.TextMuted,
		LayoutOrder = 1,
		Parent = settlementContent,
	})
	MeterRow.new({
		Label = "Construction",
		Value = `{builtPads} / {totalPads} nodes`,
		Progress = if totalPads > 0 then builtPads / totalPads else 0,
		Accent = IDENTITY.Accent,
		Info = "How many of your base's authored construction nodes are built.",
		LayoutOrder = 2,
		Parent = settlementContent,
	})

	-- OPERATIONS: power, storage and production in one glanceable block.
	local power = BaseSessionController.GetPowerSummary()
	local storage = BaseSessionController.GetStorageSummary()
	local production = BaseSessionController.GetProductionSummary()

	SectionHeader.new({
		Text = "Operations",
		Accent = FacilityStyle.Accents.Production,
		LayoutOrder = nextOrder(),
		Parent = content,
	})

	local _opsCard, opsContent = FacilityCard.new({
		Name = "Operations",
		LayoutOrder = nextOrder(),
		Parent = content,
	})

	MeterRow.new({
		Label = "Power",
		Value = if power.HasGenerator then `{power.Used} / {power.Capacity}` else "No generator",
		Progress = if power.Capacity > 0 then power.Used / power.Capacity else 0,
		Accent = FacilityStyle.Accents.Generator,
		ValueColor = if not power.HasGenerator then Theme.Colors.TextMuted
			elseif power.Used > power.Capacity then Theme.Colors.Danger
			else Theme.Colors.TextPrimary,
		Info = "Power your generator supplies versus what your enabled machines draw.",
		LayoutOrder = 1,
		Parent = opsContent,
	})

	MeterRow.new({
		Label = "Storage",
		Value = `{storage.Used} / {storage.Capacity}`,
		Progress = if storage.Capacity > 0 then storage.Used / storage.Capacity else 0,
		Accent = FacilityStyle.Accents.Storage,
		LayoutOrder = 2,
		Parent = opsContent,
	})

	local productionRow = Instance.new("Frame")
	productionRow.Name = "ProductionRow"
	productionRow.Size = UDim2.new(1, 0, 0, 30)
	productionRow.LayoutOrder = 3
	productionRow.BackgroundTransparency = 1
	productionRow.Parent = opsContent

	local productionLabel = Instance.new("TextLabel")
	productionLabel.Size = UDim2.new(0.5, 0, 1, 0)
	productionLabel.BackgroundTransparency = 1
	productionLabel.Font = Theme.Font.Label.Font
	productionLabel.TextSize = Theme.Font.Label.Size
	productionLabel.TextXAlignment = Enum.TextXAlignment.Left
	productionLabel.TextColor3 = Theme.Colors.TextSecondary
	productionLabel.Text = "PRODUCTION"
	productionLabel.Parent = productionRow

	if production.Machines == 0 then
		local none = productionLabel:Clone()
		none.AnchorPoint = Vector2.new(1, 0)
		none.Position = UDim2.fromScale(1, 0)
		none.TextXAlignment = Enum.TextXAlignment.Right
		none.TextColor3 = Theme.Colors.TextMuted
		none.Text = "NO MACHINES"
		none.Parent = productionRow
	else
		StatusChip.new({
			Status = if production.Ready > 0 then "Ready" elseif production.Running > 0 then "Running" else "Idle",
			Text = if production.Ready > 0 then `{production.Ready} READY`
				elseif production.Running > 0 then `{production.Running} RUNNING`
				else "IDLE",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Parent = productionRow,
		})
	end

	-- DEFENSE: the compact perimeter readout.
	local defense = BaseSessionController.GetDefenseSummary()
	if #defense > 0 then
		SectionHeader.new({ Text = "Defense", Accent = FacilityStyle.Accents.Defense, LayoutOrder = nextOrder(), Parent = content })

		local _defenseCard, defenseContent = FacilityCard.new({
			Name = "Defense",
			Spacing = Theme.Spacing.XS,
			LayoutOrder = nextOrder(),
			Parent = content,
		})

		for index, group in defense do
			local detail: string?
			local detailColor: Color3? = nil
			if group.Built < group.Sockets then
				detail = `{group.Built} / {group.Sockets} sockets built`
				detailColor = Theme.Colors.Danger
			elseif group.MaxHealth > 0 and group.Health < group.MaxHealth then
				detail = `HP {group.Health} / {group.MaxHealth}`
				detailColor = Theme.Colors.Warning
			end

			TierPips.Row({
				Name = `{group.Group} Wall`,
				Tier = group.Tier,
				Detail = detail,
				DetailColor = detailColor,
				LayoutOrder = index,
				Parent = defenseContent,
			})
		end

		routeButton(content, "Defense", "Open Defense Control", FacilityStyle.Accents.Defense, nextOrder())
	end

	-- SUGGESTED
	local suggestions = buildSuggestions()
	if #suggestions > 0 then
		SectionHeader.new({
			Text = "Suggested",
			Accent = Theme.Colors.Success,
			Info = "Ideas for what to do next. These are suggestions, not objectives — nothing expires and nothing is missed by ignoring them.",
			LayoutOrder = nextOrder(),
			Parent = content,
		})
		for _, suggestion in suggestions do
			local route = suggestion.Route
			RecommendationRow.new({
				Glyph = suggestion.Glyph,
				Title = suggestion.Title,
				Detail = suggestion.Detail,
				Accent = suggestion.Accent,
				LayoutOrder = nextOrder(),
				OnActivated = if route and FacilityRouter.Has(route)
					then function()
						FacilityRouter.Open(route)
					end
					else nil,
				Parent = content,
			})
		end
	end

	-- BUILD: guided pads are the primary path; freeform stays clearly optional.
	SectionHeader.new({ Text = "Build", Accent = FacilityStyle.Accents.Build, LayoutOrder = nextOrder(), Parent = content })

	local buildRow = Instance.new("Frame")
	buildRow.Name = "BuildActions"
	buildRow.Size = UDim2.new(1, 0, 0, 42)
	buildRow.LayoutOrder = nextOrder()
	buildRow.BackgroundTransparency = 1
	buildRow.Parent = content

	local buildLayout = Instance.new("UIListLayout")
	buildLayout.FillDirection = Enum.FillDirection.Horizontal
	buildLayout.Padding = UDim.new(0, Theme.Spacing.S)
	buildLayout.Parent = buildRow

	Button.new({
		Text = "Find a Build Node",
		Variant = "Primary",
		AccentColor = FacilityStyle.Accents.Build,
		Size = UDim2.new(0.62, 0, 1, 0),
		LayoutOrder = 1,
		OnActivated = function()
			BaseUIController.Close()
			NotificationController.Toast("ObjectiveAdvanced", "Walk to a construction beacon in your base to build")
		end,
		Parent = buildRow,
	})
	Button.new({
		Text = "Freeform",
		Variant = "Secondary",
		Size = UDim2.new(0.38, 0, 1, 0),
		LayoutOrder = 2,
		OnActivated = function()
			BaseUIController.Close()
			BasePlacementController.EnterBuildMode()
		end,
		Parent = buildRow,
	})
end

-- ---------------------------------------------------------------------
-- Tab: Production
-- ---------------------------------------------------------------------

local function renderProduction(content: GuiObject)
	local session = BaseSessionController.GetSession()
	local nextOrder = order()
	local now = os.time()
	local machineCount = 0

	if session then
		for structureId, structure in session.Structures do
			local definition = BuildingConfig.Get(structure.BuildingId)
			if not definition or definition.Category ~= "Production" then
				continue
			end
			machineCount += 1

			local job = BaseSessionController.GetActiveJob(structureId)
			local _card, cardContent = FacilityCard.new({
				Name = `Machine_{structureId}`,
				Accent = FacilityStyle.Accents.Production,
				LayoutOrder = nextOrder(),
				Parent = content,
			})

			if job then
				local recipe = ProductionRecipeConfig.Get(job.RecipeId)
				local remaining = math.max(0, job.CompletesAt - now)
				local isReady = remaining <= 0

				FacilityCard.Header({
					Icon = "Production",
					Title = definition.Name,
					Subtitle = if recipe then recipe.Name else job.RecipeId,
					Accent = FacilityStyle.Accents.Production,
					LayoutOrder = 1,
					Parent = cardContent,
				})
				StatusChip.new({
					Status = if isReady then "Ready" else "Running",
					LayoutOrder = 2,
					Parent = cardContent,
				})

				if not isReady then
					local total = math.max(1, job.CompletesAt - job.StartedAt)
					MeterRow.new({
						Label = "Progress",
						Value = `{FacilityStyle.FormatClock(remaining)} left`,
						Progress = 1 - remaining / total,
						Accent = FacilityStyle.Accents.Production,
						LayoutOrder = 3,
						Parent = cardContent,
					})
				elseif recipe then
					FacilityCard.Text({
						Text = `{recipe.OutputQuantity} {FacilityStyle.PrettyName(recipe.OutputItemId)} waiting to collect.`,
						Color = Theme.Colors.Success,
						LayoutOrder = 3,
						Parent = cardContent,
					})
				end
			else
				FacilityCard.Header({
					Icon = "Production",
					Title = definition.Name,
					Subtitle = "No job running",
					Accent = FacilityStyle.Accents.Production,
					LayoutOrder = 1,
					Parent = cardContent,
				})
				StatusChip.new({ Status = "Idle", LayoutOrder = 2, Parent = cardContent })
			end

			routeButton(cardContent, "Production", "Open Processor", FacilityStyle.Accents.Production, 4)
		end
	end

	if machineCount == 0 then
		EmptyState.new({
			Glyph = "Production",
			Text = "No production yet",
			Subtext = "Build a Resource Processor to refine raw materials.",
			Card = true,
			LayoutOrder = nextOrder(),
			Parent = content,
		})
	end
end

-- ---------------------------------------------------------------------
-- Tab: Defense
-- ---------------------------------------------------------------------

local function renderDefense(content: GuiObject)
	local nextOrder = order()
	local defense = BaseSessionController.GetDefenseSummary()

	if #defense == 0 then
		EmptyState.new({
			Glyph = "Defense",
			Text = "No perimeter yet",
			Subtext = "Build Defense Control to unlock the wall sockets.",
			Card = true,
			LayoutOrder = nextOrder(),
			Parent = content,
		})
		return
	end

	SectionHeader.new({
		Text = "Perimeter",
		Accent = FacilityStyle.Accents.Defense,
		Info = "Each side is only as strong as its weakest socket, so the tier shown is the lowest along that side.",
		LayoutOrder = nextOrder(),
		Parent = content,
	})

	for _, group in defense do
		local _card, cardContent = FacilityCard.new({
			Name = `Defense_{group.Group}`,
			Accent = FacilityStyle.TierAccent(group.Tier),
			LayoutOrder = nextOrder(),
			Parent = content,
		})

		TierPips.Row({
			Name = `{group.Group} Wall`,
			Tier = group.Tier,
			LayoutOrder = 1,
			Parent = cardContent,
		})

		if group.Built < group.Sockets then
			FacilityCard.Text({
				Text = `{group.Sockets - group.Built} socket{if group.Sockets - group.Built == 1 then "" else "s"} still open.`,
				Color = Theme.Colors.Danger,
				LayoutOrder = 2,
				Parent = cardContent,
			})
		end
		if group.MaxHealth > 0 then
			MeterRow.new({
				Label = "Integrity",
				Value = `{group.Health} / {group.MaxHealth}`,
				Progress = group.Health / group.MaxHealth,
				Accent = if group.Health < group.MaxHealth then Theme.Colors.Warning else FacilityStyle.Accents.Defense,
				Compact = true,
				LayoutOrder = 3,
				Parent = cardContent,
			})
		end
	end

	routeButton(content, "Defense", "Open Defense Control", FacilityStyle.Accents.Defense, nextOrder())
	routeButton(content, "UpgradeStation", "Open Upgrade Station", FacilityStyle.Accents.UpgradeStation, nextOrder())
end

-- ---------------------------------------------------------------------
-- Tab: Power
-- ---------------------------------------------------------------------

local function renderPower(content: GuiObject)
	local session = BaseSessionController.GetSession()
	local nextOrder = order()
	local power = BaseSessionController.GetPowerSummary()

	if not power.HasGenerator then
		EmptyState.new({
			Glyph = "Power",
			Text = "No generator built",
			Subtext = "Build a Basic Generator to power machines.",
			Card = true,
			LayoutOrder = nextOrder(),
			Parent = content,
		})
		return
	end

	local _card, cardContent = FacilityCard.new({
		Name = "PowerSummary",
		Accent = FacilityStyle.Accents.Generator,
		LayoutOrder = nextOrder(),
		Parent = content,
	})

	local headroom = power.Capacity - power.Used
	FacilityCard.Header({
		Icon = "Power",
		Title = "POWER GRID",
		Subtitle = `Generator level {power.GeneratorLevel}`,
		Accent = FacilityStyle.Accents.Generator,
		LayoutOrder = 1,
		Parent = cardContent,
	})
	StatusChip.new({
		Status = if headroom < 0 then "Critical" elseif headroom <= 1 then "Low" else "Stable",
		LayoutOrder = 2,
		Parent = cardContent,
	})
	MeterRow.new({
		Label = "Output",
		Value = `{power.Used} / {power.Capacity}`,
		Progress = if power.Capacity > 0 then power.Used / power.Capacity else 0,
		Accent = FacilityStyle.Accents.Generator,
		LayoutOrder = 3,
		Parent = cardContent,
	})

	routeButton(content, "Generator", "Open Generator", FacilityStyle.Accents.Generator, nextOrder())

	SectionHeader.new({ Text = "Consumers", LayoutOrder = nextOrder(), Parent = content })

	local consumerCount = 0
	if session then
		for structureId, structure in session.Structures do
			local definition = BuildingConfig.Get(structure.BuildingId)
			if not definition or definition.PowerDraw <= 0 then
				continue
			end
			consumerCount += 1
			local enabled = session.Power.Enabled[structureId] == true

			local _consumerCard, consumerContent = FacilityCard.new({
				Name = `Consumer_{structureId}`,
				Padding = Theme.Spacing.S,
				LayoutOrder = nextOrder(),
				Parent = content,
			})

			FacilityCard.Header({
				Title = definition.Name,
				TrailingText = `{definition.PowerDraw} PWR`,
				TrailingColor = FacilityStyle.Accents.Generator,
				LayoutOrder = 1,
				Parent = consumerContent,
			})
			StatusChip.new({
				Status = if enabled then "Running" else "Offline",
				Text = if enabled then "ENABLED" else "DISABLED",
				LayoutOrder = 2,
				Parent = consumerContent,
			})
		end
	end

	if consumerCount == 0 then
		EmptyState.new({
			Glyph = "Power",
			Text = "Nothing draws power yet",
			Subtext = "Machines appear here once built.",
			Card = true,
			LayoutOrder = nextOrder(),
			Parent = content,
		})
	end
end

-- ---------------------------------------------------------------------
-- Tab: Storage
-- ---------------------------------------------------------------------

local function renderStorage(content: GuiObject)
	local session = BaseSessionController.GetSession()
	local nextOrder = order()
	local storage = BaseSessionController.GetStorageSummary()

	MeterRow.new({
		Label = "Capacity",
		Value = `{storage.Used} / {storage.Capacity}`,
		Progress = if storage.Capacity > 0 then storage.Used / storage.Capacity else 0,
		Accent = FacilityStyle.Accents.Storage,
		ValueColor = if storage.Capacity > 0 and storage.Used / storage.Capacity >= 0.9 then Theme.Colors.Warning else Theme.Colors.TextPrimary,
		LayoutOrder = nextOrder(),
		Parent = content,
	})

	local itemIds: { string } = {}
	if session then
		for itemId, amount in session.Storage do
			if amount > 0 then
				table.insert(itemIds, itemId)
			end
		end
	end
	table.sort(itemIds, function(a, b)
		return (session.Storage[a] :: number) > (session.Storage[b] :: number)
	end)

	if #itemIds == 0 then
		EmptyState.new({
			Glyph = "Storage",
			Text = "Base Storage is empty",
			Subtext = "Deposit expedition materials at the storage crate.",
			Card = true,
			LayoutOrder = nextOrder(),
			Parent = content,
		})
	else
		SectionHeader.new({ Text = "Stored", LayoutOrder = nextOrder(), Parent = content })
		for _, itemId in itemIds do
			local row = Instance.new("Frame")
			row.Name = `Stored_{itemId}`
			row.Size = UDim2.new(1, 0, 0, 34)
			row.LayoutOrder = nextOrder()
			row.BackgroundTransparency = 1
			row.Parent = content

			ItemIcon.new({ ItemId = itemId, Size = UDim2.fromOffset(26, 26), Parent = row })

			local name = Instance.new("TextLabel")
			name.Position = UDim2.fromOffset(36, 0)
			name.Size = UDim2.new(1, -140, 1, 0)
			name.BackgroundTransparency = 1
			name.Font = Theme.Font.Body.Font
			name.TextSize = Theme.Font.Body.Size
			name.TextXAlignment = Enum.TextXAlignment.Left
			name.TextTruncate = Enum.TextTruncate.AtEnd
			name.TextColor3 = Theme.Colors.TextSecondary
			name.Text = FacilityStyle.PrettyName(itemId)
			name.Parent = row

			local amount = Instance.new("TextLabel")
			amount.AnchorPoint = Vector2.new(1, 0)
			amount.Position = UDim2.fromScale(1, 0)
			amount.Size = UDim2.new(0, 96, 1, 0)
			amount.BackgroundTransparency = 1
			amount.Font = Theme.Font.Stat.Font
			amount.TextSize = Theme.Font.Heading.Size
			amount.TextXAlignment = Enum.TextXAlignment.Right
			amount.TextColor3 = Theme.Colors.TextPrimary
			amount.Text = tostring(session.Storage[itemId])
			amount.Parent = row
		end
	end

	routeButton(content, "Storage", "Deposit / Withdraw", FacilityStyle.Accents.Storage, nextOrder())
	routeButton(content, "Trader", "Open Trader Terminal", FacilityStyle.Accents.Trader, nextOrder())
end

-- ---------------------------------------------------------------------
-- Shell
-- ---------------------------------------------------------------------

local RENDERERS: { [string]: (GuiObject) -> () } = {
	Overview = renderOverview,
	Production = renderProduction,
	Defense = renderDefense,
	Power = renderPower,
	Storage = renderStorage,
}

local function render()
	local activeModal = modal
	if not activeModal then
		return
	end
	activeModal:ClearContent()
	local renderer = RENDERERS[currentTab] or renderOverview
	renderer(activeModal.Content)
	activeModal:RevealContent()
end

function BaseUIController.Open(initialTab: string?)
	local activeModal = modal
	if not activeModal then
		return
	end
	BaseSessionController.Refresh()
	currentTab = initialTab or "Overview"
	activeModal:Open(currentTab)
	-- Open() only re-runs the tab callback when the tab actually changes, so
	-- render explicitly here — otherwise re-opening on the same tab would
	-- show whatever was on screen when it last closed.
	render()
end

function BaseUIController.Close()
	if modal then
		modal:Close()
	end
end

function BaseUIController:Init()
	self._trove = Trove.new()

	modal = FacilityModal.new({
		Id = "BaseManagement",
		Icon = IDENTITY.Icon,
		Title = IDENTITY.Title,
		Subtitle = IDENTITY.Subtitle,
		Accent = IDENTITY.Accent,
		WidthClass = "Regular",
		Tabs = TABS,
		OnTabSelected = function(tabId: string)
			currentTab = tabId
			render()
		end,
	})

	FacilityRouter.Register("BaseManagement", function(tabId: string?)
		BaseUIController.Open(tabId)
	end)
end

function BaseUIController:Start()
	self._trove:Add(FacilityPrompts.Bind({
		Tag = "BaseCoreTerminal",
		OnTriggered = function()
			BaseUIController.Open("Overview")
		end,
	}))

	-- Live-update while open. A base screen that silently goes stale after a
	-- deposit or a finished job is worse than one that never showed the
	-- number at all.
	self._trove:Add(BaseSessionController.Changed:Connect(function()
		local activeModal = modal
		if activeModal and activeModal:IsOpen() then
			render()
		end
	end))
end

return BaseUIController
