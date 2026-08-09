--!strict
-- Routes loaded profiles to Tutorial or Haven and commits authoritative
-- tutorial completion before allowing the Haven transition in production.
-- Read-only Studio playtests may transition on in-memory state.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local QuestConfig = require(ReplicatedStorage.Shared.Config.QuestConfig)
local PlayerSessionService = require(script.Parent.PlayerSessionService)
local QuestService = require(script.Parent.QuestService)
local InventoryService = require(script.Parent.InventoryService)
local PortalService = require(script.Parent.PortalService)

local TutorialProgressionService = {}

local TUTORIAL_SPAWN_NAME = "TutorialSpawn"
local HAVEN_SPAWN_NAME = "HavenSpawn"
local HATCHET_ITEM_ID = "Hatchet"
local RETRY_SECONDS = 10

local pendingCommit: { [Player]: boolean } = {}
local routingBound: { [Player]: boolean } = {}

local function findSpawn(name: string): SpawnLocation?
	local instance = Workspace:FindFirstChild(name, true)
	return if instance and instance:IsA("SpawnLocation") then instance else nil
end

local function routeCharacter(player: Player, character: Model)
	local session = PlayerSessionService.AwaitLoaded(player)
	if not player.Parent or not character.Parent then
		return
	end
	local spawnName = if session.TutorialCompleted then HAVEN_SPAWN_NAME else TUTORIAL_SPAWN_NAME
	local spawn = findSpawn(spawnName)
	if not spawn then
		warn(`[TutorialProgressionService] Missing {spawnName}; run Build Complete World.`)
		return
	end
	player.RespawnLocation = spawn
	character:PivotTo(spawn.CFrame + Vector3.new(0, 3.5, 0))
end

local function bindCharacterRouting(player: Player)
	if routingBound[player] then
		return
	end
	routingBound[player] = true
	player.CharacterAdded:Connect(function(character)
		task.spawn(routeCharacter, player, character)
	end)
	if player.Character then
		task.spawn(routeCharacter, player, player.Character)
	end
end

local function normalizeIncompleteTutorial(player: Player)
	local session = PlayerSessionService.Get(player)
	if session.TutorialCompleted then
		return
	end
	local index = table.find(session.Quest.CompletedQuestIds, QuestConfig.TutorialQuest.id)
	if index then
		table.remove(session.Quest.CompletedQuestIds, index)
		session.Quest.ActiveQuestId = nil
		session.Quest.ObjectiveIndex = 1
		session.Quest.ObjectiveProgress = 0
		PlayerSessionService.MarkDirty(player)
	end
end

local function commitAndEnterHaven(player: Player)
	if pendingCommit[player] then
		return
	end
	pendingCommit[player] = true
	while player.Parent do
		local session = PlayerSessionService.Get(player)
		if not session.TutorialCompleted then
			pendingCommit[player] = nil
			return
		end
		-- A production player never leaves the tutorial until completion is
		-- durable. Studio sessions with API Services disabled are deliberately
		-- read-only, so allow that playtest to continue on an in-memory profile.
		local completionIsSafe = if PlayerSessionService.CanPersist(player)
			then PlayerSessionService.SaveNow(player, true)
			else RunService:IsStudio()
		if completionIsSafe then
			if not PlayerSessionService.CanPersist(player) then
				warn(`[TutorialProgressionService] Persistence is unavailable for {player.Name}; Studio Haven transition is session-only.`)
			end
			local havenSpawn = findSpawn(HAVEN_SPAWN_NAME)
			if havenSpawn then
				player.RespawnLocation = havenSpawn
			end
			local ok, reason = PortalService.TeleportToHavenArrival(player)
			if not ok then
				warn(`[TutorialProgressionService] Haven transition failed for {player.Name}: {tostring(reason)}`)
			end
			pendingCommit[player] = nil
			return
		end
		warn(`[TutorialProgressionService] Completion save failed for {player.Name}; keeping player in Tutorial and retrying.`)
		task.wait(RETRY_SECONDS)
	end
	pendingCommit[player] = nil
end

-- If a prior transition failed (or a completed player deliberately revisits
-- the Tutorial Zone), speaking to the Guide again retries only the Haven
-- travel. Quest rewards and completion are not awarded a second time.
local function onCompletedQuestGiverInteracted(player: Player, questId: string)
	if questId ~= QuestConfig.TutorialQuest.id then
		return
	end
	local session = PlayerSessionService.Get(player)
	if not session.TutorialCompleted then
		if not InventoryService.HasAtLeast(player, HATCHET_ITEM_ID, 1) then
			warn(`[TutorialProgressionService] Refusing Haven transition retry for {player.Name}: canonical Hatchet is missing.`)
			return
		end
		session.TutorialCompleted = true
		PlayerSessionService.MarkDirty(player)
	end
	task.spawn(commitAndEnterHaven, player)
end

local function onQuestCompleted(player: Player, questId: string)
	if questId ~= QuestConfig.TutorialQuest.id then
		return
	end
	local session = PlayerSessionService.Get(player)
	if session.TutorialCompleted then
		return
	end
	if not InventoryService.HasAtLeast(player, HATCHET_ITEM_ID, 1) then
		warn(`[TutorialProgressionService] Refusing completion for {player.Name}: canonical Hatchet is missing.`)
		return
	end
	session.TutorialCompleted = true
	PlayerSessionService.MarkDirty(player)
	task.spawn(commitAndEnterHaven, player)
end

function TutorialProgressionService:Init()
	QuestService.QuestCompleted:Connect(onQuestCompleted)
	QuestService.CompletedQuestGiverInteracted:Connect(onCompletedQuestGiverInteracted)
	PlayerSessionService.ProfileLoaded:Connect(function(player)
		normalizeIncompleteTutorial(player)
		bindCharacterRouting(player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			PlayerSessionService.AwaitLoaded(player)
			normalizeIncompleteTutorial(player)
			bindCharacterRouting(player)
		end)
	end
	Players.PlayerRemoving:Connect(function(player)
		pendingCommit[player] = nil
		routingBound[player] = nil
	end)
end

return TutorialProgressionService
