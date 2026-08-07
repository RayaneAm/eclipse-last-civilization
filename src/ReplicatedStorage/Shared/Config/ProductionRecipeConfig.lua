--!strict
-- Base production recipes (Phase 4A) — ProductionService reads this instead
-- of any hardcoded per-machine recipe logic. Starter recipes only.

export type ProductionRecipe = {
	Id: string,
	Name: string,
	MachineBuildingId: string, -- which BuildingConfig id can run this recipe
	Materials: { [string]: number },
	Scrap: number,
	PowerDraw: number, -- consumed only while the job is running
	DurationSeconds: number,
	OutputItemId: string,
	OutputQuantity: number,
}

local ProductionRecipeConfig = {}

local recipes: { [string]: ProductionRecipe } = {
	ReinforcedPlanks = {
		Id = "ReinforcedPlanks",
		Name = "Reinforced Planks",
		MachineBuildingId = "ResourceProcessor",
		Materials = { Wood = 30, Resin = 5 },
		Scrap = 120,
		PowerDraw = 2,
		DurationSeconds = 120,
		OutputItemId = "ReinforcedPlanks",
		OutputQuantity = 10,
	},
	StoneBricks = {
		Id = "StoneBricks",
		Name = "Stone Bricks",
		MachineBuildingId = "ResourceProcessor",
		Materials = { Stone = 25 },
		Scrap = 60,
		PowerDraw = 2,
		DurationSeconds = 90,
		OutputItemId = "StoneBricks",
		OutputQuantity = 10,
	},
}

ProductionRecipeConfig.All = recipes

function ProductionRecipeConfig.Get(id: string): ProductionRecipe?
	return recipes[id]
end

function ProductionRecipeConfig.ForMachine(buildingId: string): { ProductionRecipe }
	local list = {}
	for _, recipe in recipes do
		if recipe.MachineBuildingId == buildingId then
			table.insert(list, recipe)
		end
	end
	return list
end

return ProductionRecipeConfig
