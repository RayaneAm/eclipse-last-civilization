--!strict
-- Personal Base-only build/upgrade confirmation. Unlike the generic text
-- confirmation, this shows owned/required resources and blocks an
-- unaffordable action before a server round trip.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BuildingConfig = require(ReplicatedStorage.Shared.Config.BuildingConfig)
local Theme = require(script.Parent.Parent.Theme)
local Motion = require(script.Parent.Parent.Motion)
local GamepadNav = require(script.Parent.Parent.GamepadNav)
local GlassPanel = require(script.Parent.GlassPanel)
local Surface = require(script.Parent.Surface)
local Button = require(script.Parent.Button)
local ItemIcon = require(script.Parent.ItemIcon)

local BaseActionDialog = {}

export type Options = {
	Title: string,
	Eyebrow: string?,
	Description: string?,
	Detail: string?,
	Cost: BuildingConfig.BuildingCost,
	Storage: { [string]: number },
	Scrap: number,
	ConfirmText: string?,
	AccentColor: Color3?,
	OnConfirm: (() -> ())?,
	OnCancel: (() -> ())?,
}

local built = false
local isOpen = false
local previousSelection: GuiObject? = nil
local backdrop: CanvasGroup
local panel: Frame
local panelScale: UIScale
local accentBand: Frame
local eyebrowLabel: TextLabel
local titleLabel: TextLabel
local descriptionLabel: TextLabel
local detailLabel: TextLabel
local costs: Frame
local confirmButton: TextButton
local cancelButton: TextButton
local onConfirm: (() -> ())? = nil
local onCancel: (() -> ())? = nil

local function close(cancelled: boolean)
	if not isOpen then
		return
	end
	isOpen = false
	local tween = Motion.Tween(backdrop, "Fade", Theme.Motion.PanelClose, { GroupTransparency = 1 })
	Motion.Tween(panelScale, "Scale", Theme.Motion.PanelClose, { Scale = 0.94 })
	tween.Completed:Once(function()
		if not isOpen then
			backdrop.Visible = false
		end
	end)
	GamepadNav.Restore(previousSelection)
	if cancelled and onCancel then
		onCancel()
	end
end

local function textLabel(name: string, order: number, font: Enum.Font, size: number, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.Size = UDim2.new(1, 0, 0, 0)
	label.LayoutOrder = order
	label.BackgroundTransparency = 1
	label.Font = font
	label.TextSize = size
	label.TextColor3 = color
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	return label
end

local function build()
	if built then
		return
	end
	built = true
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "BaseActionDialogUI"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 51
	screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	backdrop = Instance.new("CanvasGroup")
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.35
	backdrop.GroupTransparency = 1
	backdrop.Visible = false
	backdrop.Parent = screenGui
	local catcher = Instance.new("TextButton")
	catcher.Size = UDim2.fromScale(1, 1)
	catcher.BackgroundTransparency = 1
	catcher.Text = ""
	catcher.Parent = backdrop
	catcher.Activated:Connect(function()
		close(true)
	end)

	panel = GlassPanel.new({
		Name = "BaseActionPanel",
		Size = UDim2.new(0.88, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.fromScale(0.5, 0.48),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = backdrop,
	})
	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = Vector2.new(300, 0)
	constraint.MaxSize = Vector2.new(460, 620)
	constraint.Parent = panel
	panelScale = Instance.new("UIScale")
	panelScale.Scale = 0.94
	panelScale.Parent = panel
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, Theme.Spacing.L)
	padding.PaddingRight = UDim.new(0, Theme.Spacing.L)
	padding.PaddingTop = UDim.new(0, Theme.Spacing.L)
	padding.PaddingBottom = UDim.new(0, Theme.Spacing.L)
	padding.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, Theme.Spacing.S)
	layout.Parent = panel

	accentBand = Instance.new("Frame")
	accentBand.Name = "AccentBand"
	accentBand.Size = UDim2.new(1, 0, 0, 4)
	accentBand.LayoutOrder = 1
	accentBand.BorderSizePixel = 0
	accentBand.Parent = panel
	eyebrowLabel = textLabel("Eyebrow", 2, Theme.Font.Label.Font, Theme.Font.Label.Size, Theme.Colors.Teal)
	eyebrowLabel.Parent = panel
	titleLabel = textLabel("Title", 3, Theme.Font.Title.Font, Theme.Font.Title.Size, Theme.Colors.TextPrimary)
	titleLabel.Parent = panel
	descriptionLabel = textLabel("Description", 4, Theme.Font.Body.Font, Theme.Font.Body.Size, Theme.Colors.TextSecondary)
	descriptionLabel.Parent = panel
	detailLabel = textLabel("Detail", 5, Theme.Font.Caption.Font, Theme.Font.Caption.Size, Theme.Colors.TextMuted)
	detailLabel.Parent = panel

	costs = Surface.new({ Name = "Requirements", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 6, Parent = panel })
	local costPadding = Instance.new("UIPadding")
	costPadding.PaddingLeft = UDim.new(0, Theme.Spacing.M)
	costPadding.PaddingRight = UDim.new(0, Theme.Spacing.M)
	costPadding.PaddingTop = UDim.new(0, Theme.Spacing.S)
	costPadding.PaddingBottom = UDim.new(0, Theme.Spacing.S)
	costPadding.Parent = costs
	local costLayout = Instance.new("UIListLayout")
	costLayout.Padding = UDim.new(0, Theme.Spacing.XS)
	costLayout.Parent = costs

	local buttons = Instance.new("Frame")
	buttons.Size = UDim2.new(1, 0, 0, 44)
	buttons.LayoutOrder = 7
	buttons.BackgroundTransparency = 1
	buttons.Parent = panel
	local buttonLayout = Instance.new("UIListLayout")
	buttonLayout.FillDirection = Enum.FillDirection.Horizontal
	buttonLayout.HorizontalFlex = Enum.UIFlexAlignment.SpaceBetween
	buttonLayout.Parent = buttons
	cancelButton = Button.new({
		Text = "Cancel",
		Variant = "Secondary",
		Size = UDim2.new(0.38, 0, 1, 0),
		OnActivated = function()
			close(true)
		end,
		Parent = buttons,
	})
	confirmButton = Button.new({ Text = "Build", Variant = "Primary", Size = UDim2.new(0.58, 0, 1, 0), OnActivated = function()
		if not isOpen then
			return
		end
		local callback = onConfirm
		close(false)
		if callback then
			callback()
		end
	end, Parent = buttons })
	GamepadNav.LinkChain({ cancelButton, confirmButton })
