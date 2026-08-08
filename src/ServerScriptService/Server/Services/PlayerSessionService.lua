--!strict
-- Canonical runtime PlayerSessionData owner plus its narrow persistent profile
-- foundation. Only tutorial/progression/quest-completion fields are durable;
-- economy fields remain runtime-only until their dedicated architecture owns
-- them. Loads finish before Get returns, and failed production loads are never
-- treated as writable new profiles.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local PlayerSessionTypes = require(ReplicatedStorage.Shared.Config.PlayerSessionTypes)
local PersistenceConfig = require(ReplicatedStorage.Shared.Config.PlayerSessionPersistenceConfig)
local Signal = require(ReplicatedStorage.Shared.Modules.Signal)
local Trove = require(ReplicatedStorage.Shared.Modules.Trove)
local PersistenceStore = require(script.Parent.Parent.Modules.PersistenceStore)

local PlayerSessionService = {}

PlayerSessionService.ProfileLoaded = Signal.new() -- (player, session, canPersist)

type LoadState = "Loading" | "Ready" | "Failed"

local profileStore = PersistenceStore.GetStore(PersistenceConfig.DATASTORE_NAME)
local sessions: { [Player]: PlayerSessionTypes.PlayerSessionData } = {}
local sessionTroves: { [Player]: any } = {}
local loadStates: { [Player]: LoadState } = {}
local loadEvents: { [Player]: BindableEvent } = {}
local canPersist: { [Player]: boolean } = {}
local changeRevision: { [Player]: number } = {}
local savedRevision: { [Player]: number } = {}
local saving: { [Player]: boolean } = {}

local function keyFor(player: Player): string
	return PersistenceConfig.KeyForUserId(player.UserId)
end

local function retry(attempts: number, callback: () -> (boolean, any)): (boolean, any)
	local lastResult = nil
	for attempt = 1, attempts do
		local ok, result = callback()
		if ok then
			return true, result
		end
		lastResult = result
		if attempt < attempts then
			task.wait(attempt)
		end
	end
	return false, lastResult
end

local function finishLoad(player: Player, session: PlayerSessionTypes.PlayerSessionData, writable: boolean, state: LoadState)
	sessions[player] = session
	sessionTroves[player] = Trove.new()
	canPersist[player] = writable
	loadStates[player] = state
	local event = loadEvents[player]
	if event then
		event:Fire()
	end
	PlayerSessionService.ProfileLoaded:Fire(player, session, writable)
end

local function loadProfile(player: Player)
	local ok, raw = retry(PersistenceConfig.LOAD_ATTEMPTS, function()
		return PersistenceStore.SafeGet(profileStore, keyFor(player))
	end)
	if not player.Parent then
		return
	end

	if ok then
		if typeof(raw) == "table"
			and typeof(raw.SchemaVersion) == "number"
			and raw.SchemaVersion > PlayerSessionTypes.CURRENT_SCHEMA_VERSION
		then
			warn(`[PlayerSessionService] Profile for {player.Name} uses unsupported future schema {raw.SchemaVersion}; refusing writes.`)
			finishLoad(player, PlayerSessionTypes.Reconcile(raw), false, "Failed")
			if not RunService:IsStudio() then
				player:Kick("Your survivor profile was saved by a newer game version. Please rejoin after this server updates.")
			end
			return
		end
		finishLoad(player, PlayerSessionTypes.Reconcile(raw), true, "Ready")
		return
	end

	-- Studio commonly has API Services disabled. Allow an explicit read-only
	-- session for visual/gameplay testing, but never write that fallback over
	-- a potentially real profile. Production failures are also read-only and
	-- immediately remove the player with an actionable message.
	warn(`[PlayerSessionService] CRITICAL profile load failed for {player.Name}; persistence is disabled for this session.`)
	finishLoad(player, PlayerSessionTypes.NewDefault(), false, "Failed")
	if not RunService:IsStudio() then
		player:Kick("Your survivor profile could not be loaded safely. Please rejoin in a moment.")
	end
end

local function ensureLoadStarted(player: Player)
	if not loadStates[player] then
		loadStates[player] = "Loading"
		loadEvents[player] = Instance.new("BindableEvent")
		task.spawn(loadProfile, player)
	end
