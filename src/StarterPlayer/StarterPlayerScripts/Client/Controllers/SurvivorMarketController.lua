--!strict
-- SURVIVOR MARKET — the Haven's merchant, opened from its facility anchor.
--
-- Before this pass the Survivor Market had no screen at all: its prompt read
-- "View" and pressing it did nothing but show the floating info panel.
--
-- BUY and SELL are fully real. They go through TraderActions to the same
-- TraderService the base terminal uses, which trades your carried inventory
-- at server-computed TraderConfig prices from anywhere — so a Haven-side
-- merchant is not a second economy, it is the same one with survivor
-- framing.
--
-- MY LISTINGS is the player-to-player marketplace, which is deliberately
-- GATED: PlayerMarketConfig.LiveTransactionsEnabled is false because the
-- durable listing/escrow machinery sits on top of an in-memory inventory and
-- Scrap balance, and real trades on that footing are an economy-integrity
-- risk (see PlayerMarketService's header). So that tab states the situation
-- plainly and offers no fake listing flow — it links to the existing
-- Marketplace panel, which enforces the same gate.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage.Shared.Modules.Trove)
local TraderConfig = require(ReplicatedStorage.Shared.Config.TraderConfig)
local PlayerMarketConfig = require(ReplicatedStorage.Shared.Config.PlayerMarketConfig)

local Theme = require(script.Parent.Parent.UI.Theme)
local FacilityStyle = require(script.Parent.Parent.UI.FacilityStyle)
local FacilityRouter = require(script.Parent.Parent.UI.FacilityRouter)
local TraderActions = require(script.Parent.Parent.UI.TraderActions)
local FacilityModal = require(script.Parent.Parent.UI.Components.FacilityModal)
local FacilityCard = require(script.Parent.Parent.UI.Components.FacilityCard)
local SectionHeader = require(script.Parent.Parent.UI.Components.SectionHeader)
local TradeRow = require(script.Parent.Parent.UI.Components.TradeRow)
local StatusChip = require(script.Parent.Parent.UI.Components.StatusChip)
local EmptyState = require(script.Parent.Parent.UI.Components.EmptyState)
local Button = require(script.Parent.Parent.UI.Components.Button)

local BaseSessionController = require(script.Parent.BaseSessionController)

local SurvivorMarketController = {}

local IDENTITY = FacilityStyle.Facilities.SurvivorMarket
local ACCENT = IDENTITY.Accent

local TABS = {
	{ Id = "Buy", Label = "BUY" },
	{ Id = "Listings", Label = "MY LISTINGS" },
	{ Id = "Sell", Label = "SELL" },
}

local modal: FacilityModal.FacilityModal? = nil
local currentTab = "Buy"

local function renderBuy(content: GuiObject, nextOrder: () -> number)
	local inventory = BaseSessionController.GetInventory()
	local scrap = BaseSessionController.GetScrap()

	SectionHeader.new({
		Text = "Merchant stock",
		Accent = ACCENT,
		Value = `◆{scrap}`,
		ValueColor = ACCENT,
		Info = "Prices are fixed by the merchant and paid from your carried Scrap.",
		LayoutOrder = nextOrder(),
		Parent = content,
	})

	local items: { string } = {}
	for itemId, entry in TraderConfig.All do
		if entry.BuyPrice > 0 then
			table.insert(items, itemId)
		end
	end
	table.sort(items, function(a, b)
		local entryA, entryB = TraderConfig.Get(a), TraderConfig.Get(b)
		return (if entryA then entryA.BuyPrice else 0) < (if entryB then entryB.BuyPrice else 0)
	end)

	if #items == 0 then
		EmptyState.new({
			Glyph = "Market",
			Text = "No stock today",
			Subtext = "Check back soon.",
			Card = true,
			LayoutOrder = nextOrder(),
			Parent = content,
		})
		return
	end

	for _, itemId in items do
		local entry = TraderConfig.Get(itemId) :: TraderConfig.TraderEntry
		TradeRow.new({
			ItemId = itemId,
			UnitPrice = entry.BuyPrice,
			Held = inventory[itemId] or 0,
			ActionText = "Buy",
			Accent = ACCENT,
			Disabled = scrap < entry.BuyPrice,
			LayoutOrder = nextOrder(),
			OnAct = function(quantity)
				TraderActions.Buy(itemId, quantity)
			end,
			Parent = content,
		})
	end
end

