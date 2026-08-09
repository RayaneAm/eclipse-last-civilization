--!strict
-- Shared rarity presentation. Lives in ReplicatedStorage (not the client UI
-- folder) because both the Daily Reward pool and any future server-authored
-- reward/cosmetic payload need to name the same rarity tiers — a client-only
-- palette would let the two drift apart.
--
-- IMPORTANT: this module is PRESENTATION ONLY. It carries no drop weights,
-- no probabilities and no economy values. Daily Reward odds stay entirely in
-- DailyRewardConfig.Rewards[].Weight exactly as they were.

export type RarityId = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic"

export type RarityDefinition = {
	Id: RarityId,
	Label: string,
	Order: number, -- ascending; used for "Rare+" style floors and sorting
	Color: Color3,
	-- Only the top tiers get a glow, and even then a subtle one — rarity is
	-- carried by the top strip and border accent, never by recoloring a card.
	Glow: boolean,
}

local RarityConfig = {}

local definitions: { [RarityId]: RarityDefinition } = {
	Common = { Id = "Common", Label = "COMMON", Order = 1, Color = Color3.fromRGB(178, 180, 190), Glow = false },
	Uncommon = { Id = "Uncommon", Label = "UNCOMMON", Order = 2, Color = Color3.fromRGB(120, 210, 130), Glow = false },
	Rare = { Id = "Rare", Label = "RARE", Order = 3, Color = Color3.fromRGB(95, 165, 240), Glow = false },
	Epic = { Id = "Epic", Label = "EPIC", Order = 4, Color = Color3.fromRGB(175, 120, 245), Glow = true },
	Legendary = { Id = "Legendary", Label = "LEGENDARY", Order = 5, Color = Color3.fromRGB(250, 180, 75), Glow = true },
	Mythic = { Id = "Mythic", Label = "MYTHIC", Order = 6, Color = Color3.fromRGB(235, 85, 85), Glow = true },
}

RarityConfig.All = definitions

RarityConfig.Ascending = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" } :: { RarityId }

function RarityConfig.Get(id: string?): RarityDefinition
	return definitions[id :: RarityId] or definitions.Common
end

-- ---------------------------------------------------------------------
-- Eclipse Shards — reserved future currency
-- ---------------------------------------------------------------------
-- UI SUPPORT ONLY (see the facility UI brief §32). There is deliberately no
-- Shard balance, no earn rate and no spend sink implemented anywhere yet:
-- this entry exists so a reward card, a rarity strip or a future shop row
-- can render Shards consistently the moment a backend does arrive, without
-- a second ad hoc icon/color being invented at that point.
--
-- This is NOT Robux and must never be wired to a Robux purchase flow.
RarityConfig.EclipseShard = {
	ItemId = "EclipseShard",
	Label = "Eclipse Shards",
	Glyph = "ES", -- ASCII fallback only; facility UI uses IconArt's vector shard
	AccentColor = Color3.fromRGB(190, 130, 255),
	Rarity = "Mythic" :: RarityId,
	Implemented = false, -- flipped only when a real Shard economy ships
}

return RarityConfig
