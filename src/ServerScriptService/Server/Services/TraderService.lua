--!strict
-- Base NPC trader (Phase 4A): system-controlled instant buy/sell, always at
-- server-computed prices (TraderConfig — never trusts a client price). Sells
-- from the player's carried Inventory (the natural post-expedition flow).
-- Blocks a sale that would dip below a configured Reserved amount unless the
-- client explicitly re-confirms after showing the warning copy from the
-- brief — the server returns the remaining/reserved numbers so the client
-- never has to guess or duplicate that math.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local TraderConfig = require(ReplicatedStorage.Shared.Config.TraderConfig)

local BaseService = require(script.Parent.BaseService)
local InventoryService = require(script.Parent.InventoryService)
local CurrencyService = require(script.Parent.CurrencyService)

local TraderService = {}

local function reservedAmount(player: Player, itemId: string): number
	local session = BaseService.Get(player.UserId)
	if not session then
		return 0
	end
	return session.Reserved[itemId] or 0
end

-- Returns (ok, reasonOrPayout, extra). On success, reasonOrPayout is the
-- Scrap paid. On a reserve-block, extra carries {Remaining, Reserved} so the
-- client can render the exact warning copy without its own math.
local function requestSell(player: Player, payload: { ItemId: string, Amount: number, ConfirmOverride: boolean? }): (boolean, any, any)
	if typeof(payload) ~= "table" or typeof(payload.ItemId) ~= "string" or typeof(payload.Amount) ~= "number" or payload.Amount <= 0 then
		return false, "InvalidRequest", nil
	end
	local entry = TraderConfig.Get(payload.ItemId)
	if not entry then
		return false, "NotSellable", nil
	end
	if not InventoryService.HasAtLeast(player, payload.ItemId, payload.Amount) then
		return false, "InsufficientInventory", nil
	end

	local reserved = reservedAmount(player, payload.ItemId)
	if reserved > 0 then
		local currentQty = InventoryService.GetQuantity(player, payload.ItemId)
		local remainingAfterSale = currentQty - payload.Amount
		if remainingAfterSale < reserved and not payload.ConfirmOverride then
			return false, "BelowReserve", { Remaining = remainingAfterSale, Reserved = reserved }
		end
	end

	InventoryService.RemoveItem(player, payload.ItemId, payload.Amount)
	local payout = entry.SellPrice * payload.Amount
	CurrencyService.Add(player, payout)
	return true, payout, nil
end

local function requestSellJunk(player: Player): (boolean, number)
	local total = 0
	for itemId, entry in TraderConfig.All do
		if entry.IsJunk then
			local quantity = InventoryService.GetQuantity(player, itemId)
			if quantity > 0 then
				local ok, payoutOrReason = requestSell(player, { ItemId = itemId, Amount = quantity, ConfirmOverride = true })
				if ok then
					total += payoutOrReason :: number
				end
			end
		end
	end
	return true, total
end

local function requestBuy(player: Player, payload: { ItemId: string, Amount: number }): (boolean, string?)
	if typeof(payload) ~= "table" or typeof(payload.ItemId) ~= "string" or typeof(payload.Amount) ~= "number" or payload.Amount <= 0 then
		return false, "InvalidRequest"
	end
	local entry = TraderConfig.Get(payload.ItemId)
	if not entry or entry.BuyPrice <= 0 then
		return false, "NotBuyable"
	end
	local cost = entry.BuyPrice * payload.Amount
	if not CurrencyService.Remove(player, cost) then
		return false, "InsufficientScrap"
	end
	InventoryService.AddItem(player, payload.ItemId, payload.Amount)
	return true
end

local function requestSetReserve(player: Player, payload: { ItemId: string, Amount: number }): (boolean, string?)
	if typeof(payload) ~= "table" or typeof(payload.ItemId) ~= "string" or typeof(payload.Amount) ~= "number" or payload.Amount < 0 then
		return false, "InvalidRequest"
	end
	local session = BaseService.Get(player.UserId)
	if not session then
		return false, "BaseNotReady"
	end
	session.Reserved[payload.ItemId] = if payload.Amount > 0 then payload.Amount else nil
	BaseService.BroadcastState(player.UserId)
	return true
end

function TraderService:Init()
	Net.GetFunction("RequestTraderSell").OnServerInvoke = function(player: Player, payload: any)
		return requestSell(player, payload)
	end
	Net.GetFunction("RequestTraderSellJunk").OnServerInvoke = function(player: Player)
		return requestSellJunk(player)
	end
	Net.GetFunction("RequestTraderBuy").OnServerInvoke = function(player: Player, payload: any)
		return requestBuy(player, payload)
	end
	Net.GetFunction("RequestSetReserve").OnServerInvoke = function(player: Player, payload: any)
		return requestSetReserve(player, payload)
	end
end

return TraderService
