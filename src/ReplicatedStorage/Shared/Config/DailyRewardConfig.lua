--!strict
-- Phase 3B: the Daily Rewards weighted reward pool, used identically by the
-- client (renders the roulette strip) and the server (picks the
-- authoritative result) so the strip can never show an outcome the server
-- didn't actually grant.

export type RewardEntry = {
	Id: string,
	Label: string,
	Icon: string,
	Weight: number,
	Kind: "Currency" | "Item",
	Amount: number,
	ItemId: string?, -- only set when Kind == "Item"
	-- PRESENTATION ONLY (added with the facility UI pass). Names which
	-- RarityConfig tier the reward card renders as. It has no effect on
	-- which reward is picked — `Weight` remains the sole input to
	-- PickWeighted below, and no weight was changed when these were added.
	Rarity: string?,
	-- Short display name/amount for the reward card, which shows them on
	-- separate lines. `Label` stays the one-line form used by the toast.
	CardTitle: string?,
	CardAmount: string?,
}

local DailyRewardConfig = {}

-- Rarity assignments mirror the existing weights (commonest -> Common,
-- rarest -> Epic) so the card a player sees matches how rare the drop
-- actually is. Reordering or reweighting this table is a BALANCE change and
-- is out of scope for a UI pass.
DailyRewardConfig.Rewards = {
	{ Id = "Scrap50", Label = "50 Scrap", Icon = "S", Weight = 40, Kind = "Currency", Amount = 50, ItemId = nil, Rarity = "Common", CardTitle = "SCRAP", CardAmount = "x50" },
	{ Id = "Scrap100", Label = "100 Scrap", Icon = "S", Weight = 25, Kind = "Currency", Amount = 100, ItemId = nil, Rarity = "Common", CardTitle = "SCRAP", CardAmount = "x100" },
	{ Id = "Scrap250", Label = "250 Scrap", Icon = "S", Weight = 15, Kind = "Currency", Amount = 250, ItemId = nil, Rarity = "Uncommon", CardTitle = "SCRAP", CardAmount = "x250" },
	{ Id = "Wood10", Label = "10 Wood", Icon = "W", Weight = 12, Kind = "Item", Amount = 10, ItemId = "Wood", Rarity = "Common", CardTitle = "WOOD", CardAmount = "x10" },
	{ Id = "Stone10", Label = "10 Stone", Icon = "R", Weight = 12, Kind = "Item", Amount = 10, ItemId = "Stone", Rarity = "Common", CardTitle = "STONE", CardAmount = "x10" },
	{ Id = "Scrap500", Label = "500 Scrap", Icon = "S", Weight = 4, Kind = "Currency", Amount = 500, ItemId = nil, Rarity = "Rare", CardTitle = "SCRAP", CardAmount = "x500" },
	{ Id = "HatchetRare", Label = "Hatchet", Icon = "H", Weight = 2, Kind = "Item", Amount = 1, ItemId = "Hatchet", Rarity = "Epic", CardTitle = "HATCHET", CardAmount = "x1" },
} :: { RewardEntry }

-- How many days the streak strip shows before it loops. Presentation only —
-- DailyRewardsService's stored Streak counter keeps incrementing past this.
DailyRewardConfig.StreakCycleDays = 7

-- The reset period, mirrored from DailyRewardsService's own SECONDS_PER_DAY
-- so the client can render an accurate "next reset in" countdown without
-- another remote round trip. Both sides derive the day index the same way
-- (floor(os.time() / SECONDS_PER_DAY)); this must stay in step with the
-- server constant.
DailyRewardConfig.SecondsPerDay = 86400

-- Design targets for per-day rarity floors (brief §34). Deliberately NOT
-- enforced anywhere yet: the live pick is still a pure weighted roll over
-- the table above. This exists so the intended shape is recorded in config
-- rather than hardcoded into a UI file, and so the streak strip can show
-- which days are meant to feel better. Wiring it into the roll would be a
-- balance change and needs its own pass.
DailyRewardConfig.StreakRarityTargets = {
	[1] = "Common",
	[2] = "Common",
	[3] = "Uncommon",
	[4] = "Uncommon",
	[5] = "Rare",
	[6] = "Rare",
	[7] = "Epic",
}

DailyRewardConfig.StreakTargetsEnforced = false

-- Picks a weighted-random index into `Rewards`. Shared by the server (the
-- authoritative pick) — the client never calls this itself, it only renders
-- whatever index the server already picked.
function DailyRewardConfig.PickWeighted(rng: Random): number
	local totalWeight = 0
	for _, reward in DailyRewardConfig.Rewards do
		totalWeight += reward.Weight
	end

	local roll = rng:NextNumber(0, totalWeight)
	local cumulative = 0
	for index, reward in DailyRewardConfig.Rewards do
		cumulative += reward.Weight
		if roll <= cumulative then
			return index
		end
	end
	return #DailyRewardConfig.Rewards
end

return DailyRewardConfig
