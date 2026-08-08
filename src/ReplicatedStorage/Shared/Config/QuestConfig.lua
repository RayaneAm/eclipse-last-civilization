--!strict
-- Quest + objective definitions. One quest to start: the tutorial chain
-- that ends in the Forest Wildlands unlock. QuestService drives progress
-- purely off this data plus server-validated Signals — see QuestService's
-- top comment for why objectives are never advanced by a client claim.

local PlayerSessionTypes = require(script.Parent.PlayerSessionTypes)

export type ObjectiveType = "GatherItem" | "CraftItem" | "TalkToNPC"

export type ObjectiveDefinition = {
	type: ObjectiveType,
	targetId: string?, -- itemId for GatherItem, recipeId for CraftItem, nil for TalkToNPC
	amount: number, -- target amount; always 1 for CraftItem/TalkToNPC
	description: string,
	locationHint: string?, -- short "where/how" guidance shown alongside description — see DescribeCurrentObjectiveHint
}

export type DialogueLine = { Speaker: string, Text: string }

-- Which page set the Quest Giver dialogue window shows, chosen client-side
-- (DialogueController) from live QuestState — see that controller for the
-- exact selection logic. Reminder's pages are static flavor; DialogueController
-- appends one more dynamic page (via DescribeCurrentObjective below) so the
-- player is always told exactly what's still needed, without this data
-- needing to restate objective text itself.
export type QuestDialogueSet = {
	Intro: { DialogueLine },
	Reminder: { DialogueLine },
	TurnIn: { DialogueLine },
	AlreadyDone: { DialogueLine },
}

export type QuestDefinition = {
	id: string,
	name: string,
	objectives: { ObjectiveDefinition },
	rewardScrap: number,
	rewardXP: number, -- must equal XPConfig.ThresholdForTier(0) for the tutorial's "full bar + gate unlock" beat to land together
	rewardTier: number, -- Progression.Tier granted on completion (see BiomeConfig's unlockTier values)
	dialogue: QuestDialogueSet,
	preQuestHint: string, -- shown before the quest has been started at all (no ActiveQuestId, not completed)
}

local QuestConfig = {}

local GUIDE_SPEAKER = "Outpost Guide"

QuestConfig.TutorialQuest = {
	id = "TutorialQuest",
	name = "First Steps",
	objectives = {
		{
			type = "GatherItem",
			targetId = "Wood",
			amount = 2,
			description = "Gather 2 Wood",
			locationHint = "Harvest resources scattered around the Tutorial Zone.",
		},
		{
			type = "GatherItem",
			targetId = "Stone",
			amount = 1,
			description = "Gather 1 Stone",
			locationHint = "Harvest resources scattered around the Tutorial Zone.",
		},
		{
			type = "CraftItem",
			targetId = "Hatchet",
			amount = 1,
			description = "Craft a Field Hatchet",
			locationHint = "Use the shelter workbench. The server moves you to Haven after the Field Hatchet is safely recorded.",
		},
	},
	rewardScrap = 25,
	rewardXP = 100,
	rewardTier = 1,
	preQuestHint = "Speak to the Survivor Guide in the training shelter to begin.",
	dialogue = {
		Intro = {
			{ Speaker = GUIDE_SPEAKER, Text = "Another survivor. Good, we need every set of hands we can get." },
			{ Speaker = GUIDE_SPEAKER, Text = "The Eclipse tore through everything we built. Wood, stone, even the basics are scarce now." },
			{
				Speaker = GUIDE_SPEAKER,
				Text = "Gather 2 Wood and 1 Stone in this clearing, then use the shelter workbench to craft a Field Hatchet.",
			},
		},
		Reminder = {
			{ Speaker = GUIDE_SPEAKER, Text = "Still gathering? The forest won't wait forever." },
			{ Speaker = GUIDE_SPEAKER, Text = "Once you have enough materials, the shelter workbench can craft a Field Hatchet." },
		},
		TurnIn = {
			{ Speaker = GUIDE_SPEAKER, Text = "Is that a Hatchet? Well done, survivor." },
			{ Speaker = GUIDE_SPEAKER, Text = "You've proven you can handle yourself out here." },
			{ Speaker = GUIDE_SPEAKER, Text = "The Forest Wildlands gate is yours to pass now. Stay sharp out there." },
		},
		AlreadyDone = {
			{ Speaker = GUIDE_SPEAKER, Text = "Good to see you again. The Forest gate is still open, whenever you're ready." },
		},
	},
} :: QuestDefinition

QuestConfig.All = { QuestConfig.TutorialQuest } :: { QuestDefinition }

function QuestConfig.Get(id: string): QuestDefinition?
	for _, quest in QuestConfig.All do
		if quest.id == id then
			return quest
		end
	end
	return nil
end

-- Derives the current-objective display text (and, when there's a numeric
-- target, its progress/target pair for a progress bar) from raw session
-- Quest state. Single source of truth for this so QuestGiverController's
-- billboard label and the HUD's quest tracker widget can't drift apart —
-- both are just different renderings of the same derived text/numbers.
function QuestConfig.DescribeCurrentObjective(state: PlayerSessionTypes.QuestState): (string, number?, number?)
	if not state.ActiveQuestId then
		if table.find(state.CompletedQuestIds, QuestConfig.TutorialQuest.id) then
			return "Quest complete. Thank you, survivor.", nil, nil
		end
		return "Speak to the Survivor Guide", 0, 1
	end

	local quest = QuestConfig.Get(state.ActiveQuestId)
	if not quest then
		return "", nil, nil
	end
	local objective = quest.objectives[state.ObjectiveIndex]
	if not objective then
		return "", nil, nil
	end

	local text = if objective.amount > 1
		then `{objective.description} ({state.ObjectiveProgress}/{objective.amount})`
		else objective.description
	return text, state.ObjectiveProgress, objective.amount
end

-- Companion to DescribeCurrentObjective: a short "where/how" line for
-- whatever step the player is currently on — the pre-quest hint, the current
-- objective's own locationHint, or a completion hint once the quest is done.
-- Always reflects only the CURRENT step (derived fresh from live state), so
-- a completed step's hint is never shown — no extra bookkeeping needed.
-- Shared by HUDController's quest tracker and SpawnBriefingController so the
-- two can't drift apart into different guidance for the same state.
function QuestConfig.DescribeCurrentObjectiveHint(state: PlayerSessionTypes.QuestState): string?
	if not state.ActiveQuestId then
		if table.find(state.CompletedQuestIds, QuestConfig.TutorialQuest.id) then
			return "The Forest Wildlands gate is open — head through the central passage."
		end
		return QuestConfig.TutorialQuest.preQuestHint
	end

	local quest = QuestConfig.Get(state.ActiveQuestId)
	if not quest then
		return nil
	end
	local objective = quest.objectives[state.ObjectiveIndex]
	return objective and objective.locationHint
end

return QuestConfig
