--!strict
-- Base-construction material tiers (Phase 4A). Deliberately kept separate
-- from ResourceConfig.luau, which owns biome harvest-NODE definitions — no
-- mining nodes are built this phase, so these tier-2/3/4 item ids exist only
-- as data BuildingConfig/ProductionRecipeConfig/TraderConfig can reference,
-- not as anything a player can currently harvest. Tier 1's Wood/Stone reuse
-- the ids ResourceConfig.luau already defines; Fiber/Resin are new.

export type ResourceTierEntry = {
	id: string,
	name: string,
	tier: number, -- 1-4
	category: string, -- flavor grouping (e.g. "Forest", "Frozen") for shop/UI display only
}

local ResourceTierConfig = {}

local entries: { ResourceTierEntry } = {
	-- Tier 1 — Forest
	{ id = "Wood", name = "Wood", tier = 1, category = "Forest" },
	{ id = "Stone", name = "Stone", tier = 1, category = "Forest" },
	{ id = "Fiber", name = "Fiber", tier = 1, category = "Forest" },
	{ id = "Resin", name = "Resin", tier = 1, category = "Forest" },
	{ id = "ReinforcedPlanks", name = "Reinforced Planks", tier = 1, category = "ForestProcessed" },
	{ id = "StoneBricks", name = "Stone Bricks", tier = 1, category = "ForestProcessed" },

	-- Tier 2 — Frozen
	{ id = "Iron", name = "Iron", tier = 2, category = "Frozen" },
	{ id = "FrozenCrystal", name = "Frozen Crystal", tier = 2, category = "Frozen" },
	{ id = "InsulatedComponent", name = "Insulated Component", tier = 2, category = "Frozen" },
	{ id = "HardenedMetal", name = "Hardened Metal", tier = 2, category = "Frozen" },

	-- Tier 3 — Nuclear
	{ id = "AdvancedAlloy", name = "Advanced Alloy", tier = 3, category = "Nuclear" },
	{ id = "Electronics", name = "Electronics", tier = 3, category = "Nuclear" },
	{ id = "ReactorPart", name = "Reactor Part", tier = 3, category = "Nuclear" },
	{ id = "ContaminatedTech", name = "Contaminated Tech Component", tier = 3, category = "Nuclear" },

	-- Tier 4 — Volcanic
	{ id = "Obsidian", name = "Obsidian", tier = 4, category = "Volcanic" },
	{ id = "VolcanicAlloy", name = "Volcanic Alloy", tier = 4, category = "Volcanic" },
	{ id = "GeothermalCore", name = "Geothermal Core", tier = 4, category = "Volcanic" },
	{ id = "LegendaryMineral", name = "Legendary Mineral", tier = 4, category = "Volcanic" },
}

local byId: { [string]: ResourceTierEntry } = {}
for _, entry in entries do
	byId[entry.id] = entry
end

ResourceTierConfig.All = entries

function ResourceTierConfig.Get(id: string): ResourceTierEntry?
	return byId[id]
end

function ResourceTierConfig.TierOf(id: string): number?
	local entry = byId[id]
	return entry and entry.tier
end

return ResourceTierConfig
