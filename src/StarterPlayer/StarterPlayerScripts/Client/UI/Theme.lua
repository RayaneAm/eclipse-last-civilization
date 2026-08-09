--!strict
-- Single source of truth for the ECLIPSE UI visual language: colors,
-- spacing, corner radii, stroke weights, typography and motion timings.
--
-- ===========================================================================
-- ART DIRECTION (Facility UI Visual Rebuild pass)
-- ===========================================================================
-- The previous revision of this file produced a competent but generic dark
-- dashboard: near-black panels, 1.5px hairline strokes, muted accents used
-- sparingly, and cards that differed from their background by only a few
-- shades. On screen that read as a web admin panel, not a Roblox game.
--
-- This revision keeps ECLIPSE's dark survival identity but rebuilds the
-- system around four rules taken from polished simulator/tycoon UI:
--
--   1. LADDER, NOT MUD. Surfaces step up in clearly distinguishable stages
--      (Void -> Panel -> Surface -> Card -> CardRaised). Each step is a
--      visible jump, so a card always reads as sitting ON something rather
--      than being a slightly different dark.
--
--   2. DARK OUTLINES ON BRIGHT SHAPES. Strokes are near-black (Theme.Colors
--      .Void), not accent-tinted hairlines, and they are 2-3px. This is what
--      produces the chunky, sticker-like, tactile look — a 1px accent border
--      reads as a web control at any size.
--
--   3. ACCENTS CARRY MEANING AND ARE SATURATED. The palette below is a full
--      spectrum of vivid hues, one per facility/state, rather than one purple
--      reused everywhere. Accents appear on headers, icon holders, buttons,
--      meters and strips — never as a full-panel wash.
--
--   4. NOTHING IS FLAT. Buttons and cards get a darker bottom lip plus a
--      top highlight, which is what makes them look pressable.
--
-- SURFACE ROLES
--   Void        — strokes, shadows, the darkest possible ink. Never a fill
--                 for a large area.
--   PanelBackground — the modal body behind everything.
--   Surface     — a content well inside the panel (scroll regions, groups).
--   CardBackground  — ordinary rows and cards.
--   CardRaised  — hover/selected/emphasis state of a card.
--
-- Resource/material colors are NOT duplicated here — they stay owned by
-- ItemIconConfig + IconArt, which every economy screen reads from.
-- ===========================================================================

local Theme = {}

Theme.Colors = {
	-- --- Surface ladder -------------------------------------------------
	-- Deliberately blue-violet rather than neutral grey: the whole UI reads
	-- as one cool family, and warm accents (gold, orange) pop hard against it.
	Void = Color3.fromRGB(10, 11, 22), -- strokes + shadows only
	PanelBackground = Color3.fromRGB(27, 29, 51),
	Surface = Color3.fromRGB(38, 41, 70),
	CardBackground = Color3.fromRGB(52, 56, 94),
	CardRaised = Color3.fromRGB(68, 73, 118),

	-- --- Accent spectrum -------------------------------------------------
	-- One vivid hue per facility/state (see FacilityStyle for the mapping).
	Violet = Color3.fromRGB(150, 105, 255),
	Blue = Color3.fromRGB(72, 148, 255),
	Cyan = Color3.fromRGB(58, 205, 238),
	Teal = Color3.fromRGB(42, 206, 180),
	Green = Color3.fromRGB(92, 216, 112),
	Lime = Color3.fromRGB(164, 226, 68),
	Yellow = Color3.fromRGB(255, 206, 60),
	Gold = Color3.fromRGB(255, 176, 48),
	Orange = Color3.fromRGB(255, 134, 58),
	Red = Color3.fromRGB(246, 82, 88),
	Pink = Color3.fromRGB(255, 96, 176),
	Magenta = Color3.fromRGB(216, 86, 236),

	-- --- Semantic aliases -------------------------------------------------
	-- Kept as the names the rest of the codebase already imports, so this
	-- rebuild is a re-skin rather than a breaking API change.
	Brand = Color3.fromRGB(150, 105, 255),
	BrandLight = Color3.fromRGB(186, 155, 255),
	BrandDim = Color3.fromRGB(96, 64, 178),
	Trade = Color3.fromRGB(72, 148, 255),
	Success = Color3.fromRGB(92, 216, 112),
	Danger = Color3.fromRGB(246, 82, 88),
	Warning = Color3.fromRGB(255, 176, 48),

	-- --- Text -------------------------------------------------------------
	TextPrimary = Color3.fromRGB(255, 255, 255),
	TextSecondary = Color3.fromRGB(206, 210, 235),
	TextMuted = Color3.fromRGB(150, 156, 190),
	-- For text sitting ON a bright accent fill (header titles, rarity strips,
	-- button labels on yellow/gold). White would smear on gold; this near-
	-- black keeps contrast at every accent hue.
	TextOnAccent = Color3.fromRGB(18, 16, 32),
}

