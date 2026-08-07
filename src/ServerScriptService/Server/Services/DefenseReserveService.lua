--!strict
-- Defense Reserve (Phase 4A): approved consumables the owner allocates from
-- base Storage ahead of an Eclipse Assault; helpers consume from THIS pool
-- during co-op defense, never the host's main Storage directly. A
-- non-yielding check-then-decrement is already race-free under Luau's
-- single-threaded server-script model — no extra locking needed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local DefenseReserveConfig = require(ReplicatedStorage.Shared.Config.DefenseReserveConfig)

local BaseService = require(script.Parent.BaseService)
local BasePermissionService = require(script.Parent.BasePermissionService)

local DefenseReserveService = {}

local function requestAllocate(player: Player, payload: { ItemId: string, Amount: number }): (boolean, string?)
	if typeof(payload) ~= "table" or typeof(payload.ItemId) ~= "string" or typeof(payload.Amount) ~= "number" or payload.Amount <= 0 then
		return false, "InvalidRequest"
	end
	if not DefenseReserveConfig.IsApproved(payload.ItemId) then
		return false, "NotApproved"
	end

	local session = BaseService.Get(player.UserId)
	if not session then
		return false, "BaseNotReady"
	end
	if (session.Storage[payload.ItemId] or 0) < payload.Amount then
		return false, "InsufficientStorage"
	end

	session.Storage[payload.ItemId] -= payload.Amount
	session.DefenseReserve[payload.ItemId] = (session.DefenseReserve[payload.ItemId] or 0) + payload.Amount
	BaseService.BroadcastState(player.UserId)
	return true
end

-- `hostUserId`: the base whose reserve is being drawn from — the caller's
-- own base if they're the owner, or the base they're currently helping
-- defend if a permitted visitor.
local function requestConsume(player: Player, payload: { HostUserId: number?, ItemId: string, Amount: number }): (boolean, string?)
	if typeof(payload) ~= "table" or typeof(payload.ItemId) ~= "string" or typeof(payload.Amount) ~= "number" or payload.Amount <= 0 then
		return false, "InvalidRequest"
	end
	local hostUserId = payload.HostUserId or player.UserId
	if not BasePermissionService.IsHelper(player, hostUserId) then
		return false, "NotInvited"
	end
	if not DefenseReserveConfig.IsApproved(payload.ItemId) then
		return false, "NotApproved"
	end

	local session = BaseService.Get(hostUserId)
	if not session then
		return false, "BaseNotReady"
	end
	local available = session.DefenseReserve[payload.ItemId] or 0
	if available < payload.Amount then
		return false, "InsufficientReserve"
	end

	session.DefenseReserve[payload.ItemId] = available - payload.Amount
	BaseService.BroadcastState(hostUserId)
	return true
end

function DefenseReserveService:Init()
	Net.GetFunction("RequestAllocateDefenseReserve").OnServerInvoke = function(player: Player, payload: any)
		return requestAllocate(player, payload)
	end
	Net.GetFunction("RequestConsumeDefenseReserve").OnServerInvoke = function(player: Player, payload: any)
		return requestConsume(player, payload)
	end
end

return DefenseReserveService
