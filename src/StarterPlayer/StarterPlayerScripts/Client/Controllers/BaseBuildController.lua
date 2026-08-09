--!strict
-- BUILD and STRUCTURE UPGRADE — the two confirmation screens reached by
-- walking up to a construction node (BaseBlueprintPad) or to an upgradeable
-- structure (BaseUpgradeableStructure) and pressing E.
--
-- Both replace the old generic BaseActionDialog, which showed a title, a
-- paragraph and a bare "owned / required" list. What changed:
--
--   * The cost block is now ResourceRequirementRow's shared presentation
--     (icon, readable name, drawn check/cross, owned/required) and the
--     SHORTFALL IS COMPUTED — "Missing 7 Fiber" — instead of leaving the
--     player to subtract two numbers per row (brief §10).
--   * The upgrade screen leads with a real before/after: the tier names, the
--     tier pips, and only the stats that actually change (brief §12/§14).
--   * The primary CTA is disabled with the reason stated whenever we already
--     know the server would reject it, rather than firing a doomed request.
--
-- Both screens are strictly client-side previews of a server-authoritative
-- action: they show what BuildingService's canAfford/chargeCost will check,
-- and the real decision still happens on the server. `pendingAction` guards
-- against a double-fire while a request is in flight.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local Trove = require(ReplicatedStorage.Shared.Modules.Trove)
local BuildingConfig = require(ReplicatedStorage.Shared.Config.BuildingConfig)
local BlueprintLayoutConfig = require(ReplicatedStorage.Shared.Config.BlueprintLayoutConfig)

local Theme = require(script.Parent.Parent.UI.Theme)
local FacilityStyle = require(script.Parent.Parent.UI.FacilityStyle)
local FacilityRouter = require(script.Parent.Parent.UI.FacilityRouter)
local FacilityPrompts = require(script.Parent.Parent.UI.FacilityPrompts)
local UIAnimator = require(script.Parent.Parent.UI.UIAnimator)
local FacilityModal = require(script.Parent.Parent.UI.Components.FacilityModal)
local FacilityCard = require(script.Parent.Parent.UI.Components.FacilityCard)
local SectionHeader = require(script.Parent.Parent.UI.Components.SectionHeader)
local ResourceRequirementRow = require(script.Parent.Parent.UI.Components.ResourceRequirementRow)
local StatComparison = require(script.Parent.Parent.UI.Components.StatComparison)
local TierPips = require(script.Parent.Parent.UI.Components.TierPips)
local ActionBar = require(script.Parent.Parent.UI.Components.ActionBar)

local BaseSessionController = require(script.Parent.BaseSessionController)
local BaseWorldFeedbackController = require(script.Parent.BaseWorldFeedbackController)
local NotificationController = require(script.Parent.NotificationController)

local BaseBuildController = {}

-- Every EXPECTED server rejection mapped to player-facing copy. An
-- unexpected reason still surfaces its raw code so a bug is visible rather
-- than swallowed behind a generic message.
local BUILD_REJECTIONS: { [string]: string } = {
	AlreadyBuilt = "This node has already been built",
	CannotAfford = "Not enough materials in Base Storage",
	BuildingLimitReached = "Base building limit reached",
	UnknownPad = "Unknown construction node",
	UnknownBuilding = "Unknown building type",
	BaseNotReady = "Your base is not ready yet",
	ProtectedZone = "This node is blocked",
	Overlap = "This node is blocked",
	MissingPrerequisite = "Build the required structure first",
}

local UPGRADE_REJECTIONS: { [string]: string } = {
	CannotAfford = "Not enough materials for this upgrade",
	NoUpgradeAvailable = "This structure is already at its highest tier",
	InvalidUpgradePath = "That upgrade is not valid for this socket",
	UnknownStructure = "This structure no longer exists",
	BaseNotReady = "Your base is not ready yet",
}

local DISTRICT_ACCENTS: { [string]: Color3 } = {
	Entrance = Color3.fromRGB(196, 158, 91),
	Logistics = Color3.fromRGB(91, 181, 184),
	Production = Color3.fromRGB(203, 137, 67),
	Support = Color3.fromRGB(114, 169, 103),
	Perimeter = Color3.fromRGB(179, 94, 76),
}

local buildModal: FacilityModal.FacilityModal? = nil
local upgradeModal: FacilityModal.FacilityModal? = nil
local pendingAction = false

-- What each screen is currently showing, so a live storage change can
-- re-render the same target rather than guessing.
local currentPadId: string? = nil
local currentStructureId: string? = nil

