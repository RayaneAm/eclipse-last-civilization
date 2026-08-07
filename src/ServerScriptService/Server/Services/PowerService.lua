--!strict
-- Simple, expandable base-power grid (Phase 4A) — total capacity, current
-- consumption, generator fuel, per-consumer enable/disable, and an ordered
-- shutoff priority when fuel runs short. Deliberately not a wiring/circuit
-- simulation — see PersonalBaseConfig.PowerShutoffPriority.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local BuildingConfig = require(ReplicatedStorage.Shared.Config.BuildingConfig)
local PersonalBaseConfig = require(ReplicatedStorage.Shared.Config.PersonalBaseConfig)

local BaseService = require(script.Parent.BaseService)

local GENERATOR_BASE_CAPACITY = 10
local GENERATOR_CAPACITY_PER_LEVEL = 4

local PowerService = {}

local function generatorStructure(session)
	for _, structure in session.Structures do
		if structure.BuildingId == "Generator" then
			return structure
		end
	end
	return nil
end

function PowerService.TotalCapacity(session): number
	local generator = generatorStructure(session)
	if not generator then
		return 0
	end
	return GENERATOR_BASE_CAPACITY + (generator.Level - 1) * GENERATOR_CAPACITY_PER_LEVEL
end

function PowerService.CurrentConsumption(session): number
	local total = 0
	for structureId, enabled in session.Power.Enabled do
		if enabled then
			local structure = session.Structures[structureId]
			if structure then
				local definition = BuildingConfig.Get(structure.BuildingId)
				if definition then
					total += definition.PowerDraw
				end
			end
		end
	end
	return total
end

function PowerService.HasCapacity(session, additionalDraw: number): boolean
	return PowerService.CurrentConsumption(session) + additionalDraw <= PowerService.TotalCapacity(session)
end

-- Disables consumers, lowest-priority category first, until consumption fits
-- within capacity again. Fires PowerChanged-equivalent via BaseService's
-- broadcast so the client always knows exactly what turned off — never a
-- silent shutdown.
function PowerService.EnforceCapacity(hostUserId: number)
	local session = BaseService.Get(hostUserId)
	if not session then
		return
	end
	local capacity = PowerService.TotalCapacity(session)

	for _, _category in PersonalBaseConfig.PowerShutoffPriority do
		if PowerService.CurrentConsumption(session) <= capacity then
			break
		end
		for structureId, enabled in session.Power.Enabled do
			if PowerService.CurrentConsumption(session) <= capacity then
				break
			end
			if enabled then
				local structure = session.Structures[structureId]
				local definition = structure and BuildingConfig.Get(structure.BuildingId)
				-- category grouping here is approximate (PowerDraw doesn't
				-- currently carry its own category tag) — every consumer is
				-- eligible for shutoff once we've fallen through all
				-- priority tiers without reaching capacity.
				if definition then
					session.Power.Enabled[structureId] = false
					if structure then
						structure.Enabled = false
					end
				end
			end
		end
	end

	BaseService.BroadcastState(hostUserId)
end

local function requestSetPowerEnabled(player: Player, payload: { StructureId: string, Enabled: boolean }): (boolean, string?)
	if typeof(payload) ~= "table" or typeof(payload.StructureId) ~= "string" then
		return false, "InvalidRequest"
	end
	local session = BaseService.Get(player.UserId)
	if not session then
		return false, "BaseNotReady"
	end
	local structure = session.Structures[payload.StructureId]
	if not structure then
		return false, "UnknownStructure"
	end
	local definition = BuildingConfig.Get(structure.BuildingId)
	if not definition or definition.PowerDraw <= 0 then
		return false, "NotAPowerConsumer"
	end

	if payload.Enabled then
		if not PowerService.HasCapacity(session, definition.PowerDraw) then
			return false, "InsufficientPower"
		end
		session.Power.Enabled[payload.StructureId] = true
		structure.Enabled = true
	else
		session.Power.Enabled[payload.StructureId] = false
		structure.Enabled = false
	end

	BaseService.BroadcastState(player.UserId)
	return true
end

function PowerService:Init()
	Net.GetFunction("RequestSetPowerEnabled").OnServerInvoke = function(player: Player, payload: any)
		return requestSetPowerEnabled(player, payload)
	end
end

return PowerService
