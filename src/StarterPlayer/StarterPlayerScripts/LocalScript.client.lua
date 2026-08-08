-- EclipseSettings.client.luau
-- Plaats dit als LocalScript in StarterPlayer > StarterPlayerScripts.
-- Genereert een responsief, geanimeerd Settings-menu in dezelfde stijl
-- als de meegestuurde Eclipse UI-screenshots.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local oldGui = playerGui:FindFirstChild("EclipseSettingsGui")
if oldGui then
	oldGui:Destroy()
end

local Theme = {
	Colors = {
		Backdrop = Color3.fromRGB(38, 39, 44),
		Panel = Color3.fromRGB(10, 10, 17),
		PanelSoft = Color3.fromRGB(18, 16, 27),
		Card = Color3.fromRGB(30, 27, 42),
		CardHover = Color3.fromRGB(37, 33, 51),

		White = Color3.fromRGB(247, 246, 250),
		Text = Color3.fromRGB(223, 219, 230),
		Muted = Color3.fromRGB(155, 150, 166),
		Disabled = Color3.fromRGB(97, 93, 108),

		Purple = Color3.fromRGB(132, 88, 255),
		PurpleBright = Color3.fromRGB(151, 105, 255),
		PurpleDark = Color3.fromRGB(67, 37, 183),

		Cyan = Color3.fromRGB(88, 205, 255),
		Orange = Color3.fromRGB(242, 147, 36),
		OrangeDark = Color3.fromRGB(174, 92, 18),
		Red = Color3.fromRGB(255, 92, 99),
		Green = Color3.fromRGB(75, 218, 139),

		Stroke = Color3.fromRGB(128, 85, 236),
		Divider = Color3.fromRGB(58, 53, 71),
	},

	-- Dichtstbijzijnde Roblox-fontcombinatie voor de screenshots.
	Fonts = {
		ScreenTitle = Enum.Font.GothamBlack,
		Heading = Enum.Font.GothamBold,
		Button = Enum.Font.GothamBold,
		Body = Enum.Font.Gotham,
		BodyMedium = Enum.Font.GothamMedium,
		Display = Enum.Font.FredokaOne,
	},
}

local SETTINGS_DEFAULT_WIDTH = 620
local SETTINGS_MIN_WIDTH = 560
local SETTINGS_MAX_WIDTH = 660
local SETTINGS_WINDOW_HEIGHT = 500
local SETTINGS_FOOTER_HEIGHT = 44
local SETTINGS_OUTER_PADDING = 20

local function new(className: string, properties: {[string]: any}?)
	local object = Instance.new(className)

	if properties then
		local parent = properties.Parent

		for property, value in pairs(properties) do
			if property ~= "Parent" then
				object[property] = value
			end
		end

		object.Parent = parent
	end

	return object
end

local function corner(parent: Instance, radius: number)
	return new("UICorner", {
		Parent = parent,
		CornerRadius = UDim.new(0, radius),
	})
end

