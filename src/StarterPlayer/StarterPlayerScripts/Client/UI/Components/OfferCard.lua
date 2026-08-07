--!strict
-- Shop/economy offer card, two compositions sharing one option shape:
--   "Row" (default) — icon left, info right, small button bottom-right.
--     Fits a browsable LIST of many potential items (Marketplace listings).
--   "Stacked" — full-width dominant preview plate on top, info below, cost/
--     requirements grouped into their own Surface sub-block, full-width
--     footer CTA. Fits a small set of high-value items the player should
--     stop and inspect (Supply Shop).
-- Exactly ONE bordered surface either way (the outer GlassPanel) — see
-- Theme.luau's art-direction header for the border rule this follows.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemIconConfig = require(ReplicatedStorage.Shared.Config.ItemIconConfig)

local Theme = require(script.Parent.Parent.Theme)
local GlassPanel = require(script.Parent.GlassPanel)
local Surface = require(script.Parent.Surface)
local Button = require(script.Parent.Button)
local ItemIcon = require(script.Parent.ItemIcon)
local CurrencyCostRow = require(script.Parent.CurrencyCostRow)
local RequirementRow = require(script.Parent.RequirementRow)
local StatusBadge = require(script.Parent.StatusBadge)

local OfferCard = {}

export type RequirementLine = { Text: string, Met: boolean }
export type OfferCardLayout = "Row" | "Stacked"

export type OfferCardOptions = {
	Name: string?,
	ItemId: string,
	Title: string,
	Description: string,
	ScrapCost: number?,
	Materials: { [string]: number }?,
	Requirements: { RequirementLine }?,
	StatusText: string?,
	StatusVariant: StatusBadge.StatusBadgeVariant?,
	ButtonText: string,
	ButtonVariant: Button.ButtonVariant?,
	ButtonDisabled: boolean?,
	Layout: OfferCardLayout?,
	OnActivated: (() -> ())?,
	LayoutOrder: number?,
	Parent: Instance?,
}

local LOCKED_PLATE_COLOR = Theme.Colors.TextMuted

local function buildRow(options: OfferCardOptions): (Frame, TextButton)
	local card = GlassPanel.new({
		Name = options.Name or options.Title,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Gradient = false,
		LayoutOrder = options.LayoutOrder or 0,
		Parent = options.Parent,
	})

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, Theme.Spacing.M)
	padding.PaddingRight = UDim.new(0, Theme.Spacing.M)
	padding.PaddingTop = UDim.new(0, Theme.Spacing.M)
	padding.PaddingBottom = UDim.new(0, Theme.Spacing.M)
	padding.Parent = card

	if options.StatusText then
		StatusBadge.new({
			Text = options.StatusText,
			Variant = options.StatusVariant,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 0),
			Parent = card,
		})
	end

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.AutomaticSize = Enum.AutomaticSize.Y
	content.Size = UDim2.new(1, 0, 0, 0)
	content.BackgroundTransparency = 1
	content.Parent = card

	local contentLayout = Instance.new("UIListLayout")
	contentLayout.FillDirection = Enum.FillDirection.Horizontal
	contentLayout.Padding = UDim.new(0, Theme.Spacing.M)
	contentLayout.Parent = content

	ItemIcon.new({ ItemId = options.ItemId, Size = UDim2.fromOffset(64, 64), LayoutOrder = 1, Parent = content })

	local info = Instance.new("Frame")
	info.Name = "Info"
	info.AutomaticSize = Enum.AutomaticSize.Y
	info.Size = UDim2.new(1, -80, 0, 0)
	info.LayoutOrder = 2
	info.BackgroundTransparency = 1
	info.Parent = content

	local infoLayout = Instance.new("UIListLayout")
	infoLayout.FillDirection = Enum.FillDirection.Vertical
	infoLayout.Padding = UDim.new(0, Theme.Spacing.XS)
	infoLayout.Parent = info

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.AutomaticSize = Enum.AutomaticSize.Y
	title.Size = UDim2.new(1, 0, 0, 0)
	title.LayoutOrder = 1
	title.BackgroundTransparency = 1
	title.Font = Theme.Font.Heading.Font
	title.TextSize = Theme.Font.Heading.Size
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Theme.Colors.TextPrimary
	title.Text = options.Title
	title.Parent = info

	local description = Instance.new("TextLabel")
	description.Name = "Description"
	description.AutomaticSize = Enum.AutomaticSize.Y
	description.Size = UDim2.new(1, 0, 0, 0)
	description.LayoutOrder = 2
	description.BackgroundTransparency = 1
	description.Font = Theme.Font.Body.Font
	description.TextSize = Theme.Font.Body.Size
	description.TextWrapped = true
	description.TextXAlignment = Enum.TextXAlignment.Left
	description.TextColor3 = Theme.Colors.TextSecondary
	description.Text = options.Description
	description.Parent = info

	CurrencyCostRow.new({ ScrapCost = options.ScrapCost, Materials = options.Materials, LayoutOrder = 3, Parent = info })

	if options.Requirements then
		for i, requirement in options.Requirements do
			RequirementRow.new({ Text = requirement.Text, Met = requirement.Met, LayoutOrder = 3 + i, Parent = info })
		end
	end

	local footer = Instance.new("Frame")
	footer.Name = "Footer"
	footer.Size = UDim2.new(1, 0, 0, 40)
	footer.LayoutOrder = 3
	footer.BackgroundTransparency = 1
	footer.Parent = card

	local button = Button.new({
		Text = options.ButtonText,
		Variant = options.ButtonVariant or "Primary",
		Size = UDim2.fromOffset(140, 36),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 4),
		Disabled = options.ButtonDisabled,
		OnActivated = options.OnActivated,
		Parent = footer,
	})

	return card, button
