--!strict
-- Owns Inventory inside the player's session (itemId -> quantity). Every
-- mutation is server-side, called by another server module (ResourceService
-- granting a harvest, CraftingService deducting/granting) — never directly
-- by a client remote with a pre-computed amount. Fires ItemAdded/ItemRemoved
-- Signals so QuestService can advance GatherItem objectives off real,
-- already-validated server state instead of a client claim.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local Signal = require(ReplicatedStorage.Shared.Modules.Signal)
local PlayerSessionService = require(script.Parent.PlayerSessionService)

local InventoryService = {}

InventoryService.ItemAdded = Signal.new() -- (player, itemId, amountAdded, newQuantity)
InventoryService.ItemRemoved = Signal.new() -- (player, itemId, amountRemoved, newQuantity)

function InventoryService.GetQuantity(player: Player, itemId: string): number
	return PlayerSessionService.Get(player).Inventory[itemId] or 0
end

function InventoryService.HasAtLeast(player: Player, itemId: string, amount: number): boolean
	return InventoryService.GetQuantity(player, itemId) >= amount
end

local function fireChanged(player: Player)
	Net.GetEvent("InventoryChanged"):FireClient(player, PlayerSessionService.Get(player).Inventory)
end

function InventoryService.AddItem(player: Player, itemId: string, amount: number)
	if amount <= 0 then
		return
	end
	local inventory = PlayerSessionService.Get(player).Inventory
	local newQuantity = (inventory[itemId] or 0) + amount
	inventory[itemId] = newQuantity
	InventoryService.ItemAdded:Fire(player, itemId, amount, newQuantity)
	fireChanged(player)
end

-- Returns false (no changes made) if the player doesn't have enough.
function InventoryService.RemoveItem(player: Player, itemId: string, amount: number): boolean
	if amount <= 0 then
		return true
	end
	local inventory = PlayerSessionService.Get(player).Inventory
	local current = inventory[itemId] or 0
	if current < amount then
		return false
	end
	local newQuantity = current - amount
	inventory[itemId] = newQuantity
	InventoryService.ItemRemoved:Fire(player, itemId, amount, newQuantity)
	fireChanged(player)
	return true
end

return InventoryService
