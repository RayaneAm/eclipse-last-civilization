--!strict
-- Fade-to-black transition overlay for portal travel (Prompt 2) — shared by
-- every biome gate and the Tutorial Portal alike, so this lives on its own
-- rather than inside GateController (which isn't biome-specific travel, it's
-- gate-specific interaction). Purely reactive to the server's
-- PortalTransitionBegin/End events; PortalService alone decides when a
-- transition starts and ends, this never guesses.
--
-- One persistent overlay, reused across every transition (transitions are
-- frequent enough that build/destroy-per-use would be wasteful) — but
-- explicitly sets Visible = false whenever hidden, not just transparency,
-- learned from the stuck-Banner playtest fix: a transparency-only hide left
-- a persistent instance with no guaranteed-safe rest state.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)

local Theme = require(script.Parent.Parent.UI.Theme)
local Motion = require(script.Parent.Parent.UI.Motion)

local PortalTransitionController = {}

function PortalTransitionController:Init()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "PortalTransition"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 100 -- above every other UI while a transition is active
	screenGui.Parent = playerGui

	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 1
	overlay.Visible = false
	overlay.Parent = screenGui
	self._overlay = overlay

	local loadingLabel = Instance.new("TextLabel")
	loadingLabel.Name = "LoadingText"
	loadingLabel.BackgroundTransparency = 1
	loadingLabel.Size = UDim2.new(1, 0, 0, 32)
	loadingLabel.Position = UDim2.new(0, 0, 0.46, 0)
	loadingLabel.Font = Theme.Font.Heading.Font
	loadingLabel.TextSize = Theme.Font.Heading.Size
	loadingLabel.TextColor3 = Theme.Colors.TextPrimary
	loadingLabel.TextTransparency = 1
	loadingLabel.Text = ""
	loadingLabel.Parent = overlay
	self._loadingLabel = loadingLabel
end

function PortalTransitionController:BeginTransition(loadingText: string?)
	self._overlay.Visible = true
	self._loadingLabel.Text = loadingText or ""
	Motion.Tween(self._overlay, "Fade", Theme.Motion.PanelOpen, { BackgroundTransparency = 0 })
	Motion.Tween(self._loadingLabel, "Fade", Theme.Motion.PanelOpen, { TextTransparency = 0.15 })
end

function PortalTransitionController:EndTransition()
	Motion.Tween(self._loadingLabel, "Fade", Theme.Motion.PanelClose, { TextTransparency = 1 })
	local tween = Motion.Tween(self._overlay, "Fade", Theme.Motion.PanelClose, { BackgroundTransparency = 1 })
	tween.Completed:Once(function()
		self._overlay.Visible = false
	end)
end

function PortalTransitionController:Start()
	Net.GetEvent("PortalTransitionBegin").OnClientEvent:Connect(function(loadingText: string?)
		self:BeginTransition(loadingText)
	end)
	Net.GetEvent("PortalTransitionEnd").OnClientEvent:Connect(function()
		self:EndTransition()
	end)
end

return PortalTransitionController
