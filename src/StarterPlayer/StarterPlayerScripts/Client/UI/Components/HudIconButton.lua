--!strict
-- HUD shortcut button. IconTile.luau's permanent opaque-card look (fill +
-- UIStroke + gradient wash) is correct for inventory/grid item cells but
-- wrong for a row of HUD shortcuts — this is the separate, dedicated
-- component for that context. IconTile itself is left unchanged for its
-- existing (grid-cell) uses.
--
-- Rest state is a real filled circular chip (BackgroundTransparency ~0.3,
-- the button's own accent color, NO stroke — see Theme.luau's art-direction
-- header) rather than fully invisible: HUD icons need presence of their own
-- since they float directly over the busy 3D world, not just a hover
-- reaction. Uses Theme.Shadow.Hero — the strongest depth tier in the
-- system — for the same reason. Hover/press deepen the fill further.
-- Optional small notification Badge (e.g. "!") for a limited-time offer.

local Theme = require(script.Parent.Parent.Theme)
local Motion = require(script.Parent.Parent.Motion)
local Interaction = require(script.Parent.Parent.Interaction)
local Shadow = require(script.Parent.Parent.Shadow)

local HudIconButton = {}

export type HudIconButtonOptions = {
	Name: string?,
	Icon: string,
	Label: string?,
	AccentColor: Color3?,
	Badge: string?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	Pulse: boolean?,
	OnActivated: (() -> ())?,
	Parent: Instance?,
}

local REST_TRANSPARENCY = 0.3
local HOVER_TRANSPARENCY = 0.12

-- Returns (container, button) — mirrors IconTile's return shape so existing
-- call sites migrate with minimal churn.
function HudIconButton.new(options: HudIconButtonOptions): (Frame, TextButton)
	local accentColor = options.AccentColor or Theme.Colors.Brand
	local tileSize = options.Size or UDim2.fromOffset(56, 56)

	local container = Instance.new("Frame")
	container.Name = options.Name or "HudIconButton"
	container.AutomaticSize = Enum.AutomaticSize.Y
	container.Size = UDim2.new(tileSize.X.Scale, tileSize.X.Offset, 0, 0)
	container.Position = options.Position or UDim2.fromScale(0, 0)
	container.AnchorPoint = options.AnchorPoint or Vector2.new(0, 0)
	container.LayoutOrder = options.LayoutOrder or 0
	container.BackgroundTransparency = 1

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, Theme.Spacing.XS)
	layout.Parent = container

	local button = Instance.new("TextButton")
	button.Name = "Button"
	button.Size = tileSize
	button.LayoutOrder = 1
	button.AutoButtonColor = false
	button.Text = ""
	button.BackgroundColor3 = accentColor
	button.BackgroundTransparency = REST_TRANSPARENCY
	button.BorderSizePixel = 0
	button.Parent = container

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.Corner.Pill
	corner.Parent = button

	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromScale(1, 1)
	icon.Font = Enum.Font.GothamBold
	icon.TextSize = 30
	icon.TextColor3 = Theme.Colors.TextPrimary
	icon.TextStrokeColor3 = Color3.new(0, 0, 0)
	icon.TextStrokeTransparency = 0.5
	icon.Text = options.Icon
	icon.Parent = button

	if options.Badge then
		local badge = Instance.new("Frame")
		badge.Name = "Badge"
		badge.Size = UDim2.fromOffset(18, 18)
		badge.AnchorPoint = Vector2.new(1, 0)
		badge.Position = UDim2.new(1, 4, 0, -4)
		badge.BackgroundColor3 = Theme.Colors.Danger
		badge.BorderSizePixel = 0
		badge.ZIndex = button.ZIndex + 1
		badge.Parent = button

		local badgeCorner = Instance.new("UICorner")
		badgeCorner.CornerRadius = Theme.Corner.Pill
		badgeCorner.Parent = badge

		local badgeLabel = Instance.new("TextLabel")
		badgeLabel.BackgroundTransparency = 1
		badgeLabel.Size = UDim2.fromScale(1, 1)
		badgeLabel.Font = Theme.Font.Caption.Font
		badgeLabel.TextSize = 11
		badgeLabel.TextColor3 = Theme.Colors.TextPrimary
		badgeLabel.Text = options.Badge
		badgeLabel.ZIndex = badge.ZIndex + 1
		badgeLabel.Parent = badge
	end

	if options.Label then
		local pill = Instance.new("Frame")
		pill.Name = "LabelPill"
		pill.AutomaticSize = Enum.AutomaticSize.X
		pill.Size = UDim2.new(0, 0, 0, 18)
		pill.LayoutOrder = 2
		pill.BackgroundColor3 = Theme.Colors.PanelBackground
		pill.BackgroundTransparency = Theme.Transparency.PanelBackground
		pill.BorderSizePixel = 0
		pill.Parent = container

		local pillCorner = Instance.new("UICorner")
		pillCorner.CornerRadius = Theme.Corner.Pill
		pillCorner.Parent = pill

		local pillPadding = Instance.new("UIPadding")
		pillPadding.PaddingLeft = UDim.new(0, Theme.Spacing.S)
		pillPadding.PaddingRight = UDim.new(0, Theme.Spacing.S)
		pillPadding.Parent = pill

		local pillLabel = Instance.new("TextLabel")
		pillLabel.Name = "Text"
		pillLabel.AutomaticSize = Enum.AutomaticSize.X
		pillLabel.Size = UDim2.new(0, 0, 1, 0)
		pillLabel.BackgroundTransparency = 1
		pillLabel.Font = Theme.Font.Caption.Font
		pillLabel.TextSize = Theme.Font.Caption.Size
		pillLabel.TextColor3 = Theme.Colors.TextSecondary
		pillLabel.Text = options.Label
		pillLabel.Parent = pill
	end

	container.Parent = options.Parent
	Shadow.Attach(button, { Transparency = Theme.Shadow.Hero.Transparency, Offset = Theme.Shadow.Hero.Offset })

	local function applyHover()
		Motion.Tween(button, "Wash", Theme.Motion.HoverIn, { BackgroundTransparency = HOVER_TRANSPARENCY })
	end
	local function clearHover()
		Motion.Tween(button, "Wash", Theme.Motion.HoverOut, { BackgroundTransparency = REST_TRANSPARENCY })
	end
	button.MouseEnter:Connect(applyHover)
	button.MouseLeave:Connect(clearHover)
	button.SelectionGained:Connect(applyHover)
	button.SelectionLost:Connect(clearHover)

	if options.Pulse then
		Motion.Tween(icon, "Pulse", Theme.Motion.Pulse, { TextTransparency = 0.35 })
	end

	local cleanup = Interaction.Bind(button, { OnActivated = options.OnActivated })
	button.Destroying:Once(cleanup)

	return container, button
end

return HudIconButton