local function stroke(
	parent: Instance,
	thickness: number,
	color: Color3,
	transparency: number?
)
	return new("UIStroke", {
		Parent = parent,
		Thickness = thickness,
		Color = color,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function padding(
	parent: Instance,
	left: number,
	right: number,
	top: number,
	bottom: number
)
	return new("UIPadding", {
		Parent = parent,
		PaddingLeft = UDim.new(0, left),
		PaddingRight = UDim.new(0, right),
		PaddingTop = UDim.new(0, top),
		PaddingBottom = UDim.new(0, bottom),
	})
end

local function tween(
	instance: Instance,
	duration: number,
	properties: {[string]: any},
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
)
	local animation = TweenService:Create(
		instance,
		TweenInfo.new(
			duration,
			style or Enum.EasingStyle.Quad,
			direction or Enum.EasingDirection.Out
		),
		properties
	)

	animation:Play()
	return animation
end

local function makeText(properties: {[string]: any})
	local label = new(properties.ClassName or "TextLabel", {
		Name = properties.Name or "Text",
		Parent = properties.Parent,
		BackgroundTransparency = properties.BackgroundTransparency or 1,
		Position = properties.Position or UDim2.fromOffset(0, 0),
		Size = properties.Size or UDim2.fromScale(1, 1),
		AnchorPoint = properties.AnchorPoint or Vector2.zero,

		Text = properties.Text or "",
		TextColor3 = properties.TextColor3 or Theme.Colors.Text,
		TextTransparency = properties.TextTransparency or 0,
		TextSize = properties.TextSize or 14,
		Font = properties.Font or Theme.Fonts.Body,
		TextXAlignment = properties.TextXAlignment or Enum.TextXAlignment.Left,
		TextYAlignment = properties.TextYAlignment or Enum.TextYAlignment.Center,
		TextWrapped = properties.TextWrapped or false,
		TextTruncate = properties.TextTruncate or Enum.TextTruncate.None,
		RichText = properties.RichText or false,
		AutoButtonColor = properties.AutoButtonColor,
		Visible = if properties.Visible == nil then true else properties.Visible,
		LayoutOrder = properties.LayoutOrder or 0,
		ZIndex = properties.ZIndex or 1,
	})

	return label
end

local gui = new("ScreenGui", {
	Name = "EclipseSettingsGui",
	Parent = playerGui,
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 85,
})

local backdrop = new("TextButton", {
	Name = "Backdrop",
	Parent = gui,
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Theme.Colors.Backdrop,
	BackgroundTransparency = 0.45,
	BorderSizePixel = 0,
	Text = "",
	AutoButtonColor = false,
	Active = true,
	Modal = true,
	Visible = false,
	ZIndex = 1,
})

local window = new("Frame", {
	Name = "Window",
	Parent = backdrop,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.46),
	Size = UDim2.fromOffset(SETTINGS_DEFAULT_WIDTH, SETTINGS_WINDOW_HEIGHT),
	BackgroundColor3 = Theme.Colors.Panel,
	BackgroundTransparency = 0.08,
	BorderSizePixel = 0,
	ClipsDescendants = true,
	Active = true,
	SelectionGroup = true,
	ZIndex = 3,
})
corner(window, 20)

-- Keep the modal outline inset so UIStroke never paints outside the rounded
-- clipping frame. This mirrors the Backpack's single, intentional outline.
local innerBorder = new("Frame", {
	Name = "InnerBorder",
	Parent = window,
	Position = UDim2.fromOffset(3, 3),
	Size = UDim2.new(1, -6, 1, -6),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Active = false,
	ZIndex = 20,
})
corner(innerBorder, 16)
stroke(innerBorder, 1, Theme.Colors.Stroke, 0.12)

new("UISizeConstraint", {
	Parent = window,
	MinSize = Vector2.new(SETTINGS_MIN_WIDTH, SETTINGS_WINDOW_HEIGHT),
	MaxSize = Vector2.new(SETTINGS_MAX_WIDTH, SETTINGS_WINDOW_HEIGHT),
})

local windowScale
local settingsBaseScale = 1

local function getResponsiveWindowWidth(viewportWidth: number): number
	if viewportWidth >= 1800 then
		return SETTINGS_MAX_WIDTH
	elseif viewportWidth >= 1450 then
		return 640
	elseif viewportWidth >= 1100 then
		return SETTINGS_DEFAULT_WIDTH
	end
	-- Preserve the modal's internal proportions and scale the whole surface on
	-- small displays instead of squeezing individual controls into each other.
	return SETTINGS_MIN_WIDTH
end

local function updateWindowPosition()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local viewport = camera.ViewportSize
	local yScale = if viewport.Y < 760 then 0.52 else 0.46
	local responsiveWidth = getResponsiveWindowWidth(viewport.X)
	local responsiveSize = UDim2.fromOffset(responsiveWidth, SETTINGS_WINDOW_HEIGHT)
	window.Size = responsiveSize
	settingsBaseScale = math.clamp(
		math.min(viewport.X / (responsiveWidth + 24), (viewport.Y - 48) / (SETTINGS_WINDOW_HEIGHT + 48)),
		0.55,
		1
	)
	window.Position = UDim2.fromScale(0.5, yScale)
	if windowScale then
		windowScale.Scale = settingsBaseScale
	end
end

updateWindowPosition()
if Workspace.CurrentCamera then
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateWindowPosition)
end
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(updateWindowPosition)

windowScale = new("UIScale", {
	Parent = window,
	Scale = 1,
})
updateWindowPosition()

local topDecor = new("Frame", {
	Name = "TopDecor",
	Parent = window,
	Position = UDim2.fromOffset(18, 2),
	Size = UDim2.new(1, -36, 0, 2),
	BackgroundColor3 = Theme.Colors.Purple,
	BorderSizePixel = 0,
	ZIndex = 21,
})
corner(topDecor, 1)
new("UIGradient", {
	Parent = topDecor,
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.Colors.PurpleDark),
		ColorSequenceKeypoint.new(0.62, Theme.Colors.PurpleBright),
		ColorSequenceKeypoint.new(1, Theme.Colors.Cyan),
	}),
})

local header = new("Frame", {
	Name = "Header",
	Parent = window,
	Position = UDim2.fromOffset(0, 6),
	Size = UDim2.new(1, 0, 0, 88),
	BackgroundTransparency = 1,
	ZIndex = 4,
})
padding(header, SETTINGS_OUTER_PADDING, SETTINGS_OUTER_PADDING, 10, 8)

makeText({
	Name = "Eyebrow",
	Parent = header,
	Position = UDim2.fromOffset(0, 0),
	Size = UDim2.new(1, -74, 0, 16),
	Text = "PLAYER CONFIGURATION",
	TextColor3 = Theme.Colors.Muted,
	TextTransparency = 0.25,
	TextSize = 10,
	Font = Theme.Fonts.BodyMedium,
	ZIndex = 5,
})