Theme.Transparency = {
	-- Panels and cards are now essentially OPAQUE. The old glassy 0.22/0.08
	-- let the 3D world bleed through every surface, which is the single
	-- biggest reason the UI read as washed-out and low-contrast.
	PanelBackground = 0,
	CardBackground = 0,
	StrokeDefault = 0,
	StrokeSubtle = 0.35,
	StrokeBright = 0,
	GradientNear = 0.85,
	GradientFar = 0.97,
}

-- Stroke weights. The chunky look lives here: important surfaces get a real
-- 2-3px dark outline, not a hairline.
Theme.Stroke = {
	Panel = 3, -- the outer modal edge
	Card = 2, -- cards, buttons, chips
	Thin = 1.5, -- inner dividers, small badges
}

Theme.Shadow = {
	Transparency = 0.45,
	Offset = Vector2.new(0, 5),
	Color = Color3.new(0, 0, 0),
	Card = {
		Transparency = 0.4,
		Offset = Vector2.new(0, 6),
	},
	Hero = {
		Transparency = 0.3,
		Offset = Vector2.new(0, 10),
	},
}

-- Chunkier than before across the board — small radii on big shapes are a
-- large part of what made the old panels feel like web dialogs.
Theme.Corner = {
	Small = UDim.new(0, 8),
	Medium = UDim.new(0, 14),
	Large = UDim.new(0, 22),
	Pill = UDim.new(1, 0),
}

Theme.Spacing = {
	XXS = 2,
	XS = 4,
	S = 8,
	M = 12,
	L = 16,
	XL = 24,
	XXL = 32,
}

export type FontStyle = { Font: Enum.Font, Size: number }

-- Weights pushed heavier and sizes up. GothamBlack for anything structural
-- (titles, stats, buttons) so hierarchy is obvious at a glance on a phone.
Theme.Font = {
	Title = { Font = Enum.Font.GothamBlack, Size = 24 },
	Heading = { Font = Enum.Font.GothamBold, Size = 17 },
	Body = { Font = Enum.Font.GothamMedium, Size = 14 },
	Label = { Font = Enum.Font.GothamBold, Size = 12 },
	Caption = { Font = Enum.Font.GothamMedium, Size = 11 },
	Stat = { Font = Enum.Font.GothamBlack, Size = 18 },
	Hero = { Font = Enum.Font.GothamBlack, Size = 32 },
	-- Button labels: black weight, slightly tighter than Heading so a CTA
	-- reads as a control rather than a sentence.
	Button = { Font = Enum.Font.GothamBlack, Size = 16 },
}

-- The one "hero"/featured gradient, accent toward a darker version of itself.
function Theme.HeroGradient(accentColor: Color3): UIGradient
	local gradient = Instance.new("UIGradient")
	gradient.Name = "HeroGradient"
	gradient.Color = ColorSequence.new(accentColor, accentColor:Lerp(Color3.new(0, 0, 0), 0.55))
	gradient.Rotation = 90
	return gradient
end

-- The top-highlight -> base gradient that makes a filled shape look lit from
-- above. Used by buttons, header bars and icon holders; this plus the darker
-- bottom lip is the whole "3D chunky" trick, at zero runtime cost.
function Theme.GlossGradient(accentColor: Color3): UIGradient
	local gradient = Instance.new("UIGradient")
	gradient.Name = "Gloss"
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, accentColor:Lerp(Color3.new(1, 1, 1), 0.28)),
		ColorSequenceKeypoint.new(0.55, accentColor),
		ColorSequenceKeypoint.new(1, accentColor:Lerp(Color3.new(0, 0, 0), 0.18)),
	})
	gradient.Rotation = 90
	return gradient
end

-- Attaches the standard dark outline. Centralized so "how thick, what color"
-- is answered once rather than per component.
function Theme.Outline(parent: GuiObject, thickness: number?, color: Color3?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Outline"
	stroke.Color = color or Theme.Colors.Void
	stroke.Thickness = thickness or Theme.Stroke.Card
	stroke.Transparency = 0
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

-- Motion. Faster and snappier than the previous 0.35s panel timings — game
-- UI should feel immediate. Still Quad only; no Back/Bounce/Elastic.
Theme.Motion = {
	HoverIn = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	HoverOut = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	PressDown = TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	PressUp = TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	PanelOpen = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	PanelClose = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Fade = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Pulse = TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
}

Theme.MinTouchTarget = 48 -- px, minimum interactive control size on any platform

return Theme
