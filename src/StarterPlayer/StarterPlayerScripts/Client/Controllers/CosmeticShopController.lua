--!strict
-- COSMETIC SHOP — the Haven's cosmetics facility.
--
-- HONEST SCOPE: there is no cosmetic system in this game. No config defines
-- skins, banners, base decorations or effects; no service owns ownership or
-- equipping; there is no cosmetic currency and no purchase path. Its Haven
-- prompt previously read "View" and did nothing.
--
-- So this screen is a genuine, complete SHELL: the category tabs, the card
-- grid geometry, the preview pane and the responsive stacking behaviour all
-- exist and are laid out for real, and every card is explicitly marked as a
-- placeholder for a system that is not built. Nothing can be bought,
-- equipped or owned, no card claims a price, and no button pretends to work
-- (brief §43/§44/§56).
--
-- The layout choice worth knowing: on a wide screen the grid and preview sit
-- side by side; below FacilityStyle's narrow breakpoint the preview stacks
-- above the grid instead, which is why this modal uses FreeformContent and
-- lays itself out rather than dropping into the shell's vertical list.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage.Shared.Modules.Trove)

local Theme = require(script.Parent.Parent.UI.Theme)
local FacilityStyle = require(script.Parent.Parent.UI.FacilityStyle)
local FacilityRouter = require(script.Parent.Parent.UI.FacilityRouter)
local UIAnimator = require(script.Parent.Parent.UI.UIAnimator)
local FacilityModal = require(script.Parent.Parent.UI.Components.FacilityModal)
local StatusChip = require(script.Parent.Parent.UI.Components.StatusChip)
local Surface = require(script.Parent.Parent.UI.Components.Surface)
local ItemIcon = require(script.Parent.Parent.UI.Components.ItemIcon)

local CosmeticShopController = {}

local IDENTITY = FacilityStyle.Facilities.CosmeticShop
local ACCENT = IDENTITY.Accent

local TABS = {
	{ Id = "Skins", Label = "SKINS" },
	{ Id = "Banners", Label = "BANNERS" },
	{ Id = "Base", Label = "BASE" },
	{ Id = "Effects", Label = "EFFECTS" },
}

-- Category framing only. These are NOT items — there is no cosmetic content
-- to list, and inventing named cosmetics would be exactly the fake content
-- this pass forbids. Each tab describes what will live there.
local CATEGORY_COPY: { [string]: { Glyph: string, Blurb: string } } = {
	Skins = { Glyph = "Cosmetic", Blurb = "Survivor outfits and field gear." },
	Banners = { Glyph = "Star", Blurb = "Banners flown over your settlement." },
	Base = { Glyph = "Base", Blurb = "Decorative structures and base finishes." },
	Effects = { Glyph = "Power", Blurb = "Construction and arrival visual effects." },
}

local PLACEHOLDER_SLOTS = 6

local modal: FacilityModal.FacilityModal? = nil
local currentTab = "Skins"
local gridFrame: ScrollingFrame? = nil
local previewFrame: Frame? = nil

-- ---------------------------------------------------------------------
-- Layout
-- ---------------------------------------------------------------------

local function buildLayout(content: GuiObject)
	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local stacked = FacilityStyle.ShouldStack(viewport)

	for _, child in content:GetChildren() do
		child:Destroy()
	end

	local preview = Instance.new("Frame")
	preview.Name = "Preview"
	preview.BackgroundColor3 = Theme.Colors.CardBackground
	preview.BackgroundTransparency = Theme.Transparency.CardBackground
	preview.BorderSizePixel = 0
	preview.Parent = content
	local previewCorner = Instance.new("UICorner")
	previewCorner.CornerRadius = Theme.Corner.Medium
	previewCorner.Parent = preview

	local grid = Instance.new("ScrollingFrame")
	grid.Name = "Grid"
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.CanvasSize = UDim2.new()
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.ScrollBarThickness = 4
	grid.ScrollBarImageColor3 = ACCENT
	grid.ScrollBarImageTransparency = 0.5
	grid.Parent = content

	if stacked then
		-- Narrow: preview on top, grid fills the rest.
		preview.Position = UDim2.fromScale(0, 0)
		preview.Size = UDim2.new(1, 0, 0, 130)
		grid.Position = UDim2.fromOffset(0, 138)
		grid.Size = UDim2.new(1, 0, 1, -138)
	else
		-- Wide: grid left, preview right.
		grid.Position = UDim2.fromScale(0, 0)
		grid.Size = UDim2.new(0.62, -Theme.Spacing.S, 1, 0)
		preview.AnchorPoint = Vector2.new(1, 0)
		preview.Position = UDim2.fromScale(1, 0)
		preview.Size = UDim2.new(0.38, 0, 1, 0)
	end

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.fromOffset(112, 140)
	gridLayout.CellPadding = UDim2.fromOffset(Theme.Spacing.S, Theme.Spacing.S)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.FillDirection = Enum.FillDirection.Horizontal
	gridLayout.StartCorner = Enum.StartCorner.TopLeft
	gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	gridLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	gridLayout.Parent = grid

	gridFrame = grid
	previewFrame = preview
end

-- ---------------------------------------------------------------------
-- Content
-- ---------------------------------------------------------------------

