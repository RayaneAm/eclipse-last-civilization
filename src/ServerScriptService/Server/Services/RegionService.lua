--!strict
-- Server-authoritative, coarse-interval region tracking. Not per-frame —
-- "which biome wedge is the player standing in" doesn't need that precision,
-- and polling ~1.5s apart for a handful of players is negligible. Fires
-- RegionChanged only on an actual change, so RegionAnnounceController never
-- gets spammed by repeat pushes while a player stands still.
--
-- Prompt 4A adds a locked-region backstop: BiomeGateService's PhysicsService
-- collision groups are the real barrier, but this poll loop already knows
-- exactly which biome wedge a player is standing in, so it's a cheap,
-- independent second check — if a player is somehow in a region their tier
-- hasn't unlocked (collision-group bypass, exploit, edge case), they're
-- teleported back to Haven. Reuses RegionAnnounceController's existing
-- "Returning to Survivor Haven" toast for free: teleporting back just makes
-- the next poll see region go back to nil, which already fires that toast.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local WorldMapConfig = require(ReplicatedStorage.Shared.Config.WorldMapConfig)
local HavenLayoutConfig = require(ReplicatedStorage.Shared.Config.HavenLayoutConfig)
local BiomeConfig = require(ReplicatedStorage.Shared.Config.BiomeConfig)
local ProgressionService = require(script.Parent.ProgressionService)

local POLL_INTERVAL = 1.5

local RegionService = {}

local lastRegionByPlayer: { [Player]: string? } = {}

local unlockTierByBiomeId: { [string]: number } = {}
for _, biome in BiomeConfig do
	unlockTierByBiomeId[biome.id] = biome.unlockTier
end

local function havenSpawnPosition(): Vector3
	local direction = WorldMapConfig.DirectionForAngle(math.rad(HavenLayoutConfig.SPAWN_ANGLE_DEGREES))
	return WorldMapConfig.WORLD_ORIGIN.Position + direction * HavenLayoutConfig.SPAWN_RADIUS + Vector3.new(0, 3, 0)
end

local function enforceUnlockedRegion(player: Player, rootPart: BasePart, region: string?)
	if not region then
		return
	end
	local requiredTier = unlockTierByBiomeId[region]
	if not requiredTier or ProgressionService.GetTier(player) >= requiredTier then
		return
	end

	rootPart.CFrame = CFrame.new(havenSpawnPosition())
end

local function pollPlayer(player: Player)
	local character = player.Character
	if not character then
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		return
	end

	-- Portal architecture (Prompt 2): GetRegionAt now takes an ABSOLUTE world
	-- position and checks it against each biome's own independent RealOrigin
	-- (not a Haven-relative offset checked against an angular wedge) — see
	-- WorldMapConfig.GetRegionAt's own updated header comment.
	local region = WorldMapConfig.GetRegionAt(rootPart.Position)

	if lastRegionByPlayer[player] ~= region then
		lastRegionByPlayer[player] = region
		Net.GetEvent("RegionChanged"):FireClient(player, region)
	end

	enforceUnlockedRegion(player, rootPart, region)
end

function RegionService:Init()
	Players.PlayerRemoving:Connect(function(player)
		lastRegionByPlayer[player] = nil
	end)
end

function RegionService:Start()
	while true do
		for _, player in Players:GetPlayers() do
			pollPlayer(player)
		end
		task.wait(POLL_INTERVAL)
	end
end

return RegionService
