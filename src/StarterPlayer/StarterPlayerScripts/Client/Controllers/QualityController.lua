--!strict
-- Detects touch-only (mobile) and console devices and exposes a single shared
-- quality tier other controllers scale their particle counts / shadows /
-- light counts against. Computed once at boot — cheap, and device class
-- doesn't change mid-session.

local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

export type QualitySettings = {
	Tier: "High" | "Low",
	ParticleScale: number,
	ShadowsEnabled: boolean,
	MaxDynamicLights: number,
}

local QualityController = {}

local settings: QualitySettings = {
	Tier = "High",
	ParticleScale = 1,
	ShadowsEnabled = true,
	MaxDynamicLights = 12,
}

function QualityController:Init()
	local isTouchOnly = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
	local isConsole = GuiService:IsTenFootInterface()

	if isTouchOnly or isConsole then
		settings.Tier = "Low"
		settings.ParticleScale = 0.35
		settings.ShadowsEnabled = false
		settings.MaxDynamicLights = 4
	end
end

function QualityController.GetSettings(): QualitySettings
	return settings
end

return QualityController
