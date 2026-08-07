--!strict
-- ProximityPrompt-driven quest start/turn-in on the Quest Giver anchor
-- (GuidanceGenerator's QuestGiverAnchor, tagged "QuestGiver" specifically so
-- this doesn't also attach to other "NPC"-tagged anchors like the Capsule
-- Lab's scientist spot). Shows current objective text via a billboard,
-- matching the project's existing hologram-panel pattern rather than a new
-- UI system — a real quest log/HUD is a future prompt's job.
--
-- Assumes exactly one QuestGiver-tagged anchor exists (true for the current
-- design — one tutorial NPC). If a future prompt adds more, this needs a
-- per-anchor label lookup instead of the single module-level `statusLabel`.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local QuestConfig = require(ReplicatedStorage.Shared.Config.QuestConfig)
local PlayerSessionTypes = require(ReplicatedStorage.Shared.Config.PlayerSessionTypes)
local HavenLayoutConfig = require(ReplicatedStorage.Shared.Config.HavenLayoutConfig)
local HologramPanel = require(script.Parent.Parent.UI.Components.HologramPanel)
local DialogueController = require(script.Parent.DialogueController)

local QUEST_GIVER_TAG = "QuestGiver"

local QuestGiverController = {}

local statusLabel: TextLabel? = nil

-- Text formatting itself now lives in QuestConfig.DescribeCurrentObjective
-- (shared with HUDController's quest tracker widget, added this prompt) so
-- the two can't drift apart into different wording for the same state.
local function updateLabel(state: PlayerSessionTypes.QuestState)
	if statusLabel then
		statusLabel.Text = QuestConfig.DescribeCurrentObjective(state)
	end
end

-- Retrofitted onto the shared HologramPanel this prompt — same bare "..."
-- text as before, now with a real dark-glass background (previously just
-- floating white text with no panel chrome at all) and the Guidance
-- District's own accent color (120,220,140 — the same green
-- CivicBuildingGenerator/GuidanceGenerator already use for this district's
-- other geometry), since QuestGiverAnchor itself has no .Color set (unlike
-- FacilityAnchor, which the generator does color).
local function buildPanel(anchor: BasePart): TextLabel
	local guidanceAccent = HavenLayoutConfig.GetDistrict("Onboarding").accentColor

	local _billboard, labels = HologramPanel.new({
		Name = "QuestPanel",
		Size = UDim2.fromOffset(260, 60),
		StudsOffsetWorldSpace = Vector3.new(0, 9, 0),
		MaxDistance = 45,
		AccentColor = guidanceAccent,
		Parent = anchor,
		Sections = {
			{ Name = "Body", Font = Enum.Font.Gotham, TextSize = 14, Height = 44, Wrapped = true, Text = "..." },
		},
	})

	return labels.Body
end

local function setupQuestGiver(anchor: Instance)
	if not anchor:IsA("BasePart") then
		return
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "QuestGiverPrompt"
	prompt.ObjectText = "Survivor Network Outpost"
	prompt.ActionText = "Talk"
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor

	statusLabel = buildPanel(anchor)

	prompt.Triggered:Connect(function()
		-- Prompt 4C: the already-correct, already-server-validated remote
		-- call is unchanged — it's simply deferred until the player finishes
		-- (or skips) the new presentational dialogue window instead of
		-- firing silently and immediately.
		DialogueController.PresentQuestGiverDialogue(function()
			local ok, resultOrReason = Net.GetFunction("InteractQuestGiver"):InvokeServer()
			if not ok then
				warn(`QuestGiverController: interaction failed: {tostring(resultOrReason)}`)
			end
		end)
	end)
end

function QuestGiverController:Start()
	for _, instance in CollectionService:GetTagged(QUEST_GIVER_TAG) do
		setupQuestGiver(instance)
	end
	CollectionService:GetInstanceAddedSignal(QUEST_GIVER_TAG):Connect(setupQuestGiver)

	Net.GetEvent("QuestUpdated").OnClientEvent:Connect(function(state: PlayerSessionTypes.QuestState)
		updateLabel(state)
	end)

	local ok, session = pcall(function()
		return Net.GetFunction("RequestPlayerSession"):InvokeServer()
	end)
	if ok and session then
		updateLabel((session :: PlayerSessionTypes.PlayerSessionData).Quest)
	end
end

return QuestGiverController
