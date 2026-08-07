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

local windowShadow = new("Frame", {
	Name = "WindowShadow",
	Parent = backdrop,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 7, 0.46, 9),
	Size = UDim2.new(0.82, 0, 0.78, 0),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.45,
	BorderSizePixel = 0,
	ZIndex = 2,
})
corner(windowShadow, 20)

new("UISizeConstraint", {
	Parent = windowShadow,
	MinSize = Vector2.new(320, 430),
	MaxSize = Vector2.new(650, 600),
})

local window = new("Frame", {
	Name = "Window",
	Parent = backdrop,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.46),
	Size = UDim2.new(0.82, 0, 0.78, 0),
	BackgroundColor3 = Theme.Colors.Panel,
	BackgroundTransparency = 0.08,
	BorderSizePixel = 0,
	ClipsDescendants = true,
	SelectionGroup = true,
	ZIndex = 3,
})
corner(window, 20)

local outerStroke = stroke(window, 2, Theme.Colors.Stroke, 0.05)
new("UIGradient", {
	Parent = outerStroke,
	Rotation = 18,
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.Colors.PurpleBright),
		ColorSequenceKeypoint.new(0.55, Theme.Colors.Purple),
		ColorSequenceKeypoint.new(1, Theme.Colors.Orange),
	}),
})

new("UISizeConstraint", {
	Parent = window,
	MinSize = Vector2.new(320, 430),
	MaxSize = Vector2.new(650, 600),
})

local windowScale
local shadowScale
local settingsBaseScale = 1

local function updateWindowPosition()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local viewport = camera.ViewportSize
	local yScale = if viewport.Y < 760 then 0.52 else 0.46
	settingsBaseScale = math.clamp(math.min(viewport.X / 720, (viewport.Y - 48) / 650), 0.65, 1)
	window.Position = UDim2.fromScale(0.5, yScale)
	windowShadow.Position = UDim2.new(0.5, 7, yScale, 9)
	if windowScale and shadowScale then
		windowScale.Scale = settingsBaseScale
		shadowScale.Scale = settingsBaseScale
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

shadowScale = new("UIScale", {
	Parent = windowShadow,
	Scale = 1,
})
updateWindowPosition()

local topDecor = new("Frame", {
	Name = "TopDecor",
	Parent = window,
	Size = UDim2.new(1, 0, 0, 4),
	BackgroundColor3 = Theme.Colors.Purple,
	BorderSizePixel = 0,
	ZIndex = 4,
})
new("UIGradient", {
	Parent = topDecor,
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.Colors.Purple),
		ColorSequenceKeypoint.new(0.65, Theme.Colors.Cyan),
		ColorSequenceKeypoint.new(1, Theme.Colors.Orange),
	}),
})

local header = new("Frame", {
	Name = "Header",
	Parent = window,
	Position = UDim2.fromOffset(0, 4),
	Size = UDim2.new(1, 0, 0, 105),
	BackgroundTransparency = 1,
	ZIndex = 4,
})
padding(header, 22, 22, 18, 12)

makeText({
	Name = "Eyebrow",
	Parent = header,
	Position = UDim2.fromOffset(0, 0),
	Size = UDim2.new(1, -74, 0, 16),
	Text = "PLAYER CONFIGURATION",
	TextColor3 = Theme.Colors.Muted,
	TextSize = 11,
	Font = Theme.Fonts.BodyMedium,
	ZIndex = 5,
})

makeText({
	Name = "Title",
	Parent = header,
	Position = UDim2.fromOffset(0, 17),
	Size = UDim2.new(1, -74, 0, 34),
	Text = "SETTINGS",
	TextColor3 = Theme.Colors.White,
	TextSize = 25,
	Font = Theme.Fonts.ScreenTitle,
	ZIndex = 5,
})

makeText({
	Name = "Description",
	Parent = header,
	Position = UDim2.fromOffset(0, 52),
	Size = UDim2.new(1, -85, 0, 24),
	Text = "Adjust audio, gameplay and interface preferences.",
	TextColor3 = Theme.Colors.Muted,
	TextSize = 12,
	Font = Theme.Fonts.Body,
	TextWrapped = true,
	ZIndex = 5,
})

