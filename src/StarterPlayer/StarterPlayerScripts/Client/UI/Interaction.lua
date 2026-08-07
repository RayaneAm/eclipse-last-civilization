--!strict
-- Wires the standard idle/hover/pressed/disabled/gamepad-selected feedback
-- states onto any GuiButton, reusing one shared UIScale + the button's own
-- UIStroke. `Activated` (not MouseButton1Click) is used to fire the caller's
-- callback since it's Roblox's one event that already unifies mouse click,
-- touch tap, and gamepad A/Select — no separate touch-handling path needed
-- for activation itself, only for the visual press state (see below).
--
-- Touch has no MouseEnter/MouseLeave (no hover concept on a touchscreen), so
-- touch input drives the press state directly off InputBegan/InputEnded
-- instead of a separate hover phase — on a touchscreen, "pressed" IS the
-- feedback state, which is the correct native mobile-game feel.
--
-- Gamepad focus (SelectionGained/SelectionLost) reuses the exact same tween
-- calls as desktop hover, so a controller-focused button reads identically to
-- a moused-over one with zero extra code.

local Theme = require(script.Parent.Theme)
local Motion = require(script.Parent.Motion)

local Interaction = {}

export type InteractionOptions = {
	HoverScale: number?,
	PressScale: number?,
	OnActivated: (() -> ())?,
}

local DEFAULT_HOVER_SCALE = 1.03
local DEFAULT_PRESS_SCALE = 0.97

local function getOrCreateScale(button: GuiButton): UIScale
	local existing = button:FindFirstChild("HoverScale") :: UIScale?
	if existing then
		return existing
	end
	local scale = Instance.new("UIScale")
	scale.Name = "HoverScale"
	scale.Parent = button
	return scale
end

local function getStroke(button: GuiButton): UIStroke?
	return button:FindFirstChildOfClass("UIStroke")
end

-- Returns a cleanup function (Trove-compatible: `trove:Add(cleanup)`).
function Interaction.Bind(button: GuiButton, options: InteractionOptions?): () -> ()
	local opts = options or {}
	local hoverScale = opts.HoverScale or DEFAULT_HOVER_SCALE
	local pressScale = opts.PressScale or DEFAULT_PRESS_SCALE
	local scale = getOrCreateScale(button)
	local stroke = getStroke(button)

	local disabled = false
	local hovered = false

	local function applyIdle()
		Motion.Tween(scale, "Scale", Theme.Motion.HoverOut, { Scale = 1 })
		if stroke then
			Motion.Tween(stroke, "Stroke", Theme.Motion.HoverOut, { Transparency = Theme.Transparency.StrokeDefault })
		end
	end

	local function applyHover()
		Motion.Tween(scale, "Scale", Theme.Motion.HoverIn, { Scale = hoverScale })
		if stroke then
			Motion.Tween(stroke, "Stroke", Theme.Motion.HoverIn, { Transparency = Theme.Transparency.StrokeBright })
		end
	end

	local function applyPress()
		Motion.Tween(scale, "Scale", Theme.Motion.PressDown, { Scale = pressScale })
		if stroke then
			Motion.Tween(stroke, "Stroke", Theme.Motion.PressDown, { Transparency = 0 })
		end
	end

	local connections: { RBXScriptConnection } = {}
	local function connect(signal: RBXScriptSignal, handler: (...any) -> ())
		table.insert(connections, signal:Connect(handler))
	end

	connect(button.MouseEnter, function()
		hovered = true
		if not disabled then
			applyHover()
		end
	end)
	connect(button.MouseLeave, function()
		hovered = false
		if not disabled then
			applyIdle()
		end
	end)
	connect(button.SelectionGained, function()
		if not disabled then
			applyHover()
		end
	end)
	connect(button.SelectionLost, function()
		if not disabled then
			applyIdle()
		end
	end)

	connect(button.InputBegan, function(input: InputObject)
		if disabled then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			applyPress()
		end
	end)
	connect(button.InputEnded, function(input: InputObject)
		if disabled then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if hovered and input.UserInputType == Enum.UserInputType.MouseButton1 then
				applyHover()
			else
				applyIdle()
			end
		end
	end)

	if opts.OnActivated then
		connect(button.Activated, opts.OnActivated)
	end

	applyIdle()

	return function()
		for _, connection in connections do
			connection:Disconnect()
		end
	end
end

function Interaction.SetDisabled(button: GuiButton, disabled: boolean)
	button.Active = not disabled
	button.Selectable = not disabled

	local scale = getOrCreateScale(button)
	local stroke = getStroke(button)

	if disabled then
		Motion.Tween(scale, "Scale", Theme.Motion.HoverOut, { Scale = 1 })
		if stroke then
			Motion.Tween(stroke, "Stroke", Theme.Motion.HoverOut, { Transparency = 0.6 })
		end
		for _, child in button:GetDescendants() do
			if child:IsA("TextLabel") or child:IsA("TextButton") then
				Motion.Tween(child, "TextFade", Theme.Motion.HoverOut, { TextTransparency = 0.5 })
			end
		end
	else
		if stroke then
			Motion.Tween(stroke, "Stroke", Theme.Motion.HoverOut, { Transparency = Theme.Transparency.StrokeDefault })
		end
		for _, child in button:GetDescendants() do
			if child:IsA("TextLabel") or child:IsA("TextButton") then
				Motion.Tween(child, "TextFade", Theme.Motion.HoverOut, { TextTransparency = 0 })
			end
		end
	end
end

return Interaction
