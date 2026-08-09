--!strict
-- The ECLIPSE FACILITY UI LANGUAGE — one shared vocabulary every facility
-- modal (Base Management, Production, Generator, Storage, Defense, Upgrade
-- Station, Daily Rewards, Survivor Market, Cosmetic Shop, Laboratory) reads
-- from, so all of them visibly belong to the same game.
--
-- This layers ON TOP of Theme.luau — it never replaces it. Theme still owns
-- the base surfaces/typography/spacing/motion vocabulary; this module owns
-- only the facility-specific decisions Theme has no opinion about:
--
--   * per-facility ACCENT (header band, icon tint, thin highlights) — the
--     single place a facility's identity is expressed. The dark shell stays
--     identical across every facility; we never recolor a whole screen.
--   * STATUS colors (Ready/Running/Idle/Stable/Low/Critical/Locked), so
--     "● READY" means the same green in Production as in the Generator.
--   * DEFENSE TIER accents (wood/reinforced/metal/advanced) used by tier
--     pips and upgrade comparisons.
--   * RARITY presentation, re-exported from the shared RarityConfig so a
--     client-side card never invents its own rarity palette.
--   * RESPONSIVE sizing — the one place that decides how wide a facility
--     panel is on desktop vs landscape mobile vs a narrow phone.
--
-- Nothing here carries gameplay balance. Costs, durations, weights, prices
-- and probabilities all stay in their existing config modules.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RarityConfig = require(ReplicatedStorage.Shared.Config.RarityConfig)
local Theme = require(script.Parent.Theme)

local FacilityStyle = {}

-- ---------------------------------------------------------------------
-- Facility identity
-- ---------------------------------------------------------------------

