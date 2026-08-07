--!strict
-- Server-authoritative building placement/move/upgrade/repair/dismantle
-- (Phase 4A) — the sole authority; the client (BasePlacementController) only
-- ever PREVIEWS a placement, never commits one. Every request implicitly
-- targets the calling player's OWN base (only the owner can ever build), so
-- there's no separate "which base" parameter to validate — see
-- BasePermissionService for why that's a plain ownership check, not a
-- collision-group trick.
--
-- CFrames sent by the client are always LOCAL to the base's own origin, not
-- a world CFrame — bounds/overlap validation works in that local space, and
-- the server composes with BaseService's own resolved world origin only at
-- the moment a physical part is actually spawned. This avoids ever trusting
-- a client-claimed world position, the same principle PortalService already
-- established for travel.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local BuildingConfig = require(ReplicatedStorage.Shared.Config.BuildingConfig)
local PersonalBaseConfig = require(ReplicatedStorage.Shared.Config.PersonalBaseConfig)
local BaseSessionTypes = require(ReplicatedStorage.Shared.Config.BaseSessionTypes)
local BlueprintLayoutConfig = require(ReplicatedStorage.Shared.Config.BlueprintLayoutConfig)

local BaseService = require(script.Parent.BaseService)
local InventoryService = require(script.Parent.InventoryService)
local CurrencyService = require(script.Parent.CurrencyService)

local BuildingService = {}

local function withinBounds(localCFrame: CFrame): boolean
	local pos = localCFrame.Position
	local bounds = PersonalBaseConfig.PlotBounds
	return math.abs(pos.X) <= bounds.HalfWidth and math.abs(pos.Z) <= bounds.HalfDepth
end

local function withinFreeformZone(localCFrame: CFrame): boolean
	local pos = localCFrame.Position
	local zone = PersonalBaseConfig.FreeformZone
	return pos.X >= zone.MinX and pos.X <= zone.MaxX and pos.Z >= zone.MinZ and pos.Z <= zone.MaxZ
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

-- Phase 4A.1: real footprint check, not a fixed point-distance radius —
-- "validate the actual building footprint, not only the pad center point."
-- Deliberately a conservative CIRCLE approximation (each footprint's own
-- half-diagonal as its radius) rather than a true oriented-rectangle (SAT)
-- test: footprints here can sit at arbitrary rotations (the 8 perimeter
-- wall pads are spaced every 45°), and a circle can never under-detect a
-- real overlap — it may occasionally reject a placement that a tighter
-- rectangle test would have allowed near a shared corner, which is the
-- safe direction to be wrong in for a collision check.
local function footprintRadius(size: Vector3): number
	return math.sqrt((size.X / 2) ^ 2 + (size.Z / 2) ^ 2)
end

local function footprintsOverlap(posA: Vector3, sizeA: Vector3, posB: Vector3, sizeB: Vector3): boolean
	local flatA, flatB = Vector3.new(posA.X, 0, posA.Z), Vector3.new(posB.X, 0, posB.Z)
	return (flatA - flatB).Magnitude < footprintRadius(sizeA) + footprintRadius(sizeB)
end

local function overlapsExisting(session: BaseSessionTypes.BaseSessionData, buildingId: string, localCFrame: CFrame, excludeStructureId: string?): boolean
	local footprint = BuildingConfig.GetFootprintSize(buildingId)
	for id, structure in session.Structures do
		if id ~= excludeStructureId then
			local otherFootprint = BuildingConfig.GetFootprintSize(structure.BuildingId)
			if footprintsOverlap(localCFrame.Position, footprint, structure.CFrame.Position, otherFootprint) then
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
		local padFootprint = BuildingConfig.GetFootprintSize(pad.BuildingId)
		if footprintsOverlap(localCFrame.Position, footprint, pad.LocalCFrame.Position, padFootprint) then
			return true
		end
	end
	return false
end

local function canAfford(player: Player, cost: BuildingConfig.BuildingCost): boolean
	for itemId, amount in cost.Materials do
		if not InventoryService.HasAtLeast(player, itemId, amount) then
			return false
		end
	end
	return CurrencyService.GetBalance(player) >= cost.Scrap
end

local function chargeCost(player: Player, cost: BuildingConfig.BuildingCost)
	for itemId, amount in cost.Materials do
		InventoryService.RemoveItem(player, itemId, amount)
	end
	if cost.Scrap > 0 then
		CurrencyService.Remove(player, cost.Scrap)
	end
end

local function spawnStructurePart(hostUserId: number, structure: BaseSessionTypes.StructureInstance)
	local origin = BaseService.GetResolvedOrigin(hostUserId)
	if not origin then
		return
	end
	local PersonalBaseGenerator = require(ServerStorage.Tools.Generators.PersonalBaseGenerator)
	PersonalBaseGenerator.BuildStructure(hostUserId, origin, structure)
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

	-- Phase 4A.1: freeform placement is now confined to the one marked
	-- Freeform Zone — core progression structures go through their
	-- blueprint pad (RequestBuildBlueprint) instead, which needs none of
	-- these checks since its transform is server-authored, not client-sent.
	local localCFrame = payload.CFrame
	if not withinBounds(localCFrame) or not withinFreeformZone(localCFrame) then
		return false, "OutOfBounds"
	end
	if insideProtectedZone(localCFrame) then
		return false, "ProtectedZone"
	end
	if overlapsAnyPad(payload.BuildingId, localCFrame) then
		return false, "ProtectedZone"
	end
	if overlapsExisting(session, payload.BuildingId, localCFrame, nil) then
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

	if not canAfford(player, definition.Cost) then
		return false, "CannotAfford"
	end

	chargeCost(player, definition.Cost)

	local structureId = HttpService:GenerateGUID(false)
	local structure: BaseSessionTypes.StructureInstance = {
		Id = structureId,
		BuildingId = definition.Id,
		CFrame = localCFrame,
		Level = 1,
		Health = 100,
		Enabled = if definition.PowerDraw > 0 then false else nil,
	}
	session.Structures[structureId] = structure

	local points = PersonalBaseConfig.InvestmentPoints.StructureBuilt[definition.Category] or 1
	BaseService.AddInvestment(player.UserId, points)

	spawnStructurePart(player.UserId, structure)
	BaseService.BroadcastState(player.UserId)

	return true, structureId
