--!strict
-- Durable pending-delivery mailbox (Phase 4A) — the "pending delivery or
-- mailbox logic" the Player Marketplace plan calls for. A seller who's
-- offline when their item sells, or a buyer whose item can't be delivered
-- immediately, gets a durably-recorded entry here instead of a grant that
-- depends on a live session existing. Drained into CurrencyService/
-- InventoryService the next time that player's session is created.
--
-- Correctness note: this module is fully built and exercised via
-- PlayerMarketService's Studio-only test-transaction path (see
-- PlayerMarketConfig.LiveTransactionsEnabled) — it is not yet reachable from
-- real public marketplace transactions.

local PersistenceStore = require(script.Parent.PersistenceStore)

local mailboxStore = PersistenceStore.GetStore("EclipseMarketMailbox_v1")

export type MailboxEntry = {
	Id: string, -- dedupe key, typically TransactionId .. ":" .. "item"/"currency"
	Type: "Item" | "Currency",
	ItemId: string?,
	Amount: number,
}

local MarketMailbox = {}

-- Appends `entry` to userId's durable mailbox unless an entry with the same
-- Id is already present (idempotent — a retried/resumed transaction step
-- can call this again safely).
function MarketMailbox.Add(userId: number, entry: MailboxEntry): boolean
	local key = tostring(userId)
	local ok = select(1, PersistenceStore.SafeUpdate(mailboxStore, key, function(old)
		local entries = (old :: { MailboxEntry }?) or {}
		for _, existing in entries do
			if existing.Id == entry.Id then
				return nil -- already recorded, no change needed
			end
		end
		table.insert(entries, entry)
		return entries
	end))
	return ok
end

-- Grants every pending entry for `player` into the live in-memory session
-- (CurrencyService/InventoryService), then clears the durable mailbox.
-- CurrencyService/InventoryService are required lazily (not at module top)
-- to avoid a require cycle, since both of those modules sit under
-- src/server/Services rather than src/server/Modules.
function MarketMailbox.Drain(player: Player)
	local key = tostring(player.UserId)
	local ok, entries = PersistenceStore.SafeGet(mailboxStore, key)
	if not ok or not entries or #(entries :: { MailboxEntry }) == 0 then
		return
	end

	local CurrencyService = require(script.Parent.Parent.Services.CurrencyService)
	local InventoryService = require(script.Parent.Parent.Services.InventoryService)

	for _, entry in entries :: { MailboxEntry } do
		if entry.Type == "Currency" then
			CurrencyService.Add(player, entry.Amount)
		elseif entry.Type == "Item" and entry.ItemId then
			InventoryService.AddItem(player, entry.ItemId, entry.Amount)
		end
	end

	PersistenceStore.SafeSet(mailboxStore, key, {})
end

-- Not a Loader-discovered Service (this lives under src/server/Modules, not
-- Services) — PlayerMarketService owns the actual Players.PlayerAdded hook
-- in its own :Init() and calls MarketMailbox.Drain from there, so this stays
-- a plain, dependency-free module.
return MarketMailbox
