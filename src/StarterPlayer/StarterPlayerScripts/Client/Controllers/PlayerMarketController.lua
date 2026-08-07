--!strict
-- Phase 4A: the player-to-player Marketplace panel — Browse/Categories/Sell/
-- My Listings. Opens from anywhere (base, Haven, biome) via its own HUD
-- button, independent of the base NPC trader and the Supply Shop.
--
-- LIVE TRANSACTIONS ARE DISABLED (PlayerMarketConfig.LiveTransactionsEnabled
-- = false — see PlayerMarketService's header comment for the full economy-
-- integrity reasoning). This panel reflects that honestly: a persistent
-- "Marketplace Foundation — Coming Soon" banner, and Sell/Purchase actions
-- that show the server's real rejection reason rather than pretending to
-- succeed. Browse/Search still call the real, live RequestMarketListings
-- (backed by the cross-server MemoryStoreSortedMap index), so the full
-- browse experience is inspectable even while listing/buying is gated off.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local Trove = require(ReplicatedStorage.Shared.Modules.Trove)
local PlayerMarketConfig = require(ReplicatedStorage.Shared.Config.PlayerMarketConfig)

local Theme = require(script.Parent.Parent.UI.Theme)
local Motion = require(script.Parent.Parent.UI.Motion)
local GamepadNav = require(script.Parent.Parent.UI.GamepadNav)
local GlassPanel = require(script.Parent.Parent.UI.Components.GlassPanel)
local CloseButton = require(script.Parent.Parent.UI.Components.CloseButton)
local TabStrip = require(script.Parent.Parent.UI.Components.TabStrip)
local ConfirmDialog = require(script.Parent.Parent.UI.Components.ConfirmDialog)
local OfferCard = require(script.Parent.Parent.UI.Components.OfferCard)
local EmptyState = require(script.Parent.Parent.UI.Components.EmptyState)

local HUDController = require(script.Parent.HUDController)

local PlayerMarketController = {}

local isOpen = false
local previousSelection: GuiObject? = nil

-- Same OfferCard "Row" card language every other shop/economy screen uses —
-- a listing maps onto it cleanly (ItemId -> icon, Price -> CurrencyCostRow,
-- Buy -> the one footer button). The seller line is prefixed (👤) so item/
-- seller/quantity/price read as distinct fields rather than one sentence.
-- Still fully gated behind PlayerMarketConfig.LiveTransactionsEnabled=false
-- (Buy stays disabled) until player Scrap/inventory become cross-server-safe
-- — see this file's own header comment for the full reasoning. Returns the
-- Buy button for GamepadNav chaining.
local function renderListingCard(parent: Instance, listing: any, layoutOrder: number): TextButton
	local _card, button = OfferCard.new({
		Name = listing.ListingId or `Listing{layoutOrder}`,
		ItemId = listing.ItemId,
		Title = `{listing.ItemId} x{listing.Quantity}`,
		Description = `👤 Survivor #{listing.SellerUserId}`,
		ScrapCost = listing.Price,
		ButtonText = "Buy",
		ButtonDisabled = not PlayerMarketConfig.LiveTransactionsEnabled,
		LayoutOrder = layoutOrder,
		OnActivated = function()
			ConfirmDialog.Show({
				Title = "Purchase Listing",
				Message = `Buy {listing.Quantity}x {listing.ItemId} for ◆ {listing.Price}?`,
				ConfirmText = "Buy",
				OnConfirm = function()
					local ok, reason = Net.GetFunction("RequestPurchaseMarketListing"):InvokeServer({ ListingId = listing.ListingId })
					if not ok then
						warn(`PlayerMarketController: purchase failed: {tostring(reason)}`)
					end
				end,
			})
		end,
		Parent = parent,
	})
	return button
end

