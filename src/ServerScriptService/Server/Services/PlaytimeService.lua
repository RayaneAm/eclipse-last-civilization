--!strict
-- Phase 3B: minimal, single-purpose DataStore tracking cumulative playtime
-- per player. This remains independent from the later narrow canonical
-- PlayerSession profile because it accumulates elapsed playtime for the
-- Starter Pack gate. Exists solely so the Starter Pack promo's
-- "under 30 total hours played" gate is actually correct across sessions
-- instead of a session-only guess — confirmed as the right tradeoff during
-- planning. Not a general player-data/profile system; do not extend this
-- pattern to other features without the same explicit scoping discussion.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)

local STARTER_PACK_ELIGIBLE_HOURS = 30
local AUTOSAVE_INTERVAL_SECONDS = 180

local playtimeStore = DataStoreService:GetDataStore("EclipsePlaytimeSeconds_v1")

local PlaytimeService = {}

local savedSecondsAtJoin: { [Player]: number } = {}
local sessionStartClock: { [Player]: number } = {}

local function keyFor(player: Player): string
	return tostring(player.UserId)
end

local function save(player: Player)
	local saved = savedSecondsAtJoin[player]
	local start = sessionStartClock[player]
	if not saved or not start then
		return
	end

	local total = saved + (os.clock() - start)
	local ok, err = pcall(function()
		playtimeStore:SetAsync(keyFor(player), total)
	end)
	if ok then
		-- Reset the session baseline to what was just persisted, so a second
		-- autosave later this same session doesn't re-add the same elapsed
		-- time on top of itself.
		savedSecondsAtJoin[player] = total
		sessionStartClock[player] = os.clock()
	else
		warn(`PlaytimeService: failed to save playtime for {player.Name}:`, err)
	end
end

-- Total hours played, including the current session so far. Safe to call
-- even if the initial load hasn't finished yet (reads as 0 until it has).
function PlaytimeService.GetTotalHours(player: Player): number
	local saved = savedSecondsAtJoin[player]
	local start = sessionStartClock[player]
	if not saved or not start then
		return 0
	end
	return (saved + (os.clock() - start)) / 3600
end

function PlaytimeService.IsEligibleForStarterPack(player: Player): boolean
	return PlaytimeService.GetTotalHours(player) < STARTER_PACK_ELIGIBLE_HOURS
end

local function onPlayerJoined(player: Player)
	local ok, saved = pcall(function()
		return playtimeStore:GetAsync(keyFor(player))
	end)
	savedSecondsAtJoin[player] = if ok and typeof(saved) == "number" then saved else 0
	sessionStartClock[player] = os.clock()
end

function PlaytimeService:Init()
	Players.PlayerAdded:Connect(onPlayerJoined)
	-- Covers a player who joined before this connection was established
	-- (e.g. Studio's LocalPlayer, which can be present the instant the
	-- server starts) — the same lazy-safety concern PlayerSessionService's
	-- header comment calls out for cross-service Init ordering.
	for _, player in Players:GetPlayers() do
		onPlayerJoined(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		save(player)
		savedSecondsAtJoin[player] = nil
		sessionStartClock[player] = nil
	end)

	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			save(player)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL_SECONDS)
			for _, player in Players:GetPlayers() do
				save(player)
			end
		end
	end)

	Net.GetFunction("RequestStarterPackEligible").OnServerInvoke = function(player: Player)
		return PlaytimeService.IsEligibleForStarterPack(player)
	end
end

return PlaytimeService
