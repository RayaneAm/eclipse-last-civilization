--!strict
-- Single source of truth for the premium UI system's visual language: colors,
-- spacing, corner radii, typography, and motion timings. Every new UI
-- component (src/client/UI/Components/) and every retrofitted hologram panel
-- reads from here instead of hand-rolling its own values, so the whole game
-- shares one consistent look instead of N slightly-different black panels.
--
-- Every value below is either lifted verbatim from the panel GateController
-- already established (black @ ~0.3 transparency, 1.5px stroke, Gotham
-- family) or derived from EclipseCoreGenerator's existing violet-blue
-- "Eclipse energy" palette (120,90,255 / 150,120,255 / 200,180,255) for the
-- generic brand accent — nothing here is an arbitrary new color scheme.
--
-- ===========================================================================
-- ECLIPSE UI ART DIRECTION SYSTEM (Phase: UI/HUD Visual Direction Pass)
-- ===========================================================================
-- The concrete "when to use what" rules every screen in this system follows.
-- ECLIPSE's UI is a brighter, more playful layer OVER a dark survival world —
-- not a full light theme, and not a clone of any reference game consulted
-- for direction. Read this before adding a new panel/card/surface.
--
-- SURFACES
--   PanelBackground — the outer panel of every screen, used exactly ONCE per
--     screen. This is the ONLY surface allowed a full-perimeter UIStroke.
--   CardBackground — a visibly lighter warm-neutral surface for nested rows/
--     cards/grouped sub-blocks (Surface.luau, OfferCard's "Stacked" cost
--     block). NEVER stroked — hierarchy comes from the background-shade step
--     + shadow, never a border.
--   HeroSurface (see Theme.HeroGradient below) — reserved for featured/hero
--     bands only (Shop's hero offers, Starter Pack, Marketplace's gated
--     banner). Deliberately rare so it reads as "special," never used for
--     ordinary rows.
--   Resource/material colors are NOT duplicated here — they stay owned by
--     ItemIconConfig.luau (per-item glyph + accent), which every economy
--     screen already reads from.
--
-- ACCENT COLORS
--   Brand / BrandLight — core progression UI (Menu, general navigation).
--   Gold — premium/featured/promo ONLY (Starter Pack, "Featured" badges,
--     Premium tab). Kept exclusive to monetization/promo contexts so it
--     keeps meaning instead of becoming a second generic accent.
--   Teal — economy/trade-adjacent HUD entries (Shop, Supply Shop) so the HUD
--     reads as more than one repeated purple.
--   Danger — locked/blocked states, destructive actions, close-button glyph.
--
-- TYPOGRAPHY
--   The existing Title/Heading/Body/Label/Caption/Stat scale stays as-is.
--   Font.Hero is reserved for hero-card headlines ONLY (Shop offers, Starter
--     Pack) — never for an ordinary panel title.
--
-- DEPTH
--   Shadow (default) — buttons, list rows.
--   Shadow.Card — nested cards (Surface, OfferCard): slightly larger offset.
--   Shadow.Hero — hero bands and HUD icons (which float directly over the
--     busy 3D world and need more separation than an in-panel card): the
--     strongest offset/opacity. Bigger/more prominent surfaces get
--     proportionally stronger shadows, never the reverse.
--
-- BORDER RULE (the actual fix for "border-inside-border")
--   Exactly ONE stroked surface per screen: the outer GlassPanel. Every
--   nested surface (Surface, CardBackground blocks, HeroSurface bands) is
--   stroke-free — differentiated by background shade + shadow only. The
--   only components allowed a thin stroke besides the outer panel are small
--   chips (Pill, StatusBadge) since they're not "boxes."
-- ===========================================================================

local Theme = {}