function PlayerMarketController:_buildPanel()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "PlayerMarketUI"
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
	self._backdrop = backdrop

	local backdropButton = Instance.new("TextButton")
	backdropButton.Name = "BackdropCatcher"
	backdropButton.Size = UDim2.fromScale(1, 1)
	backdropButton.BackgroundTransparency = 1
	backdropButton.Text = ""
	backdropButton.AutoButtonColor = false
	backdropButton.Parent = backdrop
	self._trove:Add(backdropButton.Activated:Connect(function()
		PlayerMarketController.Close()
	end))

	local panel = GlassPanel.new({
		Name = "Panel",
		Size = UDim2.new(0.8, 0, 0.8, 0),
		Position = UDim2.fromScale(0.5, 0.46),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = backdrop,
	})
	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = Vector2.new(380, 440)
	sizeConstraint.MaxSize = Vector2.new(640, 640)
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

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, -52, 0, 40)
	header.BackgroundTransparency = 1
	header.Parent = panel

	local headerLayout = Instance.new("UIListLayout")
	headerLayout.FillDirection = Enum.FillDirection.Horizontal
	headerLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	headerLayout.Padding = UDim.new(0, Theme.Spacing.S)
	headerLayout.Parent = header

	local headerIcon = Instance.new("TextLabel")
	headerIcon.BackgroundTransparency = 1
	headerIcon.Size = UDim2.fromOffset(28, 28)
	headerIcon.LayoutOrder = 1
	headerIcon.Font = Enum.Font.GothamBold
	headerIcon.TextSize = 24
	headerIcon.TextColor3 = Theme.Colors.BrandLight
	headerIcon.Text = "🔁"
	headerIcon.Parent = header

	local headerText = Instance.new("Frame")
	headerText.AutomaticSize = Enum.AutomaticSize.Y
	headerText.Size = UDim2.new(1, -34, 0, 0)
	headerText.LayoutOrder = 2
	headerText.BackgroundTransparency = 1
	headerText.Parent = header

	local headerTextLayout = Instance.new("UIListLayout")
	headerTextLayout.FillDirection = Enum.FillDirection.Vertical
	headerTextLayout.Parent = headerText

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.AutomaticSize = Enum.AutomaticSize.Y
	title.Size = UDim2.new(1, 0, 0, 0)
	title.LayoutOrder = 1
	title.BackgroundTransparency = 1
	title.Font = Theme.Font.Title.Font
	title.TextSize = Theme.Font.Title.Size
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Theme.Colors.TextPrimary
	title.Text = "MARKETPLACE"
	title.Parent = headerText

	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.AutomaticSize = Enum.AutomaticSize.Y
	subtitle.Size = UDim2.new(1, 0, 0, 0)
	subtitle.LayoutOrder = 2
	subtitle.BackgroundTransparency = 1
	subtitle.Font = Theme.Font.Caption.Font
	subtitle.TextSize = Theme.Font.Caption.Size
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	subtitle.TextColor3 = Theme.Colors.TextMuted
	subtitle.Text = "Player-to-player trading"
	subtitle.Parent = headerText

	local closeButton = CloseButton.new({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		OnActivated = function()
			PlayerMarketController.Close()
		end,
		Parent = panel,
	})

	-- Promoted from a small floating Pill to a full-width integrated banner —
	-- still 100% honest about the gate, just visually part of the screen
	-- rather than a token.
	if not PlayerMarketConfig.LiveTransactionsEnabled then
		local banner = Instance.new("Frame")
		banner.Name = "GatedBanner"
		banner.Size = UDim2.new(1, 0, 0, 28)
		banner.Position = UDim2.new(0, 0, 0, 46)
		banner.BackgroundColor3 = Theme.Colors.Warning
		banner.BackgroundTransparency = 0.85
		banner.BorderSizePixel = 0
		banner.Parent = panel

		local bannerCorner = Instance.new("UICorner")
		bannerCorner.CornerRadius = Theme.Corner.Small
		bannerCorner.Parent = banner

		local bannerLabel = Instance.new("TextLabel")
		bannerLabel.BackgroundTransparency = 1
		bannerLabel.Size = UDim2.fromScale(1, 1)
		bannerLabel.Font = Theme.Font.Label.Font
		bannerLabel.TextSize = Theme.Font.Label.Size
		bannerLabel.TextColor3 = Theme.Colors.Warning
		bannerLabel.Text = "MARKETPLACE FOUNDATION — COMING SOON"
		bannerLabel.Parent = banner
	end

	local browseArea = Instance.new("Frame")
	browseArea.Name = "BrowseArea"
	browseArea.Size = UDim2.new(1, 0, 1, -126)
	browseArea.Position = UDim2.new(0, 0, 0, 126)
	browseArea.BackgroundTransparency = 1
	browseArea.Parent = panel

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Listings"
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = 6
	scroll.Parent = browseArea
	self._listings = scroll

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, Theme.Spacing.S)
	listLayout.Parent = scroll

	local currentCategory = PlayerMarketConfig.Categories[1]
	local tabDefs = {}
	for _, category in PlayerMarketConfig.Categories do
		table.insert(tabDefs, { Id = category, Label = category })
	end

	-- Phase 4A.1: 8 categories reliably overflowed a fixed-width row (the
	-- exact "Marketplace tabs overflow the viewport" complaint) — wrapped in
	-- a horizontally-scrollable strip instead of a "More" dropdown, per the
	-- approved plan's simplest-correct-fix choice. TabStrip itself is
	-- reused completely unchanged; only its container's Size is widened to
	-- AutomaticSize.X so the ScrollingFrame has real content to scroll.
	local tabScroll = Instance.new("ScrollingFrame")
	tabScroll.Name = "CategoryTabsScroll"
	tabScroll.Position = UDim2.new(0, 0, 0, 82)
	tabScroll.Size = UDim2.new(1, 0, 0, 36)
	tabScroll.BackgroundTransparency = 1
	tabScroll.BorderSizePixel = 0
	tabScroll.ScrollingDirection = Enum.ScrollingDirection.X
	tabScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	tabScroll.AutomaticCanvasSize = Enum.AutomaticSize.X
	tabScroll.ClipsDescendants = true
	tabScroll.ScrollBarThickness = 4
	tabScroll.Parent = panel

	local tabStrip, _selectTab, tabButtons = TabStrip.new({
		Name = "CategoryTabs",
		Size = UDim2.new(0, 0, 1, 0),
		Tabs = tabDefs,
		InitialTabId = currentCategory,
		OnTabSelected = function(tabId: string)
			currentCategory = tabId
			self:_refreshListings(currentCategory)
		end,
		Parent = tabScroll,
	})
	tabStrip.AutomaticSize = Enum.AutomaticSize.X

	GamepadNav.LinkChain({ closeButton, table.unpack(tabButtons) })
	self._currentCategory = currentCategory
