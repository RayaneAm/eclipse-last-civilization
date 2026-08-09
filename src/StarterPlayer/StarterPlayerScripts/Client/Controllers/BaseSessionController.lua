--!strict
-- One client-side cache of the player's base session + player session, shared
-- by every base facility screen (Base Management, Production, Storage,
-- Generator, Defense Control, Upgrade Station, Survivor Quarters, Trader,
-- and the build/upgrade dialogs).
--
-- Before this, each screen invoked RequestBaseState/RequestPlayerSession on
-- its own and kept a private copy. That meant a round trip per facility open,
-- and several stale copies of the same data disagreeing with each other while
-- BaseStateChanged pushed updates to only one of them.
--
-- Now: BaseStateChanged/InventoryChanged/CurrencyChanged keep this cache
-- live, and screens subscribe to `Changed` to re-render. A screen still calls
-- Refresh() when it opens, so a freshly-joined client that has not yet seen a
-- push is never rendering an empty base.
--
-- This module is a read-through cache only. It performs no mutations — every
-- write still goes directly from the acting screen to its own remote, and the
-- authoritative result comes back through BaseStateChanged.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local Signal = require(ReplicatedStorage.Shared.Modules.Signal)
local Trove = require(ReplicatedStorage.Shared.Modules.Trove)
local BuildingConfig = require(ReplicatedStorage.Shared.Config.BuildingConfig)
local ProductionRecipeConfig = require(ReplicatedStorage.Shared.Config.ProductionRecipeConfig)
local BlueprintLayoutConfig = require(ReplicatedStorage.Shared.Config.BlueprintLayoutConfig)

local BaseSessionController = {}

BaseSessionController.Changed = Signal.new() -- fired whenever the cached base session changes

local baseSession: any = nil
local playerSession: any = nil

-- Mirrors PowerService's own constants. Capacity is a pure function of the
-- generator's level there, and the client needs the same number to render a
-- power meter; duplicating two integers is preferable to adding a remote
-- round trip for a value that is already derivable from replicated state.
-- If PowerService's curve changes, these must change with it.
local GENERATOR_BASE_CAPACITY = 10
local GENERATOR_CAPACITY_PER_LEVEL = 4

-- ---------------------------------------------------------------------
-- Accessors
-- ---------------------------------------------------------------------

function BaseSessionController.GetSession(): any
	return baseSession
end

function BaseSessionController.GetPlayerSession(): any
	return playerSession
end

function BaseSessionController.GetStorage(): { [string]: number }
	return if baseSession then baseSession.Storage else {}
end

function BaseSessionController.GetInventory(): { [string]: number }
	return if playerSession then playerSession.Inventory else {}
end

function BaseSessionController.GetScrap(): number
	if playerSession and playerSession.Currencies then
		return playerSession.Currencies.Scrap or 0
	end
	return 0
end

-- ---------------------------------------------------------------------
-- Derived summaries — computed here once so six screens don't each
-- reimplement the same loops over Structures/ProductionJobs.
-- ---------------------------------------------------------------------

export type PowerSummary = { Capacity: number, Used: number, GeneratorLevel: number, HasGenerator: boolean }

function BaseSessionController.GetPowerSummary(): PowerSummary
	local summary: PowerSummary = { Capacity = 0, Used = 0, GeneratorLevel = 0, HasGenerator = false }
	if not baseSession then
		return summary
	end

	for _, structure in baseSession.Structures do
		if structure.BuildingId == "Generator" then
			summary.HasGenerator = true
			summary.GeneratorLevel = structure.Level
			summary.Capacity = GENERATOR_BASE_CAPACITY + (structure.Level - 1) * GENERATOR_CAPACITY_PER_LEVEL
		end
	end

	for structureId, enabled in baseSession.Power.Enabled do
		if enabled then
			local structure = baseSession.Structures[structureId]
			local definition = structure and BuildingConfig.Get(structure.BuildingId)
			if definition then
				summary.Used += definition.PowerDraw
			end
		end
	end
	-- Running jobs reserve their recipe's operating draw; a finished job has
	-- stopped and no longer consumes. Same rule as PowerService.
	local now = os.time()
	for _, job in baseSession.ProductionJobs do
		if not job.Collected and now < job.CompletesAt then
			local recipe = ProductionRecipeConfig.Get(job.RecipeId)
			if recipe then
				summary.Used += recipe.PowerDraw
			end
		end
	end

	return summary
end

export type StorageSummary = { Used: number, Capacity: number, DistinctItems: number }

