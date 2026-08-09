--!strict
-- The Shop panel (Season Pass + Premium/Gamepasses tabs) and the Starter
-- Pack offer panel, opened by HUDController's 2 left-middle buttons. Same
-- dark-glass panel pattern InventoryController established (backdrop
-- CanvasGroup + GlassPanel + PanelScale tween).
--
-- UI/HUD Visual Direction Pass: Season Pass, Premium, and Starter Pack all
-- render on the shared HeroOffer composition (src/client/UI/Components/
-- HeroOffer.luau) instead of small ItemCell grid cells — one component,
-- three call sites, each with a distinct accent color/glyph/value-section
-- content so the three offers read as genuinely different, not the same
-- card relabeled (see HeroOffer's own header comment).
--
-- Every offer's ProductOrPassId is a placeholder 0 until a real id exists
-- in the Creator Dashboard (see MonetizationConfig) — for those, the CTA
-- button is disabled and shows "Coming Soon," and no price is displayed at
-- all. PromptProductPurchase/PromptGamePassPurchase is never called with a
-- placeholder id. Once a real id is configured, the displayed price is
-- fetched live via MarketplaceService:GetProductInfo so it can never
-- disagree with the Creator Dashboard — no hardcoded price is trusted.

local GuiService = game:GetService("GuiService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage.Shared.Modules.Trove)
local MonetizationConfig = require(ReplicatedStorage.Shared.Config.MonetizationConfig)

local Theme = require(script.Parent.Parent.UI.Theme)
local Motion = require(script.Parent.Parent.UI.Motion)
local FacilityRouter = require(script.Parent.Parent.UI.FacilityRouter)
local GamepadNav = require(script.Parent.Parent.UI.GamepadNav)
local GlassPanel = require(script.Parent.Parent.UI.Components.GlassPanel)
local TabStrip = require(script.Parent.Parent.UI.Components.TabStrip)
local CloseButton = require(script.Parent.Parent.UI.Components.CloseButton)
local HeroOffer = require(script.Parent.Parent.UI.Components.HeroOffer)

local HUDController = require(script.Parent.HUDController)

local ShopController = {}

local shopOpen = false
local starterPackOpen = false
local shopPreviousSelection: GuiObject? = nil
local starterPackPreviousSelection: GuiObject? = nil

local priceCache: { [string]: number? } = {}

local function fetchLivePriceRobux(offer: MonetizationConfig.Offer): number?
	if offer.ProductOrPassId == 0 then
		return nil
	end
	if priceCache[offer.Id] ~= nil then
		return priceCache[offer.Id]
	end

	local infoType = if offer.Kind == "GamePass" then Enum.InfoType.GamePass else Enum.InfoType.Product
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(offer.ProductOrPassId, infoType)
	end)
	if ok and info and info.PriceInRobux then
		priceCache[offer.Id] = info.PriceInRobux
		return info.PriceInRobux
	end
	return nil
end

local function promptPurchase(offer: MonetizationConfig.Offer)
	if offer.ProductOrPassId == 0 then
		return
	end
	local player = Players.LocalPlayer
	if offer.Kind == "GamePass" then
		MarketplaceService:PromptGamePassPurchase(player, offer.ProductOrPassId)
	else
		MarketplaceService:PromptProductPurchase(player, offer.ProductOrPassId)
	end
end

local function rewardTilesFor(offer: MonetizationConfig.Offer): { HeroOffer.RewardTile }
	local tiles: { HeroOffer.RewardTile } = {}
	for _, line in offer.Contents do
		if line.Kind == "Currency" then
			table.insert(tiles, { ItemId = "Scrap", Amount = line.Amount })
		else
			table.insert(tiles, { ItemId = line.ItemId, Amount = line.Amount })
		end
	end
	return tiles
end

-- Returns the CTA button so callers can gather it for GamepadNav wiring.
local function renderOfferHero(parent: Instance, offer: MonetizationConfig.Offer, icon: string, accentColor: Color3, layoutOrder: number): TextButton
	local isConfigured = offer.ProductOrPassId ~= 0
	local livePrice = fetchLivePriceRobux(offer)
	local priceText = if not isConfigured then "COMING SOON" elseif livePrice then `R$ {livePrice}` else "R$ —"
	local tiles = rewardTilesFor(offer)

	local _card, button = HeroOffer.new({
		Name = offer.Id,
		Icon = icon,
		AccentColor = accentColor,
		BadgeText = if not isConfigured then "COMING SOON" else nil,
		BadgeVariant = "Locked",
		Title = offer.Name,
		Description = offer.Description,
		RewardTiles = if #tiles > 0 then tiles else nil,
		PriceText = priceText,
		ButtonText = if isConfigured then "Buy" else "Coming Soon",
		ButtonDisabled = not isConfigured,
		LayoutOrder = layoutOrder,
		OnActivated = function()
			promptPurchase(offer)
		end,
		Parent = parent,
	})

	return button
end

-- Header block (icon + title + subtitle) shared by both Shop and Starter
-- Pack panel shells — kept inline rather than a new component since it's 3
-- static elements, not reused logic.
local function buildHeader(parent: Instance, icon: string, title: string, subtitle: string, accentColor: Color3)
	local row = Instance.new("Frame")
	row.Name = "Header"
	row.Size = UDim2.new(1, -52, 0, 0)
	row.AutomaticSize = Enum.AutomaticSize.Y
	row.BackgroundTransparency = 1
	row.Parent = parent

	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	rowLayout.Padding = UDim.new(0, Theme.Spacing.S)
	rowLayout.Parent = row

	local iconLabel = Instance.new("TextLabel")
	iconLabel.BackgroundTransparency = 1
	iconLabel.Size = UDim2.fromOffset(28, 28)
	iconLabel.LayoutOrder = 1
	iconLabel.Font = Enum.Font.GothamBold
	iconLabel.TextSize = 24
	iconLabel.TextColor3 = accentColor
	iconLabel.Text = icon
	iconLabel.Parent = row

	local textColumn = Instance.new("Frame")
	textColumn.AutomaticSize = Enum.AutomaticSize.Y
	textColumn.Size = UDim2.new(1, -34, 0, 0)
	textColumn.LayoutOrder = 2
	textColumn.BackgroundTransparency = 1
	textColumn.Parent = row

	local textLayout = Instance.new("UIListLayout")
	textLayout.FillDirection = Enum.FillDirection.Vertical
	textLayout.Parent = textColumn

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.AutomaticSize = Enum.AutomaticSize.Y
	titleLabel.Size = UDim2.new(1, 0, 0, 0)
	titleLabel.LayoutOrder = 1
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Theme.Font.Title.Font
	titleLabel.TextSize = Theme.Font.Title.Size
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextColor3 = Theme.Colors.TextPrimary
	titleLabel.Text = title
	titleLabel.Parent = textColumn

	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Name = "Subtitle"
	subtitleLabel.AutomaticSize = Enum.AutomaticSize.Y
	subtitleLabel.Size = UDim2.new(1, 0, 0, 0)
	subtitleLabel.LayoutOrder = 2
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Font = Theme.Font.Caption.Font
	subtitleLabel.TextSize = Theme.Font.Caption.Size
	subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
	subtitleLabel.TextColor3 = Theme.Colors.TextMuted
	subtitleLabel.Text = subtitle
	subtitleLabel.Parent = textColumn
end

function ShopController:_buildShopPanel()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ShopUI"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
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
	self._shopBackdrop = backdrop

	local backdropButton = Instance.new("TextButton")
	backdropButton.Name = "BackdropCatcher"
	backdropButton.Size = UDim2.fromScale(1, 1)
	backdropButton.BackgroundTransparency = 1
	backdropButton.Text = ""
	backdropButton.AutoButtonColor = false
	backdropButton.Parent = backdrop
	self._trove:Add(backdropButton.Activated:Connect(function()
		ShopController.CloseShop()
	end))

	local panel = GlassPanel.new({
		Name = "Panel",
		Size = UDim2.new(0.8, 0, 0.78, 0),
		Position = UDim2.fromScale(0.5, 0.46),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = backdrop,
	})
	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = Vector2.new(360, 460)
	sizeConstraint.MaxSize = Vector2.new(640, 620)
	sizeConstraint.Parent = panel
	self._shopPanel = panel

	local panelScale = Instance.new("UIScale")
	panelScale.Name = "PanelScale"
	panelScale.Scale = 0.94
	panelScale.Parent = panel
	self._shopPanelScale = panelScale

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, Theme.Spacing.L)
	padding.PaddingRight = UDim.new(0, Theme.Spacing.L)
	padding.PaddingTop = UDim.new(0, Theme.Spacing.L)
	padding.PaddingBottom = UDim.new(0, Theme.Spacing.L)
	padding.Parent = panel

	buildHeader(panel, "🛍", "SHOP", "Premium upgrades for Eclipse survivors", Theme.Colors.Brand)

	local closeButton = CloseButton.new({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		OnActivated = function()
			ShopController.CloseShop()
		end,
		Parent = panel,
	})

	local _tabStrip, _selectTab, tabButtons = TabStrip.new({
		Name = "Tabs",
		Position = UDim2.new(0, 0, 0, 58),
		Tabs = {
			{ Id = "Season", Label = "Season Pass" },
			{ Id = "Premium", Label = "Premium" },
		},
		InitialTabId = "Season",
		OnTabSelected = function(tabId: string)
			self._seasonTab.Visible = tabId == "Season"
			self._premiumTab.Visible = tabId == "Premium"
		end,
		Parent = panel,
	})

	local seasonTab = Instance.new("ScrollingFrame")
	seasonTab.Name = "SeasonTab"
	seasonTab.Size = UDim2.new(1, 0, 1, -102)
	seasonTab.Position = UDim2.new(0, 0, 0, 102)
	seasonTab.BackgroundTransparency = 1
	seasonTab.BorderSizePixel = 0
	seasonTab.CanvasSize = UDim2.new(0, 0, 0, 0)
	seasonTab.AutomaticCanvasSize = Enum.AutomaticSize.Y
	seasonTab.ScrollBarThickness = 6
	seasonTab.Parent = panel
	self._seasonTab = seasonTab

	local seasonLayout = Instance.new("UIListLayout")
	seasonLayout.Padding = UDim.new(0, Theme.Spacing.M)
	seasonLayout.Parent = seasonTab

	local premiumTab = Instance.new("ScrollingFrame")
	premiumTab.Name = "PremiumTab"
	premiumTab.Size = UDim2.new(1, 0, 1, -102)
	premiumTab.Position = UDim2.new(0, 0, 0, 102)
	premiumTab.BackgroundTransparency = 1
	premiumTab.BorderSizePixel = 0
	premiumTab.CanvasSize = UDim2.new(0, 0, 0, 0)
	premiumTab.AutomaticCanvasSize = Enum.AutomaticSize.Y
	premiumTab.ScrollBarThickness = 6
	premiumTab.Visible = false
	premiumTab.Parent = panel
	self._premiumTab = premiumTab

	local premiumLayout = Instance.new("UIListLayout")
	premiumLayout.Padding = UDim.new(0, Theme.Spacing.M)
	premiumLayout.Parent = premiumTab

	local seasonBuyButton = renderOfferHero(seasonTab, MonetizationConfig.SeasonPass, "🎫", Theme.Colors.Brand, 1)

	local premiumButtons: { TextButton } = {}
	for index, offer in MonetizationConfig.Gamepasses do
		table.insert(premiumButtons, renderOfferHero(premiumTab, offer, "💎", Theme.Colors.BrandLight, index))
	end

	GamepadNav.LinkChain({ closeButton, table.unpack(tabButtons) })
	GamepadNav.LinkChain({ seasonBuyButton })
	if #premiumButtons > 0 then
		GamepadNav.LinkChain(premiumButtons)
	end