-- Compact close control: quiet by default, red only as a hover/close cue.
local closeGlow = new("Frame", {
	Name = "CloseGlow",
	Parent = header,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 0, 0, 0),
	Size = UDim2.fromOffset(44, 44),
	BackgroundColor3 = Theme.Colors.PanelSoft,
	BackgroundTransparency = 0,
	BorderSizePixel = 0,
	ZIndex = 5,
})
corner(closeGlow, 8)

local closeOuter = new("Frame", {
	Name = "CloseOuter",
	Parent = closeGlow,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(42, 42),
	BackgroundColor3 = Theme.Colors.PanelSoft,
	BorderSizePixel = 0,
	ZIndex = 6,
})
corner(closeOuter, 5)

local closeBorder = new("Frame", {
	Name = "CloseBorder",
	Parent = closeOuter,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(1, -2, 1, -2),
	BackgroundColor3 = Theme.Colors.Red,
	BorderSizePixel = 0,
	ZIndex = 7,
})
corner(closeBorder, 3)

local closeButton = makeText({
	ClassName = "TextButton",
	Name = "CloseButton",
	Parent = closeBorder,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(1, -2, 1, -2),
	BackgroundTransparency = 0,
	Text = "X",
	TextColor3 = Theme.Colors.Red,
	TextSize = 27,
	Font = Theme.Fonts.Body,
	TextXAlignment = Enum.TextXAlignment.Center,
	AutoButtonColor = false,
	ZIndex = 8,
})
closeButton.BackgroundColor3 = Theme.Colors.Panel
corner(closeButton, 2)

local tabs = new("Frame", {
	Name = "Tabs",
	Parent = window,
	Position = UDim2.fromOffset(20, 105),
	Size = UDim2.new(1, -40, 0, 44),
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
	Position = UDim2.fromOffset(20, 157),
	Size = UDim2.new(1, -40, 1, -226),
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
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.Colors.Purple,
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
		Padding = UDim.new(0, 10),
	})

	pages[name] = page
	return page
end

local audioPage = createPage("Audio")
local gameplayPage = createPage("Gameplay")
local interfacePage = createPage("Interface")

local values = {
	Music = true,
	SFX = true,
	Ambient = true,
	Trading = true,
	ShowOtherPlayers = true,
	CameraShake = false,
	DamageNumbers = true,
	Notifications = true,
	CompactHUD = false,
}

