--!strict
-- The close control that sits in every facility header.
--
-- Now a real chunky button rather than a bare glyph floating in a corner:
-- a rounded square with a dark outline, sitting ON the header's accent bar,
-- with a thick white X. On hover it fills red, which is the standard
-- "this dismisses the window" cue.
--
-- The X is still DRAWN from two rotated bars rather than typed as a glyph.
-- The Unicode multiplication/ballot characters are outside the block
-- Roblox's default UI fonts reliably cover and render as a missing-glyph box
-- on many clients — the same class of bug that made resource emoji vanish
-- (see IconArt's header). Two Frames cannot fail.
--
-- 44x44 keeps it above the minimum comfortable touch target while staying
-- proportionate inside the header bar.

local Theme = require(script.Parent.Parent.Theme)
local Motion = require(script.Parent.Parent.Motion)

local CloseButton = {}

export type CloseButtonOptions = {
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Parent: Instance?,
	OnActivated: (() -> ())?,
}

local SIZE = 42
local BAR_THICKNESS = 4

function CloseButton.new(options: CloseButtonOptions): TextButton
	local button = Instance.new("TextButton")
	button.Name = "CloseButton"
	button.Size = UDim2.fromOffset(SIZE, SIZE)
	button.Position = options.Position or UDim2.fromScale(0, 0)
	button.AnchorPoint = options.AnchorPoint or Vector2.new(0, 0)
	button.AutoButtonColor = false
	button.Text = ""
	-- A dark plate over the accent header: reads as a control cut into the
	-- bar rather than a floating symbol.
	button.BackgroundColor3 = Theme.Colors.Void
	button.BackgroundTransparency = 0.55
	button.BorderSizePixel = 0
	button.ZIndex = 5

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.Corner.Medium
	corner.Parent = button

	local stroke = Theme.Outline(button, Theme.Stroke.Thin)
	stroke.Transparency = 0.35

	local glyph = Instance.new("Frame")
	glyph.Name = "Glyph"
	glyph.AnchorPoint = Vector2.new(0.5, 0.5)
	glyph.Position = UDim2.fromScale(0.5, 0.5)
	glyph.Size = UDim2.fromOffset(18, 18)
	glyph.BackgroundTransparency = 1
	glyph.ZIndex = 6
	glyph.Parent = button

	for _, rotation in { 45, -45 } do
		local bar = Instance.new("Frame")
		bar.Name = `Bar{rotation}`
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.fromScale(0.5, 0.5)
		bar.Size = UDim2.new(1, 2, 0, BAR_THICKNESS)
		bar.Rotation = rotation
		bar.BackgroundColor3 = Theme.Colors.TextPrimary
		bar.BorderSizePixel = 0
		bar.ZIndex = 6
		bar.Parent = glyph

		local barCorner = Instance.new("UICorner")
		barCorner.CornerRadius = UDim.new(0.5, 0)
		barCorner.Parent = bar
	end

	button.Parent = options.Parent

	local function setHovered(hovered: boolean)
		Motion.Tween(button, "CloseHover", Theme.Motion.HoverIn, {
			BackgroundColor3 = if hovered then Theme.Colors.Danger else Theme.Colors.Void,
			BackgroundTransparency = if hovered then 0 else 0.55,
		})
	end

	button.MouseEnter:Connect(function()
		setHovered(true)
	end)
	button.MouseLeave:Connect(function()
		setHovered(false)
	end)
	button.SelectionGained:Connect(function()
		setHovered(true)
	end)
	button.SelectionLost:Connect(function()
		setHovered(false)
	end)

	if options.OnActivated then
		button.Activated:Connect(options.OnActivated)
	end

	return button
end

return CloseButton