end

local function addCostRow(itemId: string, owned: number, needed: number, order: number): boolean
	local enough = owned >= needed
	local row = Instance.new("Frame")
	row.Name = itemId
	row.Size = UDim2.new(1, 0, 0, 34)
	row.LayoutOrder = order
	row.BackgroundTransparency = 1
	row.Parent = costs
	ItemIcon.new({ ItemId = itemId, Size = UDim2.fromOffset(28, 28), Parent = row })
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Position = UDim2.fromOffset(38, 0)
	name.Size = UDim2.new(1, -132, 1, 0)
	name.Font = Theme.Font.Body.Font
	name.TextSize = Theme.Font.Body.Size
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextColor3 = Theme.Colors.TextSecondary
	name.Text = itemId
	name.Parent = row
	local amount = Instance.new("TextLabel")
	amount.BackgroundTransparency = 1
	amount.Position = UDim2.new(1, -94, 0, 0)
	amount.Size = UDim2.fromOffset(94, 34)
	amount.Font = Theme.Font.Heading.Font
	amount.TextSize = Theme.Font.Body.Size
	amount.TextXAlignment = Enum.TextXAlignment.Right
	amount.TextColor3 = if enough then Theme.Colors.Success else Theme.Colors.Danger
	amount.Text = `{owned} / {needed}`
	amount.Parent = row
	return enough
end

function BaseActionDialog.Show(options: Options)
	build()
	for _, child in costs:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
	local accent = options.AccentColor or Theme.Colors.Teal
	accentBand.BackgroundColor3 = accent
	eyebrowLabel.TextColor3 = accent
	eyebrowLabel.Text = options.Eyebrow or "PERSONAL BASE"
	titleLabel.Text = options.Title
	descriptionLabel.Text = options.Description or ""
	descriptionLabel.Visible = options.Description ~= nil and options.Description ~= ""
	detailLabel.Text = options.Detail or ""
	detailLabel.Visible = options.Detail ~= nil and options.Detail ~= ""
	local affordable = true
	local order = 1
	local itemIds = {}
	for itemId in options.Cost.Materials do
		table.insert(itemIds, itemId)
	end
	table.sort(itemIds)
	for _, itemId in itemIds do
		affordable = addCostRow(itemId, options.Storage[itemId] or 0, options.Cost.Materials[itemId], order) and affordable
		order += 1
	end
	if options.Cost.Scrap > 0 then
		affordable = addCostRow("Scrap", options.Scrap, options.Cost.Scrap, order) and affordable
		order += 1
	end
	if order == 1 then
		local free = textLabel("Free", 1, Theme.Font.Heading.Font, Theme.Font.Heading.Size, Theme.Colors.Success)
		free.Text = "READY • NO COST"
		free.Parent = costs
	end
	local confirmLabel = confirmButton:FindFirstChild("Label")
	if confirmLabel and confirmLabel:IsA("TextLabel") then
		confirmLabel.Text = if affordable then (options.ConfirmText or "Confirm") else "Missing Resources"
	end
	Button.SetDisabled(confirmButton, not affordable)
	onConfirm = options.OnConfirm
	onCancel = options.OnCancel
	isOpen = true
	backdrop.Visible = true
	previousSelection = GuiService.SelectedObject
	Motion.Tween(backdrop, "Fade", Theme.Motion.PanelOpen, { GroupTransparency = 0 })
	Motion.Tween(panelScale, "Scale", Theme.Motion.PanelOpen, { Scale = 1 })
	GamepadNav.FocusFirst(panel)
end

return BaseActionDialog