local function renderSell(content: GuiObject, nextOrder: () -> number)
	local inventory = BaseSessionController.GetInventory()

	local junkCount = 0
	for itemId, entry in TraderConfig.All do
		if entry.IsJunk then
			junkCount += inventory[itemId] or 0
		end
	end

	Button.new({
		Text = if junkCount > 0 then `Sell All Junk ({junkCount})` else "Sell All Junk",
		Variant = "Secondary",
		AccentColor = ACCENT,
		Size = UDim2.new(1, 0, 0, 40),
		LayoutOrder = nextOrder(),
		Disabled = junkCount == 0,
		OnActivated = TraderActions.SellJunk,
		Parent = content,
	})

	local items: { string } = {}
	for itemId, entry in TraderConfig.All do
		if entry.SellPrice > 0 and not entry.IsJunk and (inventory[itemId] or 0) > 0 then
			table.insert(items, itemId)
		end
	end
	table.sort(items, function(a, b)
		local entryA, entryB = TraderConfig.Get(a), TraderConfig.Get(b)
		return (if entryA then entryA.SellPrice else 0) > (if entryB then entryB.SellPrice else 0)
	end)

	if #items == 0 then
		EmptyState.new({
			Glyph = "Storage",
			Text = "Nothing to trade",
			Subtext = "The merchant buys salvage you bring back from expeditions.",
			Card = true,
			LayoutOrder = nextOrder(),
			Parent = content,
		})
		return
	end

	SectionHeader.new({
		Text = "Your salvage",
		Accent = ACCENT,
		LayoutOrder = nextOrder(),
		Parent = content,
	})

	for _, itemId in items do
		local entry = TraderConfig.Get(itemId) :: TraderConfig.TraderEntry
		local held = inventory[itemId] or 0
		TradeRow.new({
			ItemId = itemId,
			UnitPrice = entry.SellPrice,
			Held = held,
			ActionText = "Sell",
			Accent = ACCENT,
			LayoutOrder = nextOrder(),
			OnAct = function(quantity)
				TraderActions.Sell(itemId, math.min(quantity, held))
			end,
			Parent = content,
		})
	end
end

local function renderListings(content: GuiObject, nextOrder: () -> number)
	local _card, cardContent = FacilityCard.new({
		Name = "MarketGate",
		Accent = FacilityStyle.Accents.Trader,
		LayoutOrder = nextOrder(),
		Parent = content,
	})

	FacilityCard.Header({
		Icon = "Market",
		Title = "SURVIVOR-TO-SURVIVOR TRADING",
		Accent = FacilityStyle.Accents.Trader,
		LayoutOrder = 1,
		Parent = cardContent,
	})

	if PlayerMarketConfig.LiveTransactionsEnabled then
		-- Reachable only once the gate is genuinely opened; the full browse
		-- and listing flow lives in the existing Marketplace panel rather
		-- than being reimplemented here.
		StatusChip.new({ Status = "Available", Text = "OPEN", LayoutOrder = 2, Parent = cardContent })
		FacilityCard.Text({
			Text = "Browse listings from other survivors, or list your own surplus.",
			LayoutOrder = 3,
			Parent = cardContent,
		})
	else
		StatusChip.new({ Status = "Locked", Text = "NOT YET OPEN", LayoutOrder = 2, Parent = cardContent })
		FacilityCard.Text({
			Text = "Trading directly with other survivors is not live yet. The merchant above buys and sells at fixed prices in the meantime.",
			Color = Theme.Colors.TextMuted,
			LayoutOrder = 3,
			Parent = cardContent,
		})
	end

	if FacilityRouter.Has("Marketplace") and PlayerMarketConfig.LiveTransactionsEnabled then
		Button.new({
			Text = "OPEN MARKETPLACE",
			Variant = "Secondary",
			AccentColor = FacilityStyle.Accents.Trader,
			Size = UDim2.new(1, 0, 0, 40),
			LayoutOrder = 4,
			OnActivated = function()
				FacilityRouter.Open("Marketplace")
			end,
			Parent = cardContent,
		})
	elseif not PlayerMarketConfig.LiveTransactionsEnabled then
		Button.new({
			Text = "MARKETPLACE COMING SOON",
			Variant = "Secondary",
			AccentColor = FacilityStyle.Accents.Trader,
			Size = UDim2.new(1, 0, 0, 40),
			LayoutOrder = 4,
			Disabled = true,
			Parent = cardContent,
		})
	end
end

local function render()
	local activeModal = modal
	if not activeModal then
		return
	end
	activeModal:ClearContent()

	local layoutOrder = 0
	local function nextOrder(): number
		layoutOrder += 1
		return layoutOrder
	end

	if currentTab == "Sell" then
		renderSell(activeModal.Content, nextOrder)
	elseif currentTab == "Listings" then
		renderListings(activeModal.Content, nextOrder)
	else
		renderBuy(activeModal.Content, nextOrder)
	end

	activeModal:RevealContent()
end

function SurvivorMarketController.Open(initialTab: string?)
	local activeModal = modal
	if not activeModal then
		return
	end
	BaseSessionController.Refresh()
	currentTab = initialTab or "Buy"
	activeModal:Open(currentTab)
	render()
end

function SurvivorMarketController:Init()
	self._trove = Trove.new()

	modal = FacilityModal.new({
		Id = "SurvivorMarket",
		Icon = IDENTITY.Icon,
		Title = IDENTITY.Title,
		Subtitle = IDENTITY.Subtitle,
		Accent = ACCENT,
		WidthClass = "Regular",
		Tabs = TABS,
		OnTabSelected = function(tabId: string)
			currentTab = tabId
			render()
		end,
	})

	FacilityRouter.Register("SurvivorMarket", function(tabId: string?)
		SurvivorMarketController.Open(tabId)
	end)
end

function SurvivorMarketController:Start()
	self._trove:Add(BaseSessionController.Changed:Connect(function()
		local activeModal = modal
		if activeModal and activeModal:IsOpen() then
			render()
		end
	end))
end

return SurvivorMarketController
