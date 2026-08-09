--!strict
-- Pure config/selection checks for the Daily Quest pool, safe to run from the
-- canonical world build (no DataStore, no Workspace, no player). Mirrors
-- ValidatePlayerSessionProfile's shape: every check asserts and is also
-- returned as a line so the build log shows what was actually verified.
--
-- The rules worth guarding here are the ones a future pool edit could quietly
-- break: unique ids, sane amounts/rewards, biome-gated entries pointing at
-- real biomes, and — the important one — that selection never hands a player
-- a duplicate or an objective their own context says they can't finish.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DailyQuestConfig = require(ReplicatedStorage.Shared.Config.DailyQuestConfig)
local PlayerSessionTypes = require(ReplicatedStorage.Shared.Config.PlayerSessionTypes)
local BiomeConfig = require(ReplicatedStorage.Shared.Config.BiomeConfig)
local ResourceConfig = require(ReplicatedStorage.Shared.Config.ResourceConfig)

local ValidateDailyQuests = {}

-- A player with everything unlocked, in a world where an accessible biome
-- really does provide every resource: used to prove selection is duplicate-free
-- and fills a full set when it can.
local function fullyUnlockedContext(): DailyQuestConfig.AvailabilityContext
	local accessible: { [string]: boolean } = {}
	for _, resource in ResourceConfig.All do
		accessible[resource.id] = true
	end
	local maxTier = 0
	for _, biome in BiomeConfig do
		maxTier = math.max(maxTier, biome.unlockTier)
	end
	return {
		TutorialCompleted = true,
		Tier = maxTier,
		HasPersonalBase = true,
		HasUpgradableStructure = true,
		HasBuildablePad = true,
		AccessibleResourceIds = accessible,
		HasCraftableRecipe = true,
		HasCraftableTool = true,
	}
end

-- TODAY'S world: a fully-progressed player with a developed base, but every
-- resource node still living in the Tutorial Zone, so nothing is reachable
-- through normal gameplay. DailyQuestService resolves this to an empty
-- AccessibleResourceIds set — see isAccessibleArea.
local function tutorialOnlyResourcesContext(): DailyQuestConfig.AvailabilityContext
	local context = fullyUnlockedContext()
	context.AccessibleResourceIds = {}
	return context
end

-- A brand new post-tutorial player: no base prepared yet, nothing built, no
-- biome passable, and nothing farmable.
local function barePostTutorialContext(): DailyQuestConfig.AvailabilityContext
	return {
		TutorialCompleted = true,
		Tier = 0,
		HasPersonalBase = false,
		HasUpgradableStructure = false,
		HasBuildablePad = false,
		AccessibleResourceIds = {},
		HasCraftableRecipe = false,
		HasCraftableTool = false,
	}
end

