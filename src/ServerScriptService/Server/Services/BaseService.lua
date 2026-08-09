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
local BaseSessionMigration = require(ReplicatedStorage.Shared.Config.BaseSessionMigration)
local BuildingConfig = require(ReplicatedStorage.Shared.Config.BuildingConfig)
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
local canPersist: { [number]: boolean } = {}
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
		StorageCapacity = raw.StorageCapacity or BaseSessionTypes.NewDefault(raw.OwnerUserId or 0).StorageCapacity,
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

-- Yields (DataStore) only on the first call per server session for this userId.
local function loadOrCreateSession(userId: number): BaseSessionTypes.BaseSessionData
	if sessions[userId] then
		return sessions[userId]
	end

	local key = tostring(userId)
	local ok, raw = PersistenceStore.SafeGet(baseDataStore, key)
	local session: BaseSessionTypes.BaseSessionData
	local writable = false
	if ok and raw then
		local deserializeOk, deserialized = pcall(deserializeSession, raw)
		if deserializeOk then
			session = deserialized
			writable = session.SchemaVersion <= BaseSessionTypes.CURRENT_SCHEMA_VERSION
			if not writable then
				warn(`[BaseService] Base {userId} uses unsupported future schema {session.SchemaVersion}; refusing writes.`)
			end
		else
			warn(`[BaseService] Base {userId} could not be deserialized; using a read-only fallback.`)
			session = newSessionWithCore(userId)
		end
	elseif ok then
		session = newSessionWithCore(userId)
		writable = true
	else
		warn(`[BaseService] Base load failed for {userId}; using a read-only fallback so existing data cannot be overwritten.`)
		session = newSessionWithCore(userId)
	end

	-- Migration runs BEFORE the session is cached or handed to anything
	-- else — blueprint-pad ghost rendering, RequestBuildBlueprint, and every
	-- other consumer only ever see already-migrated data.
	if writable and session.SchemaVersion < BaseSessionTypes.CURRENT_SCHEMA_VERSION then
		BaseSessionMigration.Migrate(session)
	end

	sessions[userId] = session
	canPersist[userId] = writable
	return session
end

function BaseService.Get(hostUserId: number): BaseSessionTypes.BaseSessionData?
	return sessions[hostUserId]
end

function BaseService.CanPersist(hostUserId: number): boolean
	return canPersist[hostUserId] == true
end

function BaseService.SaveNow(hostUserId: number)
	local session = sessions[hostUserId]
	if not session or not BaseService.CanPersist(hostUserId) then
		return
	end
	local ok, serialized = pcall(serializeSession, session)
	if ok then
		PersistenceStore.SafeUpdate(baseDataStore, tostring(hostUserId), function(old)
			if typeof(old) == "table" and typeof(old.SchemaVersion) == "number" and old.SchemaVersion > BaseSessionTypes.CURRENT_SCHEMA_VERSION then
				warn(`[BaseService] Base {hostUserId} was upgraded by a newer server during play; aborting stale save.`)
				return nil
			end
			local merged = if typeof(old) == "table" then table.clone(old) else {}
			for field, value in serialized do
				merged[field] = value
			end
			return merged
		end)
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
	-- needs the resolved world origin to position its preview. BuildingService
	-- independently converts the submitted world CFrame with its trusted origin.
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
