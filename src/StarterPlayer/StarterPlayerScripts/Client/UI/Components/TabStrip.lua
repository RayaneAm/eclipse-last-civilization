--!strict
-- Inventory/Crafting/Shop/Marketplace/Base UI tab switcher. Active tab is a
-- filled rounded pill (accent color, white text); inactive tabs stay plain
-- muted text — no stroke on either state (see Theme.luau's art-direction
-- header). Replaces the previous thin-underline treatment, which read as
-- too subtle to register as "this is a tab control."

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

-- Returns (container, selectTab, buttons). `buttons` is exposed so the caller
-- can chain it into GamepadNav wiring alongside the rest of the panel.
function TabStrip.new(options: TabStripOptions): (Frame, (tabId: string) -> (), { TextButton })
	local accentColor = options.AccentColor or Theme.Colors.Brand

	local container = Instance.new("Frame")
	container.Name = options.Name or "TabStrip"
	container.Size = options.Size or UDim2.new(1, 0, 0, 36)
	container.Position = options.Position or UDim2.fromScale(0, 0)
	container.AnchorPoint = options.AnchorPoint or Vector2.new(0, 0)
	container.BackgroundTransparency = 1

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, Theme.Spacing.S)
	layout.Parent = container

	local buttons: { TextButton } = {}

	local function refreshVisual(activeId: string)
		for _, tab in options.Tabs do
			local button = container:FindFirstChild(tab.Id) :: TextButton?
			if button then
				local isActive = tab.Id == activeId
				Motion.Tween(button, "TabFill", Theme.Motion.HoverIn, { BackgroundTransparency = if isActive then 0.05 else 1 })
				local label = button:FindFirstChild("Label") :: TextLabel?
				if label then
					label.TextColor3 = if isActive then Theme.Colors.TextPrimary else Theme.Colors.TextMuted
				end
			end
		end
	end

	local selectTab: (tabId: string) -> ()

	for _, tab in options.Tabs do
		local button = Instance.new("TextButton")
		button.Name = tab.Id
		button.AutomaticSize = Enum.AutomaticSize.X
		button.Size = UDim2.new(0, 0, 1, 0)
		button.AutoButtonColor = false
		button.Text = ""
		button.BackgroundColor3 = accentColor
		button.BackgroundTransparency = 1
		button.BorderSizePixel = 0
		button.Parent = container

		local corner = Instance.new("UICorner")
		corner.CornerRadius = Theme.Corner.Pill
		corner.Parent = button

		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, Theme.Spacing.M)
		padding.PaddingRight = UDim.new(0, Theme.Spacing.M)
		padding.Parent = button

		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.AutomaticSize = Enum.AutomaticSize.X
		label.Size = UDim2.new(0, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.Font = Theme.Font.Heading.Font
		label.TextSize = Theme.Font.Heading.Size
		label.TextColor3 = Theme.Colors.TextMuted
		label.Text = tab.Label
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
