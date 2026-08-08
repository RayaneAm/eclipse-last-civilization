--!strict
-- Drives the 4 biome gates: holographic info panel + locked/unlocked visual
-- state + activation FX pulse. Reads gates from CollectionService tag
-- "BiomeGate" (set on each gate's anchor Part by the world-build tool),
-- keeping this controller independent of exactly how the geometry was
-- assembled — a hand-tuned gate works identically to a freshly generated one.
--
-- Gate lock state is fetched from the server (BiomeGateService) — never
-- trusted client-side — so a locked gate can't be spoofed open.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local BiomeConfig = require(ReplicatedStorage.Shared.Config.BiomeConfig)
local Trove = require(ReplicatedStorage.Shared.Modules.Trove)
local QualityController = require(script.Parent.QualityController)
local HologramPanel = require(script.Parent.Parent.UI.Components.HologramPanel)
local NotificationController = require(script.Parent.NotificationController)

local FOV_PUNCH_MAX_DISTANCE = 50 -- studs; keeps the camera beat reserved for a player actually near the gate

local GATE_TAG = "BiomeGate"
local BARRIER_TAG = "GateBarrier"
-- Must stay equal to GateGenerator.BARRIER_LOCKED_TRANSPARENCY. This one is
-- what actually renders: applyBarrierVisual tweens every barrier to it as
-- soon as the client picks the gate up, overwriting whatever the world build
-- baked in. The generator now uses grounded rectangular glass panels; this
-- shared value keeps their locked state restrained and their unlocked state
-- nearly invisible.
local BARRIER_LOCKED_TRANSPARENCY = 0.68
local BARRIER_UNLOCKED_TRANSPARENCY = 0.86 -- readable energy remains after unlocking

local GateController = {}

local biomeById: { [string]: BiomeConfig.BiomeDefinition } = {}
for _, biome in BiomeConfig do
	biomeById[biome.id] = biome
end

local statusCache: { [string]: boolean } = {}
-- Shared across every gate — only one portal travel request should ever be
-- in flight at a time (client-side spam guard; the server enforces its own
-- cooldown/duplicate-request checks independently, never trusting this).
local travelRequestInFlight = false

local function findFxLight(anchor: BasePart): PointLight?
	local model = anchor:FindFirstAncestorOfClass("Model") or anchor
	return model:FindFirstChild("ActivationLight", true) :: PointLight?
end

local function findFxParticles(anchor: BasePart): { ParticleEmitter }
	local model = anchor:FindFirstAncestorOfClass("Model") or anchor
	local emitters = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("ParticleEmitter") and descendant.Name == "ActivationParticles" then
			table.insert(emitters, descendant)
		end
	end
	return emitters
end

local function findBarrier(biomeId: string): BasePart?
	for _, instance in CollectionService:GetTagged(BARRIER_TAG) do
		if instance:IsA("BasePart") and instance:GetAttribute("BiomeId") == biomeId then
			return instance
		end
	end
	return nil
end

local function applyLockVisual(anchor: BasePart, unlocked: boolean)
	local quality = QualityController.GetSettings()

	local light = findFxLight(anchor)
	if light then
		light.Enabled = unlocked
	end

	for _, emitter in findFxParticles(anchor) do
		emitter.Enabled = unlocked
		emitter.Rate = unlocked and (emitter:GetAttribute("BaseRate") :: number? or 10) * quality.ParticleScale or 0
	end
end

-- Client-side visual only — actual collision is 100% server-authoritative
-- via BiomeGateService's PhysicsService groups, unchanged by this fade. This
-- just makes an opened gate visibly read as open instead of silently
-- non-solid while still looking identical to every other player's view of
-- the same (still-rendered) barrier part.
local function applyBarrierVisual(barrier: BasePart?, unlocked: boolean)
	if not barrier then
		return
	end
	local target = if unlocked then BARRIER_UNLOCKED_TRANSPARENCY else BARRIER_LOCKED_TRANSPARENCY
	TweenService:Create(barrier, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = target,
	}):Play()
end

local function pulseActivation(anchor: BasePart)
	local light = findFxLight(anchor)
	if not light then
		return
	end
	local baseRange = light.Range
	local tween =
		TweenService:Create(light, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true), {
			Range = baseRange * 1.6,
		})
	tween:Play()
end

