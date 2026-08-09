--!strict
-- Server-authoritative Daily Quests. DailyQuestConfig selects one deterministic
-- three-quest set from the UTC day index, so every server and every player has
-- the same active IDs. Only progress, completion and rewards are per-player.
-- Clients can read state but cannot submit progress; every increment below is
-- driven by an already-validated server signal.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local DailyQuestConfig = require(ReplicatedStorage.Shared.Config.DailyQuestConfig)
local PlayerSessionTypes = require(ReplicatedStorage.Shared.Config.PlayerSessionTypes)
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
local DailyRewardsService = require(script.Parent.DailyRewardsService)
local SupplyShopService = require(script.Parent.SupplyShopService)

local DailyQuestService = {}
local RESET_POLL_SECONDS = 60

-- Runtime-only bookkeeping. Daily payouts must not advance EarnScrap, and an
-- expedition completion requires a real outbound/return pair.
local lastKnownBalance: { [Player]: number } = {}
local grantingReward: { [Player]: boolean } = {}
local onExpeditionAt: { [Player]: string } = {}

local function pushUpdate(player: Player, state: PlayerSessionTypes.DailyQuestState)
	Net.GetEvent("DailyQuestsUpdated"):FireClient(player, state)
end

local function describeSet(state: PlayerSessionTypes.DailyQuestState): string
	local ids: { string } = {}
	for _, entry in state.Quests do
		table.insert(ids, entry.Id)
	end
	return table.concat(ids, ", ")
end

local function matchesSharedSet(state: PlayerSessionTypes.DailyQuestState, dayIndex: number, ids: { string }): boolean
	if state.DayIndex ~= dayIndex or #state.Quests ~= DailyQuestConfig.QUESTS_PER_DAY then
		return false
	end
	for index, id in ids do
		if state.Quests[index].Id ~= id then
			return false
		end
	end
	return true
end

local function ensureTodaysSet(player: Player): PlayerSessionTypes.DailyQuestState
	local state = PlayerSessionService.Get(player).DailyQuests
	local today = DailyQuestConfig.CurrentDayIndex()
	local sharedIds = DailyQuestConfig.SharedDailyIds(today)
	if matchesSharedSet(state, today, sharedIds) then
		return state
	end

	-- During rollout, preserve progress for an ID that already belonged to the
	-- same UTC day while replacing the old per-player selection/order.
	-- Preserve the day's all-clear flag as well, otherwise a migrated player
	-- could receive that once-per-day bonus twice.
	local bonusAlreadyGranted = state.DayIndex == today and state.BonusGranted
	local previousById: { [string]: PlayerSessionTypes.DailyQuestEntry } = {}
	if state.DayIndex == today then
		for _, entry in state.Quests do
			previousById[entry.Id] = entry
		end
	end

	state.DayIndex = today
	state.BonusGranted = bonusAlreadyGranted
	state.Quests = {}
	for _, id in sharedIds do
		local previous = previousById[id]
		table.insert(state.Quests, if previous then {
			Id = id,
			Progress = previous.Progress,
			Completed = previous.Completed,
		} else {
			Id = id,
			Progress = 0,
			Completed = false,
		})
	end

	PlayerSessionService.MarkDirty(player)
	print(`[DailyQuestService] {player.Name} assigned shared day {today}: {describeSet(state)}`)
	pushUpdate(player, state)
	return state
end

local function payScrap(player: Player, amount: number)
	if amount <= 0 then
		return
	end
	grantingReward[player] = true
	CurrencyService.Add(player, amount)
	grantingReward[player] = nil
end

local function completeEntry(
	player: Player,
	entry: PlayerSessionTypes.DailyQuestEntry,
	definition: DailyQuestConfig.DailyQuestDefinition
)
	entry.Completed = true
	print(`[DailyQuestService] {player.Name} completed daily "{definition.name}" — granting {definition.rewardScrap} Scrap`)
	payScrap(player, definition.rewardScrap)
	if definition.rewardXP > 0 then
		ProgressionService.AddXP(player, definition.rewardXP)
	end
end

local function grantBonusIfSetComplete(player: Player, state: PlayerSessionTypes.DailyQuestState)
	if state.BonusGranted or #state.Quests ~= DailyQuestConfig.QUESTS_PER_DAY then
		return
	end
	for _, entry in state.Quests do
		if not entry.Completed then
			return
		end
	end
	state.BonusGranted = true
	payScrap(player, DailyQuestConfig.ALL_COMPLETE_BONUS_SCRAP)
end

local function addProgress(
	player: Player,
	objectiveType: DailyQuestConfig.DailyObjectiveType,
	amount: number,
	targetId: string?
)
	if amount <= 0 then
		return
	end
	local state = ensureTodaysSet(player)
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

local function connectSignals()
	InventoryService.ItemAdded:Connect(function(player: Player, itemId: string, amountAdded: number)
		addProgress(player, "GatherItem", amountAdded, itemId)
	end)
	ResourceService.NodeHarvested:Connect(function(player: Player)
		addProgress(player, "HarvestNode", 1)
	end)
	CraftingService.ItemCrafted:Connect(function(player: Player, recipeId: string)
		addProgress(player, "CraftAny", 1)
		addProgress(player, "UseFacility", 1)
		local recipe = CraftingConfig.Get(recipeId)
		if recipe and ToolConfig.Get(recipe.output.itemId) then
			addProgress(player, "CraftTool", 1)
		end
	end)
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
		if kind == "Biome" then
			onExpeditionAt[player] = portalId
			addProgress(player, "EnterBiome", 1, portalId)
		end
	end)
	PortalService.ReturnedToHaven:Connect(function(player: Player, portalId: string, kind: string)
		if kind == "Biome" and onExpeditionAt[player] == portalId then
			onExpeditionAt[player] = nil
			addProgress(player, "CompleteExpedition", 1)
		end
	end)
	CurrencyService.BalanceChanged:Connect(function(player: Player, newBalance: number)
		local previous = lastKnownBalance[player]
		lastKnownBalance[player] = newBalance
		if previous ~= nil and not grantingReward[player] then
			addProgress(player, "EarnScrap", newBalance - previous)
		end
	end)
	DailyRewardsService.RewardClaimed:Connect(function(player: Player)
		addProgress(player, "UseFacility", 1)
	end)
	SupplyShopService.ItemPurchased:Connect(function(player: Player)
		addProgress(player, "UseFacility", 1)
	end)
end

function DailyQuestService:Init()
	connectSignals()
	PlayerSessionService.ProfileLoaded:Connect(function(player: Player)
		lastKnownBalance[player] = CurrencyService.GetBalance(player)
		ensureTodaysSet(player)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastKnownBalance[player] = nil
		grantingReward[player] = nil
		onExpeditionAt[player] = nil
	end)
	Net.GetFunction("RequestDailyQuests").OnServerInvoke = function(player: Player)
		return ensureTodaysSet(player)
	end
end

function DailyQuestService:Start()
	while true do
		task.wait(RESET_POLL_SECONDS)
		for _, player in Players:GetPlayers() do
			if PlayerSessionService.IsLoaded(player) then
				ensureTodaysSet(player)
			end
		end
	end
end

return DailyQuestService
