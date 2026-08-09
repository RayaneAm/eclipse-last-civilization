--!strict
-- The Daily Quest pool: what a daily objective can BE and what it's worth.
-- The active three are selected once from SharedPoolIds using only the UTC
-- day index, so every server and every player sees the same rotation.
-- same spirit as QuestConfig/DailyRewardConfig — DailyQuestService advances
-- every objective off already-validated server Signals plus this table, and
-- DailyQuestsController only ever RENDERS what's here. Adding an objective is
-- a new entry in `Pool` below plus its Signal wiring in DailyQuestService;
-- nothing in the UI hardcodes a quest.
--
-- AVAILABILITY ("never hand out a quest the player can't finish today") is
-- declared per entry in `requires` and checked against an AvailabilityContext
-- the SERVER builds from live state — unlocked tier, whether a personal base
-- exists, which resource nodes actually exist in the running world, and so on.
-- This module stays safely requirable from the client, so it never reaches for
-- a service itself; the context is passed in. Biome-gated entries name a
-- BiomeConfig id and are resolved to that biome's own unlockTier here, so a
-- locked biome can never be rolled — there is no second copy of the unlock
-- rule to drift from BiomeConfig.
--
-- REWARDS are Scrap only, deliberately. Progression.Tier is the biome unlock
-- ladder (BiomeConfig.unlockTier) and the Tier 2-4 biomes are still COMING
-- SOON, so a repeatable daily loop must not quietly push players through gates
-- with nothing behind them — that is a progression-system change, not a daily-
-- quest one. Every entry keeps a rewardXP field for the day those biomes ship;
-- they are all 0 until then, and DailyQuestService already grants it.
--
-- AMOUNTS are tuned against the real yields the game actually has today
-- (ResourceConfig.baseYield = 1 per harvest, 25-30s respawn, 3 Wood + 3 Stone
-- nodes authored by BuildTutorialZone, ToolConfig.Hatchet doubling Wood), so
-- each entry lands in a handful of minutes rather than a grind. Retune them
-- here — they are read nowhere else.

local BiomeConfig = require(script.Parent.BiomeConfig)

export type DailyObjectiveType =
	"GatherItem" -- InventoryService.ItemAdded for `targetId`
	| "HarvestNode" -- ResourceService.NodeHarvested, any node
	| "CraftAny" -- CraftingService.ItemCrafted, any recipe
	| "CraftTool" -- CraftingService.ItemCrafted where the output is a ToolConfig id
	| "DepositStorage" -- StorageService.ItemsDeposited into the player's OWN base
	| "BuildStructure" -- BuildingService.StructureBuilt
	| "UpgradeStructure" -- BuildingService.StructureUpgraded
	| "EnterBiome" -- PortalService.DestinationEntered for `targetId`
	| "CompleteExpedition" -- a full PortalService round trip: biome entered, then returned
	| "EarnScrap" -- net CurrencyService increases, excluding this system's own payouts
	| "UseFacility" -- a server-validated Haven facility use (crafting, daily rewards, supply shop)

-- Every field is optional and ANDed together — an entry with an empty
-- `requires` is always offerable to a post-tutorial player.
export type DailyQuestRequirements = {
	BiomeId: string?, -- resolved to that biome's own BiomeConfig.unlockTier
	AnyUnlockedBiome: boolean?, -- at least one biome is passable at the player's tier
	PersonalBase: boolean?,
	UpgradableStructure: boolean?, -- the base owns something with a NextTierBuildingId
	BuildablePad: boolean?, -- the base still has an unbuilt blueprint pad
	AccessibleResourceId: string?, -- that resource is farmable in an area this player can reach
	AnyAccessibleResource: boolean?,
	CraftableRecipe: boolean?,
	CraftableTool: boolean?,
}

export type DailyQuestDefinition = {
	id: string,
	name: string,
	icon: string,
	objectiveType: DailyObjectiveType,
	targetId: string?, -- itemId for GatherItem, biomeId for EnterBiome, nil otherwise
	amount: number,
	description: string, -- the "what to do" line; DescribeProgress appends the counter
	hint: string, -- short "where/how" line, same role as QuestConfig's locationHint
	rewardScrap: number,
	rewardXP: number,
	requires: DailyQuestRequirements,
}