-- One-time celebration on unlock: reuses the existing ActivationParticles
-- (already wired by applyLockVisual for the steady-state Enabled/Rate), just
-- temporarily boosted with a burst, then restored to its normal rate.
local function celebrateParticles(anchor: BasePart)
	local quality = QualityController.GetSettings()
	for _, emitter in findFxParticles(anchor) do
		local baseRate = (emitter:GetAttribute("BaseRate") :: number? or 10) * quality.ParticleScale
		emitter.Rate = baseRate * 4
		emitter:Emit(40)
		task.delay(1.2, function()
			if emitter.Parent then
				emitter.Rate = baseRate
			end
		end)
	end
end

-- Runtime-created one-shot chime — matching AmbientController.playPlazaAmbience's
-- existing "build the Sound at runtime, gate playback on a non-empty SoundId"
-- pattern rather than a tools/Generators change (this is client polish, not
-- static world-build content). SoundId is intentionally "" — a wired hook,
-- not working audio, since no audio assets exist anywhere in this project yet.
local function playUnlockChime(anchor: BasePart)
	local sound = Instance.new("Sound")
	sound.Name = "GateUnlockChime"
	sound.SoundId = ""
	sound.Volume = 0.6
	sound.Parent = anchor
	if sound.SoundId ~= "" then
		sound:Play()
	end
	Debris:AddItem(sound, 3)
end

-- Tasteful camera emphasis: a brief FieldOfView punch, never touching
-- CameraType or taking control away (unlike CameraIntroController's heavier
-- spawn-only cinematic pattern, which would be a much bigger UX risk to use
-- during live gameplay). Gated to players actually near the gate that just
-- unlocked, so it doesn't fire for someone still standing at the Quest Giver.
local function isLocalPlayerNear(anchor: BasePart): boolean
	local character = Players.LocalPlayer.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return rootPart ~= nil and (rootPart.Position - anchor.Position).Magnitude <= FOV_PUNCH_MAX_DISTANCE
end

local function punchCamera()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local baseFov = camera.FieldOfView
	local tweenIn = TweenService:Create(camera, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		FieldOfView = baseFov - 6,
	})
	tweenIn:Play()
	tweenIn.Completed:Once(function()
		TweenService:Create(camera, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			FieldOfView = baseFov,
		}):Play()
	end)
end

-- Premium multi-section holographic layout (Prompt 4A.1, generalized onto
-- Components/HologramPanel.luau this prompt): icon+title, description,
-- Recommended Level, Status, and — only while locked — a Requirement line.
-- Parented to a small dedicated float-anchor Part (not the GateAnchor
-- itself, same "anchor stays put, decoration moves" separation used
-- throughout the generators) so AmbientController's existing AmbientFloat
-- tag can give the whole panel a slow, tasteful vertical bob without
-- disturbing the ProximityPrompt/FX anchor beneath it.
local function buildPanel(anchor: BasePart, biome: BiomeConfig.BiomeDefinition): (BillboardGui, { [string]: TextLabel })
	local floatAnchor = Instance.new("Part")
	floatAnchor.Name = "GatePanelFloatAnchor"
	floatAnchor.Size = Vector3.new(0.2, 0.2, 0.2)
	floatAnchor.Transparency = 1
	floatAnchor.CanCollide = false
	floatAnchor.CanQuery = false
	floatAnchor.Anchored = true
	floatAnchor.CFrame = anchor.CFrame * CFrame.new(0, 13, 0)
	floatAnchor:SetAttribute("FloatAmplitude", 0.7)
	floatAnchor:SetAttribute("FloatSpeed", 0.8)
	CollectionService:AddTag(floatAnchor, "AmbientFloat")
	floatAnchor.Parent = anchor

	local billboard, labels = HologramPanel.new({
		Name = "GatePanel",
		Size = UDim2.fromOffset(270, 172),
		AccentColor = biome.gate.accentColor,
		Parent = floatAnchor,
		Sections = {
			{
				Name = "Title",
				Font = Enum.Font.GothamBlack,
				TextSize = 17,
				Height = 24,
				Text = `{biome.gate.icon}  {string.upper(biome.name)}`,
			},
			{
				Name = "Description",
				Font = Enum.Font.Gotham,
				TextSize = 12,
				Height = 42,
				Wrapped = true,
				TextColor3 = Color3.fromRGB(215, 215, 220),
				Text = biome.description,
			},
			{ Kind = "Divider", Name = "Divider", Height = 1 },
			{
				Name = "RecommendedLevel",
				Font = Enum.Font.GothamMedium,
				TextSize = 12,
				Height = 16,
				TextColor3 = Color3.fromRGB(200, 200, 205),
				Text = `Recommended Level {biome.recommendedLevel}`,
			},
			{ Name = "Status", Font = Enum.Font.GothamBold, TextSize = 13, Height = 16, Text = "..." },
			{
				Name = "Requirement",
				Font = Enum.Font.GothamMedium,
				TextSize = 12,
				Height = 16,
				TextColor3 = Color3.fromRGB(230, 160, 160),
				Text = `Requires: {biome.unlockRequirementText}`,
			},
		},
	})

	return billboard, labels
