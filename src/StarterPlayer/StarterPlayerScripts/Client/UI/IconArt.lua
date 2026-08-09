--!strict
-- Vector icons drawn from primitive Frames. No fonts, no image assets, no
-- upload pipeline — every icon is a handful of rounded rectangles.
--
-- ===========================================================================
-- WHY THIS EXISTS: THE BLANK-RECTANGLE BUG
-- ===========================================================================
-- ItemIconConfig previously rendered each item as a TEXT GLYPH, and the
-- glyphs chosen for the most common resources were recent emoji:
--
--     Wood     "\u{1FAB5}"  wood      — Emoji 13.0 (2020)
--     Stone    "\u{1FAA8}"  rock      — Emoji 13.0 (2020)
--     Hatchet  "\u{1FA93}"  axe       — Emoji 12.0 (2019)
--
-- Roblox has no bundled emoji font; it falls through to whatever the client
-- OS provides. Any client whose system emoji font predates those additions
-- has no glyph for those codepoints and renders nothing — an empty box.
-- That is exactly the "Wood shows as a blank rectangle" symptom, and it is
-- also why the emoji that DID work in this codebase all happen to be old
-- ones (gift, package, cart — Emoji 1.0-3.0, present on every platform since
-- ~2015). The bug was never about ImageLabels, asset IDs or permissions:
-- there was no ImageLabel involved at all.
--
-- The other half of the old set were two-letter monograms ("Fb", "Rs", "Fe",
-- "Hm", "Aa", "Sb"...). Those always rendered, but a wall of tiny letter
-- pairs is not an icon-driven UI.
--
-- So: every resource is now DRAWN. A rounded Frame always renders, on every
-- platform, at every size, with zero load time and no failure mode. Colors
-- are chosen so each item is identifiable by silhouette AND hue, never by
-- color alone.
--
-- ===========================================================================
-- HOW AN ICON IS DEFINED
-- ===========================================================================
-- Each icon is a list of shapes in a normalized 0..1 box, so one definition
-- renders correctly at 20px in a cost row and 64px in a reward card.
--
--     X, Y     center, 0..1 across the icon box
--     W, H     size, fraction of the box
--     Rot      degrees (optional)
--     Color    fill
--     Corner   corner radius as a fraction of the shape's own size;
--              0.5 on a square gives a circle
--     Alpha    background transparency (optional)
--
-- Keep shapes few and bold. These are read at 24px most of the time, so
-- detail below ~0.12 of the box is wasted.

local Theme = require(script.Parent.Theme)

local IconArt = {}

export type Shape = {
	X: number,
	Y: number,
	W: number,
	H: number,
	Rot: number?,
	Color: Color3,
	Corner: number?,
	Alpha: number?,
}

