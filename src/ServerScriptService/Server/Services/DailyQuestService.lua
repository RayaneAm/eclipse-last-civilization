--!strict
-- Server-authoritative Daily Quests: rolls each player DailyQuestConfig
-- .QUESTS_PER_DAY unique, currently-completable objectives per UTC day and
-- advances them ONLY from already-validated server Signals — the same rule
-- QuestService's header states for the tutorial chain. There is deliberately
-- no "I finished a daily objective" remote; the single remote here
-- (RequestDailyQuests) is a READ that also makes sure today's set exists, so a
-- client can't invent progress by calling it.
--
-- This service owns no player table of its own: the day's set lives in
-- PlayerSessionData.DailyQuests via PlayerSessionService, so it autosaves,
-- survives a rejoin mid-day, and is subject to the same persistence rules as
-- every other durable field. The only per-player state kept here is genuinely
-- runtime-only bookkeeping that must NOT survive a rejoin (see below).
--
-- Which Signal feeds which objective type is the whole wiring surface, and it
-- lives in one place — connectSignals at the bottom.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local DailyQuestConfig = require(ReplicatedStorage.Shared.Config.DailyQuestConfig)
local PlayerSessionTypes = require(ReplicatedStorage.Shared.Config.PlayerSessionTypes)
local BiomeConfig = require(ReplicatedStorage.Shared.Config.BiomeConfig)
local BuildingConfig = require(ReplicatedStorage.Shared.Config.BuildingConfig)
local BlueprintLayoutConfig = require(ReplicatedStorage.Shared.Config.BlueprintLayoutConfig)
local CraftingConfig = require(ReplicatedStorage.Shared.Config.CraftingConfig)
local ToolConfig = require(ReplicatedStorage.Shared.Config.ToolConfig)

local PlayerSessionService = require(script.Parent.PlayerSessionService)
local ProgressionService = require(script.Parent.ProgressionService)
local CurrencyService = require(script.Parent.CurrencyService)
local InventoryService = require(script.Parent.InventoryService)
local CraftingService = require(script.Parent.CraftingService)
local ResourceService = require(script.Parent.ResourceService)
local StorageService = require(script.Parent.StorageService)
local BuildingService = require(script.Parent.BuildingService)
local PortalService = require(script.Parent.PortalService)
local BaseService = require(script.Parent.BaseService)
local DailyRewardsService = require(script.Parent.DailyRewardsService)
local SupplyShopService = require(script.Parent.SupplyShopService)

local DailyQuestService = {}

-- How often an already-online player's set is checked for the midnight
-- rollover. A minute of lag on a once-a-day event is invisible, and this only
-- reads two integers per player.
local RESET_POLL_SECONDS = 60

-- Upper bound on how long the FIRST roll of a session waits for the player's
-- personal base to finish loading. See awaitBaseReady.
local BASE_READY_WAIT_SECONDS = 10

-- Runtime-only, deliberately not persisted:
--   * lastKnownBalance — the baseline the EarnScrap objective diffs against.
--     A rejoin re-seeds it, which is correct: crossing a session boundary
--     shouldn't retroactively credit anything.
--   * grantingReward — set while THIS service pays a player out, so a daily's
--     own Scrap reward can't complete the "Earn Scrap" daily.
--   * onExpeditionAt — which biome the player is currently out in, so
--     CompleteExpedition needs a real round trip. Without this pairing a
--     client could farm it by calling RequestPortalReturn alone.
local lastKnownBalance: { [Player]: number } = {}
local grantingReward: { [Player]: boolean } = {}
local onExpeditionAt: { [Player]: string } = {}

local function pushUpdate(player: Player, state: PlayerSessionTypes.DailyQuestState)
	Net.GetEvent("DailyQuestsUpdated"):FireClient(player, state)
end

-- ---------------------------------------------------------------------
-- Availability context
-- ---------------------------------------------------------------------

local craftableRecipeCount = #CraftingConfig.All
local craftableToolCount = 0
for _, recipe in CraftingConfig.All do
	if ToolConfig.Get(recipe.output.itemId) then
		craftableToolCount += 1
	end
end

local unlockTierByBiomeId: { [string]: number } = {}
for _, biome in BiomeConfig do
	unlockTierByBiomeId[biome.id] = biome.unlockTier
end

