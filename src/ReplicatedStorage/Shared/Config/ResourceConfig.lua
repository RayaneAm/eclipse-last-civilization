--!strict
-- Harvestable resource types. Node placement/geometry lives in
-- ResourceService (runtime-spawned, not build-time art — see Prompt 4A's
-- explicit "don't art-pass Forest yet" boundary); this config only defines
-- what a resource IS, not where its nodes sit in the world.

export type ResourceDefinition = {
	id: string,
	name: string,
	baseYield: number, -- items granted per successful harvest, before tool multiplier
	respawnSeconds: number,
	nodeColor: Color3, -- plain, functional node color — not an art pass
}

local ResourceConfig = {}

ResourceConfig.Wood = {
	id = "Wood",
	name = "Wood",
	baseYield = 1,
	respawnSeconds = 25,
	nodeColor = Color3.fromRGB(90, 70, 50),
} :: ResourceDefinition

ResourceConfig.Stone = {
	id = "Stone",
	name = "Stone",
	baseYield = 1,
	respawnSeconds = 30,
	nodeColor = Color3.fromRGB(120, 120, 124),
} :: ResourceDefinition

ResourceConfig.Food = {
	id = "Food",
	name = "Food",
	baseYield = 1,
	respawnSeconds = 20,
	nodeColor = Color3.fromRGB(140, 180, 90),
} :: ResourceDefinition

ResourceConfig.All = { ResourceConfig.Wood, ResourceConfig.Stone, ResourceConfig.Food } :: { ResourceDefinition }

function ResourceConfig.Get(id: string): ResourceDefinition?
	for _, resource in ResourceConfig.All do
		if resource.id == id then
			return resource
		end
	end
	return nil
end

return ResourceConfig
