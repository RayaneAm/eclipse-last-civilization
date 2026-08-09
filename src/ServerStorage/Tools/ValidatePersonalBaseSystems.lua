--!strict
-- Pure Personal Base data/config validation. This runs before any world-build
-- mutation and deliberately performs no DataStore or Workspace work.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseSessionMigration = require(ReplicatedStorage.Shared.Config.BaseSessionMigration)
local BaseSessionTypes = require(ReplicatedStorage.Shared.Config.BaseSessionTypes)
local BlueprintLayoutConfig = require(ReplicatedStorage.Shared.Config.BlueprintLayoutConfig)
local BuildingConfig = require(ReplicatedStorage.Shared.Config.BuildingConfig)
local ProductionRecipeConfig = require(ReplicatedStorage.Shared.Config.ProductionRecipeConfig)
local ResourceTierConfig = require(ReplicatedStorage.Shared.Config.ResourceTierConfig)

local ValidatePersonalBaseSystems = {}

local function structure(id: string, buildingId: string, cframe: CFrame, padId: string?): BaseSessionTypes.StructureInstance
	return {
		Id = id,
		BuildingId = buildingId,
		CFrame = cframe,
		Level = 1,
		Health = 100,
		PadId = padId,
	}
end

function ValidatePersonalBaseSystems.Run(): { string }
	local checks = {}
	local function check(condition: boolean, message: string)
		assert(condition, `[PersonalBaseSystems] {message}`)
		table.insert(checks, message)
	end

	-- Migration: an authored match relocates to its canonical socket, while a
	-- legitimate freeform structure and every non-layout data slice survive.
	local oldSession = BaseSessionTypes.NewDefault(7001)
	oldSession.SchemaVersion = 1
	oldSession.Level = 4
	oldSession.InvestmentScore = 88
	oldSession.Storage = { Wood = 37, Stone = 19 }
	oldSession.Reserved = { Wood = 12 }
	oldSession.Power.GeneratorFuel = 9
	oldSession.DefenseReserve = { Ammunition = 3 }
	oldSession.AllowedVisitors[7002] = true
	oldSession.ProductionJobs.jobA = {
		Id = "jobA",
		MachineStructureId = "processor",
		RecipeId = "StoneBricks",
		StartedAt = 100,
		CompletesAt = 190,
		Collected = false,
	}
	local legacyStorageCFrame = CFrame.new(-9, 0, -11)
	local freeformCFrame = CFrame.new(88, 0, -24) * CFrame.Angles(0, math.rad(27), 0)
	oldSession.Structures.storage = structure("storage", "Storage", legacyStorageCFrame, nil)
	oldSession.Structures.freeform = structure("freeform", "Foundation", freeformCFrame, nil)
	oldSession.Structures.processor = structure("processor", "ResourceProcessor", CFrame.new(-2, 0, 3), nil)
	oldSession.Structures.wall = structure("wall", "ReinforcedWall", CFrame.new(-43, 0, -74), "Wall_0")
	local freeformWallCFrame = CFrame.new(74, 0, 18) * CFrame.Angles(0, math.rad(18), 0)
	oldSession.Structures.freeformWall = structure("freeformWall", "Wall", freeformWallCFrame, nil)
	oldSession.Structures.storage.Level = 3
	oldSession.Structures.storage.Health = 73

	local storageReference = oldSession.Storage
	local jobsReference = oldSession.ProductionJobs
	local migrated = BaseSessionMigration.Migrate(oldSession)
	local storagePad = assert(BlueprintLayoutConfig.Get("Storage_1"))
	check(migrated == oldSession, "migration updates the existing session rather than replacing it")
	check(migrated.SchemaVersion == BaseSessionTypes.CURRENT_SCHEMA_VERSION, "old sessions advance to the current schema")
	check(migrated.Structures.storage.PadId == "Storage_1" and migrated.Structures.storage.CFrame == storagePad.LocalCFrame, "an exact legacy authored structure is deterministically linked and relocated")
	check(migrated.Structures.storage.Level == 3 and migrated.Structures.storage.Health == 73, "migration preserves structure level and health")
	check(migrated.Structures.freeform.PadId == nil and migrated.Structures.freeform.CFrame == freeformCFrame, "migration never relocates a legitimate freeform structure")
	check(migrated.Structures.freeformWall.PadId == nil and migrated.Structures.freeformWall.CFrame == freeformWallCFrame, "migration never guesses a repeated wall socket for an unlinked freeform wall")
	local wallReference = assert(BlueprintLayoutConfig.Get("Wall_0"))
	check(migrated.Structures.wall.BuildingId == "ReinforcedWall" and migrated.Structures.wall.CFrame == wallReference.LocalCFrame, "migration keeps an upgraded linked wall and moves it with its stable perimeter socket")
	check(migrated.Storage == storageReference and migrated.ProductionJobs == jobsReference, "migration preserves storage and in-flight production tables")
	check(migrated.Level == 4 and migrated.InvestmentScore == 88 and migrated.Power.GeneratorFuel == 9, "migration preserves progression, economy and power state")
	check(migrated.Reserved.Wood == 12 and migrated.DefenseReserve.Ammunition == 3 and migrated.AllowedVisitors[7002], "migration preserves reserve and visitor state")

	local firstStorageFrame = migrated.Structures.storage.CFrame
	local firstFreeformFrame = migrated.Structures.freeform.CFrame
	local firstStoragePad = migrated.Structures.storage.PadId
	BaseSessionMigration.Migrate(migrated)
	check(migrated.Structures.storage.CFrame == firstStorageFrame and migrated.Structures.storage.PadId == firstStoragePad and migrated.Structures.freeform.CFrame == firstFreeformFrame, "migration is idempotent when run twice")

	local futureSession = BaseSessionTypes.NewDefault(8001)
	futureSession.SchemaVersion = BaseSessionTypes.CURRENT_SCHEMA_VERSION + 1
	futureSession.Structures.futureFreeform = structure("futureFreeform", "Foundation", CFrame.new(41, 0, 17), nil)
	local futureFrame = futureSession.Structures.futureFreeform.CFrame
	BaseSessionMigration.Migrate(futureSession)
	check(futureSession.SchemaVersion == BaseSessionTypes.CURRENT_SCHEMA_VERSION + 1 and futureSession.Structures.futureFreeform.CFrame == futureFrame, "future schemas are not downgraded or rewritten")

	-- Construction graph: seven starter choices are visible together; only
	-- the defensive perimeter waits for the logical Defense Control dependency.
	local emptyStructures: { [string]: BaseSessionTypes.StructureInstance } = {}
	local initialUnlocked = 0
	local initialLocked = 0
	local withDefense: { [string]: BaseSessionTypes.StructureInstance } = {
		defense = structure("defense", "DefenseControl", CFrame.identity, "DefenseControl_1"),
	}
	for _, pad in BlueprintLayoutConfig.All do
		check(BuildingConfig.Get(pad.BuildingId) ~= nil, `{pad.PadId} references a configured building`)
		if pad.RequiredBuildingId then
			check(BuildingConfig.Get(pad.RequiredBuildingId) ~= nil and pad.RequiredBuildingId ~= pad.BuildingId, `{pad.PadId} has a valid non-self dependency`)
		end
		if BlueprintLayoutConfig.IsUnlocked(pad, emptyStructures) then
			initialUnlocked += 1
		else
			initialLocked += 1
		end
		check(BlueprintLayoutConfig.IsUnlocked(pad, withDefense), `{pad.PadId} is available after Defense Control exists`)
	end
	check(initialUnlocked == 7 and initialLocked == 8, "seven branching starter lots are visible and eight perimeter sockets are initially gated")

	local function validateDefenseChain(ids: { string }, label: string)
		local lastHealth = 0
		for tier, buildingId in ids do
			local definition = assert(BuildingConfig.Get(buildingId))
			check(definition.DefenseTier == tier, `{label} tier {tier} has the correct defense tier`)
			check(BuildingConfig.GetMaxHealth(buildingId) > lastHealth, `{label} tier {tier} increases maximum health`)
			lastHealth = BuildingConfig.GetMaxHealth(buildingId)
			local expectedNext = ids[tier + 1]
			check(definition.NextTierBuildingId == expectedNext, `{label} tier {tier} links only to the next approved tier`)
		end
	end
	validateDefenseChain({ "Wall", "ReinforcedWall", "MetalWall", "AdvancedWall" }, "wall")
	validateDefenseChain({ "EntranceGate", "ReinforcedGate", "MetalGate", "AdvancedGate" }, "gate")
	for _, pad in BlueprintLayoutConfig.All do
		if pad.AllowedBuildingIds then
			for _, buildingId in pad.AllowedBuildingIds do
				check(BlueprintLayoutConfig.AcceptsBuilding(pad, buildingId), `{pad.PadId} accepts configured tier {buildingId}`)
			end
		end
	end

	local visiting: { [string]: boolean } = {}
	local visited: { [string]: boolean } = {}
	local function visit(buildingId: string): boolean
		if visiting[buildingId] then
			return false
		end
		if visited[buildingId] then
			return true
		end
		visiting[buildingId] = true
		local definition = BuildingConfig.Get(buildingId)
		if definition and definition.PrerequisiteBuildingId and not visit(definition.PrerequisiteBuildingId) then
			return false
		end
		visiting[buildingId] = nil
		visited[buildingId] = true
		return true
	end
	for buildingId, definition in BuildingConfig.All do
		check(definition.Id == buildingId, `{buildingId} registry key matches its definition id`)
		check(definition.RequiredTier >= 1 and definition.Cost.Scrap >= 0 and definition.PowerDraw >= 0, `{buildingId} has non-negative build requirements`)
		for itemId, amount in definition.Cost.Materials do
			check(ResourceTierConfig.Get(itemId) ~= nil and amount > 0, `{buildingId} cost uses positive configured material {itemId}`)
		end
		if definition.PrerequisiteBuildingId then
			check(BuildingConfig.Get(definition.PrerequisiteBuildingId) ~= nil, `{buildingId} prerequisite exists`)
		end
		if definition.NextTierBuildingId then
			check(BuildingConfig.Get(definition.NextTierBuildingId) ~= nil and definition.NextTierBuildingId ~= buildingId, `{buildingId} next tier exists and is not itself`)
		end
		check(visit(buildingId), `{buildingId} build dependency graph is acyclic`)
	end

	-- Production config remains economy-backed: known inputs are consumed,
	-- known processed outputs are bounded by the machine and at least one is
	-- used by a building upgrade rather than existing only as menu currency.
	local producedItems: { [string]: boolean } = {}
	for recipeId, recipe in ProductionRecipeConfig.All do
		check(recipe.Id == recipeId, `{recipeId} registry key matches its recipe id`)
		local machine = BuildingConfig.Get(recipe.MachineBuildingId)
		check(machine ~= nil and machine.Category == "Production" and machine.ProductionProfile ~= nil, `{recipeId} targets a configured production machine`)
		local profile = (machine :: BuildingConfig.BuildingDefinition).ProductionProfile :: BuildingConfig.ProductionProfile
		check(profile.QueueSize >= 1 and profile.SpeedMultiplier > 0 and profile.OutputCapacity >= recipe.OutputQuantity and profile.AppearanceTier >= 1, `{recipeId} fits a valid expandable machine profile`)
		check(recipe.DurationSeconds > 0 and recipe.OutputQuantity > 0 and recipe.PowerDraw >= 0 and recipe.Scrap >= 0, `{recipeId} has sane time/output/operating costs`)
		for itemId, amount in recipe.Materials do
			check(ResourceTierConfig.Get(itemId) ~= nil and amount > 0, `{recipeId} consumes positive configured material {itemId}`)
		end
		check(ResourceTierConfig.Get(recipe.OutputItemId) ~= nil, `{recipeId} produces a configured material`)
		producedItems[recipe.OutputItemId] = true
	end
	local processedMaterialFeedsBuilding = false
	for _, definition in BuildingConfig.All do
		for itemId in definition.Cost.Materials do
			if producedItems[itemId] then
				processedMaterialFeedsBuilding = true
			end
		end
	end
	check(processedMaterialFeedsBuilding, "processed production output feeds a real building upgrade")

	return checks
end

return ValidatePersonalBaseSystems