makeText({
	Name = "Title",
	Parent = header,
	Position = UDim2.fromOffset(0, 15),
	Size = UDim2.new(1, -74, 0, 30),
	Text = "SETTINGS",
	TextColor3 = Theme.Colors.White,
	TextSize = 23,
	Font = Theme.Fonts.ScreenTitle,
	ZIndex = 5,
})

makeText({
	Name = "Description",
	Parent = header,
	Position = UDim2.fromOffset(0, 45),
	Size = UDim2.new(1, -85, 0, 20),
	Text = "Configure your game experience.",
	TextColor3 = Theme.Colors.Muted,
	TextSize = 12,
	Font = Theme.Fonts.Body,
	TextWrapped = true,
	ZIndex = 5,
})

-- Same single-surface close treatment used by Backpack: one rounded button and
-- one stroke, with red reserved for the close affordance and hover state.
local closeButton = makeText({
	ClassName = "TextButton",
	Name = "CloseButton",
	Parent = header,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 0, 0, 0),
	Size = UDim2.fromOffset(44, 44),
	BackgroundTransparency = 0,
	Text = "X",
	TextColor3 = Theme.Colors.Red,
	TextSize = 18,
	Font = Theme.Fonts.Heading,
	TextXAlignment = Enum.TextXAlignment.Center,
	AutoButtonColor = false,
	ZIndex = 6,
})
closeButton.BackgroundColor3 = Theme.Colors.PanelSoft
corner(closeButton, 10)
local closeButtonStroke = stroke(closeButton, 1, Theme.Colors.Red, 0.42)

local tabs = new("Frame", {
	Name = "Tabs",
	Parent = window,
	Position = UDim2.fromOffset(SETTINGS_OUTER_PADDING, 100),
	Size = UDim2.new(1, -(SETTINGS_OUTER_PADDING * 2), 0, 38),
	BackgroundTransparency = 1,
	ZIndex = 4,
})

new("UIListLayout", {
	Parent = tabs,
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Left,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 8),
})

local pageHolder = new("Frame", {
	Name = "PageHolder",
	Parent = window,
	Position = UDim2.fromOffset(SETTINGS_OUTER_PADDING, 148),
	Size = UDim2.new(
		1,
		-(SETTINGS_OUTER_PADDING * 2),
		1,
		-(148 + SETTINGS_FOOTER_HEIGHT + 12)
	),
	BackgroundColor3 = Theme.Colors.PanelSoft,
	BackgroundTransparency = 0.18,
	BorderSizePixel = 0,
	ClipsDescendants = true,
	ZIndex = 4,
})
corner(pageHolder, 14)
stroke(pageHolder, 1, Theme.Colors.Divider, 0.22)

local pages = {}
local tabButtons = {}
local selectedTab = "Audio"

local function createPage(name: string)
	local page = new("ScrollingFrame", {
		Name = name .. "Page",
		Parent = pageHolder,
		Position = UDim2.fromOffset(4, 4),
		Size = UDim2.new(1, -8, 1, -8),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 2,
		ScrollBarImageColor3 = Theme.Colors.Muted:Lerp(Theme.Colors.Purple, 0.35),
		ScrollBarImageTransparency = 0.5,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.fromOffset(0, 0),
		Visible = false,
		ZIndex = 5,
	})
	padding(page, 12, 12, 12, 12)

	new("UIListLayout", {
		Parent = page,
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
	})

	pages[name] = page
	return page
end

local audioPage = createPage("Audio")
local gameplayPage = createPage("Gameplay")
local interfacePage = createPage("Interface")

local defaults = {
	MusicVolume = 0.75,
	SFXVolume = 0.9,
	Ambient = true,
	Trading = true,
	ShowOtherPlayers = true,
	CameraShake = false,
	DamageNumbers = true,
	Notifications = true,
	CompactHUD = false,
}
local values = table.clone(defaults)
local settingRenderers = {}

for key, defaultValue in pairs(defaults) do
	local savedValue = player:GetAttribute("EclipseSetting_" .. key)
	if savedValue ~= nil and typeof(savedValue) == typeof(defaultValue) then
		values[key] = savedValue
	end
end

local function autoSaveSetting(key: string)
	-- Attributes give the rest of the local client an immediate, observable
	-- source of truth. A server-backed settings service can mirror these later
	-- without reintroducing a manual Save step in this UI.
	player:SetAttribute("EclipseSetting_" .. key, values[key])
end

local function autoSaveAllSettings()
	for key in pairs(defaults) do
		autoSaveSetting(key)
	end
end

local function createSectionLabel(parent: Instance, text: string, order: number)
	return makeText({
		Name = text:gsub("%s+", "") .. "Section",
		Parent = parent,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 18),
		Text = string.upper(text),
		TextColor3 = Theme.Colors.PurpleBright,
		TextSize = 12,
		Font = Theme.Fonts.Heading,
		ZIndex = 6,
	})
end

