--!strict
-- Big, centered, one-at-a-time announcement for major beats (quest complete,
-- level up, biome unlocked). NotificationController builds a fresh instance
-- per showing and fully destroys it after fade-out — same idiom as this
-- file's own Toast.luau and Components/SpawnBriefingCard.luau, chosen so
-- there's never a persistent instance that could linger on screen with
-- stale visible state.

local Theme = require(script.Parent.Parent.Theme)
local Motion = require(script.Parent.Parent.Motion)
local Shadow = require(script.Parent.Parent.Shadow)

local Banner = {}

export type BannerOptions = { Parent: Instance }
export type BannerLabels = {
	Icon: TextLabel,
	Title: TextLabel,
	Subtitle: TextLabel,
	Stroke: UIStroke,
	IconStroke: UIStroke,
	IconGradient: UIGradient,
}

local ICON_TILE_SIZE = 56
local TEXT_OFFSET = ICON_TILE_SIZE + Theme.Spacing.L -- 72

-- Returns (wrapper, scale, labels) — NotificationController drives
-- fade/pop tweens on wrapper/scale and writes into `labels` per announcement.
function Banner.new(options: BannerOptions): (CanvasGroup, UIScale, BannerLabels)
	local wrapper = Instance.new("CanvasGroup")
	wrapper.Name = "Banner"
	-- 4px taller than the panel below so the panel's drop shadow has slack to
	-- render in — see Toast.luau's identical comment for why (CanvasGroup
	-- clips to its own bounds like ClipsDescendants=true).
	wrapper.Size = UDim2.fromOffset(440, 120)
	wrapper.AnchorPoint = Vector2.new(0.5, 0)
	wrapper.Position = UDim2.new(0.5, 0, 0.16, 0)
	wrapper.BackgroundTransparency = 1
	wrapper.GroupTransparency = 1
	wrapper.Parent = options.Parent

	local scale = Instance.new("UIScale")
	scale.Name = "Scale"
	scale.Scale = 0.94
	scale.Parent = wrapper

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.new(1, 0, 1, -4)
	panel.BackgroundColor3 = Theme.Colors.PanelBackground
	panel.BackgroundTransparency = Theme.Transparency.PanelBackground
	panel.BorderSizePixel = 0
	panel.Parent = wrapper

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.Corner.Large
	corner.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Name = "Stroke"
	stroke.Color = Theme.Colors.Brand
	stroke.Thickness = 1.5
	stroke.Transparency = Theme.Transparency.StrokeDefault
	stroke.Parent = panel

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Theme.Colors.Brand)
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, Theme.Transparency.GradientNear),
		NumberSequenceKeypoint.new(1, Theme.Transparency.GradientFar),
	})
	gradient.Rotation = 90
	gradient.Parent = panel

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, Theme.Spacing.L)
	padding.PaddingRight = UDim.new(0, Theme.Spacing.L)
	padding.Parent = panel

	local iconTile = Instance.new("Frame")
	iconTile.Name = "IconTile"
	iconTile.Size = UDim2.fromOffset(ICON_TILE_SIZE, ICON_TILE_SIZE)
	iconTile.AnchorPoint = Vector2.new(0, 0.5)
	iconTile.Position = UDim2.new(0, 0, 0.5, 0)
	iconTile.BackgroundColor3 = Theme.Colors.PanelBackground
	iconTile.BackgroundTransparency = Theme.Transparency.PanelBackground
	iconTile.BorderSizePixel = 0
	iconTile.Parent = panel

	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = Theme.Corner.Pill
	iconCorner.Parent = iconTile

	-- Both get retinted per-notification-kind by NotificationController via
	-- the labels below.
	local iconStroke = Instance.new("UIStroke")
	iconStroke.Name = "Stroke"
	iconStroke.Color = Theme.Colors.Brand
	iconStroke.Thickness = 1.5
	iconStroke.Transparency = Theme.Transparency.StrokeBright
	iconStroke.Parent = iconTile

	local iconGradient = Instance.new("UIGradient")
	iconGradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Theme.Colors.Brand)
	iconGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, Theme.Transparency.GradientNear),
		NumberSequenceKeypoint.new(1, Theme.Transparency.GradientFar),
	})
	iconGradient.Rotation = 90
	iconGradient.Parent = iconTile

	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.Size = UDim2.fromScale(1, 1)
	icon.BackgroundTransparency = 1
	icon.Font = Theme.Font.Title.Font
	icon.TextSize = 28
	icon.TextColor3 = Theme.Colors.TextPrimary
	icon.TextStrokeColor3 = Color3.new(0, 0, 0)
	icon.TextStrokeTransparency = 0.6
	icon.Text = ""
	icon.Parent = iconTile

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -TEXT_OFFSET, 0, 30)
	title.Position = UDim2.new(0, TEXT_OFFSET, 0.5, -26)
	title.BackgroundTransparency = 1
	title.Font = Theme.Font.Title.Font
	title.TextSize = Theme.Font.Title.Size
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Theme.Colors.TextPrimary
	title.Text = ""
	title.Parent = panel

	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.Size = UDim2.new(1, -TEXT_OFFSET, 0, 20)
	subtitle.Position = UDim2.new(0, TEXT_OFFSET, 0.5, 4)
	subtitle.BackgroundTransparency = 1
	subtitle.Font = Theme.Font.Body.Font
	subtitle.TextSize = Theme.Font.Body.Size
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	subtitle.TextColor3 = Theme.Colors.TextSecondary
	subtitle.TextWrapped = true
	subtitle.Text = ""
	subtitle.Parent = panel

	Shadow.Attach(panel)

	-- Continuous ambient glow — always on for Banner (rare, high-value
	-- moments), unlike IconTile/ItemCell where pulsing is opt-in only.
	Motion.Tween(iconStroke, "Pulse", Theme.Motion.Pulse, { Transparency = Theme.Transparency.StrokeDefault })

	return wrapper, scale, { Icon = icon, Title = title, Subtitle = subtitle, Stroke = stroke, IconStroke = iconStroke, IconGradient = iconGradient }
end

return Banner
