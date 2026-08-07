--!strict
-- Rounded-square icon tile with a large glyph and an optional label pill
-- below it — inspired by the reference image's quality bar (flat colored
-- icon tile + label) without copying its layout or artwork. Used for the
-- HUD menu button and every inventory item cell.

local Theme = require(script.Parent.Parent.Theme)
local Motion = require(script.Parent.Parent.Motion)
local Interaction = require(script.Parent.Parent.Interaction)
local Shadow = require(script.Parent.Parent.Shadow)

local IconTile = {}

export type IconTileOptions = {
	Name: string?,
	Icon: string,
	Label: string?,
	AccentColor: Color3?,
	TileSize: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	Disabled: boolean?,
	-- Continuous ambient stroke glow — off by default (see Theme.Motion.Pulse
	-- doc comment: "don't overuse effects"), opt in only for something
	-- meaningfully special.
	Pulse: boolean?,
	OnActivated: (() -> ())?,
	Parent: Instance?,
}

-- Returns (container, tileButton). The container includes the optional label
-- pill beneath the tile; the button is the actual interactive glyph tile.
function IconTile.new(options: IconTileOptions): (Frame, TextButton)
	local accentColor = options.AccentColor or Theme.Colors.Brand
	local tileSize = options.TileSize or UDim2.fromOffset(84, 84)

	local container = Instance.new("Frame")
	container.Name = options.Name or "IconTile"
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

	local tile = Instance.new("TextButton")
	tile.Name = "Tile"
	tile.Size = tileSize
	tile.LayoutOrder = 1
	tile.AutoButtonColor = false
	tile.Text = ""
	tile.BackgroundColor3 = Theme.Colors.PanelBackground
	tile.BackgroundTransparency = Theme.Transparency.PanelBackground
	tile.BorderSizePixel = 0
	tile.Parent = container

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.Corner.Large
	corner.Parent = tile

	local stroke = Instance.new("UIStroke")
	stroke.Name = "Stroke"
	stroke.Color = accentColor
	stroke.Thickness = 1.5
	stroke.Transparency = Theme.Transparency.StrokeDefault
	stroke.Parent = tile

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), accentColor)
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, Theme.Transparency.GradientNear),
		NumberSequenceKeypoint.new(1, Theme.Transparency.GradientFar),
	})
	gradient.Rotation = 90
	gradient.Parent = tile

	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromScale(1, 1)
	icon.Font = Enum.Font.GothamBold
	icon.TextSize = 34
	icon.TextColor3 = Theme.Colors.TextPrimary
	icon.TextStrokeColor3 = Color3.new(0, 0, 0)
	icon.TextStrokeTransparency = 0.6
	icon.Text = options.Icon
	icon.Parent = tile

	if options.Label then
		local pill = Instance.new("Frame")
		pill.Name = "LabelPill"
		pill.AutomaticSize = Enum.AutomaticSize.X
		pill.Size = UDim2.new(0, 0, 0, 20)
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
		pillLabel.Font = Theme.Font.Label.Font
		pillLabel.TextSize = Theme.Font.Label.Size
		pillLabel.TextColor3 = Theme.Colors.TextSecondary
		pillLabel.Text = options.Label
		pillLabel.Parent = pill
	end

	container.Parent = options.Parent

	Shadow.Attach(tile)

	if options.Pulse then
		Motion.Tween(stroke, "Pulse", Theme.Motion.Pulse, { Transparency = Theme.Transparency.StrokeBright })
	end

	local cleanup = Interaction.Bind(tile, { OnActivated = options.OnActivated })
	tile.Destroying:Once(cleanup)

	if options.Disabled then
		Interaction.SetDisabled(tile, true)
	end

	return container, tile
end

return IconTile
