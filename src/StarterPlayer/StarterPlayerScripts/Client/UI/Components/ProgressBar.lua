--!strict
-- The meter fill bar. Now a chunky capsule: a dark recessed track, a bright
-- accent fill with a gloss highlight, and a dark outline around the whole
-- thing.
--
-- The old bar was an 8px track on CardBackground with a muted grey hairline
-- stroke and a flat fill — at a glance it read as a loading indicator on a
-- settings page. Meters are one of the most-looked-at elements in a base
-- game (power, storage, wall integrity, production), so they earn real
-- weight.

local Theme = require(script.Parent.Parent.Theme)
local Motion = require(script.Parent.Parent.Motion)

local ProgressBar = {}

export type ProgressBarOptions = {
	Name: string?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	AccentColor: Color3?,
	InitialProgress: number?,
	Parent: Instance?,
}

function ProgressBar.new(options: ProgressBarOptions): (Frame, (fraction: number, animated: boolean?) -> ())
	local accent = options.AccentColor or Theme.Colors.Brand

	local track = Instance.new("Frame")
	track.Name = options.Name or "ProgressBar"
	track.Size = options.Size or UDim2.fromOffset(220, 14)
	track.Position = options.Position or UDim2.fromScale(0, 0)
	track.AnchorPoint = options.AnchorPoint or Vector2.new(0, 0)
	track.LayoutOrder = options.LayoutOrder or 0
	-- A genuinely dark well, so even a 5% fill is visible against it.
	track.BackgroundColor3 = Theme.Colors.Void
	track.BackgroundTransparency = 0.15
	track.BorderSizePixel = 0
	track.ClipsDescendants = true

	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = Theme.Corner.Pill
	trackCorner.Parent = track

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(math.clamp(options.InitialProgress or 0, 0, 1), 0, 1, 0)
	fill.BackgroundColor3 = accent
	fill.BorderSizePixel = 0
	fill.Parent = track

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = Theme.Corner.Pill
	fillCorner.Parent = fill

	-- A lighter band across the top third makes the fill look like a glossy
	-- capsule rather than a flat block of color.
	local gloss = Instance.new("Frame")
	gloss.Name = "Gloss"
	gloss.Size = UDim2.new(1, 0, 0.42, 0)
	gloss.Position = UDim2.fromScale(0, 0.08)
	gloss.BackgroundColor3 = Color3.new(1, 1, 1)
	gloss.BackgroundTransparency = 0.75
	gloss.BorderSizePixel = 0
	gloss.Parent = fill

	local glossCorner = Instance.new("UICorner")
	glossCorner.CornerRadius = Theme.Corner.Pill
	glossCorner.Parent = gloss

	-- The outline lives on a sibling overlay rather than on the track itself,
	-- because the track clips its descendants and an inset border stroke on a
	-- clipping frame gets cut at the rounded ends.
	local outline = Instance.new("Frame")
	outline.Name = "Outline"
	outline.Size = UDim2.fromScale(1, 1)
	outline.BackgroundTransparency = 1
	outline.ZIndex = 3
	outline.Parent = track
	local outlineCorner = Instance.new("UICorner")
	outlineCorner.CornerRadius = Theme.Corner.Pill
	outlineCorner.Parent = outline
	Theme.Outline(outline, Theme.Stroke.Thin)

	local function setProgress(fraction: number, animated: boolean?)
		local clamped = math.clamp(fraction, 0, 1)
		if animated == false then
			fill.Size = UDim2.new(clamped, 0, 1, 0)
		else
			Motion.Tween(fill, "Progress", Theme.Motion.Fade, { Size = UDim2.new(clamped, 0, 1, 0) })
		end
	end

	track.Parent = options.Parent

	return track, setProgress
end

return ProgressBar
