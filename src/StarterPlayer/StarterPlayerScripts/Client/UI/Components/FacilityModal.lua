--!strict
-- THE shared facility modal shell. Every screen a player opens by pressing E
-- at a facility is one of these.
--
-- ===========================================================================
-- VISUAL REBUILD
-- ===========================================================================
-- The previous shell was a near-black rounded rectangle with a 1.5px accent
-- hairline, a dark header row and a thin 3px accent line under it. Rendered,
-- that is a web dialog: the facility's identity was a single thin stripe, and
-- ~85% of the panel was the same near-black as every other panel.
--
-- This version is built like a game window:
--
--   SOLID ACCENT HEADER BAR spanning the full panel width, carrying the
--   facility icon in its own tile, a large black-weight title, a subtitle,
--   and the close button. The header is the facility's identity — you can
--   tell Storage from Defense from across the room.
--
--   LIGHTER CONTENT WELL. The body is Theme.Colors.Surface, a visible step
--   up from the panel, so cards placed on it read as layered rather than
--   floating in a void.
--
--   3px NEAR-BLACK OUTER STROKE plus a drop shadow, which is what makes the
--   whole window read as a solid object sitting above the world.
--
-- Everything else this owns is unchanged in contract: one shared ScreenGui,
-- single-modal exclusivity, Escape/controller-B close, prompt suppression
-- while open, responsive geometry, and delegated open/close motion.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Theme = require(script.Parent.Parent.Theme)
local FacilityStyle = require(script.Parent.Parent.FacilityStyle)
local UIAnimator = require(script.Parent.Parent.UIAnimator)
local GamepadNav = require(script.Parent.Parent.GamepadNav)
local Shadow = require(script.Parent.Parent.Shadow)
local CloseButton = require(script.Parent.CloseButton)
local TabStrip = require(script.Parent.TabStrip)
local ItemIcon = require(script.Parent.ItemIcon)

local FacilityModal = {}
FacilityModal.__index = FacilityModal

export type TabDefinition = { Id: string, Label: string }

