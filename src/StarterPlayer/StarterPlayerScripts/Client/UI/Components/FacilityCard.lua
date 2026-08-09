--!strict
-- The generic content block inside a facility modal: a padded, outlined card
-- that auto-sizes to its children.
--
-- Accent is reserved for selected outlines and accented child content. The
-- card stays neutral so it cannot create a full-height decorative rail.

local Theme = require(script.Parent.Parent.Theme)
local UIAnimator = require(script.Parent.Parent.UIAnimator)
local Surface = require(script.Parent.Surface)
local ItemIcon = require(script.Parent.ItemIcon)

local FacilityCard = {}

export type FacilityCardOptions = {
	Name: string?,
	Accent: Color3?,
	Padding: number?,
	Spacing: number?,
	LayoutOrder: number?,
	OnActivated: (() -> ())?,
	Selected: boolean?,
	Parent: Instance?,
}

function FacilityCard.new(options: FacilityCardOptions): (GuiObject, Frame)
	local padding = options.Padding or Theme.Spacing.M
	local interactive = options.OnActivated ~= nil
	local accent = options.Accent

	local card: GuiObject
	if interactive then
		local button = Instance.new("TextButton")
		button.Name = options.Name or "FacilityCard"
		button.AutomaticSize = Enum.AutomaticSize.Y
		button.Size = UDim2.new(1, 0, 0, 0)
		button.LayoutOrder = options.LayoutOrder or 0
		button.AutoButtonColor = false
		button.Text = ""
		button.BackgroundColor3 = if options.Selected then Theme.Colors.CardRaised else Theme.Colors.CardBackground
		button.BorderSizePixel = 0
		button.ClipsDescendants = true
		local corner = Instance.new("UICorner")
		corner.CornerRadius = Theme.Corner.Medium
		corner.Parent = button
		Theme.Outline(button, Theme.Stroke.Card)
		card = button

		local cleanupPress = UIAnimator.BindButton(button, options.OnActivated)
		local cleanupHover = UIAnimator.BindHover(button)
		button.Destroying:Once(function()
			cleanupPress()
			cleanupHover()
		end)
	else
		card = Surface.new({
			Name = options.Name or "FacilityCard",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Color = if options.Selected then Theme.Colors.CardRaised else Theme.Colors.CardBackground,
			LayoutOrder = options.LayoutOrder or 0,
		})
		card.ClipsDescendants = true
	end

	-- Selected cards get an accent edge instead of the neutral dark one, so
	-- selection is unmistakable without changing the card's footprint.
	if options.Selected then
		local outline = card:FindFirstChildOfClass("UIStroke")
		if outline then
			outline.Color = accent or Theme.Colors.Brand
			outline.Thickness = Theme.Stroke.Card + 1
		end
	end

	local cardPadding = Instance.new("UIPadding")
	cardPadding.PaddingLeft = UDim.new(0, padding)
	cardPadding.PaddingRight = UDim.new(0, padding)
	cardPadding.PaddingTop = UDim.new(0, padding)
	cardPadding.PaddingBottom = UDim.new(0, padding)
	cardPadding.Parent = card

	local content = Instance.new("Frame")
	content.Name = "CardContent"
	content.AutomaticSize = Enum.AutomaticSize.Y
	content.Size = UDim2.new(1, 0, 0, 0)
	content.BackgroundTransparency = 1
	content.Parent = card

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, options.Spacing or Theme.Spacing.S)
	layout.Parent = content

	card.Parent = options.Parent
	return card, content
end

-- The title/subtitle line most cards open with. `Icon` is an IconArt glyph
-- name and renders as a real icon tile, not a text character.
export type CardHeaderOptions = {
	Icon: string?,
	ItemId: string?,
	Title: string,
	Subtitle: string?,
	TrailingText: string?,
	TrailingColor: Color3?,
	Accent: Color3?,
	LayoutOrder: number?,
	Parent: Instance,
}

function FacilityCard.Header(options: CardHeaderOptions): Frame
	local hasSubtitle = options.Subtitle ~= nil and options.Subtitle ~= ""
	local hasIcon = options.Icon ~= nil or options.ItemId ~= nil
	local height = if hasSubtitle then 44 else 30

	local header = Instance.new("Frame")
	header.Name = "CardHeader"
	header.Size = UDim2.new(1, 0, 0, height)
	header.LayoutOrder = options.LayoutOrder or 0
	header.BackgroundTransparency = 1
	header.Parent = options.Parent

	local textLeft = 0
	if hasIcon then
		ItemIcon.new({
			Name = "HeaderIcon",
			ItemId = options.ItemId or (options.Icon :: string),
			Glyph = options.Icon,
			Size = UDim2.fromOffset(34, 34),
			Position = UDim2.new(0, 0, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			AccentOverride = if options.ItemId then nil else options.Accent,
			Parent = header,
		})
		textLeft = 44
	end

	local trailingWidth = if options.TrailingText then 116 else 0

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Position = UDim2.fromOffset(textLeft, if hasSubtitle then 2 else 0)
	title.Size = UDim2.new(1, -textLeft - trailingWidth, 0, if hasSubtitle then 22 else height)
	title.BackgroundTransparency = 1
	title.Font = Theme.Font.Heading.Font
	title.TextSize = Theme.Font.Heading.Size
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextYAlignment = Enum.TextYAlignment.Center
	title.TextTruncate = Enum.TextTruncate.AtEnd
	title.TextColor3 = Theme.Colors.TextPrimary
	title.Text = string.upper(options.Title)
	title.Parent = header

	if options.TrailingText then
		local trailing = Instance.new("TextLabel")
		trailing.Name = "Trailing"
		trailing.AnchorPoint = Vector2.new(1, 0.5)
		trailing.Position = UDim2.new(1, 0, 0.5, 0)
		trailing.Size = UDim2.fromOffset(trailingWidth - 4, 26)
		trailing.BackgroundTransparency = 1
		trailing.Font = Theme.Font.Stat.Font
		trailing.TextSize = Theme.Font.Heading.Size
		trailing.TextXAlignment = Enum.TextXAlignment.Right
		trailing.TextColor3 = options.TrailingColor or Theme.Colors.TextSecondary
		trailing.Text = options.TrailingText
		trailing.Parent = header
	end

	if hasSubtitle then
		local subtitle = Instance.new("TextLabel")
		subtitle.Name = "Subtitle"
		subtitle.Position = UDim2.fromOffset(textLeft, 25)
		subtitle.Size = UDim2.new(1, -textLeft, 0, 17)
		subtitle.BackgroundTransparency = 1
		subtitle.Font = Theme.Font.Caption.Font
		subtitle.TextSize = Theme.Font.Caption.Size
		subtitle.TextXAlignment = Enum.TextXAlignment.Left
		subtitle.TextTruncate = Enum.TextTruncate.AtEnd
		subtitle.TextColor3 = Theme.Colors.TextMuted
		subtitle.Text = options.Subtitle :: string
		subtitle.Parent = header
	end

	return header
end

export type CardTextOptions = {
	Text: string,
	Color: Color3?,
	LayoutOrder: number?,
	Parent: Instance,
}

function FacilityCard.Text(options: CardTextOptions): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = "CardText"
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.Size = UDim2.new(1, 0, 0, 0)
	label.LayoutOrder = options.LayoutOrder or 0
	label.BackgroundTransparency = 1
	label.Font = Theme.Font.Body.Font
	label.TextSize = Theme.Font.Body.Size
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextWrapped = true
	label.TextColor3 = options.Color or Theme.Colors.TextSecondary
	label.Text = options.Text
	label.Parent = options.Parent
	return label
end

return FacilityCard
