--!strict
-- The single source of truth for a player's runtime session shape and the
-- schema/reconciliation boundary for its deliberately narrow persistent
-- subset. Economy fields remain runtime-only; tutorial, progression and
-- completed-quest fields are serialized by PlayerSessionService.
--
-- Every other session-owning service (InventoryService, ToolService,
-- CurrencyService, ProgressionService, QuestService) reads/writes its own
-- slice of this same table via PlayerSessionService.Get(player) — nobody
-- keeps a second parallel player-keyed table.

local CurrencyConfig = require(script.Parent.CurrencyConfig)
local DailyQuestConfig = require(script.Parent.DailyQuestConfig)

export type QuestState = {
	ActiveQuestId: string?,
	ObjectiveIndex: number, -- 1-based index into the active quest's Objectives list; meaningless if ActiveQuestId is nil
	ObjectiveProgress: number, -- progress toward the current objective's target amount
	CompletedQuestIds: { string },
}

export type DailyQuestEntry = {
	Id: string, -- a DailyQuestConfig.Pool id
	Progress: number,
	Completed: boolean, -- objective met AND its reward already granted
}

export type DailyQuestState = {
	DayIndex: number, -- the DailyQuestConfig.CurrentDayIndex() this set was rolled for; -1 = never rolled
	Quests: { DailyQuestEntry },
	BonusGranted: boolean, -- DailyQuestConfig.ALL_COMPLETE_BONUS_SCRAP already paid for this day
}

export type PlayerSessionData = {
	SchemaVersion: number,
	TutorialCompleted: boolean,
	Inventory: { [string]: number }, -- itemId -> quantity
	EquippedTool: string?, -- toolId, per ToolConfig
	Currencies: { Scrap: number },
	Progression: { Tier: number, XP: number }, -- XP is progress *within* the current tier, reset to 0 on every tier rollover (see ProgressionService.AddXP)
	Quest: QuestState,
	DailyQuests: DailyQuestState,
}

local PlayerSessionTypes = {}

PlayerSessionTypes.CURRENT_SCHEMA_VERSION = 1

function PlayerSessionTypes.NewDefault(): PlayerSessionData
	return {
		SchemaVersion = PlayerSessionTypes.CURRENT_SCHEMA_VERSION,
		TutorialCompleted = false,
		Inventory = {},
		EquippedTool = nil,
		Currencies = { Scrap = CurrencyConfig.Scrap.startingBalance },
		Progression = { Tier = 0, XP = 0 },
		Quest = {
			ActiveQuestId = nil,
			ObjectiveIndex = 1,
			ObjectiveProgress = 0,
			CompletedQuestIds = {},
		},
		DailyQuests = {
			DayIndex = -1, -- never equal to a real day index, so the first read always rolls a fresh set
			Quests = {},
			BonusGranted = false,
		},
	}
end

local function isFiniteNonNegativeInteger(value: any): boolean
	return typeof(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
		and value >= 0
		and value == math.floor(value)
end

-- A saved daily set is only worth restoring if it still describes today's
-- game: entries whose pool id no longer exists (a retuned/removed objective)
-- are dropped rather than left to render as a blank row, and anything past
-- QUESTS_PER_DAY is truncated so a shrunk config can't leave a player with a
-- permanently oversized set. DailyQuestService re-rolls whenever DayIndex
-- isn't today, so a set that reconciles down to nothing simply gets replaced.
local function reconcileDailyQuests(raw: any, session: PlayerSessionData)
	if typeof(raw) ~= "table" then
		return
	end
	if not isFiniteNonNegativeInteger(raw.DayIndex) then
		return -- no usable day stamp: leave the default -1 so today's set is re-rolled
	end
	if typeof(raw.Quests) ~= "table" then
		return
	end

	local entries: { DailyQuestEntry } = {}
	local seen: { [string]: boolean } = {}
	for _, entry in raw.Quests do
		if #entries >= DailyQuestConfig.QUESTS_PER_DAY then
			break
		end
		if typeof(entry) == "table" and typeof(entry.Id) == "string" and not seen[entry.Id] then
			local definition = DailyQuestConfig.Get(entry.Id)
			if definition and isFiniteNonNegativeInteger(entry.Progress) then
				seen[entry.Id] = true
				table.insert(entries, {
					Id = entry.Id,
					Progress = math.min(entry.Progress, definition.amount),
					Completed = entry.Completed == true,
				})
			end
		end
	end

	if #entries == 0 then
		return
	end

	session.DailyQuests.DayIndex = raw.DayIndex
	session.DailyQuests.Quests = entries
	session.DailyQuests.BonusGranted = raw.BonusGranted == true
end

-- Reconciles the persistent subset into a complete runtime session. Missing
-- or malformed additive fields fall back to NewDefault; runtime-only economy
-- fields intentionally start fresh and are never read from this profile store.
function PlayerSessionTypes.Reconcile(raw: any): PlayerSessionData
	local session = PlayerSessionTypes.NewDefault()
	if typeof(raw) ~= "table" then
		return session
	end

	if raw.TutorialCompleted == true then
		session.TutorialCompleted = true
	end

	if typeof(raw.Progression) == "table" then
		if isFiniteNonNegativeInteger(raw.Progression.Tier) then
			session.Progression.Tier = raw.Progression.Tier
		end
		if isFiniteNonNegativeInteger(raw.Progression.XP) then
			session.Progression.XP = raw.Progression.XP
		end
	end

	if typeof(raw.Quest) == "table" and typeof(raw.Quest.CompletedQuestIds) == "table" then
		local seen: { [string]: boolean } = {}
		for _, questId in raw.Quest.CompletedQuestIds do
			if typeof(questId) == "string" and not seen[questId] then
				seen[questId] = true
				table.insert(session.Quest.CompletedQuestIds, questId)
			end
		end
	end

	reconcileDailyQuests(raw.DailyQuests, session)

	session.SchemaVersion = PlayerSessionTypes.CURRENT_SCHEMA_VERSION
	return session
end

-- Only fields that logically survive reconnects are serialized here. The
-- caller merges this table into the previous raw record so unknown future
-- fields are retained across a save by an older server.
--
-- DailyQuests is additive and deliberately did NOT bump CURRENT_SCHEMA_VERSION:
-- a version bump makes every profile touched by a new server unreadable to a
-- still-running old one (see PlayerSessionService's future-schema kick), and
-- this field needs none of that protection. An old server reconciles the extra
-- field away harmlessly and its merge-aware save preserves it untouched, so a
-- player bouncing between server versions mid-rollout keeps their day's
-- progress either way.
function PlayerSessionTypes.SerializePersistent(session: PlayerSessionData): { [string]: any }
	local dailyQuests = {}
	for _, entry in session.DailyQuests.Quests do
		table.insert(dailyQuests, { Id = entry.Id, Progress = entry.Progress, Completed = entry.Completed })
	end

	return {
		SchemaVersion = PlayerSessionTypes.CURRENT_SCHEMA_VERSION,
		TutorialCompleted = session.TutorialCompleted,
		Progression = {
			Tier = session.Progression.Tier,
			XP = session.Progression.XP,
		},
		Quest = {
			CompletedQuestIds = table.clone(session.Quest.CompletedQuestIds),
		},
		DailyQuests = {
			DayIndex = session.DailyQuests.DayIndex,
			Quests = dailyQuests,
			BonusGranted = session.DailyQuests.BonusGranted,
		},
	}
end

return PlayerSessionTypes
