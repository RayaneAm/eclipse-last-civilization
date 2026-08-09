--!strict
-- The chunky ECLIPSE game button. Every CTA in the game is one of these.
--
-- The previous version was a translucent tinted rectangle with a hairline
-- stroke — it read as a web control. This one is built the way simulator/
-- tycoon buttons are built, from four cheap layers:
--
--   1. LIP      a darker slab offset a few px down, visible below the face.
--               This is the entire "3D" illusion and costs one Frame.
--   2. FACE     the accent fill, carrying a gloss gradient (light at the
--               top, slightly darkened at the bottom) so it looks lit.
--   3. OUTLINE  a 2px near-black border. Dark outlines on bright shapes are
--               what make a UI look chunky rather than flat.
--   4. LABEL    black-weight text, with dark text on light accents so a
--               gold or yellow button stays readable.
--
-- Pressing tweens the face DOWN onto the lip, so the button physically
-- depresses instead of only scaling. That is handled here rather than in
-- UIAnimator because it is specific to this construction.

local Theme = require(script.Parent.Parent.Theme)
local Motion = require(script.Parent.Parent.Motion)
local Interaction = require(script.Parent.Parent.Interaction)

local Button = {}

export type ButtonVariant = "Primary" | "Secondary" | "Ghost" | "Danger"

export type ButtonOptions = {
	Name: string?,
	Text: string,
	Variant: ButtonVariant?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	AccentColor: Color3?,
	LayoutOrder: number?,
	Disabled: boolean?,
	OnActivated: (() -> ())?,
	Parent: Instance?,
}

local LIP_DEPTH = 4

-- Light accents (gold, yellow, lime) need dark text; deep ones need white.
-- Perceptual luminance, so this is decided by the color rather than by a
-- per-caller guess.
local function labelColorFor(fill: Color3): Color3
	local luminance = 0.299 * fill.R + 0.587 * fill.G + 0.114 * fill.B
	return if luminance > 0.62 then Theme.Colors.TextOnAccent else Theme.Colors.TextPrimary
end