-- Built by the server from live state and handed to SelectDailySet. Kept as a
-- plain data snapshot (not a bag of callbacks) so the validation tool can
-- exercise selection against any hypothetical player without a running game.
export type AvailabilityContext = {
	TutorialCompleted: boolean,
	Tier: number,
	HasPersonalBase: boolean,
	HasUpgradableStructure: boolean,
	HasBuildablePad: boolean,
	-- Resources the player can farm in a NORMALLY ACCESSIBLE gameplay area —
	-- not merely "a node of this type exists somewhere on the server". The
	-- Tutorial Zone is excluded from this set by DailyQuestService: it is
	-- one-time onboarding, and a daily that can only be finished by walking a
	-- graduated player back through the Tutorial portal is a worse quest than
	-- no quest. Empty until an accessible biome actually provides nodes.
	AccessibleResourceIds: { [string]: boolean },
	HasCraftableRecipe: boolean,
	HasCraftableTool: boolean,
}

local DailyQuestConfig = {}

DailyQuestConfig.QUESTS_PER_DAY = 3
-- Paid once, on the day's third completion. A daily SET should feel like a
-- set — without this the third quest is worth no more than the first.
DailyQuestConfig.ALL_COMPLETE_BONUS_SCRAP = 100
DailyQuestConfig.SECONDS_PER_DAY = 86400

-- Matches DailyRewardsService's own day bucketing exactly (floor of UTC epoch
-- days) so the Daily Rewards claim and the Daily Quest reset always roll over
-- in the same instant — two different "daily" clocks in one game would be a
-- support nightmare.
function DailyQuestConfig.CurrentDayIndex(): number
	return math.floor(os.time() / DailyQuestConfig.SECONDS_PER_DAY)
end

function DailyQuestConfig.SecondsUntilReset(): number
	return DailyQuestConfig.SECONDS_PER_DAY - (os.time() % DailyQuestConfig.SECONDS_PER_DAY)
end

-- "15 hours 33 minutes" / "42 minutes" / "Less than a minute" — the countdown
-- line the panel header shows. Derived here so the client never reimplements
-- the reset clock it must agree with the server on.
function DailyQuestConfig.DescribeTimeUntilReset(): string
	local remaining = DailyQuestConfig.SecondsUntilReset()
	local hours = math.floor(remaining / 3600)
	local minutes = math.floor((remaining % 3600) / 60)
	if hours > 0 then
		return `{hours} hour{if hours == 1 then "" else "s"} {minutes} minute{if minutes == 1 then "" else "s"}`
	end
	if minutes > 0 then
		return `{minutes} minute{if minutes == 1 then "" else "s"}`
	end
	return "Less than a minute"
end

-- ---------------------------------------------------------------------
-- The pool
-- ---------------------------------------------------------------------

