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
}

local DailyRewardConfig = {}

DailyRewardConfig.Rewards = {
	{ Id = "Scrap50", Label = "50 Scrap", Icon = "⚙", Weight = 40, Kind = "Currency", Amount = 50, ItemId = nil },
	{ Id = "Scrap100", Label = "100 Scrap", Icon = "⚙", Weight = 25, Kind = "Currency", Amount = 100, ItemId = nil },
	{ Id = "Scrap250", Label = "250 Scrap", Icon = "⚙", Weight = 15, Kind = "Currency", Amount = 250, ItemId = nil },
	{ Id = "Wood10", Label = "10 Wood", Icon = "🌳", Weight = 12, Kind = "Item", Amount = 10, ItemId = "Wood" },
	{ Id = "Stone10", Label = "10 Stone", Icon = "⛰", Weight = 12, Kind = "Item", Amount = 10, ItemId = "Stone" },
	{ Id = "Scrap500", Label = "500 Scrap", Icon = "⚙", Weight = 4, Kind = "Currency", Amount = 500, ItemId = nil },
	{ Id = "HatchetRare", Label = "Hatchet", Icon = "⛏", Weight = 2, Kind = "Item", Amount = 1, ItemId = "Hatchet" },
} :: { RewardEntry }

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
