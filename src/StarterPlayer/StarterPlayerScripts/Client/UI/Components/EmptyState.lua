--!strict
-- The "nothing here yet" state. A large vector icon in its own well, a bold
-- title and one short explanatory line, inside a real card.
--
-- Two changes in the visual rebuild:
--   * The icon is IconArt vector art, not a text emoji. The old version set
--     an emoji at TextSize 32 with TextTransparency 0.4, which on clients
--     missing that glyph produced a large empty area above the text — the
--     worst possible version of an empty state.
--   * It is a proper card by default. A bare centered label floating in a
--     dark panel is what made empty screens read as unfinished rather than
--     designed.

local Theme = require(script.Parent.Parent.Theme)
local IconArt = require(script.Parent.Parent.IconArt)
local Surface = require(script.Parent.Surface)

local EmptyState = {}

export type EmptyStateOptions = {
	-- IconArt glyph name (e.g. "Storage", "Production", "Lab").
	Glyph: string?,
	Accent: Color3?,
	Text: string,
	Subtext: string?,
	Card: boolean?,
	Size: UDim2?,
	LayoutOrder: number?,
	Parent: Instance?,
}

function EmptyState.new(options: EmptyStateOptions): Frame
	local useCard = options.Card ~= false

	local host: Instance? = options.Parent
	local root: Frame? = nil
	if useCard then
		local card = Surface.new({
			Name = "EmptyStateCard",
			Size = options.Size or UDim2.new(1, 0, 0, 152),
			LayoutOrder = options.LayoutOrder or 0,
			Parent = options.Parent,
		})
		host = card
		root = card
	end

	local container = Instance.new("Frame")
	container.Name = "EmptyState"
	container.Size = if useCard then UDim2.fromScale(1, 1) else (options.Size or UDim2.new(1, 0, 0, 132))
	container.LayoutOrder = if useCard then 0 else (options.LayoutOrder or 0)
	container.BackgroundTransparency = 1

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, Theme.Spacing.S)
	layout.Parent = container

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, Theme.Spacing.L)
	padding.PaddingRight = UDim.new(0, Theme.Spacing.L)
	padding.Parent = container

	if options.Glyph then
		local well = Instance.new("Frame")
		well.Name = "IconWell"
		well.Size = UDim2.fromOffset(50, 50)
		well.LayoutOrder = 1
		well.BackgroundColor3 = Theme.Colors.Void
		well.BackgroundTransparency = 0.5
		well.BorderSizePixel = 0
		well.Parent = container
		local wellCorner = Instance.new("UICorner")
		wellCorner.CornerRadius = Theme.Corner.Medium
		wellCorner.Parent = well

		local artHost = Instance.new("Frame")
		artHost.AnchorPoint = Vector2.new(0.5, 0.5)
		artHost.Position = UDim2.fromScale(0.5, 0.5)
		artHost.Size = UDim2.fromScale(0.62, 0.62)
		artHost.BackgroundTransparency = 1
		artHost.Parent = well
		local art = IconArt.Render(artHost, IconArt.GetGlyph(options.Glyph))
		-- Dimmed: this is an absence, not a call to action.
		for _, shape in art:GetChildren() do
			if shape:IsA("Frame") then
				shape.BackgroundTransparency = 0.35
			end
		end
	end

	local label = Instance.new("TextLabel")
	label.Name = "Title"
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.Size = UDim2.new(1, 0, 0, 0)
	label.LayoutOrder = 2
	label.BackgroundTransparency = 1
	label.Font = Theme.Font.Heading.Font
	label.TextSize = Theme.Font.Heading.Size
	label.TextColor3 = Theme.Colors.TextSecondary
	label.TextWrapped = true
	label.Text = string.upper(options.Text)
	label.Parent = container

	if options.Subtext then
		local subtext = Instance.new("TextLabel")
		subtext.Name = "Subtext"
		subtext.AutomaticSize = Enum.AutomaticSize.Y
		subtext.Size = UDim2.new(1, 0, 0, 0)
		subtext.LayoutOrder = 3
		subtext.BackgroundTransparency = 1
		subtext.Font = Theme.Font.Caption.Font
		subtext.TextSize = Theme.Font.Caption.Size
		subtext.TextColor3 = Theme.Colors.TextMuted
		subtext.TextWrapped = true
		subtext.Text = options.Subtext
		subtext.Parent = container
	end

	container.Parent = host
	return if useCard and root then root else container
end

return EmptyState
