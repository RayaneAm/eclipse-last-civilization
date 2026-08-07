--!strict
-- XP thresholds per Progression.Tier. ThresholdForTier(tier) returns the
-- total XP required to advance OUT of that tier (nil at the max tier — there
-- is nothing further to advance to). ProgressionService.AddXP is the only
-- mutator of XP; the client only ever reads this indirectly via the
-- XPChanged event's pre-computed XPToNextTier field, never reimplements the
-- rollover math itself — same "server derives, client just renders" split
-- QuestConfig.DescribeCurrentObjective already established for quest text.
--
-- Tier 0 -> 1 is set to exactly QuestConfig.TutorialQuest.rewardXP (100) so
-- completing the tutorial fills the XP bar to 100% in the same instant
-- Progression.Tier increments to 1 and the Forest gate opens.

local XPConfig = {}

XPConfig.MaxTier = 4 -- matches BiomeConfig's highest unlockTier (VolcanicCore)

local Thresholds: { [number]: number } = {
	[0] = 100, -- Tier 0 -> 1 (Forest Wildlands) — must equal QuestConfig.TutorialQuest.rewardXP
	[1] = 500, -- Tier 1 -> 2 (Frozen Wasteland) — scaffolded for future content, unused today
	[2] = 1500, -- Tier 2 -> 3 (Nuclear City) — scaffolded for future content, unused today
	[3] = 4000, -- Tier 3 -> 4 (Volcanic Core) — scaffolded for future content, unused today
}

function XPConfig.ThresholdForTier(tier: number): number?
	return Thresholds[tier]
end

return XPConfig