end

-- Phase 4A.1: guided progression's primary build path — places a structure
-- at exactly its pad's own server-authored LocalCFrame, never a client-sent
-- one, which is why OutOfBounds is structurally impossible here (see the
-- freeform-only bounds checks above). Layered duplicate protection per the
-- approved migration-hardening plan section: (1) the primary, authoritative
-- PadId-linked check, correct once BaseService.migrateStructuresToPads has
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

	-- Genuine footprint-overlap tests, deliberately NOT a blanket
	-- insideProtectedZone reuse: EntranceGate_1 is intentionally positioned
	-- exactly at EntranceLocalPosition, so applying the freeform-style
	-- protected-zone rejection to pad validation would incorrectly reject
	-- the entrance gate's own legitimate, authored pad. A pad never
	-- conflicts with itself, so "every other pad" naturally excludes it
	-- without special-casing.
	local padFootprint = BuildingConfig.GetFootprintSize(pad.BuildingId)
	local coreFootprint = BuildingConfig.GetFootprintSize("CivilizationCore")
	if footprintsOverlap(pad.LocalCFrame.Position, padFootprint, PersonalBaseConfig.CoreLocalPosition, coreFootprint) then
		return false, "ProtectedZone"
	end
	for _, otherPad in BlueprintLayoutConfig.All do
		if otherPad.PadId ~= pad.PadId then
			local otherFootprint = BuildingConfig.GetFootprintSize(otherPad.BuildingId)
			if footprintsOverlap(pad.LocalCFrame.Position, padFootprint, otherPad.LocalCFrame.Position, otherFootprint) then
				return false, "ProtectedZone"
			end
		end
	end
	if overlapsExisting(session, pad.BuildingId, pad.LocalCFrame, nil) then
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

	if not canAfford(player, definition.Cost) then
		return false, "CannotAfford"
	end

	chargeCost(player, definition.Cost)

	local structureId = HttpService:GenerateGUID(false)
	local structure: BaseSessionTypes.StructureInstance = {
		Id = structureId,
		BuildingId = definition.Id,
		CFrame = pad.LocalCFrame,
		Level = 1,
		Health = 100,
		Enabled = if definition.PowerDraw > 0 then false else nil,
		PadId = pad.PadId,
	}
	session.Structures[structureId] = structure

	local points = PersonalBaseConfig.InvestmentPoints.StructureBuilt[definition.Category] or 1
	BaseService.AddInvestment(player.UserId, points)

	spawnStructurePart(player.UserId, structure)
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

	local localCFrame = payload.CFrame
	if not withinBounds(localCFrame) or not withinFreeformZone(localCFrame) then
		return false, "OutOfBounds"
	end
	if insideProtectedZone(localCFrame) then
		return false, "ProtectedZone"
	end
	if overlapsAnyPad(structure.BuildingId, localCFrame) then
		return false, "ProtectedZone"
	end
	if overlapsExisting(session, structure.BuildingId, localCFrame, payload.StructureId) then
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
	-- Upgrade always requires the current structure PLUS new materials —
	-- never a Scrap-only path (enforced structurally: every upgrade recipe
	-- in BuildingConfig has a non-empty Materials list).
	if not canAfford(player, nextDef.Cost) then
		return false, "CannotAfford"
	end

	chargeCost(player, nextDef.Cost)
	structure.BuildingId = nextDef.Id
	structure.Level += 1

	local points = PersonalBaseConfig.InvestmentPoints.StructureUpgraded[nextDef.Category] or 1
	BaseService.AddInvestment(player.UserId, points)

	spawnStructurePart(player.UserId, structure)
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
	if structure.Health >= 100 then
		return false, "AlreadyFullHealth"
	end

	-- Foundation-phase repair cost: a flat fraction of the structure's own
	-- build cost, proportional to missing health. No repair minigame yet
	-- (see the Phase 4A plan's Eclipse Assault foundation scoping).
	local definition = BuildingConfig.Get(structure.BuildingId)
	if not definition then
		return false, "UnknownBuilding"
	end
	local missingFraction = (100 - structure.Health) / 100
	local repairCost: BuildingConfig.BuildingCost = { Materials = {}, Scrap = math.ceil(definition.Cost.Scrap * missingFraction * 0.5) }
	for itemId, amount in definition.Cost.Materials do
		repairCost.Materials[itemId] = math.ceil(amount * missingFraction * 0.5)
	end

	if not canAfford(player, repairCost) then
		return false, "CannotAfford"
	end
	chargeCost(player, repairCost)
	structure.Health = 100

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
	-- back up — restore that one pad's ghost so it's buildable again,
	-- without a full rebuild/rejoin (PersonalBaseGenerator.RestoreBlueprintPad
	-- is idempotent, so this is safe even if called more than once).
	if padId then
		local origin = BaseService.GetResolvedOrigin(player.UserId)
		if origin then
			local PersonalBaseGenerator = require(ServerStorage.Tools.Generators.PersonalBaseGenerator)
			PersonalBaseGenerator.RestoreBlueprintPad(player.UserId, origin, padId)
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