function BaseSessionController.GetStorageSummary(): StorageSummary
	if not baseSession then
		return { Used = 0, Capacity = 0, DistinctItems = 0 }
	end
	local used, distinct = 0, 0
	for _, amount in baseSession.Storage do
		used += amount
		if amount > 0 then
			distinct += 1
		end
	end
	return { Used = used, Capacity = baseSession.StorageCapacity, DistinctItems = distinct }
end

export type ProductionSummary = { Running: number, Ready: number, Machines: number, IdleMachines: number }

function BaseSessionController.GetProductionSummary(): ProductionSummary
	local summary: ProductionSummary = { Running = 0, Ready = 0, Machines = 0, IdleMachines = 0 }
	if not baseSession then
		return summary
	end

	local now = os.time()
	local busyMachines: { [string]: boolean } = {}
	for _, job in baseSession.ProductionJobs do
		if not job.Collected then
			busyMachines[job.MachineStructureId] = true
			if now < job.CompletesAt then
				summary.Running += 1
			else
				summary.Ready += 1
			end
		end
	end

	for structureId, structure in baseSession.Structures do
		local definition = BuildingConfig.Get(structure.BuildingId)
		if definition and definition.Category == "Production" then
			summary.Machines += 1
			if not busyMachines[structureId] then
				summary.IdleMachines += 1
			end
		end
	end

	return summary
end

-- The active (uncollected) job for a machine, or nil. Used by both the
-- Production screen and the world prompt's collect shortcut.
function BaseSessionController.GetActiveJob(machineStructureId: string): any
	if not baseSession then
		return nil
	end
	for _, job in baseSession.ProductionJobs do
		if job.MachineStructureId == machineStructureId and not job.Collected then
			return job
		end
	end
	return nil
end

export type DefenseGroupSummary = {
	Group: string,
	Built: number,
	Sockets: number,
	Tier: number, -- the WEAKEST tier in the group; 0 when any socket is still open
	Health: number,
	MaxHealth: number,
}

-- A perimeter group is only as strong as its weakest socket, so `Tier`
-- reports the minimum rather than an average — an open socket makes the
-- whole side a hole regardless of how good the other segments are.
function BaseSessionController.GetDefenseSummary(): { DefenseGroupSummary }
	local results: { DefenseGroupSummary } = {}
	if not baseSession then
		return results
	end

	local structureByPad: { [string]: any } = {}
	for _, structure in baseSession.Structures do
		if structure.PadId then
			structureByPad[structure.PadId] = structure
		end
	end

	for _, groupName in { "Front", "Left", "Right", "Back", "Gate" } do
		local summary: DefenseGroupSummary = { Group = groupName, Built = 0, Sockets = 0, Tier = 4, Health = 0, MaxHealth = 0 }
		for _, pad in BlueprintLayoutConfig.All do
			if pad.DefenseGroup ~= groupName then
				continue
			end
			summary.Sockets += 1
			local structure = structureByPad[pad.PadId]
			if structure then
				summary.Built += 1
				local definition = BuildingConfig.Get(structure.BuildingId)
				local tier = if definition and definition.DefenseTier then definition.DefenseTier else 1
				summary.Tier = math.min(summary.Tier, tier)
				summary.Health += structure.Health
				summary.MaxHealth += BuildingConfig.GetMaxHealth(structure.BuildingId)
			else
				summary.Tier = 0
			end
		end
		if summary.Sockets > 0 then
			table.insert(results, summary)
		end
	end

	return results
end

-- Every structure that has a next tier available, newest-weakest first.
-- Shared by the Upgrade Station list and Base Management's suggestions.
export type UpgradeCandidate = {
	StructureId: string,
	Structure: any,
	Current: BuildingConfig.BuildingDefinition,
	Next: BuildingConfig.BuildingDefinition,
	Affordable: boolean,
	MissingCount: number,
}

