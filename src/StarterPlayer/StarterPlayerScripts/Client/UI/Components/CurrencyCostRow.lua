--!strict
-- Horizontal row of ItemIcon+amount pairs for a cost (Scrap plus any
-- required materials) — Phase 4A.1 correction: replaces plain-text cost
-- lines ("◆ 1500  Iron x20") with real resource icons next to each amount.

local Theme = require(script.Parent.Parent.Theme)
local ItemIcon = require(script.Parent.ItemIcon)

local CurrencyCostRow = {}

export type CurrencyCostRowOptions = {
	Name: string?,
	ScrapCost: number?,
	Materials: { [string]: number }?,
	LayoutOrder: number?,
	Parent: Instance?,
}

function CurrencyCostRow.new(options: CurrencyCostRowOptions): Frame
	local row = Instance.new("Frame")
	row.Name = options.Name or "CurrencyCostRow"
	row.AutomaticSize = Enum.AutomaticSize.XY
	row.Size = UDim2.new(0, 0, 0, 0)
	row.LayoutOrder = options.LayoutOrder or 0
	row.BackgroundTransparency = 1

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, Theme.Spacing.S)
	layout.Parent = row

	local function addEntry(itemId: string, amount: number, order: number)
		local entryFrame = Instance.new("Frame")
		entryFrame.AutomaticSize = Enum.AutomaticSize.XY
		entryFrame.Size = UDim2.new(0, 0, 0, 0)
		entryFrame.LayoutOrder = order
		entryFrame.BackgroundTransparency = 1
		local entryLayout = Instance.new("UIListLayout")
		entryLayout.FillDirection = Enum.FillDirection.Horizontal
		entryLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		entryLayout.Padding = UDim.new(0, Theme.Spacing.XXS)
		entryLayout.Parent = entryFrame

		ItemIcon.new({ ItemId = itemId, Size = UDim2.fromOffset(22, 22), LayoutOrder = 1, Parent = entryFrame })

		local amountLabel = Instance.new("TextLabel")
		amountLabel.AutomaticSize = Enum.AutomaticSize.X
		amountLabel.Size = UDim2.new(0, 0, 0, 20)
		amountLabel.LayoutOrder = 2
		amountLabel.BackgroundTransparency = 1
		amountLabel.Font = Theme.Font.Label.Font
		amountLabel.TextSize = Theme.Font.Label.Size
		amountLabel.TextColor3 = Theme.Colors.TextSecondary
		amountLabel.Text = tostring(amount)
		amountLabel.Parent = entryFrame

		entryFrame.Parent = row
	end

	local order = 1
	if options.ScrapCost and options.ScrapCost > 0 then
		addEntry("Scrap", options.ScrapCost, order)
		order += 1
	end
	if options.Materials then
		for itemId, amount in options.Materials do
			addEntry(itemId, amount, order)
			order += 1
		end
	end

	row.Parent = options.Parent
	return row
end

return CurrencyCostRow
