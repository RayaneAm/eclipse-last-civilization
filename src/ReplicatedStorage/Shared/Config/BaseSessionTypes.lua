--!strict
-- The single source of truth for a personal base's in-memory + persisted
-- shape — mirrors PlayerSessionTypes.luau's own "data-only" convention.
-- BaseService owns the per-player table this describes; every other base
-- service (BuildingService, StorageService, ProductionService,
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
	PadId: string?, -- authored construction socket, if any; nil remains valid for freeform structures
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
	-- Checked before the session is exposed to gameplay. New sessions are
	-- stamped at CURRENT; older saves pass through BaseSessionMigration.
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

-- Version 6 moves the stable perimeter socket ids to the true settlement
-- boundary and formalizes multi-tier wall/gate structures on those sockets.
BaseSessionTypes.CURRENT_SCHEMA_VERSION = 6

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