local function createSettingCard(
	parent: Instance,
	title: string,
	description: string,
	order: number
)
	local hasDescription = description ~= ""
	local card = new("Frame", {
		Name = title:gsub("%s+", "") .. "Card",
		Parent = parent,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 60),
		BackgroundColor3 = Theme.Colors.PanelSoft,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 6,
	})
	corner(card, 7)

	new("Frame", {
		Name = "Divider",
		Parent = card,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 8, 1, 0),
		Size = UDim2.new(1, -16, 0, 1),
		BackgroundColor3 = Theme.Colors.Divider,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		ZIndex = 6,
	})

	makeText({
		Name = "SettingTitle",
		Parent = card,
		Position = UDim2.fromOffset(8, if hasDescription then 7 else 0),
		Size = UDim2.new(1, -248, if hasDescription then 0 else 1, if hasDescription then 20 else 0),
		Text = title,
		TextColor3 = Theme.Colors.White,
		TextSize = 15,
		Font = Theme.Fonts.Heading,
		ZIndex = 7,
	})

	makeText({
		Name = "SettingDescription",
		Parent = card,
		Position = UDim2.fromOffset(8, 28),
		Size = UDim2.new(1, -248, 0, 24),
		Text = description,
		TextColor3 = Theme.Colors.Muted:Lerp(Theme.Colors.Text, 0.32),
		TextSize = 12,
		Font = Theme.Fonts.Body,
		TextWrapped = true,
		Visible = hasDescription,
		ZIndex = 7,
	})

	card.MouseEnter:Connect(function()
		tween(card, 0.12, { BackgroundTransparency = 0.7 })
	end)

	card.MouseLeave:Connect(function()
		tween(card, 0.12, { BackgroundTransparency = 1 })
	end)

	local controlArea = new("Frame", {
		Name = "ControlArea",
		Parent = card,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 0),
		Size = UDim2.new(0, 224, 1, -1),
		BackgroundTransparency = 1,
		ZIndex = 7,
	})

	return card, controlArea
end

local function createToggle(
	parent: Instance,
	key: string,
	title: string,
	description: string,
	order: number
)
	local card, controlArea = createSettingCard(parent, title, description, order)

	local toggle = new("TextButton", {
		Name = "Toggle",
		Parent = controlArea,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(50, 26),
		BackgroundColor3 = Theme.Colors.Disabled,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 8,
	})
	corner(toggle, 13)
	stroke(toggle, 1, Theme.Colors.White, 0.75)

	local knob = new("Frame", {
		Name = "Knob",
		Parent = toggle,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(20, 20),
		BackgroundColor3 = Theme.Colors.White,
		BorderSizePixel = 0,
		ZIndex = 9,
	})
	corner(knob, 10)

	local function render(animated: boolean)
		local enabled = values[key]
		local targetPosition = if enabled
			then UDim2.new(1, -13, 0.5, 0)
			else UDim2.new(0, 13, 0.5, 0)

		local targetColor = if enabled
			then Theme.Colors.Purple
			else Theme.Colors.Disabled

		if animated then
			tween(
				knob,
				0.17,
				{ Position = targetPosition },
				Enum.EasingStyle.Back
			)
			tween(toggle, 0.16, { BackgroundColor3 = targetColor })
		else
			knob.Position = targetPosition
			toggle.BackgroundColor3 = targetColor
		end
	end

	toggle.Activated:Connect(function()
		values[key] = not values[key]
		render(true)
		autoSaveSetting(key)
	end)

	settingRenderers[key] = render
	render(false)
	return card
end

local function createSlider(
	parent: Instance,
	key: string,
	title: string,
	description: string,
	initialValue: number,
	order: number
)
	local card, controlArea = createSettingCard(parent, title, description, order)
	local startingValue = values[key] or initialValue
	values[key] = startingValue

	local percentage = makeText({
		Name = "Percentage",
		Parent = controlArea,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(50, 20),
		Text = tostring(math.round(startingValue * 100)) .. "%",
		TextColor3 = Theme.Colors.White,
		TextSize = 12,
		Font = Theme.Fonts.Heading,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 8,
	})

	local track = new("TextButton", {
		Name = "SliderTrack",
		Parent = controlArea,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -62, 0.5, 0),
		Size = UDim2.fromOffset(160, 8),
		BackgroundColor3 = Theme.Colors.Divider,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 8,
	})
	corner(track, 4)

	local fill = new("Frame", {
		Name = "Fill",
		Parent = track,
		Size = UDim2.fromScale(startingValue, 1),
		BackgroundColor3 = Theme.Colors.Purple,
		BorderSizePixel = 0,
		ZIndex = 9,
	})
	corner(fill, 4)
	new("UIGradient", {
		Parent = fill,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Theme.Colors.PurpleDark),
			ColorSequenceKeypoint.new(1, Theme.Colors.PurpleBright),
		}),
	})

	local knob = new("Frame", {
		Name = "Knob",
		Parent = track,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(startingValue, 0, 0.5, 0),
		Size = UDim2.fromOffset(17, 17),
		BackgroundColor3 = Theme.Colors.White,
		BorderSizePixel = 0,
		ZIndex = 10,
	})
	corner(knob, 9)
	stroke(knob, 2, Theme.Colors.Purple, 0)

	local dragging = false
	local function render(_animated: boolean)
		local value = values[key]
		fill.Size = UDim2.fromScale(value, 1)
		knob.Position = UDim2.new(value, 0, 0.5, 0)
		percentage.Text = tostring(math.round(value * 100)) .. "%"
	end

	local function updateFromX(screenX: number)
		local relative = math.clamp(
			(screenX - track.AbsolutePosition.X) / track.AbsoluteSize.X,
			0,
			1
		)

		values[key] = relative
		fill.Size = UDim2.fromScale(relative, 1)
		knob.Position = UDim2.new(relative, 0, 0.5, 0)
		percentage.Text = tostring(math.round(relative * 100)) .. "%"

	end

	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = true
			updateFromX(input.Position.X)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging
			and (
				input.UserInputType == Enum.UserInputType.MouseMovement
					or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			updateFromX(input.Position.X)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			if dragging then
				autoSaveSetting(key)
			end
			dragging = false
		end
	end)

	settingRenderers[key] = render
	render(false)
	return card
