--!strict
-- The footer of an action screen: an optional secondary/cancel button and
-- one obvious primary CTA, plus the shortfall line that sits above them.
--
--     Missing 7 Fiber
--     [ CANCEL ]              [ BUILD ]
--
-- Exists so Build, Upgrade, Production and Research all present their
-- decision point identically, and so the "primary CTA is disabled and says
-- why" rule is implemented once rather than four times.

local Theme = require(script.Parent.Parent.Theme)
local Button = require(script.Parent.Button)

local ActionBar = {}

export type ActionBarOptions = {
	PrimaryText: string,
	PrimaryAccent: Color3?,
	OnPrimary: (() -> ())?,
	SecondaryText: string?,
	OnSecondary: (() -> ())?,
	-- When present, the primary button is disabled and this explains why.
	-- Never leave a CTA enabled that the server will reject for a reason we
	-- already know client-side (brief §10/§56).
	BlockedReason: string?,
	BlockedIsWarning: boolean?, -- amber "not yet supported" vs red "can't afford"
	LayoutOrder: number?,
	Parent: Instance?,
}

-- Returns (container, primaryButton) so a caller can keep driving the button
-- (disable during an in-flight request, chain it into GamepadNav).
function ActionBar.new(options: ActionBarOptions): (Frame, TextButton)
	local blocked = options.BlockedReason ~= nil

	local container = Instance.new("Frame")
	container.Name = "ActionBar"
	container.Size = UDim2.new(1, 0, 0, if blocked then 76 else 48)
	container.LayoutOrder = options.LayoutOrder or 0
	container.BackgroundTransparency = 1

	local buttonTop = 0
	if blocked then
		local reason = Instance.new("TextLabel")
		reason.Name = "BlockedReason"
		reason.Size = UDim2.new(1, 0, 0, 22)
		reason.BackgroundTransparency = 1
		reason.Font = Theme.Font.Label.Font
		reason.TextSize = Theme.Font.Label.Size
		reason.TextXAlignment = Enum.TextXAlignment.Left
		reason.TextTruncate = Enum.TextTruncate.AtEnd
		reason.TextColor3 = if options.BlockedIsWarning then Theme.Colors.Warning else Theme.Colors.Danger
		reason.Text = options.BlockedReason :: string
		reason.Parent = container
		buttonTop = 28
	end

	local row = Instance.new("Frame")
	row.Name = "Buttons"
	row.Position = UDim2.fromOffset(0, buttonTop)
	row.Size = UDim2.new(1, 0, 0, 44)
	row.BackgroundTransparency = 1
	row.Parent = container

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalFlex = if options.SecondaryText then Enum.UIFlexAlignment.SpaceBetween else Enum.UIFlexAlignment.Fill
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, Theme.Spacing.S)
	layout.Parent = row

	if options.SecondaryText then
		Button.new({
			Name = "Secondary",
			Text = options.SecondaryText,
			Variant = "Secondary",
			Size = UDim2.new(0.36, 0, 1, 0),
			LayoutOrder = 1,
			OnActivated = options.OnSecondary,
			Parent = row,
		})
	end

	local primary = Button.new({
		Name = "Primary",
		Text = options.PrimaryText,
		Variant = "Primary",
		AccentColor = options.PrimaryAccent,
		Size = if options.SecondaryText then UDim2.new(0.6, 0, 1, 0) else UDim2.new(1, 0, 1, 0),
		LayoutOrder = 2,
		Disabled = blocked,
		OnActivated = options.OnPrimary,
		Parent = row,
	})

	container.Parent = options.Parent
	return container, primary
end

return ActionBar
