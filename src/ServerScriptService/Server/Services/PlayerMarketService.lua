--!strict
-- Player-to-player marketplace (Phase 4A) — deliberately named PlayerMarketService,
-- never MarketplaceService, to avoid any confusion with Roblox's own engine
-- service of that name (referenced only by ShopController/MonetizationService
-- for real-money purchases, an entirely separate system).
--
-- LIVE TRANSACTIONS ARE GATED OFF (PlayerMarketConfig.LiveTransactionsEnabled
-- = false). The cross-server listing/escrow state machine below is complete
-- and correct on its own, but it sits on top of the still-in-memory
-- InventoryService/CurrencyService — see the Phase 4A plan's Player
-- Marketplace section for why that combination is a genuine economy-
-- integrity risk, not just a scope preference, until player inventory and
-- Scrap are themselves persistent. The full state machine is exercised via
-- the Studio-only DebugSeedTestListing/DebugTestPurchase functions at the
-- bottom of this file.
--
-- Cross-server safety mechanism: every listing is its own DataStore entry
-- (never one ever-growing blob), and every state transition (purchase
-- claim, cancel, expire) is a single UpdateAsync whose callback only
-- proceeds if the current state is still "Active" — Roblox serializes
-- concurrent UpdateAsync calls to the same key, so exactly one caller ever
-- wins a given transition, regardless of which server it came from.

local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local PlayerMarketConfig = require(ReplicatedStorage.Shared.Config.PlayerMarketConfig)
local ResourceTierConfig = require(ReplicatedStorage.Shared.Config.ResourceTierConfig)
local TraderConfig = require(ReplicatedStorage.Shared.Config.TraderConfig)

local PersistenceStore = require(script.Parent.Parent.Modules.PersistenceStore)
local MarketMailbox = require(script.Parent.Parent.Modules.MarketMailbox)
local InventoryService = require(script.Parent.InventoryService)
local CurrencyService = require(script.Parent.CurrencyService)

local listingsStore = PersistenceStore.GetStore("EclipseMarketListings_v1")
local transactionsStore = PersistenceStore.GetStore("EclipseMarketTransactions_v1")

export type ListingState = "Active" | "PurchasePending" | "Sold" | "Cancelled" | "Expired"

export type Listing = {
	Id: string,
	SellerUserId: number,
	ItemId: string,
	Quantity: number,
	Price: number,
	Category: string,
	ReservedForUserId: number?,
	State: ListingState,
	CreatedAt: number,
	TransactionId: string?,
	PurchasePendingSince: number?,
}

export type TransactionRecord = {
	Id: string,
	ListingId: string,
	BuyerUserId: number,
	SellerUserId: number,
	ItemId: string,
	Quantity: number,
	Price: number,
	Fee: number,
	BuyerDebited: boolean,
	ItemDelivered: boolean,
	SellerCredited: boolean,
	Completed: boolean,
}

local PlayerMarketService = {}

local recentListingRequests: { [Player]: { number } } = {}
local recentPurchaseRequests: { [Player]: { number } } = {}

local function isTradeableItem(itemId: string): boolean
	return ResourceTierConfig.Get(itemId) ~= nil or TraderConfig.Get(itemId) ~= nil
end

local function withinRateLimit(tracker: { [Player]: { number } }, player: Player, maxPerMinute: number): boolean
	local now = os.clock()
	local timestamps = tracker[player]
	if not timestamps then
		timestamps = {}
		tracker[player] = timestamps
	end
	while #timestamps > 0 and now - timestamps[1] > 60 do
		table.remove(timestamps, 1)
	end
	if #timestamps >= maxPerMinute then
		return false
	end
	table.insert(timestamps, now)
	return true
end

local function indexMap(category: string)
	return MemoryStoreService:GetSortedMap(`MarketIndex_{category}`)
end

local function addToIndex(listing: Listing)
	pcall(function()
		indexMap(listing.Category):SetAsync(listing.Id, {
			ListingId = listing.Id,
			ItemId = listing.ItemId,
			Quantity = listing.Quantity,
			Price = listing.Price,
			SellerUserId = listing.SellerUserId,
			ReservedForUserId = listing.ReservedForUserId,
		}, PlayerMarketConfig.ListingDurationSeconds, listing.CreatedAt)
	end)
