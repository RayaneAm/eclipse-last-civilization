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
	-- Dark, readable post-apocalypse: cool exterior fill with warm practical
	-- Haven lighting. This remains evening rather than full nighttime.
	--
	Default = {
		-- Readable evening pass: darker outdoors, with enough indirect fill
		-- that paths and player silhouettes remain navigable on mobile.
		--
		-- Readable evening: the sun is below the horizon, while controlled
		-- blue-gray fill keeps characters, paths, entrances and walls legible.
		-- This gives Haven's warm practical lights real contrast without
		-- turning the hub into black nighttime.
		ClockTime = 18.75,
		Brightness = 2.15,
		Ambient = Color3.fromRGB(86, 92, 108),
		OutdoorAmbient = Color3.fromRGB(112, 121, 138),
		ExposureCompensation = 0.06,
		-- Contrast pulled back further (0.07 -> 0.03) since positive contrast
		-- crushes exactly the shadow detail the ambient lift is buying, and
		-- Saturation flipped positive with a warm tint to carry the "cozy"
		-- half of the brief.
		ColorCorrection = {
			Brightness = 0.015,
			Contrast = 0.02,
			Saturation = -0.01,
			TintColor = Color3.fromRGB(230, 234, 242),
		},
		-- Density/Haze trimmed: at 0.28/0.9 the atmosphere was itself a large
		-- part of the murk, greying out mid-distance geometry before the eye
		-- ever reached it. Color/Decay warmed to match the new sun angle.
		Atmosphere = {
			Density = 0.14,
			Offset = 0.25,
			Color = Color3.fromRGB(157, 170, 190),
			Decay = Color3.fromRGB(82, 89, 104),
			Glare = 0.02,
			Haze = 0.42,
		},
		-- Bloom trimmed again and its threshold raised: with ambient this
		-- much higher, the old 0.12/2.6 caught ordinary lit concrete, not
		-- just the emissives it is meant for. Larger Size keeps the halo soft
		-- and wide (reads as glow) rather than tight and hot (reads as blown).
		Bloom = { Intensity = 0.08, Size = 20, Threshold = 2.9 },
		DepthOfField = { FarIntensity = 0.06, FocusDistance = 55, InFocusRadius = 35, NearIntensity = 0 },
		SunRays = { Intensity = 0.05, Spread = 0.5 },
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
	-- Softened 0.2 -> 0.55: hard-edged shadows at this sun angle cut the
	-- plaza into sharp black wedges, which is the opposite of cozy.
	Lighting.ShadowSoftness = 0.55
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