export type FacilityModalOptions = {
	Id: string,
	Icon: string, -- IconArt glyph name (see IconArt's `glyphs`)
	Title: string,
	Subtitle: string?,
	Accent: Color3?,
	WidthClass: FacilityStyle.WidthClass?,
	Tabs: { TabDefinition }?,
	OnTabSelected: ((tabId: string) -> ())?,
	OnClose: (() -> ())?,
	FreeformContent: boolean?,
	FitContent: boolean?,
}

export type FacilityModal = typeof(setmetatable({} :: {
	Id: string,
	Content: GuiObject,
	Panel: Frame,
	Accent: Color3,
	_root: CanvasGroup,
	_titleLabel: TextLabel,
	_subtitleLabel: TextLabel,
	_selectTab: ((tabId: string) -> ())?,
	_tabButtons: { TextButton },
	_closeButton: TextButton,
	_onClose: (() -> ())?,
	_onTabSelected: ((tabId: string) -> ())?,
	_isOpen: boolean,
	_widthClass: FacilityStyle.WidthClass,
	_freeform: boolean,
	_fitContent: boolean,
	_innerTop: number,
	_previousSelection: GuiObject?,
}, FacilityModal))

local CLOSE_ACTION = "EclipseFacilityModalClose"
local HEADER_HEIGHT = 68
local TAB_HEIGHT = 42

local sharedScreenGui: ScreenGui? = nil
local activeModal: FacilityModal? = nil
local promptsSuppressed = false

local function ensureScreenGui(): ScreenGui
	if sharedScreenGui and sharedScreenGui.Parent then
		return sharedScreenGui
	end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("EclipseFacilityUI")
	if existing and existing:IsA("ScreenGui") then
		existing.DisplayOrder = 95
		sharedScreenGui = existing
		return existing
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "EclipseFacilityUI"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 95
	screenGui.Parent = playerGui
	sharedScreenGui = screenGui
	return screenGui
end

local function setPromptsSuppressed(suppressed: boolean)
	if suppressed == promptsSuppressed then
		return
	end
	promptsSuppressed = suppressed
	ProximityPromptService.Enabled = not suppressed
end

-- ---------------------------------------------------------------------
-- Header
-- ---------------------------------------------------------------------

local function buildHeader(self: FacilityModal, panel: Frame, options: FacilityModalOptions)
	-- The accent bar. Deliberately opaque and full-bleed: this single element
	-- is responsible for most of the screen's identity and energy.
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, HEADER_HEIGHT)
	header.BackgroundColor3 = self.Accent
	header.BorderSizePixel = 0
	header.ZIndex = 2
	header.Parent = panel

	Theme.GlossGradient(self.Accent).Parent = header

	-- A darker ledge under the bar, matching the button lip idiom, so the
	-- header reads as a raised physical strip.
	local ledge = Instance.new("Frame")
	ledge.Name = "Ledge"
	ledge.AnchorPoint = Vector2.new(0, 0)
	ledge.Position = UDim2.new(0, 0, 1, 0)
	ledge.Size = UDim2.new(1, 0, 0, 3)
	ledge.BackgroundColor3 = self.Accent:Lerp(Theme.Colors.Void, 0.55)
	ledge.BorderSizePixel = 0
	ledge.ZIndex = 3
	ledge.Parent = header

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, Theme.Spacing.M)
	padding.PaddingRight = UDim.new(0, Theme.Spacing.M)
	padding.Parent = header

	-- Facility icon in its own tile, matching the resource-icon language.
	local iconHolder = Instance.new("Frame")
	iconHolder.Name = "IconHolder"
	iconHolder.AnchorPoint = Vector2.new(0, 0.5)
	iconHolder.Position = UDim2.new(0, 0, 0.5, -2)
	iconHolder.Size = UDim2.fromOffset(44, 44)
	iconHolder.BackgroundTransparency = 1
	iconHolder.ZIndex = 4
	iconHolder.Parent = header

	ItemIcon.new({
		Name = "FacilityIcon",
		ItemId = options.Icon,
		Glyph = options.Icon,
		Size = UDim2.fromOffset(44, 44),
		AccentOverride = self.Accent,
		Parent = iconHolder,
	})

	local textColumn = Instance.new("Frame")
	textColumn.Name = "HeaderText"
	textColumn.AnchorPoint = Vector2.new(0, 0.5)
	textColumn.Position = UDim2.new(0, 56, 0.5, -2)
	textColumn.Size = UDim2.new(1, -112, 0, 46)
	textColumn.BackgroundTransparency = 1
	textColumn.ZIndex = 4
	textColumn.Parent = header

	local hasSubtitle = (options.Subtitle or "") ~= ""

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, if hasSubtitle then 26 else 46)
	title.Position = UDim2.fromOffset(0, if hasSubtitle then 1 else 0)
	title.BackgroundTransparency = 1
	title.Font = Theme.Font.Title.Font
	title.TextSize = Theme.Font.Title.Size
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextYAlignment = Enum.TextYAlignment.Center
	title.TextColor3 = Theme.Colors.TextPrimary
	title.TextTruncate = Enum.TextTruncate.AtEnd
	title.TextScaled = true
	title.Text = string.upper(options.Title)
	title.ZIndex = 4
	title.Parent = textColumn
	local titleSize = Instance.new("UITextSizeConstraint")
	titleSize.MinTextSize = 16
	titleSize.MaxTextSize = Theme.Font.Title.Size
	titleSize.Parent = title

	-- A dark drop-shadow stroke keeps a white title readable on a yellow or
	-- lime header, where plain white alone would smear.
	local titleStroke = Instance.new("UIStroke")
	titleStroke.Color = Theme.Colors.Void
	titleStroke.Thickness = 2
	titleStroke.Transparency = 0.55
	titleStroke.Parent = title

	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.Size = UDim2.new(1, 0, 0, 16)
	subtitle.Position = UDim2.fromOffset(0, 28)
	subtitle.BackgroundTransparency = 1
	subtitle.Font = Theme.Font.Label.Font
	subtitle.TextSize = Theme.Font.Label.Size
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	subtitle.TextColor3 = Theme.Colors.TextPrimary
	subtitle.TextTransparency = 0.2
	subtitle.TextTruncate = Enum.TextTruncate.AtEnd
	subtitle.Text = options.Subtitle or ""
	subtitle.Visible = hasSubtitle
	subtitle.ZIndex = 4
	subtitle.Parent = textColumn
	self._subtitleLabel = subtitle
	self._titleLabel = title

	self._closeButton = CloseButton.new({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, -2),
		OnActivated = function()
			self:Close()
		end,
		Parent = header,
	})
	self._closeButton.ZIndex = 5
