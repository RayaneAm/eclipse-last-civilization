--!strict
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
	| "DailyQuestBoard"
export type FacilityDefinition = {
	id: string,
	name: string,
	description: string,
	district: HavenLayoutConfig.DistrictId,
	kind: FacilityKind,
	localPosition: Vector3,
	frontDirection: Vector3,
	bespoke: boolean,
}

local HavenFacilityConfig = {
	-- Bespoke: DailyQuestBoardGenerator authors the physical notice board, the
	-- same way the Leaderboards hall authors its own. This entry only carries
	-- the interaction contract FacilityController reads off the tagged anchor.
	{
		id = "DailyQuests",
		name = "Daily Quests",
		description = "Today's survivor tasks. Refreshes every day.",
		district = "Onboarding",
		kind = "DailyQuestBoard",
		localPosition = HavenLayoutConfig.NOTICE_BOARD_LOCAL_POSITION,
		frontDirection = Vector3.new(0, 0, 1),
		bespoke = true,
	},
	{
		id = "UpgradeStation",
		name = "Upgrade Station",
		description = "Reinforce gear with salvaged technology.",
		district = "Progression",
		kind = "UpgradeStation",
		-- Shared 18-stud depth: rear edge lands on the east wall inner face.
		localPosition = Vector3.new(49, 0, 52),
		frontDirection = Vector3.new(-1, 0, 0),
		bespoke = false,
	},
	{
		id = "Leaderboards",
		name = "Leaderboards",
		description = "Survivor records.",
		district = "Progression",
		kind = "Leaderboard",
		localPosition = HavenLayoutConfig.LEADERBOARD_LOCAL_POSITION,
		frontDirection = (HavenLayoutConfig.SPAWN_LOCAL_POSITION - HavenLayoutConfig.LEADERBOARD_LOCAL_POSITION).Unit,
		bespoke = true,
	},
	{
		id = "SurvivorMarket",
		name = "Survivor Market",
		description = "Trade salvaged goods with the Merchant.",
		district = "Commerce",
		kind = "Market",
		localPosition = Vector3.new(-49, 0, 52),
		frontDirection = Vector3.new(1, 0, 0),
		bespoke = false,
	},
	{
		id = "DailyRewards",
		name = "Daily Rewards",
		description = "Check in for supplies.",
		district = "Commerce",
		kind = "DailyRewards",
		localPosition = Vector3.new(49, 0, 25),
		frontDirection = Vector3.new(-1, 0, 0),
		bespoke = false,
	},
	{
		id = "CapsuleLaboratory",
		name = "Capsule Laboratory",
		description = "Decode recovered survival capsules.",
		district = "Commerce",
		kind = "CapsuleLab",
		localPosition = Vector3.new(-49, 0, 0),
		frontDirection = Vector3.new(1, 0, 0),
		bespoke = false,
	},
	{
		id = "CosmeticShop",
		name = "Cosmetic Shop",
		description = "Survivor clothing and field gear.",
		district = "Commerce",
		kind = "CosmeticShop",
		localPosition = Vector3.new(-49, 0, 26),
		frontDirection = Vector3.new(1, 0, 0),
		bespoke = false,
	},
	-- Retained for UI lookups only. No physical marketplace or premium building.
	{
		id = "GamepassShowcase",
		name = "Gamepass Showcase",
		description = "UI only.",
		district = "Commerce",
		kind = "GamepassShowcase",
		localPosition = Vector3.zero,
		frontDirection = Vector3.zAxis,
		bespoke = true,
	},
	{
		id = "StarterPack",
		name = "Starter Pack",
		description = "UI only.",
		district = "Commerce",
		kind = "StarterPack",
		localPosition = Vector3.zero,
		frontDirection = Vector3.zAxis,
		bespoke = true,
	},
	{
		id = "SeasonEvent",
		name = "Eclipse Event",
		description = "UI only.",
		district = "EventSeason",
		kind = "SeasonEvent",
		localPosition = Vector3.zero,
		frontDirection = Vector3.zAxis,
		bespoke = true,
	},
	{
		id = "SeasonPass",
		name = "Season Pass",
		description = "UI only.",
		district = "EventSeason",
		kind = "EventPavilion",
		localPosition = Vector3.zero,
		frontDirection = Vector3.zAxis,
		bespoke = true,
	},
} :: { FacilityDefinition }

return HavenFacilityConfig