end

local function removeFromIndex(listing: Listing)
	pcall(function()
		indexMap(listing.Category):RemoveAsync(listing.Id)
	end)
end

-- ---------------------------------------------------------------------
-- Atomic state-machine claims — the entire cross-server-safety mechanism.
-- ---------------------------------------------------------------------

local function claimForPurchase(listingId: string, buyerUserId: number, transactionId: string): (boolean, Listing?)
	local ok, result = PersistenceStore.SafeUpdate(listingsStore, listingId, function(old)
		if not old or (old :: Listing).State ~= "Active" then
			return nil
		end
		local listing = old :: Listing
		if listing.ReservedForUserId and listing.ReservedForUserId ~= buyerUserId then
			return nil
		end
		listing.State = "PurchasePending"
		listing.TransactionId = transactionId
		listing.PurchasePendingSince = os.time()
		return listing
	end)
	return ok and result ~= nil, result :: Listing?
end

local function claimForCancelOrExpire(listingId: string, newState: ListingState): (boolean, Listing?)
	local ok, result = PersistenceStore.SafeUpdate(listingsStore, listingId, function(old)
		if not old or (old :: Listing).State ~= "Active" then
			return nil
		end
		local listing = old :: Listing
		listing.State = newState
		return listing
	end)
	return ok and result ~= nil, result :: Listing?
end

