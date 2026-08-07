--!strict
-- Base NPC trader prices (Phase 4A) — system-controlled instant buy/sell,
-- separate from the (foundation-only, gated) player-to-player marketplace.
-- Deliberately lower/more stable than the marketplace could offer, per the
-- brief's "convenience vs. patience" tradeoff.

export type TraderEntry = {
	ItemId: string,
	SellPrice: number, -- Scrap paid to the player per unit sold
	BuyPrice: number, -- Scrap charged to the player per unit bought
	IsJunk: boolean, -- included in "Sell Junk"
}

local TraderConfig = {}

local entries: { [string]: TraderEntry } = {
	Wood = { ItemId = "Wood", SellPrice = 2, BuyPrice = 4, IsJunk = false },
	Stone = { ItemId = "Stone", SellPrice = 2, BuyPrice = 4, IsJunk = false },
	Fiber = { ItemId = "Fiber", SellPrice = 3, BuyPrice = 5, IsJunk = false },
	Resin = { ItemId = "Resin", SellPrice = 4, BuyPrice = 7, IsJunk = false },
	Iron = { ItemId = "Iron", SellPrice = 8, BuyPrice = 14, IsJunk = false },
	FrozenCrystal = { ItemId = "FrozenCrystal", SellPrice = 10, BuyPrice = 18, IsJunk = false },
	ReinforcedPlanks = { ItemId = "ReinforcedPlanks", SellPrice = 6, BuyPrice = 0, IsJunk = false },
	StoneBricks = { ItemId = "StoneBricks", SellPrice = 5, BuyPrice = 0, IsJunk = false },
	Scrap_JunkDebris = { ItemId = "Scrap_JunkDebris", SellPrice = 1, BuyPrice = 0, IsJunk = true },
}

TraderConfig.All = entries

function TraderConfig.Get(itemId: string): TraderEntry?
	return entries[itemId]
end

return TraderConfig