end

function ShopController:_buildStarterPackPanel()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "StarterPackUI"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
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
	self._starterPackBackdrop = backdrop

	local backdropButton = Instance.new("TextButton")
	backdropButton.Name = "BackdropCatcher"
	backdropButton.Size = UDim2.fromScale(1, 1)
	backdropButton.BackgroundTransparency = 1
	backdropButton.Text = ""
	backdropButton.AutoButtonColor = false
	backdropButton.Parent = backdrop
	self._trove:Add(backdropButton.Activated:Connect(function()
		ShopController.CloseStarterPack()
	end))

	local accentColor = Theme.Colors.Gold

	local panel = GlassPanel.new({
		Name = "Panel",
		Size = UDim2.new(0.6, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.fromScale(0.5, 0.46),
		AnchorPoint = Vector2.new(0.5, 0.5),
		AccentColor = accentColor,
		Gradient = false,
		Parent = backdrop,
	})
	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = Vector2.new(320, 0)
	sizeConstraint.MaxSize = Vector2.new(440, 700)
	sizeConstraint.Parent = panel
	self._starterPackPanel = panel

	local panelScale = Instance.new("UIScale")
	panelScale.Name = "PanelScale"
	panelScale.Scale = 0.94
	panelScale.Parent = panel
	self._starterPackPanelScale = panelScale

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, Theme.Spacing.L)
	padding.PaddingRight = UDim.new(0, Theme.Spacing.L)
	padding.PaddingTop = UDim.new(0, Theme.Spacing.L)
	padding.PaddingBottom = UDim.new(0, Theme.Spacing.L)
	padding.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.Padding = UDim.new(0, Theme.Spacing.S)
	layout.Parent = panel

	buildHeader(panel, "🎁", "NEW SURVIVOR OFFER", "A head start for players just arriving in Eclipse", accentColor)

	local closeButton = CloseButton.new({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		OnActivated = function()
			ShopController.CloseStarterPack()
		end,
		Parent = panel,
	})
	closeButton.LayoutOrder = 0

	local isConfigured = MonetizationConfig.StarterPack.ProductOrPassId ~= 0
	local livePrice = fetchLivePriceRobux(MonetizationConfig.StarterPack)
	local priceText = if not isConfigured then "COMING SOON" elseif livePrice then `R$ {livePrice}` else "R$ —"

	local _card, claimButton = HeroOffer.new({
		Icon = "🎁",
		AccentColor = accentColor,
		BadgeText = "LIMITED-TIME",
		BadgeVariant = "Recommended",
		Title = MonetizationConfig.StarterPack.Name,
		Description = MonetizationConfig.StarterPack.Description,
		RewardTiles = rewardTilesFor(MonetizationConfig.StarterPack),
		PriceText = priceText,
		ButtonText = if isConfigured then "Claim Offer" else "Coming Soon",
		ButtonDisabled = not isConfigured,
		LayoutOrder = 2,
		OnActivated = function()
			promptPurchase(MonetizationConfig.StarterPack)
		end,
		Parent = panel,
	})

	GamepadNav.LinkChain({ closeButton, claimButton })
