--!strict
-- Owns Progression.Tier (and, since Prompt 4C, Progression.XP) inside the
-- player's session — the single authority BiomeGateService (gate unlock +
-- physical barrier collision groups) and RegionService's locked-region
-- backstop both read.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local Signal = require(ReplicatedStorage.Shared.Modules.Signal)
local XPConfig = require(ReplicatedStorage.Shared.Config.XPConfig)
local PlayerSessionService = require(script.Parent.PlayerSessionService)

local ProgressionService = {}

-- Server-side signal (other Services react to a tier change without a
-- network round-trip). Net's "ProgressionChanged" event, fired alongside
-- this, is the client-facing push.
ProgressionService.TierChanged = Signal.new()

function ProgressionService.GetTier(player: Player): number
	return PlayerSessionService.Get(player).Progression.Tier
end

function ProgressionService.SetTier(player: Player, tier: number)
	local session = PlayerSessionService.Get(player)
	if session.Progression.Tier == tier then
		return
	end
	local previousTier = session.Progression.Tier
	session.Progression.Tier = tier
	print(`[ProgressionService] {player.Name} Progression.Tier {previousTier} -> {tier}`)
	ProgressionService.TierChanged:Fire(player, tier, previousTier)
	Net.GetEvent("ProgressionChanged"):FireClient(player, tier)
end

-- XP is progress *within* the current tier (see PlayerSessionTypes) — it
-- rolls over to 0 on every tier crossing rather than accumulating forever,
-- which keeps the client's XP bar math a simple XP/XPToNextTier fraction.
-- Crossing a threshold calls the existing, unmodified SetTier — safe even if
-- called redundantly elsewhere (e.g. QuestService still also calls SetTier
-- directly), since SetTier already no-ops on an unchanged value.
function ProgressionService.AddXP(player: Player, amount: number)
	if amount <= 0 then
		return
	end

	local session = PlayerSessionService.Get(player)
	local progression = session.Progression
	local tierUp = false

	progression.XP += amount

	local threshold = XPConfig.ThresholdForTier(progression.Tier)
	while threshold and progression.XP >= threshold do
		progression.XP -= threshold
		tierUp = true
		ProgressionService.SetTier(player, progression.Tier + 1)
		threshold = XPConfig.ThresholdForTier(progression.Tier)
	end

	if not threshold then
		progression.XP = 0 -- max tier reached; nothing further to accumulate toward
	end

	local nextThreshold = XPConfig.ThresholdForTier(progression.Tier)
	print(
		`[ProgressionService] {player.Name} +{amount} XP -> {progression.XP}{if nextThreshold then `/{nextThreshold}` else ""} (Tier {progression.Tier}){if tierUp then " [TIER UP]" else ""}`
	)

	Net.GetEvent("XPChanged"):FireClient(player, {
		AmountGained = amount,
		XP = progression.XP,
		XPToNextTier = nextThreshold,
		Tier = progression.Tier,
		TierUp = tierUp,
	})
end

return ProgressionService
