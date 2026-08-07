--!strict
-- Shared featured-offer hero composition — Shop's Premium tab, Shop's Season
-- Pass tab, and Starter Pack all build on this one component instead of
-- three bespoke one-off layouts. That's what makes "visually distinct
-- Premium vs Season Pass vs Starter Pack" achievable (different accent
-- color / glyph / value-section content within one consistent hero frame)
-- without duplicating an entire card layout three times.
--
-- Per Theme.luau's art-direction header: the outer card here uses
-- CardBackground + Shadow.Card and is NEVER stroked (it's nested inside its
-- screen's own single stroked GlassPanel) — the HeroSurface gradient is
-- reserved for the preview band only, not the whole card.

local Theme = require(script.Parent.Parent.Theme)
local Shadow = require(script.Parent.Parent.Shadow)
local Button = require(script.Parent.Button)
local ItemIcon = require(script.Parent.ItemIcon)
local RequirementRow = require(script.Parent.RequirementRow)
local StatusBadge = require(script.Parent.StatusBadge)

local HeroOffer = {}

export type RewardTile = { ItemId: string, Amount: number }

export type HeroOfferOptions = {
	Name: string?,
	Icon: string,
	AccentColor: Color3?,
	BadgeText: string?,
	BadgeVariant: StatusBadge.StatusBadgeVariant?,
	Title: string,
	Description: string,
	-- Value section: EITHER reward tiles (Starter Pack, Season Pass) OR
	-- feature bullets (Premium/gamepass benefits) — never both; whichever
	-- is provided renders, RewardTiles taking priority if both are somehow
	-- passed.
	RewardTiles: { RewardTile }?,
	Features: { string }?,
	PriceText: string,
	ButtonText: string,
	ButtonDisabled: boolean?,
	OnActivated: (() -> ())?,
	Size: UDim2?,
	LayoutOrder: number?,
	Parent: Instance?,
}

-- Returns (card, button) — button exposed so callers can wire it into
-- GamepadNav chains.
function HeroOffer.new(options: HeroOfferOptions): (Frame, TextButton)
	local accentColor = options.AccentColor or Theme.Colors.Brand

	local card = Instance.new("Frame")
	card.Name = options.Name or "HeroOffer"
	card.Size = options.Size or UDim2.new(1, 0, 0, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.LayoutOrder = options.LayoutOrder or 0
	card.BackgroundColor3 = Theme.Colors.CardBackground
	card.BackgroundTransparency = Theme.Transparency.CardBackground
	card.BorderSizePixel = 0

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = Theme.Corner.Large
	cardCorner.Parent = card

	local cardPadding = Instance.new("UIPadding")
	cardPadding.PaddingLeft = UDim.new(0, Theme.Spacing.M)
	cardPadding.PaddingRight = UDim.new(0, Theme.Spacing.M)
	cardPadding.PaddingTop = UDim.new(0, Theme.Spacing.M)
	cardPadding.PaddingBottom = UDim.new(0, Theme.Spacing.M)
	cardPadding.Parent = card

	local cardLayout = Instance.new("UIListLayout")
	cardLayout.FillDirection = Enum.FillDirection.Vertical
	cardLayout.Padding = UDim.new(0, Theme.Spacing.M)
	cardLayout.Parent = card

	card.Parent = options.Parent
	Shadow.Attach(card, { Transparency = Theme.Shadow.Card.Transparency, Offset = Theme.Shadow.Card.Offset })

	-- Hero preview band: HeroSurface gradient + a big centered glyph + an
	-- optional badge pill overlaid top-right ("LIMITED-TIME", "COMING SOON").
	local heroBand = Instance.new("Frame")
	heroBand.Name = "HeroBand"
	heroBand.Size = UDim2.new(1, 0, 0, 110)
	heroBand.LayoutOrder = 1
	heroBand.BackgroundColor3 = accentColor
	heroBand.BorderSizePixel = 0
	heroBand.Parent = card

	local heroBandCorner = Instance.new("UICorner")
	heroBandCorner.CornerRadius = Theme.Corner.Medium
	heroBandCorner.Parent = heroBand

	local heroGradient = Theme.HeroGradient(accentColor)
	heroGradient.Parent = heroBand

	local heroIcon = Instance.new("TextLabel")
	heroIcon.Name = "Icon"
	heroIcon.BackgroundTransparency = 1
	heroIcon.Size = UDim2.fromScale(1, 1)
	heroIcon.Font = Enum.Font.GothamBold
	heroIcon.TextSize = 56
	heroIcon.TextColor3 = Color3.new(1, 1, 1)
	heroIcon.Text = options.Icon
	heroIcon.Parent = heroBand

	if options.BadgeText then
		StatusBadge.new({
			Text = options.BadgeText,
			Variant = options.BadgeVariant,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -Theme.Spacing.S, 0, Theme.Spacing.S),
			Parent = heroBand,
		})
	end

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.AutomaticSize = Enum.AutomaticSize.Y
	title.Size = UDim2.new(1, 0, 0, 0)
	title.LayoutOrder = 2
	title.BackgroundTransparency = 1
	title.Font = Theme.Font.Hero.Font
	title.TextSize = Theme.Font.Hero.Size
	title.TextWrapped = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Theme.Colors.TextPrimary
	title.Text = options.Title
	title.Parent = card

	local description = Instance.new("TextLabel")
	description.Name = "Description"
	description.AutomaticSize = Enum.AutomaticSize.Y
	description.Size = UDim2.new(1, 0, 0, 0)
	description.LayoutOrder = 3
	description.BackgroundTransparency = 1
	description.Font = Theme.Font.Body.Font
	description.TextSize = Theme.Font.Body.Size
	description.TextWrapped = true
	description.TextXAlignment = Enum.TextXAlignment.Left
	description.TextColor3 = Theme.Colors.TextSecondary
	description.Text = options.Description
	description.Parent = card

	if options.RewardTiles and #options.RewardTiles > 0 then
		local tiles = Instance.new("Frame")
		tiles.Name = "RewardTiles"
		tiles.AutomaticSize = Enum.AutomaticSize.Y
		tiles.Size = UDim2.new(1, 0, 0, 0)
		tiles.LayoutOrder = 4
		tiles.BackgroundTransparency = 1
		tiles.Parent = card

		local tilesLayout = Instance.new("UIListLayout")
		tilesLayout.FillDirection = Enum.FillDirection.Horizontal
		tilesLayout.Wraps = true
		tilesLayout.Padding = UDim.new(0, Theme.Spacing.M)
		tilesLayout.Parent = tiles

		for i, reward in options.RewardTiles do
			ItemIcon.new({
				Name = `Reward{i}`,
				ItemId = reward.ItemId,
				Label = `x{reward.Amount}`,
				Size = UDim2.fromOffset(44, 44),
				LayoutOrder = i,
				Parent = tiles,
			})
		end
	elseif options.Features and #options.Features > 0 then
		local features = Instance.new("Frame")
		features.Name = "Features"
		features.AutomaticSize = Enum.AutomaticSize.Y
		features.Size = UDim2.new(1, 0, 0, 0)
		features.LayoutOrder = 4
		features.BackgroundTransparency = 1
		features.Parent = card

		local featuresLayout = Instance.new("UIListLayout")
		featuresLayout.FillDirection = Enum.FillDirection.Vertical
		featuresLayout.Padding = UDim.new(0, Theme.Spacing.XS)
		featuresLayout.Parent = features

		for i, text in options.Features do
			RequirementRow.new({ Text = text, Met = true, LayoutOrder = i, Parent = features })
		end
	end

	local footer = Instance.new("Frame")
	footer.Name = "Footer"
	footer.AutomaticSize = Enum.AutomaticSize.Y
	footer.Size = UDim2.new(1, 0, 0, 0)
	footer.LayoutOrder = 5
	footer.BackgroundTransparency = 1
	footer.Parent = card

	local footerLayout = Instance.new("UIListLayout")
	footerLayout.FillDirection = Enum.FillDirection.Vertical
	footerLayout.Padding = UDim.new(0, Theme.Spacing.S)
	footerLayout.Parent = footer

	local priceLabel = Instance.new("TextLabel")
	priceLabel.Name = "Price"
	priceLabel.AutomaticSize = Enum.AutomaticSize.Y
	priceLabel.Size = UDim2.new(1, 0, 0, 0)
	priceLabel.LayoutOrder = 1
	priceLabel.BackgroundTransparency = 1
	priceLabel.Font = Theme.Font.Stat.Font
	priceLabel.TextSize = Theme.Font.Stat.Size
	priceLabel.TextXAlignment = Enum.TextXAlignment.Left
	priceLabel.TextColor3 = accentColor
	priceLabel.Text = options.PriceText
	priceLabel.Parent = footer

	local button = Button.new({
		Text = options.ButtonText,
		Variant = "Primary",
		AccentColor = accentColor,
		Size = UDim2.new(1, 0, 0, 46),
		LayoutOrder = 2,
		Disabled = options.ButtonDisabled,
		OnActivated = options.OnActivated,
		Parent = footer,
	})

	return card, button
end

return HeroOffer
