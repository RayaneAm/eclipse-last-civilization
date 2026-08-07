--!strict
-- Small fade in/out region-name toast ("ENTERING: FROZEN WASTELAND"),
-- driven by the server's RegionService. Deliberately a simpler, separate UI
-- from CameraIntroController's full letterboxed cinematic intro — the two
-- are different enough moments (one-time spawn cinematic vs. a recurring
-- travel cue) that sharing a UI module would be a forced abstraction.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local BiomeConfig = require(ReplicatedStorage.Shared.Config.BiomeConfig)

local HAVEN_NAME = "Survivor Haven"
local HAVEN_DESCRIPTION = "You've returned to safety."
local HAVEN_ACCENT_COLOR = Color3.fromRGB(150, 150, 255)
local VISIBLE_DURATION = 3.5

local player = Players.LocalPlayer

local RegionAnnounceController = {}

local biomeById: { [string]: BiomeConfig.BiomeDefinition } = {}
for _, biome in BiomeConfig do
	biomeById[biome.id] = biome
end

local function buildToast(): (TextLabel, TextLabel)
	local gui = Instance.new("ScreenGui")
	gui.Name = "RegionAnnounce"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 50

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 50)
	title.Position = UDim2.new(0, 0, 0.14, 0)
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 34
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextTransparency = 1
	title.Text = ""
	title.Parent = gui

	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.BackgroundTransparency = 1
	subtitle.Size = UDim2.new(1, 0, 0, 24)
	subtitle.Position = UDim2.new(0, 0, 0.14, 46)
	subtitle.Font = Enum.Font.Gotham
	subtitle.TextSize = 16
	subtitle.TextColor3 = Color3.fromRGB(220, 220, 220)
	subtitle.TextTransparency = 1
	subtitle.Text = ""
	subtitle.Parent = gui

	gui.Parent = player:WaitForChild("PlayerGui")
	return title, subtitle
end

function RegionAnnounceController:Init()
	self._title, self._subtitle = buildToast()
	self._activeToken = 0
end

function RegionAnnounceController:Start()
	Net.GetEvent("RegionChanged").OnClientEvent:Connect(function(regionId: string?)
		self:Announce(regionId)
	end)
end

function RegionAnnounceController:Announce(regionId: string?)
	local name, description, accentColor

	if regionId then
		local biome = biomeById[regionId]
		if not biome then
			warn(`RegionAnnounceController: unknown region id "{regionId}"`)
			return
		end
		name, description, accentColor = biome.name, biome.description, biome.gate.accentColor
	else
		name, description, accentColor = HAVEN_NAME, HAVEN_DESCRIPTION, HAVEN_ACCENT_COLOR
	end

	self._activeToken += 1
	local token = self._activeToken

	self._title.Text = `ENTERING: {string.upper(name)}`
	self._title.TextColor3 = accentColor
	self._subtitle.Text = description

	TweenService:Create(self._title, TweenInfo.new(0.6), { TextTransparency = 0 }):Play()
	TweenService:Create(self._subtitle, TweenInfo.new(0.6), { TextTransparency = 0.15 }):Play()

	task.delay(VISIBLE_DURATION, function()
		if token ~= self._activeToken then
			return -- a newer announcement has already superseded this one
		end
		TweenService:Create(self._title, TweenInfo.new(0.8), { TextTransparency = 1 }):Play()
		TweenService:Create(self._subtitle, TweenInfo.new(0.8), { TextTransparency = 1 }):Play()
	end)
end

return RegionAnnounceController
