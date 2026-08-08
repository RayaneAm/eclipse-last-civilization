--!strict
-- Always-available, system-controlled Supply Shop (Phase 4A) — distinct from
-- the NPC trader and the (foundation-only) player marketplace. Every
-- purchase re-validates progression/base-level/material requirements
-- server-side; nothing here lets a player buy endgame power purely by
-- farming Scrap.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local Signal = require(ReplicatedStorage.Shared.Modules.Signal)
local SupplyShopConfig = require(ReplicatedStorage.Shared.Config.SupplyShopConfig)
local BiomeConfig = require(ReplicatedStorage.Shared.Config.BiomeConfig)

local BaseService = require(script.Parent.BaseService)
local InventoryService = require(script.Parent.InventoryService)
local CurrencyService = require(script.Parent.CurrencyService)
local ProgressionService = require(script.Parent.ProgressionService)

local SupplyShopService = {}

-- Fired only after every requirement check passed and the purchase was
-- actually charged and delivered.
SupplyShopService.ItemPurchased = Signal.new() -- (player, itemId)

-- Mirrors BiomeGateService's own (private) buildStatusFor logic — "biome
-- unlocked" is just tier >= biome.unlockTier — rather than depending on a
-- public API BiomeGateService doesn't currently expose.
local function biomeUnlocked(player: Player, biomeId: string): boolean
	local tier = ProgressionService.GetTier(player)
	for _, biome in BiomeConfig do
		if biome.id == biomeId then
			return tier >= biome.unlockTier
		end
	end
	return false
end

local function meetsRequirements(player: Player, item: SupplyShopConfig.SupplyShopItem): (boolean, string?)
	if item.Requirements.MinBaseLevel then
		local session = BaseService.Get(player.UserId)
		local level = if session then session.Level else 1
		if level < item.Requirements.MinBaseLevel then
			return false, "BaseLevelTooLow"
		end
	end
	if item.Requirements.RequiredBiomeId and not biomeUnlocked(player, item.Requirements.RequiredBiomeId) then
		return false, "BiomeNotUnlocked"
	end
	return true, nil
end

local function requestPurchase(player: Player, payload: { ItemId: string }): (boolean, string?)
	if typeof(payload) ~= "table" or typeof(payload.ItemId) ~= "string" then
		return false, "InvalidRequest"
	end
	local item = SupplyShopConfig.Get(payload.ItemId)
	if not item then
		return false, "UnknownItem"
	end

	local meets, reason = meetsRequirements(player, item)
	if not meets then
		return false, reason
	end

	for itemId, amount in item.Materials do
		if not InventoryService.HasAtLeast(player, itemId, amount) then
			return false, "InsufficientMaterials"
		end
	end
	if CurrencyService.GetBalance(player) < item.ScrapCost then
		return false, "InsufficientScrap"
	end

	for itemId, amount in item.Materials do
		InventoryService.RemoveItem(player, itemId, amount)
	end
	if item.ScrapCost > 0 then
		CurrencyService.Remove(player, item.ScrapCost)
	end
	InventoryService.AddItem(player, item.Id, 1)

	SupplyShopService.ItemPurchased:Fire(player, item.Id)
	return true
end

function SupplyShopService:Init()
	Net.GetFunction("RequestSupplyShopCatalog").OnServerInvoke = function()
		return SupplyShopConfig.All
	end
	Net.GetFunction("RequestSupplyShopPurchase").OnServerInvoke = function(player: Player, payload: any)
		return requestPurchase(player, payload)
	end
end

return SupplyShopService