end

-- Audio page
createSectionLabel(audioPage, "Audio levels", 1)
createSlider(
	audioPage,
	"MusicVolume",
	"Music",
	"",
	0.75,
	2
)
createSlider(
	audioPage,
	"SFXVolume",
	"Sound effects",
	"",
	0.9,
	3
)
createToggle(
	audioPage,
	"Ambient",
	"Ambient world audio",
	"Wind, machinery and biome atmosphere.",
	4
)

-- Gameplay page
createSectionLabel(gameplayPage, "Player preferences", 1)
createToggle(
	gameplayPage,
	"Trading",
	"Trading requests",
	"Allow other survivors to send trade requests.",
	2
)
createToggle(
	gameplayPage,
	"ShowOtherPlayers",
	"Show other players",
	"",
	3
)
createToggle(
	gameplayPage,
	"CameraShake",
	"Camera shake",
	"Adds restrained impact movement during danger.",
	4
)
createToggle(
	gameplayPage,
	"DamageNumbers",
	"Damage numbers",
	"",
	5
)

-- Interface page
createSectionLabel(interfacePage, "Interface", 1)
createToggle(
	interfacePage,
	"Notifications",
	"Notifications",
	"Show discoveries, rewards and production updates.",
	2
)
createToggle(
	interfacePage,
	"CompactHUD",
	"Compact HUD",
	"Use a smaller quest and navigation HUD.",
	3
)
autoSaveAllSettings()

local function selectTab(name: string)
	selectedTab = name

	for pageName, page in pairs(pages) do
		page.Visible = pageName == name
	end

	for tabName, data in pairs(tabButtons) do
		local active = tabName == name

		tween(
			data.Button,
			0.15,
			{
				BackgroundColor3 = if active
					then Theme.Colors.Purple
					else Theme.Colors.PanelSoft,
				BackgroundTransparency = if active then 0 else 0.12,
			}
		)

		tween(
			data.Label,
			0.15,
			{
				TextColor3 = if active
					then Theme.Colors.White
					else Theme.Colors.Muted,
			}
		)

		data.Underline.Visible = active
	end
end

local function createTab(name: string, order: number)
	local button = new("TextButton", {
		Name = name .. "Tab",
		Parent = tabs,
		LayoutOrder = order,
		Size = UDim2.fromOffset(108, 36),
		BackgroundColor3 = Theme.Colors.PanelSoft,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 5,
	})
	corner(button, 18)
	stroke(button, 1, Theme.Colors.Divider, 0.1)

	local label = makeText({
		Name = "Label",
		Parent = button,
		Size = UDim2.fromScale(1, 1),
		Text = name,
		TextColor3 = Theme.Colors.Muted,
		TextSize = 13,
		Font = Theme.Fonts.Button,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 6,
	})

	local underline = new("Frame", {
		Name = "Underline",
		Parent = button,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -2),
		Size = UDim2.new(0.48, 0, 0, 2),
		BackgroundColor3 = Theme.Colors.White,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 7,
	})
	corner(underline, 1)

	tabButtons[name] = {
		Button = button,
		Label = label,
		Underline = underline,
	}

	button.Activated:Connect(function()
		selectTab(name)
	end)

	button.MouseEnter:Connect(function()
		if selectedTab ~= name then
			tween(button, 0.1, { BackgroundColor3 = Theme.Colors.CardHover })
		end
	end)

	button.MouseLeave:Connect(function()
		if selectedTab ~= name then
			tween(button, 0.1, { BackgroundColor3 = Theme.Colors.PanelSoft })
		end
	end)
end

createTab("Audio", 1)
createTab("Gameplay", 2)
createTab("Interface", 3)
selectTab("Audio")

