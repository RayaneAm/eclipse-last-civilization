--!strict
-- UPGRADE STATION — opened at the workbench (BaseUpgradeStation tag) and
-- from Base Management.
--
-- Answers one question: what can I improve right now? The list is built from
-- BaseSessionController.GetUpgradeCandidates, which already filters out
-- anything the server would reject (a pad-bound structure whose next tier is
-- not in that pad's allowed chain never appears) and sorts affordable-first,
-- then closest-to-affordable, then weakest — exactly the priority the brief
-- asks for (§24).
--
-- Every entry routes to the shared upgrade screen, so the cost breakdown and
-- the before/after comparison are the same ones you get by walking up to the
-- structure itself. This screen deliberately does not duplicate that detail:
-- it is a browser, not a second upgrade dialog.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage.Shared.Modules.Trove)
local BuildingConfig = require(ReplicatedStorage.Shared.Config.BuildingConfig)

local Theme = require(script.Parent.Parent.UI.Theme)
local FacilityStyle = require(script.Parent.Parent.UI.FacilityStyle)
local FacilityRouter = require(script.Parent.Parent.UI.FacilityRouter)
local FacilityPrompts = require(script.Parent.Parent.UI.FacilityPrompts)
local FacilityModal = require(script.Parent.Parent.UI.Components.FacilityModal)
local FacilityCard = require(script.Parent.Parent.UI.Components.FacilityCard)
local SectionHeader = require(script.Parent.Parent.UI.Components.SectionHeader)
local StatComparison = require(script.Parent.Parent.UI.Components.StatComparison)
local StatusChip = require(script.Parent.Parent.UI.Components.StatusChip)
local TierPips = require(script.Parent.Parent.UI.Components.TierPips)
local EmptyState = require(script.Parent.Parent.UI.Components.EmptyState)
local Button = require(script.Parent.Parent.UI.Components.Button)

local BaseSessionController = require(script.Parent.BaseSessionController)

local UpgradeStationController = {}

local IDENTITY = FacilityStyle.Facilities.UpgradeStation
local ACCENT = IDENTITY.Accent

local TABS = {
	{ Id = "Available", Label = "AVAILABLE" },
	{ Id = "Buildings", Label = "BUILDINGS" },
	{ Id = "Defense", Label = "DEFENSE" },
	{ Id = "Production", Label = "PRODUCTION" },
}

local modal: FacilityModal.FacilityModal? = nil
local currentTab = "Available"

-- Which tab a candidate belongs in, derived from its BuildingConfig category
-- rather than a separate list that could drift.
local function isDefense(candidate: BaseSessionController.UpgradeCandidate): boolean
	return candidate.Current.DefenseTier ~= nil or candidate.Current.Category == "Defense"
end

local function isProduction(candidate: BaseSessionController.UpgradeCandidate): boolean
	return candidate.Current.Category == "Production" or candidate.Current.Id == "Generator"
end

local function matchesTab(candidate: BaseSessionController.UpgradeCandidate, tabId: string): boolean
	if tabId == "Available" then
		return true
	elseif tabId == "Defense" then
		return isDefense(candidate)
	elseif tabId == "Production" then
		return isProduction(candidate)
	end
	-- Buildings contains support and built-structure upgrades, never defense or
	-- production/power candidates that already have dedicated tabs.
	return not isDefense(candidate) and not isProduction(candidate)
end

local function buildCandidateCard(parent: Instance, candidate: BaseSessionController.UpgradeCandidate, layoutOrder: number)
	local isDefense = candidate.Current.DefenseTier ~= nil
	local currentTier = candidate.Current.DefenseTier or candidate.Structure.Level
	local nextTier = candidate.Next.DefenseTier or (currentTier + 1)
	local accent = if isDefense then FacilityStyle.TierAccent(nextTier) else ACCENT

	local _card, cardContent = FacilityCard.new({
		Name = `Upgrade_{candidate.StructureId}`,
		Accent = accent,
		LayoutOrder = layoutOrder,
		Parent = parent,
	})

	FacilityCard.Header({
		Icon = if isDefense then "Defense" else "Upgrade",
		Title = candidate.Current.Name,
		Subtitle = `{candidate.Current.TierLabel or `Level {candidate.Structure.Level}`} → {candidate.Next.TierLabel or `Level {candidate.Structure.Level + 1}`}`,
		Accent = accent,
		LayoutOrder = 1,
		Parent = cardContent,
	})

	if isDefense then
		local pipRow = Instance.new("Frame")
		pipRow.Name = "Pips"
		pipRow.Size = UDim2.new(1, 0, 0, 14)
		pipRow.LayoutOrder = 2
		pipRow.BackgroundTransparency = 1
		pipRow.Parent = cardContent
		TierPips.new({ Tier = nextTier, Parent = pipRow })
	end

	-- Only the stats that move — the same rule the full upgrade screen uses.
	local comparison = StatComparison.new({
		Stats = {
			{
				Label = "Durability",
				Current = tostring(BuildingConfig.GetMaxHealth(candidate.Current.Id)),
				Next = tostring(BuildingConfig.GetMaxHealth(candidate.Next.Id)),
			},
			{
				Label = "Power draw",
				Current = tostring(candidate.Current.PowerDraw),
				Next = tostring(candidate.Next.PowerDraw),
			},
		},
		Accent = accent,
		LayoutOrder = 3,
	})
	if comparison then
		comparison.Parent = cardContent
	end

	local totalRequirements = 0
	for _ in candidate.Next.Cost.Materials do
		totalRequirements += 1
	end
	if candidate.Next.Cost.Scrap > 0 then
		totalRequirements += 1
	end
	local ready = totalRequirements - candidate.MissingCount

	local footer = Instance.new("Frame")
	footer.Name = "Footer"
	footer.Size = UDim2.new(1, 0, 0, 38)
	footer.LayoutOrder = 4
	footer.BackgroundTransparency = 1
	footer.Parent = cardContent

	StatusChip.new({
		Status = if candidate.Affordable then "Available" else "Idle",
		Text = if candidate.Affordable then "MATERIALS READY" else `MATERIALS {ready} / {totalRequirements}`,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Parent = footer,
	})

	local structureId = candidate.StructureId
	Button.new({
		Text = "View",
		Variant = if candidate.Affordable then "Primary" else "Secondary",
		AccentColor = accent,
		Size = UDim2.fromOffset(104, 32),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		OnActivated = function()
			FacilityRouter.Open("UpgradeStructure", structureId)
		end,
		Parent = footer,
	})