-- Is this resource AREA somewhere the player can go as part of normal,
-- repeatable gameplay right now?
--
-- Two things are deliberately NOT accessible:
--   * The Tutorial Zone. It is one-time onboarding. The portal back into it
--     technically still works, but a daily that can only be finished by
--     walking a graduated survivor back through it is a worse quest than no
--     quest at all — so a Tutorial-only resource never makes its gather daily
--     eligible.
--   * Any area this module doesn't recognise. Unknown ids fail closed rather
--     than being optimistically assumed reachable.
--
-- Everything else resolves through the one existing authority for "can this
-- player be here": the biome's own BiomeConfig.unlockTier versus their
-- Progression.Tier — the same comparison PortalService and BiomeGateService
-- already gate travel on, not a second copy of the rule.
--
-- Today no biome spawns nodes, so this returns false for everything and the
-- three gather/mine/harvest dailies sit out of the pool. The moment a biome
-- node spawner tags its anchors with that biome's AreaId, they light up on
-- their own — the quest definitions never had to change.
local function isAccessibleArea(player: Player, areaId: string): boolean
	if areaId == ResourceService.TUTORIAL_AREA_ID then
		return false
	end
	local unlockTier = unlockTierByBiomeId[areaId]
	if not unlockTier then
		return false
	end
	return ProgressionService.GetTier(player) >= unlockTier
end

local function accessibleResourceIds(player: Player): { [string]: boolean }
	local accessible: { [string]: boolean } = {}
	for areaId, resources in ResourceService.GetHarvestableResourceIdsByArea() do
		if isAccessibleArea(player, areaId) then
			for resourceId in resources do
				accessible[resourceId] = true
			end
		end
	end
	return accessible
end

local function hasUpgradableStructure(hostUserId: number): boolean
	local base = BaseService.Get(hostUserId)
	if not base then
		return false
	end
	for _, structure in base.Structures do
		local definition = BuildingConfig.Get(structure.BuildingId)
		if definition and definition.NextTierBuildingId then
			return true
		end
	end
	return false
end

local function hasBuildablePad(hostUserId: number): boolean
	local base = BaseService.Get(hostUserId)
	if not base then
		return false
	end
	local claimed: { [string]: boolean } = {}
	for _, structure in base.Structures do
		if structure.PadId then
			claimed[structure.PadId] = true
		end
	end
	for _, pad in BlueprintLayoutConfig.All do
		if not claimed[pad.PadId] then
			return true
		end
	end
	return false
end

-- Snapshots everything DailyQuestConfig needs to decide what this player can
-- actually finish today. Only ever called at roll time, never per progress
-- event — walking the base's structures and pads on every harvest would be
-- pointless work.
local function buildContext(player: Player): DailyQuestConfig.AvailabilityContext
	local session = PlayerSessionService.Get(player)
	return {
		TutorialCompleted = session.TutorialCompleted,
		Tier = ProgressionService.GetTier(player),
		HasPersonalBase = BaseService.Get(player.UserId) ~= nil,
		HasUpgradableStructure = hasUpgradableStructure(player.UserId),
		HasBuildablePad = hasBuildablePad(player.UserId),
		AccessibleResourceIds = accessibleResourceIds(player),
		HasCraftableRecipe = craftableRecipeCount > 0,
		HasCraftableTool = craftableToolCount > 0,
	}
end

-- ---------------------------------------------------------------------
-- Rolling today's set
-- ---------------------------------------------------------------------

-- Yields, briefly and boundedly. BaseService prepares a player's base
-- asynchronously (DataStore slot + physical build) right after they join, and
-- a set rolled inside that window silently drops every base objective for the
-- whole day — the top-up in ensureTodaysSet only fires when a set came out
-- SHORT, and a set of three non-base quests isn't short. Called from the two
-- "first look of the session" entry points only, never from a Signal handler.
local function awaitBaseReady(player: Player)
	local deadline = os.clock() + BASE_READY_WAIT_SECONDS
	while player.Parent and BaseService.Get(player.UserId) == nil and os.clock() < deadline do
		task.wait(0.5)
	end
end

local function describeSet(state: PlayerSessionTypes.DailyQuestState): string
	local names: { string } = {}
	for _, entry in state.Quests do
		table.insert(names, entry.Id)
	end
	return table.concat(names, ", ")
end

