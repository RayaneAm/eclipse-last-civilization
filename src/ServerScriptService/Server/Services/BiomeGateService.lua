--!strict
-- Server-authoritative biome gate lock state AND physical blocking.
-- Progression is now owned by ProgressionService (Prompt 4A) — this service
-- only reads it. Public remote surface is RequestGateStatus, GateActivated;
-- onTierChanged (Prompt 4C) is what actually fires GateActivated, once per
-- biome a tier change newly crosses. This service owns lock/unlock STATE and
-- collision only — actual travel is PortalService's job (Prompt 2), which
-- reads ProgressionService.GetTier the same way this file does rather than
-- duplicating the check. The old RequestGateUnlock remote (dead — confirmed
-- zero callers anywhere in the client) was removed once PortalService's
-- RequestPortalTravel became the real client-facing entry point.
--
-- Physical blocking: each gate's GateBarrier part (built by GateGenerator,
-- tagged "GateBarrier" + BiomeId) sits in a "Barrier_<BiomeId>" PhysicsService
-- collision group. The Expedition security barrier (Portal Expedition Zone
-- rework) reuses this exact mechanism as one more group,
-- "Barrier_ExpeditionSecurity" — not a parallel system. 5 static
-- "PlayerTier_0".."PlayerTier_4" groups are registered once with a FIXED
-- collidability matrix against all 5 barrier groups (tier 0 collides with
-- every biome barrier plus the Expedition barrier = fully blocked; tier 4
-- collides with none) — that matrix never changes at runtime. What DOES
-- change is which group a player's character parts are assigned to, on
-- spawn and whenever their tier changes. This scales to any player count
-- with only 10 total collision groups, unlike a per-player-group design
-- (Roblox caps at 32 groups total, so per-player groups would hit that
-- ceiling around ~27 concurrent players).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local BiomeConfig = require(ReplicatedStorage.Shared.Config.BiomeConfig)
local ProgressionService = require(script.Parent.ProgressionService)

local BiomeGateService = {}

local BARRIER_TAG = "GateBarrier"
local MAX_TIER = 4 -- highest unlockTier in BiomeConfig (Volcanic) — see Prompt 4A plan §5

-- Portal Expedition Zone rework: the Eclipse security checkpoint across the
-- shared approach to the 4-portal arc. Not a duplicate tutorial system —
-- it reuses the exact same tier threshold Forest's own GateBarrier already
-- gates on (BiomeConfig.ForestWildlands.unlockTier = 1, granted by
-- QuestConfig.TutorialQuest.rewardTier = 1), just as one more row in this
-- same fixed collision matrix instead of a parallel mechanism.
local EXPEDITION_BARRIER_TAG = "ExpeditionSecurityBarrier"
local EXPEDITION_BARRIER_GROUP = "Barrier_ExpeditionSecurity"
local EXPEDITION_BARRIER_UNLOCK_TIER = 1

type GateStatus = { id: string, unlocked: boolean, unlockTier: number }

-- ---------------------------------------------------------------------
-- Collision groups
-- ---------------------------------------------------------------------

local function barrierGroupName(biomeId: string): string
	return `Barrier_{biomeId}`
end

local function playerTierGroupName(tier: number): string
	return `PlayerTier_{math.clamp(tier, 0, MAX_TIER)}`
end

local function registerGroup(name: string)
	local ok, err = pcall(function()
		PhysicsService:RegisterCollisionGroup(name)
	end)
	if not ok and not tostring(err):find("already exists") then
		warn(`BiomeGateService: failed to register collision group "{name}": {err}`)
	end
end

local function setupCollisionGroups()
	for _, biome in BiomeConfig do
		registerGroup(barrierGroupName(biome.id))
	end
	registerGroup(EXPEDITION_BARRIER_GROUP)
	for tier = 0, MAX_TIER do
		registerGroup(playerTierGroupName(tier))
	end

	-- Fixed matrix: a player's tier group collides with a biome's barrier
	-- group only while that tier hasn't cleared the biome's unlockTier.
	for tier = 0, MAX_TIER do
		local tierGroup = playerTierGroupName(tier)
		for _, biome in BiomeConfig do
			local blocked = tier < biome.unlockTier
			PhysicsService:CollisionGroupSetCollidable(tierGroup, barrierGroupName(biome.id), blocked)
		end
		PhysicsService:CollisionGroupSetCollidable(tierGroup, EXPEDITION_BARRIER_GROUP, tier < EXPEDITION_BARRIER_UNLOCK_TIER)
	end
end

