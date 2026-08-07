--!strict
-- Phase 4A: personal-base placement, grid-slot allocation, and level-
-- progression tuning. Deliberately data-only (no Instances, no yielding) —
-- BaseService owns all the runtime/DataStore behavior that reads this.

local PersonalBaseConfig = {}

-- Collision-free slot -> world-origin mapping. `slot` is an atomically
-- assigned, durably persisted sequential integer (see BaseService), never a
-- hash of UserId — see the Phase 4A plan's "Collision-free origin
-- allocation" section for why a hash was rejected. Grid sits far beyond the
-- ~20,000-stud biome RealOrigin footprint (WorldMapConfig.luau), and
-- CellSize is comfortably larger than PlotBounds so neighboring plots can
-- never overlap or be walked between.
PersonalBaseConfig.GridOrigin = Vector3.new(200000, 0, 0)
PersonalBaseConfig.GridWidth = 500 -- cells per row before wrapping to the next row
PersonalBaseConfig.CellSize = 1000 -- studs between adjacent base plot centers

-- A base's own buildable footprint, centered on its plot origin. Comfortably
-- inside CellSize so no plot can ever reach a neighboring one.
PersonalBaseConfig.PlotBounds = {
	HalfWidth = 90,
	HalfDepth = 90,
}

-- Grid-snap increment for building placement.
PersonalBaseConfig.GridSize = 4

-- Protected zones, in the base's own LOCAL space (relative to its origin —
-- see PersonalBaseGenerator/BuildingService, which always work in local
-- coordinates and only ever compose with the resolved world origin at the
-- moment something is actually spawned). Nothing can be placed inside these.
-- Must match PersonalBaseGenerator.luau's own CORE_OFFSET constant exactly
-- — offset forward of the raw origin so the Core never overlaps the
-- arrival platform/return portal PortalDestinationGenerator builds AT the
-- raw origin.
PersonalBaseConfig.CoreLocalPosition = Vector3.new(0, 0, 45)
PersonalBaseConfig.CoreProtectedRadius = 16
PersonalBaseConfig.EntranceLocalPosition = Vector3.new(0, 0, -80)
PersonalBaseConfig.EntranceProtectedRadius = 12

-- Generic footprint clearance between any two placed structures. Superseded
-- by the footprint-AABB (well, footprint-circle — see BuildingService's
-- comment on why a conservative circle approximation was chosen over a
-- true oriented-rectangle test) overlap check in BuildingService.luau as of
-- Phase 4A.1; kept only as the fallback radius when a footprint size can't
-- be resolved for some reason.
PersonalBaseConfig.MinStructureSpacing = 6

-- Phase 4A.1: the one region freeform placement (BasePlacementController)
-- accepts structures in — core progression now goes through fixed
-- blueprint pads instead (see BlueprintLayoutConfig.luau). Deliberately
-- clear of the Core (CoreLocalPosition, Z=45), the entrance
-- (EntranceLocalPosition, Z=-80), every pad in BlueprintLayoutConfig, and
-- the radius-85 perimeter wall ring.
PersonalBaseConfig.FreeformZone = {
	MinX = 15,
	MaxX = 55,
	MinZ = -15,
	MaxZ = 15,
}

-- UI/HUD Visual Direction Pass: reserved for a FUTURE mailbox delivery
-- system (marketplace/trade item receipt) — location only, no pad, no
-- BuildingConfig entry, no RequestBuildBlueprint wiring this pass.
-- PersonalBaseGenerator draws a purely decorative "Coming Soon" prop here;
-- nothing reads or writes this position yet. Verified clear of every
-- existing pad/zone: Storage_1 (-25,0,18), DefenseControl_1 (-25,0,-10),
-- ResourceProcessor_1 (-40,0,-35), the Freeform Zone above, Core (Z=45),
-- and the entrance (Z=-80).
PersonalBaseConfig.MailboxReservedLocalPosition = Vector3.new(-35, 0, 5)

function PersonalBaseConfig.OriginForSlot(slot: number): CFrame
	local gridX = slot % PersonalBaseConfig.GridWidth
	local gridZ = slot // PersonalBaseConfig.GridWidth
	local offset = Vector3.new(gridX * PersonalBaseConfig.CellSize, 0, gridZ * PersonalBaseConfig.CellSize)
	return CFrame.new(PersonalBaseConfig.GridOrigin + offset)
end

-- Investment score weighting — Structural/decorative categories are cheap on
-- purpose so decoration spam can't be the fastest way to level a base (see
-- the brief's explicit warning).
PersonalBaseConfig.InvestmentPoints = {
	StructureBuilt = {
		Structural = 2,
		Utility = 5,
		Production = 6,
		Defense = 6,
		Civilization = 8,
	},
	StructureUpgraded = {
		Structural = 3,
		Utility = 8,
		Production = 10,
		Defense = 10,
		Civilization = 14,
	},
	CoreUpgrade = 25,
}

-- Level thresholds anchored at the 5 named tiers from the brief. Levels
-- between anchors are reached by linear interpolation of investment score.
local LEVEL_ANCHORS = {
	{ Level = 1, Score = 0 },
	{ Level = 10, Score = 400 },
	{ Level = 50, Score = 4000 },
	{ Level = 100, Score = 16000 },
	{ Level = 250, Score = 80000 },
}

function PersonalBaseConfig.LevelForScore(score: number): number
	if score <= LEVEL_ANCHORS[1].Score then
		return LEVEL_ANCHORS[1].Level
	end
	for i = 1, #LEVEL_ANCHORS - 1 do
		local lower, upper = LEVEL_ANCHORS[i], LEVEL_ANCHORS[i + 1]
		if score >= lower.Score and score <= upper.Score then
			local t = (score - lower.Score) / (upper.Score - lower.Score)
			return math.floor(lower.Level + (upper.Level - lower.Level) * t)
		end
	end
	return LEVEL_ANCHORS[#LEVEL_ANCHORS].Level
end

-- Building-count capacity derived from Level — a simple, tunable curve, not
-- meant to be final balance. Base raised to 18 (from 8) in Phase 4A.1: the
-- full starter blueprint-pad set (CivilizationCore + 8 Wall pads + 7 other
-- pads = 16 structures) must be buildable at Level 1 without capacity ever
-- blocking guided progression, plus headroom for a few Freeform Zone pieces.
function PersonalBaseConfig.BuildingCapacityForLevel(level: number): number
	return 18 + level * 2
end

-- Power auto-disable priority when fuel runs short — first entries disable
-- first. Not a wiring/circuit simulation, just an ordered preference list.
PersonalBaseConfig.PowerShutoffPriority = { "Lighting", "Crafting", "Production", "Shields", "Defense" }

return PersonalBaseConfig
