--!strict
-- Lightweight "world feels alive" layer: torch flicker, banner sway, and slow
-- continuous rotation (orbit rings, holographic glyphs, market display
-- plinths) on any tagged instance the world-build tools (or a builder by
-- hand) placed, plus plaza ambience audio. All motion is driven from a
-- single Heartbeat loop (not one per instance) and scaled by
-- QualityController so mobile doesn't pay for effects nobody can tell apart
-- from static at that resolution.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local QualityController = require(script.Parent.QualityController)

local FLICKER_LIGHT_TAG = "AmbientFlicker"
local SWAY_PART_TAG = "AmbientSway"
local SPIN_PART_TAG = "SlowSpin"
local FLOAT_PART_TAG = "AmbientFloat"
local PULSE_PART_TAG = "AmbientPulse" -- Portal Expedition Zone rework: restrained Transparency oscillation, e.g. the security barrier's warning stripes — deliberately NOT rotation/translation (see AmbientPulse's own note below)
local QUALITY_GATED_TAG = "QualityGatedEffect" -- Beams/other pricier effects; disabled once, at Start, on the Low tier
local DEFAULT_SPIN_SPEED = 15 -- degrees/second, used when a tagged part has no "Speed" attribute
local DEFAULT_FLOAT_AMPLITUDE = 0.6 -- studs, used when a tagged part has no "FloatAmplitude" attribute
local DEFAULT_FLOAT_SPEED = 1 -- radians/second, used when a tagged part has no "FloatSpeed" attribute
local DEFAULT_PULSE_SPEED = 1.5 -- radians/second, used when a tagged part has no "PulseSpeed" attribute
local DEFAULT_PULSE_AMPLITUDE = 0.15 -- max Transparency swing above the part's own base Transparency

local AmbientController = {}

type FlickerState = { light: PointLight | SpotLight | SurfaceLight, baseBrightness: number, seed: number }
type SwayState = { part: BasePart, baseCFrame: CFrame, seed: number }
-- PVInstance covers both BasePart and Model: GetPivot/PivotTo rotate a whole
-- multi-part Model (e.g. a segmented orbit ring) around its shared center,
-- not just a single part around its own — required for anything built from
-- more than one Part per Prompt 1/2's kitbash technique.
type SpinState = { instance: PVInstance, basePivot: CFrame, degreesPerSecond: number }
type FloatState = { instance: PVInstance, basePivot: CFrame, amplitude: number, speed: number, seed: number }
type PulseState = { part: BasePart, baseTransparency: number, amplitude: number, speed: number, seed: number }

local flickerStates: { FlickerState } = {}
local swayStates: { SwayState } = {}
local spinStates: { SpinState } = {}
local floatStates: { FloatState } = {}
local pulseStates: { PulseState } = {}

local function registerFlicker(instance: Instance)
	if instance:IsA("PointLight") or instance:IsA("SpotLight") or instance:IsA("SurfaceLight") then
		table.insert(flickerStates, {
			light = instance,
			baseBrightness = instance.Brightness,
			seed = math.random() * 1000,
		})
	end
end

local function registerSway(instance: Instance)
	if instance:IsA("BasePart") then
		table.insert(swayStates, {
			part = instance,
			baseCFrame = instance.CFrame,
			seed = math.random() * 1000,
		})
	end
end

local function registerSpin(instance: Instance)
	if instance:IsA("BasePart") or instance:IsA("Model") then
		table.insert(spinStates, {
			instance = instance,
			basePivot = instance:GetPivot(),
			degreesPerSecond = (instance:GetAttribute("Speed") :: number?) or DEFAULT_SPIN_SPEED,
		})
	end
end

-- Correction pass: previously nothing ever dropped an entry from spinStates,
-- so an instance kept spinning forever once tagged even after the tag was
-- removed or the instance destroyed (e.g. a rebuild replacing an old tagged
-- Core ring with a new untagged one). GetInstanceRemovedSignal fires both
-- when the tag is explicitly removed and when the tagged instance is
-- destroyed, so this correctly drops the stale entry either way.
local function unregisterSpin(instance: Instance)
	for i = #spinStates, 1, -1 do
		if spinStates[i].instance == instance then
			table.remove(spinStates, i)
		end
	end
end

local function registerFloat(instance: Instance)
	if instance:IsA("BasePart") or instance:IsA("Model") then
		table.insert(floatStates, {
			instance = instance,
			basePivot = instance:GetPivot(),
			amplitude = (instance:GetAttribute("FloatAmplitude") :: number?) or DEFAULT_FLOAT_AMPLITUDE,
			speed = (instance:GetAttribute("FloatSpeed") :: number?) or DEFAULT_FLOAT_SPEED,
			seed = math.random() * 1000,
		})
	end
end

