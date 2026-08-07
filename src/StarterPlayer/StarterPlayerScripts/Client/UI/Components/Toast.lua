--!strict
-- Small stacking notification card (icon + text) on the shared dark-glass
-- panel language. Pure constructor — NotificationController owns the actual
-- stack, timers, and destruction; this only builds the visual, wrapped in a
-- CanvasGroup so the whole card fades as one unit via Motion.FadeIn/FadeOut.

local Theme = require(script.Parent.Parent.Theme)
local Shadow = require(script.Parent.Parent.Shadow)

local Toast = {}

export type ToastOptions = {
	Icon: string,
	Text: string,
	AccentColor: Color3?,
	LayoutOrder: number?,
	Parent: Instance?,
}

-- Returns (wrapper, scale) so the caller drives entrance/exit tweens (fade on
-- `wrapper`, pop-in on `scale`) and eventual :Destroy() itself.
function Toast.new(options: ToastOptions): (CanvasGroup, UIScale)
	local accentColor = options.AccentColor or Theme.Colors.Brand

	local wrapper = Instance.new("CanvasGroup")
	wrapper.Name = "Toast"
	-- 4px taller than the panel below (48 vs the panel's effective 44) so the
	-- panel's drop shadow has slack to render in — a CanvasGroup clips to its
	-- own bounds like ClipsDescendants=true, so an exact fromScale(1,1) fit
	-- would slice the shadow's offset bottom edge off.
	wrapper.Size = UDim2.new(1, 0, 0, 48)
	wrapper.BackgroundTransparency = 1
	wrapper.GroupTransparency = 1
	wrapper.LayoutOrder = options.LayoutOrder or 0

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
	corner.CornerRadius = Theme.Corner.Medium
	corner.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Color = accentColor
	stroke.Thickness = 1.5
	stroke.Transparency = Theme.Transparency.StrokeDefault
	stroke.Parent = panel

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, Theme.Spacing.S)
	padding.PaddingRight = UDim.new(0, Theme.Spacing.S)
	padding.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, Theme.Spacing.S)
	layout.Parent = panel

	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.Size = UDim2.fromOffset(24, 24)
	icon.LayoutOrder = 1
	icon.BackgroundTransparency = 1
	icon.Font = Theme.Font.Heading.Font
	icon.TextSize = 18
	icon.TextColor3 = accentColor
	icon.TextStrokeColor3 = Color3.new(0, 0, 0)
	icon.TextStrokeTransparency = 0.6
	icon.Text = options.Icon
	icon.Parent = panel

	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.Size = UDim2.new(1, -32, 1, 0)
	text.LayoutOrder = 2
	text.BackgroundTransparency = 1
	text.Font = Theme.Font.Label.Font
	text.TextSize = Theme.Font.Label.Size
	text.TextColor3 = Theme.Colors.TextPrimary
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextWrapped = true
	text.Text = options.Text
	text.Parent = panel

	wrapper.Parent = options.Parent

	Shadow.Attach(panel)

	return wrapper, scale
end

return Toast