end

local function buildStacked(options: OfferCardOptions): (Frame, TextButton)
	local isLocked = options.StatusVariant == "Locked"

	local card = GlassPanel.new({
		Name = options.Name or options.Title,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Gradient = false,
		LayoutOrder = options.LayoutOrder or 0,
		Parent = options.Parent,
	})

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, Theme.Spacing.M)
	padding.PaddingRight = UDim.new(0, Theme.Spacing.M)
	padding.PaddingTop = UDim.new(0, Theme.Spacing.M)
	padding.PaddingBottom = UDim.new(0, Theme.Spacing.M)
	padding.Parent = card

	local cardLayout = Instance.new("UIListLayout")
	cardLayout.FillDirection = Enum.FillDirection.Vertical
	cardLayout.Padding = UDim.new(0, Theme.Spacing.S)
	cardLayout.Parent = card

	-- Dominant preview plate — the visually primary element of the card, not
	-- a small badge competing with text. Tints to a muted gray when locked
	-- (chrome communicates state; text stays full-contrast, never just
	-- globally dimmed to illegible).
	local plate = Instance.new("Frame")
	plate.Name = "PreviewPlate"
	plate.Size = UDim2.new(1, 0, 0, 100)
	plate.LayoutOrder = 1
	plate.BorderSizePixel = 0
	plate.Parent = card

	local plateCorner = Instance.new("UICorner")
	plateCorner.CornerRadius = Theme.Corner.Medium
	plateCorner.Parent = plate

	local iconEntry = ItemIconConfig.Get(options.ItemId)
	local plateColor = if isLocked then LOCKED_PLATE_COLOR else iconEntry.AccentColor
	plate.BackgroundColor3 = plateColor
	if not isLocked then
		Theme.HeroGradient(plateColor).Parent = plate
	end

	local plateIcon = Instance.new("TextLabel")
	plateIcon.Name = "Icon"
	plateIcon.BackgroundTransparency = 1
	plateIcon.Size = UDim2.fromScale(1, 1)
	plateIcon.Font = Enum.Font.GothamBold
	plateIcon.TextSize = 48
	plateIcon.TextColor3 = Color3.new(1, 1, 1)
	plateIcon.Text = iconEntry.Glyph
	plateIcon.Parent = plate

	if options.StatusText then
		StatusBadge.new({
			Text = options.StatusText,
			Variant = options.StatusVariant,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -Theme.Spacing.S, 0, Theme.Spacing.S),
			Parent = plate,
		})
	end

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.AutomaticSize = Enum.AutomaticSize.Y
	title.Size = UDim2.new(1, 0, 0, 0)
	title.LayoutOrder = 2
	title.BackgroundTransparency = 1
	title.Font = Theme.Font.Heading.Font
	title.TextSize = Theme.Font.Heading.Size
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

	-- Cost + requirements grouped into their own Surface sub-block — a
	-- visible group, not just more stacked text lines.
	local group = Surface.new({
		Name = "CostGroup",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 4,
		DropShadow = false,
		Parent = card,
	})
	local groupPadding = Instance.new("UIPadding")
	groupPadding.PaddingLeft = UDim.new(0, Theme.Spacing.S)
	groupPadding.PaddingRight = UDim.new(0, Theme.Spacing.S)
	groupPadding.PaddingTop = UDim.new(0, Theme.Spacing.S)
	groupPadding.PaddingBottom = UDim.new(0, Theme.Spacing.S)
	groupPadding.Parent = group
	local groupLayout = Instance.new("UIListLayout")
	groupLayout.FillDirection = Enum.FillDirection.Vertical
	groupLayout.Padding = UDim.new(0, Theme.Spacing.XS)
	groupLayout.Parent = group

	CurrencyCostRow.new({ ScrapCost = options.ScrapCost, Materials = options.Materials, LayoutOrder = 1, Parent = group })

	if options.Requirements then
		for i, requirement in options.Requirements do
			RequirementRow.new({ Text = requirement.Text, Met = requirement.Met, LayoutOrder = 1 + i, Parent = group })
		end
	end

	-- Full-width footer CTA in its own strip — reads as "the one action,"
	-- not a small button fighting for space.
	local button = Button.new({
		Text = options.ButtonText,
		Variant = options.ButtonVariant or "Primary",
		Size = UDim2.new(1, 0, 0, 44),
		LayoutOrder = 5,
		Disabled = options.ButtonDisabled,
		OnActivated = options.OnActivated,
		Parent = card,
	})

	return card, button
end

-- Returns (card, button) — button exposed for GamepadNav chaining.
function OfferCard.new(options: OfferCardOptions): (Frame, TextButton)
	local layout: OfferCardLayout = options.Layout or "Row"
	if layout == "Stacked" then
		return buildStacked(options)
	end
	return buildRow(options)
end

return OfferCard
