--!strict
-- Small colored icon badge for a resource/item, driven by ItemIconConfig
-- (Phase 4A.1 correction) — used everywhere a cost, reward, or offer needs
-- to show WHAT a resource is without relying on plain text alone. Never
-- color-only: the glyph itself (emoji or monogram) is always legible text,
-- and an optional caption below adds the full item name for full
-- accessibility (screen-reader-equivalent — this project has no hover-only
-- tooltip system, so the caption IS the accessible label).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemIconConfig = require(ReplicatedStorage.Shared.Config.ItemIconConfig)
local Theme = require(script.Parent.Parent.Theme)

local ItemIcon = {}

export type ItemIconOptions = {
	Name: string?,
	ItemId: string,
	Label: string?, -- shown as a small caption under the badge when provided
	Size: UDim2?,
	LayoutOrder: number?,
	Parent: Instance?,
}

function ItemIcon.new(options: ItemIconOptions): Frame
	local entry = ItemIconConfig.Get(options.ItemId)
	local badgeSize = options.Size or UDim2.fromOffset(32, 32)

	local container = Instance.new("Frame")
	container.Name = options.Name or "ItemIcon"
	container.AutomaticSize = Enum.AutomaticSize.Y
	container.Size = UDim2.new(badgeSize.X.Scale, badgeSize.X.Offset, 0, 0)
	container.LayoutOrder = options.LayoutOrder or 0
	container.BackgroundTransparency = 1

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, Theme.Spacing.XXS)
	layout.Parent = container

	local badge = Instance.new("Frame")
	badge.Name = "Badge"
	badge.Size = badgeSize
	badge.LayoutOrder = 1
	badge.BackgroundColor3 = entry.AccentColor
	badge.BackgroundTransparency = 0.75
	badge.BorderSizePixel = 0
	badge.Parent = container

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.Corner.Small
	corner.Parent = badge

	local stroke = Instance.new("UIStroke")
	stroke.Color = entry.AccentColor
	stroke.Thickness = 1
	stroke.Transparency = Theme.Transparency.StrokeSubtle
	stroke.Parent = badge

	local glyph = Instance.new("TextLabel")
	glyph.Name = "Glyph"
	glyph.BackgroundTransparency = 1
	glyph.Size = UDim2.fromScale(1, 1)
	glyph.Font = Enum.Font.GothamBold
	glyph.TextScaled = true
	glyph.TextColor3 = entry.AccentColor
	glyph.Text = entry.Glyph
	local glyphPadding = Instance.new("UIPadding")
	glyphPadding.PaddingLeft = UDim.new(0, 3)
	glyphPadding.PaddingRight = UDim.new(0, 3)
	glyphPadding.PaddingTop = UDim.new(0, 3)
	glyphPadding.PaddingBottom = UDim.new(0, 3)
	glyphPadding.Parent = glyph
	glyph.Parent = badge

	if options.Label then
		local caption = Instance.new("TextLabel")
		caption.Name = "Caption"
		caption.AutomaticSize = Enum.AutomaticSize.XY
		caption.Size = UDim2.new(0, 0, 0, 14)
		caption.LayoutOrder = 2
		caption.BackgroundTransparency = 1
		caption.Font = Theme.Font.Caption.Font
		caption.TextSize = Theme.Font.Caption.Size
		caption.TextColor3 = Theme.Colors.TextMuted
		caption.Text = options.Label
		caption.Parent = container
	end

	container.Parent = options.Parent
	return container
end

return ItemIcon