local function renderPreview()
	local preview = previewFrame
	if not preview then
		return
	end
	for _, child in preview:GetChildren() do
		if not child:IsA("UICorner") then
			child:Destroy()
		end
	end

	local copy = CATEGORY_COPY[currentTab]

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, Theme.Spacing.M)
	padding.PaddingRight = UDim.new(0, Theme.Spacing.M)
	padding.PaddingTop = UDim.new(0, Theme.Spacing.M)
	padding.PaddingBottom = UDim.new(0, Theme.Spacing.M)
	padding.Parent = preview

	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.Padding = UDim.new(0, Theme.Spacing.S)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = preview

	ItemIcon.new({
		Name = "CategoryIcon",
		ItemId = copy.Glyph,
		Glyph = copy.Glyph,
		Size = UDim2.fromOffset(56, 56),
		LayoutOrder = 1,
		AccentOverride = ACCENT,
		Parent = preview,
	})

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 24)
	title.LayoutOrder = 2
	title.BackgroundTransparency = 1
	title.Font = Theme.Font.Title.Font
	title.TextSize = 18
	title.TextColor3 = Theme.Colors.TextPrimary
	title.Text = string.upper(currentTab)
	title.Parent = preview

	StatusChip.new({ Status = "Locked", Text = "COMING SOON", LayoutOrder = 3, Parent = preview })

	local blurb = Instance.new("TextLabel")
	blurb.Name = "Blurb"
	blurb.AutomaticSize = Enum.AutomaticSize.Y
	blurb.Size = UDim2.new(1, 0, 0, 0)
	blurb.LayoutOrder = 4
	blurb.BackgroundTransparency = 1
	blurb.Font = Theme.Font.Body.Font
	blurb.TextSize = Theme.Font.Body.Size
	blurb.TextWrapped = true
	blurb.TextColor3 = Theme.Colors.TextMuted
	blurb.Text = copy.Blurb
	blurb.Parent = preview

	local note = Instance.new("TextLabel")
	note.Name = "Note"
	note.AutomaticSize = Enum.AutomaticSize.Y
	note.Size = UDim2.new(1, 0, 0, 0)
	note.LayoutOrder = 5
	note.BackgroundTransparency = 1
	note.Font = Theme.Font.Caption.Font
	note.TextSize = Theme.Font.Caption.Size
	note.TextWrapped = true
	note.TextColor3 = Theme.Colors.TextMuted
	note.Text = "Cosmetics are not in the game yet. Nothing here can be bought or equipped."
	note.Parent = preview
end

-- A locked slot card. Deliberately unnamed and unpriced: it communicates
-- "something will go here" without inventing an item.
local function buildPlaceholderCard(parent: Instance, index: number)
	local card = Surface.new({
		Name = `Slot{index}`,
		Size = UDim2.fromOffset(112, 140),
		LayoutOrder = index,
		Parent = parent,
	})

	local strip = Instance.new("Frame")
	strip.Name = "Strip"
	strip.Size = UDim2.new(1, 0, 0, 18)
	strip.BackgroundColor3 = Theme.Colors.TextMuted
	strip.BackgroundTransparency = 0.7
	strip.BorderSizePixel = 0
	strip.Parent = card

	ItemIcon.new({
		Name = "LockedCategoryIcon",
		ItemId = CATEGORY_COPY[currentTab].Glyph,
		Glyph = CATEGORY_COPY[currentTab].Glyph,
		Size = UDim2.fromOffset(46, 46),
		Position = UDim2.new(0.5, 0, 0, 34),
		AnchorPoint = Vector2.new(0.5, 0),
		AccentOverride = Theme.Colors.TextMuted,
		Flat = true,
		Parent = card,
	})

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -12, 0, 34)
	label.Position = UDim2.fromOffset(6, 92)
	label.BackgroundTransparency = 1
	label.Font = Theme.Font.Caption.Font
	label.TextSize = Theme.Font.Caption.Size
	label.TextWrapped = true
	label.TextColor3 = Theme.Colors.TextMuted
	label.Text = "LOCKED"
	label.Parent = card
end

local function render()
	local activeModal = modal
	if not activeModal then
		return
	end
	buildLayout(activeModal.Content)
	renderPreview()

	local grid = gridFrame
	if grid then
		for index = 1, PLACEHOLDER_SLOTS do
			buildPlaceholderCard(grid, index)
		end
		UIAnimator.StaggerChildren(grid)
	end
end

function CosmeticShopController.Open(initialTab: string?)
	local activeModal = modal
	if not activeModal then
		return
	end
	currentTab = initialTab or "Skins"
	activeModal:Open(currentTab)
	render()
end

function CosmeticShopController:Init()
	self._trove = Trove.new()

	modal = FacilityModal.new({
		Id = "CosmeticShop",
		Icon = IDENTITY.Icon,
		Title = IDENTITY.Title,
		Subtitle = IDENTITY.Subtitle,
		Accent = ACCENT,
		WidthClass = "Wide",
		Tabs = TABS,
		FreeformContent = true,
		OnTabSelected = function(tabId: string)
			currentTab = tabId
			render()
		end,
	})

	FacilityRouter.Register("CosmeticShop", function(tabId: string?)
		CosmeticShopController.Open(tabId)
	end)
end

function CosmeticShopController:Start()
	-- Re-lay out on rotation/resize: the grid/preview split flips to stacked
	-- below the narrow breakpoint, and that has to survive a device rotation
	-- while the screen is open.
	local camera = workspace.CurrentCamera
	if camera then
		self._trove:Add(camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			local activeModal = modal
			if activeModal and activeModal:IsOpen() then
				render()
			end
		end))
	end
end

return CosmeticShopController
