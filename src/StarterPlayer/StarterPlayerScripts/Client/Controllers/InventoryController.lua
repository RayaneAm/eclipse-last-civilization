--!strict
-- The Inventory/Crafting panel opened by HUDController's menu button. First
-- client caller of RequestCraft/EquipTool anywhere in the project (both had
-- zero callers before this) — this is what finally makes the tutorial's
-- "craft a Hatchet" objective reachable by a real player.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local Trove = require(ReplicatedStorage.Shared.Modules.Trove)
local ResourceConfig = require(ReplicatedStorage.Shared.Config.ResourceConfig)
local ToolConfig = require(ReplicatedStorage.Shared.Config.ToolConfig)
local CraftingConfig = require(ReplicatedStorage.Shared.Config.CraftingConfig)
local PlayerSessionTypes = require(ReplicatedStorage.Shared.Config.PlayerSessionTypes)

local Theme = require(script.Parent.Parent.UI.Theme)
local Motion = require(script.Parent.Parent.UI.Motion)
local GamepadNav = require(script.Parent.Parent.UI.GamepadNav)
local IconGlyphs = require(script.Parent.Parent.UI.IconGlyphs)
local GlassPanel = require(script.Parent.Parent.UI.Components.GlassPanel)
local Button = require(script.Parent.Parent.UI.Components.Button)
local Pill = require(script.Parent.Parent.UI.Components.Pill)
local TabStrip = require(script.Parent.Parent.UI.Components.TabStrip)
local CloseButton = require(script.Parent.Parent.UI.Components.CloseButton)
local ItemCell = require(script.Parent.Parent.UI.Components.ItemCell)

local HUDController = require(script.Parent.HUDController)
local NotificationController = require(script.Parent.NotificationController)

local GRID_COLUMNS = 4

-- Crafting row layout constants — derive the relationship between the icon
-- size and where the row's text content starts, rather than repeating an
-- unexplained magic "52" wherever the offset is needed.
local RECIPE_ICON_SIZE = 40
local RECIPE_ROW_CONTENT_OFFSET = RECIPE_ICON_SIZE + Theme.Spacing.M -- 52
local RECIPE_INGREDIENTS_ROW_Y = 24 + Theme.Spacing.XXS -- 26 (name label height + 2px gap)
local RECIPE_INGREDIENTS_ROW_WIDTH = 220 -- genuinely arbitrary content width, not derived from anything

-- Friendlier text for CraftingService.tryCraft's raw failure reason strings
-- (RequestCraft stays the only crafting request — this is presentation only).
local CRAFT_FAILURE_MESSAGES: { [string]: string } = {
	MissingIngredients = "Missing ingredients",
	UnknownRecipe = "Unknown recipe",
	InvalidRecipe = "Invalid recipe",
}

local InventoryController = {}

local isOpen = false
local previousSelection: GuiObject? = nil