DailyQuestConfig.Pool = {
	{
		id = "GatherWood",
		name = "Timber Run",
		icon = "🪵",
		objectiveType = "GatherItem",
		targetId = "Wood",
		amount = 40,
		description = "Gather 40 Wood",
		hint = "Chop wood out on expedition. A Field Hatchet doubles every swing.",
		rewardScrap = 80,
		rewardXP = 0,
		requires = { AccessibleResourceId = "Wood" },
	},
	{
		id = "MineStone",
		name = "Quarry Shift",
		icon = "🪨",
		objectiveType = "GatherItem",
		targetId = "Stone",
		amount = 30,
		description = "Mine 30 Stone",
		hint = "Break stone deposits out on expedition.",
		rewardScrap = 70,
		rewardXP = 0,
		requires = { AccessibleResourceId = "Stone" },
	},
	{
		id = "HarvestNodes",
		name = "Scavenger",
		icon = "⛏",
		objectiveType = "HarvestNode",
		amount = 20,
		description = "Harvest 20 resource nodes",
		hint = "Any node out in the field counts — wood, stone, whatever you find.",
		rewardScrap = 60,
		rewardXP = 0,
		requires = { AnyAccessibleResource = true },
	},
	{
		id = "CraftItems",
		name = "Workbench Duty",
		icon = "🔨",
		objectiveType = "CraftAny",
		amount = 2,
		description = "Craft 2 items",
		hint = "Use the Upgrade Station workbench in Haven.",
		rewardScrap = 50,
		rewardXP = 0,
		requires = { CraftableRecipe = true },
	},
	{
		id = "CraftTool",
		name = "Tool Up",
		icon = "🪓",
		objectiveType = "CraftTool",
		amount = 1,
		description = "Craft 1 tool",
		hint = "The Field Hatchet counts — 2 Wood and 1 Stone at the workbench.",
		rewardScrap = 40,
		rewardXP = 0,
		requires = { CraftableTool = true },
	},
	{
		id = "DepositStorage",
		name = "Stock the Shelves",
		icon = "📦",
		objectiveType = "DepositStorage",
		amount = 50,
		description = "Deposit 50 resources into base storage",
		hint = "Travel to your Personal Base and deposit from your backpack.",
		rewardScrap = 70,
		rewardXP = 0,
		requires = { PersonalBase = true },
	},
	{
		id = "BuildStructure",
		name = "Break Ground",
		icon = "🏗",
		objectiveType = "BuildStructure",
		amount = 1,
		description = "Build 1 base structure",
		hint = "Any blueprint pad at your Personal Base counts.",
		rewardScrap = 90,
		rewardXP = 0,
		requires = { PersonalBase = true, BuildablePad = true },
	},
	{
		id = "UpgradeStructure",
		name = "Reinforce",
		icon = "⚒",
		objectiveType = "UpgradeStructure",
		amount = 1,
		description = "Upgrade 1 base structure",
		hint = "Walls and Doors can be reinforced from the base build menu.",
		rewardScrap = 120,
		rewardXP = 0,
		requires = { PersonalBase = true, UpgradableStructure = true },
	},
	{
		id = "EnterForestWildlands",
		name = "Into the Green",
		icon = "🌲",
		objectiveType = "EnterBiome",
		targetId = "ForestWildlands",
		amount = 1,
		description = "Enter the Forest Wildlands once",
		hint = "Take the Forest gate in the Expedition District, north of the plaza.",
		rewardScrap = 40,
		rewardXP = 0,
		requires = { BiomeId = "ForestWildlands" },
	},
	{
		id = "CompleteExpedition",
		name = "Round Trip",
		icon = "🧭",
		objectiveType = "CompleteExpedition",
		amount = 1,
		description = "Complete 1 expedition",
		hint = "Go through any unlocked biome gate and make it back to Haven.",
		rewardScrap = 100,
		rewardXP = 0,
		requires = { AnyUnlockedBiome = true },
	},
	{
		id = "EarnScrap",
		name = "Payday",
		icon = "◆",
		objectiveType = "EarnScrap",
		amount = 100,
		description = "Earn 100 Scrap",
		hint = "Sell what you don't need to the trader. Daily Quest payouts don't count.",
		rewardScrap = 60,
		rewardXP = 0,
		requires = {},
	},
	{
		id = "UseFacilities",
		name = "Make the Rounds",
		icon = "🏛",
		objectiveType = "UseFacility",
		amount = 3,
		description = "Use a Haven facility 3 times",
		hint = "Crafting, claiming Daily Rewards, and Supply Shop purchases all count.",
		rewardScrap = 50,
		rewardXP = 0,
		requires = {},
	},
} :: { DailyQuestDefinition }

local byId: { [string]: DailyQuestDefinition } = {}
for _, definition in DailyQuestConfig.Pool do
	assert(byId[definition.id] == nil, `DailyQuestConfig: duplicate pool id "{definition.id}"`)
	byId[definition.id] = definition
end

function DailyQuestConfig.Get(id: string): DailyQuestDefinition?
	return byId[id]
end

-- Only objectives that remain reasonable for every survivor after onboarding
-- participate in the shared rotation. Player-specific base/resource
-- availability must never influence the active IDs.
DailyQuestConfig.SharedPoolIds = {
	"CraftItems",
	"CraftTool",
	"EnterForestWildlands",
	"CompleteExpedition",
	"EarnScrap",
	"UseFacilities",
}

function DailyQuestConfig.SharedDailyIds(dayIndex: number?): { string }
	local day = dayIndex or DailyQuestConfig.CurrentDayIndex()
	local candidates = table.clone(DailyQuestConfig.SharedPoolIds)
	local rng = Random.new(day)
	for index = #candidates, 2, -1 do
		local swapWith = rng:NextInteger(1, index)
		candidates[index], candidates[swapWith] = candidates[swapWith], candidates[index]
	end

	local selected: { string } = {}
	for index = 1, DailyQuestConfig.QUESTS_PER_DAY do
		local id = assert(candidates[index], "DailyQuestConfig.SharedPoolIds must contain at least QUESTS_PER_DAY ids")
		assert(byId[id], `DailyQuestConfig.SharedPoolIds contains unknown id "{id}"`)
		table.insert(selected, id)
	end
	return selected
