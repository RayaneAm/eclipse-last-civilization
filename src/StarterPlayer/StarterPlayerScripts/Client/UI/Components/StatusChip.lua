--!strict
-- "READY", "RUNNING", "CRITICAL" — the compact live-state indicator.
--
-- Rebuilt as a filled accent pill with a dark outline and dark text, rather
-- than the previous muted-grey capsule with a small colored dot and colored
-- text on it. A state badge should be readable across the room; the old one
-- relied on a 8px dot carrying all the color.

local Theme = require(script.Parent.Parent.Theme)
local FacilityStyle = require(script.Parent.Parent.FacilityStyle)

local StatusChip = {}

export type StatusChipOptions = {
	Status: FacilityStyle.StatusKind,
	Text: string?,
	LayoutOrder: number?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Parent: Instance?,
}

local function labelColorFor(fill: Color3): Color3
	local luminance = 0.299 * fill.R + 0.587 * fill.G + 0.114 * fill.B
	return if luminance > 0.62 then Theme.Colors.TextOnAccent else Theme.Colors.TextPrimary
end

function StatusChip.new(options: StatusChipOptions): (Frame, (status: FacilityStyle.StatusKind, text: string?) -> ())
	local chip = Instance.new("Frame")
	chip.Name = "StatusChip"
	chip.AutomaticSize = Enum.AutomaticSize.X
	chip.Size = UDim2.new(0, 0, 0, 26)
	chip.Position = options.Position or UDim2.fromScale(0, 0)
	chip.AnchorPoint = options.AnchorPoint or Vector2.new(0, 0)
	chip.LayoutOrder = options.LayoutOrder or 0
	chip.BorderSizePixel = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.Corner.Pill
	corner.Parent = chip

	Theme.Outline(chip, Theme.Stroke.Thin)

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, Theme.Spacing.M)
	padding.PaddingRight = UDim.new(0, Theme.Spacing.M)
	padding.Parent = chip

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.new(0, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = Theme.Font.Label.Font
	label.TextSize = Theme.Font.Label.Size
	label.Parent = chip

	local function setStatus(status: FacilityStyle.StatusKind, text: string?)
		local color = FacilityStyle.StatusColor[status] or Theme.Colors.TextMuted
		-- Muted states (Idle/Locked/Offline) stay recessed rather than
		-- shouting in a bright pill; live states get the full fill.
		local isMuted = status == "Idle" or status == "Locked" or status == "Offline"
		chip.BackgroundColor3 = if isMuted then Theme.Colors.CardBackground else color
		label.TextColor3 = if isMuted then Theme.Colors.TextMuted else labelColorFor(color)
		label.Text = string.upper(text or status)
	end

	setStatus(options.Status, options.Text)
	chip.Parent = options.Parent
	return chip, setStatus
end

return StatusChip
