--!strict
-- TRADER TERMINAL — opened at the base trader (BaseTraderTerminal tag).
--
-- The compact, base-side face of the NPC merchant: what you can offload from
-- this run, and the handful of staples you can buy back. The Haven's
-- Survivor Market is the fuller version of the same economy; both call
-- through TraderActions and render TradeRow, so prices, confirmations and
-- rejection copy can never disagree between them.
--
-- Worth stating because it is not obvious from the world: the trader works
-- on your CARRIED backpack and Scrap, not on Base Storage. The rows show
-- what you are actually holding so that is visible without guessing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage.Shared.Modules.Trove)
local TraderConfig = require(ReplicatedStorage.Shared.Config.TraderConfig)

local FacilityStyle = require(script.Parent.Parent.UI.FacilityStyle)
local FacilityRouter = require(script.Parent.Parent.UI.FacilityRouter)
local FacilityPrompts = require(script.Parent.Parent.UI.FacilityPrompts)
local TraderActions = require(script.Parent.Parent.UI.TraderActions)
local FacilityModal = require(script.Parent.Parent.UI.Components.FacilityModal)
local SectionHeader = require(script.Parent.Parent.UI.Components.SectionHeader)
local TradeRow = require(script.Parent.Parent.UI.Components.TradeRow)
local EmptyState = require(script.Parent.Parent.UI.Components.EmptyState)
local Button = require(script.Parent.Parent.UI.Components.Button)

local BaseSessionController = require(script.Parent.BaseSessionController)

local TraderTerminalController = {}

local IDENTITY = FacilityStyle.Facilities.Trader
local ACCENT = IDENTITY.Accent

local TABS = {
	{ Id = "Sell", Label = "SELL" },
	{ Id = "Buy", Label = "BUY" },
}

local modal: FacilityModal.FacilityModal? = nil
local currentTab = "Sell"

-- Sorted item lists, computed from TraderConfig rather than hand-ordered so
-- a new tradeable item appears automatically.
local function sellableItems(inventory: { [string]: number }): { string }
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
	return items
end

local function buyableItems(): { string }
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
	return items
end

local function renderSell(content: GuiObject, nextOrder: () -> number)
	local inventory = BaseSessionController.GetInventory()

	local junkCount = 0
	for itemId, entry in TraderConfig.All do
		if entry.IsJunk then
			junkCount += inventory[itemId] or 0
		end
	end

	-- The one-tap action worth putting first after a run.
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

	local items = sellableItems(inventory)
	if #items == 0 then
		EmptyState.new({
			Glyph = "Storage",
			Text = "Nothing to sell",
			Subtext = "Bring materials back from an expedition and the trader will buy them.",
			Card = true,
			LayoutOrder = nextOrder(),
			Parent = content,
		})
		return
	end

	SectionHeader.new({
		Text = "Sell from backpack",
		Accent = ACCENT,
		Info = "The trader buys what you are carrying, not what is in Base Storage.",
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

local function renderBuy(content: GuiObject, nextOrder: () -> number)
	local inventory = BaseSessionController.GetInventory()
	local scrap = BaseSessionController.GetScrap()

	SectionHeader.new({
		Text = "Buy with Scrap",
		Accent = ACCENT,
		Value = `◆{scrap}`,
		ValueColor = ACCENT,
		LayoutOrder = nextOrder(),
		Parent = content,
	})

	local items = buyableItems()
	if #items == 0 then
		EmptyState.new({
			Glyph = "Trader",
			Text = "Nothing for sale",
			Subtext = "The trader has no stock right now.",
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
			-- Disabled when a single unit is already unaffordable, so the
			-- button never fires a request the server will refuse.
			Disabled = scrap < entry.BuyPrice,
			LayoutOrder = nextOrder(),
			OnAct = function(quantity)
				TraderActions.Buy(itemId, quantity)
			end,
			Parent = content,
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

	if currentTab == "Buy" then
		renderBuy(activeModal.Content, nextOrder)
	else
		renderSell(activeModal.Content, nextOrder)
	end

	activeModal:RevealContent()
end

function TraderTerminalController.Open(initialTab: string?)
	local activeModal = modal
	if not activeModal then
		return
	end
	BaseSessionController.Refresh()
	currentTab = initialTab or "Sell"
	activeModal:Open(currentTab)
	render()
end

function TraderTerminalController:Init()
	self._trove = Trove.new()

	modal = FacilityModal.new({
		Id = "TraderTerminal",
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

	FacilityRouter.Register("Trader", function(tabId: string?)
		TraderTerminalController.Open(tabId)
	end)
end

function TraderTerminalController:Start()
	self._trove:Add(FacilityPrompts.Bind({
		Tag = "BaseTraderTerminal",
		OnTriggered = function()
			TraderTerminalController.Open("Sell")
		end,
	}))

	self._trove:Add(BaseSessionController.Changed:Connect(function()
		local activeModal = modal
		if activeModal and activeModal:IsOpen() then
			render()
		end
	end))
end

return TraderTerminalController