function InventoryController:Init()
	self._trove = Trove.new()
	self._inventory = {} :: { [string]: number }
	self._equippedTool = nil :: string?

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "InventoryUI"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Enabled = true
	screenGui.Parent = playerGui
	self._trove:Add(screenGui)

	local backdrop = Instance.new("CanvasGroup")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 1
	backdrop.GroupTransparency = 1
	backdrop.Visible = false
	backdrop.Parent = screenGui
	self._backdrop = backdrop

	local backdropButton = Instance.new("TextButton")
	backdropButton.Name = "BackdropCatcher"
	backdropButton.Size = UDim2.fromScale(1, 1)
	backdropButton.BackgroundTransparency = 1
	backdropButton.Text = ""
	backdropButton.AutoButtonColor = false
	backdropButton.Parent = backdrop
	self._trove:Add(backdropButton.Activated:Connect(function()
		InventoryController.Close()
	end))

	local panel = GlassPanel.new({
		Name = "Panel",
		Size = UDim2.new(0.85, 0, 0.75, 0),
		Position = UDim2.fromScale(0.5, 0.46),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = backdrop,
	})
	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = Vector2.new(300, 360)
	sizeConstraint.MaxSize = Vector2.new(560, 480)
	sizeConstraint.Parent = panel
	self._panel = panel

	local panelScale = Instance.new("UIScale")
	panelScale.Name = "PanelScale"
	panelScale.Scale = 0.94
	panelScale.Parent = panel
	self._panelScale = panelScale

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, Theme.Spacing.L)
	padding.PaddingRight = UDim.new(0, Theme.Spacing.L)
	padding.PaddingTop = UDim.new(0, Theme.Spacing.L)
	padding.PaddingBottom = UDim.new(0, Theme.Spacing.L)
	padding.Parent = panel

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -52, 0, 28)
	title.Font = Theme.Font.Title.Font
	title.TextSize = Theme.Font.Title.Size
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Theme.Colors.TextPrimary
	title.Text = "INVENTORY"
	title.Parent = panel

	local closeButton = CloseButton.new({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		OnActivated = function()
			InventoryController.Close()
		end,
		Parent = panel,
	})
	self._closeButton = closeButton

	local inventoryTab = Instance.new("Frame")
	inventoryTab.Name = "InventoryTab"
	inventoryTab.Size = UDim2.new(1, 0, 1, -84)
	inventoryTab.Position = UDim2.new(0, 0, 0, 76)
	inventoryTab.BackgroundTransparency = 1
	inventoryTab.Parent = panel
	self._inventoryTab = inventoryTab

	local inventoryGrid = Instance.new("UIGridLayout")
	inventoryGrid.CellSize = UDim2.fromOffset(96, 128)
	inventoryGrid.CellPadding = UDim2.fromOffset(Theme.Spacing.M, Theme.Spacing.M)
	inventoryGrid.Parent = inventoryTab

	local craftingTab = Instance.new("Frame")
	craftingTab.Name = "CraftingTab"
	craftingTab.Size = UDim2.new(1, 0, 1, -84)
	craftingTab.Position = UDim2.new(0, 0, 0, 76)
	craftingTab.BackgroundTransparency = 1
	craftingTab.Visible = false
	craftingTab.Parent = panel
	self._craftingTab = craftingTab

	local craftingLayout = Instance.new("UIListLayout")
	craftingLayout.Padding = UDim.new(0, Theme.Spacing.S)
	craftingLayout.Parent = craftingTab

	local _tabStrip, selectTab, tabButtons = TabStrip.new({
		Name = "Tabs",
		Position = UDim2.new(0, 0, 0, 36),
		Tabs = {
			{ Id = "Inventory", Label = "Inventory" },
			{ Id = "Crafting", Label = "Crafting" },
		},
		InitialTabId = "Inventory",
		OnTabSelected = function(tabId: string)
			inventoryTab.Visible = tabId == "Inventory"
			craftingTab.Visible = tabId == "Crafting"
		end,
		Parent = panel,
	})
	self._tabButtons = tabButtons
	self._selectTab = selectTab

	GamepadNav.LinkChain({ closeButton, table.unpack(tabButtons) })
end

function InventoryController:_renderInventoryTab()
	for _, child in self._inventoryTab:GetChildren() do
		if not child:IsA("UIGridLayout") then
			child:Destroy()
		end
	end

	local cellButtons: { GuiButton } = {}
	local layoutOrder = 0

	local function renderEntry(id: string, name: string)
		local quantity = self._inventory[id] or 0
		local display = IconGlyphs.Get(id)
		layoutOrder += 1

		local _cell, actionSlot = ItemCell.new({
			Name = id,
			Icon = display.Icon,
			Label = `{name} x{quantity}`,
			AccentColor = display.AccentColor,
			LayoutOrder = layoutOrder,
			Parent = self._inventoryTab,
		})

		local isTool = ToolConfig.Get(id) ~= nil
		if isTool and quantity > 0 then
			if self._equippedTool == id then
				Pill.new({ Text = "EQUIPPED", AccentColor = Theme.Colors.Success, TextColor3 = Theme.Colors.Success, Parent = actionSlot })
			else
				local equipButton = Button.new({
					Text = "Equip",
					Variant = "Secondary",
					Size = UDim2.new(1, 0, 0, 28),
					OnActivated = function()
						local ok, reason = Net.GetFunction("EquipTool"):InvokeServer(id)
						if not ok then
							warn(`InventoryController: EquipTool failed for "{id}": {tostring(reason)}`)
						else
							self._equippedTool = id
							self:_renderInventoryTab()
							NotificationController.Toast("ItemEquipped", `{name} equipped`, {
								Icon = display.Icon,
								AccentColor = display.AccentColor,
							})
						end
					end,
					Parent = actionSlot,
				})
				table.insert(cellButtons, equipButton)
			end
		end
	end

	for _, resource in ResourceConfig.All do
		if (self._inventory[resource.id] or 0) > 0 then
			renderEntry(resource.id, resource.name)
		end
	end
	for _, tool in ToolConfig.All do
		if (self._inventory[tool.id] or 0) > 0 then
			renderEntry(tool.id, tool.name)
		end
	end

	if layoutOrder == 0 then
		local empty = Instance.new("TextLabel")
		empty.Name = "EmptyState"
		empty.BackgroundTransparency = 1
		empty.Size = UDim2.new(1, 0, 0, 40)
		empty.Font = Theme.Font.Body.Font
		empty.TextSize = Theme.Font.Body.Size
		empty.TextColor3 = Theme.Colors.TextMuted
		empty.Text = "Nothing gathered yet — harvest resources around Survivor Haven."
		empty.Parent = self._inventoryTab
	end

	GamepadNav.LinkGrid(cellButtons, GRID_COLUMNS)
