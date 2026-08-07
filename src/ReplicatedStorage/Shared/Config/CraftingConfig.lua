--!strict
-- Crafting recipes. One recipe to start (the tutorial's Hatchet) — designed
-- as a list so future prompts add entries here, not new parallel systems.

export type RecipeIngredient = { itemId: string, amount: number }

export type RecipeDefinition = {
	id: string,
	name: string,
	inputs: { RecipeIngredient },
	output: RecipeIngredient,
}

local CraftingConfig = {}

CraftingConfig.Hatchet = {
	id = "Hatchet",
	name = "Hatchet",
	inputs = {
		{ itemId = "Wood", amount = 2 },
		{ itemId = "Stone", amount = 1 },
	},
	output = { itemId = "Hatchet", amount = 1 },
} :: RecipeDefinition

CraftingConfig.All = { CraftingConfig.Hatchet } :: { RecipeDefinition }

function CraftingConfig.Get(id: string): RecipeDefinition?
	for _, recipe in CraftingConfig.All do
		if recipe.id == id then
			return recipe
		end
	end
	return nil
end

return CraftingConfig
