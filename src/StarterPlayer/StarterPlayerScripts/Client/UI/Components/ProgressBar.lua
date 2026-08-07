--!strict
-- Tween-animated fill bar — the quest tracker's objective progress today,
-- reusable for anything else that's a fraction of a target later.

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

-- Returns (track, setProgress). setProgress(fraction, animated?) clamps to
-- [0,1] and tweens the fill's width unless animated is explicitly false.
function ProgressBar.new(options: ProgressBarOptions): (Frame, (fraction: number, animated: boolean?) -> ())
	local accentColor = options.AccentColor or Theme.Colors.Brand

	local track = Instance.new("Frame")
	track.Name = options.Name or "ProgressBar"
	track.Size = options.Size or UDim2.fromOffset(220, 8)
	track.Position = options.Position or UDim2.fromScale(0, 0)
	track.AnchorPoint = options.AnchorPoint or Vector2.new(0, 0)
	track.LayoutOrder = options.LayoutOrder or 0
	track.BackgroundColor3 = Theme.Colors.CardBackground
	track.BackgroundTransparency = 0.02
	track.BorderSizePixel = 0

	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = Theme.Corner.Pill
	trackCorner.Parent = track

	local trackStroke = Instance.new("UIStroke")
	trackStroke.Color = Theme.Colors.TextMuted
	trackStroke.Thickness = 1
	trackStroke.Transparency = 0.58
	trackStroke.Parent = track

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(math.clamp(options.InitialProgress or 0, 0, 1), 0, 1, 0)
	fill.BackgroundColor3 = accentColor
	fill.BorderSizePixel = 0
	fill.Parent = track

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = Theme.Corner.Pill
	fillCorner.Parent = fill

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
