--!strict
-- Server-authoritative building placement/move/upgrade/repair/dismantle
-- (Phase 4A) — the sole authority; the client (BasePlacementController) only
-- ever PREVIEWS a placement, never commits one. Every request implicitly
-- targets the calling player's OWN base (only the owner can ever build), so
-- there's no separate "which base" parameter to validate — see
-- BasePermissionService for why that's a plain ownership check, not a
-- collision-group trick.
--
-- CFrames sent by the client are world-space previews. The server converts
-- them through its own resolved base origin before any local-space bounds or
-- overlap validation; the client never supplies the trusted origin.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local Signal = require(ReplicatedStorage.Shared.Modules.Signal)
local BuildingConfig = require(ReplicatedStorage.Shared.Config.BuildingConfig)
local PersonalBaseConfig = require(ReplicatedStorage.Shared.Config.PersonalBaseConfig)
local BaseSessionTypes = require(ReplicatedStorage.Shared.Config.BaseSessionTypes)
local BlueprintLayoutConfig = require(ReplicatedStorage.Shared.Config.BlueprintLayoutConfig)

local BaseService = require(script.Parent.BaseService)
local CurrencyService = require(script.Parent.CurrencyService)

local BuildingService = {}

-- Fired only after the structure exists in the session and its cost has been
-- charged — never on a rejected request. Both cover the freeform and blueprint
-- build paths, so a consumer never has to know which one the player used.
BuildingService.StructureBuilt = Signal.new() -- (player, buildingId, structureId)
BuildingService.StructureUpgraded = Signal.new() -- (player, newBuildingId, structureId)

local function footprintFor(buildingId: string, padId: string?): Vector3
	local pad = padId and BlueprintLayoutConfig.Get(padId) or nil
	return if pad then BlueprintLayoutConfig.GetFootprintSize(pad, buildingId) else BuildingConfig.GetFootprintSize(buildingId)
end

local function cframeFor(buildingId: string, localCFrame: CFrame, padId: string?): CFrame
	local pad = padId and BlueprintLayoutConfig.Get(padId) or nil
	return if pad then BlueprintLayoutConfig.GetStructureLocalCFrame(pad, buildingId) else localCFrame
end

local function footprintExtents(buildingId: string, localCFrame: CFrame, padId: string?): (number, number)
	local size = footprintFor(buildingId, padId)
	local resolvedCFrame = cframeFor(buildingId, localCFrame, padId)
	local right = resolvedCFrame.RightVector
	local look = resolvedCFrame.LookVector
	local halfX = math.abs(right.X) * size.X / 2 + math.abs(look.X) * size.Z / 2
	local halfZ = math.abs(right.Z) * size.X / 2 + math.abs(look.Z) * size.Z / 2
	return halfX, halfZ
end

local function withinBounds(buildingId: string, localCFrame: CFrame, padId: string?): boolean
	local pos = cframeFor(buildingId, localCFrame, padId).Position
	local bounds = PersonalBaseConfig.PlotBounds
	local halfX, halfZ = footprintExtents(buildingId, localCFrame, padId)
	return math.abs(pos.X) + halfX <= bounds.HalfWidth and math.abs(pos.Z) + halfZ <= bounds.HalfDepth
end

local function withinFreeformZone(buildingId: string, localCFrame: CFrame, padId: string?): boolean
	local pos = cframeFor(buildingId, localCFrame, padId).Position
	local zone = PersonalBaseConfig.FreeformZone
	local halfX, halfZ = footprintExtents(buildingId, localCFrame, padId)
	return pos.X - halfX >= zone.MinX and pos.X + halfX <= zone.MaxX and pos.Z - halfZ >= zone.MinZ and pos.Z + halfZ <= zone.MaxZ
end

local function insideProtectedZone(localCFrame: CFrame): boolean
	local pos = localCFrame.Position
	if (pos - PersonalBaseConfig.CoreLocalPosition).Magnitude < PersonalBaseConfig.CoreProtectedRadius then
		return true
	end
	if (pos - PersonalBaseConfig.EntranceLocalPosition).Magnitude < PersonalBaseConfig.EntranceProtectedRadius then
		return true
	end
	return false