end

function ShopController:Init()
	self._trove = Trove.new()
	self:_buildShopPanel()
	self:_buildStarterPackPanel()

	-- Lets the Daily Rewards screen's "VIEW PASS" hand off to this existing
	-- shop on an explicit press. Registered as a route rather than required
	-- directly so no facility screen has to depend on this controller — and
	-- so nothing here can ever be triggered automatically.
	FacilityRouter.Register("Shop", function()
		ShopController.OpenShop()
	end)
end

function ShopController.OpenShop()
	if shopOpen then
		return
	end
	shopOpen = true

	local self = ShopController
	self._shopBackdrop.Visible = true
	Motion.Tween(self._shopBackdrop, "Fade", Theme.Motion.PanelOpen, { GroupTransparency = 0 })
	Motion.Tween(self._shopPanelScale, "Scale", Theme.Motion.PanelOpen, { Scale = 1 })

	shopPreviousSelection = GuiService.SelectedObject
	GamepadNav.FocusFirst(self._shopPanel)
end

function ShopController.CloseShop()
	if not shopOpen then
		return
	end
	shopOpen = false

	local self = ShopController
	local tween = Motion.Tween(self._shopBackdrop, "Fade", Theme.Motion.PanelClose, { GroupTransparency = 1 })
	Motion.Tween(self._shopPanelScale, "Scale", Theme.Motion.PanelClose, { Scale = 0.94 })
	tween.Completed:Once(function()
		if not shopOpen then
			self._shopBackdrop.Visible = false
		end
	end)

	GamepadNav.Restore(shopPreviousSelection)
