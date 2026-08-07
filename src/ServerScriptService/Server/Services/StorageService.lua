--!strict
-- Base storage deposit/withdraw (Phase 4A) — a pool separate from the
-- player's own InventoryService, matching "resources can move between
-- player inventory and base storage." Withdraw is owner-only; deposit is
-- allowed for the owner and any permitted visitor/helper (helpers
-- "contribute personal supplies," never withdraw from the host's main
-- storage) — see BasePermissionService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)

local BaseService = require(script.Parent.BaseService)
local BasePermissionService = require(script.Parent.BasePermissionService)
local InventoryService = require(script.Parent.InventoryService)

local StorageService = {}

local function totalStored(session): number
	local total = 0
	for _, amount in session.Storage do
		total += amount
	end
	return total
end

-- `hostUserId` is the base being deposited into/withdrawn from — for a
-- player standing in their own base this is their own userId; for a helper
-- depositing into a host's base while visiting, it's the host's userId.
local function requestDeposit(player: Player, payload: { HostUserId: number?, ItemId: string, Amount: number }): (boolean, string?)
	if typeof(payload) ~= "table" or typeof(payload.ItemId) ~= "string" or typeof(payload.Amount) ~= "number" or payload.Amount <= 0 then
		return false, "InvalidRequest"
	end
	local hostUserId = payload.HostUserId or player.UserId
	if not BasePermissionService.CanVisit(player, hostUserId) then
		return false, "NotInvited"
	end

	local session = BaseService.Get(hostUserId)
	if not session then
		return false, "BaseNotReady"
	end
	if totalStored(session) + payload.Amount > session.StorageCapacity then
		return false, "StorageFull"
	end
	if not InventoryService.RemoveItem(player, payload.ItemId, payload.Amount) then
		return false, "InsufficientInventory"
	end

	session.Storage[payload.ItemId] = (session.Storage[payload.ItemId] or 0) + payload.Amount
	BaseService.BroadcastState(hostUserId)
	return true
end

local function requestWithdraw(player: Player, payload: { ItemId: string, Amount: number }): (boolean, string?)
	if typeof(payload) ~= "table" or typeof(payload.ItemId) ~= "string" or typeof(payload.Amount) ~= "number" or payload.Amount <= 0 then
		return false, "InvalidRequest"
	end
	-- Owner-only: withdrawing is always from your OWN base's main storage.
	local session = BaseService.Get(player.UserId)
	if not session then
		return false, "BaseNotReady"
	end

	local available = session.Storage[payload.ItemId] or 0
	if available < payload.Amount then
		return false, "InsufficientStorage"
	end

	session.Storage[payload.ItemId] = available - payload.Amount
	InventoryService.AddItem(player, payload.ItemId, payload.Amount)
	BaseService.BroadcastState(player.UserId)
	return true
end

function StorageService:Init()
	Net.GetFunction("RequestDepositStorage").OnServerInvoke = function(player: Player, payload: any)
		return requestDeposit(player, payload)
	end
	Net.GetFunction("RequestWithdrawStorage").OnServerInvoke = function(player: Player, payload: any)
		return requestWithdraw(player, payload)
	end
end

return StorageService