end

function FacilityModal.new(options: FacilityModalOptions): FacilityModal
	local self = setmetatable({}, FacilityModal) :: FacilityModal
	self.Id = options.Id
	self.Accent = options.Accent or Theme.Colors.Brand
	self._onClose = options.OnClose
	self._onTabSelected = options.OnTabSelected
	self._isOpen = false
	self._tabButtons = {}
	self._widthClass = options.WidthClass or "Regular"
	self._freeform = options.FreeformContent == true
	self._fitContent = options.FitContent ~= false and not self._freeform
	self._innerTop = 0

	local screenGui = ensureScreenGui()

	local root = Instance.new("CanvasGroup")
	root.Name = `{options.Id}Modal`
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = Theme.Colors.Void
	-- Darker scrim than before. A modal should clearly own the screen; the
	-- previous 0.45 left the world competing with the panel for attention.
	root.BackgroundTransparency = 0.5
	root.GroupTransparency = 1
	root.Visible = false
	root.Parent = screenGui
	self._root = root

	local catcher = Instance.new("TextButton")
	catcher.Name = "BackdropCatcher"
	catcher.Size = UDim2.fromScale(1, 1)
	catcher.BackgroundTransparency = 1
	catcher.Text = ""
	catcher.AutoButtonColor = false
	catcher.Selectable = false
	catcher.Parent = root
	catcher.Activated:Connect(function()
		self:Close()
	end)

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.BackgroundColor3 = Theme.Colors.PanelBackground
	panel.BackgroundTransparency = 0
	panel.BorderSizePixel = 0
	panel.ClipsDescendants = true
	panel.Parent = root
	self.Panel = panel

	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = Theme.Corner.Large
	panelCorner.Parent = panel

	Theme.Outline(panel, Theme.Stroke.Panel)
	Shadow.Attach(panel, { Transparency = Theme.Shadow.Hero.Transparency, Offset = Theme.Shadow.Hero.Offset })

	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.Name = "SizeConstraint"
	sizeConstraint.Parent = panel

	buildHeader(self, panel, options)

	local contentTop = HEADER_HEIGHT + 3 -- + subtle header ledge

	-- The content well: a visibly lighter surface than the panel, which is
	-- what stops the interior reading as one flat black field.
	local well = Instance.new("Frame")
	well.Name = "ContentWell"
	well.Position = UDim2.fromOffset(0, contentTop)
	well.Size = UDim2.new(1, 0, 1, -contentTop)
	well.BackgroundColor3 = Theme.Colors.Surface
	well.BorderSizePixel = 0
	well.Parent = panel

	local wellPadding = Instance.new("UIPadding")
	wellPadding.PaddingLeft = UDim.new(0, Theme.Spacing.M)
	wellPadding.PaddingRight = UDim.new(0, Theme.Spacing.M)
	wellPadding.PaddingTop = UDim.new(0, Theme.Spacing.M)
	wellPadding.PaddingBottom = UDim.new(0, Theme.Spacing.M)
	wellPadding.Parent = well

	local innerTop = 0
	if options.Tabs and #options.Tabs > 0 then
		local tabsScroller = Instance.new("ScrollingFrame")
		tabsScroller.Name = "Tabs"
		tabsScroller.Position = UDim2.fromOffset(0, 0)
		tabsScroller.Size = UDim2.new(1, 0, 0, TAB_HEIGHT)
		tabsScroller.BackgroundTransparency = 1
		tabsScroller.BorderSizePixel = 0
		tabsScroller.ScrollBarThickness = 0
		tabsScroller.ScrollingDirection = Enum.ScrollingDirection.X
		tabsScroller.AutomaticCanvasSize = Enum.AutomaticSize.X
		tabsScroller.CanvasSize = UDim2.new()
		tabsScroller.Parent = well

		local strip, selectTab, buttons = TabStrip.new({
			Name = "TabStrip",
			Size = UDim2.new(0, 0, 1, 0),
			Tabs = options.Tabs,
			InitialTabId = options.Tabs[1].Id,
			AccentColor = self.Accent,
			OnTabSelected = function(tabId: string)
				if self._onTabSelected then
					self._onTabSelected(tabId)
				end
			end,
			Parent = tabsScroller,
		})
		strip.AutomaticSize = Enum.AutomaticSize.X
		self._selectTab = selectTab
		self._tabButtons = buttons
		innerTop = TAB_HEIGHT + Theme.Spacing.S
	end

	if self._freeform then
		local content = Instance.new("Frame")
		content.Name = "Content"
		content.Position = UDim2.fromOffset(0, innerTop)
		content.Size = UDim2.new(1, 0, 1, -innerTop)
		content.BackgroundTransparency = 1
		content.Parent = well
		self.Content = content
	else
		local content = Instance.new("ScrollingFrame")
		content.Name = "Content"
		content.Position = UDim2.fromOffset(0, innerTop)
		content.Size = UDim2.new(1, 0, 1, -innerTop)
		content.BackgroundTransparency = 1
		content.BorderSizePixel = 0
		content.CanvasSize = UDim2.new()
		content.AutomaticCanvasSize = Enum.AutomaticSize.Y
		content.ScrollBarThickness = 5
		content.ScrollBarImageColor3 = self.Accent
		content.ScrollBarImageTransparency = 0.25
		content.ScrollingDirection = Enum.ScrollingDirection.Y
		content.Parent = well

		local layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.VerticalAlignment = Enum.VerticalAlignment.Top
		layout.Padding = UDim.new(0, Theme.Spacing.S)
		layout.Parent = content

		local contentPadding = Instance.new("UIPadding")
		contentPadding.PaddingRight = UDim.new(0, Theme.Spacing.S)
		contentPadding.PaddingBottom = UDim.new(0, Theme.Spacing.S)
		contentPadding.Parent = content

		self.Content = content
		layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			if self._fitContent and self._isOpen then
				self:_applyGeometry()
			end
		end)
	end
	self._innerTop = innerTop

	-- Keep a failed initial geometry calculation from leaving a partial modal
	-- root in PlayerGui. The error is rethrown; this is cleanup, not masking.
	local geometryOk, geometryError = xpcall(function()
		self:_applyGeometry()
	end, debug.traceback)
	if not geometryOk then
		root:Destroy()
		error(geometryError, 0)
	end
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			self:_applyGeometry()
		end)
	end

	return self
