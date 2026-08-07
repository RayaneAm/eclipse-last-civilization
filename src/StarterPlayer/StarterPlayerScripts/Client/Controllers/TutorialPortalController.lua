--!strict
-- Handles the Tutorial Portal's interaction (Prompt 2) — discovered via
-- CollectionService tag "TutorialPortal" (set by GuidanceGenerator),
-- mirroring GateController's tag-driven discovery pattern. Unlike a biome
-- gate, this has no lock state at all: it's always active, so there's no
-- BiomeGateService involvement and no status panel, just a ProximityPrompt
-- straight to PortalService — re-enterable any time, never blocking an
-- experienced player who's already completed it.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local Trove = require(ReplicatedStorage.Shared.Modules.Trove)

local TUTORIAL_PORTAL_TAG = "TutorialPortal"
local TUTORIAL_PORTAL_ID = "Tutorial"
local TUTORIAL_GATE_BIOME_ID = "ForestWildlands" -- same Tier >= 1 threshold as tutorial completion — see BiomeGateService

local TutorialPortalController = {}

-- Shared with GateController/ReturnPortalController's own guards — only one
-- portal travel request should ever be in flight at a time client-side; the
-- server enforces its own cooldown/duplicate-request checks independently.
local travelRequestInFlight = false

-- Portal Expedition Zone rework: stronger guidance only for players who
-- haven't completed the tutorial ("Do not integrate the Tutorial Portal
-- into the main arc... no giant permanent START HERE label for experienced
-- players... reduced emphasis for returning players"). Reuses the same
-- RequestGateStatus/ForestWildlands.unlocked signal ExpeditionBarrierController
-- uses — no new remote, no duplicate tutorial-tracking.
local function buildGuidanceLabel(instance: BasePart, trove: any, tutorialIncomplete: boolean)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "GuidanceLabel"
	billboard.Size = if tutorialIncomplete then UDim2.fromOffset(220, 48) else UDim2.fromOffset(140, 26)
	billboard.StudsOffset = Vector3.new(0, if tutorialIncomplete then 3.5 else 2.5, 0)
	billboard.MaxDistance = if tutorialIncomplete then 60 else 30
	billboard.LightInfluence = 0
	billboard.Parent = instance
	trove:Add(billboard)

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = if tutorialIncomplete then Enum.Font.GothamBlack else Enum.Font.GothamMedium
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = if tutorialIncomplete then 0.25 else 0.6
	label.Text = if tutorialIncomplete then "ENTER TUTORIAL" else "Tutorial Zone"
	label.Parent = billboard

	if tutorialIncomplete then
		-- Modest pulse — stays inside the project's Quad/Out|Sine/InOut-only
		-- motion vocabulary, restrained (never full transparency).
		local tween = TweenService:Create(
			label,
			TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ TextTransparency = 0.35 }
		)
		tween:Play()
		trove:Add(tween)
	end
end

local function setupTutorialPortal(instance: Instance, trove: any, tutorialIncomplete: boolean)
	if not instance:IsA("BasePart") then
		return
	end

	local prompt = instance:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		warn(`TutorialPortalController: "{instance:GetFullName()}" is tagged {TUTORIAL_PORTAL_TAG} but has no ProximityPrompt`)
		return
	end

	buildGuidanceLabel(instance, trove, tutorialIncomplete)

	trove:Add(prompt.Triggered:Connect(function()
		if travelRequestInFlight then
			return
		end
		travelRequestInFlight = true

		task.spawn(function()
			local ok, reason = Net.GetFunction("RequestPortalTravel"):InvokeServer(TUTORIAL_PORTAL_ID)
			if not ok then
				warn(`TutorialPortalController: travel to the Tutorial Zone failed: {tostring(reason)}`)
			end
			travelRequestInFlight = false
		end)
	end))
end

function TutorialPortalController:Init()
	self._trove = Trove.new()
end

function TutorialPortalController:Start()
	local tutorialIncomplete = true -- default to the stronger cue if the fetch fails; never worse than showing guidance to someone who doesn't need it
	local ok, result = pcall(function()
		return Net.GetFunction("RequestGateStatus"):InvokeServer()
	end)
	if ok and typeof(result) == "table" then
		for _, entry in result do
			if entry.id == TUTORIAL_GATE_BIOME_ID then
				tutorialIncomplete = entry.unlocked ~= true
				break
			end
		end
	else
		warn("TutorialPortalController: failed to fetch initial gate status", result)
	end

	for _, instance in CollectionService:GetTagged(TUTORIAL_PORTAL_TAG) do
		setupTutorialPortal(instance, self._trove, tutorialIncomplete)
	end

	CollectionService:GetInstanceAddedSignal(TUTORIAL_PORTAL_TAG):Connect(function(instance)
		setupTutorialPortal(instance, self._trove, tutorialIncomplete)
	end)
end

return TutorialPortalController
