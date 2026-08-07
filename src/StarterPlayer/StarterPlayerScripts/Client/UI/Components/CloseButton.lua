--!strict
-- Universal close control for every major HUD panel (Phase 4A.1 correction).
-- The X is DRAWN from two thin rotated Frames, not a font glyph — the
-- previous version used the Unicode dingbat "✕" (U+2715), a symbol outside
-- the block Roblox's default UI font family reliably covers (unlike emoji,
-- which render fine everywhere else in this UI), so it showed as a "tofu"
-- missing-glyph box on many clients — exactly the "placeholder square"
-- complaint. A drawn X has no font-coverage dependency at all and is always
-- red (Theme.Colors.Danger), matching "clear red X" literally rather than
-- leaving color to whatever accent a caller happened to pass.
--
-- Fixed 44x44 hit target (clears Theme.MinTouchTarget minus the small
-- margin already accepted for a corner-isolated control), no permanent
-- background/stroke at rest — a subtle circular wash appears on hover/press/
-- gamepad-focus, consistent with the borderless HUD treatment established by
-- HudIconButton.luau, so a close control never reads as another bordered box
-- stacked in the corner of an already-bordered panel.

local Theme = require(script.Parent.Parent.Theme)
local Motion = require(script.Parent.Parent.Motion)
local Shadow = require(script.Parent.Parent.Shadow)

local CloseButton = {}

export type CloseButtonOptions = {
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Parent: Instance?,
	OnActivated: (() -> ())?,
}

local SIZE = 44
local WASH_TRANSPARENCY = 0.85

function CloseButton.new(options: CloseButtonOptions): TextButton
	local button = Instance.new("TextButton")
	button.Name = "CloseButton"
	button.Size = UDim2.fromOffset(SIZE, SIZE)
	button.Position = options.Position or UDim2.fromScale(0, 0)
	button.AnchorPoint = options.AnchorPoint or Vector2.new(0, 0)
	button.AutoButtonColor = false
	button.Text = ""
	button.BackgroundColor3 = Theme.Colors.PanelBackground
	button.BackgroundTransparency = 1
	button.BorderSizePixel = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.Corner.Pill
	corner.Parent = button

	local glyphHolder = Instance.new("Frame")
	glyphHolder.Name = "Glyph"
	glyphHolder.Size = UDim2.fromOffset(16, 16)
	glyphHolder.Position = UDim2.fromScale(0.5, 0.5)
	glyphHolder.AnchorPoint = Vector2.new(0.5, 0.5)
	glyphHolder.BackgroundTransparency = 1
	glyphHolder.Parent = button

	for _, rotation in { 45, -45 } do
		local bar = Instance.new("Frame")
		bar.Name = `Bar{rotation}`
		bar.Size = UDim2.new(1, 4, 0, 2.5)
		bar.Position = UDim2.fromScale(0.5, 0.5)
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Rotation = rotation
		bar.BackgroundColor3 = Theme.Colors.Danger
		bar.BorderSizePixel = 0
		local barCorner = Instance.new("UICorner")
		barCorner.CornerRadius = UDim.new(1, 0)
		barCorner.Parent = bar
		bar.Parent = glyphHolder
	end

	button.Parent = options.Parent
	Shadow.Attach(button, { Transparency = 0.75 })

	local function applyWash()
		Motion.Tween(button, "Wash", Theme.Motion.HoverIn, { BackgroundTransparency = WASH_TRANSPARENCY })
	end
	local function clearWash()
		Motion.Tween(button, "Wash", Theme.Motion.HoverOut, { BackgroundTransparency = 1 })
	end
	button.MouseEnter:Connect(applyWash)
	button.MouseLeave:Connect(clearWash)
	button.SelectionGained:Connect(applyWash)
	button.SelectionLost:Connect(clearWash)

	if options.OnActivated then
		button.Activated:Connect(options.OnActivated)
	end

	return button
end

return CloseButton
