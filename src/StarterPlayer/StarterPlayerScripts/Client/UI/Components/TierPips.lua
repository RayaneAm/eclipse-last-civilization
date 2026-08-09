--!strict
-- The four-dot defense tier readout:
--
--     WOOD        ● ○ ○ ○
--     REINFORCED  ● ● ○ ○
--     METAL       ● ● ● ○
--     ADVANCED    ● ● ● ●
--
-- Filled pips take the tier's own accent (brown / stone-gray / steel-blue /
-- powered violet from FacilityStyle.TierColor); empty pips stay a neutral
-- dark. Only the pips are tinted — the panel around them never is.
--
-- Pips are drawn as rounded Frames rather than ●/○ characters for the same
-- font-coverage reason ResourceRequirementRow draws its check and cross.

local Theme = require(script.Parent.Parent.Theme)
local FacilityStyle = require(script.Parent.Parent.FacilityStyle)

local TierPips = {}

export type TierPipsOptions = {
	Tier: number, -- 0 = nothing built
	MaxTier: number?,
	PipSize: number?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	Parent: Instance?,
}

function TierPips.new(options: TierPipsOptions): Frame
	local maxTier = options.MaxTier or FacilityStyle.MaxDefenseTier
	local tier = math.clamp(math.floor(options.Tier), 0, maxTier)
	local pipSize = options.PipSize or 9
	local gap = 5
	local width = maxTier * pipSize + (maxTier - 1) * gap

	local container = Instance.new("Frame")
	container.Name = "TierPips"
	container.Size = UDim2.fromOffset(width, pipSize)
	container.Position = options.Position or UDim2.fromScale(0, 0)
	container.AnchorPoint = options.AnchorPoint or Vector2.new(0, 0)
	container.LayoutOrder = options.LayoutOrder or 0
	container.BackgroundTransparency = 1

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, gap)
	layout.Parent = container

	local filledColor = FacilityStyle.TierAccent(tier)
	for index = 1, maxTier do
		local pip = Instance.new("Frame")
		pip.Name = `Pip{index}`
		pip.Size = UDim2.fromOffset(pipSize, pipSize)
		pip.LayoutOrder = index
		pip.BackgroundColor3 = if index <= tier then filledColor else FacilityStyle.TierColor[0]
		pip.BackgroundTransparency = if index <= tier then 0 else 0.35
		pip.BorderSizePixel = 0
		pip.Parent = container

		local corner = Instance.new("UICorner")
		corner.CornerRadius = Theme.Corner.Pill
		corner.Parent = pip
	end

	container.Parent = options.Parent
	return container
end

-- A compact "T3  ● ● ● ○" row with a name on the left, used by the Base
-- Management defense summary and Defense Control. `detail` is an optional
-- trailing line (health, percentage) shown under the name.
export type TierRowOptions = {
	Name: string,
	Tier: number,
	MaxTier: number?,
	Detail: string?,
	DetailColor: Color3?,
	LayoutOrder: number?,
	Parent: Instance?,
}

function TierPips.Row(options: TierRowOptions): Frame
	local maxTier = options.MaxTier or FacilityStyle.MaxDefenseTier
	local tier = math.clamp(math.floor(options.Tier), 0, maxTier)

	local row = Instance.new("Frame")
	row.Name = `TierRow_{options.Name}`
	row.Size = UDim2.new(1, 0, 0, if options.Detail then 40 else 28)
	row.LayoutOrder = options.LayoutOrder or 0
	row.BackgroundTransparency = 1

	local name = Instance.new("TextLabel")
	name.Name = "Label"
	name.Size = UDim2.new(0.5, 0, 0, 18)
	name.BackgroundTransparency = 1
	name.Font = Theme.Font.Label.Font
	name.TextSize = Theme.Font.Label.Size
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextColor3 = Theme.Colors.TextSecondary
	name.Text = string.upper(options.Name)
	name.Parent = row

	local tierLabel = Instance.new("TextLabel")
	tierLabel.Name = "Tier"
	tierLabel.AnchorPoint = Vector2.new(1, 0)
	tierLabel.Position = UDim2.new(1, -(maxTier * 9 + (maxTier - 1) * 5) - 10, 0, 0)
	tierLabel.Size = UDim2.fromOffset(34, 18)
	tierLabel.BackgroundTransparency = 1
	tierLabel.Font = Theme.Font.Stat.Font
	tierLabel.TextSize = Theme.Font.Label.Size
	tierLabel.TextXAlignment = Enum.TextXAlignment.Right
	tierLabel.TextColor3 = if tier > 0 then FacilityStyle.TierAccent(tier) else Theme.Colors.TextMuted
	tierLabel.Text = if tier > 0 then `T{tier}` else "OPEN"
	tierLabel.Parent = row

	TierPips.new({
		Tier = tier,
		MaxTier = maxTier,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 5),
		Parent = row,
	})

	if options.Detail then
		local detail = Instance.new("TextLabel")
		detail.Name = "Detail"
		detail.Position = UDim2.fromOffset(0, 20)
		detail.Size = UDim2.new(1, 0, 0, 16)
		detail.BackgroundTransparency = 1
		detail.Font = Theme.Font.Caption.Font
		detail.TextSize = Theme.Font.Caption.Size
		detail.TextXAlignment = Enum.TextXAlignment.Left
		detail.TextColor3 = options.DetailColor or Theme.Colors.TextMuted
		detail.Text = options.Detail
		detail.Parent = row
	end

	row.Parent = options.Parent
	return row
end

return TierPips