Theme.Colors = {
	PanelBackground = Color3.fromRGB(12, 11, 18), -- near-black with a cool violet undertone matching Brand, richer than flat black
	CardBackground = Color3.fromRGB(32, 29, 42), -- visibly lighter than PanelBackground — nested rows/cards read as a real step up, not a stroke
	Brand = Color3.fromRGB(140, 110, 255),
	BrandLight = Color3.fromRGB(180, 160, 255),
	BrandDim = Color3.fromRGB(100, 80, 200),
	Gold = Color3.fromRGB(255, 190, 90), -- premium/featured/promo only — formalizes the value Starter Pack already hardcoded ad hoc
	Teal = Color3.fromRGB(90, 200, 190), -- economy/trade HUD accent (Shop, Supply Shop)
	Trade = Color3.fromRGB(80, 190, 225), -- player-to-player trading / marketplace
	TextPrimary = Color3.new(1, 1, 1),
	TextSecondary = Color3.fromRGB(215, 215, 220),
	TextMuted = Color3.fromRGB(160, 160, 170),
	Success = Color3.fromRGB(120, 220, 130),
	Danger = Color3.fromRGB(220, 90, 90),
	Warning = Color3.fromRGB(230, 160, 160),
}

Theme.Transparency = {
	PanelBackground = 0.22, -- richer/less washed-out glass than the original 0.32
	CardBackground = 0.08, -- deliberately much less transparent than PanelBackground so it reads as a real lighter surface, not a slightly-different shade of the same dark
	StrokeDefault = 0.15,
	StrokeSubtle = 0.2,
	StrokeBright = 0.05,
	GradientNear = 0.8,
	GradientFar = 0.92,
}

Theme.Shadow = {
	Transparency = 0.6,
	Offset = Vector2.new(0, 4),
	Color = Color3.new(0, 0, 0),
	-- Nested cards (Surface, OfferCard) — slightly stronger than the default
	-- so a card reads as sitting above the panel behind it.
	Card = {
		Transparency = 0.5,
		Offset = Vector2.new(0, 6),
	},
	-- Hero bands and HUD icons — the strongest depth in the system, reserved
	-- for surfaces that need to separate from a busy background (the 3D
	-- world behind HUD icons, or a featured offer band).
	Hero = {
		Transparency = 0.4,
		Offset = Vector2.new(0, 8),
	},
}

Theme.Corner = {
	Small = UDim.new(0, 6),
	Medium = UDim.new(0, 8),
	Large = UDim.new(0, 16),
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

Theme.Font = {
	Title = { Font = Enum.Font.GothamBlack, Size = 20 },
	Heading = { Font = Enum.Font.GothamBold, Size = 16 },
	Body = { Font = Enum.Font.Gotham, Size = 13 },
	Label = { Font = Enum.Font.GothamMedium, Size = 12 },
	Caption = { Font = Enum.Font.Gotham, Size = 11 },
	-- Numeric HUD readouts (currency, XP) — same size as Heading, but Black
	-- weight so weight alone differentiates "this is a stat" from "this is a
	-- label," a common premium-HUD hierarchy technique.
	Stat = { Font = Enum.Font.GothamBlack, Size = 16 },
	-- Hero-card headlines ONLY (Shop offers, Starter Pack) — bigger than
	-- Title so a featured offer's name reads as the visual anchor of the
	-- card. Never used for an ordinary panel title.
	Hero = { Font = Enum.Font.GothamBlack, Size = 28 },
}

-- The one HeroSurface gradient used by every hero band (HeroOffer, OfferCard's
-- "Stacked" preview plate) — accent color toward a darker version of itself,
-- rather than a flat fill, so featured surfaces read as richer/more premium
-- than an ordinary CardBackground block. Centralized here (not hand-rolled
-- per component) so "hero" always means the same visual treatment.
function Theme.HeroGradient(accentColor: Color3): UIGradient
	local gradient = Instance.new("UIGradient")
	gradient.Name = "HeroGradient"
	gradient.Color = ColorSequence.new(accentColor, accentColor:Lerp(Color3.new(0, 0, 0), 0.55))
	gradient.Rotation = 90
	return gradient
end

-- Every duration/easing here stays inside the vocabulary already established
-- across GateController/AmbientController/CameraIntroController: Quad/Out,
-- durations clustering 0.15-0.6s. No Back/Bounce/Elastic anywhere.
Theme.Motion = {
	HoverIn = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	HoverOut = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	PressDown = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	PressUp = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	PanelOpen = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	PanelClose = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Fade = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	-- Continuous ambient glow (icon-tile pulse) — Sine/InOut is the
	-- vocabulary already used for smooth continuous motion (camera work),
	-- never Quad/InOut and never a new easing family.
	Pulse = TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
}

Theme.MinTouchTarget = 48 -- px, minimum interactive control size on any platform

return Theme