-- ---------------------------------------------------------------------
-- Build
-- ---------------------------------------------------------------------

local function renderBuild(padId: string)
	local modal = buildModal
	if not modal then
		return
	end

	local pad = BlueprintLayoutConfig.Get(padId)
	local definition = pad and BuildingConfig.Get(pad.BuildingId)
	if not pad or not definition then
		return
	end

	-- The district tints the cost heading and the CTA, so a Logistics node
	-- and a Perimeter node are distinguishable at a glance without the panel
	-- shell changing.
	local accent = DISTRICT_ACCENTS[pad.District] or FacilityStyle.Accents.Build

	modal:SetHeader(string.upper(definition.Name), `{string.upper(pad.District)} BUILD NODE`)
	modal:ClearContent()

	local content = modal.Content
	local layoutOrder = 0
	local function nextOrder(): number
		layoutOrder += 1
		return layoutOrder
	end

	FacilityCard.Text({
		Text = definition.Description or "Add this structure to your settlement.",
		Color = Theme.Colors.TextSecondary,
		LayoutOrder = nextOrder(),
		Parent = content,
	})

	local storage = BaseSessionController.GetStorage()
	local scrap = BaseSessionController.GetScrap()

	SectionHeader.new({
		Text = "Cost",
		Accent = accent,
		Info = "Materials come from Base Storage, not your backpack.",
		LayoutOrder = nextOrder(),
		Parent = content,
	})

	local _costCard, costContent = FacilityCard.new({
		Name = "Cost",
		Accent = accent,
		Spacing = Theme.Spacing.XXS,
		LayoutOrder = nextOrder(),
		Parent = content,
	})

	local result = ResourceRequirementRow.RenderCost(costContent, definition.Cost.Materials, storage)
	local affordable = result.Affordable
	local shortfall = result.Summary

	if definition.Cost.Scrap > 0 then
		ResourceRequirementRow.new({
			ItemId = "Scrap",
			Owned = scrap,
			Required = definition.Cost.Scrap,
			LayoutOrder = 100,
			Parent = costContent,
		})
		if scrap < definition.Cost.Scrap then
			affordable = false
			local missingScrap = definition.Cost.Scrap - scrap
			shortfall = if shortfall then `{shortfall}, {missingScrap} Scrap` else `Missing {missingScrap} Scrap`
		end
	end

	if next(definition.Cost.Materials) == nil and definition.Cost.Scrap == 0 then
		FacilityCard.Text({ Text = "No materials required.", Color = Theme.Colors.Success, LayoutOrder = 1, Parent = costContent })
	end

	ActionBar.new({
		PrimaryText = "Build",
		PrimaryAccent = accent,
		SecondaryText = "Cancel",
		BlockedReason = shortfall,
		LayoutOrder = nextOrder(),
		OnSecondary = function()
			BaseWorldFeedbackController.DismissPreview(padId)
			modal:Close()
		end,
		OnPrimary = function()
			if pendingAction or not affordable then
				return
			end
			pendingAction = true
			local ok, reason = Net.GetFunction("RequestBuildBlueprint"):InvokeServer({ PadId = padId })
			pendingAction = false

			if ok then
				-- Close first so the world construction animation the server
				-- kicked off is actually visible — the confirmation is a
				-- brief toast over the base, not another panel to dismiss.
				modal:Close()
				UIAnimator.PlaySound("Build")
				NotificationController.Toast("BuildConfirmed", `{definition.Name} built ✓`)
			else
				NotificationController.Toast("BuildRejected", BUILD_REJECTIONS[tostring(reason)] or `Build failed: {tostring(reason)}`)
			end
		end,
		Parent = content,
	})

	modal:RevealContent()
end

function BaseBuildController.OpenBuild(padId: string)
	local modal = buildModal
	if not modal then
		return
	end
	BaseSessionController.Refresh()
	currentPadId = padId
	currentStructureId = nil
	modal:Open()
	renderBuild(padId)
end

-- ---------------------------------------------------------------------
-- Upgrade
-- ---------------------------------------------------------------------

