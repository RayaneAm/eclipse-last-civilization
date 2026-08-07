--!strict
-- Owns global mood: Lighting/Atmosphere/post-processing. Presets are data, not
-- one-off property soup, so a future Eclipse Event system can call
-- EnvironmentService:ApplyPreset("EclipseEvent") to darken the sky and swap
-- the whole look in one call instead of duplicating tuning logic.

local Lighting = game:GetService("Lighting")

export type Preset = {
	ClockTime: number,
	Brightness: number,
	Ambient: Color3,
	OutdoorAmbient: Color3,
	ExposureCompensation: number,
	ColorCorrection: { Brightness: number, Contrast: number, Saturation: number, TintColor: Color3 },
	Atmosphere: { Density: number, Offset: number, Color: Color3, Decay: Color3, Glare: number, Haze: number },
	Bloom: { Intensity: number, Size: number, Threshold: number },
	DepthOfField: { FarIntensity: number, FocusDistance: number, InFocusRadius: number, NearIntensity: number },
	SunRays: { Intensity: number, Spread: number },
}

local Presets: { [string]: Preset } = {
	-- Cinematic, hopeful post-apocalypse: warm key light, cool falloff, gentle haze
	-- for depth. Deliberately NOT dark-horror per the user's brief.
	--
	-- Prompt 3 art-pass tuning: bloom pulled back and its threshold raised so
	-- it catches genuinely emissive surfaces (Neon, the Eclipse Core) instead
	-- of glowing the whole scene; haze trimmed slightly now that Prompt 2's
	-- real terrain is visible beyond every gate and shouldn't be hidden in
	-- fog; a restrained SunRaysEffect added for the Core's light-shaft
	-- synergy.
	Default = {
		ClockTime = 16.5,
		Brightness = 2.5,
		Ambient = Color3.fromRGB(74, 82, 96),
		OutdoorAmbient = Color3.fromRGB(120, 128, 140),
		ExposureCompensation = 0.15,
		ColorCorrection = { Brightness = 0.02, Contrast = 0.1, Saturation = 0.05, TintColor = Color3.fromRGB(255, 246, 235) },
		Atmosphere = { Density = 0.3, Offset = 0.25, Color = Color3.fromRGB(199, 202, 209), Decay = Color3.fromRGB(92, 100, 120), Glare = 0.2, Haze = 1.05 },
		Bloom = { Intensity = 0.5, Size = 24, Threshold = 1.85 },
		DepthOfField = { FarIntensity = 0.25, FocusDistance = 40, InFocusRadius = 20, NearIntensity = 0 },
		SunRays = { Intensity = 0.08, Spread = 0.5 },
	},
}

local EnvironmentService = {}

local function getOrCreate<T>(className: string, name: string): T
	local existing = Lighting:FindFirstChild(name)
	if existing then
		return existing :: any
	end
	local instance = Instance.new(className :: any)
	instance.Name = name
	instance.Parent = Lighting
	return instance :: any
end

function EnvironmentService:ApplyPreset(presetName: string)
	local preset = Presets[presetName]
	if not preset then
		warn(`EnvironmentService: unknown preset "{presetName}"`)
		return
	end

	Lighting.ClockTime = preset.ClockTime
	Lighting.Brightness = preset.Brightness
	Lighting.Ambient = preset.Ambient
	Lighting.OutdoorAmbient = preset.OutdoorAmbient
	Lighting.ExposureCompensation = preset.ExposureCompensation
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.2
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1

	local colorCorrection = getOrCreate("ColorCorrectionEffect", "Eclipse_ColorCorrection") :: ColorCorrectionEffect
	colorCorrection.Brightness = preset.ColorCorrection.Brightness
	colorCorrection.Contrast = preset.ColorCorrection.Contrast
	colorCorrection.Saturation = preset.ColorCorrection.Saturation
	colorCorrection.TintColor = preset.ColorCorrection.TintColor

	local atmosphere = getOrCreate("Atmosphere", "Eclipse_Atmosphere") :: Atmosphere
	atmosphere.Density = preset.Atmosphere.Density
	atmosphere.Offset = preset.Atmosphere.Offset
	atmosphere.Color = preset.Atmosphere.Color
	atmosphere.Decay = preset.Atmosphere.Decay
	atmosphere.Glare = preset.Atmosphere.Glare
	atmosphere.Haze = preset.Atmosphere.Haze

	local bloom = getOrCreate("BloomEffect", "Eclipse_Bloom") :: BloomEffect
	bloom.Intensity = preset.Bloom.Intensity
	bloom.Size = preset.Bloom.Size
	bloom.Threshold = preset.Bloom.Threshold

	local depthOfField = getOrCreate("DepthOfFieldEffect", "Eclipse_DepthOfField") :: DepthOfFieldEffect
	depthOfField.FarIntensity = preset.DepthOfField.FarIntensity
	depthOfField.FocusDistance = preset.DepthOfField.FocusDistance
	depthOfField.InFocusRadius = preset.DepthOfField.InFocusRadius
	depthOfField.NearIntensity = preset.DepthOfField.NearIntensity

	local sunRays = getOrCreate("SunRaysEffect", "Eclipse_SunRays") :: SunRaysEffect
	sunRays.Intensity = preset.SunRays.Intensity
	sunRays.Spread = preset.SunRays.Spread
end

function EnvironmentService:Init()
	self:ApplyPreset("Default")
end

return EnvironmentService
