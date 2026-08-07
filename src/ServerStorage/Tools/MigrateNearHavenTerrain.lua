--!strict
-- One-time, self-gating migration: destroys the OLD near-Haven biome
-- terrain footprint (built back when biome terrain radiated directly out
-- from WorldMapConfig.WORLD_ORIGIN as 4 wedges) and never touches it again.
--
-- Deliberately NOT a "clear everything near Haven every rebuild" step — that
-- would eventually also destroy the new portal teasers, hand-edited terrain,
-- and anything else legitimately built near Haven in the future. Instead
-- this checks a persisted marker attribute on Workspace; once set, every
-- future call is an instant no-op, forever. Uses WorldMapConfig's frozen
-- LEGACY_NEAR_HAVEN_TERRAIN_INNER/OUTER_RADIUS constants (NOT the current
-- HAVEN_PLAZA_RADIUS-derived BIOME_START_RADIUS) so this always targets the
-- exact same historical bounds regardless of later config changes.
--
-- Run once as part of tools/BuildWorldMap.luau's pipeline, before any of the
-- new per-destination terrain is built.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldMapConfig = require(ReplicatedStorage.Shared.Config.WorldMapConfig)

local MARKER_ATTRIBUTE = "EclipseNearHavenTerrainMigrated"
local CHUNK_SIZE = WorldMapConfig.TERRAIN_CHUNK_SIZE

local MigrateNearHavenTerrain = {}

type ChunkBounds = { minX: number, maxX: number, minZ: number, maxZ: number }

-- Ring-shaped chunk grid: only chunks whose square overlaps the annulus
-- between the inner and outer legacy radii are cleared — skips the inner
-- disc entirely (that's Haven's own plaza/gates/teasers, never touched).
local function buildRingChunkGrid(innerRadius: number, outerRadius: number): { ChunkBounds }
	local chunks: { ChunkBounds } = {}
	local start = -math.ceil(outerRadius / CHUNK_SIZE) * CHUNK_SIZE
	local steps = math.ceil((outerRadius - start) / CHUNK_SIZE)

	for xi = 0, steps - 1 do
		local minX = start + xi * CHUNK_SIZE
		local maxX = minX + CHUNK_SIZE
		for zi = 0, steps - 1 do
			local minZ = start + zi * CHUNK_SIZE
			local maxZ = minZ + CHUNK_SIZE

			local closestX = math.clamp(0, minX, maxX)
			local closestZ = math.clamp(0, minZ, maxZ)
			local farthestX = if math.abs(minX) > math.abs(maxX) then minX else maxX
			local farthestZ = if math.abs(minZ) > math.abs(maxZ) then minZ else maxZ

			local closestDistance = Vector2.new(closestX, closestZ).Magnitude
			local farthestDistance = Vector2.new(farthestX, farthestZ).Magnitude

			-- Keep the chunk if its square overlaps the [inner, outer] ring at all.
			if closestDistance <= outerRadius and farthestDistance >= innerRadius then
				table.insert(chunks, { minX = minX, maxX = maxX, minZ = minZ, maxZ = maxZ })
			end
		end
	end

	return chunks
end

function MigrateNearHavenTerrain.Run()
	if Workspace:GetAttribute(MARKER_ATTRIBUTE) == true then
		print("[MigrateNearHavenTerrain] Already migrated — skipping (no-op).")
		return
	end

	print("[MigrateNearHavenTerrain] Clearing obsolete near-Haven biome terrain (one-time)...")

	local origin = WorldMapConfig.WORLD_ORIGIN
	local chunks = buildRingChunkGrid(
		WorldMapConfig.LEGACY_NEAR_HAVEN_TERRAIN_INNER_RADIUS,
		WorldMapConfig.LEGACY_NEAR_HAVEN_TERRAIN_OUTER_RADIUS
	)

	local Terrain = Workspace.Terrain :: Terrain
	for index, chunk in chunks do
		local region = Region3.new(
			origin.Position + Vector3.new(chunk.minX, WorldMapConfig.TERRAIN_CLEAR_FLOOR_Y, chunk.minZ),
			origin.Position + Vector3.new(chunk.maxX, WorldMapConfig.TERRAIN_CLEAR_CEILING_Y, chunk.maxZ)
		):ExpandToGrid(4)

		local ok, err = pcall(function()
			Terrain:FillRegion(region, 4, Enum.Material.Air)
		end)
		if not ok then
			warn(`MigrateNearHavenTerrain: failed clearing chunk {index}/{#chunks}: {err}`)
		end

		if index % 4 == 0 or index == #chunks then
			print(`[MigrateNearHavenTerrain] Clearing chunk {index}/{#chunks}`)
			task.wait()
		end
	end

	Workspace:SetAttribute(MARKER_ATTRIBUTE, true)
	print("[MigrateNearHavenTerrain] Done — marker set, this will never run again.")
end

return MigrateNearHavenTerrain
