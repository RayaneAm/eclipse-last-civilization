--!strict
-- Phase 3B: monetization offer definitions — Season Pass, a couple of
-- gamepasses, and the Starter Pack — consumed by ShopController (UI) and
-- MonetizationService (the purchase hook). Every `ProductOrPassId` is a
-- placeholder `0` until a real id is configured in the Creator Dashboard;
-- see ShopController's "Coming Soon" handling — a placeholder id never
-- reaches PromptProductPurchase/PromptGamePassPurchase, and never shows a
-- price. `Contents` are real and grantable even though the id is a
-- placeholder (CurrencyService/InventoryService already support them).

local HavenFacilityConfig = require(script.Parent.HavenFacilityConfig)

export type OfferKind = "Product" | "GamePass"

export type ContentLine = { Kind: "Currency", Amount: number } | { Kind: "Item", ItemId: string, Amount: number }

export type Offer = {
	Id: string,
	Name: string,
	Description: string,
	Kind: OfferKind,
	ProductOrPassId: number, -- TODO: replace with a real Product/GamePass id once one exists in the Creator Dashboard
	Contents: { ContentLine },
}

local function facilityText(id: string): (string, string)
	for _, facility in HavenFacilityConfig do
		if facility.id == id then
			return facility.name, facility.description
		end
	end
	return id, ""
end

local MonetizationConfig = {}

local starterPackName, starterPackDescription = facilityText("StarterPack")
local seasonPassName, seasonPassDescription = facilityText("SeasonPass")
local gamepassName, gamepassDescription = facilityText("GamepassShowcase")

-- Target price once a real Product id exists: ~200-300 Robux. Never shown
-- to players as a number here — ShopController fetches the live price via
-- MarketplaceService:GetProductInfo once a real id is configured, and shows
-- "Coming Soon" (no price) until then.
MonetizationConfig.StarterPack = {
	Id = "StarterPack",
	Name = starterPackName,
	Description = starterPackDescription,
	Kind = "Product",
	ProductOrPassId = 0,
	Contents = {
		{ Kind = "Currency", Amount = 500 },
		{ Kind = "Item", ItemId = "Hatchet", Amount = 1 },
	},
} :: Offer

MonetizationConfig.SeasonPass = {
	Id = "SeasonPass",
	Name = seasonPassName,
	Description = seasonPassDescription,
	Kind = "Product",
	ProductOrPassId = 0,
	Contents = {
		{ Kind = "Currency", Amount = 1500 },
	},
} :: Offer

MonetizationConfig.Gamepasses = {
	{
		Id = "GamepassShowcase",
		Name = gamepassName,
		Description = gamepassDescription,
		Kind = "GamePass",
		ProductOrPassId = 0,
		Contents = {},
	},
} :: { Offer }

return MonetizationConfig
