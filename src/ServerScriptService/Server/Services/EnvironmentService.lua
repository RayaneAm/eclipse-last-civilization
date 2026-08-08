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
	-- Superseded by the "cozy dusk" pass documented on Default below: the
	-- earlier tuning kept trying to fix blown-out emissives with global
	-- exposure/bloom, which only ever made the unlit 90% of the world darker.
	-- Emissive brightness is now handled per-part in the generators, leaving
	-- this file free to light the world properly.
	Default = {
		-- "Cozy dusk" pass. The previous tuning was legitimately dark but
		-- unreadable: anything more than a lamp's radius away fell to near
		-- black, so the world read as an unlit void with a few blown-out
		-- neon props floating in it.
		--
		-- The fix is deliberately split across two levers, because they do
		-- different jobs:
		--   * AMBIENT (here) is raised hard. Ambient/OutdoorAmbient light
		--     surfaces only — they do NOT brighten Neon/ForceField parts,
		--     which always render at full color regardless of Lighting. So
		--     raising ambient closes the gap between "lit prop" and "black
		--     nothing" WITHOUT making the already-too-bright emissives worse.
		--   * EXPOSURE stays near neutral. Raising it would scale emissives
		--     up too and undo the emissive trims done in the generators.
		-- Anything still too bright after this is fixed at the source (a
		-- darker Neon Color / higher Transparency on that part), never by
		-- pulling global exposure back down again.
		--
		-- ClockTime nudged 18.2 -> 17.9 so the sun sits just on the horizon:
		-- keeps a warm sunset band in the sky (the "cozy" half) instead of
		-- the flat gray dome of full civil twilight, without turning it into
		-- daytime.
		ClockTime = 17.75,
		Brightness = 2.6,
		-- The single biggest readability lever: shadow-side fill. Warm-neutral
		-- rather than the old cold blue-gray so unlit geometry reads as
		-- "evening indoors" instead of "moonlit ruin".
		Ambient = Color3.fromRGB(100, 106, 118),
		OutdoorAmbient = Color3.fromRGB(138, 148, 162),
		ExposureCompensation = 0.12,
		-- Contrast pulled back further (0.07 -> 0.03) since positive contrast
		-- crushes exactly the shadow detail the ambient lift is buying, and
		-- Saturation flipped positive with a warm tint to carry the "cozy"
		-- half of the brief.
		ColorCorrection = {
			Brightness = 0.04,
			Contrast = 0,
			Saturation = 0.01,
			TintColor = Color3.fromRGB(241, 238, 230),
		},
		-- Density/Haze trimmed: at 0.28/0.9 the atmosphere was itself a large
		-- part of the murk, greying out mid-distance geometry before the eye
		-- ever reached it. Color/Decay warmed to match the new sun angle.
		Atmosphere = {
			Density = 0.14,
			Offset = 0.25,
			Color = Color3.fromRGB(190, 198, 208),
			Decay = Color3.fromRGB(104, 111, 126),
			Glare = 0.04,
			Haze = 0.4,
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
