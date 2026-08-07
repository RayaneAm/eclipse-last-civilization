--!strict
-- Single source of truth for the macro world layout: where Survivor Haven's
-- geometry ends and generated terrain begins, and each biome's wedge
-- direction/extent/elevation identity. Consumed by:
--   * tools/Generators/HavenPlatformGenerator.luau + GateGenerator.luau (seam radius)
--   * tools/Generators/TerrainGenerator.luau + LandmarkGenerator.luau (what to build, where)
--   * src/server/Services/RegionService.luau (which biome a player is standing in)
--
-- Elevation profile numbers are first-pass values — expect to retune
-- amplitude/radius after the first real playtest at this scale (see Prompt 2
-- plan's Verification section).

local BiomeConfig = require(script.Parent.BiomeConfig)

local WorldMapConfig = {}

-- Survivor Haven's own world-space origin. tools/BuildSurvivorHaven.luau
-- builds relative to this. Real biome terrain no longer radiates from here
-- (see RealOrigin below) — only Haven itself (the colosseum wall, portals,
-- and their threshold dressing) stays at this origin.
WorldMapConfig.WORLD_ORIGIN = CFrame.new(0, 0, 0)

-- Must match HavenPlatformGenerator's plaza radius exactly — this is now the
-- shared source both that file and GateGenerator reference.
WorldMapConfig.HAVEN_PLAZA_RADIUS = 140

-- Portal architecture (Prompt 2): each real biome's terrain, and the
-- Tutorial Zone, now lives at its OWN independent world-space origin, far
-- from Haven AND far from every other destination — not a shared distant
-- ring. Nearest pairwise distance between any two entries here is 20,000
-- studs; even the largest biome radius (Volcanic's 2600-stud outerRadius,
-- see ElevationProfiles) leaves well over 17,000 studs of clear space to its
-- nearest neighbor, comfortably beyond StreamingConfig's 512-stud
-- TargetRadius and enough headroom for future per-biome combat/enemy
-- systems to never overlap. PortalDestinationConfig.luau reads these.
WorldMapConfig.RealOrigin = {
	ForestWildlands = CFrame.new(20000, 0, 0),
	FrozenWasteland = CFrame.new(-20000, 0, 0),
	NuclearCity = CFrame.new(0, 0, 20000),
	VolcanicCore = CFrame.new(0, 0, -20000),
	Tutorial = CFrame.new(20000, 0, 20000),
} :: { [string]: CFrame }

-- Flat clearing radius around a destination's own arrival point, before
-- terrain begins ramping up to natural elevation (via SEAM_BLEND_DISTANCE
-- below) — the destination-local replacement for the old Haven-relative
-- BIOME_START_RADIUS, which specifically described the seam between Haven's
-- plaza and an adjacent biome wedge and no longer applies now that each
-- biome sits at its own independent origin with no Haven seam to blend from.
WorldMapConfig.ARRIVAL_CLEARING_RADIUS = 40

-- Frozen, historical bounds of the OLD near-Haven terrain footprint — built
-- back when biome terrain radiated directly out from WORLD_ORIGIN as 4
-- wedges. Deliberately NOT derived from HAVEN_PLAZA_RADIUS or any other
-- current config value: these numbers describe one specific past build, not
-- a formula that should track future changes, so a later radius/config
-- change can never accidentally resize (or shrink) the one-time migration
-- clear. See tools/MigrateNearHavenTerrain.luau — this is the only reader.
WorldMapConfig.LEGACY_NEAR_HAVEN_TERRAIN_INNER_RADIUS = 176
WorldMapConfig.LEGACY_NEAR_HAVEN_TERRAIN_OUTER_RADIUS = 2600

-- Half-width (degrees) of the opening left in the perimeter wall at each
-- gate. Moved here from HavenPlatformGenerator's private local (Prompt
-- 4A.1) so GateGenerator's physical barrier width can be computed from the
-- SAME number the wall breach itself uses — previously the barrier (sized
-- off the gate's decorative span, ~21 studs) was far narrower than the
-- actual breach opening (~97-stud chord at this angle and radius), leaving
-- a walk-around gap on each side that made "locked" gates not actually
-- physically block anyone.
WorldMapConfig.GATE_BREACH_DEGREES = 22

-- Distance beyond ARRIVAL_CLEARING_RADIUS (at a destination's own arrival
-- point) over which terrain height ramps from the flat clearing up to the
-- biome's natural elevation, so the join isn't a visible cliff. Consumed by
-- TerrainGenerator.buildCell.
WorldMapConfig.SEAM_BLEND_DISTANCE = 70

-- Terrain:FillRegion has a hard engine cap on how large a single region can
-- be ("Region is too large" if exceeded) — the whole map is thousands of
-- studs across, so TerrainGenerator must never hand it one giant region.
-- Instead it processes a grid of square chunks this size (horizontal X/Z;
-- MUST stay an exact multiple of TerrainGenerator's GRID_CELL_SIZE so
-- per-chunk cell loops tile the same global grid with no gaps/overlaps at
-- chunk seams), each well inside the safe range. Conservative on purpose —
-- this is a one-time build step, not a hot path.
WorldMapConfig.TERRAIN_CHUNK_SIZE = 256

-- Vertical range (relative to WORLD_ORIGIN) that terrain clearing covers.
-- Trimmed from a naive "cover everything" span to something that still
-- comfortably contains the lowest generated point (TerrainGenerator's
-- FLOOR_Y = -60) and the highest (the Volcanic caldera's outermost FillBall
-- layer tops out around baseHeight 30 + 320 + 110 = 460) with real margin,
-- without being any larger than it needs to be — every stud of unnecessary
-- vertical range multiplies every chunk's voxel count for no reason.
WorldMapConfig.TERRAIN_CLEAR_FLOOR_Y = -100
WorldMapConfig.TERRAIN_CLEAR_CEILING_Y = 550

export type ElevationProfile = {
	outerRadius: number,
	baseHeight: number,
	hillAmplitude: number,
	noiseFrequency: number,
	dominantMaterial: Enum.Material,
	secondaryMaterial: Enum.Material,
	landmarkDistanceFraction: number, -- 0..1 along the wedge (from BIOME_START_RADIUS to outerRadius) where the hero landmark sits
}

WorldMapConfig.ElevationProfiles = {
	ForestWildlands = {
		outerRadius = 1400,
		baseHeight = 20,
		hillAmplitude = 25,
		noiseFrequency = 0.006,
		dominantMaterial = Enum.Material.Grass,
		secondaryMaterial = Enum.Material.LeafyGrass,
		landmarkDistanceFraction = 0.55,
	} :: ElevationProfile,
	FrozenWasteland = {
		outerRadius = 1800,
		baseHeight = 15,
		hillAmplitude = 55,
		noiseFrequency = 0.004,
		dominantMaterial = Enum.Material.Snow,
		secondaryMaterial = Enum.Material.Ice,
		landmarkDistanceFraction = 0.6,
	} :: ElevationProfile,
	NuclearCity = {
		outerRadius = 2000,
		baseHeight = 10,
		hillAmplitude = 12,
		noiseFrequency = 0.01,
		dominantMaterial = Enum.Material.Concrete,
		secondaryMaterial = Enum.Material.Asphalt,
		landmarkDistanceFraction = 0.5,
	} :: ElevationProfile,
	VolcanicCore = {
		outerRadius = 2600,
		baseHeight = 30,
		hillAmplitude = 140,
		noiseFrequency = 0.003,
		dominantMaterial = Enum.Material.Basalt,
		secondaryMaterial = Enum.Material.CrackedLava,
		landmarkDistanceFraction = 0.85,
	} :: ElevationProfile,
} :: { [string]: ElevationProfile }

-- Biome.order (1..4) maps to a cardinal-ish angle around Haven — identical
-- math to HavenPlatformGenerator's angleForOrder, kept in sync deliberately
-- since both must agree on where each gate/wedge points.
function WorldMapConfig.AngleForOrder(order: number): number
	return math.rad((order - 1) * 90)
end

-- Low-level primitive: the horizontal world direction a Y-axis angle (in
-- radians) points toward, using the same "rotate local -Z" convention every
-- generator places gates/wedges/districts with. Exposed so other layout
-- config modules (e.g. HavenLayoutConfig) can share this instead of
-- reimplementing the CFrame math.
function WorldMapConfig.DirectionForAngle(angleRadians: number): Vector3
	return CFrame.Angles(0, angleRadians, 0):VectorToWorldSpace(Vector3.new(0, 0, -1))
end

function WorldMapConfig.DirectionForOrder(order: number): Vector3
	return WorldMapConfig.DirectionForAngle(WorldMapConfig.AngleForOrder(order))
end

-- World-space position of a biome's signature landmark (or, for Volcanic,
-- its terrain caldera) — shared by TerrainGenerator and LandmarkGenerator so
-- both agree on the same point without duplicating the formula. `origin` is
-- that biome's own RealOrigin (each biome is a standalone circular region
-- now, not a wedge sharing Haven's origin with 3 others), so `direction`
-- here is purely a "which way this landmark leans from center" convention,
-- not a real-world bearing from Haven.
function WorldMapConfig.GetLandmarkPosition(origin: CFrame, biome: { id: string, order: number }): Vector3
	local profile = WorldMapConfig.ElevationProfiles[biome.id]
	assert(profile, `WorldMapConfig: no elevation profile for biome "{biome.id}"`)

	local direction = WorldMapConfig.DirectionForOrder(biome.order)
	local radius = WorldMapConfig.ARRIVAL_CLEARING_RADIUS + (profile.outerRadius - WorldMapConfig.ARRIVAL_CLEARING_RADIUS) * profile.landmarkDistanceFraction

	return origin.Position + direction * radius
end

-- Given an absolute world position, returns which biome's independent
-- region it falls within (nil if it isn't inside any biome's own bounding
-- circle around its RealOrigin — e.g. standing in Haven, in transit, or in
-- the Tutorial Zone). Replaces the old Haven-relative angular-wedge version
-- of this function now that each biome sits at its own separate origin
-- rather than sharing one with the other 3.
function WorldMapConfig.GetRegionAt(worldPosition: Vector3): string?
	for _, biome in BiomeConfig do
		local origin = WorldMapConfig.RealOrigin[biome.id]
		local profile = WorldMapConfig.ElevationProfiles[biome.id]
		if origin and profile then
			local offset = worldPosition - origin.Position
			local flatDistance = Vector2.new(offset.X, offset.Z).Magnitude
			if flatDistance <= profile.outerRadius then
				return biome.id
			end
		end
	end
	return nil
end

return WorldMapConfig
