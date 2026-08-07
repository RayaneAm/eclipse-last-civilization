--!strict
-- Owns the one persistent Quest Giver dialogue window and picks which page
-- set to show from locally-cached QuestState — the same established pattern
-- HUDController/QuestGiverController already use (subscribe to QuestUpdated
-- + one initial RequestPlayerSession pull), not a new parallel cache system.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local QuestConfig = require(ReplicatedStorage.Shared.Config.QuestConfig)
local PlayerSessionTypes = require(ReplicatedStorage.Shared.Config.PlayerSessionTypes)
local HavenLayoutConfig = require(ReplicatedStorage.Shared.Config.HavenLayoutConfig)

local DialogueWindow = require(script.Parent.Parent.UI.Components.DialogueWindow)

local DialogueController = {}

local windowApi: DialogueWindow.DialogueWindowApi
local latestQuestState: PlayerSessionTypes.QuestState? = nil

-- Picks Intro / Reminder(+dynamic current-objective page) / TurnIn /
-- AlreadyDone from live QuestState, exactly mirroring the branches
-- QuestService.interactQuestGiver itself uses server-side to decide
-- start-vs-turn-in-vs-reminder — this is presentation only, the server
-- still independently re-derives and validates all of this itself.
local function selectDialoguePages(): { DialogueWindow.DialogueLine }
	local quest = QuestConfig.TutorialQuest
	local dialogue = quest.dialogue
	local state = latestQuestState

	if not state or not state.ActiveQuestId then
		if state and table.find(state.CompletedQuestIds, quest.id) then
			return dialogue.AlreadyDone
		end
		return dialogue.Intro
	end

	local objective = quest.objectives[state.ObjectiveIndex]
	if objective and objective.type == "TalkToNPC" then
		return dialogue.TurnIn
	end

	local pages = table.clone(dialogue.Reminder)
	local descriptionText = QuestConfig.DescribeCurrentObjective(state)
	table.insert(pages, { Speaker = "Outpost Guide", Text = descriptionText })
	return pages
end

-- Called by QuestGiverController in place of directly invoking
-- InteractQuestGiver — onComplete is exactly that existing remote call,
-- deferred until the player finishes (or skips) the dialogue.
function DialogueController.PresentQuestGiverDialogue(onComplete: (() -> ())?)
	windowApi.Show(selectDialoguePages(), onComplete)
end

function DialogueController:Init()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "DialogueUI"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = playerGui

	local guidanceAccent = HavenLayoutConfig.GetDistrict("Onboarding").accentColor
	local _wrapper, api = DialogueWindow.new({ Parent = screenGui, AccentColor = guidanceAccent })
	windowApi = api
end

function DialogueController:Start()
	Net.GetEvent("QuestUpdated").OnClientEvent:Connect(function(state: PlayerSessionTypes.QuestState)
		latestQuestState = state
	end)

	local ok, session = pcall(function()
		return Net.GetFunction("RequestPlayerSession"):InvokeServer()
	end)
	if ok and session then
		latestQuestState = (session :: PlayerSessionTypes.PlayerSessionData).Quest
	else
		warn("DialogueController: failed to fetch initial session", session)
	end

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if Players.LocalPlayer:GetAttribute("EclipseMenuOpen") == true
			or gameProcessed
			or not windowApi.IsOpen()
		then
			return
		end
		if input.KeyCode == Enum.KeyCode.ButtonB or input.KeyCode == Enum.KeyCode.Escape then
			windowApi.Skip()
		end
	end)
end

return DialogueController
