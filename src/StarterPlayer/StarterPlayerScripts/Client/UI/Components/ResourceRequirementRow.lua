--!strict
-- One line of a cost / requirement block, rebuilt as a real card row:
--
--     ┌──────────────────────────────────────┐
--     │ [icon]  WOOD              40 / 30  ✓ │
--     └──────────────────────────────────────┘
--
-- The previous row was a transparent strip with a small tinted badge, plain
-- text, and a drawn tick floating at the far left. It read as a table row.
-- This version gives every requirement its own outlined slab, a full-size
-- resource icon tile, a bold name, a large stat-weight value and a colored
-- pass/fail badge on the right, so a player scanning a cost list sees
-- shape and color before they read any number.
--
-- The pass/fail mark is DRAWN (IconArt's Check/Cross), never a text glyph —
-- the tick and cross codepoints are exactly the kind that render as an empty
-- box on clients with limited font coverage.
--
-- Color is never the only signal: the badge shape differs (tick vs cross),
-- the value color changes, and the row's own outline picks up the state.

local Theme = require(script.Parent.Parent.Theme)
local FacilityStyle = require(script.Parent.Parent.FacilityStyle)
local IconArt = require(script.Parent.Parent.IconArt)
local Surface = require(script.Parent.Surface)
local ItemIcon = require(script.Parent.ItemIcon)

local ResourceRequirementRow = {}

export type ResourceRequirementRowOptions = {
	ItemId: string,
	Owned: number,
	Required: number,
	LayoutOrder: number?,
	Parent: Instance?,
}

local ROW_HEIGHT = 50

function ResourceRequirementRow.new(options: ResourceRequirementRowOptions): Frame
	local met = options.Owned >= options.Required
	local stateColor = if met then Theme.Colors.Success else Theme.Colors.Danger

	local row = Surface.new({
		Name = `Requirement_{options.ItemId}`,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		LayoutOrder = options.LayoutOrder or 0,
		DropShadow = false,
		Parent = options.Parent,
	})

	-- The row's own edge carries the state too, so an unaffordable line is
	-- visible in peripheral vision without reading the numbers.
	local outline = row:FindFirstChildOfClass("UIStroke")
	if outline then
		outline.Color = if met then Theme.Colors.Void else Theme.Colors.Danger:Lerp(Theme.Colors.Void, 0.45)
	end

	ItemIcon.new({
		ItemId = options.ItemId,
		Size = UDim2.fromOffset(34, 34),
		Position = UDim2.new(0, 8, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Flat = true,
		Parent = row,
	})

	local name = Instance.new("TextLabel")
	name.Name = "ItemName"
	name.Position = UDim2.new(0, 50, 0, 0)
	name.Size = UDim2.new(1, -160, 1, 0)
	name.BackgroundTransparency = 1
	name.Font = Theme.Font.Heading.Font
	name.TextSize = Theme.Font.Heading.Size
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.TextColor3 = Theme.Colors.TextPrimary
	name.Text = string.upper(FacilityStyle.PrettyName(options.ItemId))
	name.Parent = row

	-- Pass/fail badge, right-aligned.
	local badge = Instance.new("Frame")
	badge.Name = "StateBadge"
	badge.AnchorPoint = Vector2.new(1, 0.5)
	badge.Position = UDim2.new(1, -8, 0.5, 0)
	badge.Size = UDim2.fromOffset(28, 28)
	badge.BackgroundColor3 = stateColor
	badge.BorderSizePixel = 0
	badge.Parent = row

	local badgeCorner = Instance.new("UICorner")
	badgeCorner.CornerRadius = UDim.new(0.5, 0)
	badgeCorner.Parent = badge

	Theme.Outline(badge, Theme.Stroke.Thin)

	local markHost = Instance.new("Frame")
	markHost.Name = "Mark"
	markHost.AnchorPoint = Vector2.new(0.5, 0.5)
	markHost.Position = UDim2.fromScale(0.5, 0.5)
	markHost.Size = UDim2.fromScale(0.58, 0.58)
	markHost.BackgroundTransparency = 1
	markHost.Parent = badge
	IconArt.Render(markHost, IconArt.GetGlyph(if met then "Check" else "Cross"))

	local amount = Instance.new("TextLabel")
	amount.Name = "Amount"
	amount.AnchorPoint = Vector2.new(1, 0.5)
	amount.Position = UDim2.new(1, -44, 0.5, 0)
	amount.Size = UDim2.fromOffset(100, ROW_HEIGHT)
	amount.BackgroundTransparency = 1
	amount.Font = Theme.Font.Stat.Font
	amount.TextSize = Theme.Font.Stat.Size
	amount.TextXAlignment = Enum.TextXAlignment.Right
	amount.TextColor3 = stateColor
	amount.Text = `{options.Owned} / {options.Required}`
	amount.Parent = row

	return row
end

-- Renders a whole cost block and reports what is still missing, so no caller
-- has to redo this loop and no player has to work out a shortfall in their
-- head.
export type ShortfallResult = { Affordable: boolean, Summary: string? }

function ResourceRequirementRow.RenderCost(parent: Instance, costMaterials: { [string]: number }, owned: { [string]: number }, startOrder: number?): ShortfallResult
	local order = startOrder or 1
	local itemIds: { string } = {}
	for itemId in costMaterials do
		table.insert(itemIds, itemId)
	end
	table.sort(itemIds)

	local missing: { string } = {}
	for _, itemId in itemIds do
		local required = costMaterials[itemId]
		local have = owned[itemId] or 0
		ResourceRequirementRow.new({
			ItemId = itemId,
			Owned = have,
			Required = required,
			LayoutOrder = order,
			Parent = parent,
		})
		order += 1
		if have < required then
			table.insert(missing, `{required - have} {FacilityStyle.PrettyName(itemId)}`)
		end
	end

	if #missing == 0 then
		return { Affordable = true, Summary = nil }
	elseif #missing == 1 then
		return { Affordable = false, Summary = `Missing {missing[1]}` }
	elseif #missing == 2 then
		return { Affordable = false, Summary = `Missing {missing[1]} and {missing[2]}` }
	end
	return { Affordable = false, Summary = `Missing {missing[1]} and {#missing - 1} more` }
end

return ResourceRequirementRow
