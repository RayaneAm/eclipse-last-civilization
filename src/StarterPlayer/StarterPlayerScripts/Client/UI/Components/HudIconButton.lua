--!strict
-- HUD shortcut button. IconTile.luau's permanent opaque-card look (fill +
-- UIStroke + gradient wash) is correct for inventory/grid item cells but
-- wrong for a row of HUD shortcuts — this is the separate, dedicated
-- component for that context. IconTile itself is left unchanged for its
-- existing (grid-cell) uses.
--
-- Compact horizontal cards keep icon and label readable over the game world.
-- Accent color is limited to the icon plate and side rail so color communicates
-- purpose without turning every shortcut into a different floating circle.

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

local REST_TRANSPARENCY = 0.24
local HOVER_TRANSPARENCY = 0.08
local ACTIVE_TRANSPARENCY = 0.02

function HudIconButton.SetActive(button: TextButton, active: boolean)
	button:SetAttribute("Active", active)

	local accent = button:FindFirstChild("Accent")
	if accent and accent:IsA("Frame") then
		Motion.Tween(accent, "ActiveWidth", Theme.Motion.HoverIn, {
			Size = UDim2.new(0, if active then 5 else 3, 1, -16),
		})
	end

	local iconPlate = button:FindFirstChild("IconPlate")
	if iconPlate and iconPlate:IsA("Frame") then
		Motion.Tween(iconPlate, "ActivePlate", Theme.Motion.HoverIn, {
			BackgroundTransparency = if active then 0.05 else 0.3,
		})
	end

	local label = button:FindFirstChild("Label")
	if label and label:IsA("TextLabel") then
		label.Font = if active then Enum.Font.GothamBold else Theme.Font.Label.Font
		label.TextColor3 = if active then Theme.Colors.TextPrimary else Theme.Colors.TextSecondary
	end

	Motion.Tween(button, "ActiveWash", Theme.Motion.HoverIn, {
		BackgroundTransparency = if active then ACTIVE_TRANSPARENCY else REST_TRANSPARENCY,
	})
end