end

function FacilityModal:_applyGeometry()
	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local size, minSize, maxSize = FacilityStyle.PanelGeometry(viewport, self._widthClass)
	-- Defense in depth: PanelGeometry already returns ordered bounds, but this
	-- method owns the clamp and must remain safe even if a future geometry
	-- policy regresses or receives an uninitialized viewport.
	maxSize = Vector2.new(math.max(1, maxSize.X), math.max(1, maxSize.Y))
	minSize = Vector2.new(math.clamp(minSize.X, 0, maxSize.X), math.clamp(minSize.Y, 0, maxSize.Y))
	if self._fitContent then
		local layout = self.Content:FindFirstChildOfClass("UIListLayout")
		local contentHeight = if layout then layout.AbsoluteContentSize.Y else 0
		local desiredHeight = HEADER_HEIGHT
			+ 3
			+ Theme.Spacing.M * 2
			+ self._innerTop
			+ contentHeight
			+ Theme.Spacing.S
		desiredHeight = math.clamp(desiredHeight, minSize.Y, maxSize.Y)
		size = UDim2.new(size.X.Scale, size.X.Offset, 0, desiredHeight)
	end

	self.Panel.Size = size
	local constraint = self.Panel:FindFirstChild("SizeConstraint") :: UISizeConstraint?
	if constraint then
		constraint.MinSize = minSize
		constraint.MaxSize = maxSize
	end