-- Returns nil while the player has no daily set and shouldn't get one yet.
-- Daily Quests deliberately don't exist until the tutorial is done: a brand
-- new player already has one guided objective on screen, and a second list of
-- three more is exactly the "too much at once" this game is trying to avoid.
local function ensureTodaysSet(player: Player): PlayerSessionTypes.DailyQuestState?
	local session = PlayerSessionService.Get(player)
	local state = session.DailyQuests
	if not session.TutorialCompleted then
		return nil
	end

	local today = DailyQuestConfig.CurrentDayIndex()
	local rng = Random.new()

	if state.DayIndex ~= today then
		local selected = DailyQuestConfig.SelectDailySet(buildContext(player), rng)
		state.DayIndex = today
		state.BonusGranted = false
		state.Quests = {}
		for _, id in selected do
			table.insert(state.Quests, { Id = id, Progress = 0, Completed = false })
		end
		PlayerSessionService.MarkDirty(player)
		print(`[DailyQuestService] {player.Name} rolled day {today}: {describeSet(state)}`)
		pushUpdate(player, state)
		return state
	end

	-- Top-up, not a re-roll. A set can legitimately come out short — rolled
	-- during the seconds before BaseService finished preparing the player's
	-- base, or before they unlocked their first biome — and leaving them on
	-- one or two quests for the rest of the day would be a worse bug than the
	-- race itself. Existing entries (and their progress) are never touched.
	if #state.Quests < DailyQuestConfig.QUESTS_PER_DAY then
		local existing: { [string]: boolean } = {}
		for _, entry in state.Quests do
			existing[entry.Id] = true
		end
		local wanted = DailyQuestConfig.QUESTS_PER_DAY - #state.Quests
		local topUp = DailyQuestConfig.SelectDailySet(buildContext(player), rng, wanted, existing)
		if #topUp > 0 then
			for _, id in topUp do
				table.insert(state.Quests, { Id = id, Progress = 0, Completed = false })
			end
			PlayerSessionService.MarkDirty(player)
			print(`[DailyQuestService] {player.Name} topped up day {today}: {describeSet(state)}`)
			pushUpdate(player, state)
		end
	end

	return state
end

-- ---------------------------------------------------------------------
-- Rewards
-- ---------------------------------------------------------------------

-- Wraps every payout this service makes so the EarnScrap objective ignores it
-- — otherwise finishing two dailies would quietly finish a third.
local function payScrap(player: Player, amount: number)
	if amount <= 0 then
		return
	end
	grantingReward[player] = true
	CurrencyService.Add(player, amount)
	grantingReward[player] = nil
end

local function completeEntry(player: Player, entry: PlayerSessionTypes.DailyQuestEntry, definition: DailyQuestConfig.DailyQuestDefinition)
	entry.Completed = true
	print(`[DailyQuestService] {player.Name} completed daily "{definition.name}" — granting {definition.rewardScrap} Scrap`)
	payScrap(player, definition.rewardScrap)
	-- 0 for every pool entry today; see DailyQuestConfig's header for why the
	-- daily loop deliberately doesn't feed the biome unlock ladder yet.
	if definition.rewardXP > 0 then
		ProgressionService.AddXP(player, definition.rewardXP)
	end
end

local function grantBonusIfSetComplete(player: Player, state: PlayerSessionTypes.DailyQuestState)
	if state.BonusGranted or #state.Quests == 0 then
		return
	end
	for _, entry in state.Quests do
		if not entry.Completed then
			return
		end
	end
	state.BonusGranted = true
	print(`[DailyQuestService] {player.Name} cleared every daily — granting {DailyQuestConfig.ALL_COMPLETE_BONUS_SCRAP} bonus Scrap`)
	payScrap(player, DailyQuestConfig.ALL_COMPLETE_BONUS_SCRAP)
end

-- ---------------------------------------------------------------------
-- Progress
-- ---------------------------------------------------------------------

-- The single funnel every Signal handler goes through. `targetId` is matched
-- only when the definition names one, so "any craft" and "craft a Hatchet"
-- share one code path. Advances every matching quest in the set — a day that
-- rolled both "Gather 40 Wood" and "Harvest 20 nodes" should credit one swing
-- to both, not pick a winner.
local function addProgress(player: Player, objectiveType: DailyQuestConfig.DailyObjectiveType, amount: number, targetId: string?)
	if amount <= 0 then
		return
	end
	local state = ensureTodaysSet(player)
	if not state then
		return
	end

	local changed = false
	for _, entry in state.Quests do
		if entry.Completed then
			continue
		end
		local definition = DailyQuestConfig.Get(entry.Id)
		if not definition or definition.objectiveType ~= objectiveType then
			continue
		end
		if definition.targetId and definition.targetId ~= targetId then
			continue
		end

		entry.Progress = math.min(definition.amount, entry.Progress + amount)
		changed = true
		if entry.Progress >= definition.amount then
			completeEntry(player, entry, definition)
		end
	end

	if not changed then
		return
	end

	grantBonusIfSetComplete(player, state)
	PlayerSessionService.MarkDirty(player)
	pushUpdate(player, state)
end

-- ---------------------------------------------------------------------
-- Signal wiring — the complete list of what moves a daily objective
-- ---------------------------------------------------------------------