end

local function render()
	local activeModal = modal
	if not activeModal then
		return
	end
	activeModal:ClearContent()

	local content = activeModal.Content
	local layoutOrder = 0
	local function nextOrder(): number
		layoutOrder += 1
		return layoutOrder
	end

	local candidates = BaseSessionController.GetUpgradeCandidates()
	local shown = 0
	for _, candidate in candidates do
		if matchesTab(candidate, currentTab) then
			shown += 1
			buildCandidateCard(content, candidate, nextOrder())
		end
	end

	if shown == 0 then
		local emptyCopy: { [string]: { Text: string, Subtext: string } } = {
			Available = {
				Text = "No upgrades available",
				Subtext = "Gather more advanced materials, or build more of your settlement first.",
			},
			Buildings = {
				Text = "No building upgrades",
				Subtext = "Build or progress support structures to unlock their next improvements.",
			},
			Defense = {
				Text = "No defense upgrades",
				Subtext = "Build or reinforce perimeter defenses to reveal their next tiers.",
			},
			Production = {
				Text = "No production upgrades",
				Subtext = "Build production equipment or a generator to reveal its next improvement.",
			},
		}
		local copy = emptyCopy[currentTab] or emptyCopy.Available
		EmptyState.new({
			Glyph = "Upgrade",
			Text = copy.Text,
			Subtext = copy.Subtext,
			Card = true,
			LayoutOrder = nextOrder(),
			Parent = content,
		})
	end

	-- Gear crafting is a genuinely separate system (InventoryController's
	-- crafting panel, driven by CraftingConfig). Pointing at it here is
	-- accurate; folding it into this list would conflate two different
	-- backends.
	if FacilityRouter.Has("Crafting") then
		SectionHeader.new({
			Text = "Equipment Bench",
			Accent = Theme.Colors.Brand,
			LayoutOrder = nextOrder(),
			Parent = content,
		})

		local _craftingCard, craftingContent = FacilityCard.new({
			Name = "EquipmentCrafting",
			LayoutOrder = nextOrder(),
			Parent = content,
		})

		FacilityCard.Header({
			ItemId = "Hatchet",
			Title = "Equipment Crafting",
			Subtitle = "Craft tools and field equipment from recovered materials.",
			LayoutOrder = 1,
			Parent = craftingContent,
		})

		Button.new({
			Text = "Open Equipment Crafting",
			Variant = "Secondary",
			AccentColor = Theme.Colors.Brand,
			Size = UDim2.new(1, 0, 0, 40),
			LayoutOrder = 2,
			OnActivated = function()
				local stationModal = modal
				if stationModal then
					stationModal:Suspend()
				end
				FacilityRouter.Open("Crafting", { ReturnRoute = "UpgradeStation", ReturnTab = currentTab })
			end,
			Parent = craftingContent,
		})
	end

	activeModal:RevealContent()
end

function UpgradeStationController.Open(initialTab: string?)
	local activeModal = modal
	if not activeModal then
		return
	end
	BaseSessionController.Refresh()
	currentTab = initialTab or "Available"
	activeModal:Open(currentTab)
	render()
end

function UpgradeStationController:Init()
	self._trove = Trove.new()

	modal = FacilityModal.new({
		Id = "UpgradeStation",
		Icon = IDENTITY.Icon,
		Title = IDENTITY.Title,
		Subtitle = IDENTITY.Subtitle,
		Accent = ACCENT,
		WidthClass = "Regular",
		Tabs = TABS,
		OnTabSelected = function(tabId: string)
			currentTab = tabId
			render()
		end,
	})

	FacilityRouter.Register("UpgradeStation", function(tabId: string?)
		UpgradeStationController.Open(tabId)
	end)
end

function UpgradeStationController:Start()
	self._trove:Add(FacilityPrompts.Bind({
		Tag = "BaseUpgradeStation",
		OnTriggered = function()
			UpgradeStationController.Open("Available")
		end,
	}))

	self._trove:Add(BaseSessionController.Changed:Connect(function()
		local activeModal = modal
		if activeModal and activeModal:IsOpen() then
			render()
		end
	end))
end

return UpgradeStationController
