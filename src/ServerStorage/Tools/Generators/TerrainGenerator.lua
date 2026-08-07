--!strict
-- Sculpts the macro terrain for ONE biome's standalone hidden region, using
-- Terrain:FillBlock/FillBall/FillCylinder (not per-voxel WriteVoxels — see
-- Prompt 2 plan decision #3) driven by Luau's native math.noise. This is a
-- GREYBOX pass: real per-biome hand-sculpting happens in Studio's Terrain
-- Editor afterward and is expected to replace these numbers, not preserve
-- them forever.
--
-- Portal architecture (Prompt 2): each biome now generates as a standalone
-- full circle around its OWN independent WorldMapConfig.RealOrigin entry,
-- not as a 90° wedge sharing Haven's origin with the other 3 biomes — the
-- old wedge/angle-partitioning logic (closestBiome) is retired along with
-- it, since a single call now only ever owns the one biome it was asked to
-- build. tools/BuildWorldMap.luau calls TerrainGenerator.Build once per
-- biome, each with that biome's own RealOrigin.
--
-- CAUTION: unlike the Part-based generators in this folder, Terrain has no
-- per-object namespace to "graduate" hand edits out of harm's way —
-- regenerating always clears the whole bounding region back to Air first.
-- Only re-run this after hand-sculpting has begun if losing those edits is
-- acceptable.
--
-- CHUNKING: Terrain:FillRegion has a hard engine cap on single-call region
-- size ("Region is too large" if exceeded — a single biome's outerRadius is
-- thousands of studs across, way past it). Both clearing and the base
-- height-pass are processed as a grid of WorldMapConfig.TERRAIN_CHUNK_SIZE
-- square chunks instead of one giant operation. FillBlock/FillBall/
-- FillCylinder (used everywhere else here) take a center+size/radius, not a
-- Region3, and aren't subject to the same cap — those don't need chunking.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BiomeConfig = require(ReplicatedStorage.Shared.Config.BiomeConfig)
local WorldMapConfig = require(ReplicatedStorage.Shared.Config.WorldMapConfig)

local Terrain = Workspace.Terrain :: Terrain

local GRID_CELL_SIZE = 32 -- studs; coarse on purpose for a first greybox pass
local FLOOR_Y = -60 -- solid ground safety margin below the lowest possible surface
local HILL_STAMPS_PER_BIOME = 12
local HILL_RADIUS_MIN = 90
local HILL_RADIUS_MAX = 200
local HILL_ANGLE_SPREAD_DEGREES = 35 -- keeps hill stamps comfortably inside the biome's own 90° wedge

local CHUNK_SIZE = WorldMapConfig.TERRAIN_CHUNK_SIZE
local CHUNK_YIELD_EVERY = 4 -- chunks between task.wait() calls

assert(CHUNK_SIZE % GRID_CELL_SIZE == 0, "TerrainGenerator: TERRAIN_CHUNK_SIZE must be an exact multiple of GRID_CELL_SIZE")

local TerrainGenerator = {}

type ChunkBounds = { minX: number, maxX: number, minZ: number, maxZ: number }

-- Builds a grid of horizontal square chunks covering [-extent, extent]^2
-- (aligned so chunk edges always land on multiples of CHUNK_SIZE), skipping
-- any chunk whose closest point to the origin is already beyond `extent` —
-- the generated area is a circle inscribed in that square, so this prunes
-- the corner chunks that would do no work.
local function buildChunkGrid(extent: number): { ChunkBounds }
	local chunks: { ChunkBounds } = {}
	local start = -math.ceil(extent / CHUNK_SIZE) * CHUNK_SIZE
	local steps = math.ceil((extent - start) / CHUNK_SIZE)

	for xi = 0, steps - 1 do
		local minX = start + xi * CHUNK_SIZE
		local maxX = minX + CHUNK_SIZE
		for zi = 0, steps - 1 do
			local minZ = start + zi * CHUNK_SIZE
			local maxZ = minZ + CHUNK_SIZE

			local closestX = math.clamp(0, minX, maxX)
			local closestZ = math.clamp(0, minZ, maxZ)
			if Vector2.new(closestX, closestZ).Magnitude <= extent then
				table.insert(chunks, { minX = minX, maxX = maxX, minZ = minZ, maxZ = maxZ })
			end
		end
	end

	return chunks
end

-- Exposed (not just a local) so the "Clear Generated World" Studio plugin
-- button can wipe exactly the region this generator owns, instead of a
-- blanket Terrain:Clear() that would also destroy anything outside it.
-- Uses the SAME chunked-grid technique as generation — never one oversized
-- FillRegion call. `extent` is the caller's own bounding radius (usually
-- that biome's outerRadius + margin) — each biome now clears only its own
-- standalone region around its own origin, never a shared global extent.
function TerrainGenerator.ClearGeneratedRegion(origin: CFrame, extent: number)
	local chunks = buildChunkGrid(extent)

	for index, chunk in chunks do
		local region = Region3.new(
			origin.Position + Vector3.new(chunk.minX, WorldMapConfig.TERRAIN_CLEAR_FLOOR_Y, chunk.minZ),
			origin.Position + Vector3.new(chunk.maxX, WorldMapConfig.TERRAIN_CLEAR_CEILING_Y, chunk.maxZ)
		):ExpandToGrid(4)

		local ok, err = pcall(function()
			Terrain:FillRegion(region, 4, Enum.Material.Air)
		end)
		if not ok then
			warn(`TerrainGenerator: failed clearing chunk {index}/{#chunks} (X {chunk.minX}..{chunk.maxX}, Z {chunk.minZ}..{chunk.maxZ}): {err}`)
		end

		if index % CHUNK_YIELD_EVERY == 0 or index == #chunks then
			print(`[TerrainGenerator] Clearing chunk {index}/{#chunks}`)
			task.wait()
		end
	end
end

-- Fills one GRID_CELL_SIZE column of this standalone biome's terrain, if it
-- falls within [startRadius, profile.outerRadius] of `origin` — unchanged
-- height/blend/material formulas from the original wedge-based version, just
-- with the old closest-biome angular test removed entirely: since each
-- biome now owns its own independent origin with nothing else nearby, every
-- cell in range simply belongs to it, no comparison needed.
local function buildCell(origin: CFrame, worldX: number, worldZ: number, startRadius: number, profile: WorldMapConfig.ElevationProfile)
	local flatDistance = Vector2.new(worldX, worldZ).Magnitude
	if flatDistance < startRadius or flatDistance > profile.outerRadius then
		return
	end

	local worldPos = origin.Position + Vector3.new(worldX, 0, worldZ)
	local noiseVal = math.noise(worldPos.X * profile.noiseFrequency, worldPos.Z * profile.noiseFrequency, 0)
	local rawHeight = profile.baseHeight + noiseVal * profile.hillAmplitude
	local blend = math.clamp((flatDistance - startRadius) / WorldMapConfig.SEAM_BLEND_DISTANCE, 0, 1)
	local surfaceY = 1 + (rawHeight - 1) * blend

	local columnHeight = surfaceY - FLOOR_Y
	Terrain:FillBlock(
		CFrame.new(worldPos.X, FLOOR_Y + columnHeight / 2, worldPos.Z),
		Vector3.new(GRID_CELL_SIZE * 1.05, columnHeight, GRID_CELL_SIZE * 1.05),
		profile.dominantMaterial
	)
end

-- Builds this biome's base height-pass, chunk by chunk, around its own
-- independent origin.
local function buildBasePass(origin: CFrame, biome: BiomeConfig.BiomeDefinition, profile: WorldMapConfig.ElevationProfile, startRadius: number)
	local chunks = buildChunkGrid(profile.outerRadius)

	for index, chunk in chunks do
		local ok, err = pcall(function()
			for worldX = chunk.minX, chunk.maxX, GRID_CELL_SIZE do
				for worldZ = chunk.minZ, chunk.maxZ, GRID_CELL_SIZE do
					buildCell(origin, worldX, worldZ, startRadius, profile)
				end
			end
		end)
		if not ok then
			warn(`TerrainGenerator: failed building {biome.name} chunk {index}/{#chunks} (X {chunk.minX}..{chunk.maxX}, Z {chunk.minZ}..{chunk.maxZ}): {err}`)
		end

		if index % CHUNK_YIELD_EVERY == 0 or index == #chunks then
			print(`[TerrainGenerator] Building {biome.name} chunk {index}/{#chunks}`)
			task.wait()
		end
	end
end

local function buildHillStamps(origin: CFrame, biome: BiomeConfig.BiomeDefinition, profile: WorldMapConfig.ElevationProfile, rng: Random)
	local direction = WorldMapConfig.DirectionForOrder(biome.order)

	for _ = 1, HILL_STAMPS_PER_BIOME do
		local angleOffset = math.rad(rng:NextNumber(-HILL_ANGLE_SPREAD_DEGREES, HILL_ANGLE_SPREAD_DEGREES))
		local sampleDirection = CFrame.Angles(0, angleOffset, 0):VectorToWorldSpace(direction)
		local radius = rng:NextNumber(WorldMapConfig.ARRIVAL_CLEARING_RADIUS + WorldMapConfig.SEAM_BLEND_DISTANCE, profile.outerRadius * 0.9)
		local position = origin.Position + sampleDirection * radius

		local hillRadius = rng:NextNumber(HILL_RADIUS_MIN, HILL_RADIUS_MAX) * (profile.hillAmplitude / 40)
		local material = if rng:NextNumber() < 0.3 then profile.secondaryMaterial else profile.dominantMaterial

		Terrain:FillBall(Vector3.new(position.X, profile.baseHeight, position.Z), hillRadius, material)
	end
end

-- Frozen Wasteland gets a large flat frozen lake basin off to one side of
-- its wedge, breaking up the jagged-peaks silhouette with breathing room.
local function buildFrozenLakeBasin(origin: CFrame, biome: BiomeConfig.BiomeDefinition, profile: WorldMapConfig.ElevationProfile, rng: Random)
	local direction = WorldMapConfig.DirectionForOrder(biome.order)
	local angleOffset = math.rad(rng:NextNumber(-25, 25))
	local sampleDirection = CFrame.Angles(0, angleOffset, 0):VectorToWorldSpace(direction)
	local radius = profile.outerRadius * 0.4
	local position = origin.Position + sampleDirection * radius

	Terrain:FillCylinder(CFrame.new(position.X, profile.baseHeight - 4, position.Z), 10, 220, Enum.Material.Ice)
end

-- Nuclear City gets a handful of shallow bomb-crater dips in its plateau.
local function buildNuclearCraters(origin: CFrame, biome: BiomeConfig.BiomeDefinition, profile: WorldMapConfig.ElevationProfile, rng: Random)
	local direction = WorldMapConfig.DirectionForOrder(biome.order)

	for _ = 1, 5 do
		local angleOffset = math.rad(rng:NextNumber(-40, 40))
		local sampleDirection = CFrame.Angles(0, angleOffset, 0):VectorToWorldSpace(direction)
		local radius = rng:NextNumber(WorldMapConfig.ARRIVAL_CLEARING_RADIUS + 150, profile.outerRadius * 0.85)
		local position = origin.Position + sampleDirection * radius

		Terrain:FillBall(Vector3.new(position.X, profile.baseHeight - 6, position.Z), rng:NextNumber(30, 60), Enum.Material.Air)
		Terrain:FillBall(Vector3.new(position.X, profile.baseHeight - 8, position.Z), rng:NextNumber(30, 60), Enum.Material.Ground)
	end
end

-- Volcanic Core's caldera: the tallest point in the world and that biome's
-- landmark (see LandmarkGenerator, which deliberately builds nothing for
-- Volcanic — this IS its landmark). Built from stacked, narrowing FillBall
-- stamps for a mountain silhouette, then an Air carve for the crater and a
-- CrackedLava fill for the glowing floor.
local function buildVolcanicCaldera(origin: CFrame, biome: BiomeConfig.BiomeDefinition, profile: WorldMapConfig.ElevationProfile)
	local peak = WorldMapConfig.GetLandmarkPosition(origin, biome)

	local layers = {
		{ heightOffset = 0, radius = 420, material = profile.dominantMaterial },
		{ heightOffset = 120, radius = 300, material = profile.dominantMaterial },
		{ heightOffset = 230, radius = 190, material = profile.dominantMaterial },
		{ heightOffset = 320, radius = 110, material = profile.dominantMaterial },
	}

	for _, layer in layers do
		Terrain:FillBall(Vector3.new(peak.X, profile.baseHeight + layer.heightOffset, peak.Z), layer.radius, layer.material)
	end

	-- Crater carve + glowing lava floor at the summit.
	local craterY = profile.baseHeight + 360
	Terrain:FillBall(Vector3.new(peak.X, craterY, peak.Z), 70, Enum.Material.Air)
	Terrain:FillCylinder(CFrame.new(peak.X, craterY - 55, peak.Z), 20, 65, profile.secondaryMaterial)
end

local function buildBiomeFeatures(origin: CFrame, biome: BiomeConfig.BiomeDefinition, profile: WorldMapConfig.ElevationProfile)
	local rng = Random.new(#biome.id * 131 + 7)

	local ok, err = pcall(function()
		buildHillStamps(origin, biome, profile, rng)

		if biome.id == "FrozenWasteland" then
			buildFrozenLakeBasin(origin, biome, profile, rng)
		elseif biome.id == "NuclearCity" then
			buildNuclearCraters(origin, biome, profile, rng)
		elseif biome.id == "VolcanicCore" then
			buildVolcanicCaldera(origin, biome, profile)
		end
	end)
	if not ok then
		warn(`TerrainGenerator: failed building {biome.name} features (hills/lake/craters/caldera): {err}`)
	end
end

-- Builds ONE biome's standalone terrain around its own independent origin
-- (see WorldMapConfig.RealOrigin) — full circle out to profile.outerRadius,
-- no wedge partitioning, since nothing else shares this origin.
function TerrainGenerator.Build(origin: CFrame, biome: BiomeConfig.BiomeDefinition)
	local profile = WorldMapConfig.ElevationProfiles[biome.id]
	assert(profile, `TerrainGenerator: no elevation profile for biome "{biome.id}"`)

	TerrainGenerator.ClearGeneratedRegion(origin, profile.outerRadius + 50)
	buildBasePass(origin, biome, profile, WorldMapConfig.ARRIVAL_CLEARING_RADIUS)
	buildBiomeFeatures(origin, biome, profile)
end

return TerrainGenerator