end

function InventoryController:_renderCraftingTab()
	for _, child in self._craftingTab:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end

	for index, recipe in CraftingConfig.All do
		local outputDisplay = IconGlyphs.Get(recipe.output.itemId)

		local row = GlassPanel.new({
			Name = recipe.id,
			Size = UDim2.new(1, 0, 0, 76),
			CornerRadius = Theme.Corner.Medium,
			AccentColor = outputDisplay.AccentColor,
			Gradient = false,
			LayoutOrder = index,
			Parent = self._craftingTab,
		})

		local rowPadding = Instance.new("UIPadding")
		rowPadding.PaddingLeft = UDim.new(0, Theme.Spacing.M)
		rowPadding.PaddingRight = UDim.new(0, Theme.Spacing.M)
		rowPadding.PaddingTop = UDim.new(0, Theme.Spacing.S)
		rowPadding.PaddingBottom = UDim.new(0, Theme.Spacing.S)
		rowPadding.Parent = row

		local icon = Instance.new("TextLabel")
		icon.BackgroundTransparency = 1
		icon.Size = UDim2.fromOffset(RECIPE_ICON_SIZE, RECIPE_ICON_SIZE)
		icon.Font = Enum.Font.GothamBold
		icon.TextSize = 28
		icon.TextColor3 = Theme.Colors.TextPrimary
		icon.TextStrokeColor3 = Color3.new(0, 0, 0)
		icon.TextStrokeTransparency = 0.6
		icon.Text = outputDisplay.Icon
		icon.Parent = row

		local name = Instance.new("TextLabel")
		name.BackgroundTransparency = 1
		name.Position = UDim2.fromOffset(RECIPE_ROW_CONTENT_OFFSET, 0)
		name.Size = UDim2.fromOffset(120, 24)
		name.Font = Theme.Font.Heading.Font
		name.TextSize = Theme.Font.Heading.Size
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextColor3 = Theme.Colors.TextPrimary
		name.Text = recipe.name
		name.Parent = row

		local ingredientsRow = Instance.new("Frame")
		ingredientsRow.Position = UDim2.fromOffset(RECIPE_ROW_CONTENT_OFFSET, RECIPE_INGREDIENTS_ROW_Y)
		ingredientsRow.Size = UDim2.fromOffset(RECIPE_INGREDIENTS_ROW_WIDTH, 24)
		ingredientsRow.BackgroundTransparency = 1
		ingredientsRow.Parent = row

		local ingredientsLayout = Instance.new("UIListLayout")
		ingredientsLayout.FillDirection = Enum.FillDirection.Horizontal
		ingredientsLayout.Padding = UDim.new(0, Theme.Spacing.XS)
		ingredientsLayout.Parent = ingredientsRow

		local allMet = true
		for _, ingredient in recipe.inputs do
			local owned = self._inventory[ingredient.itemId] or 0
			local met = owned >= ingredient.amount
			allMet = allMet and met
			local ingredientDisplay = IconGlyphs.Get(ingredient.itemId)
			Pill.new({
				Text = `{ingredientDisplay.Icon} {owned}/{ingredient.amount}`,
				AccentColor = if met then Theme.Colors.Success else Theme.Colors.Danger,
				TextColor3 = if met then Theme.Colors.Success else Theme.Colors.Danger,
				Parent = ingredientsRow,
			})
		end

		local feedback = Instance.new("TextLabel")
		feedback.Name = "Feedback"
		feedback.AnchorPoint = Vector2.new(1, 1)
		feedback.Position = UDim2.new(1, 0, 1, -4)
		feedback.Size = UDim2.fromOffset(160, 16)
		feedback.BackgroundTransparency = 1
		feedback.Font = Theme.Font.Caption.Font
		feedback.TextSize = Theme.Font.Caption.Size
		feedback.TextXAlignment = Enum.TextXAlignment.Right
		feedback.TextColor3 = Theme.Colors.Danger
		feedback.TextTransparency = 1
		feedback.Text = ""
		feedback.Parent = row

		local craftButton = Button.new({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 0),
			Size = UDim2.fromOffset(90, 40),
			Text = "Craft",
			Disabled = not allMet,
			OnActivated = function()
				local ok, reasonOrTrue = Net.GetFunction("RequestCraft"):InvokeServer(recipe.id)
				if not ok then
					local reason = tostring(reasonOrTrue)
					feedback.Text = CRAFT_FAILURE_MESSAGES[reason] or reason
					feedback.TextTransparency = 0
					Motion.Tween(feedback, "Fade", TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 1 })
				else
					NotificationController.Toast("ItemCrafted", recipe.name, {
						Icon = outputDisplay.Icon,
						AccentColor = outputDisplay.AccentColor,
					})
				end
			end,
			Parent = row,
		})
		table.insert(self._craftButtons, craftButton)
	end