local function createSectionLabel(parent: Instance, text: string, order: number)
	return makeText({
		Name = text:gsub("%s+", "") .. "Section",
		Parent = parent,
		Size = UDim2.new(1, 0, 0, 22),
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
	local card = new("Frame", {
		Name = title:gsub("%s+", "") .. "Card",
		Parent = parent,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 68),
		BackgroundColor3 = Theme.Colors.Card,
		BorderSizePixel = 0,
		ZIndex = 6,
	})
	corner(card, 11)
	stroke(card, 1, Theme.Colors.Divider, 0.15)

	makeText({
		Name = "SettingTitle",
		Parent = card,
		Position = UDim2.fromOffset(15, 9),
		Size = UDim2.new(1, -105, 0, 22),
		Text = title,
		TextColor3 = Theme.Colors.White,
		TextSize = 15,
		Font = Theme.Fonts.Heading,
		ZIndex = 7,
	})

	makeText({
		Name = "SettingDescription",
		Parent = card,
		Position = UDim2.fromOffset(15, 31),
		Size = UDim2.new(1, -105, 0, 25),
		Text = description,
		TextColor3 = Theme.Colors.Muted,
		TextSize = 11,
		Font = Theme.Fonts.Body,
		TextWrapped = true,
		ZIndex = 7,
	})

	card.MouseEnter:Connect(function()
		tween(card, 0.12, { BackgroundColor3 = Theme.Colors.CardHover })
	end)

	card.MouseLeave:Connect(function()
		tween(card, 0.12, { BackgroundColor3 = Theme.Colors.Card })
	end)

	return card
end

local function createToggle(
	parent: Instance,
	key: string,
	title: string,
	description: string,
	order: number
)
	local card = createSettingCard(parent, title, description, order)

	local toggle = new("TextButton", {
		Name = "Toggle",
		Parent = card,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(56, 30),
		BackgroundColor3 = Theme.Colors.Disabled,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 8,
	})
	corner(toggle, 15)
	stroke(toggle, 1, Theme.Colors.White, 0.75)

	local knob = new("Frame", {
		Name = "Knob",
		Parent = toggle,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(22, 22),
		BackgroundColor3 = Theme.Colors.White,
		BorderSizePixel = 0,
		ZIndex = 9,
	})
	corner(knob, 11)

	local status = makeText({
		Name = "Status",
		Parent = toggle,
		Position = UDim2.new(0, 0, 1, 4),
		Size = UDim2.new(1, 0, 0, 14),
		Text = "",
		TextColor3 = Theme.Colors.Muted,
		TextSize = 9,
		Font = Theme.Fonts.BodyMedium,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 9,
	})

	local function render(animated: boolean)
		local enabled = values[key]
		local targetPosition = if enabled
			then UDim2.new(1, -15, 0.5, 0)
			else UDim2.new(0, 15, 0.5, 0)

		local targetColor = if enabled
			then Theme.Colors.Purple
			else Theme.Colors.Disabled

		status.Text = if enabled then "ON" else "OFF"
		status.TextColor3 = if enabled
			then Theme.Colors.PurpleBright
			else Theme.Colors.Muted

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

		-- Koppel hier jouw echte game-instellingen.
		print("[Eclipse Settings]", key, values[key])
	end)

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
	local card = createSettingCard(parent, title, description, order)
	values[key] = initialValue

	local percentage = makeText({
		Name = "Percentage",
		Parent = card,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 8),
		Size = UDim2.fromOffset(50, 20),
		Text = tostring(math.round(initialValue * 100)) .. "%",
		TextColor3 = Theme.Colors.White,
		TextSize = 12,
		Font = Theme.Fonts.Heading,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 8,
	})

	local track = new("TextButton", {
		Name = "SliderTrack",
		Parent = card,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -14, 1, -13),
		Size = UDim2.fromOffset(122, 9),
		BackgroundColor3 = Theme.Colors.Divider,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 8,
	})
	corner(track, 5)

	local fill = new("Frame", {
		Name = "Fill",
		Parent = track,
		Size = UDim2.fromScale(initialValue, 1),
		BackgroundColor3 = Theme.Colors.Purple,
		BorderSizePixel = 0,
		ZIndex = 9,
	})
	corner(fill, 5)
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
		Position = UDim2.new(initialValue, 0, 0.5, 0),
		Size = UDim2.fromOffset(17, 17),
		BackgroundColor3 = Theme.Colors.White,
		BorderSizePixel = 0,
		ZIndex = 10,
	})
	corner(knob, 9)
	stroke(knob, 2, Theme.Colors.Purple, 0)

	local dragging = false

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

		print("[Eclipse Settings]", key, math.round(relative * 100))
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
			dragging = false
		end
	end)

	return card
end

-- Audio page
createSectionLabel(audioPage, "Audio levels", 1)
createSlider(
	audioPage,
	"MusicVolume",
	"Music",
	"Controls menu and world music volume.",
	0.75,
	2
)
createSlider(
	audioPage,
	"SFXVolume",
	"Sound effects",
	"Controls tools, combat and interface sounds.",
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
	"Display nearby survivors while exploring.",
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
	"Show damage feedback during combat.",
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
	"Reduce permanent HUD elements on smaller screens.",
	3
)

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
	Size = UDim2.new(1, 0, 0, 67),
	BackgroundColor3 = Theme.Colors.PanelSoft,
	BackgroundTransparency = 0.05,
	BorderSizePixel = 0,
	ZIndex = 5,
})

new("Frame", {
	Name = "Divider",
	Parent = footer,
	Size = UDim2.new(1, 0, 0, 1),
	BackgroundColor3 = Theme.Colors.Divider,
	BorderSizePixel = 0,
	ZIndex = 6,
})

local resetButton = makeText({
	ClassName = "TextButton",
	Name = "ResetButton",
	Parent = footer,
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 18, 0.5, 0),
	Size = UDim2.fromOffset(138, 38),
	BackgroundTransparency = 0,
	Text = "RESET DEFAULTS",
	TextColor3 = Theme.Colors.Text,
	TextSize = 11,
	Font = Theme.Fonts.Button,
	TextXAlignment = Enum.TextXAlignment.Center,
	AutoButtonColor = false,
	ZIndex = 7,
})
resetButton.BackgroundColor3 = Theme.Colors.Card
corner(resetButton, 9)
stroke(resetButton, 1, Theme.Colors.Divider, 0)

