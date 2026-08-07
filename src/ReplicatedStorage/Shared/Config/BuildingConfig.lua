--!strict
-- The single centralized building/recipe registry (Phase 4A) — BuildingService,
-- PowerService, and PersonalBaseGenerator all read this instead of any
-- per-script hardcoded cost/category logic. Starter structures only, one or
-- two per category plus a couple of higher-tier stubs to prove the upgrade
-- hook — not an exhaustive endgame catalog (see the Phase 4A plan's
-- "foundation only" scoping).

export type BuildingCost = {
	Materials: { [string]: number }, -- itemId -> quantity, keys from ResourceTierConfig/ResourceConfig
	Scrap: number,
}

export type BuildingCategory = "Structural" | "Utility" | "Production" | "Defense" | "Civilization"

export type BuildingDefinition = {
	Id: string,
	Name: string,
	Category: BuildingCategory,
	RequiredTier: number, -- ResourceTierConfig tier gate
	Cost: BuildingCost,
	PowerDraw: number, -- 0 for non-consumers
	PrerequisiteBuildingId: string?, -- must already exist in the base to build this
	NextTierBuildingId: string?, -- what RequestUpgradeBuilding turns this into
	-- Phase 4A.1: real footprint for AABB-vs-AABB overlap checks (replaces
	-- the old point-distance-only check). Optional — BuildingConfig.GetFootprintSize
	-- returns a sane generic default (matching the existing placeholder box
	-- size) for any entry that hasn't set one yet, so this is purely
	-- additive and changes no existing behavior until an entry opts in.
	FootprintSize: Vector3?,
}

local DEFAULT_FOOTPRINT = Vector3.new(6, 6, 6)

local BuildingConfig = {}

local definitions: { [string]: BuildingDefinition } = {
	-- Structural
	Foundation = {
		Id = "Foundation",
		Name = "Foundation",
		Category = "Structural",
		RequiredTier = 1,
		Cost = { Materials = { Stone = 10 }, Scrap = 0 },
		PowerDraw = 0,
	},
	Wall = {
		Id = "Wall",
		Name = "Wooden Wall",
		Category = "Structural",
		RequiredTier = 1,
		Cost = { Materials = { Wood = 15 }, Scrap = 0 },
		PowerDraw = 0,
		NextTierBuildingId = "ReinforcedWall",
	},
	ReinforcedWall = {
		Id = "ReinforcedWall",
		Name = "Reinforced Wall",
		Category = "Structural",
		RequiredTier = 2,
		Cost = { Materials = { Wood = 15, Iron = 20 }, Scrap = 60 },
		PowerDraw = 0,
		PrerequisiteBuildingId = "Wall",
	},
	Door = {
		Id = "Door",
		Name = "Wooden Door",
		Category = "Structural",
		RequiredTier = 1,
		Cost = { Materials = { Wood = 12, Fiber = 4 }, Scrap = 0 },
		PowerDraw = 0,
		NextTierBuildingId = "IronDoor",
	},
	IronDoor = {
		Id = "IronDoor",
		Name = "Iron Door",
		Category = "Structural",
		RequiredTier = 2,
		Cost = { Materials = { Iron = 25 }, Scrap = 80 },
		PowerDraw = 1,
		PrerequisiteBuildingId = "Door",
	},

	-- Phase 4A.1: the entrance blueprint pad's building — a real,
	-- upgradeable gate structure (the old entrance archway was pure
	-- decoration with nothing to build).
	EntranceGate = {
		Id = "EntranceGate",
		Name = "Entrance Gate",
		Category = "Structural",
		RequiredTier = 1,
		Cost = { Materials = { Wood = 25, Stone = 10 }, Scrap = 20 },
		PowerDraw = 0,
		FootprintSize = Vector3.new(14, 10, 4),
	},

	-- Utility
	Storage = {
		Id = "Storage",
		Name = "Storage Crate",
		Category = "Utility",
		RequiredTier = 1,
		Cost = { Materials = { Wood = 20, Stone = 10 }, Scrap = 0 },
		PowerDraw = 0,
	},
	Workbench = {
		Id = "Workbench",
		Name = "Workbench",
		Category = "Utility",
		RequiredTier = 1,
		Cost = { Materials = { Wood = 25, Stone = 5 }, Scrap = 0 },
		PowerDraw = 0,
	},
	Generator = {
		Id = "Generator",
		Name = "Basic Generator",
		Category = "Utility",
		RequiredTier = 1,
		Cost = { Materials = { Stone = 15, Fiber = 10 }, Scrap = 40 },
		PowerDraw = 0, -- a generator is the power SOURCE, not a consumer
	},
	RepairStation = {
		Id = "RepairStation",
		Name = "Repair Station",
		Category = "Utility",
		RequiredTier = 1,
		Cost = { Materials = { Wood = 15, Stone = 15 }, Scrap = 30 },
		PowerDraw = 1,
	},

	-- Production
	ResourceProcessor = {
		Id = "ResourceProcessor",
		Name = "Resource Processor",
		Category = "Production",
		RequiredTier = 1,
		Cost = { Materials = { Wood = 30, Stone = 20 }, Scrap = 80 },
		PowerDraw = 2,
	},

	-- Defense
	DefenseWall = {
		Id = "DefenseWall",
		Name = "Defensive Wall Segment",
		Category = "Defense",
		RequiredTier = 1,
		Cost = { Materials = { Wood = 20, Stone = 15 }, Scrap = 20 },
		PowerDraw = 0,
	},
	-- Phase 4A.1: promoted from a purely-decorative marker (buildDefenseControl)
	-- into a real blueprint-pad structure.
	DefenseControl = {
		Id = "DefenseControl",
		Name = "Defense Control",
		Category = "Defense",
		RequiredTier = 1,
		Cost = { Materials = { Stone = 20, Fiber = 10 }, Scrap = 40 },
		PowerDraw = 1,
		FootprintSize = Vector3.new(4, 5, 4),
	},

	-- Civilization
	CivilizationCore = {
		Id = "CivilizationCore",
		Name = "Civilization Core",
		Category = "Civilization",
		RequiredTier = 1,
		Cost = { Materials = {}, Scrap = 0 }, -- placed automatically at base creation, never bought
		PowerDraw = 0,
	},
	SurvivorQuarters = {
		Id = "SurvivorQuarters",
		Name = "Survivor Quarters",
		Category = "Civilization",
		RequiredTier = 1,
		Cost = { Materials = { Wood = 30, Fiber = 15 }, Scrap = 20 },
		PowerDraw = 1,
	},
}

BuildingConfig.All = definitions

function BuildingConfig.Get(id: string): BuildingDefinition?
	return definitions[id]
end

function BuildingConfig.GetFootprintSize(id: string): Vector3
	local definition = definitions[id]
	if definition and definition.FootprintSize then
		return definition.FootprintSize
	end
	return DEFAULT_FOOTPRINT
end

return BuildingConfig