-- Restrained Transparency oscillation — e.g. the Expedition security
-- barrier's warning stripes "moving" without any physical rotation or
-- translation (see the Portal Expedition Zone rework plan: the barrier's
-- silhouette must stay fixed in world space).
local function registerPulse(instance: Instance)
	if instance:IsA("BasePart") then
		table.insert(pulseStates, {
			part = instance,
			baseTransparency = instance.Transparency,
			amplitude = (instance:GetAttribute("PulseAmplitude") :: number?) or DEFAULT_PULSE_AMPLITUDE,
			speed = (instance:GetAttribute("PulseSpeed") :: number?) or DEFAULT_PULSE_SPEED,
			seed = math.random() * 1000,
		})
	end
end

local function playPlazaAmbience()
	local ambience = Instance.new("Sound")
	ambience.Name = "PlazaAmbience"
	ambience.SoundId = "" -- TODO: paste an uploaded ambience asset ID here (see BiomeConfig note on audio).
	ambience.Looped = true
	ambience.Volume = 0
	ambience.Parent = SoundService

	if ambience.SoundId ~= "" then
		ambience:Play()
		TweenService:Create(ambience, TweenInfo.new(3), { Volume = 0.35 }):Play()
	end
end

-- Beams and other pricier one-off effects don't need per-frame management —
-- just switched off once for the session on the Low tier, exactly like
-- GateController already does for gate activation particles. Deliberately
-- only ever called from Start(), never Init(): QualityController's own
-- Init() computes the real device tier, and Loader's Init/Start phases give
-- no ordering guarantee *among* different modules' Init() calls — only that
-- every Init() finishes before any Start() begins. Reading the tier here
-- during Init() could race and silently read stale "High" defaults.
local function applyQualityGate(instance: Instance)
	if QualityController.GetSettings().Tier ~= "Low" then
		return
	end
	if instance:IsA("Beam") or instance:IsA("ParticleEmitter") then
		instance.Enabled = false
	end
end

function AmbientController:Init()
	for _, instance in CollectionService:GetTagged(FLICKER_LIGHT_TAG) do
		registerFlicker(instance)
	end
	for _, instance in CollectionService:GetTagged(SWAY_PART_TAG) do
		registerSway(instance)
	end
	for _, instance in CollectionService:GetTagged(SPIN_PART_TAG) do
		registerSpin(instance)
	end
	for _, instance in CollectionService:GetTagged(FLOAT_PART_TAG) do
		registerFloat(instance)
	end
	for _, instance in CollectionService:GetTagged(PULSE_PART_TAG) do
		registerPulse(instance)
	end

	CollectionService:GetInstanceAddedSignal(FLICKER_LIGHT_TAG):Connect(registerFlicker)
	CollectionService:GetInstanceAddedSignal(SWAY_PART_TAG):Connect(registerSway)
	CollectionService:GetInstanceAddedSignal(SPIN_PART_TAG):Connect(registerSpin)
	CollectionService:GetInstanceRemovedSignal(SPIN_PART_TAG):Connect(unregisterSpin)
	CollectionService:GetInstanceAddedSignal(FLOAT_PART_TAG):Connect(registerFloat)
	CollectionService:GetInstanceAddedSignal(PULSE_PART_TAG):Connect(registerPulse)
	CollectionService:GetInstanceAddedSignal(QUALITY_GATED_TAG):Connect(applyQualityGate)
end

function AmbientController:Start()
	for _, instance in CollectionService:GetTagged(QUALITY_GATED_TAG) do
		applyQualityGate(instance)
	end

	playPlazaAmbience()

	RunService.Heartbeat:Connect(function()
		local quality = QualityController.GetSettings()
		local now = os.clock()

		for _, state in flickerStates do
			local noise = math.noise(now * 3 + state.seed, 0, 0)
			state.light.Brightness = state.baseBrightness * (0.85 + noise * 0.3 * quality.ParticleScale)
		end

		if quality.Tier == "High" then
			for _, state in swayStates do
				local angle = math.sin(now * 0.6 + state.seed) * 2
				state.part.CFrame = state.baseCFrame * CFrame.Angles(0, 0, math.rad(angle))
			end
		end

		for _, state in spinStates do
			state.instance:PivotTo(state.basePivot * CFrame.Angles(0, math.rad(state.degreesPerSecond * now), 0))
		end

		for _, state in floatStates do
			local bob = math.sin(now * state.speed + state.seed) * state.amplitude
			state.instance:PivotTo(state.basePivot * CFrame.new(0, bob, 0))
		end

		for _, state in pulseStates do
			local wave = (math.sin(now * state.speed + state.seed) + 1) / 2 -- 0..1
			state.part.Transparency = math.clamp(state.baseTransparency + wave * state.amplitude, 0, 1)
		end
	end)
end

return AmbientController
