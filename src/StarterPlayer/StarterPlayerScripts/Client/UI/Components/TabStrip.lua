--!strict
-- Tab switcher. The selected tab is a filled accent PILL with a dark outline
-- and a darker lip; unselected tabs are recessed dark slabs.
--
-- The previous version tinted the active tab's background and left inactive
-- ones fully transparent, which read as plain web nav — at a glance you
-- could not tell it was a control at all. Making every tab a visible object
-- and the selected one an obviously raised, colored pill is what the brief
-- asks for (§16) and matches how the rest of this system now builds buttons.

local Theme = require(script.Parent.Parent.Theme)
local Motion = require(script.Parent.Parent.Motion)
local Interaction = require(script.Parent.Parent.Interaction)
local GamepadNav = require(script.Parent.Parent.GamepadNav)

local TabStrip = {}

export type TabDefinition = { Id: string, Label: string }

export type TabStripOptions = {
	Name: string?,
	Tabs: { TabDefinition },
	InitialTabId: string?,
	AccentColor: Color3?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	OnTabSelected: ((tabId: string) -> ())?,
	Parent: Instance?,
}

local function labelColorFor(fill: Color3): Color3
	local luminance = 0.299 * fill.R + 0.587 * fill.G + 0.114 * fill.B
	return if luminance > 0.62 then Theme.Colors.TextOnAccent else Theme.Colors.TextPrimary
end

function TabStrip.new(options: TabStripOptions): (Frame, (tabId: string) -> (), { TextButton })
	local accent = options.AccentColor or Theme.Colors.Brand
	local activeText = labelColorFor(accent)

	local container = Instance.new("Frame")
	container.Name = options.Name or "TabStrip"
	container.Size = options.Size or UDim2.new(1, 0, 0, 40)
	container.Position = options.Position or UDim2.fromScale(0, 0)
	container.AnchorPoint = options.AnchorPoint or Vector2.new(0, 0)
	container.BackgroundTransparency = 1

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, Theme.Spacing.S)
	layout.Parent = container

	local buttons: { TextButton } = {}

	local function refreshVisual(activeId: string)
		for _, tab in options.Tabs do
			local button = container:FindFirstChild(tab.Id) :: TextButton?
			if not button then
				continue
			end
			local isActive = tab.Id == activeId
			local label = button:FindFirstChild("Label") :: TextLabel?
			local stroke = button:FindFirstChildOfClass("UIStroke")

			Motion.Tween(button, "TabFill", Theme.Motion.HoverIn, {
				BackgroundColor3 = if isActive then accent else Theme.Colors.CardBackground,
			})
			if label then
				Motion.Tween(label, "TabText", Theme.Motion.HoverIn, {
					TextColor3 = if isActive then activeText else Theme.Colors.TextMuted,
				})
			end
			if stroke then
				stroke.Transparency = if isActive then 0 else 0.45
			end
		end
	end

	local selectTab: (tabId: string) -> ()

	for _, tab in options.Tabs do
		local button = Instance.new("TextButton")
		button.Name = tab.Id
		button.AutomaticSize = Enum.AutomaticSize.X
		button.Size = UDim2.new(0, 0, 0, 34)
		button.AutoButtonColor = false
		button.Text = ""
		button.BackgroundColor3 = Theme.Colors.CardBackground
		button.BackgroundTransparency = 0
		button.BorderSizePixel = 0
		button.Parent = container

		local corner = Instance.new("UICorner")
		corner.CornerRadius = Theme.Corner.Pill
		corner.Parent = button

		Theme.Outline(button, Theme.Stroke.Thin)

		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, Theme.Spacing.L)
		padding.PaddingRight = UDim.new(0, Theme.Spacing.L)
		padding.Parent = button

		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.AutomaticSize = Enum.AutomaticSize.X
		label.Size = UDim2.new(0, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.Font = Theme.Font.Label.Font
		label.TextSize = Theme.Font.Label.Size
		label.TextColor3 = Theme.Colors.TextMuted
		label.Text = string.upper(tab.Label)
		label.Parent = button

		table.insert(buttons, button)

		Interaction.Bind(button, {
			OnActivated = function()
				selectTab(tab.Id)
			end,
		})
	end

	GamepadNav.LinkChain(buttons)

	local activeTabId = options.InitialTabId or options.Tabs[1].Id
	selectTab = function(tabId: string)
		activeTabId = tabId
		refreshVisual(tabId)
		if options.OnTabSelected then
			options.OnTabSelected(tabId)
		end
	end

	refreshVisual(activeTabId)
	container.Parent = options.Parent

	return container, selectTab, buttons
end

return TabStrip