local function renderUpgrade(structureId: string)
	local modal = upgradeModal
	if not modal then
		return
	end

	local session = BaseSessionController.GetSession()
	local structure = session and session.Structures[structureId]
	local current = structure and BuildingConfig.Get(structure.BuildingId)
	local nextDefinition = current and current.NextTierBuildingId and BuildingConfig.Get(current.NextTierBuildingId)

	if not structure or not current or not nextDefinition then
		NotificationController.Toast("BuildRejected", "This structure is already at its highest tier")
		return
	end

	local currentTier = current.DefenseTier or structure.Level
	local nextTier = nextDefinition.DefenseTier or (currentTier + 1)

	modal:SetHeader(string.upper(current.Name), `TIER {currentTier} → TIER {nextTier}`)
	modal:ClearContent()

	local content = modal.Content
	local layoutOrder = 0
	local function nextOrder(): number
		layoutOrder += 1
		return layoutOrder
	end

	-- The headline: what this thing becomes.
	local _transitionCard, transitionContent = FacilityCard.new({
		Name = "Transition",
		Accent = FacilityStyle.TierAccent(nextTier),
		LayoutOrder = nextOrder(),
		Parent = content,
	})

	StatComparison.Transition({
		FromLabel = current.TierLabel or current.Name,
		FromTier = currentTier,
		ToLabel = nextDefinition.TierLabel or nextDefinition.Name,
		ToTier = nextTier,
		FromColor = FacilityStyle.TierAccent(currentTier),
		ToColor = FacilityStyle.TierAccent(nextTier),
		LayoutOrder = 1,
		Parent = transitionContent,
	})

	local pipRow = Instance.new("Frame")
	pipRow.Name = "Pips"
	pipRow.Size = UDim2.new(1, 0, 0, 16)
	pipRow.LayoutOrder = 2
	pipRow.BackgroundTransparency = 1
	pipRow.Parent = transitionContent
	TierPips.new({ Tier = currentTier, Parent = pipRow })
	TierPips.new({ Tier = nextTier, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Parent = pipRow })

	if current.UpgradeSummary then
		FacilityCard.Text({ Text = current.UpgradeSummary, LayoutOrder = 3, Parent = transitionContent })
	end

	-- Only stats that actually move. Health is the one every tier changes;
	-- power draw and footprint height change on some, so they're offered and
	-- StatComparison drops whichever turn out to be identical.
	local currentMax = BuildingConfig.GetMaxHealth(current.Id)
	local nextMax = BuildingConfig.GetMaxHealth(nextDefinition.Id)
	local currentFootprint = BuildingConfig.GetFootprintSize(current.Id)
	local nextFootprint = BuildingConfig.GetFootprintSize(nextDefinition.Id)

	local comparison = StatComparison.new({
		Stats = {
			{ Label = "Durability", Current = tostring(currentMax), Next = tostring(nextMax) },
			{ Label = "Height", Current = tostring(currentFootprint.Y), Next = tostring(nextFootprint.Y) },
			{ Label = "Powered", Current = if current.PowerDraw > 0 then "YES" else "NO", Next = if nextDefinition.PowerDraw > 0 then "YES" else "NO" },
		},
		Accent = FacilityStyle.TierAccent(nextTier),
		LayoutOrder = nextOrder() + 1,
	})
	if comparison then
		SectionHeader.new({ Text = "Changes", Accent = FacilityStyle.TierAccent(nextTier), LayoutOrder = nextOrder(), Parent = content })
		comparison.LayoutOrder = nextOrder()
		comparison.Parent = content
	end

	if structure.Health < currentMax then
		FacilityCard.Text({
			Text = `Upgrading also restores this structure to full health (currently {structure.Health} / {currentMax}).`,
			Color = Theme.Colors.Warning,
			LayoutOrder = nextOrder(),
			Parent = content,
		})
	end

	-- Cost
	SectionHeader.new({
		Text = "Cost",
		Accent = FacilityStyle.Accents.UpgradeStation,
		Info = "Materials come from Base Storage, not your backpack.",
		LayoutOrder = nextOrder(),
		Parent = content,
	})

	local _costCard, costContent = FacilityCard.new({
		Name = "Cost",
		Spacing = Theme.Spacing.XXS,
		LayoutOrder = nextOrder(),
		Parent = content,
	})

	local storage = BaseSessionController.GetStorage()
	local scrap = BaseSessionController.GetScrap()
	local result = ResourceRequirementRow.RenderCost(costContent, nextDefinition.Cost.Materials, storage)
	local affordable = result.Affordable
	local shortfall = result.Summary

	if nextDefinition.Cost.Scrap > 0 then
		ResourceRequirementRow.new({
			ItemId = "Scrap",
			Owned = scrap,
			Required = nextDefinition.Cost.Scrap,
			LayoutOrder = 100,
			Parent = costContent,
		})
		if scrap < nextDefinition.Cost.Scrap then
			affordable = false
			local missingScrap = nextDefinition.Cost.Scrap - scrap
			shortfall = if shortfall then `{shortfall}, {missingScrap} Scrap` else `Missing {missingScrap} Scrap`
		end
	end

	ActionBar.new({
		PrimaryText = `Upgrade to T{nextTier}`,
		PrimaryAccent = FacilityStyle.TierAccent(nextTier),
		SecondaryText = "Cancel",
		BlockedReason = shortfall,
		LayoutOrder = nextOrder(),
		OnSecondary = function()
			modal:Close()
		end,
		OnPrimary = function()
			if pendingAction or not affordable then
				return
			end
			pendingAction = true
			local ok, reason = Net.GetFunction("RequestUpgradeBuilding"):InvokeServer({ StructureId = structureId })
			pendingAction = false

			if ok then
				modal:Close()
				UIAnimator.PlaySound("Upgrade")
				NotificationController.Toast("BuildConfirmed", `{nextDefinition.Name} ✓`)
			else
				NotificationController.Toast("BuildRejected", UPGRADE_REJECTIONS[tostring(reason)] or `Upgrade failed: {tostring(reason)}`)
			end
		end,
		Parent = content,
	})

	modal:RevealContent()
