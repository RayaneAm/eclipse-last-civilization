--!strict
-- Player-to-player marketplace configuration (Phase 4A). See PlayerMarketService
-- for the full cross-server-safe architecture and why LiveTransactionsEnabled
-- is false: the durable listing/escrow state machine is sound on its own, but
-- it sits on top of the still-in-memory InventoryService/CurrencyService,
-- which makes real public transactions an economy-integrity risk until
-- player inventory and Scrap are themselves persistent. See the Phase 4A
-- plan's Player Marketplace section for the full reasoning and the explicit
-- future-dependency list.

export type MarketCategory = "RawMaterials" | "ProcessedMaterials" | "Components" | "Equipment" | "Blueprints" | "DefenseSupplies" | "ProductionSupplies" | "Collectibles"

local PlayerMarketConfig = {}

-- Hard production gate. Never set true outside the explicit future-dependency
-- rollout described in the plan.
PlayerMarketConfig.LiveTransactionsEnabled = false

PlayerMarketConfig.Categories = {
	"RawMaterials",
	"ProcessedMaterials",
	"Components",
	"Equipment",
	"Blueprints",
	"DefenseSupplies",
	"ProductionSupplies",
	"Collectibles",
} :: { MarketCategory }

PlayerMarketConfig.ListingFeePercent = 2 -- charged up front, non-refundable
PlayerMarketConfig.SaleFeePercent = 5 -- deducted from proceeds on a successful sale
PlayerMarketConfig.MinPrice = 1
PlayerMarketConfig.MaxPrice = 1000000
PlayerMarketConfig.ListingDurationSeconds = 3 * 24 * 60 * 60 -- 3 days
PlayerMarketConfig.MaxActiveListingsPerPlayer = 10
PlayerMarketConfig.MaxListingRequestsPerMinute = 10
PlayerMarketConfig.MaxPurchaseRequestsPerMinute = 20
-- How long a listing may sit in PurchasePending (a claimed-but-not-yet-
-- completed transaction) before another server is allowed to attempt to
-- resume it from the transaction record.
PlayerMarketConfig.PurchasePendingTimeoutSeconds = 120

return PlayerMarketConfig
