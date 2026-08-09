--!strict
-- Generic interaction for Haven's 8 functional areas: ProximityPrompt +
-- holographic info panel, directly modeled on GateController's pattern.
-- Deliberately client-only — there's no server-authoritative state yet (no
-- purchases, no gacha, no real leaderboard data), so no remote round-trip is
-- added just for show. A future dedicated prompt (e.g. a Market economy
-- prompt) wires real backend logic behind these same FacilityAnchor points
-- without this controller needing to change.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HavenFacilityConfig = require(ReplicatedStorage.Shared.Config.HavenFacilityConfig)
local Trove = require(ReplicatedStorage.Shared.Modules.Trove)
local HologramPanel = require(script.Parent.Parent.UI.Components.HologramPanel)
local InventoryController = require(script.Parent.InventoryController)
local DailyRewardsController = require(script.Parent.DailyRewardsController)
local HUDController = require(script.Parent.HUDController)

local FACILITY_TAG = "HavenFacility"

local FacilityController = {}

local facilityById: { [string]: HavenFacilityConfig.FacilityDefinition } = {}
for _, facility in HavenFacilityConfig do
	facilityById[facility.id] = facility
end

-- Retrofitted onto the shared HologramPanel this prompt — same content as
-- before (title + description), now with the diagonal gradient wash
-- GateController's panel already has, which this one previously lacked. A
-- deliberate visual upgrade, not just an internal refactor.
local function buildPanel(anchor: BasePart, facility: HavenFacilityConfig.FacilityDefinition): BillboardGui
	local billboard = HologramPanel.new({
		Name = "FacilityPanel",
		Size = UDim2.fromOffset(220, 80),
		StudsOffsetWorldSpace = Vector3.new(0, 10, 0),
		MaxDistance = 40,
		AccentColor = anchor.Color, -- the generator sets FacilityAnchor.Color to the owning district's accent color
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

	return billboard
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
	-- Phase 1 correction: 16 -> 12 — Survivor Haven's two intentionally-close
	-- clustered facility pairs (Gamepass Showcase/Starter Pack, Season
	-- Event/Season Pass) sit ~26-34 studs apart edge-to-edge; at 16 studs
	-- each, both prompts could be active at once for a player standing
	-- between them. 12 keeps that from happening.
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor
	trove:Add(prompt)

	-- The Upgrade Station is the one facility with a real, working backend
	-- behind it today (crafting) — give it a real action instead of the
	-- generic "View" every other still-placeholder facility gets. Reuses
	-- InventoryController's existing panel; RequestCraft stays the only
	-- crafting request, nothing new added here.
	if facility.kind == "UpgradeStation" then
		prompt.ActionText = "Open Crafting"
		trove:Add(prompt.Triggered:Connect(function()
			InventoryController.Open("Crafting")
		end))
	elseif facility.kind == "DailyRewards" then
		-- Phase 3B: a real action instead of the generic "View" — the prompt
		-- opens the roulette-roll UI; the excitement lives there, not in the
		-- hologram info panel this facility keeps like every other one.
		prompt.ActionText = "Claim"
		trove:Add(prompt.Triggered:Connect(function()
			DailyRewardsController.Open()
		end))
	elseif facility.kind == "DailyQuestBoard" then
		-- The survivor task board in the Haven opens the existing Daily Quests
		-- panel. The world object carries no quest text of its own — the live
		-- set is per-player and lives in that panel.
		prompt.ActionText = "Read Board"
		trove:Add(prompt.Triggered:Connect(function()
			HUDController.DailyQuestsOpenRequested:Fire()
		end))
	else
		prompt.ActionText = "View"
	end

	local panel = buildPanel(anchor, facility)
	trove:Add(panel)
end

function FacilityController:Init()
	self._trove = Trove.new()
end

function FacilityController:Start()
	for _, instance in CollectionService:GetTagged(FACILITY_TAG) do
		setupFacility(instance, self._trove)
	end

	CollectionService:GetInstanceAddedSignal(FACILITY_TAG):Connect(function(instance)
		setupFacility(instance, self._trove)
	end)
end

return FacilityController
