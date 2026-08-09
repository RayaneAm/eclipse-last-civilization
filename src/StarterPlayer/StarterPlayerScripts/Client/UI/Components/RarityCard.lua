--!strict
-- The reward / cosmetic card: a bold rarity band across the top, a large
-- vector icon, and the reward name + amount.
--
-- Rebuilt around a real icon. The previous card rendered its reward as a
-- text glyph at TextSize 40, which for most resources meant an emoji that
-- may not exist on the client's font — a 132x168 card with an empty middle.
-- Now the icon is IconArt vector art at 56px, which always draws.
--
-- Rarity treatment (per the brief): a saturated top band with dark text, a
-- matching outline, and — only at Epic and above — a subtle inner glow. The
-- card body itself stays the same dark surface at every rarity, which is
-- what keeps a row of these readable instead of a wall of competing color.
--
-- All cards share one base size; the carousel emphasizes its centered card
-- with a UIScale rather than a different frame, so internal layout never
-- shifts as cards move through the middle.

local Theme = require(script.Parent.Parent.Theme)
local IconArt = require(script.Parent.Parent.IconArt)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RarityConfig = require(ReplicatedStorage.Shared.Config.RarityConfig)

local RarityCard = {}

RarityCard.WIDTH = 148
RarityCard.HEIGHT = 186

export type RarityCardOptions = {
	Name: string?,
	Rarity: string?,
	Glyph: string?, -- IconArt glyph name; wins over ItemId
	ItemId: string?,
	Title: string,
	Amount: string?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	ShowRarityLabel: boolean?,
	Parent: Instance?,
}

local BAND_HEIGHT = 26

function RarityCard.new(options: RarityCardOptions): (Frame, UIScale)
	local rarity = RarityConfig.Get(options.Rarity)
	local definition = if options.Glyph then IconArt.GetGlyph(options.Glyph) else IconArt.GetItem(options.ItemId or "")

	local card = Instance.new("Frame")
	card.Name = options.Name or "RarityCard"
	card.Size = options.Size or UDim2.fromOffset(RarityCard.WIDTH, RarityCard.HEIGHT)
	card.Position = options.Position or UDim2.fromScale(0, 0)
	card.AnchorPoint = options.AnchorPoint or Vector2.new(0, 0)
	card.LayoutOrder = options.LayoutOrder or 0
	card.BackgroundColor3 = Theme.Colors.CardBackground
	card.BorderSizePixel = 0
	card.ClipsDescendants = true

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.Corner.Medium
	corner.Parent = card

	-- The outline takes the rarity color rather than neutral black: at card
	-- scale this is the strongest available rarity cue after the band.
	local stroke = Theme.Outline(card, Theme.Stroke.Card, rarity.Color)
	stroke.Transparency = if rarity.Glow then 0 else 0.2

	-- Epic+ only: a faint wash of the rarity color over the card body. Kept
	-- very low so the card never becomes "a red card" or "a gold card".
	if rarity.Glow then
		local wash = Instance.new("Frame")
		wash.Name = "RarityWash"
		wash.Size = UDim2.fromScale(1, 1)
		wash.BackgroundColor3 = rarity.Color
		wash.BackgroundTransparency = 0.9
		wash.BorderSizePixel = 0
		wash.Parent = card
	end

	local band = Instance.new("Frame")
	band.Name = "RarityBand"
	band.Size = UDim2.new(1, 0, 0, BAND_HEIGHT)
	band.BackgroundColor3 = rarity.Color
	band.BorderSizePixel = 0
	band.ZIndex = 3
	band.Parent = card

	if options.ShowRarityLabel ~= false then
		local rarityLabel = Instance.new("TextLabel")
		rarityLabel.Name = "RarityLabel"
		rarityLabel.Size = UDim2.fromScale(1, 1)
		rarityLabel.BackgroundTransparency = 1
		rarityLabel.Font = Theme.Font.Label.Font
		rarityLabel.TextSize = 12
		-- Dark text works on every rarity hue including gold and lime, where
		-- white would wash out.
		rarityLabel.TextColor3 = Theme.Colors.TextOnAccent
		rarityLabel.Text = rarity.Label
		rarityLabel.ZIndex = 4
		rarityLabel.Parent = band
	end

	-- Icon well: a darker recess so the vector art reads clearly on the card.
	local iconWell = Instance.new("Frame")
	iconWell.Name = "IconWell"
	iconWell.AnchorPoint = Vector2.new(0.5, 0)
	iconWell.Position = UDim2.new(0.5, 0, 0, BAND_HEIGHT + 10)
	iconWell.Size = UDim2.fromOffset(72, 72)
	iconWell.BackgroundColor3 = Theme.Colors.Void
	iconWell.BackgroundTransparency = 0.55
	iconWell.BorderSizePixel = 0
	iconWell.ZIndex = 2
	iconWell.Parent = card
	local wellCorner = Instance.new("UICorner")
	wellCorner.CornerRadius = Theme.Corner.Medium
	wellCorner.Parent = iconWell

	local artHost = Instance.new("Frame")
	artHost.Name = "Art"
	artHost.AnchorPoint = Vector2.new(0.5, 0.5)
	artHost.Position = UDim2.fromScale(0.5, 0.5)
	artHost.Size = UDim2.fromScale(0.72, 0.72)
	artHost.BackgroundTransparency = 1
	artHost.ZIndex = 3
	artHost.Parent = iconWell
	IconArt.Render(artHost, definition)

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Position = UDim2.new(0, 6, 0, BAND_HEIGHT + 88)
	title.Size = UDim2.new(1, -12, 0, 30)
	title.BackgroundTransparency = 1
	title.Font = Theme.Font.Heading.Font
	title.TextSize = 14
	title.TextWrapped = true
	title.TextColor3 = Theme.Colors.TextPrimary
	title.Text = string.upper(options.Title)
	title.ZIndex = 3
	title.Parent = card

	if options.Amount then
		local amount = Instance.new("TextLabel")
		amount.Name = "Amount"
		amount.AnchorPoint = Vector2.new(0.5, 1)
		amount.Position = UDim2.new(0.5, 0, 1, -8)
		amount.Size = UDim2.new(1, -12, 0, 28)
		amount.BackgroundTransparency = 1
		amount.Font = Theme.Font.Stat.Font
		amount.TextSize = 22
		amount.TextColor3 = rarity.Color
		amount.Text = options.Amount
		amount.ZIndex = 3
		amount.Parent = card
	end

	local scale = Instance.new("UIScale")
	scale.Name = "CardScale"
	scale.Parent = card

	card.Parent = options.Parent
	return card, scale
end

return RarityCard
