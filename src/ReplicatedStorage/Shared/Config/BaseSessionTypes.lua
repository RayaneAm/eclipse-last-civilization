--!strict
-- The single source of truth for a personal base's in-memory + persisted
-- shape — mirrors PlayerSessionTypes.luau's own "data-only" convention.
-- BaseService owns the per-player table this describes; every other Phase
-- 4A base service (BuildingService, StorageService, ProductionService,
-- PowerService, DefenseReserveService) reads/writes its own slice via
-- BaseService.Get(hostUserId) rather than keeping a second parallel table.

export type BuildingCategory = "Structural" | "Utility" | "Production" | "Defense" | "Civilization"

export type StructureInstance = {
	Id: string, -- unique instance id (GUID), not the BuildingConfig id
	BuildingId: string, -- key into BuildingConfig
	CFrame: CFrame,
	Level: number,
	Health: number,
	Enabled: boolean?, -- power-consumer toggle state; nil for non-consumers
	PadId: string?, -- Phase 4A.1: which BlueprintLayoutConfig pad this was built from, if any — nil for freeform-placed structures (and for pre-4A.1 saves until BaseService's migration links them)
}

export type ProductionJob = {
	Id: string,
	MachineStructureId: string, -- key into Structures
	RecipeId: string, -- key into ProductionRecipeConfig
	StartedAt: number,
	CompletesAt: number,
	Collected: boolean,
}

export type PowerState = {
	GeneratorFuel: number,
	Enabled: { [string]: boolean }, -- structureId -> is this consumer switched on
}

export type BaseSessionData = {
	OwnerUserId: number,
	-- Phase 4A.1: schema version, checked by BaseService on load to decide
	-- whether migrateStructuresToPads needs to run before this session is
	-- cached/used by anything else. New sessions are stamped at CURRENT
	-- immediately (see NewDefault below); missing/older means "pre-4A.1
	-- save, needs migration."
	SchemaVersion: number,
	Level: number,
	InvestmentScore: number,
	Structures: { [string]: StructureInstance },
	Storage: { [string]: number }, -- itemId -> quantity, a pool separate from the player's own InventoryService
	StorageCapacity: number,
	Reserved: { [string]: number }, -- itemId -> protected quantity, checked by TraderService against the player's carried Inventory
	ProductionJobs: { [string]: ProductionJob },
	Power: PowerState,
	DefenseReserve: { [string]: number },
	AllowedVisitors: { [number]: boolean }, -- userId -> explicitly allowed, in addition to Roblox friends
}

local BaseSessionTypes = {}

local STARTER_STORAGE_CAPACITY = 200

-- Bump whenever BaseSessionData's shape changes in a way BaseService's
-- migration needs to reconcile (see migrateStructuresToPads).
BaseSessionTypes.CURRENT_SCHEMA_VERSION = 2

function BaseSessionTypes.NewDefault(ownerUserId: number): BaseSessionData
	return {
		OwnerUserId = ownerUserId,
		SchemaVersion = BaseSessionTypes.CURRENT_SCHEMA_VERSION,
		Level = 1,
		InvestmentScore = 0,
		Structures = {},
		Storage = {},
		StorageCapacity = STARTER_STORAGE_CAPACITY,
		Reserved = {},
		ProductionJobs = {},
		Power = { GeneratorFuel = 0, Enabled = {} },
		DefenseReserve = {},
		AllowedVisitors = {},
	}
end

return BaseSessionTypes
