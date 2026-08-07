--!strict
-- Owns EquippedTool inside the player's session. Abstract for now — an
-- equipped-tool id only, no physical Roblox Tool/backpack/viewmodel yet
-- (that's a future art/animation prompt's job; this is the data/rules layer
-- it will eventually hook into).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local ToolConfig = require(ReplicatedStorage.Shared.Config.ToolConfig)
local PlayerSessionService = require(script.Parent.PlayerSessionService)
local InventoryService = require(script.Parent.InventoryService)

local ToolService = {}

function ToolService.GetEquipped(player: Player): string?
	return PlayerSessionService.Get(player).EquippedTool
end

-- 1x for bare hands or a tool that doesn't apply to this resource, so a
-- fresh player is never blocked from gathering their first tool's ingredients.
function ToolService.GetHarvestMultiplier(player: Player, resourceId: string): number
	local equippedId = ToolService.GetEquipped(player)
	if not equippedId then
		return 1
	end
	local tool = ToolConfig.Get(equippedId)
	if not tool or tool.resourceId ~= resourceId then
		return 1
	end
	return tool.yieldMultiplier
end

local function tryEquip(player: Player, toolId: string): (boolean, string?)
	if typeof(toolId) ~= "string" then
		return false, "InvalidTool"
	end
	local tool = ToolConfig.Get(toolId)
	if not tool then
		return false, "UnknownTool"
	end
	if not InventoryService.HasAtLeast(player, toolId, 1) then
		return false, "NotOwned"
	end

	PlayerSessionService.Get(player).EquippedTool = toolId
	return true
end

function ToolService:Init()
	Net.GetFunction("EquipTool").OnServerInvoke = function(player: Player, toolId: string)
		return tryEquip(player, toolId)
	end
end

return ToolService