function Button.new(options: ButtonOptions): TextButton
	local variant: ButtonVariant = options.Variant or "Primary"
	local accent = options.AccentColor or (if variant == "Danger" then Theme.Colors.Danger else Theme.Colors.Brand)

	local isStrong = variant == "Primary" or variant == "Danger"
	local faceColor: Color3
	local labelColor: Color3
	if variant == "Ghost" then
		faceColor = Theme.Colors.CardBackground
		labelColor = Theme.Colors.TextSecondary
	elseif variant == "Secondary" then
		-- A muted slab that still reads as a real button, tinted toward the
		-- accent so it belongs to the same screen.
		faceColor = accent:Lerp(Theme.Colors.Surface, 0.72)
		labelColor = Theme.Colors.TextPrimary
	else
		faceColor = accent
		labelColor = labelColorFor(accent)
	end

	-- The outer button is the LIP: a darker slab. The face sits on top of it,
	-- inset from the bottom, which is what leaves the visible ledge.
	local button = Instance.new("TextButton")
	button.Name = options.Name or "Button"
	button.Size = options.Size or UDim2.fromOffset(150, 46)
	button.Position = options.Position or UDim2.fromScale(0, 0)
	button.AnchorPoint = options.AnchorPoint or Vector2.new(0, 0)
	button.LayoutOrder = options.LayoutOrder or 0
	button.AutoButtonColor = false
	button.Text = ""
	button.BackgroundColor3 = if variant == "Ghost" then Theme.Colors.Surface else faceColor:Lerp(Theme.Colors.Void, 0.55)
	button.BackgroundTransparency = if variant == "Ghost" then 1 else 0
	button.BorderSizePixel = 0
	button.ClipsDescendants = false

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.Corner.Medium
	corner.Parent = button

	if variant ~= "Ghost" then
		Theme.Outline(button, Theme.Stroke.Card)
	end

	local face = Instance.new("Frame")
	face.Name = "Face"
	face.Size = UDim2.new(1, 0, 1, -LIP_DEPTH)
	face.Position = UDim2.fromOffset(0, 0)
	face.BackgroundColor3 = faceColor
	face.BackgroundTransparency = if variant == "Ghost" then 1 else 0
	face.BorderSizePixel = 0
	face.Parent = button

	local faceCorner = Instance.new("UICorner")
	faceCorner.CornerRadius = Theme.Corner.Medium
	faceCorner.Parent = face

	if isStrong then
		Theme.GlossGradient(faceColor).Parent = face
	end

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Theme.Font.Button.Font
	label.TextSize = Theme.Font.Button.Size
	label.TextColor3 = labelColor
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Text = string.upper(options.Text)
	label.Parent = face

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, Theme.Spacing.S)
	padding.PaddingRight = UDim.new(0, Theme.Spacing.S)
	padding.Parent = label

	button.Parent = options.Parent

	-- Press feedback: the face travels down onto the lip and back. Combined
	-- with Interaction's scale pulse this reads as a real physical press.
	if variant ~= "Ghost" then
		local function faceDown()
			Motion.Tween(face, "Lip", Theme.Motion.PressDown, { Position = UDim2.fromOffset(0, LIP_DEPTH) })
		end
		local function faceUp()
			Motion.Tween(face, "Lip", Theme.Motion.PressUp, { Position = UDim2.fromOffset(0, 0) })
		end
		button.MouseButton1Down:Connect(faceDown)
		button.MouseButton1Up:Connect(faceUp)
		button.MouseLeave:Connect(faceUp)
		button.TouchLongPress:Connect(faceDown)
		-- Activated covers touch/gamepad, where there is no Down/Up pair to
		-- bracket the animation, so play the full dip here.
		button.Activated:Connect(function()
			faceDown()
			task.delay(Theme.Motion.PressDown.Time, faceUp)
		end)
	end

	if variant == "Ghost" then
		local function wash(on: boolean)
			Motion.Tween(button, "GhostWash", Theme.Motion.HoverIn, { BackgroundTransparency = if on then 0.4 else 1 })
		end
		button.MouseEnter:Connect(function()
			wash(true)
		end)
		button.MouseLeave:Connect(function()
			wash(false)
		end)
		button.SelectionGained:Connect(function()
			wash(true)
		end)
		button.SelectionLost:Connect(function()
			wash(false)
		end)
	end

	local cleanup = Interaction.Bind(button, { OnActivated = options.OnActivated })
	button.Destroying:Once(cleanup)

	if options.Disabled then
		Button.SetDisabled(button, true)
	end

	return button
end

-- Disabled buttons desaturate toward the panel instead of only fading text,
-- so "cannot press this" is obvious at a glance rather than a subtle tint.
function Button.SetDisabled(button: TextButton, disabled: boolean)
	Interaction.SetDisabled(button, disabled)

	local face = button:FindFirstChild("Face") :: Frame?
	local label = if face then face:FindFirstChild("Label") :: TextLabel? else nil
	if not face or not label then
		return
	end

	if disabled then
		if face:GetAttribute("EnabledColor") == nil then
			face:SetAttribute("EnabledColor", face.BackgroundColor3)
			face:SetAttribute("EnabledTextColor", label.TextColor3)
		end
		local muted = (face:GetAttribute("EnabledColor") :: Color3):Lerp(Theme.Colors.Surface, 0.78)
		Motion.Tween(face, "DisabledFill", Theme.Motion.HoverOut, { BackgroundColor3 = muted })
		Motion.Tween(label, "DisabledText", Theme.Motion.HoverOut, { TextColor3 = Theme.Colors.TextMuted })
		local gloss = face:FindFirstChild("Gloss") :: UIGradient?
		if gloss then
			gloss.Enabled = false
		end
	else
		local enabledColor = face:GetAttribute("EnabledColor") :: Color3?
		local enabledText = face:GetAttribute("EnabledTextColor") :: Color3?
		if enabledColor then
			Motion.Tween(face, "DisabledFill", Theme.Motion.HoverOut, { BackgroundColor3 = enabledColor })
		end
		if enabledText then
			Motion.Tween(label, "DisabledText", Theme.Motion.HoverOut, { TextColor3 = enabledText })
		end
		local gloss = face:FindFirstChild("Gloss") :: UIGradient?
		if gloss then
			gloss.Enabled = true
		end
	end
end

return Button
