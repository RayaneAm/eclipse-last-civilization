--!strict
-- Per-item display glyph + accent color for the Inventory/Crafting panel.
-- Deliberately client-only (not src/shared/Config) — ResourceConfig/
-- ToolConfig/CraftingConfig are read by server-side gameplay services
-- (ResourceService, ToolService, CraftingService) that have zero reason to
-- know about a display glyph; this is a pure rendering concern keyed by the
-- same itemId strings, kept out of the data/rules layer those configs
-- deliberately stay in (see e.g. ToolConfig.luau's own header comment).
--
-- Matches the project's zero-image-asset convention (BiomeConfig.gate.icon
-- is the only prior art — a single Unicode glyph, not an ImageLabel).

export type ItemDisplayDefinition = { Icon: string, AccentColor: Color3 }

local FALLBACK: ItemDisplayDefinition = { Icon = "◆", AccentColor = Color3.fromRGB(160, 160, 170) }

local IconGlyphs: { [string]: ItemDisplayDefinition } = {
	Wood = { Icon = "🌳", AccentColor = Color3.fromRGB(150, 110, 70) },
	Stone = { Icon = "⛰", AccentColor = Color3.fromRGB(150, 150, 155) },
	Food = { Icon = "🍖", AccentColor = Color3.fromRGB(170, 200, 110) },
	Hatchet = { Icon = "⛏", AccentColor = Color3.fromRGB(200, 200, 210) },
	Scrap = { Icon = "⚙", AccentColor = Color3.fromRGB(230, 190, 90) },
}

local Lookup = {}

function Lookup.Get(itemId: string): ItemDisplayDefinition
	return IconGlyphs[itemId] or FALLBACK
end

return Lookup