end

function BaseBuildController.OpenUpgrade(structureId: string)
	local modal = upgradeModal
	if not modal then
		return
	end
	BaseSessionController.Refresh()
	-- Rendered before Open so a structure that turns out to be maxed (the
	-- session moved on since the prompt appeared) never flashes an empty
	-- panel — renderUpgrade toasts and returns instead.
	local session = BaseSessionController.GetSession()
	local structure = session and session.Structures[structureId]
	local current = structure and BuildingConfig.Get(structure.BuildingId)
	if not current or not current.NextTierBuildingId then
		NotificationController.Toast("BuildRejected", "This structure is already at its highest tier")
		return
	end
	currentStructureId = structureId
	currentPadId = nil
	modal:Open()
	renderUpgrade(structureId)
end

-- ---------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------

function BaseBuildController:Init()
	self._trove = Trove.new()

	buildModal = FacilityModal.new({
		Id = "BaseBuild",
		Icon = "Build",
		Title = "BUILD",
		Subtitle = "CONSTRUCTION NODE",
		Accent = FacilityStyle.Accents.Build,
		WidthClass = "Compact",
		OnClose = function()
			BaseWorldFeedbackController.DismissPreview(currentPadId)
		end,
	})

	upgradeModal = FacilityModal.new({
		Id = "BaseUpgrade",
		Icon = "Defense",
		Title = "UPGRADE",
		Subtitle = "",
		Accent = FacilityStyle.Accents.UpgradeStation,
		WidthClass = "Compact",
	})

	FacilityRouter.Register("BuildNode", function(padId: string)
		BaseBuildController.OpenBuild(padId)
	end)
	FacilityRouter.Register("UpgradeStructure", function(structureId: string)
		BaseBuildController.OpenUpgrade(structureId)
	end)
end

function BaseBuildController:Start()
	self._trove:Add(FacilityPrompts.Bind({
		Tag = "BaseBlueprintPad",
		OnTriggered = function(host: BasePart)
			local padId = host:GetAttribute("PadId")
			if typeof(padId) == "string" then
				BaseBuildController.OpenBuild(padId)
			end
		end,
	}))

	self._trove:Add(FacilityPrompts.Bind({
		Tag = "BaseUpgradeableStructure",
		PromptName = "UpgradePrompt",
		OnTriggered = function(host: BasePart)
			local structureId = host:GetAttribute("StructureId")
			if typeof(structureId) == "string" then
				BaseBuildController.OpenUpgrade(structureId)
			end
		end,
	}))

	-- Keep an open cost screen honest while storage changes underneath it
	-- (a helper depositing, a production job collecting). Without this a
	-- BUILD button could stay greyed out after the missing material arrived.
	self._trove:Add(BaseSessionController.Changed:Connect(function()
		local build = buildModal
		local upgrade = upgradeModal
		local padId = currentPadId
		local structureId = currentStructureId
		if build and build:IsOpen() and padId then
			renderBuild(padId)
		elseif upgrade and upgrade:IsOpen() and structureId then
			renderUpgrade(structureId)
		end
	end))
end

return BaseBuildController
