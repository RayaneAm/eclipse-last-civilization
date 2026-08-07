--!strict
-- Data-only definitions for the Leaderboard Hall's 3 passive-read columns.
-- No live backend exists yet for any of these (no cross-player stats /
-- OrderedDataStore system anywhere in the project) — wiring in real data
-- later only touches this file (or a future stats service it reads from),
-- never LeaderboardHallGenerator's wall geometry.

export type LeaderboardCategory = {
	Id: string,
	Title: string,
	RowCount: number,
}

local LeaderboardConfig = {}

LeaderboardConfig.Categories = {
	{ Id = "TopSurvivalDays", Title = "TOP SURVIVAL DAYS", RowCount = 10 },
	{ Id = "MostResourcesMined", Title = "MOST RESOURCES MINED", RowCount = 10 },
	{ Id = "BestBaseLevel", Title = "BEST BASE LEVEL", RowCount = 10 },
} :: { LeaderboardCategory }

return LeaderboardConfig
