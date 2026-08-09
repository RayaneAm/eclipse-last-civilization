--!strict
-- Interaction for Haven's facility anchors: the world ProximityPrompt plus
-- the floating info panel, and the routing from a prompt to that facility's
-- screen.
--
-- Before the facility UI pass most of these prompts read "View" and did
-- nothing at all — the hologram panel was the entire interaction. Now every
-- facility with a screen routes to it through FacilityRouter, which keeps
-- this file free of direct requires on ten controllers (and free of the
-- require cycles that would come with them).
--
-- The routing table below is deliberately explicit about which facilities
-- have a destination. A facility with no entry keeps the informational
-- prompt rather than opening an empty panel — and a facility whose
-- controller failed to register (so its route is missing at runtime) falls
-- back to the same informational prompt instead of a dead press.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HavenFacilityConfig = require(ReplicatedStorage.Shared.Config.HavenFacilityConfig)
local Trove = require(ReplicatedStorage.Shared.Modules.Trove)

local FacilityRouter = require(script.Parent.Parent.UI.FacilityRouter)
local HologramPanel = require(script.Parent.Parent.UI.Components.HologramPanel)

local InventoryController = require(script.Parent.InventoryController)
local HUDController = require(script.Parent.HUDController)

local FACILITY_TAG = "HavenFacility"

local FacilityController = {}

local facilityById: { [string]: HavenFacilityConfig.FacilityDefinition } = {}
for _, facility in HavenFacilityConfig do
	facilityById[facility.id] = facility
end

-- FacilityKind -> (route id, prompt verb). Every route here is registered by
-- the controller that owns that screen.
local KIND_ROUTES: { [string]: { Route: string, ActionText: string } } = {
	UpgradeStation = { Route = "UpgradeStation", ActionText = "Manage Upgrades" },
	DailyRewards = { Route = "DailyRewards", ActionText = "Open" },
	Market = { Route = "SurvivorMarket", ActionText = "Trade" },
	CosmeticShop = { Route = "CosmeticShop", ActionText = "Browse" },
	CapsuleLab = { Route = "Laboratory", ActionText = "Examine" },
}

local function buildPanel(anchor: BasePart, facility: HavenFacilityConfig.FacilityDefinition): BillboardGui
	return HologramPanel.new({
		Name = "FacilityPanel",
		Size = UDim2.fromOffset(220, 80),
		StudsOffsetWorldSpace = Vector3.new(0, 10, 0),
		MaxDistance = 40,
		AccentColor = anchor.Color, -- the generator sets FacilityAnchor.Color to the owning district's accent
		Parent = anchor,
		Sections = {
			{ Name = "Title", Font = Enum.Font.GothamBold, TextSize = 17, Height = 24, Text = facility.name },
			{
				Name = "Description",
				Font = Enum.Font.Gotham,
				TextSize = 12,
				Height = 44,
				Wrapped = true,
				TextColor3 = Color3.fromRGB(220, 220, 220),
				Text = facility.description,
			},
		},
	})
end

local function setupFacility(anchor: Instance, trove: any)
	if not anchor:IsA("BasePart") then
		return
	end

	local facilityId = anchor:GetAttribute("FacilityId") :: string?
	if not facilityId then
		warn(`FacilityController: "{anchor:GetFullName()}" is tagged {FACILITY_TAG} but has no FacilityId attribute`)
		return
	end

	local facility = facilityById[facilityId]
	if not facility then
		warn(`FacilityController: unknown FacilityId "{facilityId}" on {anchor:GetFullName()}`)
		return
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "FacilityPrompt"
	prompt.ObjectText = facility.name
	-- 12 studs, not 16: Haven's two intentionally-close clustered facility
	-- pairs sit ~26-34 studs apart edge-to-edge, and at 16 both prompts could
	-- be active at once for a player standing between them.
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor
	trove:Add(prompt)

	local routing = KIND_ROUTES[facility.kind]
	if routing then
		prompt.ActionText = routing.ActionText
		local routeId = routing.Route
		trove:Add(prompt.Triggered:Connect(function()
			if not FacilityRouter.Open(routeId) then
				warn(`FacilityController: no screen registered for route "{routeId}"`)
			end
		end))
	elseif facility.kind == "DailyQuestBoard" then
		-- The board's live set is per-player and lives in the existing Daily
		-- Quests panel, which the HUD owns — deliberately left alone by this
		-- pass (the sidebar/HUD is a separate task).
		prompt.ActionText = "Read Board"
		trove:Add(prompt.Triggered:Connect(function()
			HUDController.DailyQuestsOpenRequested:Fire()
		end))
	else
		-- Leaderboards and the UI-only monetization anchors: the hologram
		-- panel is the whole interaction, so the prompt says so.
		prompt.ActionText = "View"
	end

	trove:Add(buildPanel(anchor, facility))
end

function FacilityController:Init()
	self._trove = Trove.new()

	-- Crafting has a real backend (CraftingConfig + RequestCraft) and already
	-- has a working panel; it is registered here rather than being rebuilt as
	-- a facility modal, so the Upgrade Station and the Laboratory can both
	-- link to the one implementation.
	FacilityRouter.Register("Crafting", function(context: { ReturnRoute: string, ReturnTab: string? }?)
		local onClosed: (() -> ())? = nil
		if context and context.ReturnRoute ~= "" then
			onClosed = function()
				FacilityRouter.Open(context.ReturnRoute, context.ReturnTab)
			end
		end
		InventoryController.Open("Crafting", onClosed)
	end)
end

function FacilityController:Start()
	for _, instance in CollectionService:GetTagged(FACILITY_TAG) do
		setupFacility(instance, self._trove)
	end

	self._trove:Add(CollectionService:GetInstanceAddedSignal(FACILITY_TAG):Connect(function(instance)
		setupFacility(instance, self._trove)
	end))
end

return FacilityController