local footer = new("Frame", {
	Name = "Footer",
	Parent = window,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 0, 1, 0),
	Size = UDim2.new(1, 0, 0, SETTINGS_FOOTER_HEIGHT),
	BackgroundColor3 = Theme.Colors.PanelSoft,
	BackgroundTransparency = 0.35,
	BorderSizePixel = 0,
	ZIndex = 5,
})

new("Frame", {
	Name = "Divider",
	Parent = footer,
	Position = UDim2.fromOffset(SETTINGS_OUTER_PADDING, 0),
	Size = UDim2.new(1, -(SETTINGS_OUTER_PADDING * 2), 0, 1),
	BackgroundColor3 = Theme.Colors.Divider,
	BorderSizePixel = 0,
	ZIndex = 6,
})

local resetButton = makeText({
	ClassName = "TextButton",
	Name = "ResetButton",
	Parent = footer,
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -SETTINGS_OUTER_PADDING, 0.5, 0),
	Size = UDim2.fromOffset(124, 28),
	BackgroundTransparency = 0.68,
	Text = "Reset to defaults",
	TextColor3 = Theme.Colors.Muted,
	TextSize = 10,
	Font = Theme.Fonts.Button,
	TextXAlignment = Enum.TextXAlignment.Center,
	AutoButtonColor = false,
	ZIndex = 7,
})
resetButton.BackgroundColor3 = Theme.Colors.Card
corner(resetButton, 7)
local resetButtonStroke = stroke(resetButton, 1, Theme.Colors.Divider, 0.52)

local resetConfirmation = new("TextButton", {
	Name = "ResetConfirmation",
	Parent = window,
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.24,
	BorderSizePixel = 0,
	Text = "",
	AutoButtonColor = false,
	Active = true,
	Modal = true,
	Visible = false,
	ZIndex = 30,
})

local resetPrompt = new("Frame", {
	Name = "Prompt",
	Parent = resetConfirmation,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(360, 164),
	BackgroundColor3 = Theme.Colors.PanelSoft,
	BorderSizePixel = 0,
	Active = true,
	ZIndex = 31,
})
corner(resetPrompt, 12)
stroke(resetPrompt, 1, Theme.Colors.Stroke, 0.15)

makeText({
	Name = "Title",
	Parent = resetPrompt,
	Position = UDim2.fromOffset(18, 15),
	Size = UDim2.new(1, -36, 0, 24),
	Text = "Reset all settings?",
	TextColor3 = Theme.Colors.White,
	TextSize = 17,
	Font = Theme.Fonts.Heading,
	ZIndex = 32,
})

makeText({
	Name = "Description",
	Parent = resetPrompt,
	Position = UDim2.fromOffset(18, 43),
	Size = UDim2.new(1, -36, 0, 42),
	Text = "Audio, gameplay and interface preferences will return to their default values.",
	TextColor3 = Theme.Colors.Muted:Lerp(Theme.Colors.Text, 0.3),
	TextSize = 12,
	Font = Theme.Fonts.Body,
	TextWrapped = true,
	TextYAlignment = Enum.TextYAlignment.Top,
	ZIndex = 32,
})

local cancelResetButton = makeText({
	ClassName = "TextButton",
	Name = "CancelReset",
	Parent = resetPrompt,
	Position = UDim2.new(0.5, -128, 1, -52),
	Size = UDim2.fromOffset(118, 34),
	BackgroundTransparency = 0,
	Text = "CANCEL",
	TextColor3 = Theme.Colors.Text,
	TextSize = 11,
	Font = Theme.Fonts.Button,
	TextXAlignment = Enum.TextXAlignment.Center,
	AutoButtonColor = false,
	ZIndex = 32,
})
cancelResetButton.BackgroundColor3 = Theme.Colors.Card
corner(cancelResetButton, 8)

local confirmResetButton = makeText({
	ClassName = "TextButton",
	Name = "ConfirmReset",
	Parent = resetPrompt,
	Position = UDim2.new(0.5, 10, 1, -52),
	Size = UDim2.fromOffset(118, 34),
	BackgroundTransparency = 0,
	Text = "RESET",
	TextColor3 = Theme.Colors.White,
	TextSize = 11,
	Font = Theme.Fonts.Button,
	TextXAlignment = Enum.TextXAlignment.Center,
	AutoButtonColor = false,
	ZIndex = 32,
})
confirmResetButton.BackgroundColor3 = Theme.Colors.Red
corner(confirmResetButton, 8)

local function setResetConfirmationVisible(visible: boolean)
	resetConfirmation.Visible = visible
	if visible then
		player:SetAttribute("EclipseModalDialogOpen", true)
	else
		-- Defer clearing so the same Esc/ButtonB event is still consumed by the
		-- central menu controller instead of also closing Settings underneath.
		task.defer(function()
			if not resetConfirmation.Visible then
				player:SetAttribute("EclipseModalDialogOpen", false)
			end
		end)
	end
end

player:SetAttribute("EclipseModalDialogOpen", false)

