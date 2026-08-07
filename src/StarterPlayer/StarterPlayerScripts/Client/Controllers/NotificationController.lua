--!strict
-- Reusable two-tier notification system: small stacking Toasts for minor
-- feedback (resource collected, item crafted/equipped, objective advanced,
-- XP gained) and a bigger, centered, one-at-a-time Banner for major beats
-- (quest completed, level up, biome unlocked). Every other controller that
-- wants to notify the player calls NotificationController.Toast/.Banner —
-- this is the single place that owns notification presentation.

local Players = game:GetService("Players")

local Theme = require(script.Parent.Parent.UI.Theme)
local Motion = require(script.Parent.Parent.UI.Motion)
local Toast = require(script.Parent.Parent.UI.Components.Toast)
local Banner = require(script.Parent.Parent.UI.Components.Banner)

local NotificationController = {}

export type NotificationKind =
	"ResourceCollected"
	| "ItemCrafted"
	| "ItemEquipped"
	| "ObjectiveAdvanced"
	| "XPGained"
	| "QuestCompleted"
	| "LevelUp"
	| "BiomeUnlocked"
	| "DailyRewardClaimed"
	-- Phase 4A.1: one clean player-facing message for base building/blueprint
	-- validation results, replacing a bare console warn() for expected
	-- rejection reasons (OutOfBounds, Overlap, etc.).
	| "BuildRejected"
	| "BuildConfirmed"

export type NotificationOverrides = { Icon: string?, AccentColor: Color3? }

local KIND_DEFAULTS: { [NotificationKind]: { Icon: string, AccentColor: Color3 } } = {
	ResourceCollected = { Icon = "◆", AccentColor = Theme.Colors.Success },
	ItemCrafted = { Icon = "🔨", AccentColor = Theme.Colors.Brand },
	ItemEquipped = { Icon = "✓", AccentColor = Theme.Colors.BrandLight },
	ObjectiveAdvanced = { Icon = "☑", AccentColor = Theme.Colors.Success },
	XPGained = { Icon = "✦", AccentColor = Theme.Colors.BrandLight },
	QuestCompleted = { Icon = "🏆", AccentColor = Theme.Colors.Success },
	LevelUp = { Icon = "▲", AccentColor = Theme.Colors.BrandLight },
	BiomeUnlocked = { Icon = "🌲", AccentColor = Theme.Colors.Success },
	DailyRewardClaimed = { Icon = "🎁", AccentColor = Theme.Colors.Success },
	BuildRejected = { Icon = "🚧", AccentColor = Theme.Colors.Danger },
	BuildConfirmed = { Icon = "🏗", AccentColor = Theme.Colors.Success },
}

local TOAST_VISIBLE_SECONDS = 2.6
local MAX_VISIBLE_TOASTS = 4 -- anti-spam cap: "do not overuse effects"
local BANNER_VISIBLE_SECONDS = 3.2

local notificationsScreenGui: ScreenGui
local toastStack: Frame

type BannerRequest = { Kind: NotificationKind, Title: string, Subtitle: string?, Overrides: NotificationOverrides? }
local bannerQueue: { BannerRequest } = {}
local bannerShowing = false
local nextToastOrder = 0

local function resolve(kind: NotificationKind, overrides: NotificationOverrides?): (string, Color3)
	local default = KIND_DEFAULTS[kind]
	local icon = (overrides and overrides.Icon) or default.Icon
	local accentColor = (overrides and overrides.AccentColor) or default.AccentColor
	return icon, accentColor
end

