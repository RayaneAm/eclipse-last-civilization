--!strict
-- Rounded, modern button in 4 variants. Every button in the system (Craft,
-- Equip, Close, tab entries) is built on this one constructor so
-- hover/press/disabled feedback is guaranteed consistent everywhere.
--
-- Primary/Danger read as solid, pressable CTAs (near-opaque fill + glossy
-- top-highlight gradient + shadow) — the original 0.75 background
-- transparency left them looking like a washed-out tint, not a real button.
-- Secondary is a lighter glass tint. Ghost is text-only at rest but gets its
-- own hover wash (Interaction.Bind has no color feedback to give it, since
-- Ghost intentionally has no UIStroke — see below).

local Theme = require(script.Parent.Parent.Theme)
local Motion = require(script.Parent.Parent.Motion)
local Interaction = require(script.Parent.Parent.Interaction)
local Shadow = require(script.Parent.Parent.Shadow)

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

local GHOST_HOVER_TRANSPARENCY = 0.85

function Button.new(options: ButtonOptions): TextButton
	local variant: ButtonVariant = options.Variant or "Primary"
	local accentColor = options.AccentColor or (if variant == "Danger" then Theme.Colors.Danger else Theme.Colors.Brand)
	local isStrong = variant == "Primary" or variant == "Danger"

	local button = Instance.new("TextButton")
	button.Name = options.Name or "Button"
	button.Size = options.Size or UDim2.fromOffset(140, 44)
	button.Position = options.Position or UDim2.fromScale(0, 0)
	button.AnchorPoint = options.AnchorPoint or Vector2.new(0, 0)
	button.LayoutOrder = options.LayoutOrder or 0
	button.AutoButtonColor = false
	button.Text = ""
	button.BackgroundColor3 = if variant == "Ghost" then Theme.Colors.PanelBackground else accentColor
	button.BackgroundTransparency = if variant == "Ghost" then 1 elseif variant == "Secondary" then 0.48 else 0.12
	button.BorderSizePixel = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.Corner.Large -- rounder shape, matching every other surface in the system
	corner.Parent = button

	if variant ~= "Ghost" then
		local stroke = Instance.new("UIStroke")
		stroke.Color = accentColor
		stroke.Thickness = if isStrong then 2 else 1.5
		stroke.Transparency = if variant == "Secondary" then 0.25 else Theme.Transparency.StrokeBright
		stroke.Parent = button
	end

	-- Glossy top-highlight gradient — distinct from GlassPanel's subtle
	-- accent wash, meant to actually read as a lit, pressable surface.
	if isStrong then
		local gradient = Instance.new("UIGradient")
		gradient.Name = "Gradient"
		gradient.Color = ColorSequence.new(accentColor:Lerp(Color3.new(1, 1, 1), 0.35), accentColor)
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.05),
			NumberSequenceKeypoint.new(1, 0.35),
		})
		gradient.Rotation = 90
		gradient.Parent = button
	end

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Theme.Font.Heading.Font
	label.TextSize = Theme.Font.Heading.Size
	label.TextColor3 = if variant == "Secondary" or variant == "Ghost" then accentColor else Theme.Colors.TextPrimary
	label.Text = options.Text
	label.Parent = button

	button.Parent = options.Parent

	if variant ~= "Ghost" then
		Shadow.Attach(button, { Transparency = 0.5 })
	end

	-- Ghost has no UIStroke, so Interaction.Bind's stroke-brighten hover
	-- feedback has nothing to act on — without this, Ghost buttons (e.g.
	-- Skip) get zero color feedback on hover, only a 3% scale nudge.
	if variant == "Ghost" then
		local function applyHoverWash()
			Motion.Tween(button, "GhostHoverBG", Theme.Motion.HoverIn, { BackgroundTransparency = GHOST_HOVER_TRANSPARENCY })
		end
		local function clearHoverWash()
			Motion.Tween(button, "GhostHoverBG", Theme.Motion.HoverOut, { BackgroundTransparency = 1 })
		end
		button.MouseEnter:Connect(applyHoverWash)
		button.MouseLeave:Connect(clearHoverWash)
		button.SelectionGained:Connect(applyHoverWash)
		button.SelectionLost:Connect(clearHoverWash)
	end

	local cleanup = Interaction.Bind(button, { OnActivated = options.OnActivated })
	button.Destroying:Once(cleanup)

	if options.Disabled then
		Interaction.SetDisabled(button, true)
	end

	return button
end

function Button.SetDisabled(button: TextButton, disabled: boolean)
	Interaction.SetDisabled(button, disabled)
end

return Button