end

function PlayerMarketController:_refreshListings(category: string)
	for _, child in self._listings:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end

	local ok, listings = pcall(function()
		return Net.GetFunction("RequestMarketListings"):InvokeServer({ Category = category })
	end)
	if not ok or not listings or #listings == 0 then
		EmptyState.new({
			Card = true,
			Icon = "📭",
			Text = "No listings yet",
			Subtext = "Be the first to list an item once trading goes live.",
			Parent = self._listings,
		})
		return
	end

	local order = 1
	local buyButtons: { TextButton } = {}
	for _, listing in listings do
		table.insert(buyButtons, renderListingCard(self._listings, listing, order))
		order += 1
	end
	GamepadNav.LinkChain(buyButtons)
end

function PlayerMarketController:Init()
	self._trove = Trove.new()
	self:_buildPanel()
end

function PlayerMarketController.Open()
	if isOpen then
		return
	end
	isOpen = true

	local self = PlayerMarketController
	self:_refreshListings(self._currentCategory)
	self._backdrop.Visible = true
	Motion.Tween(self._backdrop, "Fade", Theme.Motion.PanelOpen, { GroupTransparency = 0 })
	Motion.Tween(self._panelScale, "Scale", Theme.Motion.PanelOpen, { Scale = 1 })

	previousSelection = GuiService.SelectedObject
	GamepadNav.FocusFirst(self._panel)
end

function PlayerMarketController.Close()
	if not isOpen then
		return
	end
	isOpen = false

	local self = PlayerMarketController
	local tween = Motion.Tween(self._backdrop, "Fade", Theme.Motion.PanelClose, { GroupTransparency = 1 })
	Motion.Tween(self._panelScale, "Scale", Theme.Motion.PanelClose, { Scale = 0.94 })
	tween.Completed:Once(function()
		if not isOpen then
			self._backdrop.Visible = false
		end
	end)
	GamepadNav.Restore(previousSelection)
end

function PlayerMarketController:Start()
	self._trove:Add(HUDController.MarketplaceOpenRequested:Connect(function()
		PlayerMarketController.Open()
	end))
end

return PlayerMarketController