end

function FacilityModal:SetHeader(title: string?, subtitle: string?)
	if title then
		self._titleLabel.Text = string.upper(title)
	end
	if subtitle ~= nil then
		self._subtitleLabel.Text = subtitle
		self._subtitleLabel.Visible = subtitle ~= ""
	end
end

function FacilityModal:ClearContent()
	if self.Content:IsA("ScrollingFrame") then
		self.Content.CanvasPosition = Vector2.zero
	end
	for _, child in self.Content:GetChildren() do
		if not child:IsA("UILayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

function FacilityModal:RevealContent()
	UIAnimator.StaggerChildren(self.Content)
	task.defer(function()
		if self._isOpen then
			self:_applyGeometry()
		end
	end)
end

-- Immediately yields this modal to a child flow (for example Laboratory ->
-- Crafting). It intentionally skips the close tween so two primary panels
-- never coexist during the hand-off; reopening still uses the normal motion.
function FacilityModal:Suspend()
	if not self._isOpen then
		return
	end
	self._isOpen = false
	if activeModal == self then
		activeModal = nil
	end
	ContextActionService:UnbindAction(CLOSE_ACTION)
	self._root.Visible = false
	self._root.GroupTransparency = 1
	GamepadNav.Restore(self._previousSelection)
end

function FacilityModal:SelectTab(tabId: string)
	if self._selectTab then
		self._selectTab(tabId)
	end
end

function FacilityModal:IsOpen(): boolean
	return self._isOpen
end

function FacilityModal:Open(initialTabId: string?)
	if self._isOpen then
		if initialTabId then
			self:SelectTab(initialTabId)
		end
		return
	end

	if activeModal and activeModal ~= self then
		activeModal:Close()
	end
	activeModal = self
	self._isOpen = true

	setPromptsSuppressed(true)

	if initialTabId then
		self:SelectTab(initialTabId)
	end

	UIAnimator.OpenModal(self._root, self.Panel)

	self._previousSelection = GuiService.SelectedObject
	GamepadNav.FocusFirst(self.Panel)

	ContextActionService:BindAction(CLOSE_ACTION, function(_, inputState: Enum.UserInputState)
		if inputState == Enum.UserInputState.Begin then
			self:Close()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.Escape, Enum.KeyCode.ButtonB)
end

function FacilityModal:Close()
	if not self._isOpen then
		return
	end
	self._isOpen = false
	if activeModal == self then
		activeModal = nil
		setPromptsSuppressed(false)
	end

	ContextActionService:UnbindAction(CLOSE_ACTION)

	UIAnimator.CloseModal(self._root, self.Panel, function()
		if not self._isOpen then
			self._root.Visible = false
		end
	end)

	GamepadNav.Restore(self._previousSelection)

	if self._onClose then
		self._onClose()
	end
end

function FacilityModal.CloseActive()
	if activeModal then
		activeModal:Close()
	end
end

function FacilityModal.GetActive(): FacilityModal?
	return activeModal
end

return FacilityModal
