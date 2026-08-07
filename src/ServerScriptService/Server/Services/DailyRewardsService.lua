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
local DailyRewardConfig = require(ReplicatedStorage.Shared.Config.DailyRewardConfig)

local CurrencyService = require(script.Parent.CurrencyService)
local InventoryService = require(script.Parent.InventoryService)

local dailyRewardsStore = DataStoreService:GetDataStore("EclipseDailyRewards_v1")
local SECONDS_PER_DAY = 86400

export type ClaimResult = { Rejected: boolean, RewardIndex: number?, Streak: number? }

local DailyRewardsService = {}

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
		return { Rejected = false, RewardIndex = newRecord.RewardIndex, Streak = newRecord.Streak }
	end)

	pendingClaims[player] = nil

	if not ok then
		warn(`DailyRewardsService: claim failed for {player.Name}:`, result)
		return { Rejected = true }
	end
	return result :: ClaimResult
end

function DailyRewardsService:Init()
	Net.GetFunction("RequestDailyRewardRoll").OnServerInvoke = function(player: Player)
		return DailyRewardsService.Claim(player)
	end
end

return DailyRewardsService
