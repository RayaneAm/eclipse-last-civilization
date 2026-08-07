--!strict
-- The single source of truth for a player's in-memory session shape.
-- Deliberately data-only (no logic, no Instances, no functions inside the
-- data itself) so a future persistence prompt can serialize this whole
-- table directly — see src/server/Services/PlayerSessionService.luau and
-- the Prompt 4A plan's "Persistence boundary" section.
--
-- Every other session-owning service (InventoryService, ToolService,
-- CurrencyService, ProgressionService, QuestService) reads/writes its own
-- slice of this same table via PlayerSessionService.Get(player) — nobody
-- keeps a second parallel player-keyed table.

local CurrencyConfig = require(script.Parent.CurrencyConfig)

export type QuestState = {
	ActiveQuestId: string?,
	ObjectiveIndex: number, -- 1-based index into the active quest's Objectives list; meaningless if ActiveQuestId is nil
	ObjectiveProgress: number, -- progress toward the current objective's target amount
	CompletedQuestIds: { string },
}

export type PlayerSessionData = {
	Inventory: { [string]: number }, -- itemId -> quantity
	EquippedTool: string?, -- toolId, per ToolConfig
	Currencies: { Scrap: number },
	Progression: { Tier: number, XP: number }, -- XP is progress *within* the current tier, reset to 0 on every tier rollover (see ProgressionService.AddXP)
	Quest: QuestState,
}

local PlayerSessionTypes = {}

function PlayerSessionTypes.NewDefault(): PlayerSessionData
	return {
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
	}
end

return PlayerSessionTypes