local openButton = makeText({
	ClassName = "TextButton",
	Name = "OpenSettings",
	Parent = gui,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 16, 1, -16),
	Size = UDim2.fromOffset(48, 48),
	BackgroundTransparency = 0.14,
	Text = "⚙",
	TextColor3 = Theme.Colors.White,
	TextSize = 20,
	Font = Theme.Fonts.Button,
	TextXAlignment = Enum.TextXAlignment.Center,
	AutoButtonColor = false,
	ZIndex = 20,
})
openButton.BackgroundColor3 = Theme.Colors.PanelSoft
corner(openButton, 24)
local openButtonStroke = stroke(openButton, 1, Theme.Colors.Divider, 0.15)

local menuOpen = false
local menuTweens = {}

local function playMenuTween(
	instance: Instance,
	duration: number,
	properties: {[string]: any},
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
)
	local previous = menuTweens[instance]
	if previous then
		previous:Cancel()
	end
	local animation = tween(instance, duration, properties, style, direction)
	menuTweens[instance] = animation
	return animation
end

local function setOpen(open: boolean)
	if menuOpen == open then
		return
	end

	menuOpen = open
	openButton.Visible = not open

	if open then
		updateWindowPosition()
		backdrop.Visible = true
		backdrop.BackgroundTransparency = 1
		windowScale.Scale = settingsBaseScale * 0.98

		playMenuTween(backdrop, 0.18, { BackgroundTransparency = 0.45 })
		playMenuTween(
			windowScale,
			0.22,
			{ Scale = settingsBaseScale },
			Enum.EasingStyle.Back
		)
	else
		setResetConfirmationVisible(false)
		playMenuTween(backdrop, 0.15, { BackgroundTransparency = 1 })

		local closing = playMenuTween(
			windowScale,
			0.15,
			{ Scale = settingsBaseScale * 0.98 },
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.In
		)
		closing.Completed:Once(function()
			if not menuOpen then
				backdrop.Visible = false
			end
		end)
	end
end

local menuController = nil

local function registerWithMenuController()
	while gui.Parent do
		local eclipseUI = (_G :: any).EclipseUI
		if eclipseUI and type(eclipseUI.RegisterPanel) == "function" then
			eclipseUI.RegisterPanel("Settings", {
				GetGuiObject = function()
					return window
				end,
				Open = function()
					setOpen(true)
				end,
				Close = function()
					setOpen(false)
				end,
				Focus = function()
					if UserInputService.GamepadEnabled then
						task.defer(function()
							if menuOpen then
								GuiService.SelectedObject = closeButton
							end
						end)
					end
				end,
			})
			menuController = eclipseUI
			return eclipseUI
		end
		task.wait()
	end
	return nil
end

task.spawn(registerWithMenuController)

local function requestPanelOpen()
	local controller = menuController
	if controller and type(controller.OpenPanel) == "function" then
		controller.OpenPanel("Settings")
		return
	end
	task.spawn(function()
		local readyController = registerWithMenuController()
		if readyController then
			readyController.OpenPanel("Settings")
		end
	end)
end

local function requestPanelClose()
	local controller = menuController
	if controller and type(controller.CloseCurrentPanel) == "function" then
		controller.CloseCurrentPanel()
	else
		setOpen(false)
	end
end

openButton.Activated:Connect(function()
	requestPanelOpen()
end)

closeButton.Activated:Connect(function()
	if resetConfirmation.Visible then
		setResetConfirmationVisible(false)
	else
		requestPanelClose()
	end
end)

local function isInsideGuiObject(screenPosition: Vector3, guiObject: GuiObject): boolean
	local objectPosition = guiObject.AbsolutePosition
	local objectSize = guiObject.AbsoluteSize
	return screenPosition.X >= objectPosition.X
		and screenPosition.X <= objectPosition.X + objectSize.X
		and screenPosition.Y >= objectPosition.Y
		and screenPosition.Y <= objectPosition.Y + objectSize.Y
end

backdrop.InputBegan:Connect(function(input)
	local isPrimaryPointer = input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
	if menuOpen and isPrimaryPointer and not isInsideGuiObject(input.Position, window) then
		requestPanelClose()
	end
end)

resetButton.Activated:Connect(function()
	setResetConfirmationVisible(true)
	if UserInputService.GamepadEnabled then
		GuiService.SelectedObject = cancelResetButton
	end
end)

cancelResetButton.Activated:Connect(function()
	setResetConfirmationVisible(false)
	if UserInputService.GamepadEnabled then
		GuiService.SelectedObject = resetButton
	end
end)

resetConfirmation.InputBegan:Connect(function(input)
	local isPrimaryPointer = input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
	if isPrimaryPointer and not isInsideGuiObject(input.Position, resetPrompt) then
		setResetConfirmationVisible(false)
	end
end)

confirmResetButton.Activated:Connect(function()
	for key, defaultValue in pairs(defaults) do
		values[key] = defaultValue
		local render = settingRenderers[key]
		if render then
			render(false)
		end
	end
	autoSaveAllSettings()
	setResetConfirmationVisible(false)
	if UserInputService.GamepadEnabled then
		GuiService.SelectedObject = resetButton
	end
end)

