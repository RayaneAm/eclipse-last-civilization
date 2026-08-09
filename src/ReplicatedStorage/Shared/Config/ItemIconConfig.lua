--!strict
-- Centralized item/resource icon mapping (Phase 4A.1 correction) — every
-- shop/economy screen reads from here instead of showing costs as plain
-- text. This is explicitly a POLISHED PLACEHOLDER system, not final art:
-- each entry is either a real emoji (Roblox's default font reliably covers
-- the emoji block, confirmed already in production via HUDController's
-- 🛒/🎁/📦/🔁 icons) or a short 2-letter monogram on a colored badge for
-- anything without a natural emoji — never a bare color swatch alone
-- (color is never the only signal) and never a dingbat/symbol character
-- like "✕"/"✓" (confirmed unreliable — see CloseButton.luau's header for
-- why). "◆" for Scrap is the one exception, kept because it's already the
-- established in-game currency symbol (HUDController's currency readout)
-- and confirmed rendering correctly in production. Swappable for real icon
-- assets later without touching any call site — every caller only ever asks
-- for `ItemIconConfig.Get(itemId)`.

export type ItemIconEntry = {
	Glyph: string,
	AccentColor: Color3,
}

local ItemIconConfig = {}

local DEFAULT_ENTRY: ItemIconEntry = { Glyph = "?", AccentColor = Color3.fromRGB(140, 140, 150) }

local entries: { [string]: ItemIconEntry } = {
	-- Currency
	Scrap = { Glyph = "Sc", AccentColor = Color3.fromRGB(180, 160, 255) },

	-- Tools
	Hatchet = { Glyph = "H", AccentColor = Color3.fromRGB(170, 140, 100) },

	-- Monetization offers (Shop) — not resource items, but ItemIcon/OfferCard/
	-- HeroOffer all key off ItemIconConfig for their preview glyph, so these
	-- offer "kinds" get entries too. Colors match Theme.Colors.Brand/
	-- BrandLight numerically (this module stays dependency-free/shared-safe,
	-- so the values are duplicated here rather than requiring the client-only
	-- Theme module).
	SeasonPassOffer = { Glyph = "SP", AccentColor = Color3.fromRGB(140, 110, 255) },
	GamePassOffer = { Glyph = "GP", AccentColor = Color3.fromRGB(180, 160, 255) },

	-- Tier 1 — Forest
	Wood = { Glyph = "W", AccentColor = Color3.fromRGB(150, 110, 70) },
	Stone = { Glyph = "S", AccentColor = Color3.fromRGB(150, 150, 155) },
	Food = { Glyph = "F", AccentColor = Color3.fromRGB(190, 214, 92) },
	Fiber = { Glyph = "Fb", AccentColor = Color3.fromRGB(150, 190, 110) },
	Resin = { Glyph = "Rs", AccentColor = Color3.fromRGB(200, 150, 70) },

	-- Tier 2 — Frozen
	Iron = { Glyph = "Fe", AccentColor = Color3.fromRGB(160, 165, 175) },
	FrozenCrystal = { Glyph = "FC", AccentColor = Color3.fromRGB(140, 210, 240) },
	InsulatedComponent = { Glyph = "Ic", AccentColor = Color3.fromRGB(120, 170, 220) },
	HardenedMetal = { Glyph = "Hm", AccentColor = Color3.fromRGB(140, 145, 160) },

	-- Tier 3 — Nuclear
	AdvancedAlloy = { Glyph = "Aa", AccentColor = Color3.fromRGB(150, 200, 90) },
	Electronics = { Glyph = "El", AccentColor = Color3.fromRGB(120, 200, 160) },
	ReactorPart = { Glyph = "Rp", AccentColor = Color3.fromRGB(230, 200, 60) },
	ContaminatedTech = { Glyph = "Ct", AccentColor = Color3.fromRGB(150, 210, 70) },

	-- Tier 4 — Volcanic
	Obsidian = { Glyph = "Ob", AccentColor = Color3.fromRGB(80, 60, 90) },
	VolcanicAlloy = { Glyph = "Va", AccentColor = Color3.fromRGB(220, 100, 60) },
	GeothermalCore = { Glyph = "GC", AccentColor = Color3.fromRGB(230, 120, 50) },
	LegendaryMineral = { Glyph = "LM", AccentColor = Color3.fromRGB(255, 200, 90) },

	-- Processed/production outputs
	ReinforcedPlanks = { Glyph = "Rp", AccentColor = Color3.fromRGB(170, 130, 80) },
	StoneBricks = { Glyph = "Sb", AccentColor = Color3.fromRGB(160, 158, 155) },

	-- Supply Shop installable modules
	ReinforcedDoorMechanism = { Glyph = "DM", AccentColor = Color3.fromRGB(170, 175, 185) },
	StorageExpansionModule = { Glyph = "SM", AccentColor = Color3.fromRGB(150, 130, 90) },
	GeneratorUpgradeCoil = { Glyph = "GC", AccentColor = Color3.fromRGB(230, 210, 90) },
}

function ItemIconConfig.Get(itemId: string): ItemIconEntry
	return entries[itemId] or DEFAULT_ENTRY
end

return ItemIconConfig
