--!strict
-- Phase 3B: server-authoritative Daily Rewards claim. Same scope boundary
-- as MonetizationService: the CLAIM RESERVATION (which day, which reward
-- index, streak count) is DataStore-only state and is made genuinely
-- atomic via one UpdateAsync; the actual GRANT (CurrencyService.Add /
-- InventoryService.AddItem) lands in the same in-memory-only player data
-- every other mutation in this game already uses, so it's held to that
-- same existing durability level, not a stronger one invented just for
-- this feature. See the Phase 3B plan for the full reasoning.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local Signal = require(ReplicatedStorage.Shared.Modules.Signal)
local DailyRewardConfig = require(ReplicatedStorage.Shared.Config.DailyRewardConfig)

local CurrencyService = require(script.Parent.CurrencyService)
local InventoryService = require(script.Parent.InventoryService)

local dailyRewardsStore = DataStoreService:GetDataStore("EclipseDailyRewards_v1")
local SECONDS_PER_DAY = 86400

export type ClaimResult = { Rejected: boolean, RewardIndex: number?, Streak: number? }

local DailyRewardsService = {}

-- Fired once per genuinely-accepted claim (the UpdateAsync below actually
-- wrote a new day), never on a same-day rejection — so a consumer counting
-- Haven facility use can't be inflated by re-clicking Claim.
DailyRewardsService.RewardClaimed = Signal.new() -- (player, rewardIndex, streak)

local pendingClaims: { [Player]: boolean } = {}

local function currentDayIndex(): number
	return math.floor(os.time() / SECONDS_PER_DAY)
end

local function grantReward(player: Player, reward: DailyRewardConfig.RewardEntry)
	if reward.Kind == "Currency" then
		CurrencyService.Add(player, reward.Amount)
	elseif reward.Kind == "Item" and reward.ItemId then
		InventoryService.AddItem(player, reward.ItemId, reward.Amount)
	end
end

-- Two-line defense against a double grant: `pendingClaims` is a cheap
-- in-memory reentrancy guard so two near-simultaneous clicks from the same
-- client don't both proceed at once — an optimization only. The real
-- guarantee is the single UpdateAsync below: Roblox serializes callbacks
-- for the same key, so a same-day claim is rejected correctly even across
-- overlapping requests or different servers, which this guard alone
-- couldn't do.
function DailyRewardsService.Claim(player: Player): ClaimResult
	if pendingClaims[player] then
		return { Rejected = true }
	end
	pendingClaims[player] = true

	local ok, result = pcall(function(): ClaimResult
		local key = tostring(player.UserId)
		local today = currentDayIndex()
		local rng = Random.new()

		local newRecord = dailyRewardsStore:UpdateAsync(key, function(old)
			old = old or { LastClaimDay = -1, Streak = 0, RewardIndex = 1 }
			if old.LastClaimDay == today then
				return nil -- abort: already claimed today, no change written
			end
			local newStreak = if old.LastClaimDay == today - 1 then old.Streak + 1 else 1
			local rewardIndex = DailyRewardConfig.PickWeighted(rng)
			return { LastClaimDay = today, Streak = newStreak, RewardIndex = rewardIndex }
		end)

		if not newRecord then
			return { Rejected = true }
		end

		-- The reward is chosen and durably recorded above BEFORE anything is
		-- granted — the client only starts its reveal animation once this
		-- whole function returns, so it always reveals an already-decided,
		-- already-recorded result, never a client-side guess.
		grantReward(player, DailyRewardConfig.Rewards[newRecord.RewardIndex])
		DailyRewardsService.RewardClaimed:Fire(player, newRecord.RewardIndex, newRecord.Streak)
		return { Rejected = false, RewardIndex = newRecord.RewardIndex, Streak = newRecord.Streak }
	end)

	pendingClaims[player] = nil

	if not ok then
		warn(`DailyRewardsService: claim failed for {player.Name}:`, result)
		return { Rejected = true }
	end
	return result :: ClaimResult
end

-- Read-only status for the reveal UI: is a spin available right now, what is
-- the current streak, and how long until the next reset. Uses GetAsync, NOT
-- UpdateAsync — this must never write, never pick a reward and never grant,
-- so opening the Daily Rewards screen can't consume the day's claim. The
-- authoritative claim stays entirely in Claim() above.
--
-- On a DataStore failure it reports Available = true rather than blocking:
-- the claim itself is still guarded by the atomic UpdateAsync, so an
-- optimistic status can at worst show a SPIN button whose claim then comes
-- back rejected — which the UI already handles — while the opposite
-- (pessimistically hiding the button) would lock out a legitimate claim.
export type StatusResult = { Available: boolean, Streak: number, SecondsUntilReset: number }

function DailyRewardsService.GetStatus(player: Player): StatusResult
	local now = os.time()
	local secondsUntilReset = SECONDS_PER_DAY - (now % SECONDS_PER_DAY)

	local ok, record = pcall(function()
		return dailyRewardsStore:GetAsync(tostring(player.UserId))
	end)

	if not ok then
		warn(`DailyRewardsService: status read failed for {player.Name}:`, record)
		return { Available = true, Streak = 0, SecondsUntilReset = secondsUntilReset }
	end
	if not record then
		return { Available = true, Streak = 0, SecondsUntilReset = secondsUntilReset }
	end

	local today = currentDayIndex()
	-- A streak only survives if the last claim was today or yesterday; an
	-- older record means the run is already broken and the next claim starts
	-- over at 1, which is what the strip should be showing.
	local streak = if record.LastClaimDay >= today - 1 then record.Streak else 0
	return {
		Available = record.LastClaimDay ~= today,
		Streak = streak,
		SecondsUntilReset = secondsUntilReset,
	}
end

function DailyRewardsService:Init()
	Net.GetFunction("RequestDailyRewardRoll").OnServerInvoke = function(player: Player)
		return DailyRewardsService.Claim(player)
	end
	Net.GetFunction("RequestDailyRewardStatus").OnServerInvoke = function(player: Player)
		return DailyRewardsService.GetStatus(player)
	end
end

return DailyRewardsService
