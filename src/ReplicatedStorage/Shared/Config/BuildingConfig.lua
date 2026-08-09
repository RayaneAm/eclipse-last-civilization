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

export type ProductionProfile = {
	QueueSize: number,
	SpeedMultiplier: number,
	OutputCapacity: number,
	AppearanceTier: number,
}

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
	-- Neutral level-one values today; later machine definitions can opt into
	-- larger queues/faster operation/different physical tiers without putting
	-- balance constants into ProductionService or the world generator.
	ProductionProfile: ProductionProfile?,
	Description: string?,
	UpgradeSummary: string?,
	DefenseTier: number?,
	TierLabel: string?,
	MaxHealth: number?,
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
		FootprintSize = Vector3.new(12, 5, 2),
		NextTierBuildingId = "ReinforcedWall",
		Description = "A quick timber perimeter that marks and protects your settlement.",
		UpgradeSummary = "Replace timber sections with a reinforced stone-backed wall.",
		DefenseTier = 1,
		TierLabel = "WOOD",
		MaxHealth = 100,
	},
	ReinforcedWall = {
		Id = "ReinforcedWall",
		Name = "Reinforced Wall",
		Category = "Structural",
		RequiredTier = 2,
		Cost = { Materials = { ReinforcedPlanks = 10, StoneBricks = 10, Iron = 20 }, Scrap = 60 },
		PowerDraw = 0,
		FootprintSize = Vector3.new(12, 6, 3),
		PrerequisiteBuildingId = "Wall",
		NextTierBuildingId = "MetalWall",
		Description = "Stone footing and reinforced timber absorb heavier attacks.",
		UpgradeSummary = "Plate the wall in industrial metal for much higher durability.",
		DefenseTier = 2,
		TierLabel = "REINFORCED",
		MaxHealth = 180,
	},
	MetalWall = {
		Id = "MetalWall",
		Name = "Metal Wall",
		Category = "Structural",
		RequiredTier = 2,
		Cost = { Materials = { Iron = 40, HardenedMetal = 10 }, Scrap = 180 },
		PowerDraw = 0,
		FootprintSize = Vector3.new(12, 7, 4),
		PrerequisiteBuildingId = "ReinforcedWall",
		NextTierBuildingId = "AdvancedWall",
		Description = "Heavy metal plates and braces turn the perimeter industrial.",
		UpgradeSummary = "Add powered technology and future defense attachment points.",
		DefenseTier = 3,
		TierLabel = "METAL",
		MaxHealth = 280,
	},
	AdvancedWall = {
		Id = "AdvancedWall",
		Name = "Advanced Wall",
		Category = "Structural",
		RequiredTier = 3,
		Cost = { Materials = { AdvancedAlloy = 30, Electronics = 20 }, Scrap = 400 },
		PowerDraw = 1,
		FootprintSize = Vector3.new(12, 8, 4),
		PrerequisiteBuildingId = "MetalWall",
		Description = "Civilization-grade armor with powered monitoring and mount points.",
		DefenseTier = 4,
		TierLabel = "POWERED",
		MaxHealth = 420,
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
		FootprintSize = Vector3.new(24, 10, 4),
		NextTierBuildingId = "ReinforcedGate",
		Description = "The first controlled entrance through your defensive perimeter.",
		UpgradeSummary = "Reinforce the gate with stone footing and stronger supports.",
		DefenseTier = 1,
		TierLabel = "WOOD",
		MaxHealth = 160,
	},
	ReinforcedGate = {
		Id = "ReinforcedGate",
		Name = "Reinforced Gate",
		Category = "Structural",
		RequiredTier = 1,
		Cost = { Materials = { ReinforcedPlanks = 20, StoneBricks = 25 }, Scrap = 100 },
		PowerDraw = 0,
		FootprintSize = Vector3.new(24, 12, 5),
		PrerequisiteBuildingId = "EntranceGate",
		NextTierBuildingId = "MetalGate",
		Description = "A reinforced checkpoint with heavier posts and stone foundations.",
		UpgradeSummary = "Replace the frame with industrial metal and heavier bracing.",
		DefenseTier = 2,
		TierLabel = "REINFORCED",
		MaxHealth = 260,
	},
	MetalGate = {
		Id = "MetalGate",
		Name = "Metal Gate",
		Category = "Structural",
		RequiredTier = 2,
		Cost = { Materials = { Iron = 60, HardenedMetal = 20 }, Scrap = 250 },
		PowerDraw = 1,
		FootprintSize = Vector3.new(24, 14, 6),
		PrerequisiteBuildingId = "ReinforcedGate",
		NextTierBuildingId = "AdvancedGate",
		Description = "An industrial gate prepared for powered security systems.",
		UpgradeSummary = "Install civilization-grade powered security technology.",
		DefenseTier = 3,
		TierLabel = "METAL",
		MaxHealth = 380,
	},
	AdvancedGate = {
		Id = "AdvancedGate",
		Name = "Advanced Gate",
		Category = "Structural",
		RequiredTier = 3,
		Cost = { Materials = { AdvancedAlloy = 45, Electronics = 30 }, Scrap = 600 },
		PowerDraw = 2,
		FootprintSize = Vector3.new(24, 16, 7),
		PrerequisiteBuildingId = "MetalGate",
		Description = "A powered fortress entrance ready for future barriers and defenses.",
		DefenseTier = 4,
		TierLabel = "POWERED",
		MaxHealth = 550,
	},

	-- Utility
	Storage = {
		Id = "Storage",
		Name = "Storage Crate",
		Category = "Utility",
		RequiredTier = 1,
		Cost = { Materials = { Wood = 20, Stone = 10 }, Scrap = 0 },
		PowerDraw = 0,
		FootprintSize = Vector3.new(8, 5, 8),
		Description = "Stores expedition materials for construction and production.",
	},
	Workbench = {
		Id = "Workbench",
		Name = "Workbench",
		Category = "Utility",
		RequiredTier = 1,
		Cost = { Materials = { Wood = 25, Stone = 5 }, Scrap = 0 },
		PowerDraw = 0,
		FootprintSize = Vector3.new(10, 4, 8),
		Description = "Supports crafting, repairs and future equipment improvements.",
	},
	Generator = {
		Id = "Generator",
		Name = "Basic Generator",
		Category = "Utility",
		RequiredTier = 1,
		Cost = { Materials = { Stone = 15, Fiber = 10 }, Scrap = 40 },
		PowerDraw = 0, -- a generator is the power SOURCE, not a consumer
		FootprintSize = Vector3.new(10, 7, 10),
		Description = "Provides power for machines and advanced settlement systems.",
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
		FootprintSize = Vector3.new(12, 8, 10),
		ProductionProfile = {
			QueueSize = 1,
			SpeedMultiplier = 1,
			OutputCapacity = 20,
			AppearanceTier = 1,
		},
		Description = "Turns gathered resources into stronger construction materials.",
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
		Description = "Coordinates perimeter construction and future defensive systems.",
	},

	-- Civilization
	CivilizationCore = {
		Id = "CivilizationCore",
		Name = "Civilization Core",
		Category = "Civilization",
		RequiredTier = 1,
		Cost = { Materials = {}, Scrap = 0 }, -- placed automatically at base creation, never bought
		PowerDraw = 0,
		FootprintSize = Vector3.new(20, 24, 20),
	},
	SurvivorQuarters = {
		Id = "SurvivorQuarters",
		Name = "Survivor Quarters",
		Category = "Civilization",
		RequiredTier = 1,
		Cost = { Materials = { Wood = 30, Fiber = 15 }, Scrap = 20 },
		PowerDraw = 1,
		FootprintSize = Vector3.new(14, 7, 12),
		Description = "Provides shelter and space for future survivor support systems.",
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

function BuildingConfig.GetMaxHealth(id: string): number
	local definition = definitions[id]
	return if definition and definition.MaxHealth then definition.MaxHealth else 100
end

return BuildingConfig