end

local function refreshPanel(labels: { [string]: TextLabel }, unlocked: boolean)
	local statusLabel = labels.Status
	if statusLabel then
		if unlocked then
			statusLabel.Text = "◆ AVAILABLE"
			statusLabel.TextColor3 = Color3.fromRGB(120, 220, 130)
		else
			statusLabel.Text = "● LOCKED"
			statusLabel.TextColor3 = Color3.fromRGB(220, 90, 90)
		end
	end

	local requirementLabel = labels.Requirement
	if requirementLabel then
		requirementLabel.Visible = not unlocked
	end
end

local function setupGate(anchor: Instance, trove: any)
	if not anchor:IsA("BasePart") then
		return
	end

	local biomeId = anchor:GetAttribute("BiomeId") :: string?
	if not biomeId then
		warn(`GateController: "{anchor:GetFullName()}" is tagged {GATE_TAG} but has no BiomeId attribute`)
		return
	end

	local biome = biomeById[biomeId]
	if not biome then
		warn(`GateController: unknown BiomeId "{biomeId}" on {anchor:GetFullName()}`)
		return
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GatePrompt"
	prompt.ObjectText = biome.name
	prompt.ActionText = "Inspect"
	prompt.MaxActivationDistance = 18
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor
	trove:Add(prompt)

	local panel, labels = buildPanel(anchor, biome)
	trove:Add(panel.Parent) -- the float anchor Part; destroying it also destroys the panel (its child)

	local barrier = findBarrier(biomeId)

	local function applyStatus()
		local unlocked = statusCache[biomeId] == true
		applyLockVisual(anchor, unlocked)
		applyBarrierVisual(barrier, unlocked)
		refreshPanel(labels, unlocked)
		-- Clear interaction affordance once unlocked (Prompt 2: the gate is
		-- now a real portal, not just a locked-state visual) — locked gates
		-- keep the existing "Inspect" pulse-only behavior; the "Requirement"
		-- panel text already communicates why it can't be used yet.
		prompt.ActionText = if unlocked then "Travel" else "Inspect"
	end

	applyStatus()

	trove:Add(prompt.Triggered:Connect(function()
		if not statusCache[biomeId] then
			-- Locked: a proximity pulse is enough feedback — no remote call at
			-- all, the panel's "Requirement" line already explains why.
			pulseActivation(anchor)
			return
		end

		if travelRequestInFlight then
			return
		end
		travelRequestInFlight = true

		task.spawn(function()
			local ok, reason = Net.GetFunction("RequestPortalTravel"):InvokeServer(biomeId)
			if not ok then
				warn(`GateController: portal travel to "{biomeId}" failed: {tostring(reason)}`)
			end
			travelRequestInFlight = false
		end)
	end))

	trove:Add(Net.GetEvent("GateActivated").OnClientEvent:Connect(function(activatedBiomeId: string)
		if activatedBiomeId ~= biomeId then
			return
		end
		-- Prompt 4C bugfix: statusCache was never written after the initial
		-- RequestGateStatus fetch, so even a correctly-firing GateActivated
		-- would still read the stale "locked" value here.
		statusCache[biomeId] = true
		applyStatus()
		pulseActivation(anchor)
		celebrateParticles(anchor)
		playUnlockChime(anchor)
		NotificationController.Banner(
			"BiomeUnlocked",
			`{biome.gate.icon} {biome.name} Unlocked`,
			"The gate is open. Step through whenever you're ready.",
			{ Icon = biome.gate.icon, AccentColor = biome.gate.accentColor }
		)
		if isLocalPlayerNear(anchor) then
			punchCamera()
		end
	end))
end

function GateController:Init()
	self._trove = Trove.new()
end

function GateController:Start()
	local ok, result = pcall(function()
		return Net.GetFunction("RequestGateStatus"):InvokeServer()
	end)

	if ok and typeof(result) == "table" then
		for _, entry in result do
			statusCache[entry.id] = entry.unlocked
		end
	else
		warn("GateController: failed to fetch initial gate status", result)
	end

	for _, instance in CollectionService:GetTagged(GATE_TAG) do
		setupGate(instance, self._trove)
	end

	CollectionService:GetInstanceAddedSignal(GATE_TAG):Connect(function(instance)
		setupGate(instance, self._trove)
	end)
end

return GateController
