--!strict
-- Tracks quest/objective progress inside the player's session, driven only
-- by already-validated server Signals (InventoryService.ItemAdded,
-- CraftingService.ItemCrafted) plus one remote for the NPC-interaction step
-- — there is no "tell the server you completed an objective" remote; see
-- Prompt 4A plan §7.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local QuestConfig = require(ReplicatedStorage.Shared.Config.QuestConfig)
local PlayerSessionTypes = require(ReplicatedStorage.Shared.Config.PlayerSessionTypes)
local PlayerSessionService = require(script.Parent.PlayerSessionService)
local InventoryService = require(script.Parent.InventoryService)
local CraftingService = require(script.Parent.CraftingService)
local ProgressionService = require(script.Parent.ProgressionService)
local CurrencyService = require(script.Parent.CurrencyService)
local Signal = require(ReplicatedStorage.Shared.Modules.Signal)

local QuestService = {}

QuestService.QuestCompleted = Signal.new() -- (player, questId)

local function pushUpdate(player: Player, state: PlayerSessionTypes.QuestState)
	Net.GetEvent("QuestUpdated"):FireClient(player, state)
end

-- If the current objective's progress has reached its target, either
-- advances to the next objective or, if that was the last one, completes
-- the quest and grants its reward.
local function advanceIfObjectiveComplete(player: Player)
	local state = PlayerSessionService.Get(player).Quest
	if not state.ActiveQuestId then
		return
	end

	local quest = QuestConfig.Get(state.ActiveQuestId)
	if not quest then
		return
	end

	local objective = quest.objectives[state.ObjectiveIndex]
	if not objective or state.ObjectiveProgress < objective.amount then
		return
	end

	if state.ObjectiveIndex >= #quest.objectives then
		table.insert(state.CompletedQuestIds, quest.id)
		state.ActiveQuestId = nil
		state.ObjectiveIndex = 1
		state.ObjectiveProgress = 0

		print(`[QuestService] {player.Name} completed "{quest.name}" — granting {quest.rewardScrap} Scrap, {quest.rewardXP} XP, and Progression.Tier = {quest.rewardTier}`)
		CurrencyService.Add(player, quest.rewardScrap)
		-- AddXP's own threshold-crossing already sets Tier to rewardTier here
		-- (see XPConfig — Tier 0's threshold is engineered to equal rewardXP
		-- exactly), so the explicit SetTier below is a guaranteed no-op via
		-- its own existing same-value guard. Kept anyway as the hardened,
		-- previously-debugged fallback invariant — never remove it.
		ProgressionService.AddXP(player, quest.rewardXP)
		ProgressionService.SetTier(player, quest.rewardTier)
		PlayerSessionService.MarkDirty(player)
		QuestService.QuestCompleted:Fire(player, quest.id)
	else
		state.ObjectiveIndex += 1
		state.ObjectiveProgress = 0
		PlayerSessionService.MarkDirty(player)
		local nextObjective = quest.objectives[state.ObjectiveIndex]
		print(`[QuestService] {player.Name} advanced "{quest.name}" to objective {state.ObjectiveIndex}/{#quest.objectives}: {if nextObjective then nextObjective.description else "?"}`)
	end

	pushUpdate(player, state)
end

local function onItemAdded(player: Player, itemId: string, amountAdded: number)
	local state = PlayerSessionService.Get(player).Quest
	if not state.ActiveQuestId then
		return
	end

	local quest = QuestConfig.Get(state.ActiveQuestId)
	local objective = quest and quest.objectives[state.ObjectiveIndex]
	if not objective or objective.type ~= "GatherItem" or objective.targetId ~= itemId then
		return
	end

	state.ObjectiveProgress = math.min(objective.amount, state.ObjectiveProgress + amountAdded)
	print(`[QuestService] {player.Name} progress on "{objective.description}": {state.ObjectiveProgress}/{objective.amount}`)
	pushUpdate(player, state)
	advanceIfObjectiveComplete(player)
end

local function onItemCrafted(player: Player, recipeId: string)
	local state = PlayerSessionService.Get(player).Quest
	if not state.ActiveQuestId then
		return
	end

	local quest = QuestConfig.Get(state.ActiveQuestId)
	local objective = quest and quest.objectives[state.ObjectiveIndex]
	if not objective or objective.type ~= "CraftItem" or objective.targetId ~= recipeId then
		return
	end

	state.ObjectiveProgress = objective.amount
	print(`[QuestService] {player.Name} progress on "{objective.description}": {objective.amount}/{objective.amount}`)
	pushUpdate(player, state)
	advanceIfObjectiveComplete(player)
end

-- Handles both "start" (no active quest, not yet completed) and "turn in"
-- (active quest's current objective is TalkToNPC) through one remote — the
-- server infers which from actual quest state, never a client claim.
local function interactQuestGiver(player: Player): (boolean, string)
	local state = PlayerSessionService.Get(player).Quest

	if not state.ActiveQuestId then
		if table.find(state.CompletedQuestIds, QuestConfig.TutorialQuest.id) then
			return true, "AlreadyCompleted"
		end

		state.ActiveQuestId = QuestConfig.TutorialQuest.id
		state.ObjectiveIndex = 1
		state.ObjectiveProgress = 0
		print(`[QuestService] {player.Name} started "{QuestConfig.TutorialQuest.name}" — objective 1/{#QuestConfig.TutorialQuest.objectives}: {QuestConfig.TutorialQuest.objectives[1].description}`)
		pushUpdate(player, state)
		return true, "QuestStarted"
	end

	local quest = QuestConfig.Get(state.ActiveQuestId)
	if not quest then
		return false, "UnknownQuest"
	end

	local objective = quest.objectives[state.ObjectiveIndex]
	if objective and objective.type == "TalkToNPC" then
		state.ObjectiveProgress = objective.amount
		advanceIfObjectiveComplete(player) -- TalkToNPC is always the last objective, so this completes the quest
		return true, "QuestCompleted"
	end

	return true, "InProgress"
end

function QuestService:Init()
	InventoryService.ItemAdded:Connect(onItemAdded)
	CraftingService.ItemCrafted:Connect(onItemCrafted)

	Net.GetFunction("InteractQuestGiver").OnServerInvoke = function(player: Player)
		return interactQuestGiver(player)
	end
end

return QuestService
