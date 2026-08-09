--!strict
-- The nested card surface: a rounded slab on Theme.Colors.CardBackground
-- with a dark outline.
--
-- The old rule here was "nested surfaces are NEVER stroked — hierarchy comes
-- from background shade alone." That rule came from a palette where every
-- surface was a near-identical dark, and stroking them stacked accent
-- hairlines into visible border-in-border noise.
--
-- The rebuilt palette changes the calculus: strokes are near-black (not
-- accent-tinted), so they read as the card's own edge rather than a second
-- frame, and the surface ladder now steps far enough that a stroke
-- reinforces the step instead of substituting for it. Dark outlines on
-- lighter cards are precisely what produces the chunky, sticker-like look
-- this pass is after — the previous unstroked cards dissolved into the panel.

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
	-- Opt out of the outline for a surface nested inside an already-outlined
	-- card (an inner well), where a second edge would be noise.
	Outline: boolean?,
	Color: Color3?,
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
	surface.BackgroundColor3 = options.Color or Theme.Colors.CardBackground
	surface.BackgroundTransparency = 0
	surface.BorderSizePixel = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = options.CornerRadius or Theme.Corner.Medium
	corner.Parent = surface

	if options.Outline ~= false then
		Theme.Outline(surface, Theme.Stroke.Card)
	end

	surface.Parent = options.Parent

	if options.DropShadow ~= false then
		Shadow.Attach(surface, { Transparency = Theme.Shadow.Card.Transparency, Offset = Theme.Shadow.Card.Offset })
	end

	return surface
end

return Surface
