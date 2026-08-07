--!strict
-- Always-available, system-controlled high-value Supply Shop catalog
-- (Phase 4A) — distinct from the NPC trader and the player marketplace.
-- Fixed catalog for this phase (no rotation logic — see the brief's "core
-- progression items should not depend entirely on random rotation").
-- Every entry requires real progression AND real materials on top of Scrap,
-- so nothing here lets a player buy endgame power purely by farming Coins.

export type SupplyShopRequirements = {
	MinBaseLevel: number?,
	RequiredBiomeId: string?, -- checked against BiomeGateService/ProgressionService tier unlocks
}

export type SupplyShopItem = {
	Id: string,
	Name: string,
	Description: string,
	Category: string,
	ScrapCost: number,
	Materials: { [string]: number }, -- installed alongside the purchase, not instead of it
	Requirements: SupplyShopRequirements,
}

local SupplyShopConfig = {}

local items: { [string]: SupplyShopItem } = {
	ReinforcedDoorMechanism = {
		Id = "ReinforcedDoorMechanism",
		Name = "Reinforced Door Mechanism",
		Description = "Unlocks production of the Iron Door — a stronger, electric-capable entrance.",
		Category = "DefenseSupplies",
		ScrapCost = 1500,
		Materials = { Iron = 20 },
		Requirements = { MinBaseLevel = 10, RequiredBiomeId = "FrozenWasteland" },
	},
	StorageExpansionModule = {
		Id = "StorageExpansionModule",
		Name = "Storage Expansion Module",
		Description = "Permanently increases base storage capacity.",
		Category = "ProductionSupplies",
		ScrapCost = 800,
		Materials = { Stone = 40 },
		Requirements = { MinBaseLevel = 5 },
	},
	GeneratorUpgradeCoil = {
		Id = "GeneratorUpgradeCoil",
		Name = "Generator Upgrade Coil",
		Description = "Increases the base generator's power capacity.",
		Category = "ProductionSupplies",
		ScrapCost = 1000,
		Materials = { Iron = 15 },
		Requirements = { MinBaseLevel = 10 },
	},
}

SupplyShopConfig.All = items

function SupplyShopConfig.Get(id: string): SupplyShopItem?
	return items[id]
end

return SupplyShopConfig
