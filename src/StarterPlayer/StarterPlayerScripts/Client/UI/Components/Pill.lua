--!strict
-- Small rounded chip/badge: currency readout, tier readout, "EQUIPPED"
-- status, per-ingredient affordability ("2/2 Wood"). Auto-sized to its text.

local Theme = require(script.Parent.Parent.Theme)

local Pill = {}

export type PillOptions = {
	Name: string?,
	Text: string,
	AccentColor: Color3?,
	TextColor3: Color3?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	Parent: Instance?,
}

-- Returns (container, textLabel). Use Pill.SetText(container, text) to update.
function Pill.new(options: PillOptions): (Frame, TextLabel)
	local accentColor = options.AccentColor or Theme.Colors.Brand

	local pill = Instance.new("Frame")
	pill.Name = options.Name or "Pill"
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.Size = UDim2.new(0, 0, 0, 26)
	pill.Position = options.Position or UDim2.fromScale(0, 0)
	pill.AnchorPoint = options.AnchorPoint or Vector2.new(0, 0)
	pill.LayoutOrder = options.LayoutOrder or 0
	pill.BackgroundColor3 = Theme.Colors.PanelBackground
	pill.BackgroundTransparency = Theme.Transparency.PanelBackground
	pill.BorderSizePixel = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.Corner.Pill
	corner.Parent = pill

	local stroke = Instance.new("UIStroke")
	stroke.Color = accentColor
	stroke.Thickness = 1
	stroke.Transparency = Theme.Transparency.StrokeSubtle
	stroke.Parent = pill

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, Theme.Spacing.M)
	padding.PaddingRight = UDim.new(0, Theme.Spacing.M)
	padding.Parent = pill

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.new(0, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = Theme.Font.Label.Font
	label.TextSize = Theme.Font.Label.Size
	label.TextColor3 = options.TextColor3 or Theme.Colors.TextPrimary
	label.Text = options.Text
	label.Parent = pill

	pill.Parent = options.Parent

	return pill, label
end

function Pill.SetText(pill: Frame, text: string)
	local label = pill:FindFirstChild("Text") :: TextLabel?
	if label then
		label.Text = text
	end
end

return Pill
