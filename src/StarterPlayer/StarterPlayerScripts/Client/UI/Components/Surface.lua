--!strict
-- Soft rounded "nested card" surface — the concrete fix for border-inside-
-- border. Uses Theme.Colors.CardBackground (a real lighter step, not a
-- slightly-different dark) + Theme.Shadow.Card, and NEVER attaches a
-- UIStroke — see Theme.luau's art-direction header for the border rule this
-- enforces. Replaces the repeated `GlassPanel.new({ Stroke = false, Gradient
-- = false })` ad hoc pattern that was previously copy-pasted across
-- BaseUIController's rows and various shop panels.

local Theme = require(script.Parent.Parent.Theme)
local Shadow = require(script.Parent.Parent.Shadow)

local Surface = {}

export type SurfaceOptions = {
	Name: string?,
	Size: UDim2,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	CornerRadius: UDim?,
	AutomaticSize: Enum.AutomaticSize?,
	DropShadow: boolean?,
	LayoutOrder: number?,
	Parent: Instance?,
}

function Surface.new(options: SurfaceOptions): Frame
	local surface = Instance.new("Frame")
	surface.Name = options.Name or "Surface"
	surface.Size = options.Size
	surface.Position = options.Position or UDim2.fromScale(0, 0)
	surface.AnchorPoint = options.AnchorPoint or Vector2.new(0, 0)
	surface.LayoutOrder = options.LayoutOrder or 0
	if options.AutomaticSize then
		surface.AutomaticSize = options.AutomaticSize
	end
	surface.BackgroundColor3 = Theme.Colors.CardBackground
	surface.BackgroundTransparency = Theme.Transparency.CardBackground
	surface.BorderSizePixel = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = options.CornerRadius or Theme.Corner.Medium
	corner.Parent = surface

	surface.Parent = options.Parent

	if options.DropShadow ~= false then
		Shadow.Attach(surface, { Transparency = Theme.Shadow.Card.Transparency, Offset = Theme.Shadow.Card.Offset })
	end

	return surface
end

return Surface