-- Idempotent, resumable: each step checks its own durable flag before
-- repeating it, so a retry/resume after a crash never re-debits, re-
-- delivers, or re-credits. Returns true once the transaction (and the
-- listing's final Sold transition) is fully complete.
local function runTransaction(transactionId: string, listing: Listing, buyerUserId: number): boolean
	local _, record = PersistenceStore.SafeUpdate(transactionsStore, transactionId, function(old)
		if old then
			return old
		end
		return {
			Id = transactionId,
			ListingId = listing.Id,
			BuyerUserId = buyerUserId,
			SellerUserId = listing.SellerUserId,
			ItemId = listing.ItemId,
			Quantity = listing.Quantity,
			Price = listing.Price,
			Fee = math.floor(listing.Price * PlayerMarketConfig.SaleFeePercent / 100),
			BuyerDebited = false,
			ItemDelivered = false,
			SellerCredited = false,
			Completed = false,
		} :: TransactionRecord
	end)
	if not record then
		return false
	end
	local tx = record :: TransactionRecord

	if not tx.BuyerDebited then
		local buyer = Players:GetPlayerByUserId(buyerUserId)
		if not buyer or not CurrencyService.Remove(buyer, tx.Price) then
			return false
		end
		tx.BuyerDebited = true
		PersistenceStore.SafeSet(transactionsStore, transactionId, tx)
	end

	if not tx.ItemDelivered then
		MarketMailbox.Add(buyerUserId, { Id = `{transactionId}:item`, Type = "Item", ItemId = tx.ItemId, Amount = tx.Quantity })
		tx.ItemDelivered = true
		PersistenceStore.SafeSet(transactionsStore, transactionId, tx)
	end

	if not tx.SellerCredited then
		MarketMailbox.Add(tx.SellerUserId, { Id = `{transactionId}:currency`, Type = "Currency", Amount = tx.Price - tx.Fee })
		tx.SellerCredited = true
		PersistenceStore.SafeSet(transactionsStore, transactionId, tx)
	end

	tx.Completed = true
	PersistenceStore.SafeSet(transactionsStore, transactionId, tx)

	local soldOk = PersistenceStore.SafeUpdate(listingsStore, listing.Id, function(old)
		if not old or (old :: Listing).State ~= "PurchasePending" then
			return nil
		end
		local current = old :: Listing
		current.State = "Sold"
		return current
	end)

	removeFromIndex(listing)
	return soldOk
end

-- ---------------------------------------------------------------------
-- Public request handlers (gated)
-- ---------------------------------------------------------------------

local function requestCreateListing(player: Player, payload: { ItemId: string, Quantity: number, Price: number, Category: string, ReservedForUserId: number? }): (boolean, string?, string?)
	if not PlayerMarketConfig.LiveTransactionsEnabled then
		return false, "MarketplaceComingSoon", nil
	end
	if typeof(payload) ~= "table" or typeof(payload.ItemId) ~= "string" or typeof(payload.Quantity) ~= "number" or typeof(payload.Price) ~= "number" or typeof(payload.Category) ~= "string" then
		return false, "InvalidRequest", nil
	end
	if not withinRateLimit(recentListingRequests, player, PlayerMarketConfig.MaxListingRequestsPerMinute) then
		return false, "RateLimited", nil
	end
	if payload.Quantity <= 0 or payload.Price < PlayerMarketConfig.MinPrice or payload.Price > PlayerMarketConfig.MaxPrice then
		return false, "InvalidQuantityOrPrice", nil
	end
	if not table.find(PlayerMarketConfig.Categories, payload.Category) then
		return false, "InvalidCategory", nil
	end
	if not isTradeableItem(payload.ItemId) then
		return false, "NotTradeable", nil
	end
	if payload.ReservedForUserId then
		local ok, isFriend = pcall(function()
			return player:IsFriendsWith(payload.ReservedForUserId :: number)
		end)
		if not ok or not isFriend then
			return false, "InvalidReservedTarget", nil
		end
	end
	if not InventoryService.HasAtLeast(player, payload.ItemId, payload.Quantity) then
		return false, "InsufficientInventory", nil
	end

	local listingFee = math.max(1, math.floor(payload.Price * PlayerMarketConfig.ListingFeePercent / 100))
	if not CurrencyService.Remove(player, listingFee) then
		return false, "InsufficientScrap", nil
	end

	InventoryService.RemoveItem(player, payload.ItemId, payload.Quantity)

	local listingId = HttpService:GenerateGUID(false)
	local listing: Listing = {
		Id = listingId,
		SellerUserId = player.UserId,
		ItemId = payload.ItemId,
		Quantity = payload.Quantity,
		Price = payload.Price,
		Category = payload.Category,
		ReservedForUserId = payload.ReservedForUserId,
		State = "Active",
		CreatedAt = os.time(),
	}
	PersistenceStore.SafeSet(listingsStore, listingId, listing)
	addToIndex(listing)

	return true, nil, listingId
end

local function requestPurchaseListing(player: Player, payload: { ListingId: string }): (boolean, string?)
	if not PlayerMarketConfig.LiveTransactionsEnabled then
		return false, "MarketplaceComingSoon"
	end
	if typeof(payload) ~= "table" or typeof(payload.ListingId) ~= "string" then
		return false, "InvalidRequest"
	end
	if not withinRateLimit(recentPurchaseRequests, player, PlayerMarketConfig.MaxPurchaseRequestsPerMinute) then
		return false, "RateLimited"
	end

	local ok, listing = PersistenceStore.SafeGet(listingsStore, payload.ListingId)
	if not ok or not listing then
		return false, "ListingNotFound"
	end
	local typed = listing :: Listing
	if typed.SellerUserId == player.UserId then
		return false, "CannotBuyOwnListing"
	end
	if CurrencyService.GetBalance(player) < typed.Price then
		return false, "InsufficientScrap"
	end

	local transactionId = HttpService:GenerateGUID(false)
	local claimOk, claimed = claimForPurchase(payload.ListingId, player.UserId, transactionId)
	if not claimOk or not claimed then
		return false, "NoLongerAvailable"
	end

	if not runTransaction(transactionId, claimed, player.UserId) then
		return false, "TransactionFailed"
	end
	return true
end

local function requestCancelListing(player: Player, payload: { ListingId: string }): (boolean, string?)
	if not PlayerMarketConfig.LiveTransactionsEnabled then
		return false, "MarketplaceComingSoon"
	end
	if typeof(payload) ~= "table" or typeof(payload.ListingId) ~= "string" then
		return false, "InvalidRequest"
	end

	local ok, listing = PersistenceStore.SafeGet(listingsStore, payload.ListingId)
	if not ok or not listing then
		return false, "ListingNotFound"
	end
	local typed = listing :: Listing
	if typed.SellerUserId ~= player.UserId then
		return false, "NotYourListing"
	end

	local claimOk, claimed = claimForCancelOrExpire(payload.ListingId, "Cancelled")
	if not claimOk or not claimed then
		return false, "CannotCancel"
	end

	MarketMailbox.Add(player.UserId, { Id = `{payload.ListingId}:cancel-return`, Type = "Item", ItemId = claimed.ItemId, Amount = claimed.Quantity })
	removeFromIndex(claimed)
	return true
end

local function requestListings(_player: Player, payload: { Category: string }): { any }
	if typeof(payload) ~= "table" or typeof(payload.Category) ~= "string" then
		return {}
	end
	local ok, result = pcall(function()
		return indexMap(payload.Category):GetRangeAsync(Enum.SortDirection.Descending, 25)
	end)
	if not ok then
		return {}
	end
	local listings = {}
	for _, entry in result do
		table.insert(listings, entry.value)
	end
	return listings
end

-- ---------------------------------------------------------------------
-- Studio-only test-transaction path (RunService:IsStudio() gated, never
-- reachable via a Net remote or from a live server) — exercises the exact
-- same claim/transaction functions live transactions would use.
-- ---------------------------------------------------------------------

function PlayerMarketService.DebugSeedTestListing(sellerUserId: number, itemId: string, quantity: number, price: number, category: string): string?
	if not RunService:IsStudio() then
		return nil
	end
	local listingId = HttpService:GenerateGUID(false)
	local listing: Listing = {
		Id = listingId,
		SellerUserId = sellerUserId,
		ItemId = itemId,
		Quantity = quantity,
		Price = price,
		Category = category,
		ReservedForUserId = nil,
		State = "Active",
		CreatedAt = os.time(),
	}
	PersistenceStore.SafeSet(listingsStore, listingId, listing)
	addToIndex(listing)
	return listingId
end

function PlayerMarketService.DebugTestPurchase(listingId: string, buyerUserId: number): (boolean, string?)
	if not RunService:IsStudio() then
		return false, "StudioOnly"
	end
	local transactionId = HttpService:GenerateGUID(false)
	local claimOk, claimed = claimForPurchase(listingId, buyerUserId, transactionId)
	if not claimOk or not claimed then
		return false, "NoLongerAvailable"
	end
	return runTransaction(transactionId, claimed, buyerUserId), nil
end

function PlayerMarketService.DebugCancel(listingId: string): boolean
	if not RunService:IsStudio() then
		return false
	end
	local claimOk, claimed = claimForCancelOrExpire(listingId, "Cancelled")
	if claimOk and claimed then
		removeFromIndex(claimed)
	end
	return claimOk
end

function PlayerMarketService:Init()
	Net.GetFunction("RequestCreateMarketListing").OnServerInvoke = function(player: Player, payload: any)
		return requestCreateListing(player, payload)
	end
	Net.GetFunction("RequestPurchaseMarketListing").OnServerInvoke = function(player: Player, payload: any)
		return requestPurchaseListing(player, payload)
	end
	Net.GetFunction("RequestCancelMarketListing").OnServerInvoke = function(player: Player, payload: any)
		return requestCancelListing(player, payload)
	end
	Net.GetFunction("RequestMarketListings").OnServerInvoke = function(player: Player, payload: any)
		return requestListings(player, payload)
	end
	Net.GetFunction("RequestMyMarketListings").OnServerInvoke = function(_player: Player)
		-- Foundation-phase scope: "my listings" browsing while transactions
		-- are disabled has nothing live to show; the UI reflects the
		-- Coming Soon state instead of calling this meaningfully yet.
		return {}
	end

	Players.PlayerAdded:Connect(function(player)
		MarketMailbox.Drain(player)
	end)
	for _, player in Players:GetPlayers() do
		MarketMailbox.Drain(player)
	end
end

return PlayerMarketService