local function assignBarrierGroup(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local biomeId = instance:GetAttribute("BiomeId")
	if typeof(biomeId) == "string" then
		instance.CollisionGroup = barrierGroupName(biomeId)
	end
end

local function assignExpeditionBarrierGroup(instance: Instance)
	if instance:IsA("BasePart") then
		instance.CollisionGroup = EXPEDITION_BARRIER_GROUP
	end
end

-- Tracks each live character's CURRENT tier group name so the single
-- DescendantAdded connection made at spawn (accessories added later, e.g.
-- a future equipped-tool viewmodel) always applies whatever the character's
-- latest group is, not a stale one captured at connect-time.
local characterTierGroup: { [Model]: string } = {}

local function applyGroupToAllParts(character: Model, groupName: string)
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = groupName
		end
	end
end

-- Purely for the debug log — lists which biomes a tier can physically walk
-- through, so a barrier "opening" is directly observable in Output.
local function describeUnlockedBiomes(tier: number): string
	local names = {}
	for _, biome in BiomeConfig do
		if tier >= biome.unlockTier then
			table.insert(names, biome.name)
		end
	end
	if #names == 0 then
		return "none"
	end
	return table.concat(names, ", ")
end

local function onCharacterAdded(player: Player, character: Model)
	local tier = ProgressionService.GetTier(player)
	local groupName = playerTierGroupName(tier)
	characterTierGroup[character] = groupName
	applyGroupToAllParts(character, groupName)
	print(`[BiomeGateService] {player.Name} spawned at Tier {tier} ({groupName}) — barriers open for: {describeUnlockedBiomes(tier)}`)

	character.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") then
			local currentGroup = characterTierGroup[character]
			if currentGroup then
				descendant.CollisionGroup = currentGroup
			end
		end
	end)

	character.AncestryChanged:Connect(function(_, parent)
		if not parent then
			characterTierGroup[character] = nil
		end
	end)
end

-- Prompt 4C bugfix: this was the only place a tier crossing was ever supposed
-- to tell the client a gate opened, but it only ever reassigned the physical
-- collision group — nothing anywhere called the RequestGateUnlock remote
-- (confirmed zero callers), so GateActivated never actually fired and a
-- newly-unlocked gate stayed physically walkable while still LOOKING locked
-- (stale panel text, un-faded barrier). Firing GateActivated here, once per
-- biome newly crossed by this tier change, is what the client-side visuals
-- were always supposed to react to.
local function onTierChanged(player: Player, tier: number, previousTier: number)
	local character = player.Character
	if character then
		local groupName = playerTierGroupName(tier)
		characterTierGroup[character] = groupName
		applyGroupToAllParts(character, groupName)
		print(`[BiomeGateService] {player.Name} reassigned to Tier {tier} ({groupName}) — barriers now open for: {describeUnlockedBiomes(tier)}`)
	end

	for _, biome in BiomeConfig do
		if biome.unlockTier > previousTier and biome.unlockTier <= tier then
			print(`[BiomeGateService] {player.Name} newly unlocked gate "{biome.name}" via Tier {previousTier} -> {tier}`)
			Net.GetEvent("GateActivated"):FireClient(player, biome.id)
		end
	end
end

-- ---------------------------------------------------------------------
-- Gate status / unlock remotes (unchanged surface from Prompt 1)
-- ---------------------------------------------------------------------

local function buildStatusFor(player: Player): { GateStatus }
	local tier = ProgressionService.GetTier(player)

	local statuses = {}
	for _, biome in BiomeConfig do
		table.insert(statuses, {
			id = biome.id,
			unlocked = tier >= biome.unlockTier,
			unlockTier = biome.unlockTier,
		})
	end
	return statuses
end

function BiomeGateService:Init()
	setupCollisionGroups()

	for _, instance in CollectionService:GetTagged(BARRIER_TAG) do
		assignBarrierGroup(instance)
	end
	CollectionService:GetInstanceAddedSignal(BARRIER_TAG):Connect(assignBarrierGroup)

	for _, instance in CollectionService:GetTagged(EXPEDITION_BARRIER_TAG) do
		assignExpeditionBarrierGroup(instance)
	end
	CollectionService:GetInstanceAddedSignal(EXPEDITION_BARRIER_TAG):Connect(assignExpeditionBarrierGroup)

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
		if player.Character then
			onCharacterAdded(player, player.Character)
		end
	end)

	ProgressionService.TierChanged:Connect(onTierChanged)

	Net.GetFunction("RequestGateStatus").OnServerInvoke = function(player: Player)
		return buildStatusFor(player)
	end
end

return BiomeGateService