end

function InventoryController:_refreshTabs()
	self._craftButtons = {}
	self:_renderInventoryTab()
	self:_renderCraftingTab()
end

function InventoryController.IsOpen(): boolean
	return isOpen
end

-- initialTabId lets a caller (e.g. FacilityController's Upgrade Station
-- interaction) force a specific tab. Works whether the panel was already
-- open or closed — retargeting the tab is applied unconditionally, only the
-- open animation itself is skipped if it's already open.
function InventoryController.Open(initialTabId: string?)
	local self = InventoryController

	if not isOpen then
		isOpen = true
		self._backdrop.Visible = true
		self:_refreshTabs()

		Motion.Tween(self._backdrop, "Fade", Theme.Motion.PanelOpen, { GroupTransparency = 0 })
		Motion.Tween(self._panelScale, "Scale", Theme.Motion.PanelOpen, { Scale = 1 })

		previousSelection = GuiService.SelectedObject
		GamepadNav.FocusFirst(self._panel)
	end

	if initialTabId then
		self._selectTab(initialTabId)
	end
end

function InventoryController.Close()
	if not isOpen then
		return
	end
	isOpen = false

	local self = InventoryController
	local tween = Motion.Tween(self._backdrop, "Fade", Theme.Motion.PanelClose, { GroupTransparency = 1 })
	Motion.Tween(self._panelScale, "Scale", Theme.Motion.PanelClose, { Scale = 0.94 })
	tween.Completed:Once(function()
		if not isOpen then
			self._backdrop.Visible = false
		end
	end)

	GamepadNav.Restore(previousSelection)
end

function InventoryController.Toggle()
	if isOpen then
		InventoryController.Close()
	else
		InventoryController.Open()
	end
end

function InventoryController:Start()
	self._craftButtons = {}

	self._trove:Add(HUDController.MenuOpenRequested:Connect(function()
		InventoryController.Toggle()
	end))

	local ok, session = pcall(function()
		return Net.GetFunction("RequestPlayerSession"):InvokeServer()
	end)
	if ok and session then
		local data = session :: PlayerSessionTypes.PlayerSessionData
		self._inventory = data.Inventory
		self._equippedTool = data.EquippedTool
	else
		warn("InventoryController: failed to fetch initial session", session)
	end

	self._trove:Add(Net.GetEvent("InventoryChanged").OnClientEvent:Connect(function(inventory: { [string]: number })
		self._inventory = inventory
		if InventoryController.IsOpen() then
			self:_refreshTabs()
		end
	end))

	self._trove:Add(UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed or not InventoryController.IsOpen() then
			return
		end
		if input.KeyCode == Enum.KeyCode.ButtonB or input.KeyCode == Enum.KeyCode.Escape then
			InventoryController.Close()
		end
	end))
end

return InventoryController
