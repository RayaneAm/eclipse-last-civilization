--!strict
-- A labelled meter: caption, right-aligned value readout, and a chunky fill
-- bar underneath. The most repeated shape in the facility UI (settlement
-- progress, power, storage, fuel, wall integrity, production progress).
--
-- Bar heights and the value's type weight were both increased in the visual
-- rebuild: a meter is a headline number in a base game, and the previous
-- 10px bar with label-sized text read as a secondary detail.

local Theme = require(script.Parent.Parent.Theme)
local ProgressBar = require(script.Parent.ProgressBar)
local Tooltip = require(script.Parent.Tooltip)

local MeterRow = {}

export type MeterRowOptions = {
	Name: string?,
	Label: string,
	Value: string?,
	Progress: number,
	Accent: Color3?,
	ValueColor: Color3?,
	Info: string?,
	Compact: boolean?,
	LayoutOrder: number?,
	Parent: Instance?,
}

function MeterRow.new(options: MeterRowOptions): (Frame, (fraction: number, animated: boolean?) -> (), (value: string) -> ())
	local accent = options.Accent or Theme.Colors.Brand
	local barHeight = if options.Compact then 10 else 16
	local height = if options.Compact then 34 else 48

	local row = Instance.new("Frame")
	row.Name = options.Name or "MeterRow"
	row.Size = UDim2.new(1, 0, 0, height)
	row.LayoutOrder = options.LayoutOrder or 0
	row.BackgroundTransparency = 1

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.new(0, 0, 0, 18)
	label.BackgroundTransparency = 1
	label.Font = Theme.Font.Label.Font
	label.TextSize = Theme.Font.Label.Size
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Theme.Colors.TextSecondary
	label.Text = string.upper(options.Label)
	label.Parent = row

	local valueLabel = Instance.new("TextLabel")
	valueLabel.Name = "Value"
	valueLabel.AnchorPoint = Vector2.new(1, 0)
	valueLabel.Position = UDim2.fromScale(1, 0)
	valueLabel.Size = UDim2.new(0.55, 0, 0, 20)
	valueLabel.BackgroundTransparency = 1
	valueLabel.Font = Theme.Font.Stat.Font
	valueLabel.TextSize = if options.Compact then Theme.Font.Heading.Size else Theme.Font.Stat.Size
	valueLabel.TextXAlignment = Enum.TextXAlignment.Right
	valueLabel.TextColor3 = options.ValueColor or Theme.Colors.TextPrimary
	valueLabel.Text = options.Value or ""
	valueLabel.Visible = options.Value ~= nil
	valueLabel.Parent = row

	if options.Info then
		Tooltip.Attach(row, options.Info, { Anchor = label, Accent = accent })
	end

	local _track, setProgress = ProgressBar.new({
		Name = "Bar",
		Size = UDim2.new(1, 0, 0, barHeight),
		Position = UDim2.new(0, 0, 0, height - barHeight),
		AccentColor = accent,
		InitialProgress = options.Progress,
		Parent = row,
	})

	local function setValue(value: string)
		valueLabel.Text = value
		valueLabel.Visible = value ~= ""
	end

	row.Parent = options.Parent
	return row, setProgress, setValue
end

return MeterRow