end

-- True oriented-rectangle SAT footprint check. This lets authored perimeter
-- pieces meet cleanly edge-to-edge while still rejecting any real overlap;
-- the former bounding-circle approximation could not represent a long wall.
local function horizontalUnit(vector: Vector3): Vector2
	return Vector2.new(vector.X, vector.Z).Unit
end

local function footprintsOverlap(cframeA: CFrame, sizeA: Vector3, cframeB: CFrame, sizeB: Vector3): boolean
	local axesA = { horizontalUnit(cframeA.RightVector), horizontalUnit(cframeA.LookVector) }
	local axesB = { horizontalUnit(cframeB.RightVector), horizontalUnit(cframeB.LookVector) }
	local delta = Vector2.new(cframeB.Position.X - cframeA.Position.X, cframeB.Position.Z - cframeA.Position.Z)
	for _, axis in { axesA[1], axesA[2], axesB[1], axesB[2] } do
		local radiusA = math.abs(axesA[1]:Dot(axis)) * sizeA.X / 2 + math.abs(axesA[2]:Dot(axis)) * sizeA.Z / 2
		local radiusB = math.abs(axesB[1]:Dot(axis)) * sizeB.X / 2 + math.abs(axesB[2]:Dot(axis)) * sizeB.Z / 2
		if math.abs(delta:Dot(axis)) >= radiusA + radiusB - 0.01 then
			return false
		end
	end
	return true
end

local function overlapsExisting(session: BaseSessionTypes.BaseSessionData, buildingId: string, localCFrame: CFrame, padId: string?, excludeStructureId: string?): boolean
	local footprint = footprintFor(buildingId, padId)
	local resolvedCFrame = cframeFor(buildingId, localCFrame, padId)
	for id, structure in session.Structures do
		if id ~= excludeStructureId then
			local otherFootprint = footprintFor(structure.BuildingId, structure.PadId)
			local otherCFrame = cframeFor(structure.BuildingId, structure.CFrame, structure.PadId)
			if footprintsOverlap(resolvedCFrame, footprint, otherCFrame, otherFootprint) then
				return true
			end
		end
	end
	return false
end

-- Freeform placement (never blueprint construction, which is always trusted
-- to sit exactly at its own pad) must never be allowed to land on top of a
-- reserved blueprint pad, built or not — this is what keeps a pad's ghost
-- from ever having to coexist with an unrelated structure on the same spot.
local function overlapsAnyPad(buildingId: string, localCFrame: CFrame): boolean
	local footprint = BuildingConfig.GetFootprintSize(buildingId)
	for _, pad in BlueprintLayoutConfig.All do
		local padFootprint = BlueprintLayoutConfig.GetFootprintSize(pad)
		local padCFrame = BlueprintLayoutConfig.GetStructureLocalCFrame(pad)
		if footprintsOverlap(localCFrame, footprint, padCFrame, padFootprint) then
			return true
		end
	end
	return false
end

local function canAfford(player: Player, session: BaseSessionTypes.BaseSessionData, cost: BuildingConfig.BuildingCost): boolean
	for itemId, amount in cost.Materials do
		if (session.Storage[itemId] or 0) < amount then
			return false
		end
	end
	return CurrencyService.GetBalance(player) >= cost.Scrap
end

local function chargeCost(player: Player, session: BaseSessionTypes.BaseSessionData, cost: BuildingConfig.BuildingCost)
	for itemId, amount in cost.Materials do
		session.Storage[itemId] -= amount
	end
	if cost.Scrap > 0 then
		CurrencyService.Remove(player, cost.Scrap)
	end
end

local function spawnStructurePart(hostUserId: number, structure: BaseSessionTypes.StructureInstance, animateConstruction: boolean?)
	local origin = BaseService.GetResolvedOrigin(hostUserId)
	if not origin then
		return
	end
	local PersonalBaseGenerator = require(ServerStorage.Tools.Generators.PersonalBaseGenerator)
	PersonalBaseGenerator.BuildStructure(hostUserId, origin, structure, animateConstruction == true)
end

