--!strict
-- One "SUGGESTED" entry on the Base Management overview:
--
--     ⚠  Upgrade Right Wall
--        T1 → T2
--
-- These are suggestions, never objectives (brief §17) — no completion state,
-- no reward, no ordering pressure. When a row has a safe destination it
-- becomes clickable and opens that existing screen; otherwise it renders as
-- a plain informational row rather than a button that does nothing.

local Theme = require(script.Parent.Parent.Theme)
local UIAnimator = require(script.Parent.Parent.UIAnimator)
local Surface = require(script.Parent.Surface)
local ItemIcon = require(script.Parent.ItemIcon)

local RecommendationRow = {}

export type RecommendationRowOptions = {
	Glyph: string,
	Title: string,
	Detail: string?,
	Accent: Color3?,
	LayoutOrder: number?,
	OnActivated: (() -> ())?,
	Parent: Instance?,
}

function RecommendationRow.new(options: RecommendationRowOptions): GuiObject
	local accent = options.Accent or Theme.Colors.BrandLight
	local height = if options.Detail then 50 else 38
	local interactive = options.OnActivated ~= nil

	local container: GuiObject
	if interactive then
		local button = Instance.new("TextButton")
		button.Name = "Recommendation"
		button.Size = UDim2.new(1, 0, 0, height)
		button.LayoutOrder = options.LayoutOrder or 0
		button.AutoButtonColor = false
		button.Text = ""
		button.BackgroundColor3 = Theme.Colors.CardBackground
		button.BackgroundTransparency = Theme.Transparency.CardBackground
		button.BorderSizePixel = 0
		local corner = Instance.new("UICorner")
		corner.CornerRadius = Theme.Corner.Medium
		corner.Parent = button
		container = button

		local cleanupPress = UIAnimator.BindButton(button, options.OnActivated)
		local cleanupHover = UIAnimator.BindHover(button)
		button.Destroying:Once(function()
			cleanupPress()
			cleanupHover()
		end)
	else
		container = Surface.new({
			Name = "Recommendation",
			Size = UDim2.new(1, 0, 0, height),
			LayoutOrder = options.LayoutOrder or 0,
		})
	end

	ItemIcon.new({
		Name = "RecommendationIcon",
		ItemId = options.Glyph,
		Glyph = options.Glyph,
		Size = UDim2.fromOffset(28, 28),
		Position = UDim2.new(0, 8, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		AccentOverride = accent,
		Flat = true,
		Parent = container,
	})

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Position = UDim2.new(0, 46, 0, if options.Detail then 7 else 0)
	title.Size = UDim2.new(1, -62, 0, if options.Detail then 18 else height)
	title.BackgroundTransparency = 1
	title.Font = Theme.Font.Body.Font
	title.TextSize = Theme.Font.Body.Size
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextTruncate = Enum.TextTruncate.AtEnd
	title.TextColor3 = Theme.Colors.TextPrimary
	title.Text = options.Title
	title.Parent = container

	if options.Detail then
		local detail = Instance.new("TextLabel")
		detail.Name = "Detail"
		detail.Position = UDim2.new(0, 46, 0, 26)
		detail.Size = UDim2.new(1, -62, 0, 16)
		detail.BackgroundTransparency = 1
		detail.Font = Theme.Font.Caption.Font
		detail.TextSize = Theme.Font.Caption.Size
		detail.TextXAlignment = Enum.TextXAlignment.Left
		detail.TextTruncate = Enum.TextTruncate.AtEnd
		detail.TextColor3 = Theme.Colors.TextMuted
		detail.Text = options.Detail
		detail.Parent = container
	end

	if interactive then
		local chevron = Instance.new("TextLabel")
		chevron.Name = "Chevron"
		chevron.AnchorPoint = Vector2.new(1, 0.5)
		chevron.Position = UDim2.new(1, -10, 0.5, 0)
		chevron.Size = UDim2.fromOffset(12, 20)
		chevron.BackgroundTransparency = 1
		chevron.Font = Theme.Font.Heading.Font
		chevron.TextSize = 14
		chevron.TextColor3 = Theme.Colors.TextMuted
		chevron.Text = "›"
		chevron.Parent = container
	end

	container.Parent = options.Parent
	return container
end

return RecommendationRow
