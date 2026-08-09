--!strict
-- The DETERMINISTIC Season Pass daily bonus — the contents a future Season
-- Pass owner would see and claim, listed in full before claiming.
--
-- Two rules this file exists to encode, both firm (facility UI brief
-- §35-§40):
--
--   1. The Season Pass NEVER grants extra random spins. The random Daily
--      Spin stays free and is earned by returning, once per reset period,
--      for every player. There is no "buy another spin", no paid reroll and
--      no paid rarity boost anywhere in this system.
--   2. The Season Pass advantage is deterministic and fully visible: a fixed
--      bonus drop whose exact contents are shown BEFORE the player claims.
--      That is what `Contents` below is.
--
-- BACKEND STATUS: not implemented. There is no ownership check, no claim
-- remote and no grant path for this bonus today — MonetizationConfig's
-- SeasonPass still carries the placeholder ProductOrPassId = 0, so nothing
-- can even be purchased. The Daily Rewards screen therefore renders the
-- locked/preview state and its CLAIM BONUS action stays disabled. Nothing
-- here grants anything; it is the shape a future implementation fills in.

local SeasonBonusConfig = {}

export type BonusLine = {
	Kind: "Currency" | "Item" | "Shard",
	ItemId: string?,
	Amount: number,
	Label: string,
}

-- Flip to true only when a real ownership check AND a server-authoritative
-- claim path both exist. The UI reads this and refuses to show a working
-- claim button while it is false.
SeasonBonusConfig.Implemented = false

SeasonBonusConfig.Name = "Season Bonus"
SeasonBonusConfig.Description = "Extra daily rewards with the Season Pass."

-- Example contents, config-driven so a season can change them without any
-- UI edit. These are NOT granted by anything today.
SeasonBonusConfig.Contents = {
	{ Kind = "Currency", ItemId = nil, Amount = 75, Label = "75 Scrap" },
	{ Kind = "Item", ItemId = "ReinforcedPlanks", Amount = 20, Label = "20 Reinforced Planks" },
	{ Kind = "Shard", ItemId = "EclipseShard", Amount = 2, Label = "2 Eclipse Shards" },
} :: { BonusLine }

return SeasonBonusConfig
