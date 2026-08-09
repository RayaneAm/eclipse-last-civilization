--!strict
-- Base production job flow (Phase 4A): start/collect/cancel, materials +
-- Scrap debited atomically at start (never on collect), server-only
-- os.time() timestamps (never a client-supplied duration), output granted
-- to base Storage exactly once. Cancel forfeits already-consumed inputs —
-- no refund — the simplest rule that structurally prevents any
-- cancel-to-duplicate exploit, disclosed in the UI before the player
-- confirms starting a job.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local Signal = require(ReplicatedStorage.Shared.Modules.Signal)
local BuildingConfig = require(ReplicatedStorage.Shared.Config.BuildingConfig)
local ProductionRecipeConfig = require(ReplicatedStorage.Shared.Config.ProductionRecipeConfig)

local BaseService = require(script.Parent.BaseService)
local PowerService = require(script.Parent.PowerService)
local CurrencyService = require(script.Parent.CurrencyService)

local ProductionService = {}
ProductionService.ProductionStarted = Signal.new() -- (player, machineStructureId, recipeId, jobId)
ProductionService.ProductionCollected = Signal.new() -- (player, machineStructureId, recipeId, outputItemId, amount)

local function refreshWorldVisuals(userId: number, session)
	local PersonalBaseGenerator = require(ServerStorage.Tools.Generators.PersonalBaseGenerator)
	PersonalBaseGenerator.UpdateProductionVisual(userId, session)
end

local function totalStored(session): number
	local total = 0
	for _, amount in session.Storage do
		total += amount
	end
	return total
end

local function activeJobCount(session, machineStructureId: string): number
	local count = 0
	for _, job in session.ProductionJobs do
		if job.MachineStructureId == machineStructureId and not job.Collected then
			count += 1
		end
	end
	return count
end

local function requestStartJob(player: Player, payload: { MachineStructureId: string, RecipeId: string }): (boolean, string?)
	if typeof(payload) ~= "table" or typeof(payload.MachineStructureId) ~= "string" or typeof(payload.RecipeId) ~= "string" then
		return false, "InvalidRequest"
	end
	local session = BaseService.Get(player.UserId)
	if not session then
		return false, "BaseNotReady"
	end

	local machine = session.Structures[payload.MachineStructureId]
	if not machine then
		return false, "UnknownMachine"
	end
	local recipe = ProductionRecipeConfig.Get(payload.RecipeId)
	if not recipe or recipe.MachineBuildingId ~= machine.BuildingId then
		return false, "UnknownRecipe"
	end
	local machineDefinition = BuildingConfig.Get(machine.BuildingId)
	if not machineDefinition then
		return false, "UnknownMachine"
	end
	local productionProfile = machineDefinition.ProductionProfile
	if not productionProfile then
		return false, "NotAProductionMachine"
	end
	if activeJobCount(session, payload.MachineStructureId) >= productionProfile.QueueSize then
		return false, "MachineBusy"
	end

	for itemId, amount in recipe.Materials do
		if (session.Storage[itemId] or 0) < amount then
			return false, "InsufficientMaterials"
		end
	end
	if CurrencyService.GetBalance(player) < recipe.Scrap then
		return false, "InsufficientScrap"
	end
	local machineActivationDraw = if machineDefinition.PowerDraw > 0 and session.Power.Enabled[payload.MachineStructureId] ~= true
		then machineDefinition.PowerDraw
		else 0
	if not PowerService.HasCapacity(session, machineActivationDraw + recipe.PowerDraw) then
		return false, "InsufficientPower"
	end
	if machineActivationDraw > 0 then
		session.Power.Enabled[payload.MachineStructureId] = true
		machine.Enabled = true
	end

	-- Debited immediately, atomically — no yielding between the checks
	-- above and the mutations below, so nothing else can observe or race a
	-- half-applied state.
	for itemId, amount in recipe.Materials do
		session.Storage[itemId] -= amount
	end
	if recipe.Scrap > 0 then
		CurrencyService.Remove(player, recipe.Scrap)
	end

	local jobId = HttpService:GenerateGUID(false)
	local now = os.time()
	local duration = math.max(1, math.ceil(recipe.DurationSeconds / productionProfile.SpeedMultiplier))
	session.ProductionJobs[jobId] = {
		Id = jobId,
		MachineStructureId = payload.MachineStructureId,
		RecipeId = payload.RecipeId,
		StartedAt = now,
		CompletesAt = now + duration,
		Collected = false,
	}

	refreshWorldVisuals(player.UserId, session)
	ProductionService.ProductionStarted:Fire(player, payload.MachineStructureId, payload.RecipeId, jobId)
	BaseService.BroadcastState(player.UserId)
	return true, jobId
end

local function requestCollectJob(player: Player, payload: { JobId: string }): (boolean, string?)
	if typeof(payload) ~= "table" or typeof(payload.JobId) ~= "string" then
		return false, "InvalidRequest"
	end
	local session = BaseService.Get(player.UserId)
	if not session then
		return false, "BaseNotReady"
	end
	local job = session.ProductionJobs[payload.JobId]
	if not job then
		return false, "UnknownJob"
	end
	if job.Collected then
		return false, "AlreadyCollected"
	end
	if os.time() < job.CompletesAt then
		return false, "NotFinished"
	end

	local recipe = ProductionRecipeConfig.Get(job.RecipeId)
	if not recipe then
		return false, "UnknownRecipe"
	end
	if totalStored(session) + recipe.OutputQuantity > session.StorageCapacity then
		return false, "StorageFull"
	end

	-- Flip the flag BEFORE granting output — a second concurrent collect
	-- request on the same job (e.g. a repeated click) sees Collected=true
	-- and is rejected above, never granting twice.
	job.Collected = true
	session.Storage[recipe.OutputItemId] = (session.Storage[recipe.OutputItemId] or 0) + recipe.OutputQuantity
	session.ProductionJobs[payload.JobId] = nil

	refreshWorldVisuals(player.UserId, session)
	ProductionService.ProductionCollected:Fire(player, job.MachineStructureId, job.RecipeId, recipe.OutputItemId, recipe.OutputQuantity)
	BaseService.BroadcastState(player.UserId)
	return true
end

local function requestCancelJob(player: Player, payload: { JobId: string }): (boolean, string?)
	if typeof(payload) ~= "table" or typeof(payload.JobId) ~= "string" then
		return false, "InvalidRequest"
	end
	local session = BaseService.Get(player.UserId)
	if not session then
		return false, "BaseNotReady"
	end
	local job = session.ProductionJobs[payload.JobId]
	if not job then
		return false, "UnknownJob"
	end
	if job.Collected then
		return false, "AlreadyCollected"
	end

	-- No refund — materials/Scrap already consumed at start stay consumed.
	session.ProductionJobs[payload.JobId] = nil
	refreshWorldVisuals(player.UserId, session)
	BaseService.BroadcastState(player.UserId)
	return true
end

function ProductionService:Init()
	Net.GetFunction("RequestStartProduction").OnServerInvoke = function(player: Player, payload: any)
		return requestStartJob(player, payload)
	end
	Net.GetFunction("RequestCollectProduction").OnServerInvoke = function(player: Player, payload: any)
		return requestCollectJob(player, payload)
	end
	Net.GetFunction("RequestCancelProduction").OnServerInvoke = function(player: Player, payload: any)
		return requestCancelJob(player, payload)
	end
end

return ProductionService