local function hasBuilding(session: BaseSessionTypes.BaseSessionData, buildingId: string): boolean
	for _, structure in session.Structures do
		if structure.BuildingId == buildingId then
			return true
		end
	end
	return false
end

local function meetsBuildingPrerequisite(session: BaseSessionTypes.BaseSessionData, definition: BuildingConfig.BuildingDefinition): boolean
	return not definition.PrerequisiteBuildingId or hasBuilding(session, definition.PrerequisiteBuildingId)
end

local function removeStructurePart(hostUserId: number, structureId: string)
	local PersonalBaseGenerator = require(ServerStorage.Tools.Generators.PersonalBaseGenerator)
	PersonalBaseGenerator.RemoveStructure(hostUserId, structureId)
end

local function requestPlaceBuilding(player: Player, payload: { BuildingId: string, CFrame: CFrame, Rotation: number? }): (boolean, string?)
	if typeof(payload) ~= "table" or typeof(payload.BuildingId) ~= "string" or typeof(payload.CFrame) ~= "CFrame" then
		return false, "InvalidRequest"
	end

	local session = BaseService.Get(player.UserId)
	if not session then
		return false, "BaseNotReady"
	end

	local definition = BuildingConfig.Get(payload.BuildingId)
	if not definition then
		return false, "UnknownBuilding"
	end
	if not meetsBuildingPrerequisite(session, definition) then
		return false, "MissingPrerequisite"
	end

	-- Freeform placement stays inside the settlement rectangle. Core
	-- progression structures go through their
	-- blueprint pad (RequestBuildBlueprint) instead, which needs none of
	-- these checks since its transform is server-authored, not client-sent.
	local origin = BaseService.GetResolvedOrigin(player.UserId)
	if not origin then
		return false, "BaseNotReady"
	end
	local localCFrame = origin:ToObjectSpace(payload.CFrame)
	if not withinBounds(payload.BuildingId, localCFrame, nil) or not withinFreeformZone(payload.BuildingId, localCFrame, nil) then
		return false, "OutOfBounds"
	end
	if insideProtectedZone(localCFrame) then
		return false, "ProtectedZone"
	end
	if overlapsAnyPad(payload.BuildingId, localCFrame) then
		return false, "ProtectedZone"
	end
	if overlapsExisting(session, payload.BuildingId, localCFrame, nil, nil) then
		return false, "Overlap"
	end

	local capacity = PersonalBaseConfig.BuildingCapacityForLevel(session.Level)
	local currentCount = 0
	for _ in session.Structures do
		currentCount += 1
	end
	if currentCount >= capacity then
		return false, "BuildingLimitReached"
	end

	if not canAfford(player, session, definition.Cost) then
		return false, "CannotAfford"
	end

	chargeCost(player, session, definition.Cost)

	local structureId = HttpService:GenerateGUID(false)
	local structure: BaseSessionTypes.StructureInstance = {
		Id = structureId,
		BuildingId = definition.Id,
		CFrame = localCFrame,
		Level = 1,
		Health = BuildingConfig.GetMaxHealth(definition.Id),
		Enabled = if definition.PowerDraw > 0 then false else nil,
	}
	session.Structures[structureId] = structure

	local points = PersonalBaseConfig.InvestmentPoints.StructureBuilt[definition.Category] or 1
	BaseService.AddInvestment(player.UserId, points)

	spawnStructurePart(player.UserId, structure, true)
	BuildingService.StructureBuilt:Fire(player, definition.Id, structureId)
	BaseService.BroadcastState(player.UserId)

	return true, structureId
end

-- Phase 4A.1: guided progression's primary build path — places a structure
-- at exactly its pad's own server-authored LocalCFrame, never a client-sent
-- one, which is why OutOfBounds is structurally impossible here (see the
-- freeform-only bounds checks above). Layered duplicate protection per the
-- approved migration-hardening plan section: (1) the primary, authoritative
	-- PadId-linked check, correct once BaseSessionMigration has
