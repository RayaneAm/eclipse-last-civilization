--!strict
-- Portal Expedition Zone rework: per-player PRESENTATION only for the
-- Eclipse security checkpoint. The real, per-player collision block comes
-- entirely from BiomeGateService's "Barrier_ExpeditionSecurity" PhysicsService
-- group (server-authoritative — every player's character is already
-- reassigned to PlayerTier_<their tier> by BiomeGateService, unchanged by
-- this file) — this controller never touches collision, only how the
-- checkpoint LOOKS to the local player once they've completed the
-- tutorial. Reuses the existing RequestGateStatus remote (already returns
-- ForestWildlands.unlocked, the same Tier >= 1 threshold tutorial
-- completion grants) rather than adding a new remote or a duplicate
-- tutorial-tracking system.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local Trove = require(ReplicatedStorage.Shared.Modules.Trove)

local BARRIER_TAG = "ExpeditionSecurityBarrier"
local PULSE_TAG = "AmbientPulse"
local SIGN_TAG = "ExpeditionCheckpointSign"
local TUTORIAL_GATE_BIOME_ID = "ForestWildlands"

local ExpeditionBarrierController = {}

local fadeTargets: { BasePart } = {}
local signBillboard: BillboardGui? = nil
local isFaded = false

-- Playtest correction: the "TUTORIAL REQUIRED" warning kept showing after
-- tutorial completion because collectFadeTargets only ever walked BARRIER_TAG/
-- PULSE_TAG BasePart descendants — the sign's BillboardGui/TextLabels aren't
-- BaseParts and were never tagged, so they were structurally unreachable from
-- applyFade below. ExpeditionBarrierGenerator.buildSign now tags the
-- BillboardGui itself with SIGN_TAG so it can be found the same way.
local function findSignBillboard(): BillboardGui?
	for _, instance in CollectionService:GetTagged(SIGN_TAG) do
		if instance:IsA("BillboardGui") then
			return instance
		end
	end
	return nil
end

-- The red field segments (tagged BARRIER_TAG) plus their sibling warning
-- stripes (tagged PULSE_TAG, within the same model) — the "active warning"
-- elements. Pylons/lights/sign are left alone: they stay visible as
-- permanent checkpoint architecture even for a player who's already
-- cleared it, only the glowing/blocking presentation fades.
local function collectFadeTargets(): { BasePart }
	local targets: { BasePart } = {}
	local seenModels: { [Instance]: boolean } = {}

	for _, instance in CollectionService:GetTagged(BARRIER_TAG) do
		if instance:IsA("BasePart") then
			table.insert(targets, instance)
			local model = instance:FindFirstAncestorOfClass("Model")
			if model and not seenModels[model] then
				seenModels[model] = true
				for _, descendant in model:GetDescendants() do
					if descendant:IsA("BasePart") and CollectionService:HasTag(descendant, PULSE_TAG) then
						table.insert(targets, descendant)
					end
				end
			end
		end
	end

	return targets
end

-- LocalTransparencyModifier is a client-only rendering override — it never
-- touches the real, server-authoritative Transparency (which stays whatever
-- ExpeditionBarrierGenerator built it as) and never affects collision. Only
-- this player's own view changes. Same principle now applies to the sign:
-- BillboardGui.Enabled set from this client Controller only changes what
-- THIS client renders — it isn't replicated to the server or other clients,
-- so one player unlocking never hides the warning for a still-Tier-0 player
-- on a different client.
local function applyFade(faded: boolean)
	if faded == isFaded then
		return
	end
	isFaded = faded

	if #fadeTargets == 0 then
		fadeTargets = collectFadeTargets()
	end

	for _, part in fadeTargets do
		part.LocalTransparencyModifier = if faded then 1 else 0
	end

	if not signBillboard then
		signBillboard = findSignBillboard()
	end
	if signBillboard then
		-- Locked (faded=false): billboard stays enabled — title and
		-- "TUTORIAL REQUIRED" both visible, its default built state.
		-- Unlocked (faded=true): fully disabled, so the subtitle disappears
		-- completely and the title hides too — no locked-state warning can
		-- remain floating in front of the portals.
		signBillboard.Enabled = not faded
	end
end

function ExpeditionBarrierController:Init()
	self._trove = Trove.new()
end

function ExpeditionBarrierController:Start()
	local ok, result = pcall(function()
		return Net.GetFunction("RequestGateStatus"):InvokeServer()
	end)

	if ok and typeof(result) == "table" then
		for _, entry in result do
			if entry.id == TUTORIAL_GATE_BIOME_ID then
				applyFade(entry.unlocked == true)
				break
			end
		end
	else
		warn("ExpeditionBarrierController: failed to fetch initial gate status", result)
	end

	-- Fires the moment this player individually crosses tier 1 — fades the
	-- checkpoint live, no rejoin needed.
	self._trove:Add(Net.GetEvent("GateActivated").OnClientEvent:Connect(function(biomeId: string)
		if biomeId == TUTORIAL_GATE_BIOME_ID then
			applyFade(true)
		end
	end))
end

return ExpeditionBarrierController
