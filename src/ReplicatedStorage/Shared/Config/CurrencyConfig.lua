--!strict
-- Single source of truth for the game's earn-only soft currency. No
-- monetization hooks here — see Prompt 4A's explicit non-goal.

export type CurrencyDefinition = {
	id: string,
	name: string,
	startingBalance: number,
}

local CurrencyConfig = {}

CurrencyConfig.Scrap = {
	id = "Scrap",
	name = "Scrap",
	startingBalance = 0,
} :: CurrencyDefinition

return CurrencyConfig