UserInputService.InputBegan:Connect(function(input)
	if resetConfirmation.Visible
		and (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB)
	then
		setResetConfirmationVisible(false)
		if UserInputService.GamepadEnabled then
			GuiService.SelectedObject = resetButton
		end
	end
end)

for _, button in ipairs({
	openButton,
	closeButton,
	resetButton,
	cancelResetButton,
	confirmResetButton,
	}) do
	local interactionScale = new("UIScale", {
		Parent = button,
		Scale = 1,
	})

	button.MouseEnter:Connect(function()
		tween(interactionScale, 0.12, { Scale = 1.02 })
	end)
	button.SelectionGained:Connect(function()
		tween(interactionScale, 0.12, { Scale = 1.02 })
	end)

	button.MouseButton1Down:Connect(function()
		tween(interactionScale, 0.07, { Scale = 0.98 })
	end)

	button.MouseButton1Up:Connect(function()
		tween(interactionScale, 0.11, { Scale = 1.02 })
	end)

	button.MouseLeave:Connect(function()
		tween(interactionScale, 0.11, { Scale = 1 })
	end)
	button.SelectionLost:Connect(function()
		tween(interactionScale, 0.11, { Scale = 1 })
	end)
end

resetButton.MouseEnter:Connect(function()
	tween(resetButton, 0.12, {
		BackgroundTransparency = 0.38,
		TextColor3 = Theme.Colors.Text,
	})
	tween(resetButtonStroke, 0.12, { Transparency = 0.25 })
end)
resetButton.MouseLeave:Connect(function()
	tween(resetButton, 0.12, {
		BackgroundTransparency = 0.68,
		TextColor3 = Theme.Colors.Muted,
	})
	tween(resetButtonStroke, 0.12, { Transparency = 0.52 })
end)
resetButton.SelectionGained:Connect(function()
	tween(resetButton, 0.12, {
		BackgroundTransparency = 0.38,
		TextColor3 = Theme.Colors.Text,
	})
	tween(resetButtonStroke, 0.12, { Transparency = 0.25 })
end)
resetButton.SelectionLost:Connect(function()
	tween(resetButton, 0.12, {
		BackgroundTransparency = 0.68,
		TextColor3 = Theme.Colors.Muted,
	})
	tween(resetButtonStroke, 0.12, { Transparency = 0.52 })
end)

openButton.MouseEnter:Connect(function()
	tween(openButton, 0.12, {
		BackgroundColor3 = Theme.Colors.CardHover,
		BackgroundTransparency = 0.02,
	})
	tween(openButtonStroke, 0.12, {
		Color = Theme.Colors.PurpleBright,
		Transparency = 0.02,
	})
end)
openButton.MouseLeave:Connect(function()
	tween(openButton, 0.12, {
		BackgroundColor3 = Theme.Colors.PanelSoft,
		BackgroundTransparency = 0.14,
	})
	tween(openButtonStroke, 0.12, {
		Color = Theme.Colors.Divider,
		Transparency = 0.15,
	})
end)
openButton.SelectionGained:Connect(function()
	tween(openButton, 0.12, {
		BackgroundColor3 = Theme.Colors.CardHover,
		BackgroundTransparency = 0.02,
	})
	tween(openButtonStroke, 0.12, {
		Color = Theme.Colors.PurpleBright,
		Transparency = 0.02,
	})
end)
openButton.SelectionLost:Connect(function()
	tween(openButton, 0.12, {
		BackgroundColor3 = Theme.Colors.PanelSoft,
		BackgroundTransparency = 0.14,
	})
	tween(openButtonStroke, 0.12, {
		Color = Theme.Colors.Divider,
		Transparency = 0.15,
	})
end)

closeButton.MouseEnter:Connect(function()
	tween(closeButton, 0.12, {
		BackgroundColor3 = Theme.Colors.Red,
		TextColor3 = Theme.Colors.White,
	})
	tween(closeButtonStroke, 0.12, { Transparency = 0.08 })
end)
closeButton.MouseLeave:Connect(function()
	tween(closeButton, 0.12, {
		BackgroundColor3 = Theme.Colors.PanelSoft,
		TextColor3 = Theme.Colors.Red,
	})
	tween(closeButtonStroke, 0.12, { Transparency = 0.42 })
end)
closeButton.SelectionGained:Connect(function()
	tween(closeButton, 0.12, {
		BackgroundColor3 = Theme.Colors.Red,
		TextColor3 = Theme.Colors.White,
	})
	tween(closeButtonStroke, 0.12, { Transparency = 0.08 })
end)
closeButton.SelectionLost:Connect(function()
	tween(closeButton, 0.12, {
		BackgroundColor3 = Theme.Colors.PanelSoft,
		TextColor3 = Theme.Colors.Red,
	})
	tween(closeButtonStroke, 0.12, { Transparency = 0.42 })
end)
