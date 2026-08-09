--!strict
-- Reusable "are you sure?" confirmation modal (Phase 4A) — extracted from
-- the identical backdrop+GlassPanel+PanelScale-tween skeleton every existing
-- panel (Shop, Daily Rewards, Starter Pack) already hand-rolls, since three
-- new panels (Trader valuable-item confirmation, Marketplace listing/
-- purchase confirmation, Base destructive-action confirmation) all need one.
-- A lazily-built singleton overlay — only one confirmation makes sense on
-- screen at a time — reconfigured per call rather than rebuilt.

local Players = game:GetService("Players")

local Theme = require(script.Parent.Parent.Theme)
local Motion = require(script.Parent.Parent.Motion)
local GamepadNav = require(script.Parent.Parent.GamepadNav)
local GlassPanel = require(script.Parent.GlassPanel)
local Button = require(script.Parent.Button)

local ConfirmDialog = {}

export type ConfirmDialogOptions = {
	Title: string,
	Message: string,
	ConfirmText: string?,
	CancelText: string?,
	AccentColor: Color3?,
	Danger: boolean?,
	OnConfirm: (() -> ())?,
	OnCancel: (() -> ())?,
}

local built = false
local isOpen = false
local previousSelection: GuiObject? = nil

local backdrop: CanvasGroup
local panel: Frame
local panelScale: UIScale
local titleLabel: TextLabel
local messageLabel: TextLabel
local confirmButton: TextButton
local cancelButton: TextButton

local onConfirmCallback: (() -> ())? = nil
local onCancelCallback: (() -> ())? = nil

local function close(fromCancel: boolean)
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

	if fromCancel and onCancelCallback then
		onCancelCallback()
	end
end

local function build()
	if built then
		return
	end
	built = true

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ConfirmDialogUI"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	-- Above the facility modal layer (50), which is what raises this dialog:
	-- Production's cancel-job and the trader's sell-below-reserve warnings are
	-- both asked from an open facility screen. At an equal DisplayOrder the
	-- winner would depend on ScreenGui ordering rather than intent, so this
	-- sits deliberately one band higher. Stays below Notifications (60).
	screenGui.DisplayOrder = 54
	screenGui.Parent = playerGui

	backdrop = Instance.new("CanvasGroup")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 1
	backdrop.GroupTransparency = 1
	backdrop.Visible = false
	backdrop.Parent = screenGui

	local backdropButton = Instance.new("TextButton")
	backdropButton.Name = "BackdropCatcher"
	backdropButton.Size = UDim2.fromScale(1, 1)
	backdropButton.BackgroundTransparency = 1
	backdropButton.Text = ""
	backdropButton.AutoButtonColor = false
	backdropButton.Parent = backdrop
	backdropButton.Activated:Connect(function()
		close(true)
	end)

	panel = GlassPanel.new({
		Name = "Panel",
		Size = UDim2.new(0, 380, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.fromScale(0.5, 0.46),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = backdrop,
	})

	panelScale = Instance.new("UIScale")
	panelScale.Name = "PanelScale"
	panelScale.Scale = 0.94
	panelScale.Parent = panel

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, Theme.Spacing.L)
	padding.PaddingRight = UDim.new(0, Theme.Spacing.L)
	padding.PaddingTop = UDim.new(0, Theme.Spacing.L)
	padding.PaddingBottom = UDim.new(0, Theme.Spacing.L)
	padding.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.Padding = UDim.new(0, Theme.Spacing.M)
	layout.Parent = panel

	titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.BackgroundTransparency = 1
	titleLabel.Size = UDim2.new(1, 0, 0, 0)
	titleLabel.AutomaticSize = Enum.AutomaticSize.Y
	titleLabel.LayoutOrder = 1
	titleLabel.Font = Theme.Font.Title.Font
	titleLabel.TextSize = Theme.Font.Title.Size
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextColor3 = Theme.Colors.TextPrimary
	titleLabel.Parent = panel

	messageLabel = Instance.new("TextLabel")
	messageLabel.Name = "Message"
	messageLabel.BackgroundTransparency = 1
	messageLabel.Size = UDim2.new(1, 0, 0, 0)
	messageLabel.AutomaticSize = Enum.AutomaticSize.Y
	messageLabel.LayoutOrder = 2
	messageLabel.Font = Theme.Font.Body.Font
	messageLabel.TextSize = Theme.Font.Body.Size
	messageLabel.TextWrapped = true
	messageLabel.TextXAlignment = Enum.TextXAlignment.Left
	messageLabel.TextColor3 = Theme.Colors.TextSecondary
	messageLabel.Parent = panel

	local buttonRow = Instance.new("Frame")
	buttonRow.Name = "Buttons"
	buttonRow.BackgroundTransparency = 1
	buttonRow.Size = UDim2.new(1, 0, 0, 44)
	buttonRow.LayoutOrder = 3
	buttonRow.Parent = panel

	local buttonLayout = Instance.new("UIListLayout")
	buttonLayout.FillDirection = Enum.FillDirection.Horizontal
	buttonLayout.HorizontalFlex = Enum.UIFlexAlignment.SpaceBetween
	buttonLayout.Parent = buttonRow

	cancelButton = Button.new({
		Text = "Cancel",
		Variant = "Secondary",
		Size = UDim2.new(0.48, 0, 1, 0),
		OnActivated = function()
			close(true)
		end,
		Parent = buttonRow,
	})

	confirmButton = Button.new({
		Text = "Confirm",
		Variant = "Primary",
		Size = UDim2.new(0.48, 0, 1, 0),
		OnActivated = function()
			isOpen = false -- prevent close(true) firing OnCancel from a stray backdrop tap racing the confirm
			local tween = Motion.Tween(backdrop, "Fade", Theme.Motion.PanelClose, { GroupTransparency = 1 })
			Motion.Tween(panelScale, "Scale", Theme.Motion.PanelClose, { Scale = 0.94 })
			tween.Completed:Once(function()
				backdrop.Visible = false
			end)
			GamepadNav.Restore(previousSelection)
			if onConfirmCallback then
				onConfirmCallback()
			end
		end,
		Parent = buttonRow,
	})

	GamepadNav.LinkChain({ cancelButton, confirmButton })
end

function ConfirmDialog.Show(options: ConfirmDialogOptions)
	build()

	titleLabel.Text = options.Title
	messageLabel.Text = options.Message
	local accentColor = options.AccentColor or (if options.Danger then Theme.Colors.Danger else Theme.Colors.Brand)
	local stroke = panel:FindFirstChild("Stroke") :: UIStroke?
	if stroke then
		stroke.Color = accentColor
	end

	local confirmLabel = confirmButton:FindFirstChild("Label") :: TextLabel?
	if confirmLabel then
		confirmLabel.Text = options.ConfirmText or "Confirm"
	end
	local cancelLabel = cancelButton:FindFirstChild("Label") :: TextLabel?
	if cancelLabel then
		cancelLabel.Text = options.CancelText or "Cancel"
	end

	onConfirmCallback = options.OnConfirm
	onCancelCallback = options.OnCancel

	isOpen = true
	backdrop.Visible = true
	Motion.Tween(backdrop, "Fade", Theme.Motion.PanelOpen, { GroupTransparency = 0 })
	Motion.Tween(panelScale, "Scale", Theme.Motion.PanelOpen, { Scale = 1 })

	previousSelection = game:GetService("GuiService").SelectedObject
	GamepadNav.FocusFirst(panel)
end

return ConfirmDialog