-- run on load; (2) a defensive secondary check for single-instance pad
-- groups, covering the pathological case of migration somehow not having
-- run yet; (3) a genuine footprint-overlap check, not a reuse of
-- insideProtectedZone.
local function requestBuildBlueprint(player: Player, payload: { PadId: string }): (boolean, string?)
	if typeof(payload) ~= "table" or typeof(payload.PadId) ~= "string" then
		return false, "InvalidRequest"
	end

	local pad = BlueprintLayoutConfig.Get(payload.PadId)
	if not pad then
		return false, "UnknownPad"
	end

	local session = BaseService.Get(player.UserId)
	if not session then
		return false, "BaseNotReady"
	end
	if not BlueprintLayoutConfig.IsUnlocked(pad, session.Structures) then
		return false, "MissingPrerequisite"
	end

	for _, structure in session.Structures do
		if structure.PadId == pad.PadId then
			return false, "AlreadyBuilt"
		end
	end

	-- Defensive secondary check, single-instance pad groups only (e.g.
	-- Storage/Generator/etc., as opposed to the 8-wide Wall group, where a
	-- shared BuildingId across multiple pads is expected and NOT a
	-- duplicate): an unlinked structure of the same BuildingId already
	-- existing means migration hasn't linked it yet, so refuse rather than
	-- risk a second copy.
	local padsForBuilding = 0
	for _, otherPad in BlueprintLayoutConfig.All do
		if otherPad.BuildingId == pad.BuildingId then
			padsForBuilding += 1
		end
	end
	if padsForBuilding == 1 then
		for _, structure in session.Structures do
			if structure.PadId == nil and structure.BuildingId == pad.BuildingId then
				return false, "AlreadyBuilt"
			end
		end
	end

	local definition = BuildingConfig.Get(pad.BuildingId)
	if not definition then
		return false, "UnknownBuilding"
	end
	if not meetsBuildingPrerequisite(session, definition) then
		return false, "MissingPrerequisite"
	end

	-- Genuine footprint-overlap tests, deliberately NOT a blanket
	-- insideProtectedZone reuse: EntranceGate_1 is intentionally positioned
	-- exactly at EntranceLocalPosition, so applying the freeform-style
	-- protected-zone rejection to pad validation would incorrectly reject
	-- the entrance gate's own legitimate, authored pad. A pad never
	-- conflicts with itself, so "every other pad" naturally excludes it
	-- without special-casing.
	local padFootprint = BlueprintLayoutConfig.GetFootprintSize(pad)
	local padCFrame = BlueprintLayoutConfig.GetStructureLocalCFrame(pad)
	local coreFootprint = BuildingConfig.GetFootprintSize("CivilizationCore")
	if footprintsOverlap(padCFrame, padFootprint, CFrame.new(PersonalBaseConfig.CoreLocalPosition), coreFootprint) then
		return false, "ProtectedZone"
	end
	for _, otherPad in BlueprintLayoutConfig.All do
		if otherPad.PadId ~= pad.PadId then
			local otherFootprint = BlueprintLayoutConfig.GetFootprintSize(otherPad)
			local otherCFrame = BlueprintLayoutConfig.GetStructureLocalCFrame(otherPad)
			if footprintsOverlap(padCFrame, padFootprint, otherCFrame, otherFootprint) then
				return false, "ProtectedZone"
			end
		end
	end
	if overlapsExisting(session, pad.BuildingId, pad.LocalCFrame, pad.PadId, nil) then
		return false, "Overlap"
	end

	local capacity = PersonalBaseConfig.BuildingCapacityForLevel(session.Level)
	local currentCount = 0
	for _ in session.Structures do
		currentCount += 1
	end
	if currentCount >= capacity then
		return false, "BuildingLimitReached"
	end

	if not canAfford(player, session, definition.Cost) then
		return false, "CannotAfford"
	end

	chargeCost(player, session, definition.Cost)

	local structureId = HttpService:GenerateGUID(false)
	local structure: BaseSessionTypes.StructureInstance = {
		Id = structureId,
		BuildingId = definition.Id,
		CFrame = pad.LocalCFrame,
		Level = 1,
		Health = BuildingConfig.GetMaxHealth(definition.Id),
		Enabled = if definition.PowerDraw > 0 then false else nil,
		PadId = pad.PadId,
	}
	session.Structures[structureId] = structure

	local points = PersonalBaseConfig.InvestmentPoints.StructureBuilt[definition.Category] or 1
	BaseService.AddInvestment(player.UserId, points)

	spawnStructurePart(player.UserId, structure, true)
	local origin = BaseService.GetResolvedOrigin(player.UserId)
	if origin then
		local PersonalBaseGenerator = require(ServerStorage.Tools.Generators.PersonalBaseGenerator)
		PersonalBaseGenerator.RefreshBlueprintPads(player.UserId, origin, session)
	end
	BuildingService.StructureBuilt:Fire(player, definition.Id, structureId)
	BaseService.BroadcastState(player.UserId)

	return true, structureId
