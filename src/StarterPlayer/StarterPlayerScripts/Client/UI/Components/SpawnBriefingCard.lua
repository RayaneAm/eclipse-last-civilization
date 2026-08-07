--!strict
-- Compact, top-center, content-driven "what should I do next" card. Visually
-- distinct from Banner.luau on purpose (own layout: category -> name -> body
-- lines -> action, not Banner's icon-tile-left/title-right composition) so
-- the two are never confused for the same kind of panel — this is what
-- replaced the "star panel" the playtest flagged. A fresh instance is built
-- per showing and fully destroyed after its fade-out; nothing here is ever
-- kept around reserving screen space.

local Theme = require(script.Parent.Parent.Theme)
local GlassPanel = require(script.Parent.GlassPanel)

local SpawnBriefingCard = {}

export type SpawnBriefingCardOptions = {
	Category: string,
	Name: string,
	AccentColor: Color3?,
	Lines: { string },
	Action: string,
	Parent: Instance,
}

local CARD_WIDTH = 420

-- Returns (wrapper, scale) so the caller (SpawnBriefingController) drives
-- entrance/exit tweens and eventual :Destroy() itself.
function SpawnBriefingCard.new(options: SpawnBriefingCardOptions): (CanvasGroup, UIScale)
	local accentColor = options.AccentColor or Theme.Colors.Brand

	local wrapper = Instance.new("CanvasGroup")
	wrapper.Name = "SpawnBriefing"
	wrapper.Size = UDim2.fromOffset(CARD_WIDTH, 0)
	wrapper.AutomaticSize = Enum.AutomaticSize.Y
	wrapper.AnchorPoint = Vector2.new(0.5, 0)
	wrapper.BackgroundTransparency = 1
	wrapper.GroupTransparency = 1
	wrapper.Parent = options.Parent

	local scale = Instance.new("UIScale")
	scale.Name = "Scale"
	scale.Scale = 0.96
	scale.Parent = wrapper

	-- GlassPanel's own Shadow.Attach places a sibling ~4px below the panel's
	-- bottom edge; since both wrapper and panel use AutomaticSize.Y (computed
	-- purely from children's Position+Size, independent of ZIndex/paint
	-- order), that extra height is picked up automatically — no manual
	-- clipping-slack math needed here, unlike Toast/Banner's fixed sizing.
	local panel = GlassPanel.new({
		Name = "Panel",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		AccentColor = accentColor,
		Parent = wrapper,
	})

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, Theme.Spacing.L)
	padding.PaddingRight = UDim.new(0, Theme.Spacing.L)
	padding.PaddingTop = UDim.new(0, Theme.Spacing.M)
	padding.PaddingBottom = UDim.new(0, Theme.Spacing.M)
	padding.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, Theme.Spacing.XS)
	layout.Parent = panel

	local category = Instance.new("TextLabel")
	category.Name = "Category"
	category.Size = UDim2.new(1, 0, 0, 0)
	category.AutomaticSize = Enum.AutomaticSize.Y
	category.LayoutOrder = 1
	category.BackgroundTransparency = 1
	category.Font = Theme.Font.Label.Font
	category.TextSize = Theme.Font.Label.Size
	category.TextXAlignment = Enum.TextXAlignment.Left
	category.TextColor3 = accentColor
	category.Text = string.upper(options.Category)
	category.Parent = panel

	local name = Instance.new("TextLabel")
	name.Name = "Name"
	name.Size = UDim2.new(1, 0, 0, 0)
	name.AutomaticSize = Enum.AutomaticSize.Y
	name.LayoutOrder = 2
	name.BackgroundTransparency = 1
	name.Font = Theme.Font.Title.Font
	name.TextSize = Theme.Font.Title.Size
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextColor3 = Theme.Colors.TextPrimary
	name.Text = string.upper(options.Name)
	name.Parent = panel

	for index, line in options.Lines do
		local lineLabel = Instance.new("TextLabel")
		lineLabel.Name = `Line{index}`
		lineLabel.Size = UDim2.new(1, 0, 0, 0)
		lineLabel.AutomaticSize = Enum.AutomaticSize.Y
		lineLabel.LayoutOrder = 2 + index
		lineLabel.BackgroundTransparency = 1
		lineLabel.Font = Theme.Font.Body.Font
		lineLabel.TextSize = Theme.Font.Body.Size
		lineLabel.TextXAlignment = Enum.TextXAlignment.Left
		lineLabel.TextWrapped = true
		lineLabel.TextColor3 = Theme.Colors.TextSecondary
		lineLabel.Text = line
		lineLabel.Parent = panel
	end

	local action = Instance.new("TextLabel")
	action.Name = "Action"
	action.Size = UDim2.new(1, 0, 0, 0)
	action.AutomaticSize = Enum.AutomaticSize.Y
	action.LayoutOrder = 3 + #options.Lines
	action.BackgroundTransparency = 1
	action.Font = Theme.Font.Heading.Font
	action.TextSize = Theme.Font.Heading.Size
	action.TextXAlignment = Enum.TextXAlignment.Left
	action.TextWrapped = true
	action.TextColor3 = accentColor
	action.Text = options.Action
	action.Parent = panel

	return wrapper, scale
end

return SpawnBriefingCard
