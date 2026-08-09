--!strict
-- One tradeable line: icon, item, price, how many you hold, and the action.
--
--     🧱  STONE BRICKS
--         ◆80 each · carrying 12          [ 10 ] [ BUY ]
--
-- Shared by the base Trader Terminal and the Haven Survivor Market so a
-- trade reads identically in both. Emphasis order follows the brief (§42):
-- icon, item, quantity, price, action.
--
-- Amounts are fixed buttons rather than a text field. Free numeric entry was
-- the old pattern and it is bad on every platform here — it needs a keyboard
-- on mobile, it can produce invalid values, and nobody actually wants an
-- arbitrary number.

local Theme = require(script.Parent.Parent.Theme)
local FacilityStyle = require(script.Parent.Parent.FacilityStyle)
local Surface = require(script.Parent.Surface)
local ItemIcon = require(script.Parent.ItemIcon)
local Button = require(script.Parent.Button)

local TradeRow = {}

export type TradeRowOptions = {
	ItemId: string,
	UnitPrice: number,
	Held: number,
	ActionText: string,
	Accent: Color3,
	Disabled: boolean?,
	-- Optional third line, e.g. a marketplace seller name.
	Note: string?,
	QuickAmount: number?,
	LayoutOrder: number?,
	OnAct: (quantity: number) -> (),
	Parent: Instance?,
}

function TradeRow.new(options: TradeRowOptions): Frame
	local quickAmount = options.QuickAmount or 10
	local disabled = options.Disabled == true
	local camera = workspace.CurrentCamera
	local compact = camera ~= nil and FacilityStyle.Breakpoint(camera.ViewportSize) == "Narrow"
	local height = if compact then (if options.Note then 116 else 104) else (if options.Note then 80 else 68)

	local row = Surface.new({
		Name = `Trade_{options.ItemId}`,
		Size = UDim2.new(1, 0, 0, height),
		LayoutOrder = options.LayoutOrder or 0,
		Parent = options.Parent,
	})

	ItemIcon.new({
		ItemId = options.ItemId,
		Size = UDim2.fromOffset(44, 44),
		Position = UDim2.fromOffset(16, 12),
		Parent = row,
	})

	local name = Instance.new("TextLabel")
	name.Name = "ItemName"
	name.Position = UDim2.fromOffset(70, 10)
	name.Size = UDim2.new(1, if compact then -86 else -226, 0, 22)
	name.BackgroundTransparency = 1
	name.Font = Theme.Font.Heading.Font
	name.TextSize = Theme.Font.Body.Size
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.TextColor3 = Theme.Colors.TextPrimary
	name.Text = string.upper(FacilityStyle.PrettyName(options.ItemId))
	name.Parent = row

	local price = Instance.new("TextLabel")
	price.Name = "Price"
	price.Position = UDim2.fromOffset(70, 34)
	price.Size = UDim2.new(1, if compact then -86 else -226, 0, 18)
	price.BackgroundTransparency = 1
	price.Font = Theme.Font.Label.Font
	price.TextSize = Theme.Font.Label.Size
	price.TextXAlignment = Enum.TextXAlignment.Left
	price.TextTruncate = Enum.TextTruncate.AtEnd
	price.TextColor3 = options.Accent
	price.Text = `◆{options.UnitPrice} each · carrying {options.Held}`
	price.Parent = row

	if options.Note then
		local note = Instance.new("TextLabel")
		note.Name = "Note"
		note.Position = UDim2.fromOffset(70, 55)
		note.Size = UDim2.new(1, -226, 0, 16)
		note.BackgroundTransparency = 1
		note.Font = Theme.Font.Caption.Font
		note.TextSize = Theme.Font.Caption.Size
		note.TextXAlignment = Enum.TextXAlignment.Left
		note.TextTruncate = Enum.TextTruncate.AtEnd
		note.TextColor3 = Theme.Colors.TextMuted
		note.Text = options.Note
		note.Parent = row
	end

	local actions = Instance.new("Frame")
	actions.Name = "Actions"
	actions.AnchorPoint = if compact then Vector2.new(0, 1) else Vector2.new(1, 0.5)
	actions.Position = if compact then UDim2.new(0, 16, 1, -10) else UDim2.new(1, -10, 0.5, 0)
	actions.Size = if compact then UDim2.new(1, -32, 0, 36) else UDim2.fromOffset(142, 40)
	actions.BackgroundTransparency = 1
	actions.Parent = row

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, Theme.Spacing.XS)
	layout.Parent = actions

	Button.new({
		Name = "Quick",
		Text = tostring(quickAmount),
		Variant = "Secondary",
		AccentColor = options.Accent,
		Size = if compact then UDim2.fromOffset(56, 36) else UDim2.fromOffset(48, 40),
		LayoutOrder = 1,
		Disabled = disabled,
		OnActivated = function()
			options.OnAct(quickAmount)
		end,
		Parent = actions,
	})

	Button.new({
		Name = "Act",
		Text = options.ActionText,
		Variant = "Primary",
		AccentColor = options.Accent,
		Size = if compact then UDim2.fromOffset(96, 36) else UDim2.fromOffset(86, 40),
		LayoutOrder = 2,
		Disabled = disabled,
		OnActivated = function()
			options.OnAct(1)
		end,
		Parent = actions,
	})

	return row
end

return TradeRow
