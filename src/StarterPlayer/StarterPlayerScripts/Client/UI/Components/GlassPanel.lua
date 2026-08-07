--!strict
-- The base dark-glass panel every screen-space UI surface in this system
-- builds on: black background @ Theme.Transparency.PanelBackground, a
-- context-accent-colored UIStroke, rounded UICorner, and a diagonal
-- white->accent UIGradient wash — directly generalizing GateController's
-- just-established hologram panel look into one reusable constructor.

local Theme = require(script.Parent.Parent.Theme)
local Shadow = require(script.Parent.Parent.Shadow)

local GlassPanel = {}

export type GlassPanelOptions = {
	Name: string?,
	Size: UDim2,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	AccentColor: Color3?,
	CornerRadius: UDim?,
	BackgroundTransparency: number?,
	Gradient: boolean?,
	-- Phase 4A.1 correction: every inner card nested inside another panel
	-- used to get its own full UIStroke, stacking into "border inside
	-- border." Default true (every existing call site keeps its current
	-- look) — pass false for a flat, borderless surface, which nested rows/
	-- cards should always do (see the Phase 4A.1 plan's "one strong main
	-- panel per screen" rule).
	Stroke: boolean?,
	DropShadow: boolean?,
	AutomaticSize: Enum.AutomaticSize?,
	LayoutOrder: number?,
	Parent: Instance?,
}

function GlassPanel.new(options: GlassPanelOptions): Frame
	local accentColor = options.AccentColor or Theme.Colors.Brand

	local panel = Instance.new("Frame")
	panel.Name = options.Name or "GlassPanel"
	panel.Size = options.Size
	panel.Position = options.Position or UDim2.fromScale(0, 0)
	panel.AnchorPoint = options.AnchorPoint or Vector2.new(0, 0)
	panel.LayoutOrder = options.LayoutOrder or 0
	if options.AutomaticSize then
		panel.AutomaticSize = options.AutomaticSize
	end
	panel.BackgroundColor3 = Theme.Colors.PanelBackground
	panel.BackgroundTransparency = options.BackgroundTransparency or Theme.Transparency.PanelBackground
	panel.BorderSizePixel = 0

	local corner = Instance.new("UICorner")
	corner.Name = "Corner"
	corner.CornerRadius = options.CornerRadius or Theme.Corner.Large
	corner.Parent = panel

	if options.Stroke ~= false then
		local stroke = Instance.new("UIStroke")
		stroke.Name = "Stroke"
		stroke.Color = accentColor
		stroke.Thickness = 1.5
		stroke.Transparency = Theme.Transparency.StrokeDefault
		stroke.Parent = panel
	end

	if options.Gradient ~= false then
		local gradient = Instance.new("UIGradient")
		gradient.Name = "Gradient"
		gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), accentColor)
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, Theme.Transparency.GradientNear),
			NumberSequenceKeypoint.new(1, Theme.Transparency.GradientFar),
		})
		gradient.Rotation = 90
		gradient.Parent = panel
	end

	panel.Parent = options.Parent

	if options.DropShadow ~= false then
		Shadow.Attach(panel)
	end

	return panel
end

return GlassPanel