end

local function requestMoveBuilding(player: Player, payload: { StructureId: string, CFrame: CFrame }): (boolean, string?)
	if typeof(payload) ~= "table" or typeof(payload.StructureId) ~= "string" or typeof(payload.CFrame) ~= "CFrame" then
		return false, "InvalidRequest"
	end
	local session = BaseService.Get(player.UserId)
	if not session then
		return false, "BaseNotReady"
	end
	local structure = session.Structures[payload.StructureId]
	if not structure then
		return false, "UnknownStructure"
	end
	if structure.BuildingId == "CivilizationCore" then
		return false, "CoreCannotMove"
	end

	local origin = BaseService.GetResolvedOrigin(player.UserId)
	if not origin then
		return false, "BaseNotReady"
	end
	local localCFrame = origin:ToObjectSpace(payload.CFrame)
	if not withinBounds(structure.BuildingId, localCFrame, structure.PadId) or not withinFreeformZone(structure.BuildingId, localCFrame, structure.PadId) then
		return false, "OutOfBounds"
	end
	if insideProtectedZone(localCFrame) then
		return false, "ProtectedZone"
	end
	if overlapsAnyPad(structure.BuildingId, localCFrame) then
		return false, "ProtectedZone"
	end
	if overlapsExisting(session, structure.BuildingId, localCFrame, structure.PadId, payload.StructureId) then
		return false, "Overlap"
	end

	structure.CFrame = localCFrame
	spawnStructurePart(player.UserId, structure) -- re-spawn at the new CFrame (idempotent by structureId inside the generator)
	BaseService.BroadcastState(player.UserId)
	return true
end

local function requestUpgradeBuilding(player: Player, payload: { StructureId: string }): (boolean, string?)
	if typeof(payload) ~= "table" or typeof(payload.StructureId) ~= "string" then
		return false, "InvalidRequest"
	end
	local session = BaseService.Get(player.UserId)
	if not session then
		return false, "BaseNotReady"
	end
	local structure = session.Structures[payload.StructureId]
	if not structure then
		return false, "UnknownStructure"
	end

	local currentDef = BuildingConfig.Get(structure.BuildingId)
	if not currentDef or not currentDef.NextTierBuildingId then
		return false, "NoUpgradeAvailable"
	end
	local nextDef = BuildingConfig.Get(currentDef.NextTierBuildingId)
	if not nextDef then
		return false, "NoUpgradeAvailable"
	end
	if structure.PadId then
		local pad = BlueprintLayoutConfig.Get(structure.PadId)
		if not pad or not BlueprintLayoutConfig.AcceptsBuilding(pad, nextDef.Id) then
			return false, "InvalidUpgradePath"
		end
	end
	-- Upgrade always requires the current structure PLUS new materials —
	-- never a Scrap-only path (enforced structurally: every upgrade recipe
	-- in BuildingConfig has a non-empty Materials list).
	if not canAfford(player, session, nextDef.Cost) then
		return false, "CannotAfford"
	end

	chargeCost(player, session, nextDef.Cost)
	structure.BuildingId = nextDef.Id
	structure.Level += 1
	structure.Health = BuildingConfig.GetMaxHealth(nextDef.Id)
	if nextDef.PowerDraw > 0 and session.Power.Enabled[payload.StructureId] == nil then
		session.Power.Enabled[payload.StructureId] = false
		structure.Enabled = false
	end

	local points = PersonalBaseConfig.InvestmentPoints.StructureUpgraded[nextDef.Category] or 1
	BaseService.AddInvestment(player.UserId, points)

	spawnStructurePart(player.UserId, structure)
	BuildingService.StructureUpgraded:Fire(player, nextDef.Id, payload.StructureId)
	BaseService.BroadcastState(player.UserId)
	return true