end

function ShopController.OpenStarterPack()
	if starterPackOpen then
		return
	end
	starterPackOpen = true

	local self = ShopController
	self._starterPackBackdrop.Visible = true
	Motion.Tween(self._starterPackBackdrop, "Fade", Theme.Motion.PanelOpen, { GroupTransparency = 0 })
	Motion.Tween(self._starterPackPanelScale, "Scale", Theme.Motion.PanelOpen, { Scale = 1 })

	starterPackPreviousSelection = GuiService.SelectedObject
	GamepadNav.FocusFirst(self._starterPackPanel)
end

function ShopController.CloseStarterPack()
	if not starterPackOpen then
		return
	end
	starterPackOpen = false

	local self = ShopController
	local tween = Motion.Tween(self._starterPackBackdrop, "Fade", Theme.Motion.PanelClose, { GroupTransparency = 1 })
	Motion.Tween(self._starterPackPanelScale, "Scale", Theme.Motion.PanelClose, { Scale = 0.94 })
	tween.Completed:Once(function()
		if not starterPackOpen then
			self._starterPackBackdrop.Visible = false
		end
	end)

	GamepadNav.Restore(starterPackPreviousSelection)
end

function ShopController:Start()
	self._trove:Add(HUDController.ShopOpenRequested:Connect(function()
		ShopController.OpenShop()
	end))
	self._trove:Add(HUDController.StarterPackOpenRequested:Connect(function()
		ShopController.OpenStarterPack()
	end))
end

return ShopController
