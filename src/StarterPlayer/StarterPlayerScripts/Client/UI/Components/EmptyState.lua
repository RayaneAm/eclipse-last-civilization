--!strict
-- Polished "nothing here yet" placeholder — replaces large blank dark
-- rectangles (empty Marketplace category, empty Storage, empty Production
-- queue) with a centered icon + message. Optional `Card = true` wraps it in
-- a Surface block (Theme.Colors.CardBackground, no stroke — see Theme.luau's
-- art-direction header) for a "designed" empty state rather than floating
-- text, used where a screen's own empty state should read as deliberate
-- content, not a fallback (e.g. Marketplace's empty category).

local Theme = require(script.Parent.Parent.Theme)
local Surface = require(script.Parent.Surface)

local EmptyState = {}

export type EmptyStateOptions = {
	Icon: string?,
	Text: string,
	Subtext: string?, -- optional second line, e.g. a short explanation of why it's empty
	Card: boolean?,
	Size: UDim2?,
	LayoutOrder: number?,
	Parent: Instance?,
}

function EmptyState.new(options: EmptyStateOptions): Frame
	local host: Instance? = options.Parent
	if options.Card then
		local card = Surface.new({
			Name = "EmptyStateCard",
			Size = options.Size or UDim2.new(1, 0, 0, 160),
			LayoutOrder = options.LayoutOrder or 0,
			Parent = options.Parent,
		})
		host = card
	end

	local container = Instance.new("Frame")
	container.Name = "EmptyState"
	container.Size = if options.Card then UDim2.fromScale(1, 1) else (options.Size or UDim2.new(1, 0, 0, 120))
	container.LayoutOrder = if options.Card then 0 else (options.LayoutOrder or 0)
	container.BackgroundTransparency = 1

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, Theme.Spacing.S)
	layout.Parent = container

	if options.Icon then
		local icon = Instance.new("TextLabel")
		icon.AutomaticSize = Enum.AutomaticSize.XY
		icon.Size = UDim2.new(0, 0, 0, 36)
		icon.LayoutOrder = 1
		icon.BackgroundTransparency = 1
		icon.Font = Enum.Font.GothamBold
		icon.TextSize = 32
		icon.TextTransparency = 0.4
		icon.TextColor3 = Theme.Colors.TextMuted
		icon.Text = options.Icon
		icon.Parent = container
	end

	local label = Instance.new("TextLabel")
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.Size = UDim2.new(0, 0, 0, 20)
	label.LayoutOrder = 2
	label.BackgroundTransparency = 1
	label.Font = Theme.Font.Heading.Font
	label.TextSize = Theme.Font.Heading.Size
	label.TextColor3 = Theme.Colors.TextSecondary
	label.Text = options.Text
	label.Parent = container

	if options.Subtext then
		local subtext = Instance.new("TextLabel")
		subtext.AutomaticSize = Enum.AutomaticSize.XY
		subtext.Size = UDim2.new(0, 0, 0, 16)
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
	return if options.Card then (host :: Frame) else container
end

return EmptyState
