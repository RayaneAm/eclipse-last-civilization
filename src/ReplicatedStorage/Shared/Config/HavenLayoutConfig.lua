--!strict
-- Single source of truth for where Haven's functional areas sit relative to
-- the plaza. Consumed by tools/BuildHavenDistricts.luau's facility loop and
-- tools/Generators/HavenPlatformGenerator.luau's gate/watchtower placement,
-- and by tools/BuildSurvivorHaven.luau's spawn/leaderboard/camera sweep.
--
-- Survivor Haven redesign Phase 1 (hub layout blockout): replaced the old
-- full 360deg radial ring (4 gates at cardinal angles, 4 "districts" evenly
-- spaced at the bisecting angles, spawn dead-center) with an amphitheater —
-- the player arrives at the edge facing inward, the 4 portals sit clustered
-- in a tight arc ahead, facilities flank left/right between arrival and the
-- portal arc. HAVEN_PLAZA_RADIUS also shrank 165 -> 140 in this same pass
-- (see WorldMapConfig.HAVEN_PLAZA_RADIUS) so every angle/radius below is
-- already computed at the final hub scale — not a placeholder to revisit.
--
-- DistrictId/Districts/GetDistrict are kept (every real consumer —
-- CivicBuildingGenerator, QuestGiverController, DialogueController — only
-- ever reads .accentColor/.name, never a position) purely as a small
-- accent-color/label lookup; the old ring-position math
-- (GetDistrictCenter/GetBuildingPosition/GetPromenadePosition and the
-- DISTRICT_RING_RADIUS/DISTRICT_BUILDING_SPREAD_DEGREES/PROMENADE_* constants
-- that fed them) is gone — facility placement is now direct angle/radius per
-- facility (see HavenFacilityConfig.luau), not derived from a shared ring.

export type DistrictId = "Onboarding" | "Progression" | "Commerce" | "EventSeason"

local HavenLayoutConfig = {}

-- Facing convention: 0deg = "north," the direction from the plaza toward the
-- portal arc (WorldMapConfig.DirectionForAngle's existing rotation
-- convention: positive angle = the observer's left when facing 0deg).
-- Origin (WorldMapConfig.WORLD_ORIGIN) stays the hub's true center.

-- Portal arc: 30deg spacing, 90deg total span, at the wall radius
-- (WorldMapConfig.HAVEN_PLAZA_RADIUS = 140) — order 1..4 (Forest..Volcanic,
-- see BiomeConfig) map left-to-right when facing north from spawn.
HavenLayoutConfig.GATE_ARC_HALF_SPAN_DEGREES = 45
HavenLayoutConfig.GATE_ARC_STEP_DEGREES = 30

function HavenLayoutConfig.GateAngleForOrder(order: number): number
	return HavenLayoutConfig.GATE_ARC_HALF_SPAN_DEGREES - (order - 1) * HavenLayoutConfig.GATE_ARC_STEP_DEGREES
end

-- Watchtowers: 2, flanking the arc just outside the outermost gates (45deg),
-- not colliding with them.
HavenLayoutConfig.WATCHTOWER_ANGLES_DEGREES = { -70, 70 }

-- Spawn: the far edge (south, 180deg), facing the origin. Radius 110 leaves
-- a 30-stud clear buffer to the wall (140) — enough for several simultaneous
-- spawns without a cavernous empty ring.
HavenLayoutConfig.SPAWN_ANGLE_DEGREES = 180
HavenLayoutConfig.SPAWN_RADIUS = 110

-- Central Arrival Core: unchanged from the previous pass — the canopy/dais
-- footprint (radius ~32-40) sits well inside every repositioned facility's
-- own radius (closest is 63), so it doesn't need to rescale with the rest of
-- the hub for this phase.
HavenLayoutConfig.CENTRAL_ARRIVAL_RADIUS = 32

export type DistrictDefinition = {
	id: DistrictId,
	name: string,
	accentColor: Color3,
}

HavenLayoutConfig.Districts = {
	{ id = "Onboarding", name = "Onboarding District", accentColor = Color3.fromRGB(120, 220, 140) },
	{ id = "Progression", name = "Progression District", accentColor = Color3.fromRGB(100, 200, 255) },
	{ id = "Commerce", name = "Commerce District", accentColor = Color3.fromRGB(255, 200, 100) },
	{ id = "EventSeason", name = "Event & Season District", accentColor = Color3.fromRGB(210, 130, 255) },
} :: { DistrictDefinition }

function HavenLayoutConfig.GetDistrict(id: DistrictId): DistrictDefinition
	for _, district in HavenLayoutConfig.Districts do
		if district.id == id then
			return district
		end
	end
	error(`HavenLayoutConfig: unknown district "{id}"`)
end

return HavenLayoutConfig
