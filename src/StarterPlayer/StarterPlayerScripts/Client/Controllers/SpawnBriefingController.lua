--!strict
-- Shows a short, useful "what should I do next" card once per character
-- spawn: the active quest's current guidance if the tutorial isn't done, or
-- otherwise the highest biome the player's progression currently allows —
-- derived purely from the existing ProgressionService/PlayerSession/BiomeConfig
-- data (never a client-side guess), exactly mirroring BiomeGateService's own
-- unlock-tier comparison. This is what replaced the old star-Banner as the
-- "first thing the player sees" role — a separate, purpose-built card, not a
-- reuse of NotificationController's reactive-event Banner.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local BiomeConfig = require(ReplicatedStorage.Shared.Config.BiomeConfig)
local QuestConfig = require(ReplicatedStorage.Shared.Config.QuestConfig)
local PlayerSessionTypes = require(ReplicatedStorage.Shared.Config.PlayerSessionTypes)

local Theme = require(script.Parent.Parent.UI.Theme)
local Motion = require(script.Parent.Parent.UI.Motion)
local SpawnBriefingCard = require(script.Parent.Parent.UI.Components.SpawnBriefingCard)

local CameraIntroController = require(script.Parent.CameraIntroController)

local SpawnBriefingController = {}

local VISIBLE_SECONDS = 10
local RESPAWN_DELAY_SECONDS = 1 -- no cinematic replays on respawn; just a short settle delay
local CARD_TOP_OFFSET = Theme.Spacing.L

-- Client-side derivation only, from data already fetched via the existing
-- RequestPlayerSession pull — no new remote, mirrors
-- BiomeGateService.buildStatusFor's own unlockTier comparison exactly.
local function findHighestAccessibleBiome(tier: number): BiomeConfig.BiomeDefinition?
	local best: BiomeConfig.BiomeDefinition? = nil
	for _, biome in BiomeConfig do
		if tier >= biome.unlockTier and (not best or biome.unlockTier > best.unlockTier) then
			best = biome
		end
	end
	return best
end

local function showCard(screenGui: ScreenGui, category: string, name: string, accentColor: Color3, lines: { string }, action: string)
	local wrapper, scale = SpawnBriefingCard.new({
		Category = category,
		Name = name,
		AccentColor = accentColor,
		Lines = lines,
		Action = action,
		Parent = screenGui,
	})

	-- Small downward slide + fade on entrance.
	wrapper.Position = UDim2.new(0.5, 0, 0, CARD_TOP_OFFSET - 12)
	Motion.FadeIn(wrapper, Theme.Motion.PanelOpen.Time)
	Motion.Tween(wrapper, "Slide", Theme.Motion.PanelOpen, { Position = UDim2.new(0.5, 0, 0, CARD_TOP_OFFSET) })
	Motion.Tween(scale, "Pop", Theme.Motion.PanelOpen, { Scale = 1 })

	task.delay(VISIBLE_SECONDS, function()
		if wrapper.Parent then
			Motion.FadeOut(wrapper, Theme.Motion.PanelClose.Time, function()
				wrapper:Destroy()
			end)
		end
	end)
end

local function buildAndShow(screenGui: ScreenGui)
	local ok, session = pcall(function()
		return Net.GetFunction("RequestPlayerSession"):InvokeServer()
	end)
	if not ok or not session then
		warn("SpawnBriefingController: failed to fetch session for spawn briefing", session)
		return
	end
	local data = session :: PlayerSessionTypes.PlayerSessionData
	local quest = data.Quest
	local questComplete = table.find(quest.CompletedQuestIds, QuestConfig.TutorialQuest.id) ~= nil

	if not questComplete then
		-- Priority 1: an incomplete tutorial/active quest always wins.
		local objectiveText = QuestConfig.DescribeCurrentObjective(quest)
		local hint = QuestConfig.DescribeCurrentObjectiveHint(quest)
		showCard(
			screenGui,
			"Tutorial",
			QuestConfig.TutorialQuest.name,
			Theme.Colors.Brand,
			{ hint or "" },
			`Current objective: {objectiveText}`
		)
		return
	end

	-- Priority 2: no active objective — show the highest currently
	-- accessible biome.
	local biome = findHighestAccessibleBiome(data.Progression.Tier)
	if not biome then
		return -- not reachable in practice: completing the tutorial always grants at least Forest's tier
	end

	showCard(
		screenGui,
		"Expedition Available",
		biome.name,
		biome.gate.accentColor,
		{ "This is the highest region currently available to you.", `Recommended Level: {biome.recommendedLevel}` },
		`Head to the {biome.name} gate to begin your expedition.`
	)
end

function SpawnBriefingController:Init()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "SpawnBriefingUI"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = false -- clears Roblox's own topbar automatically, same as HUDController
	screenGui.Parent = playerGui
	self._screenGui = screenGui
end

function SpawnBriefingController:Start()
	local player = Players.LocalPlayer
	local isFirstSpawn = true

	local function onCharacterAdded()
		if isFirstSpawn then
			isFirstSpawn = false
			-- First spawn: wait for the cinematic (if any) to hand back
			-- control before showing anything on top of it. Race-safe
			-- flag+signal pair — CameraIntroController may have already
			-- finished by the time we get here.
			if CameraIntroController.HasFinished then
				buildAndShow(self._screenGui)
			else
				CameraIntroController.IntroFinished:Once(function()
					buildAndShow(self._screenGui)
				end)
			end
		else
			-- Respawn: the cinematic never replays, so there's nothing to
			-- wait for — just a short settle delay.
			task.delay(RESPAWN_DELAY_SECONDS, function()
				buildAndShow(self._screenGui)
			end)
		end
	end

	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		onCharacterAdded()
	end
end

return SpawnBriefingController