end

local function requestRepairBuilding(player: Player, payload: { StructureId: string }): (boolean, string?)
	if typeof(payload) ~= "table" or typeof(payload.StructureId) ~= "string" then
		return false, "InvalidRequest"
	end
	local session = BaseService.Get(player.UserId)
	if not session then
		return false, "BaseNotReady"
	end
	local structure = session.Structures[payload.StructureId]
	if not structure then
		return false, "UnknownStructure"
	end
	local maxHealth = BuildingConfig.GetMaxHealth(structure.BuildingId)
	if structure.Health >= maxHealth then
		return false, "AlreadyFullHealth"
	end

	-- Foundation-phase repair cost: a flat fraction of the structure's own
	-- build cost, proportional to missing health. No repair minigame yet
	-- (see the Phase 4A plan's Eclipse Assault foundation scoping).
	local definition = BuildingConfig.Get(structure.BuildingId)
	if not definition then
		return false, "UnknownBuilding"
	end
	local missingFraction = (maxHealth - structure.Health) / maxHealth
	local repairCost: BuildingConfig.BuildingCost = { Materials = {}, Scrap = math.ceil(definition.Cost.Scrap * missingFraction * 0.5) }
	for itemId, amount in definition.Cost.Materials do
		repairCost.Materials[itemId] = math.ceil(amount * missingFraction * 0.5)
	end

	if not canAfford(player, session, repairCost) then
		return false, "CannotAfford"
	end
	chargeCost(player, session, repairCost)
	structure.Health = maxHealth

	BaseService.BroadcastState(player.UserId)
	return true
end

local function requestDismantleBuilding(player: Player, payload: { StructureId: string }): (boolean, string?)
	if typeof(payload) ~= "table" or typeof(payload.StructureId) ~= "string" then
		return false, "InvalidRequest"
	end
	local session = BaseService.Get(player.UserId)
	if not session then
		return false, "BaseNotReady"
	end
	local structure = session.Structures[payload.StructureId]
	if not structure then
		return false, "UnknownStructure"
	end
	if structure.BuildingId == "CivilizationCore" then
		return false, "CoreCannotBeDismantled"
	end

	local padId = structure.PadId
	session.Structures[payload.StructureId] = nil
	session.Power.Enabled[payload.StructureId] = nil
	removeStructurePart(player.UserId, payload.StructureId)

	-- Dismantling a pad-linked structure frees its guided-progression slot
	-- back up. Refresh derives the entire visible lot set from session state,
	-- so dependencies such as DefenseControl -> perimeter stay correct.
	if padId then
		local origin = BaseService.GetResolvedOrigin(player.UserId)
		if origin then
			local PersonalBaseGenerator = require(ServerStorage.Tools.Generators.PersonalBaseGenerator)
			PersonalBaseGenerator.RefreshBlueprintPads(player.UserId, origin, session)
		end
	end

	BaseService.BroadcastState(player.UserId)
	return true
end

function BuildingService:Init()
	Net.GetFunction("RequestPlaceBuilding").OnServerInvoke = function(player: Player, payload: any)
		return requestPlaceBuilding(player, payload)
	end
	Net.GetFunction("RequestBuildBlueprint").OnServerInvoke = function(player: Player, payload: any)
		return requestBuildBlueprint(player, payload)
	end
	Net.GetFunction("RequestMoveBuilding").OnServerInvoke = function(player: Player, payload: any)
		return requestMoveBuilding(player, payload)
	end
	Net.GetFunction("RequestUpgradeBuilding").OnServerInvoke = function(player: Player, payload: any)
		return requestUpgradeBuilding(player, payload)
	end
	Net.GetFunction("RequestRepairBuilding").OnServerInvoke = function(player: Player, payload: any)
		return requestRepairBuilding(player, payload)
	end
	Net.GetFunction("RequestDismantleBuilding").OnServerInvoke = function(player: Player, payload: any)
		return requestDismantleBuilding(player, payload)
	end
end

return BuildingService
