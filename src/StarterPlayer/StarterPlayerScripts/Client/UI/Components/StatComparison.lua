--!strict
-- The before/after block that makes an upgrade legible at a glance:
--
--     DURABILITY
--     500        →        850
--
-- Deliberately only renders stats that actually CHANGE. A row whose current
-- and next values are equal carries no decision-making information and is
-- dropped (facility UI brief §14), so an upgrade screen never pads itself
-- with "POWERED  NO → NO".

local Theme = require(script.Parent.Parent.Theme)

local StatComparison = {}

export type StatLine = {
	Label: string,
	Current: string,
	Next: string,
	-- Set false for a stat where a higher number is worse (none today, but
	-- the arrow tint shouldn't have to be rediscovered later).
	HigherIsBetter: boolean?,
}

export type StatComparisonOptions = {
	Stats: { StatLine },
	Accent: Color3?,
	LayoutOrder: number?,
	Parent: Instance?,
}

local function buildRow(parent: Instance, stat: StatLine, accent: Color3, order: number)
	local row = Instance.new("Frame")
	row.Name = `Stat_{stat.Label}`
	row.Size = UDim2.new(1, 0, 0, 40)
	row.LayoutOrder = order
	row.BackgroundTransparency = 1
	row.Parent = parent

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(1, 0, 0, 15)
	label.BackgroundTransparency = 1
	label.Font = Theme.Font.Caption.Font
	label.TextSize = Theme.Font.Caption.Size
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Theme.Colors.TextMuted
	label.Text = string.upper(stat.Label)
	label.Parent = row

	local values = Instance.new("Frame")
	values.Name = "Values"
	values.Position = UDim2.fromOffset(0, 16)
	values.Size = UDim2.new(1, 0, 0, 22)
	values.BackgroundTransparency = 1
	values.Parent = row

	local current = Instance.new("TextLabel")
	current.Name = "Current"
	current.Size = UDim2.new(0.42, 0, 1, 0)
	current.BackgroundTransparency = 1
	current.Font = Theme.Font.Heading.Font
	current.TextSize = Theme.Font.Heading.Size
	current.TextXAlignment = Enum.TextXAlignment.Left
	current.TextColor3 = Theme.Colors.TextMuted
	current.Text = stat.Current
	current.Parent = values

	local arrow = Instance.new("TextLabel")
	arrow.Name = "Arrow"
	arrow.Position = UDim2.fromScale(0.42, 0)
	arrow.Size = UDim2.new(0.16, 0, 1, 0)
	arrow.BackgroundTransparency = 1
	arrow.Font = Theme.Font.Heading.Font
	arrow.TextSize = Theme.Font.Heading.Size
	arrow.TextColor3 = accent
	arrow.Text = "→"
	arrow.Parent = values

	local nextValue = Instance.new("TextLabel")
	nextValue.Name = "Next"
	nextValue.Position = UDim2.fromScale(0.58, 0)
	nextValue.Size = UDim2.new(0.42, 0, 1, 0)
	nextValue.BackgroundTransparency = 1
	nextValue.Font = Theme.Font.Stat.Font
	nextValue.TextSize = Theme.Font.Heading.Size
	nextValue.TextXAlignment = Enum.TextXAlignment.Left
	nextValue.TextColor3 = Theme.Colors.Success
	nextValue.Text = stat.Next
	nextValue.Parent = values
end

-- Returns the container, or nil when every supplied stat was unchanged (so
-- the caller can skip its section header too rather than printing an empty
-- "CHANGES" block).
function StatComparison.new(options: StatComparisonOptions): Frame?
	local accent = options.Accent or Theme.Colors.Brand

	local changed: { StatLine } = {}
	for _, stat in options.Stats do
		if stat.Current ~= stat.Next then
			table.insert(changed, stat)
		end
	end
	if #changed == 0 then
		return nil
	end

	local container = Instance.new("Frame")
	container.Name = "StatComparison"
	container.Size = UDim2.new(1, 0, 0, #changed * 40 + (#changed - 1) * 4)
	container.LayoutOrder = options.LayoutOrder or 0
	container.BackgroundTransparency = 1

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = container

	for index, stat in changed do
		buildRow(container, stat, accent, index)
	end

	container.Parent = options.Parent
	return container
end

-- The headline tier transition shown above the stats:
--
--     WOOD   →   REINFORCED
--     TIER 1     TIER 2
export type TransitionOptions = {
	FromLabel: string,
	FromTier: number,
	ToLabel: string,
	ToTier: number,
	FromColor: Color3?,
	ToColor: Color3?,
	LayoutOrder: number?,
	Parent: Instance?,
}

function StatComparison.Transition(options: TransitionOptions): Frame
	local container = Instance.new("Frame")
	container.Name = "TierTransition"
	container.Size = UDim2.new(1, 0, 0, 46)
	container.LayoutOrder = options.LayoutOrder or 0
	container.BackgroundTransparency = 1

	local function side(name: string, label: string, tier: number, color: Color3, xScale: number, alignment: Enum.TextXAlignment)
		local title = Instance.new("TextLabel")
		title.Name = name
		title.Position = UDim2.fromScale(xScale, 0)
		title.Size = UDim2.new(0.42, 0, 0, 24)
		title.BackgroundTransparency = 1
		title.Font = Theme.Font.Title.Font
		title.TextSize = 18
		title.TextXAlignment = alignment
		title.TextTruncate = Enum.TextTruncate.AtEnd
		title.TextColor3 = color
		title.Text = string.upper(label)
		title.Parent = container

		local tierLabel = Instance.new("TextLabel")
		tierLabel.Name = `{name}Tier`
		tierLabel.Position = UDim2.new(xScale, 0, 0, 26)
		tierLabel.Size = UDim2.new(0.42, 0, 0, 16)
		tierLabel.BackgroundTransparency = 1
		tierLabel.Font = Theme.Font.Caption.Font
		tierLabel.TextSize = Theme.Font.Caption.Size
		tierLabel.TextXAlignment = alignment
		tierLabel.TextColor3 = Theme.Colors.TextMuted
		tierLabel.Text = `TIER {tier}`
		tierLabel.Parent = container
	end

	side("From", options.FromLabel, options.FromTier, options.FromColor or Theme.Colors.TextMuted, 0, Enum.TextXAlignment.Left)
	side("To", options.ToLabel, options.ToTier, options.ToColor or Theme.Colors.TextPrimary, 0.58, Enum.TextXAlignment.Right)

	local arrow = Instance.new("TextLabel")
	arrow.Name = "Arrow"
	arrow.Position = UDim2.fromScale(0.42, 0)
	arrow.Size = UDim2.new(0.16, 0, 0, 24)
	arrow.BackgroundTransparency = 1
	arrow.Font = Theme.Font.Title.Font
	arrow.TextSize = 18
	arrow.TextColor3 = options.ToColor or Theme.Colors.Brand
	arrow.Text = "→"
	arrow.Parent = container

	container.Parent = options.Parent
	return container
end

return StatComparison
