--!strict
-- Phase 3B: the dev-product purchase hook. Scope-limited per explicit
-- review: CurrencyService/InventoryService mutate the purely in-memory
-- PlayerSessionData (PlayerSessionService drops it all on leave — a
-- documented, project-wide "known gap," not something new here). A
-- DataStore-persisted purchase record and an in-memory-only grant
-- destination are two different systems — no UpdateAsync sequence between
-- them can be made fully crash-proof without a real persistent player-data
-- transaction layer, which does not exist in this project and is out of
-- scope this phase. So: every offer keeps ProductOrPassId = 0 this phase
-- (confirmed — no real ids exist anywhere yet), and ShopController's
-- "Coming Soon" / disabled-Buy rule means PromptProductPurchase is never
-- actually invoked by this build — live granting is never exercised in
-- practice. ProcessReceipt is still registered (Roblox requires a real
-- handler so a stray/unexpected receipt is never left stuck) with the part
-- that IS honestly achievable made genuinely correct: a purchase is
-- recorded as seen (via one atomic UpdateAsync) before granting, so a
-- *redelivered* receipt for the same PurchaseId is recognized and not
-- re-granted. The reward application itself is at the same durability
-- level as every other currency/inventory mutation already in this
-- codebase (crafting, harvesting, etc.) — not a stronger standard
-- fabricated just for this feature.

local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonetizationConfig = require(ReplicatedStorage.Shared.Config.MonetizationConfig)

local CurrencyService = require(script.Parent.CurrencyService)
local InventoryService = require(script.Parent.InventoryService)

local processedStore = DataStoreService:GetDataStore("EclipseProcessedPurchases_v1")

local MonetizationService = {}

-- Only offers with a real (non-zero) ProductOrPassId are addressable by a
-- receipt — id 0 is the "not configured yet" sentinel, and since more than
-- one offer can share it, 0 is deliberately never looked up here.
local function buildProductLookup(): { [number]: MonetizationConfig.Offer }
	local lookup = {}
	for _, offer in { MonetizationConfig.StarterPack, MonetizationConfig.SeasonPass } do
		if offer.Kind == "Product" and offer.ProductOrPassId ~= 0 then
			lookup[offer.ProductOrPassId] = offer
		end
	end
	return lookup
end
local productLookup = buildProductLookup()

local function grantContents(player: Player, contents: { MonetizationConfig.ContentLine })
	for _, line in contents do
		if line.Kind == "Currency" then
			CurrencyService.Add(player, line.Amount)
		elseif line.Kind == "Item" then
			InventoryService.AddItem(player, line.ItemId, line.Amount)
		end
	end
end

-- Returns true if this PurchaseId was already recorded before this call
-- (i.e. a redelivered receipt), false if this call just recorded it for the
-- first time. One atomic UpdateAsync — safe under concurrent/duplicate
-- receipt delivery.
local function recordPurchaseSeen(player: Player, purchaseId: string): boolean
	local key = tostring(player.UserId)
	local wasAlreadyProcessed = false
	processedStore:UpdateAsync(key, function(old)
		old = old or {}
		if old[purchaseId] then
			wasAlreadyProcessed = true
		else
			old[purchaseId] = true
		end
		return old
	end)
	return wasAlreadyProcessed
end

function MonetizationService:Init()
	MarketplaceService.ProcessReceipt = function(receiptInfo)
		local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
		if not player then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		local offer = productLookup[receiptInfo.ProductId]
		if not offer then
			warn(`MonetizationService: unrecognized ProductId {receiptInfo.ProductId} (purchase {receiptInfo.PurchaseId})`)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		local recordOk, wasAlreadyProcessed = pcall(recordPurchaseSeen, player, receiptInfo.PurchaseId)
		if not recordOk then
			warn(`MonetizationService: failed to record purchase {receiptInfo.PurchaseId}:`, wasAlreadyProcessed)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		if not wasAlreadyProcessed then
			local grantOk, grantErr = pcall(grantContents, player, offer.Contents)
			if not grantOk then
				-- Documented boundary (see file header): the purchase is
				-- already recorded, so it won't be granted a second time on
				-- redelivery even though this specific attempt's grant
				-- failed — the same durability limit every other in-memory
				-- mutation in this project already has.
				warn(`MonetizationService: grant failed for {player.Name} / {offer.Id}:`, grantErr)
			end
		end

		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
end

return MonetizationService