function ValidateDailyQuests.Run(): { string }
	local checks = {}
	local function check(condition: boolean, message: string)
		assert(condition, `[DailyQuestValidation] {message}`)
		table.insert(checks, message)
	end

	local biomeIds: { [string]: boolean } = {}
	for _, biome in BiomeConfig do
		biomeIds[biome.id] = true
	end

	-- ------------------------------------------------------------------
	-- Pool shape
	-- ------------------------------------------------------------------
	check(#DailyQuestConfig.Pool >= DailyQuestConfig.QUESTS_PER_DAY, "pool holds at least a full day's worth of quests")
	check(#DailyQuestConfig.SharedPoolIds >= DailyQuestConfig.QUESTS_PER_DAY, "shared pool holds at least three quests")

	local seenIds: { [string]: boolean } = {}
	for _, definition in DailyQuestConfig.Pool do
		check(not seenIds[definition.id], `pool id "{definition.id}" is unique`)
		seenIds[definition.id] = true
		check(definition.amount > 0, `"{definition.id}" has a positive target amount`)
		check(definition.rewardScrap >= 0 and definition.rewardXP >= 0, `"{definition.id}" has non-negative rewards`)
		check(definition.description ~= "" and definition.hint ~= "", `"{definition.id}" has player-facing text`)
		check(DailyQuestConfig.Get(definition.id) == definition, `"{definition.id}" is retrievable by id`)
		if definition.requires.BiomeId then
			check(biomeIds[definition.requires.BiomeId] == true, `"{definition.id}" gates on a real biome`)
		end
		if definition.objectiveType == "EnterBiome" then
			check(
				definition.targetId ~= nil and biomeIds[definition.targetId :: string] == true,
				`"{definition.id}" targets a real biome`
			)
			-- Otherwise a player could be handed "enter X" for a gate they
			-- cannot pass — the exact failure the requires block exists for.
			check(definition.requires.BiomeId == definition.targetId, `"{definition.id}" gates on the biome it targets`)
		end
		if definition.objectiveType == "GatherItem" then
			check(definition.targetId ~= nil, `"{definition.id}" names the item to gather`)
			check(
				definition.requires.AccessibleResourceId == definition.targetId
					or ResourceConfig.Get(definition.targetId :: string) == nil,
				`"{definition.id}" gates on the resource it asks for`
			)
		end
		if definition.objectiveType == "HarvestNode" then
			check(definition.requires.AnyAccessibleResource == true, `"{definition.id}" gates on reachable nodes existing`)
		end
	end

	local sharedA = DailyQuestConfig.SharedDailyIds(20500)
	local sharedB = DailyQuestConfig.SharedDailyIds(20500)
	check(#sharedA == 3 and #sharedB == 3, "every UTC day resolves to exactly three shared quests")
	local sharedSeen: { [string]: boolean } = {}
	for index, id in sharedA do
		check(id == sharedB[index], "same UTC day resolves identically for every caller/server")
		check(not sharedSeen[id], `shared daily id "{id}" is unique`)
		check(DailyQuestConfig.Get(id) ~= nil, `shared daily id "{id}" exists in the pool`)
		sharedSeen[id] = true
	end
	for day = 20500, 20530 do
		check(
			#DailyQuestConfig.SharedDailyIds(day) == DailyQuestConfig.QUESTS_PER_DAY,
			`UTC day {day} has exactly three quests`
		)
	end

	-- ------------------------------------------------------------------
	-- Selection
	-- ------------------------------------------------------------------
	local rng = Random.new(1234) -- fixed seed: this is a determinism check, not a dice roll
	local unlocked = fullyUnlockedContext()

	local fullSet = DailyQuestConfig.SelectDailySet(unlocked, rng)
	check(#fullSet == DailyQuestConfig.QUESTS_PER_DAY, "an unlocked player is offered a full daily set")

	-- 200 rolls is cheap and covers every shuffle path this pool can produce.
	local duplicateFree = true
	local allAvailable = true
	for _ = 1, 200 do
		local set = DailyQuestConfig.SelectDailySet(unlocked, rng)
		local seen: { [string]: boolean } = {}
		for _, id in set do
			if seen[id] then
				duplicateFree = false
			end
			seen[id] = true
			local definition = DailyQuestConfig.Get(id)
			if not definition or not DailyQuestConfig.IsAvailable(definition, unlocked) then
				allAvailable = false
			end
		end
	end
	check(duplicateFree, "repeated rolls never contain a duplicate quest")
	check(allAvailable, "repeated rolls only ever contain available quests")

	-- The accessibility rule, in both directions. First: today's world, where
	-- the only nodes sit in the Tutorial Zone. No amount of progression should
	-- make a gather daily eligible, because there is nowhere legitimate to farm.
	local tutorialOnly = tutorialOnlyResourcesContext()
	local resourceQuestIds = { "GatherWood", "MineStone", "HarvestNodes" }
	for _, id in resourceQuestIds do
		local definition = assert(DailyQuestConfig.Get(id))
		check(
			not DailyQuestConfig.IsAvailable(definition, tutorialOnly),
			`"{id}" is withheld while its resource only exists in the Tutorial Zone`
		)
	end
	check(
		#DailyQuestConfig.AvailableIds(tutorialOnly) >= DailyQuestConfig.QUESTS_PER_DAY,
		"a full daily set is still offerable with every gather quest withheld"
	)

	-- Second: the definitions must switch back on by themselves the moment an
	-- accessible biome provides the resource — no config edit required.
	local forestProvidesWood = tutorialOnlyResourcesContext()
	forestProvidesWood.AccessibleResourceIds = { Wood = true }
	check(
		DailyQuestConfig.IsAvailable(assert(DailyQuestConfig.Get("GatherWood")), forestProvidesWood),
		"the Wood quest becomes eligible again once Wood is reachable in normal gameplay"
	)
	check(
		DailyQuestConfig.IsAvailable(assert(DailyQuestConfig.Get("HarvestNodes")), forestProvidesWood),
		"the node quest becomes eligible again once any node is reachable"
	)
	check(
		not DailyQuestConfig.IsAvailable(assert(DailyQuestConfig.Get("MineStone")), forestProvidesWood),
		"a resource that is still unreachable stays withheld even when others are not"
	)

	local bare = barePostTutorialContext()
	local bareSet = DailyQuestConfig.SelectDailySet(bare, rng)
	local bareOnlyAvailable = true
	for _, id in bareSet do
		local definition = DailyQuestConfig.Get(id) :: DailyQuestConfig.DailyQuestDefinition
		if definition.requires.BiomeId or definition.requires.PersonalBase or definition.requires.AccessibleResourceId then
			bareOnlyAvailable = false
		end
	end
	check(bareOnlyAvailable, "a player with no base, no nodes and no unlocked biome is never given one of those quests")
	check(#bareSet <= DailyQuestConfig.QUESTS_PER_DAY, "a thin candidate list is never padded past a full set")

	local duringTutorial = fullyUnlockedContext()
	duringTutorial.TutorialCompleted = false
	check(#DailyQuestConfig.SelectDailySet(duringTutorial, rng) == 0, "no daily quests are offered before the tutorial is done")

	local excluded = { [fullSet[1]] = true }
	local topUp = DailyQuestConfig.SelectDailySet(unlocked, rng, 2, excluded)
	local respectsExclusion = true
	for _, id in topUp do
		if excluded[id] then
			respectsExclusion = false
		end
	end
	check(#topUp == 2 and respectsExclusion, "a top-up honours its exclusion list and requested count")

	-- ------------------------------------------------------------------
	-- Display + persistence round trip
	-- ------------------------------------------------------------------
	local counted = assert(DailyQuestConfig.Get("GatherWood"))
	check(
		DailyQuestConfig.DescribeProgress(counted, 12) == `{counted.description} (12/{counted.amount})`,
		"a counted objective renders its progress"
	)
	check(
		DailyQuestConfig.DescribeProgress(counted, counted.amount + 99) == `{counted.description} ({counted.amount}/{counted.amount})`,
		"displayed progress never exceeds the target"
	)
	local single = assert(DailyQuestConfig.Get("CompleteExpedition"))
	check(DailyQuestConfig.DescribeProgress(single, 0) == single.description, "a one-shot objective renders without a counter")

	local session = PlayerSessionTypes.NewDefault()
	check(session.DailyQuests.DayIndex == -1 and #session.DailyQuests.Quests == 0, "a new profile starts with no rolled set")

	session.DailyQuests.DayIndex = DailyQuestConfig.CurrentDayIndex()
	session.DailyQuests.BonusGranted = true
	session.DailyQuests.Quests = {
		{ Id = "GatherWood", Progress = 12, Completed = false },
		{ Id = "CraftItems", Progress = 2, Completed = true },
	}
	local reloaded = PlayerSessionTypes.Reconcile(PlayerSessionTypes.SerializePersistent(session))
	check(reloaded.DailyQuests.DayIndex == session.DailyQuests.DayIndex, "the rolled day survives a profile round-trip")
	check(#reloaded.DailyQuests.Quests == 2, "in-flight daily progress survives a profile round-trip")
	check(reloaded.DailyQuests.Quests[1].Progress == 12, "partial progress survives a profile round-trip")
	check(reloaded.DailyQuests.Quests[2].Completed, "a finished daily stays finished across a rejoin")
	check(reloaded.DailyQuests.BonusGranted, "the all-clear bonus is never paid twice in one day")

	local malformed = PlayerSessionTypes.Reconcile({
		DailyQuests = {
			DayIndex = DailyQuestConfig.CurrentDayIndex(),
			Quests = {
				{ Id = "RetiredQuestThatNoLongerExists", Progress = 3, Completed = false },
				{ Id = "GatherWood", Progress = -5, Completed = false },
				{ Id = "MineStone", Progress = 999999, Completed = false },
				{ Id = "MineStone", Progress = 1, Completed = false },
			},
		},
	})
	local ids: { string } = {}
	for _, entry in malformed.DailyQuests.Quests do
		table.insert(ids, entry.Id)
	end
	check(table.find(ids, "RetiredQuestThatNoLongerExists") == nil, "a retired pool id is dropped on load")
	check(table.find(ids, "GatherWood") == nil, "a malformed progress value is dropped on load")
	check(#ids == 1 and ids[1] == "MineStone", "a duplicated saved entry is deduplicated on load")
	check(
		malformed.DailyQuests.Quests[1].Progress == assert(DailyQuestConfig.Get("MineStone")).amount,
		"saved progress is clamped to the current target amount"
	)

	local noDayStamp = PlayerSessionTypes.Reconcile({
		DailyQuests = { Quests = { { Id = "GatherWood", Progress = 1, Completed = false } } },
	})
	check(noDayStamp.DailyQuests.DayIndex == -1, "a set with no usable day stamp is re-rolled rather than trusted")

	return checks
end

return ValidateDailyQuests