end

-- ---------------------------------------------------------------------
-- Availability + selection
-- ---------------------------------------------------------------------

local unlockTierByBiomeId: { [string]: number } = {}
local lowestBiomeUnlockTier = math.huge
for _, biome in BiomeConfig do
	unlockTierByBiomeId[biome.id] = biome.unlockTier
	lowestBiomeUnlockTier = math.min(lowestBiomeUnlockTier, biome.unlockTier)
end

-- Note what this deliberately does NOT check: whether the player is holding
-- the ingredients right now. "Can complete today" means the objective isn't
-- structurally impossible or behind a locked gate — not that it's already
-- half-done. A gather quest for a resource with no nodes in the world, or a
-- biome quest for a gate the player can't pass, is the real failure mode.
function DailyQuestConfig.IsAvailable(definition: DailyQuestDefinition, context: AvailabilityContext): boolean
	if not context.TutorialCompleted then
		return false
	end

	local requires = definition.requires

	if requires.BiomeId then
		local unlockTier = unlockTierByBiomeId[requires.BiomeId]
		if not unlockTier or context.Tier < unlockTier then
			return false
		end
	end
	if requires.AnyUnlockedBiome and context.Tier < lowestBiomeUnlockTier then
		return false
	end
	if requires.PersonalBase and not context.HasPersonalBase then
		return false
	end
	if requires.UpgradableStructure and not context.HasUpgradableStructure then
		return false
	end
	if requires.BuildablePad and not context.HasBuildablePad then
		return false
	end
	if requires.AccessibleResourceId and not context.AccessibleResourceIds[requires.AccessibleResourceId] then
		return false
	end
	if requires.AnyAccessibleResource and next(context.AccessibleResourceIds) == nil then
		return false
	end
	if requires.CraftableRecipe and not context.HasCraftableRecipe then
		return false
	end
	if requires.CraftableTool and not context.HasCraftableTool then
		return false
	end

	return true
end

function DailyQuestConfig.AvailableIds(context: AvailabilityContext): { string }
	local ids: { string } = {}
	for _, definition in DailyQuestConfig.Pool do
		if DailyQuestConfig.IsAvailable(definition, context) then
			table.insert(ids, definition.id)
		end
	end
	return ids
end

-- Picks up to `count` (default QUESTS_PER_DAY) DISTINCT ids from the
-- currently-available subset. Duplicate-free by construction: it shuffles the
-- candidate list and takes a prefix, so the same id can never be drawn twice,
-- and `excludeIds` keeps a top-up from re-drawing something already in the
-- player's set. Returns fewer than `count` only if the player genuinely has
-- fewer available objectives than that, which is the correct outcome — padding
-- it out would mean handing someone a quest they can't complete.
function DailyQuestConfig.SelectDailySet(
	context: AvailabilityContext,
	rng: Random,
	count: number?,
	excludeIds: { [string]: boolean }?
): { string }
	local candidates: { string } = {}
	for _, id in DailyQuestConfig.AvailableIds(context) do
		if not (excludeIds and excludeIds[id]) then
			table.insert(candidates, id)
		end
	end

	for index = #candidates, 2, -1 do
		local swapWith = rng:NextInteger(1, index)
		candidates[index], candidates[swapWith] = candidates[swapWith], candidates[index]
	end

	local wanted = count or DailyQuestConfig.QUESTS_PER_DAY
	local selected: { string } = {}
	for index = 1, math.min(wanted, #candidates) do
		table.insert(selected, candidates[index])
	end
	return selected
end

-- Single source of truth for a daily objective's display text, so the panel
-- row and any future tracker/notification can't drift apart — the same split
-- QuestConfig.DescribeCurrentObjective already established for the tutorial.
function DailyQuestConfig.DescribeProgress(definition: DailyQuestDefinition, progress: number): string
	if definition.amount <= 1 then
		return definition.description
	end
	return `{definition.description} ({math.min(progress, definition.amount)}/{definition.amount})`
end

return DailyQuestConfig
