--!strict
-- Validates a recipe request against the player's real server-side
-- inventory, deducts inputs and grants the output, and fires ItemCrafted so
-- QuestService can advance CraftItem objectives off real, already-validated
-- state rather than a client claim.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local Signal = require(ReplicatedStorage.Shared.Modules.Signal)
local CraftingConfig = require(ReplicatedStorage.Shared.Config.CraftingConfig)
local InventoryService = require(script.Parent.InventoryService)

local CraftingService = {}

CraftingService.ItemCrafted = Signal.new() -- (player, recipeId)

local function tryCraft(player: Player, recipeId: string): (boolean, string?)
	if typeof(recipeId) ~= "string" then
		return false, "InvalidRecipe"
	end

	local recipe = CraftingConfig.Get(recipeId)
	if not recipe then
		return false, "UnknownRecipe"
	end

	for _, ingredient in recipe.inputs do
		if not InventoryService.HasAtLeast(player, ingredient.itemId, ingredient.amount) then
			return false, "MissingIngredients"
		end
	end

	-- No yield happens between the check above and the removals below, so
	-- this is effectively atomic for a single player's sequential requests.
	for _, ingredient in recipe.inputs do
		local removed = InventoryService.RemoveItem(player, ingredient.itemId, ingredient.amount)
		assert(removed, "CraftingService: ingredient check passed but removal failed")
	end

	InventoryService.AddItem(player, recipe.output.itemId, recipe.output.amount)

	CraftingService.ItemCrafted:Fire(player, recipeId)
	return true
end

function CraftingService:Init()
	Net.GetFunction("RequestCraft").OnServerInvoke = function(player: Player, recipeId: string)
		return tryCraft(player, recipeId)
	end
end

return CraftingService