function NotificationController.Toast(kind: NotificationKind, text: string, overrides: NotificationOverrides?)
	local icon, accentColor = resolve(kind, overrides)

	-- Force-dismiss the oldest visible toast before exceeding the cap.
	local toastCount = 0
	local oldest: CanvasGroup? = nil
	for _, child in toastStack:GetChildren() do
		if child:IsA("CanvasGroup") then
			toastCount += 1
			if not oldest or child.LayoutOrder < oldest.LayoutOrder then
				oldest = child :: CanvasGroup
			end
		end
	end
	if toastCount >= MAX_VISIBLE_TOASTS and oldest then
		oldest:Destroy()
	end

	nextToastOrder += 1
	local wrapper, scale = Toast.new({
		Icon = icon,
		Text = text,
		AccentColor = accentColor,
		LayoutOrder = nextToastOrder,
		Parent = toastStack,
	})

	Motion.FadeIn(wrapper, Theme.Motion.PanelOpen.Time)
	Motion.Tween(scale, "Pop", Theme.Motion.PanelOpen, { Scale = 1 })

	task.delay(TOAST_VISIBLE_SECONDS, function()
		if wrapper.Parent then
			Motion.FadeOut(wrapper, Theme.Motion.PanelClose.Time, function()
				wrapper:Destroy()
			end)
		end
	end)
end

local function showNextBanner()
	if bannerShowing or #bannerQueue == 0 then
		return
	end
	bannerShowing = true

	local request = table.remove(bannerQueue, 1) :: BannerRequest
	local icon, accentColor = resolve(request.Kind, request.Overrides)

	-- Fresh instance per showing, fully destroyed after fade-out (see
	-- Banner.luau's own header comment) — same idiom as this file's Toast,
	-- chosen so there's never a persistent instance that could linger on
	-- screen with stale visible state.
	local bannerWrapper, bannerScale, bannerLabels = Banner.new({ Parent = notificationsScreenGui })

	bannerLabels.Icon.Text = icon
	bannerLabels.Title.Text = request.Title
	bannerLabels.Subtitle.Text = request.Subtitle or ""
	bannerLabels.Stroke.Color = accentColor
	bannerLabels.IconStroke.Color = accentColor
	bannerLabels.IconGradient.Color = ColorSequence.new(Color3.new(1, 1, 1), accentColor)

	Motion.FadeIn(bannerWrapper, Theme.Motion.PanelOpen.Time)
	-- Celebration pop: chained Quad/Out overshoot, never a new easing style.
	Motion.Tween(bannerScale, "Pop", TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.06 })
	task.delay(0.18, function()
		Motion.Tween(bannerScale, "Pop", TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 })
	end)

	task.delay(BANNER_VISIBLE_SECONDS, function()
		Motion.FadeOut(bannerWrapper, Theme.Motion.PanelClose.Time, function()
			bannerWrapper:Destroy()
			bannerShowing = false
			showNextBanner()
		end)
	end)
end

function NotificationController.Banner(kind: NotificationKind, title: string, subtitle: string?, overrides: NotificationOverrides?)
	table.insert(bannerQueue, { Kind = kind, Title = title, Subtitle = subtitle, Overrides = overrides })
	showNextBanner()
end

function NotificationController:Init()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	notificationsScreenGui = Instance.new("ScreenGui")
	notificationsScreenGui.Name = "Notifications"
	notificationsScreenGui.ResetOnSpawn = false
	notificationsScreenGui.IgnoreGuiInset = false
	notificationsScreenGui.DisplayOrder = 60
	notificationsScreenGui.Parent = playerGui

	toastStack = Instance.new("Frame")
	toastStack.Name = "ToastStack"
	toastStack.AnchorPoint = Vector2.new(1, 0)
	toastStack.Position = UDim2.new(1, -Theme.Spacing.L, 0, Theme.Spacing.L)
	toastStack.Size = UDim2.fromOffset(300, 0)
	toastStack.AutomaticSize = Enum.AutomaticSize.Y
	toastStack.BackgroundTransparency = 1
	toastStack.Parent = notificationsScreenGui

	local toastLayout = Instance.new("UIListLayout")
	toastLayout.SortOrder = Enum.SortOrder.LayoutOrder
	toastLayout.Padding = UDim.new(0, Theme.Spacing.S)
	toastLayout.Parent = toastStack
end

return NotificationController
