--!strict
-- Owns the per-player PlayerSessionData table (src/shared/Config/PlayerSessionTypes.luau)
-- — the single in-memory source of truth every other Prompt 4A service reads
-- and writes its own slice of, instead of keeping a second parallel
-- player-keyed table. No DataStore calls here — see the Prompt 4A plan's
-- "Persistence boundary": sessions are simply dropped on PlayerRemoving for
-- now, which is an intentional, known gap, not an oversight.
--
-- Get(player) is a LAZY get-or-create, not "create on PlayerAdded and
-- assume every other service can wait for that." Loader guarantees all
-- services' Init() finish before any Start(), but gives no ordering
-- guarantee *between* different services' Init() calls — if two services
-- both connect to Players.PlayerAdded independently, which one's handler
-- fires first for a given join is undefined. Lazy get-or-create removes
-- that hazard entirely: whichever service touches a player's session first
-- creates it correctly, with zero dependency on Init order.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local PlayerSessionTypes = require(ReplicatedStorage.Shared.Config.PlayerSessionTypes)
local Trove = require(ReplicatedStorage.Shared.Modules.Trove)

local PlayerSessionService = {}

local sessions: { [Player]: PlayerSessionTypes.PlayerSessionData } = {}
local sessionTroves: { [Player]: any } = {}

function PlayerSessionService.Get(player: Player): PlayerSessionTypes.PlayerSessionData
	local session = sessions[player]
	if not session then
		session = PlayerSessionTypes.NewDefault()
		sessions[player] = session
		sessionTroves[player] = Trove.new()
	end
	return session
end

-- Lets a service attach cleanup (connections, temp instances) tied to this
-- player's session lifetime without every service inventing its own
-- PlayerRemoving handler.
function PlayerSessionService.GetTrove(player: Player): any
	PlayerSessionService.Get(player) -- ensures the trove exists too, via the same lazy pattern
	return sessionTroves[player]
end

function PlayerSessionService:Init()
	Players.PlayerRemoving:Connect(function(player)
		local trove = sessionTroves[player]
		if trove then
			trove:Clean()
		end
		sessions[player] = nil
		sessionTroves[player] = nil
	end)

	-- The session table is already plain, client-safe data (see
	-- PlayerSessionTypes) — owning the consolidated snapshot pull here,
	-- rather than a separate aggregator service, avoids a second copy of
	-- "what does the whole session look like" existing anywhere.
	Net.GetFunction("RequestPlayerSession").OnServerInvoke = function(player: Player)
		return PlayerSessionService.Get(player)
	end
end

return PlayerSessionService
