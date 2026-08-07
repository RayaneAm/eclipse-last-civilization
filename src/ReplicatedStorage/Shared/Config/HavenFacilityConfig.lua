--!strict
-- Identity for Haven's functional areas — mirrors BiomeConfig's role for
-- gates. Consumed by tools/Generators/CivicBuildingGenerator.luau and
-- GuidanceGenerator.luau (what to build, where, and what it's called) and by
-- src/client/Controllers/FacilityController.luau (the hologram info panel).
--
-- Survivor Haven redesign Phase 1: `placement/slotIndex/slotCount` (the old
-- shared-ring-slot model) replaced with direct `angleDegrees`/`radius` per
-- facility, matching the new amphitheater composition (a left cluster near
-- Tutorial/Daily Rewards, a right cluster near Leaderboards/Base Gate — see
-- HavenLayoutConfig.luau's header comment for the full picture). `bespoke`
-- replaces the old "Bespoke" placement value: true for the 2 facilities
-- still built outside the generic tools/BuildHavenDistricts.luau loop
-- (QuestGiver by GuidanceGenerator, Leaderboards by
-- tools/BuildSurvivorHaven.luau), exactly as before.
--
-- `id`, `name`, `description`, `district` (still used only for
-- HavenLayoutConfig.GetDistrict's accentColor lookup), and `kind` are all
-- unchanged from the previous schema — FacilityController's hologram lookup
-- and CivicBuildingGenerator's kind-dispatch both keep working untouched.
--
-- Phase 1 correction pass: the angle/radius values below were re-derived
-- from each facility's REAL built bounding footprint (CivicBuildingGenerator's
-- plinth + fitout forward-reach per its size tier), not guessed — the first
-- pass had several genuinely overlapping buildings because its numbers were
-- picked from an angle/radius table alone. See the plan's "Measured bounding
-- footprints" section for the exact math.
--
-- Tutorial path signage isn't listed here — it's plain directional signage,
-- not a single interactable point, so it has no FacilityAnchor/hologram. The
-- Tutorial Portal itself is also not a facility — it's portal/travel
-- infrastructure, owned by PortalDestinationConfig, not this file.

local HavenLayoutConfig = require(script.Parent.HavenLayoutConfig)

export type FacilityKind =
	"Market"
	| "CapsuleLab"
	| "UpgradeStation"
	| "Leaderboard"
	| "DailyRewards"
	| "SeasonEvent"
	| "EventPavilion"
	| "GamepassShowcase"
	| "StarterPack"
	| "CosmeticShop"
	| "QuestNPC"

export type FacilityDefinition = {
	id: string,
	name: string,
	description: string,
	district: HavenLayoutConfig.DistrictId,
	kind: FacilityKind,
	angleDegrees: number,
	radius: number,
	bespoke: boolean, -- true: built outside the generic BuildHavenDistricts loop (QuestGiver/Leaderboards)
}

local HavenFacilityConfig = {
	{
		id = "QuestGiver",
		name = "Survivor Network Outpost",
		description = "Begin your journey to rebuild civilization.",
		district = "Onboarding",
		kind = "QuestNPC",
		angleDegrees = 165,
		radius = 85,
		bespoke = true,
	},
	{
		id = "UpgradeStation",
		name = "Upgrade Station",
		description = "Reinforce your gear with salvaged technology.",
		district = "Progression",
		kind = "UpgradeStation",
		angleDegrees = -70,
		radius = 65,
		bespoke = false,
	},
	{
		id = "Leaderboards",
		name = "Survivor Leaderboards",
		description = "See how your civilization measures up.",
		district = "Progression", -- descriptive only; physically placed near the Central Arrival Core, not this angle
		kind = "Leaderboard",
		angleDegrees = -160,
		radius = 85,
		bespoke = true,
	},
	{
		id = "SurvivorMarket",
		name = "Survivor Market",
		description = "Trade salvaged goods and rare finds with the Survivor Network.",
		district = "Commerce",
		kind = "Market",
		angleDegrees = -132,
		radius = 100,
		bespoke = false,
	},
	{
		id = "DailyRewards",
		name = "Daily Rewards",
		description = "Check in each day for supplies.",
		district = "Commerce",
		kind = "DailyRewards",
		angleDegrees = 145,
		radius = 100,
		bespoke = false,
	},
	{
		id = "CapsuleLaboratory",
		name = "Capsule Laboratory",
		description = "Decode recovered survival capsules.",
		district = "Commerce",
		kind = "CapsuleLab",
		angleDegrees = 82,
		radius = 90,
		bespoke = false,
	},
	{
		id = "GamepassShowcase",
		name = "Gamepass Showcase",
		description = "Permanent perks for your civilization.",
		district = "Commerce",
		kind = "GamepassShowcase",
		angleDegrees = 120,
		radius = 105,
		-- Phase 3B: UI-first now (see ShopController) — no world structure
		-- at all. `bespoke` just needs to stay true so BuildHavenDistricts'
		-- generic loop skips it; nothing builds it in place of that loop.
		bespoke = true,
	},
	{
		id = "StarterPack",
		name = "Starter Pack",
		description = "Featured offers for new survivors.",
		district = "Commerce",
		kind = "StarterPack",
		angleDegrees = 108,
		radius = 75,
		bespoke = true,
	},
	{
		id = "CosmeticShop",
		name = "Cosmetic Shop",
		description = "Skins, trails and nameplates — for looking good, not winning.",
		district = "Commerce",
		kind = "CosmeticShop",
		angleDegrees = 58,
		radius = 68,
		bespoke = false,
	},
	{
		id = "SeasonEvent",
		name = "Eclipse Event Pavilion",
		description = "Limited-time survivor initiatives.",
		district = "EventSeason",
		kind = "SeasonEvent",
		angleDegrees = -108,
		radius = 110,
		-- Built together with SeasonPass via SeasonPavilionGenerator instead
		-- of 2 near-duplicate buildings — see BuildHavenDistricts.luau's
		-- special case. Phase 3B: Season Pass is UI-first now (see
		-- ShopController), so this shrank to one small, non-interactive
		-- "Season Terminal" visual touchpoint rather than a real building.
		bespoke = true,
	},
	{
		id = "SeasonPass",
		name = "Season Pass Pavilion",
		description = "Seasonal progression and rewards for the Eclipse survivors.",
		district = "EventSeason",
		kind = "EventPavilion",
		angleDegrees = -100,
		radius = 78,
		bespoke = true,
	},
} :: { FacilityDefinition }

return HavenFacilityConfig
