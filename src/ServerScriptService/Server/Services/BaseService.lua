--!strict
-- Owns personal-base identity (the collision-free slot registry), the
-- per-player BaseSessionData record (real, scoped DataStore persistence —
-- see the Phase 4A plan's "Persistence" scoping decision), and lazily
-- building each player's physical base instance the first time it's needed.
--
-- Every other Phase 4A base service (BuildingService, StorageService,
-- ProductionService, PowerService, DefenseReserveService, TraderService's
-- reserve checks) reads/writes its own slice of the BaseSessionData this
-- service caches via BaseService.Get(hostUserId) — nobody keeps a second
-- parallel base-keyed table.
--
-- Slot resolution and the physical build both involve yielding (DataStore,
-- generator work) — kept strictly out of PortalDestinationConfig.Get, which
-- must stay synchronous (see PersonalBaseConfig.luau's header and
-- PortalDestinationConfig.luau's SetPersonalBaseOriginResolver). BaseService
-- injects a resolver callback into PortalDestinationConfig instead of that
-- shared config module requiring this server-only service directly — avoids
-- a ReplicatedStorage-module-requires-ServerScriptService-module hazard.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local PersonalBaseConfig = require(ReplicatedStorage.Shared.Config.PersonalBaseConfig)
local BaseSessionTypes = require(ReplicatedStorage.Shared.Config.BaseSessionTypes)
local BuildingConfig = require(ReplicatedStorage.Shared.Config.BuildingConfig)
local BlueprintLayoutConfig = require(ReplicatedStorage.Shared.Config.BlueprintLayoutConfig)
local PortalDestinationConfig = require(ReplicatedStorage.Shared.Config.PortalDestinationConfig)

local PersistenceStore = require(script.Parent.Parent.Modules.PersistenceStore)

local ROOT_NAME = "PersonalBases_Generated"
local SAVE_INTERVAL_SECONDS = 120

local slotStore = PersistenceStore.GetStore("EclipseBaseSlots_v1")
local slotCounterKey = "NextBaseSlotIndex"
local baseDataStore = PersistenceStore.GetStore("EclipseBaseData_v1")

local BaseService = {}

local resolvedSlots: { [number]: number } = {}
local sessions: { [number]: BaseSessionTypes.BaseSessionData } = {}
local builtThisServer: { [number]: boolean } = {}
local resolvingSlot: { [number]: boolean } = {}

-- ---------------------------------------------------------------------
-- Serialization: DataStores can't hold a CFrame directly.
-- ---------------------------------------------------------------------

local function serializeCFrame(cframe: CFrame): { number }
	return { cframe:GetComponents() }
end

local function deserializeCFrame(components: { number }): CFrame
	return CFrame.new(table.unpack(components))
end

local function serializeSession(session: BaseSessionTypes.BaseSessionData): { [string]: any }
	local structures = {}
	for id, structure in session.Structures do
		structures[id] = {
			Id = structure.Id,
			BuildingId = structure.BuildingId,
			CFrame = serializeCFrame(structure.CFrame),
			Level = structure.Level,
			Health = structure.Health,
			Enabled = structure.Enabled,
			PadId = structure.PadId,
		}
	end

	return {
		OwnerUserId = session.OwnerUserId,
		SchemaVersion = session.SchemaVersion,
		Level = session.Level,
		InvestmentScore = session.InvestmentScore,
		Structures = structures,
		Storage = session.Storage,
		StorageCapacity = session.StorageCapacity,
		Reserved = session.Reserved,
		ProductionJobs = session.ProductionJobs,
		Power = session.Power,
		DefenseReserve = session.DefenseReserve,
		AllowedVisitors = session.AllowedVisitors,
	}
end

local function deserializeSession(raw: { [string]: any }): BaseSessionTypes.BaseSessionData
	local structures: { [string]: BaseSessionTypes.StructureInstance } = {}
	for id, structure in (raw.Structures or {}) :: { [string]: any } do
		structures[id] = {
			Id = structure.Id,
			BuildingId = structure.BuildingId,
			CFrame = deserializeCFrame(structure.CFrame),
			Level = structure.Level,
			Health = structure.Health,
			Enabled = structure.Enabled,
			PadId = structure.PadId,
		}
	end

	return {
		OwnerUserId = raw.OwnerUserId,
		SchemaVersion = raw.SchemaVersion or 0, -- pre-4A.1 saves have no SchemaVersion at all — treated as version 0, always older than CURRENT, always migrated
		Level = raw.Level,
		InvestmentScore = raw.InvestmentScore,
		Structures = structures,
		Storage = raw.Storage or {},
		StorageCapacity = raw.StorageCapacity,
		Reserved = raw.Reserved or {},
		ProductionJobs = raw.ProductionJobs or {},
		Power = raw.Power or { GeneratorFuel = 0, Enabled = {} },
		DefenseReserve = raw.DefenseReserve or {},
		AllowedVisitors = raw.AllowedVisitors or {},
	}
end

-- ---------------------------------------------------------------------
-- Collision-free slot registry
-- ---------------------------------------------------------------------

-- Yields. Resolves (and durably records, if this is the first time) a
-- player's base slot. See PersonalBaseConfig.luau for why this is an
-- atomically-assigned sequential integer, not a hash.
local function resolveSlot(userId: number): number?
	if resolvedSlots[userId] then
		return resolvedSlots[userId]
	end
	if resolvingSlot[userId] then
		-- Another in-flight request on this server is already resolving it;
		-- wait rather than racing a second counter increment.
		while resolvingSlot[userId] do
			task.wait(0.05)
		end
		return resolvedSlots[userId]
	end
	resolvingSlot[userId] = true

	local key = tostring(userId)
	local ok, existing = PersistenceStore.SafeGet(slotStore, key)
	if ok and existing then
		resolvedSlots[userId] = existing :: number
		resolvingSlot[userId] = nil
		return existing :: number
	end

	local incOk, newSlot = PersistenceStore.SafeUpdate(slotStore, slotCounterKey, function(old)
		return (old or 0) + 1
	end)
	if not incOk or not newSlot then
		resolvingSlot[userId] = nil
		return nil
	end

	PersistenceStore.SafeSet(slotStore, key, newSlot)
	-- Self-correct against the narrow same-account-two-servers race: adopt
	-- whatever is actually durably stored, not necessarily what we just wrote.
	local confirmOk, confirmed = PersistenceStore.SafeGet(slotStore, key)
	local finalSlot = if confirmOk and confirmed then confirmed :: number else newSlot :: number

	resolvedSlots[userId] = finalSlot
	resolvingSlot[userId] = nil
	return finalSlot
end

-- Synchronous — the only thing PortalDestinationConfig.Get is allowed to
-- read for a PersonalBase_<userId> id. Never yields.
function BaseService.GetResolvedOrigin(userId: number): CFrame?
	local slot = resolvedSlots[userId]
	if not slot then
		return nil
	end
	return PersonalBaseConfig.OriginForSlot(slot)
end

-- ---------------------------------------------------------------------
-- Session load/save
-- ---------------------------------------------------------------------

local function newSessionWithCore(userId: number): BaseSessionTypes.BaseSessionData
	local session = BaseSessionTypes.NewDefault(userId)
	local coreDef = BuildingConfig.Get("CivilizationCore")
	if coreDef then
		session.Structures["CivilizationCore"] = {
			Id = "CivilizationCore",
			BuildingId = "CivilizationCore",
			CFrame = CFrame.new(PersonalBaseConfig.CoreLocalPosition), -- matches PersonalBaseGenerator's own bespoke Core placement exactly
			Level = 1,
			Health = 100,
			Enabled = nil,
		}
	end
	return session
end

-- Phase 4A.1: links pre-existing freeform-built structures (no PadId,
-- because blueprint pads didn't exist yet) to their matching pad by
-- BuildingId — never moves, recharges, upgrades, or deletes anything. Only
-- ever acts on structures still missing a PadId, and only claims a pad that
-- isn't already linked to something else, so re-running this against an
-- already-migrated (or partially-migrated) session is always a safe no-op
-- for anything already linked. Structures beyond what a pad group can hold
-- (e.g. a 9th freeform Wall against 8 Wall pads) are deliberately left
-- unlinked — still real, still owned, still rendered.
local function migrateStructuresToPads(session: BaseSessionTypes.BaseSessionData)
	local unlinkedIds: { string } = {}
	for structureId, structure in session.Structures do
		if not structure.PadId then
			table.insert(unlinkedIds, structureId)
		end
	end
	table.sort(unlinkedIds) -- deterministic: repeated/cross-server migrations always link the same way

	local claimedPadIds: { [string]: boolean } = {}
	for _, structure in session.Structures do
		if structure.PadId then
			claimedPadIds[structure.PadId] = true
		end
	end

	for _, pad in BlueprintLayoutConfig.All do
		if not claimedPadIds[pad.PadId] then
			for _, structureId in unlinkedIds do
				local structure = session.Structures[structureId]
				if structure and not structure.PadId and structure.BuildingId == pad.BuildingId then
					structure.PadId = pad.PadId
					claimedPadIds[pad.PadId] = true
					break
				end
			end
		end
	end
end

-- Yields (DataStore) only on the first call per server session for this userId.
local function loadOrCreateSession(userId: number): BaseSessionTypes.BaseSessionData
	if sessions[userId] then
		return sessions[userId]
	end

	local key = tostring(userId)
	local ok, raw = PersistenceStore.SafeGet(baseDataStore, key)
	local session: BaseSessionTypes.BaseSessionData
	if ok and raw then
		local deserializeOk, deserialized = pcall(deserializeSession, raw)
		session = if deserializeOk then deserialized else newSessionWithCore(userId)
	else
		session = newSessionWithCore(userId)
	end

	-- Migration runs BEFORE the session is cached or handed to anything
	-- else — blueprint-pad ghost rendering, RequestBuildBlueprint, and every
	-- other consumer only ever see already-migrated data.
	if session.SchemaVersion < BaseSessionTypes.CURRENT_SCHEMA_VERSION then
		migrateStructuresToPads(session)
		session.SchemaVersion = BaseSessionTypes.CURRENT_SCHEMA_VERSION
	end

	sessions[userId] = session
	return session
end

function BaseService.Get(hostUserId: number): BaseSessionTypes.BaseSessionData?
	return sessions[hostUserId]
end

function BaseService.SaveNow(hostUserId: number)
	local session = sessions[hostUserId]
	if not session then
		return
	end
	local ok, serialized = pcall(serializeSession, session)
	if ok then
		PersistenceStore.SafeSet(baseDataStore, tostring(hostUserId), serialized)
	end
end

function BaseService.RecalculateLevel(hostUserId: number)
	local session = sessions[hostUserId]
	if not session then
		return
	end
	session.Level = PersonalBaseConfig.LevelForScore(session.InvestmentScore)
end

function BaseService.AddInvestment(hostUserId: number, points: number)
	local session = sessions[hostUserId]
	if not session then
		return
	end
	session.InvestmentScore += points
	BaseService.RecalculateLevel(hostUserId)
end

function BaseService.GetLevelForLeaderboard(player: Player): number
	local session = sessions[player.UserId]
	return if session then session.Level else 1
end

-- Pushes the full session to the owner, if currently online. Visitors read
-- state on demand via RequestBaseState rather than a live subscription — a
-- deliberate foundation-phase simplification (see the Phase 4A plan).
function BaseService.BroadcastState(hostUserId: number)
	local session = sessions[hostUserId]
	if not session then
		return
	end
	local owner = Players:GetPlayerByUserId(hostUserId)
	if owner then
		Net.GetEvent("BaseStateChanged"):FireClient(owner, session)
	end
end

-- ---------------------------------------------------------------------
-- Physical instance
-- ---------------------------------------------------------------------

local function ensurePhysicalBase(userId: number, origin: CFrame)
	if builtThisServer[userId] then
		return
	end

	local root = Workspace:FindFirstChild(ROOT_NAME)
	if not root then
		root = Instance.new("Model")
		root.Name = ROOT_NAME
		root.Parent = Workspace
	end

	local PersonalBaseGenerator = require(ServerStorage.Tools.Generators.PersonalBaseGenerator)
	local session = sessions[userId]
	PersonalBaseGenerator.Build(root :: Model, userId, origin, session)

	builtThisServer[userId] = true
end

-- The one async entry point: resolves the durable slot, loads/creates the
-- session, and idempotently builds the physical instance. Called by
-- PortalService.travel before it resolves a PersonalBase_ destination, and
-- proactively (best-effort) right after a player's session exists.
function BaseService.PrepareBaseForTravel(hostUserId: number): boolean
	local slot = resolveSlot(hostUserId)
	if not slot then
		return false
	end
	loadOrCreateSession(hostUserId)
	local origin = BaseService.GetResolvedOrigin(hostUserId)
	if not origin then
		return false
	end
	ensurePhysicalBase(hostUserId, origin)
	return true
end

function BaseService:Init()
	PortalDestinationConfig.SetPersonalBaseOriginResolver(function(userId: number)
		return BaseService.GetResolvedOrigin(userId)
	end)

	-- Returns {Session, Origin} rather than the bare session — BasePlacementController
	-- needs the resolved world origin to convert its raycast-hit world
	-- position into the base-local CFrame BuildingService's placement
	-- remotes expect (see BuildingService.luau's header comment on why
	-- CFrames are always local, never a client-claimed world position).
	Net.GetFunction("RequestBaseState").OnServerInvoke = function(_player: Player, hostUserId: number)
		local session = sessions[hostUserId]
		if not session then
			return nil
		end
		return { Session = session, Origin = BaseService.GetResolvedOrigin(hostUserId) }
	end

	Players.PlayerAdded:Connect(function(player)
		-- Best-effort proactive resolution — not required for correctness
		-- (PortalService.travel also calls PrepareBaseForTravel), just makes
		-- the common case (clicking the Base Gate) feel instant.
		task.spawn(function()
			BaseService.PrepareBaseForTravel(player.UserId)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		BaseService.SaveNow(player.UserId)
	end)

	task.spawn(function()
		while true do
			task.wait(SAVE_INTERVAL_SECONDS)
			for userId in sessions do
				BaseService.SaveNow(userId)
			end
		end
	end)
end

return BaseService