local function connectSignals()
	-- Gathering. ItemAdded fires for crafting/trade/reward grants too, which is
	-- intentional: "Gather 40 Wood" is satisfied by 40 Wood entering the
	-- backpack, however it got there. The node-count objective below is the one
	-- that specifically means "go swing at things."
	InventoryService.ItemAdded:Connect(function(player: Player, itemId: string, amountAdded: number)
		addProgress(player, "GatherItem", amountAdded, itemId)
	end)

	ResourceService.NodeHarvested:Connect(function(player: Player)
		addProgress(player, "HarvestNode", 1)
	end)

	CraftingService.ItemCrafted:Connect(function(player: Player, recipeId: string)
		addProgress(player, "CraftAny", 1)
		addProgress(player, "UseFacility", 1) -- the workbench IS the Upgrade Station facility
		local recipe = CraftingConfig.Get(recipeId)
		if recipe and ToolConfig.Get(recipe.output.itemId) then
			addProgress(player, "CraftTool", 1)
		end
	end)

	-- Own base only. Helping a friend stock THEIR base is a good thing to do,
	-- but it isn't "deposit into your Personal Base storage."
	StorageService.ItemsDeposited:Connect(function(player: Player, hostUserId: number, _itemId: string, amount: number)
		if hostUserId == player.UserId then
			addProgress(player, "DepositStorage", amount)
		end
	end)

	BuildingService.StructureBuilt:Connect(function(player: Player)
		addProgress(player, "BuildStructure", 1)
	end)

	BuildingService.StructureUpgraded:Connect(function(player: Player)
		addProgress(player, "UpgradeStructure", 1)
	end)

	PortalService.DestinationEntered:Connect(function(player: Player, portalId: string, kind: string)
		if kind ~= "Biome" then
			return
		end
		onExpeditionAt[player] = portalId
		addProgress(player, "EnterBiome", 1, portalId)
	end)

	PortalService.ReturnedToHaven:Connect(function(player: Player, portalId: string, kind: string)
		if kind ~= "Biome" or onExpeditionAt[player] ~= portalId then
			return
		end
		onExpeditionAt[player] = nil
		addProgress(player, "CompleteExpedition", 1)
	end)

	CurrencyService.BalanceChanged:Connect(function(player: Player, newBalance: number)
		local previous = lastKnownBalance[player]
		lastKnownBalance[player] = newBalance
		-- No baseline yet (first change this session) or this service is mid-
		-- payout: record the new balance, credit nothing.
		if previous == nil or grantingReward[player] then
			return
		end
		addProgress(player, "EarnScrap", newBalance - previous)
	end)

	DailyRewardsService.RewardClaimed:Connect(function(player: Player)
		addProgress(player, "UseFacility", 1)
	end)

	SupplyShopService.ItemPurchased:Connect(function(player: Player)
		addProgress(player, "UseFacility", 1)
	end)
end

-- ---------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------

function DailyQuestService:Init()
	connectSignals()

	PlayerSessionService.ProfileLoaded:Connect(function(player: Player)
		lastKnownBalance[player] = CurrencyService.GetBalance(player)
		-- Rolling here rather than waiting for the client's first request means
		-- the set (and its push) is ready before the panel is ever opened.
		task.spawn(function()
			awaitBaseReady(player)
			if player.Parent then
				ensureTodaysSet(player)
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastKnownBalance[player] = nil
		grantingReward[player] = nil
		onExpeditionAt[player] = nil
	end)

	-- The client asks for this the instant it starts, which on a fresh join can
	-- beat BaseService's own base preparation — so the same bounded wait the
	-- ProfileLoaded roll uses applies here, but only when today's set doesn't
	-- exist yet. Every later call (and every reopen of the panel) returns
	-- immediately.
	Net.GetFunction("RequestDailyQuests").OnServerInvoke = function(player: Player)
		local session = PlayerSessionService.Get(player)
		if session.TutorialCompleted and session.DailyQuests.DayIndex ~= DailyQuestConfig.CurrentDayIndex() then
			awaitBaseReady(player)
		end
		return ensureTodaysSet(player)
	end
end

-- Rolls an already-online player over at UTC midnight without needing them to
-- rejoin — the one thing a purely lazy "check on next event" design can't do,
-- since a player standing still generates no events.
function DailyQuestService:Start()
	while true do
		task.wait(RESET_POLL_SECONDS)
		for _, player in Players:GetPlayers() do
			if PlayerSessionService.IsLoaded(player) then
				task.spawn(ensureTodaysSet, player)
			end
		end
	end
end

return DailyQuestService
