--!strict
-- Owner-vs-visitor-vs-helper permission checks for personal bases (Phase 4A).
-- Base build/edit permission is a plain server-side ownership check, NOT a
-- PhysicsService collision-group trick — BiomeGateService's own header
-- comment already rules per-player collision groups out as unscalable
-- (Roblox's 32-group cap breaks down around ~27 concurrent players). Every
-- mutating remote handler (BuildingService, StorageService, ProductionService,
-- PowerService owner-only; DefenseReserveService owner-or-helper) calls the
-- guards below independently — permission is never inferred from merely
-- being physically present at a base.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local BaseService = require(script.Parent.BaseService)

local BasePermissionService = {}

function BasePermissionService.IsOwner(player: Player, hostUserId: number): boolean
	return player.UserId == hostUserId
end

-- Owner always can; otherwise a Roblox friend or an explicit per-base
-- allow-list entry the owner configured.
function BasePermissionService.CanVisit(player: Player, hostUserId: number): boolean
	if BasePermissionService.IsOwner(player, hostUserId) then
		return true
	end

	local session = BaseService.Get(hostUserId)
	if session and session.AllowedVisitors[player.UserId] then
		return true
	end

	local ok, isFriend = pcall(function()
		return player:IsFriendsWith(hostUserId)
	end)
	return ok and isFriend == true
end

-- A visitor who is present (per CanVisit) is treated as a "helper" for
-- helper-permitted actions (Defense Reserve consume, repair/reload support
-- interactions once those exist) — owners are also implicitly helpers of
-- their own base.
function BasePermissionService.IsHelper(player: Player, hostUserId: number): boolean
	return BasePermissionService.CanVisit(player, hostUserId)
end

-- Returns true and does nothing further on success; on failure, returns
-- false so the calling remote handler can short-circuit with a rejection.
function BasePermissionService.RequireOwner(player: Player, hostUserId: number): boolean
	return BasePermissionService.IsOwner(player, hostUserId)
end

function BasePermissionService:Init()
	Net.GetFunction("RequestSetAllowedVisitor").OnServerInvoke = function(player: Player, payload: { VisitorUserId: number, Allowed: boolean })
		if typeof(payload) ~= "table" then
			return false
		end
		local hostUserId = player.UserId
		local session = BaseService.Get(hostUserId)
		if not session then
			return false
		end
		session.AllowedVisitors[payload.VisitorUserId] = if payload.Allowed then true else nil
		return true
	end
end

return BasePermissionService