local saveButton = makeText({
	ClassName = "TextButton",
	Name = "SaveButton",
	Parent = footer,
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -18, 0.5, 0),
	Size = UDim2.fromOffset(150, 40),
	BackgroundTransparency = 0,
	Text = "SAVE SETTINGS",
	TextColor3 = Theme.Colors.White,
	TextSize = 12,
	Font = Theme.Fonts.Button,
	TextXAlignment = Enum.TextXAlignment.Center,
	AutoButtonColor = false,
	ZIndex = 7,
})
saveButton.BackgroundColor3 = Theme.Colors.Purple
corner(saveButton, 9)
stroke(saveButton, 1, Theme.Colors.PurpleBright, 0)
new("UIGradient", {
	Parent = saveButton,
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.Colors.PurpleDark),
		ColorSequenceKeypoint.new(1, Theme.Colors.PurpleBright),
	}),
})

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
		backdrop.Visible = true
		backdrop.BackgroundTransparency = 1
		windowScale.Scale = settingsBaseScale * 0.98
		shadowScale.Scale = settingsBaseScale * 0.98

		playMenuTween(backdrop, 0.18, { BackgroundTransparency = 0.45 })
		playMenuTween(
			windowScale,
			0.22,
			{ Scale = settingsBaseScale },
			Enum.EasingStyle.Back
		)
		playMenuTween(
			shadowScale,
			0.22,
			{ Scale = settingsBaseScale },
			Enum.EasingStyle.Back
		)
	else
		playMenuTween(backdrop, 0.15, { BackgroundTransparency = 1 })

		local closing = playMenuTween(
			windowScale,
			0.15,
			{ Scale = settingsBaseScale * 0.98 },
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.In
		)

		playMenuTween(
			shadowScale,
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
	requestPanelClose()
end)

backdrop.Activated:Connect(function()
	requestPanelClose()
end)

window.InputBegan:Connect(function()
	-- Voorkomt dat klikken binnen het venster doorvalt naar de backdrop.
end)

resetButton.Activated:Connect(function()
	values.MusicVolume = 0.75
	values.SFXVolume = 0.9
	values.Ambient = true
	values.Trading = true
	values.ShowOtherPlayers = true
	values.CameraShake = false
	values.DamageNumbers = true
	values.Notifications = true
	values.CompactHUD = false

	warn(
		"De waarden zijn gereset. Open het menu opnieuw om alle visuele "
			.. "componenten opnieuw op te bouwen, of koppel dit aan jouw eigen "
			.. "settings-controller."
	)
end)

saveButton.Activated:Connect(function()
	-- Stuur deze tabel in jouw game naar een RemoteEvent/DataStore-controller.
	print("[Eclipse Settings] Saved values:")

	for key, value in pairs(values) do
		print(key, value)
	end

	local oldText = saveButton.Text
	saveButton.Text = "SETTINGS SAVED"
	tween(saveButton, 0.12, { BackgroundColor3 = Theme.Colors.Green })

	task.delay(1.1, function()
		if saveButton and saveButton.Parent then
			saveButton.Text = oldText
			tween(saveButton, 0.16, { BackgroundColor3 = Theme.Colors.Purple })
		end
	end)
end)

for _, button in ipairs({
	openButton,
	closeButton,
	resetButton,
	saveButton,
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
end)
closeButton.MouseLeave:Connect(function()
	tween(closeButton, 0.12, {
		BackgroundColor3 = Theme.Colors.Panel,
		TextColor3 = Theme.Colors.Red,
	})
end)
closeButton.SelectionGained:Connect(function()
	tween(closeButton, 0.12, {
		BackgroundColor3 = Theme.Colors.Red,
		TextColor3 = Theme.Colors.White,
	})
end)
closeButton.SelectionLost:Connect(function()
	tween(closeButton, 0.12, {
		BackgroundColor3 = Theme.Colors.Panel,
		TextColor3 = Theme.Colors.Red,
	})
end)