end

function PlayerSessionService.AwaitLoaded(player: Player): PlayerSessionTypes.PlayerSessionData
	ensureLoadStarted(player)
	while loadStates[player] == "Loading" do
		local event = loadEvents[player]
		if event then
			event.Event:Wait()
		else
			task.wait()
		end
	end
	local session = sessions[player]
	if not session then
		error(`PlayerSessionService: no loaded profile for {player.Name}`)
	end
	return session
end

function PlayerSessionService.Get(player: Player): PlayerSessionTypes.PlayerSessionData
	return PlayerSessionService.AwaitLoaded(player)
end

function PlayerSessionService.IsLoaded(player: Player): boolean
	return loadStates[player] == "Ready" or loadStates[player] == "Failed"
end

function PlayerSessionService.CanPersist(player: Player): boolean
	return canPersist[player] == true
end

function PlayerSessionService.GetTrove(player: Player): any
	PlayerSessionService.AwaitLoaded(player)
	return sessionTroves[player]
end

function PlayerSessionService.MarkDirty(player: Player)
	if sessions[player] then
		changeRevision[player] = (changeRevision[player] or 0) + 1
	end
end

function PlayerSessionService.SaveNow(player: Player, force: boolean?): boolean
	local session = sessions[player]
	if not session or not canPersist[player] then
		return false
	end
	if saving[player] then
		while saving[player] do
			task.wait(0.05)
		end
		return (savedRevision[player] or 0) >= (changeRevision[player] or 0)
	end
	if not force and (savedRevision[player] or 0) >= (changeRevision[player] or 0) then
		return true
	end

	saving[player] = true
	local revisionBeingSaved = changeRevision[player] or 0
	local serialized = PlayerSessionTypes.SerializePersistent(session)
	local ok = select(1, retry(PersistenceConfig.SAVE_ATTEMPTS, function()
		return PersistenceStore.SafeUpdate(profileStore, keyFor(player), function(old)
			local merged = if typeof(old) == "table" then table.clone(old) else {}
			for field, value in serialized do
				if typeof(value) == "table" and typeof(merged[field]) == "table" then
					local nested = table.clone(merged[field])
					for nestedField, nestedValue in value do
						nested[nestedField] = nestedValue
					end
					merged[field] = nested
				else
					merged[field] = value
				end
			end
			return merged
		end)
	end))
	saving[player] = nil
	if ok then
		savedRevision[player] = math.max(savedRevision[player] or 0, revisionBeingSaved)
	end
	return ok
end

local function cleanup(player: Player)
	local trove = sessionTroves[player]
	if trove then
		trove:Clean()
	end
	local event = loadEvents[player]
	if event then
		event:Destroy()
	end
	sessions[player] = nil
	sessionTroves[player] = nil
	loadStates[player] = nil
	loadEvents[player] = nil
	canPersist[player] = nil
	changeRevision[player] = nil
	savedRevision[player] = nil
	saving[player] = nil
end

function PlayerSessionService:Init()
	Players.PlayerAdded:Connect(ensureLoadStarted)
	for _, player in Players:GetPlayers() do
		ensureLoadStarted(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		if sessions[player] then
			PlayerSessionService.SaveNow(player, true)
		end
		cleanup(player)
	end)

	game:BindToClose(function()
		local pending = 0
		for _, player in Players:GetPlayers() do
			if sessions[player] and canPersist[player] then
				pending += 1
				task.spawn(function()
					PlayerSessionService.SaveNow(player, true)
					pending -= 1
				end)
			end
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.05)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(PersistenceConfig.AUTOSAVE_INTERVAL_SECONDS)
			for player in sessions do
				if player.Parent and (savedRevision[player] or 0) < (changeRevision[player] or 0) then
					task.spawn(PlayerSessionService.SaveNow, player)
				end
			end
		end
	end)

	Net.GetFunction("RequestPlayerSession").OnServerInvoke = function(player: Player)
		return PlayerSessionService.AwaitLoaded(player)
	end
end

return PlayerSessionService