-- Returns (container, button) — mirrors IconTile's return shape so existing
-- call sites migrate with minimal churn.
function HudIconButton.new(options: HudIconButtonOptions): (Frame, TextButton)
	local accentColor = options.AccentColor or Theme.Colors.Brand
	local tileSize = options.Size or UDim2.fromOffset(180, 52)

	local container = Instance.new("Frame")
	container.Name = options.Name or "HudIconButton"
	container.Size = tileSize
	container.Position = options.Position or UDim2.fromScale(0, 0)
	container.AnchorPoint = options.AnchorPoint or Vector2.new(0, 0)
	container.LayoutOrder = options.LayoutOrder or 0
	container.BackgroundTransparency = 1

	local visualGroup = Instance.new("CanvasGroup")
	visualGroup.Name = "VisualGroup"
	visualGroup.Size = UDim2.fromScale(1, 1)
	visualGroup.BackgroundTransparency = 1
	visualGroup.GroupTransparency = 0
	visualGroup.Parent = container

	local button = Instance.new("TextButton")
	button.Name = "Button"
	button.Size = UDim2.fromScale(1, 1)
	button.AutoButtonColor = false
	button.Text = ""
	button.BackgroundColor3 = Theme.Colors.PanelBackground
	button.BackgroundTransparency = REST_TRANSPARENCY
	button.BorderSizePixel = 0
	button:SetAttribute("Active", false)
	button.Parent = visualGroup

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.Corner.Medium
	corner.Parent = button

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Colors.TextMuted
	stroke.Thickness = 1
	stroke.Transparency = 0.72
	stroke.Parent = button

	local accentRail = Instance.new("Frame")
	accentRail.Name = "Accent"
	accentRail.Size = UDim2.new(0, 3, 1, -16)
	accentRail.Position = UDim2.fromOffset(0, 8)
	accentRail.BackgroundColor3 = accentColor
	accentRail.BackgroundTransparency = 0.12
	accentRail.BorderSizePixel = 0
	accentRail.Parent = button

	local railCorner = Instance.new("UICorner")
	railCorner.CornerRadius = Theme.Corner.Pill
	railCorner.Parent = accentRail

	local iconPlate = Instance.new("Frame")
	iconPlate.Name = "IconPlate"
	iconPlate.Size = UDim2.fromOffset(36, 36)
	iconPlate.AnchorPoint = Vector2.new(0, 0.5)
	iconPlate.Position = UDim2.new(0, Theme.Spacing.S, 0.5, 0)
	iconPlate.BackgroundColor3 = accentColor
	iconPlate.BackgroundTransparency = 0.3
	iconPlate.BorderSizePixel = 0
	iconPlate.Parent = button

	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = Theme.Corner.Medium
	iconCorner.Parent = iconPlate

	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromScale(1, 1)
	icon.Font = Enum.Font.GothamBold
	icon.TextSize = 22
	icon.TextColor3 = Theme.Colors.TextPrimary
	icon.TextStrokeColor3 = Color3.new(0, 0, 0)
	icon.TextStrokeTransparency = 0.65
	icon.Text = options.Icon
	icon.Parent = iconPlate

	if options.Badge then
		local badge = Instance.new("Frame")
		badge.Name = "Badge"
		badge.Size = UDim2.fromOffset(16, 16)
		badge.AnchorPoint = Vector2.new(1, 0)
		badge.Position = UDim2.new(1, 5, 0, -5)
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
		badgeLabel.TextSize = 10
		badgeLabel.TextColor3 = Theme.Colors.TextPrimary
		badgeLabel.Text = options.Badge
		badgeLabel.ZIndex = badge.ZIndex + 1
		badgeLabel.Parent = badge
	end

	if options.Label then
		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.Size = UDim2.new(1, -60, 1, 0)
		label.Position = UDim2.fromOffset(54, 0)
		label.BackgroundTransparency = 1
		label.Font = Theme.Font.Label.Font
		label.TextSize = Theme.Font.Label.Size
		label.TextColor3 = Theme.Colors.TextSecondary
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextTruncate = Enum.TextTruncate.AtEnd
		label.Text = options.Label
		label.Parent = button
	end

	container.Parent = options.Parent
	-- The shadow is now inside a layout-neutral container, so it cannot be
	-- mistaken for an extra black button by a parent UIListLayout.
	Shadow.Attach(button, { Transparency = 0.58, Offset = Vector2.new(0, 4) })

	local function applyHover()
		local active = button:GetAttribute("Active") == true
		Motion.Tween(button, "Wash", Theme.Motion.HoverIn, {
			BackgroundTransparency = if active then ACTIVE_TRANSPARENCY else HOVER_TRANSPARENCY,
		})
		Motion.Tween(iconPlate, "HoverPlate", Theme.Motion.HoverIn, {
			BackgroundTransparency = if active then 0.05 else 0.16,
		})
		local label = button:FindFirstChild("Label")
		if label and label:IsA("TextLabel") then
			label.TextColor3 = Theme.Colors.TextPrimary
		end
	end
	local function clearHover()
		local active = button:GetAttribute("Active") == true
		Motion.Tween(button, "Wash", Theme.Motion.HoverOut, {
			BackgroundTransparency = if active then ACTIVE_TRANSPARENCY else REST_TRANSPARENCY,
		})
		Motion.Tween(iconPlate, "HoverPlate", Theme.Motion.HoverOut, {
			BackgroundTransparency = if active then 0.05 else 0.3,
		})
		local label = button:FindFirstChild("Label")
		if label and label:IsA("TextLabel") then
			label.TextColor3 = if active then Theme.Colors.TextPrimary else Theme.Colors.TextSecondary
		end
	end
	button.MouseEnter:Connect(applyHover)
	button.MouseLeave:Connect(clearHover)
	button.SelectionGained:Connect(applyHover)
	button.SelectionLost:Connect(clearHover)

	if options.Pulse then
		Motion.Tween(icon, "Pulse", Theme.Motion.Pulse, { TextTransparency = 0.35 })
	end

	local cleanup = Interaction.Bind(button, {
		HoverScale = 1.02,
		PressScale = 0.98,
		IdleStrokeTransparency = 0.88,
		HoverStrokeTransparency = 0.7,
		PressStrokeTransparency = 0.55,
		OnActivated = options.OnActivated,
	})
	button.Destroying:Once(cleanup)

	return container, button
end

return HudIconButton
