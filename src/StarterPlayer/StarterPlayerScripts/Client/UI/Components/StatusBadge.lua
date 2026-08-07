--!strict
-- Small status pill ("Locked", "Available", "Owned", "Recommended", "New",
-- "Tier Required") — Phase 4A.1 correction, used in the corner of OfferCard
-- and any other card needing a compact state indicator instead of another
-- full-outline box.

local Theme = require(script.Parent.Parent.Theme)

local StatusBadge = {}

export type StatusBadgeVariant = "Locked" | "Available" | "Owned" | "Info" | "Recommended"

export type StatusBadgeOptions = {
	Text: string,
	Variant: StatusBadgeVariant?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	Parent: Instance?,
}

local VARIANT_COLOR: { [StatusBadgeVariant]: Color3 } = {
	Locked = Theme.Colors.TextMuted,
	Available = Theme.Colors.Success,
	Owned = Theme.Colors.BrandLight,
	Info = Theme.Colors.Brand,
	Recommended = Color3.fromRGB(255, 190, 90),
}

function StatusBadge.new(options: StatusBadgeOptions): Frame
	local variant = options.Variant or "Info"
	local color = VARIANT_COLOR[variant]

	local pill = Instance.new("Frame")
	pill.Name = "StatusBadge"
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.Size = UDim2.new(0, 0, 0, 20)
	pill.Position = options.Position or UDim2.fromScale(0, 0)
	pill.AnchorPoint = options.AnchorPoint or Vector2.new(0, 0)
	pill.LayoutOrder = options.LayoutOrder or 0
	pill.BackgroundColor3 = color
	pill.BackgroundTransparency = 0.8
	pill.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.Corner.Pill
	corner.Parent = pill

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, Theme.Spacing.S)
	padding.PaddingRight = UDim.new(0, Theme.Spacing.S)
	padding.Parent = pill

	local label = Instance.new("TextLabel")
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.new(0, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = Theme.Font.Caption.Font
	label.TextSize = Theme.Font.Caption.Size
	label.TextColor3 = color
	label.Text = string.upper(options.Text)
	label.Parent = pill

	pill.Parent = options.Parent
	return pill
end

return StatusBadge
