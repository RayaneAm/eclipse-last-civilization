--!strict
-- Thin, shared DataStore wrapper (Phase 4A) — pcall-safe Get/Set/Update, used
-- by BaseService (per-player base save/load, the base-slot registry) and
-- PlayerMarketService (per-listing/per-transaction/mailbox records). Roblox's
-- UpdateAsync already provides the real atomicity/retry-on-conflict
-- semantics this whole phase leans on for cross-server safety — this module
-- doesn't reimplement that, it just gives every caller the same pcall/error-
-- logging idiom instead of each hand-rolling it (the pattern already proven
-- by DailyRewardsService/MonetizationService).

local DataStoreService = game:GetService("DataStoreService")

local PersistenceStore = {}

function PersistenceStore.GetStore(name: string): DataStore
	return DataStoreService:GetDataStore(name)
end

-- Returns (ok, value). `ok=false` means the read itself failed (network/
-- throttle) — NOT the same as "key doesn't exist," which is ok=true, value=nil.
function PersistenceStore.SafeGet(store: DataStore, key: string): (boolean, any)
	local ok, result = pcall(function()
		return store:GetAsync(key)
	end)
	if not ok then
		warn(`PersistenceStore: GetAsync failed for "{key}":`, result)
	end
	return ok, result
end

function PersistenceStore.SafeSet(store: DataStore, key: string, value: any): boolean
	local ok, err = pcall(function()
		store:SetAsync(key, value)
	end)
	if not ok then
		warn(`PersistenceStore: SetAsync failed for "{key}":`, err)
	end
	return ok
end

-- Returns (ok, newValue). `transform(old)` should return nil to abort the
-- write (e.g. "this listing is no longer Active, don't claim it") — Roblox
-- serializes concurrent UpdateAsync calls to the same key across every
-- server, which is the entire cross-server-safety mechanism this phase's
-- marketplace/base-slot registry rely on.
function PersistenceStore.SafeUpdate(store: DataStore, key: string, transform: (old: any) -> any): (boolean, any)
	local ok, result = pcall(function()
		return store:UpdateAsync(key, transform)
	end)
	if not ok then
		warn(`PersistenceStore: UpdateAsync failed for "{key}":`, result)
	end
	return ok, result
end

function PersistenceStore.SafeIncrement(store: DataStore, key: string, delta: number): (boolean, number?)
	local ok, err = pcall(function()
		return store:IncrementAsync(key, delta)
	end)
	if not ok then
		warn(`PersistenceStore: IncrementAsync failed for "{key}":`, err)
		return false, nil
	end
	return ok, err
end

return PersistenceStore