function BaseSessionController.GetUpgradeCandidates(): { UpgradeCandidate }
	local candidates: { UpgradeCandidate } = {}
	if not baseSession then
		return candidates
	end

	local storage = baseSession.Storage
	local scrap = BaseSessionController.GetScrap()

	for structureId, structure in baseSession.Structures do
		local current = BuildingConfig.Get(structure.BuildingId)
		if not current or not current.NextTierBuildingId then
			continue
		end
		local nextDefinition = BuildingConfig.Get(current.NextTierBuildingId)
		if not nextDefinition then
			continue
		end
		-- A pad-bound structure can only upgrade along that pad's allowed
		-- chain; showing an upgrade the server would reject is exactly the
		-- "button that pretends to work" this pass is removing.
		if structure.PadId then
			local pad = BlueprintLayoutConfig.Get(structure.PadId)
			if not pad or not BlueprintLayoutConfig.AcceptsBuilding(pad, nextDefinition.Id) then
				continue
			end
		end

		local missing = 0
		for itemId, amount in nextDefinition.Cost.Materials do
			if (storage[itemId] or 0) < amount then
				missing += 1
			end
		end
		if nextDefinition.Cost.Scrap > 0 and scrap < nextDefinition.Cost.Scrap then
			missing += 1
		end

		table.insert(candidates, {
			StructureId = structureId,
			Structure = structure,
			Current = current,
			Next = nextDefinition,
			Affordable = missing == 0,
			MissingCount = missing,
		})
	end

	-- Affordable first, then closest to affordable, then weakest structure —
	-- "what can I improve right now" at the top (brief §24).
	table.sort(candidates, function(a, b)
		if a.Affordable ~= b.Affordable then
			return a.Affordable
		end
		if a.MissingCount ~= b.MissingCount then
			return a.MissingCount < b.MissingCount
		end
		return (a.Current.DefenseTier or a.Structure.Level) < (b.Current.DefenseTier or b.Structure.Level)
	end)

	return candidates
end

-- Structures below full health, worst first.
export type DamagedStructure = { StructureId: string, Structure: any, Definition: BuildingConfig.BuildingDefinition, Fraction: number }

function BaseSessionController.GetDamagedStructures(): { DamagedStructure }
	local damaged: { DamagedStructure } = {}
	if not baseSession then
		return damaged
	end
	for structureId, structure in baseSession.Structures do
		local definition = BuildingConfig.Get(structure.BuildingId)
		if not definition then
			continue
		end
		local maxHealth = BuildingConfig.GetMaxHealth(structure.BuildingId)
		if structure.Health < maxHealth then
			table.insert(damaged, {
				StructureId = structureId,
				Structure = structure,
				Definition = definition,
				Fraction = structure.Health / maxHealth,
			})
		end
	end
	table.sort(damaged, function(a, b)
		return a.Fraction < b.Fraction
	end)
	return damaged
end

-- Finds a built structure by BuildingConfig id (there is at most one of each
-- pad-driven utility building in the starter layout).
function BaseSessionController.FindStructureByBuildingId(buildingId: string): (string?, any)
	if not baseSession then
		return nil, nil
	end
	for structureId, structure in baseSession.Structures do
		if structure.BuildingId == buildingId then
			return structureId, structure
		end
	end
	return nil, nil
end

function BaseSessionController.HasBuilding(buildingId: string): boolean
	local structureId = BaseSessionController.FindStructureByBuildingId(buildingId)
	return structureId ~= nil
end

-- ---------------------------------------------------------------------
-- Refresh
-- ---------------------------------------------------------------------

-- Pulls both sessions. Called when a facility screen opens; pushes keep the
-- cache current after that. pcall'd because a facility prompt firing during
-- a rejoin/teleport can hit a remote whose server handler is not up yet, and
-- that should degrade to "screen shows what it last knew", not an error.
function BaseSessionController.Refresh()
	local player = Players.LocalPlayer

	local ok, result = pcall(function()
		return Net.GetFunction("RequestBaseState"):InvokeServer(player.UserId)
	end)
	if ok and result then
		baseSession = result.Session
	end

	local playerOk, playerResult = pcall(function()
		return Net.GetFunction("RequestPlayerSession"):InvokeServer()
	end)
	if playerOk and playerResult then
		playerSession = playerResult
	end

	BaseSessionController.Changed:Fire()
end

function BaseSessionController:Init()
	self._trove = Trove.new()
end

function BaseSessionController:Start()
	self._trove:Add(Net.GetEvent("BaseStateChanged").OnClientEvent:Connect(function(session: any)
		baseSession = session
		BaseSessionController.Changed:Fire()
	end))

	self._trove:Add(Net.GetEvent("InventoryChanged").OnClientEvent:Connect(function(inventory: { [string]: number })
		if playerSession then
			playerSession.Inventory = inventory
		end
		BaseSessionController.Changed:Fire()
	end))

	self._trove:Add(Net.GetEvent("CurrencyChanged").OnClientEvent:Connect(function(currencies: any)
		if playerSession then
			-- The server sends either the whole currency table or a bare
			-- Scrap number depending on the caller; normalize both.
			if typeof(currencies) == "table" then
				playerSession.Currencies = currencies
			elseif typeof(currencies) == "number" then
				playerSession.Currencies = playerSession.Currencies or {}
				playerSession.Currencies.Scrap = currencies
			end
		end
		BaseSessionController.Changed:Fire()
	end))
end

return BaseSessionController
