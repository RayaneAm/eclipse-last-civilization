--!strict
-- Tool definitions. Abstract for now — an equipped-tool id in session data,
-- no physical Roblox Tool/backpack/viewmodel yet (that's a future
-- art/animation prompt's job; this is the data/rules layer it hooks into).
--
-- Bare-handed harvesting always works at 1x (see ToolService), so a fresh
-- player is never blocked from gathering the ingredients needed to craft
-- their first tool.

export type ToolDefinition = {
	id: string,
	name: string,
	resourceId: string, -- which ResourceConfig id this tool boosts
	yieldMultiplier: number,
}

local ToolConfig = {}

ToolConfig.Hatchet = {
	id = "Hatchet",
	name = "Hatchet",
	resourceId = "Wood",
	yieldMultiplier = 2,
} :: ToolDefinition

ToolConfig.All = { ToolConfig.Hatchet } :: { ToolDefinition }

function ToolConfig.Get(id: string): ToolDefinition?
	for _, tool in ToolConfig.All do
		if tool.id == id then
			return tool
		end
	end
	return nil
end

return ToolConfig
