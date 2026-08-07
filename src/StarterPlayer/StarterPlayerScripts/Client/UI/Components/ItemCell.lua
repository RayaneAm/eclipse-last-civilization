--!strict
-- Icon + name + quantity badge + optional action button, used by the
-- Inventory grid (owned items) and the Crafting tab (recipe ingredient rows).

local Theme = require(script.Parent.Parent.Theme)
local Shadow = require(script.Parent.Parent.Shadow)

local ItemCell = {}

export type ItemCellOptions = {
	Name: string?,
	Icon: string,
	Label: string,
	AccentColor: Color3?,
	Size: UDim2?,
	LayoutOrder: number?,
	BadgeText: string?,
	BadgeColor: Color3?,
	Parent: Instance?,
}

-- Returns (cell, actionSlot). `actionSlot` is an empty Frame reserved at the
-- bottom of the cell for the caller to parent an Equip/Craft Button or a
-- status Pill into, so callers don't need to know this component's internal
-- layout to attach an action.
function ItemCell.new(options: ItemCellOptions): (Frame, Frame)
	local accentColor = options.AccentColor or Theme.Colors.Brand

	local cell = Instance.new("Frame")
	cell.Name = options.Name or "ItemCell"
	cell.Size = options.Size or UDim2.fromOffset(96, 128)
	cell.LayoutOrder = options.LayoutOrder or 0
	cell.BackgroundColor3 = Theme.Colors.PanelBackground
	cell.BackgroundTransparency = Theme.Transparency.PanelBackground
	cell.BorderSizePixel = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.Corner.Medium
	corner.Parent = cell

	local stroke = Instance.new("UIStroke")
	stroke.Color = accentColor
	stroke.Thickness = 1.5
	stroke.Transparency = Theme.Transparency.StrokeSubtle
	stroke.Parent = cell

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, Theme.Spacing.XXS)
	layout.Parent = cell

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, Theme.Spacing.S)
	padding.PaddingBottom = UDim.new(0, Theme.Spacing.S)
	padding.Parent = cell

	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.Size = UDim2.new(1, 0, 0, 40)
	icon.LayoutOrder = 1
	icon.BackgroundTransparency = 1
	icon.Font = Enum.Font.GothamBold
	icon.TextSize = 30
	icon.TextColor3 = Theme.Colors.TextPrimary
	icon.TextStrokeColor3 = Color3.new(0, 0, 0)
	icon.TextStrokeTransparency = 0.6
	icon.Text = options.Icon
	icon.Parent = cell

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(1, -Theme.Spacing.S, 0, 16)
	label.LayoutOrder = 2
	label.BackgroundTransparency = 1
	label.Font = Theme.Font.Label.Font
	label.TextSize = Theme.Font.Label.Size
	label.TextColor3 = Theme.Colors.TextSecondary
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Text = options.Label
	label.Parent = cell

	if options.BadgeText then
		local badge = Instance.new("TextLabel")
		badge.Name = "Badge"
		badge.Size = UDim2.new(1, 0, 0, 14)
		badge.LayoutOrder = 3
		badge.BackgroundTransparency = 1
		badge.Font = Theme.Font.Caption.Font
		badge.TextSize = Theme.Font.Caption.Size
		badge.TextColor3 = options.BadgeColor or Theme.Colors.TextMuted
		badge.Text = options.BadgeText
		badge.Parent = cell
	end

	local actionSlot = Instance.new("Frame")
	actionSlot.Name = "ActionSlot"
	actionSlot.AutomaticSize = Enum.AutomaticSize.Y
	actionSlot.Size = UDim2.new(1, 0, 0, 0)
	actionSlot.LayoutOrder = 4
	actionSlot.BackgroundTransparency = 1
	actionSlot.Parent = cell

	cell.Parent = options.Parent

	Shadow.Attach(cell)

	return cell, actionSlot
end

return ItemCell