export type IconDefinition = {
	Shapes: { Shape },
	-- The holder tint behind the icon. Reads as the item's "family" color.
	Accent: Color3,
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- ---------------------------------------------------------------------
-- Icon definitions
-- ---------------------------------------------------------------------

local BROWN_LIGHT = rgb(198, 142, 84)
local BROWN = rgb(160, 110, 64)
local BROWN_DARK = rgb(118, 78, 44)
local STONE_LIGHT = rgb(198, 202, 212)
local STONE = rgb(160, 165, 178)
local STONE_DARK = rgb(116, 121, 136)
local METAL_LIGHT = rgb(196, 204, 220)
local METAL = rgb(150, 158, 176)
local METAL_DARK = rgb(102, 109, 128)

local icons: { [string]: IconDefinition } = {
	-- === Currency ======================================================
	-- The Scrap diamond is the one shape players already associate with
	-- currency here, so it stays a diamond — just drawn instead of typed.
	Scrap = {
		Accent = rgb(150, 105, 255),
		Shapes = {
			{ X = 0.5, Y = 0.5, W = 0.62, H = 0.62, Rot = 45, Color = rgb(176, 140, 255), Corner = 0.16 },
			{ X = 0.5, Y = 0.5, W = 0.3, H = 0.3, Rot = 45, Color = rgb(228, 214, 255), Corner = 0.2 },
		},
	},
	EclipseShard = {
		Accent = rgb(190, 130, 255),
		Shapes = {
			{ X = 0.5, Y = 0.5, W = 0.44, H = 0.86, Color = rgb(178, 118, 250), Corner = 0.28 },
			{ X = 0.5, Y = 0.5, W = 0.44, H = 0.86, Rot = 58, Color = rgb(146, 88, 224), Corner = 0.28, Alpha = 0.15 },
			{ X = 0.41, Y = 0.36, W = 0.11, H = 0.26, Color = rgb(238, 220, 255), Corner = 0.5 },
		},
	},

	-- === Tier 1 — Forest ===============================================
	Wood = {
		Accent = rgb(168, 116, 68),
		Shapes = {
			-- Two stacked logs seen end-on: instantly readable at 20px.
			{ X = 0.52, Y = 0.34, W = 0.84, H = 0.3, Color = BROWN_LIGHT, Corner = 0.5 },
			{ X = 0.52, Y = 0.68, W = 0.84, H = 0.3, Color = BROWN, Corner = 0.5 },
			{ X = 0.24, Y = 0.34, W = 0.16, H = 0.16, Color = BROWN_DARK, Corner = 0.5 },
			{ X = 0.24, Y = 0.68, W = 0.16, H = 0.16, Color = rgb(96, 62, 34), Corner = 0.5 },
		},
	},
	Stone = {
		Accent = rgb(158, 163, 176),
		Shapes = {
			{ X = 0.42, Y = 0.6, W = 0.66, H = 0.58, Color = STONE, Corner = 0.34 },
			{ X = 0.7, Y = 0.37, W = 0.46, H = 0.42, Color = STONE_LIGHT, Corner = 0.36 },
			{ X = 0.34, Y = 0.66, W = 0.2, H = 0.18, Color = STONE_DARK, Corner = 0.5 },
		},
	},
	Fiber = {
		Accent = rgb(150, 205, 110),
		Shapes = {
			{ X = 0.5, Y = 0.5, W = 0.15, H = 0.84, Rot = -24, Color = rgb(128, 186, 92), Corner = 0.5 },
			{ X = 0.5, Y = 0.5, W = 0.15, H = 0.9, Color = rgb(176, 226, 130), Corner = 0.5 },
			{ X = 0.5, Y = 0.5, W = 0.15, H = 0.84, Rot = 24, Color = rgb(144, 202, 104), Corner = 0.5 },
		},
	},
	Resin = {
		Accent = rgb(226, 168, 74),
		Shapes = {
			{ X = 0.5, Y = 0.6, W = 0.62, H = 0.6, Color = rgb(228, 166, 66), Corner = 0.5 },
			{ X = 0.5, Y = 0.26, W = 0.3, H = 0.38, Color = rgb(228, 166, 66), Corner = 0.36 },
			{ X = 0.38, Y = 0.58, W = 0.16, H = 0.2, Color = rgb(255, 226, 160), Corner = 0.5 },
		},
	},
	Food = {
		Accent = rgb(190, 214, 92),
		Shapes = {
			{ X = 0.46, Y = 0.58, W = 0.68, H = 0.62, Color = rgb(218, 92, 86), Corner = 0.5 },
			{ X = 0.58, Y = 0.25, W = 0.14, H = 0.28, Rot = 18, Color = rgb(104, 168, 72), Corner = 0.5 },
			{ X = 0.7, Y = 0.3, W = 0.32, H = 0.18, Rot = -24, Color = rgb(142, 202, 82), Corner = 0.5 },
			{ X = 0.34, Y = 0.48, W = 0.18, H = 0.18, Color = rgb(255, 180, 150), Corner = 0.5 },
		},
	},

	-- === Tier 2 — Frozen ===============================================
	Iron = {
		Accent = rgb(160, 168, 186),
		Shapes = {
			{ X = 0.5, Y = 0.64, W = 0.84, H = 0.3, Color = METAL, Corner = 0.22 },
			{ X = 0.5, Y = 0.37, W = 0.6, H = 0.28, Color = METAL_LIGHT, Corner = 0.22 },
		},
	},
	FrozenCrystal = {
		Accent = rgb(120, 205, 240),
		Shapes = {
			{ X = 0.5, Y = 0.5, W = 0.17, H = 0.92, Color = rgb(158, 224, 248), Corner = 0.5 },
			{ X = 0.5, Y = 0.5, W = 0.17, H = 0.92, Rot = 60, Color = rgb(112, 196, 232), Corner = 0.5 },
			{ X = 0.5, Y = 0.5, W = 0.17, H = 0.92, Rot = -60, Color = rgb(196, 238, 252), Corner = 0.5 },
			{ X = 0.5, Y = 0.5, W = 0.22, H = 0.22, Color = rgb(232, 250, 255), Corner = 0.5 },
		},
	},
	InsulatedComponent = {
		Accent = rgb(110, 168, 224),
		Shapes = {
			{ X = 0.5, Y = 0.5, W = 0.76, H = 0.56, Color = rgb(104, 160, 216), Corner = 0.3 },
			{ X = 0.5, Y = 0.5, W = 0.76, H = 0.18, Color = rgb(186, 220, 250), Corner = 0.4 },
			{ X = 0.18, Y = 0.5, W = 0.12, H = 0.3, Color = rgb(70, 116, 168), Corner = 0.4 },
			{ X = 0.82, Y = 0.5, W = 0.12, H = 0.3, Color = rgb(70, 116, 168), Corner = 0.4 },
		},
	},
	HardenedMetal = {
		Accent = rgb(142, 150, 168),
		Shapes = {
			{ X = 0.5, Y = 0.5, W = 0.8, H = 0.66, Color = METAL, Corner = 0.24 },
			{ X = 0.28, Y = 0.31, W = 0.13, H = 0.13, Color = METAL_DARK, Corner = 0.5 },
			{ X = 0.72, Y = 0.31, W = 0.13, H = 0.13, Color = METAL_DARK, Corner = 0.5 },
			{ X = 0.28, Y = 0.69, W = 0.13, H = 0.13, Color = METAL_DARK, Corner = 0.5 },
			{ X = 0.72, Y = 0.69, W = 0.13, H = 0.13, Color = METAL_DARK, Corner = 0.5 },
		},
	},

	-- === Tier 3 — Nuclear ==============================================
	AdvancedAlloy = {
		Accent = rgb(158, 208, 96),
		Shapes = {
			{ X = 0.5, Y = 0.5, W = 0.72, H = 0.72, Rot = 45, Color = rgb(150, 202, 88), Corner = 0.22 },
			{ X = 0.5, Y = 0.5, W = 0.38, H = 0.38, Rot = 45, Color = rgb(206, 238, 156), Corner = 0.25 },
		},
	},
	Electronics = {
		Accent = rgb(96, 206, 168),
		Shapes = {
			{ X = 0.5, Y = 0.12, W = 0.46, H = 0.14, Color = rgb(78, 176, 142), Corner = 0.5 },
			{ X = 0.5, Y = 0.88, W = 0.46, H = 0.14, Color = rgb(78, 176, 142), Corner = 0.5 },
			{ X = 0.12, Y = 0.5, W = 0.14, H = 0.46, Color = rgb(78, 176, 142), Corner = 0.5 },
			{ X = 0.88, Y = 0.5, W = 0.14, H = 0.46, Color = rgb(78, 176, 142), Corner = 0.5 },
			{ X = 0.5, Y = 0.5, W = 0.62, H = 0.62, Color = rgb(104, 214, 176), Corner = 0.2 },
			{ X = 0.5, Y = 0.5, W = 0.28, H = 0.28, Color = rgb(40, 128, 104), Corner = 0.22 },
		},
	},
	ReactorPart = {
		Accent = rgb(232, 202, 66),
		Shapes = {
			{ X = 0.5, Y = 0.5, W = 0.88, H = 0.88, Color = rgb(232, 200, 62), Corner = 0.5 },
			{ X = 0.5, Y = 0.5, W = 0.5, H = 0.5, Color = rgb(74, 64, 30), Corner = 0.5 },
			{ X = 0.5, Y = 0.5, W = 0.24, H = 0.24, Color = rgb(255, 242, 158), Corner = 0.5 },
		},
	},
	ContaminatedTech = {
		Accent = rgb(152, 210, 74),
		Shapes = {
			{ X = 0.5, Y = 0.6, W = 0.72, H = 0.54, Color = rgb(142, 198, 70), Corner = 0.26 },
			{ X = 0.5, Y = 0.24, W = 0.3, H = 0.26, Color = rgb(104, 154, 54), Corner = 0.34 },
			{ X = 0.5, Y = 0.62, W = 0.22, H = 0.22, Color = rgb(226, 250, 168), Corner = 0.5 },
		},
	},

	-- === Tier 4 — Volcanic =============================================
	Obsidian = {
		Accent = rgb(122, 96, 150),
		Shapes = {
			{ X = 0.5, Y = 0.5, W = 0.5, H = 0.88, Rot = 12, Color = rgb(78, 60, 98), Corner = 0.22 },
			{ X = 0.4, Y = 0.5, W = 0.16, H = 0.86, Rot = 12, Color = rgb(132, 104, 162), Corner = 0.3 },
		},
	},
	VolcanicAlloy = {
		Accent = rgb(216, 100, 60),
		Shapes = {
			{ X = 0.5, Y = 0.5, W = 0.8, H = 0.62, Color = rgb(206, 92, 54), Corner = 0.26 },
			{ X = 0.5, Y = 0.5, W = 0.11, H = 0.62, Rot = 16, Color = rgb(255, 186, 96), Corner = 0.5 },
		},
	},
	GeothermalCore = {
		Accent = rgb(232, 118, 52),
		Shapes = {
			{ X = 0.5, Y = 0.5, W = 0.9, H = 0.9, Color = rgb(214, 96, 44), Corner = 0.5 },
			{ X = 0.5, Y = 0.5, W = 0.58, H = 0.58, Color = rgb(255, 166, 66), Corner = 0.5 },
			{ X = 0.5, Y = 0.5, W = 0.26, H = 0.26, Color = rgb(255, 240, 186), Corner = 0.5 },
		},
	},
	LegendaryMineral = {
		Accent = rgb(255, 202, 92),
		Shapes = {
			-- Three crossed bars read as a star burst without needing a real
			-- polygon, which Roblox UI cannot draw.
			{ X = 0.5, Y = 0.5, W = 0.26, H = 0.94, Color = rgb(255, 202, 88), Corner = 0.4 },
			{ X = 0.5, Y = 0.5, W = 0.26, H = 0.94, Rot = 60, Color = rgb(255, 202, 88), Corner = 0.4 },
			{ X = 0.5, Y = 0.5, W = 0.26, H = 0.94, Rot = -60, Color = rgb(255, 202, 88), Corner = 0.4 },
			{ X = 0.5, Y = 0.5, W = 0.4, H = 0.4, Color = rgb(255, 238, 176), Corner = 0.5 },
		},
	},

	-- === Processed / production outputs =================================
	ReinforcedPlanks = {
		Accent = rgb(184, 134, 82),
		Shapes = {
			{ X = 0.5, Y = 0.27, W = 0.88, H = 0.2, Color = BROWN_LIGHT, Corner = 0.28 },
			{ X = 0.5, Y = 0.52, W = 0.88, H = 0.2, Color = BROWN, Corner = 0.28 },
			{ X = 0.5, Y = 0.77, W = 0.88, H = 0.2, Color = BROWN_DARK, Corner = 0.28 },
			{ X = 0.3, Y = 0.52, W = 0.1, H = 0.82, Color = METAL, Corner = 0.3 },
		},
	},
	StoneBricks = {
		Accent = rgb(168, 170, 178),
		Shapes = {
			{ X = 0.29, Y = 0.3, W = 0.42, H = 0.28, Color = STONE_LIGHT, Corner = 0.18 },
			{ X = 0.73, Y = 0.3, W = 0.42, H = 0.28, Color = STONE, Corner = 0.18 },
			{ X = 0.15, Y = 0.66, W = 0.24, H = 0.28, Color = STONE, Corner = 0.18 },
			{ X = 0.51, Y = 0.66, W = 0.42, H = 0.28, Color = STONE_LIGHT, Corner = 0.18 },
			{ X = 0.87, Y = 0.66, W = 0.24, H = 0.28, Color = STONE_DARK, Corner = 0.18 },
		},
	},

	-- === Tools =========================================================
	Hatchet = {
		Accent = rgb(180, 146, 104),
		Shapes = {
			{ X = 0.56, Y = 0.58, W = 0.15, H = 0.86, Rot = -22, Color = BROWN, Corner = 0.5 },
			{ X = 0.42, Y = 0.3, W = 0.54, H = 0.36, Rot = -22, Color = METAL_LIGHT, Corner = 0.24 },
			{ X = 0.5, Y = 0.34, W = 0.16, H = 0.3, Rot = -22, Color = METAL_DARK, Corner = 0.3 },
		},
	},

	-- === Supply Shop modules ===========================================
	ReinforcedDoorMechanism = {
		Accent = rgb(170, 178, 194),
		Shapes = {
			{ X = 0.5, Y = 0.33, W = 0.44, H = 0.44, Color = METAL_DARK, Corner = 0.5 },
			{ X = 0.5, Y = 0.4, W = 0.24, H = 0.3, Color = Theme.Colors.PanelBackground, Corner = 0.5 },
			{ X = 0.5, Y = 0.66, W = 0.74, H = 0.48, Color = METAL_LIGHT, Corner = 0.26 },
			{ X = 0.5, Y = 0.66, W = 0.14, H = 0.2, Color = METAL_DARK, Corner = 0.4 },
		},
	},
	StorageExpansionModule = {
		Accent = rgb(176, 140, 88),
		Shapes = {
			{ X = 0.5, Y = 0.56, W = 0.84, H = 0.64, Color = BROWN_LIGHT, Corner = 0.18 },
			{ X = 0.5, Y = 0.56, W = 0.84, H = 0.16, Color = BROWN_DARK, Corner = 0.2 },
			{ X = 0.5, Y = 0.28, W = 0.84, H = 0.12, Color = BROWN, Corner = 0.3 },
		},
	},
	GeneratorUpgradeCoil = {
		Accent = rgb(255, 210, 74),
		Shapes = {
			{ X = 0.56, Y = 0.29, W = 0.3, H = 0.52, Rot = 20, Color = rgb(255, 216, 82), Corner = 0.16 },
			{ X = 0.44, Y = 0.71, W = 0.3, H = 0.52, Rot = 20, Color = rgb(255, 184, 48), Corner = 0.16 },
		},
	},

	-- === Monetization offer previews ===================================
	SeasonPassOffer = {
		Accent = rgb(255, 176, 48),
		Shapes = {
			{ X = 0.5, Y = 0.5, W = 0.86, H = 0.56, Color = rgb(255, 190, 74), Corner = 0.24 },
			{ X = 0.32, Y = 0.5, W = 0.1, H = 0.56, Color = rgb(198, 128, 28), Corner = 0.3 },
			{ X = 0.63, Y = 0.5, W = 0.28, H = 0.28, Color = rgb(255, 240, 190), Corner = 0.5 },
		},
	},
	GamePassOffer = {
		Accent = rgb(150, 105, 255),
		Shapes = {
			{ X = 0.5, Y = 0.56, W = 0.66, H = 0.5, Rot = 45, Color = rgb(176, 140, 255), Corner = 0.18 },
			{ X = 0.5, Y = 0.3, W = 0.5, H = 0.24, Color = rgb(214, 194, 255), Corner = 0.28 },
		},
	},
}

-- Unknown item: a deliberate, designed "unrecognized resource" crate rather
-- than a blank hole. If this ever appears in game it means an item id is
-- missing from the table above, which is visible instead of silent.
local DEFAULT_ICON: IconDefinition = {
	Accent = rgb(140, 146, 170),
	Shapes = {
		{ X = 0.5, Y = 0.5, W = 0.72, H = 0.72, Color = rgb(120, 126, 152), Corner = 0.24 },
		{ X = 0.5, Y = 0.5, W = 0.4, H = 0.4, Color = rgb(176, 182, 206), Corner = 0.3 },
	},
}

-- ---------------------------------------------------------------------
-- Facility / UI glyphs
-- ---------------------------------------------------------------------
-- Header and section icons, drawn for exactly the same reason. These replace
-- the emoji that were being used for facility headers.

local glyphs: { [string]: IconDefinition } = {
	Base = {
		Accent = rgb(150, 105, 255),
		Shapes = {
			{ X = 0.5, Y = 0.28, W = 0.9, H = 0.34, Rot = 45, Color = rgb(196, 170, 255), Corner = 0.16 },
			{ X = 0.5, Y = 0.68, W = 0.66, H = 0.52, Color = rgb(160, 120, 255), Corner = 0.16 },
			{ X = 0.5, Y = 0.75, W = 0.24, H = 0.38, Color = rgb(96, 64, 178), Corner = 0.18 },
		},
	},
	Build = {
		Accent = rgb(72, 148, 255),
		Shapes = {
			{ X = 0.42, Y = 0.62, W = 0.16, H = 0.72, Rot = -32, Color = rgb(150, 196, 255), Corner = 0.5 },
			{ X = 0.62, Y = 0.3, W = 0.52, H = 0.3, Rot = -32, Color = rgb(72, 148, 255), Corner = 0.26 },
		},
	},
	Upgrade = {
		Accent = rgb(255, 134, 58),
		Shapes = {
			{ X = 0.5, Y = 0.32, W = 0.72, H = 0.36, Rot = 45, Color = rgb(255, 176, 96), Corner = 0.18 },
			{ X = 0.5, Y = 0.72, W = 0.34, H = 0.44, Color = rgb(255, 134, 58), Corner = 0.22 },
		},
	},
	Production = {
		Accent = rgb(42, 206, 180),
		Shapes = {
			{ X = 0.5, Y = 0.5, W = 0.28, H = 0.94, Color = rgb(42, 206, 180), Corner = 0.36 },
			{ X = 0.5, Y = 0.5, W = 0.28, H = 0.94, Rot = 60, Color = rgb(42, 206, 180), Corner = 0.36 },
			{ X = 0.5, Y = 0.5, W = 0.28, H = 0.94, Rot = -60, Color = rgb(42, 206, 180), Corner = 0.36 },
			{ X = 0.5, Y = 0.5, W = 0.34, H = 0.34, Color = Theme.Colors.PanelBackground, Corner = 0.5 },
		},
	},
	Power = {
		Accent = rgb(255, 206, 60),
		Shapes = {
			{ X = 0.56, Y = 0.29, W = 0.32, H = 0.54, Rot = 18, Color = rgb(255, 222, 96), Corner = 0.14 },
			{ X = 0.44, Y = 0.71, W = 0.32, H = 0.54, Rot = 18, Color = rgb(255, 196, 40), Corner = 0.14 },
		},
	},
	Storage = {
		Accent = rgb(58, 205, 238),
		Shapes = {
			{ X = 0.5, Y = 0.58, W = 0.86, H = 0.62, Color = rgb(58, 190, 226), Corner = 0.18 },
			{ X = 0.5, Y = 0.58, W = 0.86, H = 0.16, Color = rgb(28, 138, 170), Corner = 0.22 },
			{ X = 0.5, Y = 0.26, W = 0.86, H = 0.14, Color = rgb(140, 226, 248), Corner = 0.3 },
		},
	},
	Defense = {
		Accent = rgb(246, 82, 88),
		Shapes = {
			{ X = 0.5, Y = 0.42, W = 0.78, H = 0.6, Color = rgb(246, 96, 100), Corner = 0.24 },
			{ X = 0.5, Y = 0.74, W = 0.42, H = 0.4, Color = rgb(246, 96, 100), Corner = 0.4 },
			{ X = 0.5, Y = 0.48, W = 0.26, H = 0.34, Color = rgb(255, 210, 210), Corner = 0.3 },
		},
	},
	Gift = {
		Accent = rgb(255, 176, 48),
		Shapes = {
			{ X = 0.5, Y = 0.66, W = 0.88, H = 0.56, Color = rgb(255, 168, 40), Corner = 0.16 },
			{ X = 0.5, Y = 0.3, W = 0.96, H = 0.24, Color = rgb(255, 206, 100), Corner = 0.3 },
			{ X = 0.5, Y = 0.58, W = 0.18, H = 0.8, Color = rgb(214, 82, 96), Corner = 0.2 },
			{ X = 0.34, Y = 0.22, W = 0.26, H = 0.24, Color = rgb(214, 82, 96), Corner = 0.5 },
			{ X = 0.66, Y = 0.22, W = 0.26, H = 0.24, Color = rgb(214, 82, 96), Corner = 0.5 },
		},
	},
	Market = {
		Accent = rgb(92, 216, 112),
		Shapes = {
			{ X = 0.5, Y = 0.36, W = 0.9, H = 0.24, Color = rgb(140, 232, 156), Corner = 0.28 },
			{ X = 0.5, Y = 0.68, W = 0.72, H = 0.44, Color = rgb(78, 196, 98), Corner = 0.2 },
			{ X = 0.31, Y = 0.2, W = 0.16, H = 0.26, Color = rgb(52, 150, 72), Corner = 0.4 },
			{ X = 0.69, Y = 0.2, W = 0.16, H = 0.26, Color = rgb(52, 150, 72), Corner = 0.4 },
		},
	},
	Cosmetic = {
		Accent = rgb(255, 96, 176),
		Shapes = {
			{ X = 0.5, Y = 0.5, W = 0.9, H = 0.9, Color = rgb(255, 120, 190), Corner = 0.5 },
			{ X = 0.36, Y = 0.36, W = 0.22, H = 0.22, Color = rgb(255, 224, 240), Corner = 0.5 },
			{ X = 0.66, Y = 0.4, W = 0.18, H = 0.18, Color = rgb(216, 86, 236), Corner = 0.5 },
			{ X = 0.5, Y = 0.68, W = 0.2, H = 0.2, Color = rgb(150, 105, 255), Corner = 0.5 },
		},
	},
	Lab = {
		Accent = rgb(58, 205, 238),
		Shapes = {
			{ X = 0.5, Y = 0.22, W = 0.34, H = 0.2, Color = rgb(196, 240, 252), Corner = 0.3 },
			{ X = 0.5, Y = 0.6, W = 0.44, H = 0.7, Color = rgb(120, 216, 244), Corner = 0.3 },
			{ X = 0.5, Y = 0.74, W = 0.44, H = 0.42, Color = rgb(42, 168, 206), Corner = 0.3 },
		},
	},
	Trader = {
		Accent = rgb(255, 134, 58),
		Shapes = {
			{ X = 0.5, Y = 0.72, W = 0.24, H = 0.48, Color = rgb(255, 160, 90), Corner = 0.3 },
			{ X = 0.5, Y = 0.34, W = 0.84, H = 0.22, Rot = -20, Color = rgb(255, 190, 120), Corner = 0.4 },
			{ X = 0.22, Y = 0.44, W = 0.24, H = 0.24, Color = rgb(255, 134, 58), Corner = 0.5 },
			{ X = 0.78, Y = 0.24, W = 0.24, H = 0.24, Color = rgb(255, 134, 58), Corner = 0.5 },
		},
	},
	Quarters = {
		Accent = rgb(186, 155, 255),
		Shapes = {
			{ X = 0.5, Y = 0.3, W = 0.94, H = 0.3, Rot = 45, Color = rgb(200, 176, 255), Corner = 0.16 },
			{ X = 0.5, Y = 0.7, W = 0.72, H = 0.5, Color = rgb(160, 120, 255), Corner = 0.16 },
			{ X = 0.5, Y = 0.76, W = 0.26, H = 0.38, Color = rgb(96, 64, 178), Corner = 0.2 },
		},
	},
	Check = {
		Accent = rgb(92, 216, 112),
		Shapes = {
			{ X = 0.34, Y = 0.62, W = 0.34, H = 0.2, Rot = 45, Color = rgb(255, 255, 255), Corner = 0.5 },
			{ X = 0.58, Y = 0.44, W = 0.72, H = 0.2, Rot = -45, Color = rgb(255, 255, 255), Corner = 0.5 },
		},
	},
	Cross = {
		Accent = rgb(246, 82, 88),
		Shapes = {
			{ X = 0.5, Y = 0.5, W = 0.82, H = 0.2, Rot = 45, Color = rgb(255, 255, 255), Corner = 0.5 },
			{ X = 0.5, Y = 0.5, W = 0.82, H = 0.2, Rot = -45, Color = rgb(255, 255, 255), Corner = 0.5 },
		},
	},
	Lock = {
		Accent = rgb(150, 156, 190),
		Shapes = {
			{ X = 0.5, Y = 0.3, W = 0.44, H = 0.44, Color = rgb(150, 156, 190), Corner = 0.5 },
			{ X = 0.5, Y = 0.36, W = 0.24, H = 0.3, Color = Theme.Colors.CardBackground, Corner = 0.5 },
			{ X = 0.5, Y = 0.68, W = 0.7, H = 0.48, Color = rgb(196, 202, 230), Corner = 0.24 },
			{ X = 0.5, Y = 0.68, W = 0.14, H = 0.2, Color = rgb(96, 102, 132), Corner = 0.4 },
		},
	},
	Star = {
		Accent = rgb(255, 206, 60),
		Shapes = {
			{ X = 0.5, Y = 0.5, W = 0.26, H = 0.96, Color = rgb(255, 214, 92), Corner = 0.4 },
			{ X = 0.5, Y = 0.5, W = 0.26, H = 0.96, Rot = 60, Color = rgb(255, 214, 92), Corner = 0.4 },
			{ X = 0.5, Y = 0.5, W = 0.26, H = 0.96, Rot = -60, Color = rgb(255, 214, 92), Corner = 0.4 },
			{ X = 0.5, Y = 0.5, W = 0.4, H = 0.4, Color = rgb(255, 244, 190), Corner = 0.5 },
		},
	},
}

-- ---------------------------------------------------------------------
-- Rendering
-- ---------------------------------------------------------------------

function IconArt.GetItem(itemId: string): IconDefinition
	return icons[itemId] or DEFAULT_ICON
end

function IconArt.HasItem(itemId: string): boolean
	return icons[itemId] ~= nil
end

function IconArt.GetGlyph(name: string): IconDefinition
	return glyphs[name] or DEFAULT_ICON
end

-- Draws `definition` into `parent`, filling it. The parent is expected to be
-- square-ish; shapes are positioned in scale so the icon tracks any size.
--
-- Returns the container so a caller can tween/recolor it as one unit.
function IconArt.Render(parent: GuiObject, definition: IconDefinition, name: string?): Frame
	local container = Instance.new("Frame")
	container.Name = name or "IconArt"
	container.Size = UDim2.fromScale(1, 1)
	container.BackgroundTransparency = 1
	container.Parent = parent

	for index, shape in definition.Shapes do
		local piece = Instance.new("Frame")
		piece.Name = `Shape{index}`
		piece.AnchorPoint = Vector2.new(0.5, 0.5)
		piece.Position = UDim2.fromScale(shape.X, shape.Y)
		piece.Size = UDim2.fromScale(shape.W, shape.H)
		piece.Rotation = shape.Rot or 0
		piece.BackgroundColor3 = shape.Color
		piece.BackgroundTransparency = shape.Alpha or 0
		piece.BorderSizePixel = 0
		piece.ZIndex = index
		piece.Parent = container

		local corner = shape.Corner
		if corner and corner > 0 then
			local uiCorner = Instance.new("UICorner")
			-- Scale-based radius: a value of 0.5 on a square is a circle, and
			-- the shape stays correctly rounded at any rendered size.
			uiCorner.CornerRadius = UDim.new(corner, 0)
			uiCorner.Parent = piece
		end
	end

	return container
end

return IconArt
