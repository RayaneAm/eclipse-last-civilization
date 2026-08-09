--!strict
-- The label that opens a block inside a facility modal ("COST", "DEFENSE",
-- "SUGGESTED").
--
-- Now carries a short accent bar to its left, which is what turns a line of
-- small grey text into a designed section marker. The previous version was
-- uppercase muted text alone and disappeared into the panel.

local Theme = require(script.Parent.Parent.Theme)
local Tooltip = require(script.Parent.Tooltip)

local SectionHeader = {}

export type SectionHeaderOptions = {
	Text: string,
	Value: string?,
	Accent: Color3?,
	ValueColor: Color3?,
	Info: string?,
	LayoutOrder: number?,
	Parent: Instance?,
}

function SectionHeader.new(options: SectionHeaderOptions): Frame
	local accent = options.Accent or Theme.Colors.BrandLight

	local row = Instance.new("Frame")
	row.Name = "SectionHeader"
	row.Size = UDim2.new(1, 0, 0, 26)
	row.LayoutOrder = options.LayoutOrder or 0
	row.BackgroundTransparency = 1

	local heading = Instance.new("Frame")
	heading.Name = "Heading"
	heading.Size = UDim2.new(if options.Value then 0.45 else 1, if options.Value then -8 else 0, 1, 0)
	heading.BackgroundTransparency = 1
	heading.ClipsDescendants = true
	heading.Parent = row

	local headingLayout = Instance.new("UIListLayout")
	headingLayout.FillDirection = Enum.FillDirection.Horizontal
	headingLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	headingLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	headingLayout.Padding = UDim.new(0, Theme.Spacing.S)
	headingLayout.Parent = heading

	local bar = Instance.new("Frame")
	bar.Name = "AccentBar"
	bar.Size = UDim2.fromOffset(4, 16)
	bar.LayoutOrder = 1
	bar.BackgroundColor3 = accent
	bar.BorderSizePixel = 0
	bar.Parent = heading
	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = Theme.Corner.Pill
	barCorner.Parent = bar

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(1, -(4 + Theme.Spacing.S), 1, 0)
	label.LayoutOrder = 2
	label.BackgroundTransparency = 1
	label.Font = Theme.Font.Label.Font
	label.TextSize = Theme.Font.Label.Size
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.TextColor3 = accent
	label.Text = string.upper(options.Text)
	label.Parent = heading

	if options.Info then
		Tooltip.Attach(row, options.Info, { Anchor = label, Accent = accent })
	end

	if options.Value then
		local value = Instance.new("TextLabel")
		value.Name = "Value"
		value.AnchorPoint = Vector2.new(1, 0)
		value.Position = UDim2.fromScale(1, 0)
		value.Size = UDim2.new(0.6, 0, 1, 0)
		value.BackgroundTransparency = 1
		value.Font = Theme.Font.Stat.Font
		value.TextSize = Theme.Font.Heading.Size
		value.TextXAlignment = Enum.TextXAlignment.Right
		value.TextColor3 = options.ValueColor or Theme.Colors.TextPrimary
		value.Text = options.Value
		value.Parent = row
	end

	row.Parent = options.Parent
	return row
end

return SectionHeader
