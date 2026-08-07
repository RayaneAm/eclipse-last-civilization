--!strict
-- Compact requirement status line ("Base Lv10", "Frozen Wasteland access")
-- with a met/unmet visual indicator — Phase 4A.1 correction, used by
-- OfferCard and Base UI blueprint-pad previews.

local Theme = require(script.Parent.Parent.Theme)

local RequirementRow = {}

export type RequirementRowOptions = {
	Name: string?,
	Text: string,
	Met: boolean,
	LayoutOrder: number?,
	Parent: Instance?,
}

function RequirementRow.new(options: RequirementRowOptions): Frame
	local row = Instance.new("Frame")
	row.Name = options.Name or "RequirementRow"
	row.AutomaticSize = Enum.AutomaticSize.XY
	row.Size = UDim2.new(0, 0, 0, 18)
	row.LayoutOrder = options.LayoutOrder or 0
	row.BackgroundTransparency = 1

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, Theme.Spacing.XXS)
	layout.Parent = row

	local dot = Instance.new("Frame")
	dot.Size = UDim2.fromOffset(8, 8)
	dot.LayoutOrder = 1
	dot.BackgroundColor3 = if options.Met then Theme.Colors.Success else Theme.Colors.Danger
	dot.BorderSizePixel = 0
	local dotCorner = Instance.new("UICorner")
	dotCorner.CornerRadius = Theme.Corner.Pill
	dotCorner.Parent = dot
	dot.Parent = row

	local label = Instance.new("TextLabel")
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.new(0, 0, 0, 16)
	label.LayoutOrder = 2
	label.BackgroundTransparency = 1
	label.Font = Theme.Font.Caption.Font
	label.TextSize = Theme.Font.Caption.Size
	label.TextColor3 = if options.Met then Theme.Colors.TextSecondary else Theme.Colors.Danger
	label.Text = options.Text
	label.Parent = row

	row.Parent = options.Parent
	return row
end

return RequirementRow
