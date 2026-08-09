--!strict
-- The ⓘ affordance + its floating explanation bubble. Exists so secondary
-- explanations never become paragraphs inside a panel (facility UI brief
-- §49): the screen shows the short label, and the detail is one tap/hover
-- away.
--
-- Desktop shows the bubble on hover; touch shows it on tap (a touchscreen
-- has no hover state, so the tap toggles it and a second tap anywhere
-- dismisses it). Both paths go through the same show/hide, so there is one
-- visual result regardless of input.
--
-- The bubble is parented to the tooltip's own ScreenGui layer rather than to
-- the row that owns it, so it can overhang a panel edge without being
-- clipped by an ancestor ScrollingFrame's ClipsDescendants.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Parent.Theme)
local Motion = require(script.Parent.Parent.Motion)

local Tooltip = {}

export type TooltipOptions = {
	Anchor: GuiObject?, -- what the ⓘ sits next to; defaults to the host
	Accent: Color3?,
}

local MAX_WIDTH = 240
local TOUCH_VISIBLE_SECONDS = 4

local layer: ScreenGui? = nil
local bubble: Frame? = nil
local bubbleLabel: TextLabel? = nil
local activeHost: GuiObject? = nil

local function ensureLayer(): (ScreenGui, Frame, TextLabel)
	if layer and layer.Parent and bubble and bubbleLabel then
		return layer, bubble, bubbleLabel
	end

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "EclipseTooltipLayer"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 55 -- above facility modals (50), below toasts (60)
	screenGui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Name = "Bubble"
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.Size = UDim2.fromOffset(MAX_WIDTH, 0)
	frame.BackgroundColor3 = Theme.Colors.CardBackground
	frame.BackgroundTransparency = 0
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.ZIndex = 10
	frame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.Corner.Medium
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Name = "Stroke"
	stroke.Color = Theme.Colors.Brand
	stroke.Thickness = 1
	stroke.Transparency = 0.5
	stroke.Parent = frame

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, Theme.Spacing.M)
	padding.PaddingRight = UDim.new(0, Theme.Spacing.M)
	padding.PaddingTop = UDim.new(0, Theme.Spacing.S)
	padding.PaddingBottom = UDim.new(0, Theme.Spacing.S)
	padding.Parent = frame

	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.AutomaticSize = Enum.AutomaticSize.Y
	text.Size = UDim2.new(1, 0, 0, 0)
	text.BackgroundTransparency = 1
	text.Font = Theme.Font.Caption.Font
	text.TextSize = Theme.Font.Caption.Size
	text.TextColor3 = Theme.Colors.TextSecondary
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextWrapped = true
	text.ZIndex = 11
	text.Parent = frame

	layer = screenGui
	bubble = frame
	bubbleLabel = text
	return screenGui, frame, text
end

local function hide()
	activeHost = nil
	if bubble then
		bubble.Visible = false
	end
end

local function show(host: GuiObject, text: string, accent: Color3?)
	local _, frame, label = ensureLayer()
	activeHost = host
	label.Text = text

	local stroke = frame:FindFirstChild("Stroke") :: UIStroke?
	if stroke then
		stroke.Color = accent or Theme.Colors.Brand
	end

	-- Position above the host by default, flipping below when the host is
	-- near the top of the screen so the bubble is never pushed off-screen.
	local hostPosition = host.AbsolutePosition
	local hostSize = host.AbsoluteSize
	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)

	local x = math.clamp(hostPosition.X, 8, math.max(8, viewport.X - MAX_WIDTH - 8))
	local placeBelow = hostPosition.Y < 120
	frame.AnchorPoint = Vector2.new(0, if placeBelow then 0 else 1)
	local y = if placeBelow then hostPosition.Y + hostSize.Y + 6 else hostPosition.Y - 6
	frame.Position = UDim2.fromOffset(x, y)

	frame.Visible = true
	frame.BackgroundTransparency = 1
	Motion.Tween(frame, "TooltipFade", Theme.Motion.HoverIn, { BackgroundTransparency = 0 })
end

-- Adds an ⓘ button to `host` and wires hover (desktop) / tap (touch).
-- Returns the button so a caller can position it differently if needed.
function Tooltip.Attach(host: GuiObject, text: string, options: TooltipOptions?): TextButton
	local opts = options or {}
	local anchor = opts.Anchor or host

	local button = Instance.new("TextButton")
	button.Name = "InfoAffordance"
	button.Size = UDim2.fromOffset(18, 18)
	button.AnchorPoint = Vector2.new(0, 0.5)
	-- Sits immediately right of the anchoring label. AutomaticSize on that
	-- label means its width is only known after a layout pass, so bind to
	-- the size change rather than reading it once at construction.
	button.Position = UDim2.new(0, anchor.AbsoluteSize.X + 4, 0.5, 0)
	button.BackgroundTransparency = 1
	button.AutoButtonColor = false
	button.Font = Enum.Font.GothamBold
	button.TextSize = 13
	button.TextColor3 = Theme.Colors.TextMuted
	button.Text = "ⓘ"
	button.Parent = host

	anchor:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		button.Position = UDim2.new(0, anchor.AbsoluteSize.X + 4, 0.5, 0)
	end)

	button.MouseEnter:Connect(function()
		if not UserInputService.TouchEnabled then
			show(button, text, opts.Accent)
		end
	end)
	button.MouseLeave:Connect(function()
		if activeHost == button then
			hide()
		end
	end)
	-- Touch: tapping toggles. A tap-anywhere-to-dismiss handler would race
	-- this Activated (both fire for the same tap, in an order Roblox does
	-- not guarantee), so the bubble instead auto-dismisses on a timer — the
	-- deterministic option, and long enough to read one short sentence.
	button.Activated:Connect(function()
		if activeHost == button then
			hide()
			return
		end
		show(button, text, opts.Accent)
		if UserInputService.TouchEnabled then
			task.delay(TOUCH_VISIBLE_SECONDS, function()
				if activeHost == button then
					hide()
				end
			end)
		end
	end)
	button.Destroying:Once(function()
		if activeHost == button then
			hide()
		end
	end)

	return button
end

Tooltip.Hide = hide

return Tooltip
