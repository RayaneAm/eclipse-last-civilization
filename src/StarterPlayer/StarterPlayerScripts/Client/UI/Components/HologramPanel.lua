--!strict
-- World-space BillboardGui composite for proximity-triggered info panels
-- (biome gates, Haven facilities, the Quest Giver). Generalizes the panel
-- GateController just established this session (icon+title, description,
-- Recommended Level, Status, Requirement, UIGradient wash) into one reusable
-- constructor so all 3 hologram panels in the game share one implementation
-- instead of 3 near-duplicate hand-rolled ones.

local Theme = require(script.Parent.Parent.Theme)

local HologramPanel = {}

export type HologramSectionKind = "Text" | "Divider"

export type HologramSection = {
	Kind: HologramSectionKind?,
	Name: string,
	Font: Enum.Font?,
	TextSize: number?,
	TextColor3: Color3?,
	Height: number,
	Text: string?,
	Wrapped: boolean?,
	Visible: boolean?,
}

export type HologramPanelOptions = {
	Name: string,
	Size: UDim2,
	StudsOffsetWorldSpace: Vector3?,
	MaxDistance: number?,
	AccentColor: Color3,
	Gradient: boolean?,
	Sections: { HologramSection },
	Parent: Instance,
}

-- Returns (billboard, labels). `labels` maps each non-Divider section's Name
-- to its TextLabel, so callers can update `.Text`/`.Visible` later without
-- FindFirstChild lookups (e.g. GateController's Status/Requirement refresh).
function HologramPanel.new(options: HologramPanelOptions): (BillboardGui, { [string]: TextLabel })
	local billboard = Instance.new("BillboardGui")
	billboard.Name = options.Name
	billboard.Size = options.Size
	billboard.StudsOffsetWorldSpace = options.StudsOffsetWorldSpace or Vector3.new(0, 10, 0)
	billboard.MaxDistance = options.MaxDistance or 45
	billboard.AlwaysOnTop = false
	billboard.LightInfluence = 0

	local background = Instance.new("Frame")
	background.Name = "Background"
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = Theme.Colors.PanelBackground
	background.BackgroundTransparency = Theme.Transparency.PanelBackground
	background.BorderSizePixel = 0
	background.Parent = billboard

	local stroke = Instance.new("UIStroke")
	stroke.Color = options.AccentColor
	stroke.Thickness = 1.5
	stroke.Transparency = Theme.Transparency.StrokeDefault
	stroke.Parent = background

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.Corner.Medium
	corner.Parent = background

	if options.Gradient ~= false then
		local gradient = Instance.new("UIGradient")
		gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), options.AccentColor)
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, Theme.Transparency.GradientNear),
			NumberSequenceKeypoint.new(1, Theme.Transparency.GradientFar),
		})
		gradient.Rotation = 90
		gradient.Parent = background
	end

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, Theme.Spacing.S)
	padding.PaddingRight = UDim.new(0, Theme.Spacing.S)
	padding.PaddingTop = UDim.new(0, Theme.Spacing.S)
	padding.PaddingBottom = UDim.new(0, Theme.Spacing.S)
	padding.Parent = background

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 3)
	layout.Parent = background

	local labels: { [string]: TextLabel } = {}

	for index, section in options.Sections do
		if section.Kind == "Divider" then
			local divider = Instance.new("Frame")
			divider.Name = section.Name
			divider.Size = UDim2.new(1, 0, 0, section.Height)
			divider.BackgroundColor3 = options.AccentColor
			divider.BackgroundTransparency = 0.5
			divider.BorderSizePixel = 0
			divider.LayoutOrder = index
			divider.Visible = section.Visible ~= false
			divider.Parent = background
		else
			local label = Instance.new("TextLabel")
			label.Name = section.Name
			label.BackgroundTransparency = 1
			label.Size = UDim2.new(1, 0, 0, section.Height)
			label.Font = section.Font or Theme.Font.Body.Font
			label.TextSize = section.TextSize or Theme.Font.Body.Size
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.TextYAlignment = Enum.TextYAlignment.Top
			label.TextColor3 = section.TextColor3 or Theme.Colors.TextPrimary
			label.TextWrapped = section.Wrapped == true
			label.Text = section.Text or ""
			label.LayoutOrder = index
			label.Visible = section.Visible ~= false
			label.Parent = background
			labels[section.Name] = label
		end
	end

	billboard.Parent = options.Parent

	return billboard, labels
end

return HologramPanel
