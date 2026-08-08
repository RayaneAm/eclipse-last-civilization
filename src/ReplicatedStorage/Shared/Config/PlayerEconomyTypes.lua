--!strict
-- Phase 4B: the durable player-economy profile — Scrap, carried materials,
-- equipped tool, material lock/discovery/pin metadata, and the concurrency/
-- idempotency records PlayerProfileService needs. Deliberately narrower than
-- the full PlayerSessionData: Progression (Tier/XP) and completed quests stay
-- owned and persisted by PlayerSessionService. This economy profile type is
-- retained for its future dedicated owner and is not activated by the
-- tutorial/profile foundation. Follows BaseSessionTypes.luau's convention
-- (CURRENT_SCHEMA_VERSION, NewDefault, data-only, no Instances).

export type AppliedEconomyOperation = {
	Fingerprint: string,
	Result: any,
	AppliedAt: number,
}

export type PlayerEconomyProfile = {
	SchemaVersion: number,
	Scrap: number,
	Inventory: { [string]: number },
	EquippedTool: string?,
	LockedMaterials: { [string]: boolean },
	DiscoveredMaterials: { [string]: boolean },
	PinnedTrackers: { string },
	StarterGrantVersion: number,
	-- Session lock (see PlayerProfileService) — nil means unclaimed.
	ActiveSession: { OwnerJobId: string, LeaseExpiresAt: number }?,
	-- Idempotency ledger for cross-domain operations touching THIS profile
	-- (deposits/withdrawals, production starts, building costs) — pruned
	-- after OPERATION_MARKER_RETENTION_SECONDS; the coordinator record in
	-- EclipseEconomyTransfers_v1 (see EconomyTransferJournal.luau) is the
	-- long-lived replay-protection authority, this is a fast local cache of
	-- the same fact.
	AppliedEconomyOperations: { [string]: AppliedEconomyOperation },
	-- Operations whose source-side mutation has durably landed on THIS
	-- profile but whose overall two-domain operation hasn't reached a
	-- terminal state yet — scanned and resumed on next load. Written in the
	-- SAME UpdateAsync call as the source mutation/marker above, never a
	-- separate write (see EconomyTransferJournal.luau).
	PendingOperationIds: { string },
}

local PlayerEconomyTypes = {}

local MAX_PINNED_TRACKERS = 5
PlayerEconomyTypes.MAX_PINNED_TRACKERS = MAX_PINNED_TRACKERS

PlayerEconomyTypes.CURRENT_SCHEMA_VERSION = 1
-- Bump whenever the starter grant contents change; existing players receive
-- exactly the delta once, additively, never a reset — see PlayerProfileService.
PlayerEconomyTypes.CURRENT_STARTER_GRANT_VERSION = 1

function PlayerEconomyTypes.NewDefault(): PlayerEconomyProfile
	return {
		SchemaVersion = PlayerEconomyTypes.CURRENT_SCHEMA_VERSION,
		Scrap = 0,
		Inventory = {},
		EquippedTool = nil,
		LockedMaterials = {},
		DiscoveredMaterials = {},
		PinnedTrackers = {},
		StarterGrantVersion = 0,
		ActiveSession = nil,
		AppliedEconomyOperations = {},
		PendingOperationIds = {},
	}
end

-- Per-field defensive clamp: a corrupted/garbage single entry is dropped
-- (and logged by the caller) rather than discarding the whole profile.
function PlayerEconomyTypes.IsValidQuantity(amount: number): boolean
	return typeof(amount) == "number" and amount == amount -- rejects NaN (NaN ~= NaN)
		and amount ~= math.huge and amount ~= -math.huge
		and amount >= 0 and amount == math.floor(amount)
end

-- Migrates a raw, possibly-older-or-corrupt decoded table into a valid
-- PlayerEconomyProfile. Missing SchemaVersion is treated as version 0 (pre-
-- migration), same convention as BaseSessionTypes.
function PlayerEconomyTypes.Migrate(raw: any): PlayerEconomyProfile
	local profile = PlayerEconomyTypes.NewDefault()
	if typeof(raw) ~= "table" then
		return profile
	end

	if PlayerEconomyTypes.IsValidQuantity(raw.Scrap) then
		profile.Scrap = raw.Scrap
	end
	if typeof(raw.Inventory) == "table" then
		for itemId, amount in raw.Inventory do
			if typeof(itemId) == "string" and PlayerEconomyTypes.IsValidQuantity(amount) and amount > 0 then
				profile.Inventory[itemId] = amount
			end
		end
	end
	if typeof(raw.EquippedTool) == "string" then
		profile.EquippedTool = raw.EquippedTool
	end
	if typeof(raw.LockedMaterials) == "table" then
		for itemId, locked in raw.LockedMaterials do
			if typeof(itemId) == "string" and locked == true then
				profile.LockedMaterials[itemId] = true
			end
		end
	end
	if typeof(raw.DiscoveredMaterials) == "table" then
		for itemId, discovered in raw.DiscoveredMaterials do
			if typeof(itemId) == "string" and discovered == true then
				profile.DiscoveredMaterials[itemId] = true
			end
		end
	end
	if typeof(raw.PinnedTrackers) == "table" then
		for _, key in raw.PinnedTrackers do
			if typeof(key) == "string" and #profile.PinnedTrackers < MAX_PINNED_TRACKERS then
				table.insert(profile.PinnedTrackers, key)
			end
		end
	end
	if typeof(raw.StarterGrantVersion) == "number" then
		profile.StarterGrantVersion = raw.StarterGrantVersion
	end
	if typeof(raw.ActiveSession) == "table" and typeof(raw.ActiveSession.OwnerJobId) == "string" and typeof(raw.ActiveSession.LeaseExpiresAt) == "number" then
		profile.ActiveSession = { OwnerJobId = raw.ActiveSession.OwnerJobId, LeaseExpiresAt = raw.ActiveSession.LeaseExpiresAt }
	end
	if typeof(raw.AppliedEconomyOperations) == "table" then
		for operationId, entry in raw.AppliedEconomyOperations do
			if typeof(operationId) == "string" and typeof(entry) == "table" then
				profile.AppliedEconomyOperations[operationId] = {
					Fingerprint = if typeof(entry.Fingerprint) == "string" then entry.Fingerprint else "",
					Result = entry.Result,
					AppliedAt = if typeof(entry.AppliedAt) == "number" then entry.AppliedAt else 0,
				}
			end
		end
	end
	if typeof(raw.PendingOperationIds) == "table" then
		for _, id in raw.PendingOperationIds do
			if typeof(id) == "string" then
				table.insert(profile.PendingOperationIds, id)
			end
		end
	end

	profile.SchemaVersion = PlayerEconomyTypes.CURRENT_SCHEMA_VERSION
	return profile
end

return PlayerEconomyTypes