export type FacilityIdentity = {
	Icon: string, -- an IconArt glyph name, NOT an emoji (see IconArt's header)
	Title: string,
	Subtitle: string,
	Accent: Color3,
}

-- One saturated hue per facility. These now drive a full-bleed header BAR,
-- the icon tile, section headings, meters and CTAs — so a facility is
-- identifiable from its color alone before any text is read. The previous
-- muted set (all roughly the same lightness, several near-identical blues)
-- could not do that job.
FacilityStyle.Accents = {
	BaseManagement = Theme.Colors.Violet,
	Build = Theme.Colors.Blue,
	UpgradeStation = Theme.Colors.Orange,
	Production = Theme.Colors.Teal,
	Generator = Theme.Colors.Yellow,
	Storage = Theme.Colors.Cyan,
	Defense = Theme.Colors.Red,
	DailyRewards = Theme.Colors.Gold,
	SurvivorMarket = Theme.Colors.Green,
	CosmeticShop = Theme.Colors.Pink,
	Laboratory = Theme.Colors.Cyan,
	Trader = Theme.Colors.Orange,
	Quarters = Theme.Colors.BrandLight,
}

-- Every facility's header line, in one table, so a title/subtitle is never
-- retyped (and never drifts) between the world prompt and the modal.
--
-- `Icon` is an IconArt glyph key. It is deliberately NOT an emoji: the emoji
-- previously used here are the same class of codepoint that renders as an
-- empty box on clients with an older system emoji font.
FacilityStyle.Facilities = {
	BaseManagement = { Icon = "Base", Title = "BASE MANAGEMENT", Subtitle = "Your settlement at a glance", Accent = FacilityStyle.Accents.BaseManagement },
	UpgradeStation = { Icon = "Upgrade", Title = "UPGRADE STATION", Subtitle = "What you can improve right now", Accent = FacilityStyle.Accents.UpgradeStation },
	Production = { Icon = "Production", Title = "RESOURCE PROCESSOR", Subtitle = "Refine raw materials", Accent = FacilityStyle.Accents.Production },
	Generator = { Icon = "Power", Title = "BASIC GENERATOR", Subtitle = "Powers machines and systems", Accent = FacilityStyle.Accents.Generator },
	Defense = { Icon = "Defense", Title = "DEFENSE CONTROL", Subtitle = "Perimeter status", Accent = FacilityStyle.Accents.Defense },
	Storage = { Icon = "Storage", Title = "BASE STORAGE", Subtitle = "Shared settlement materials", Accent = FacilityStyle.Accents.Storage },
	DailyRewards = { Icon = "Gift", Title = "DAILY REWARDS", Subtitle = "Return each day for supplies", Accent = FacilityStyle.Accents.DailyRewards },
	SurvivorMarket = { Icon = "Market", Title = "SURVIVOR MARKET", Subtitle = "Trade salvage with the Merchant", Accent = FacilityStyle.Accents.SurvivorMarket },
	CosmeticShop = { Icon = "Cosmetic", Title = "COSMETIC SHOP", Subtitle = "Survivor clothing and field gear", Accent = FacilityStyle.Accents.CosmeticShop },
	Laboratory = { Icon = "Lab", Title = "CAPSULE LABORATORY", Subtitle = "Decode recovered capsules", Accent = FacilityStyle.Accents.Laboratory },
	Trader = { Icon = "Trader", Title = "TRADER TERMINAL", Subtitle = "Instant buy and sell", Accent = FacilityStyle.Accents.Trader },
	Quarters = { Icon = "Quarters", Title = "SURVIVOR QUARTERS", Subtitle = "Shelter for your settlement", Accent = FacilityStyle.Accents.Quarters },
} :: { [string]: FacilityIdentity }

-- ---------------------------------------------------------------------
-- Status colors
-- ---------------------------------------------------------------------

export type StatusKind = "Ready" | "Running" | "Idle" | "Stable" | "Low" | "Critical" | "Locked" | "Offline" | "Available"

FacilityStyle.StatusColor = {
	Ready = Theme.Colors.Green,
	Running = Theme.Colors.Teal,
	Idle = Theme.Colors.TextMuted,
	Stable = Theme.Colors.Green,
	Low = Theme.Colors.Gold,
	Critical = Theme.Colors.Red,
	Locked = Theme.Colors.TextMuted,
	Offline = Theme.Colors.TextMuted,
	Available = Theme.Colors.Green,
} :: { [StatusKind]: Color3 }

-- ---------------------------------------------------------------------
-- Defense tiers
-- ---------------------------------------------------------------------

-- Tier accents from the brief: wood brown, reinforced stone-gray, metal
-- steel-blue, advanced powered purple/cyan. Index 0 = nothing built yet.
FacilityStyle.TierColor = {
	[0] = Color3.fromRGB(66, 70, 104), -- nothing built — reads as an empty slot
	[1] = Color3.fromRGB(186, 128, 72), -- WOOD, warm brown
	[2] = Color3.fromRGB(178, 184, 200), -- REINFORCED, stone grey
	[3] = Color3.fromRGB(86, 164, 240), -- METAL, steel blue
	[4] = Color3.fromRGB(176, 116, 255), -- ADVANCED, powered violet
}

FacilityStyle.MaxDefenseTier = 4

function FacilityStyle.TierAccent(tier: number): Color3
	return FacilityStyle.TierColor[math.clamp(math.floor(tier), 0, FacilityStyle.MaxDefenseTier)]
end

-- ---------------------------------------------------------------------
-- Rarity (re-exported — the source of truth is the shared config)
-- ---------------------------------------------------------------------

FacilityStyle.Rarity = RarityConfig

-- ---------------------------------------------------------------------
-- Responsive layout
-- ---------------------------------------------------------------------

-- One place decides facility panel geometry for every screen size.
--   Desktop        — a compact centered panel, never a fullscreen takeover.
--   Landscape phone/tablet — 60-75% of width, per the brief.
--   Narrow/portrait — nearly full width, content stacks and scrolls.
export type Breakpoint = "Narrow" | "Landscape" | "Desktop"

function FacilityStyle.Breakpoint(viewportSize: Vector2): Breakpoint
	if viewportSize.X < 640 then
		return "Narrow"
	elseif viewportSize.X < 1100 then
		return "Landscape"
	end
	return "Desktop"
end

-- Returns (size, minSize, maxSize) for a facility panel of the given width
-- class. `widthClass` lets a content-heavy screen (Cosmetic Shop's grid +
-- preview) ask for more room than a single-column one (Build confirm).
export type WidthClass = "Compact" | "Regular" | "Wide"

local WIDTH_CAPS: { [WidthClass]: { Narrow: number, Landscape: number, Desktop: number } } = {
	Compact = { Narrow = 400, Landscape = 460, Desktop = 480 },
	Regular = { Narrow = 440, Landscape = 620, Desktop = 660 },
	Wide = { Narrow = 480, Landscape = 780, Desktop = 900 },
}

local WIDTH_SCALE: { [Breakpoint]: number } = {
	Narrow = 0.94,
	Landscape = 0.75,
	Desktop = 0.62,
}

function FacilityStyle.PanelGeometry(viewportSize: Vector2, widthClass: WidthClass?): (UDim2, Vector2, Vector2)
	local breakpoint = FacilityStyle.Breakpoint(viewportSize)
	local class = widthClass or "Regular"
	local caps = WIDTH_CAPS[class]

	local widthScale = WIDTH_SCALE[breakpoint]
	local usableWidth = math.max(1, viewportSize.X - 24)
	local minWidth = math.min(300, usableWidth)
	local maxWidth = math.max(minWidth, caps[breakpoint])
	-- Height stays a scale so short landscape phones never produce a panel
	-- taller than the screen; the max clamps it on a tall desktop monitor.
	local heightScale = if breakpoint == "Narrow" then 0.86 else 0.82
	-- Studio briefly reports 0x0 or 1x1 while a Play camera is being created.
	-- At that point the physical viewport cannot accommodate the usual 260px
	-- minimum. Collapse both bounds to the available height and let the camera
	-- ViewportSize signal restore the normal constraints on the next update.
	local maxHeight = math.max(1, math.min(math.max(0, viewportSize.Y) * heightScale, 720))
	local minHeight = math.min(260, maxHeight)

	return UDim2.new(widthScale, 0, heightScale, 0), Vector2.new(minWidth, minHeight), Vector2.new(maxWidth, maxHeight)
end

-- True when content should stack vertically instead of sitting side by side
-- (Cosmetic Shop preview, market two-column rows).
function FacilityStyle.ShouldStack(viewportSize: Vector2): boolean
	return FacilityStyle.Breakpoint(viewportSize) == "Narrow"
end

-- ---------------------------------------------------------------------
-- Small shared formatters — used by several facilities, so they live once.
-- ---------------------------------------------------------------------

function FacilityStyle.FormatClock(seconds: number): string
	local total = math.max(0, math.floor(seconds))
	local hours = total // 3600
	local minutes = (total % 3600) // 60
	local secs = total % 60
	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, secs)
	end
	return string.format("%02d:%02d", minutes, secs)
end

-- Turns an internal item id ("ReinforcedPlanks") into a readable label
-- ("Reinforced Planks"). Item ids are PascalCase by convention across
-- ResourceConfig/BuildingConfig, so this is a presentation-only transform —
-- no per-item display-name table to keep in sync.
function FacilityStyle.PrettyName(itemId: string): string
	local spaced = string.gsub(itemId, "(%l)(%u)", "%1 %2")
	return (string.gsub(spaced, "_", " "))
end

return FacilityStyle
