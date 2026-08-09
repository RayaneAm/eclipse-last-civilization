--!strict
-- The chunky icon holder every resource, reward and offer is shown in: a
-- rounded accent-tinted tile with a dark outline, containing a VECTOR icon
-- drawn by IconArt.
--
-- This replaces the previous text-glyph badge. That version rendered each
-- item as an emoji or a two-letter monogram, which had two failures:
--
--   * Recent emoji (wood, rock, axe — all Emoji 12/13, 2019-2020) have no
--     glyph in older client system fonts and rendered as an empty box. That
--     is the "Wood is a blank rectangle" bug; see IconArt's header for the
--     full diagnosis.
--   * The monogram fallbacks ("Fb", "Rs", "Hm"...) always rendered but are
--     not icons — a screen full of letter pairs reads as a spreadsheet.
--
-- A drawn icon has no font dependency, no asset to load, no permission to
-- get wrong and no per-platform variation. It cannot fail to appear.
--
-- The holder itself is a real designed object: accent fill, gloss, dark
-- outline and a bottom lip, so an icon reads as a tactile game element
-- rather than a picture floating on the panel.

local Theme = require(script.Parent.Parent.Theme)
local IconArt = require(script.Parent.Parent.IconArt)

local ItemIcon = {}

export type ItemIconOptions = {
	Name: string?,
	ItemId: string,
	-- Use a named facility/UI glyph (see IconArt's `glyphs`) instead of an
	-- item id. Takes precedence over ItemId when set.
	Glyph: string?,
	Label: string?, -- small caption under the tile
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	-- Flat tiles (inside an already-outlined row) skip the outline + lip so
	-- the UI does not stack borders.
	Flat: boolean?,
	AccentOverride: Color3?,
	Parent: Instance?,
}

function ItemIcon.new(options: ItemIconOptions): Frame
	local definition = if options.Glyph then IconArt.GetGlyph(options.Glyph) else IconArt.GetItem(options.ItemId)
	local accent = options.AccentOverride or definition.Accent
	local tileSize = options.Size or UDim2.fromOffset(36, 36)
	local flat = options.Flat == true

	local container = Instance.new("Frame")
	container.Name = options.Name or "ItemIcon"
	container.AutomaticSize = if options.Label then Enum.AutomaticSize.Y else Enum.AutomaticSize.None
	container.Size = if options.Label then UDim2.new(tileSize.X.Scale, tileSize.X.Offset, 0, 0) else tileSize
	container.Position = options.Position or UDim2.fromScale(0, 0)
	container.AnchorPoint = options.AnchorPoint or Vector2.new(0, 0)
	container.LayoutOrder = options.LayoutOrder or 0
	container.BackgroundTransparency = 1

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, Theme.Spacing.XXS)
	layout.Parent = container

	local tile = Instance.new("Frame")
	tile.Name = "Tile"
	tile.Size = tileSize
	tile.LayoutOrder = 1
	-- A deep, desaturated version of the accent: bright enough to identify
	-- the item family, dark enough that the icon on top stays legible.
	tile.BackgroundColor3 = accent:Lerp(Theme.Colors.Void, 0.62)
	tile.BorderSizePixel = 0
	tile.Parent = container

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.Corner.Medium
	corner.Parent = tile

	if not flat then
		Theme.Outline(tile, Theme.Stroke.Card)
	end

	-- A soft accent glow behind the art lifts it off the tile without needing
	-- a real light or blur.
	local glow = Instance.new("Frame")
	glow.Name = "Glow"
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.fromScale(0.82, 0.82)
	glow.BackgroundColor3 = accent
	glow.BackgroundTransparency = 0.78
	glow.BorderSizePixel = 0
	glow.Parent = tile
	local glowCorner = Instance.new("UICorner")
	glowCorner.CornerRadius = UDim.new(0.5, 0)
	glowCorner.Parent = glow

	-- The art sits inside padding so it never touches the tile's rounded
	-- corners, which is what made the old badge look cramped.
	local artHost = Instance.new("Frame")
	artHost.Name = "Art"
	artHost.AnchorPoint = Vector2.new(0.5, 0.5)
	artHost.Position = UDim2.fromScale(0.5, 0.5)
	artHost.Size = UDim2.fromScale(0.68, 0.68)
	artHost.BackgroundTransparency = 1
	artHost.Parent = tile

	IconArt.Render(artHost, definition)

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
