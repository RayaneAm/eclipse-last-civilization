--!strict
-- Eclipse Assault foundation state machine configuration (Phase 4A) —
-- architecture only, no enemy roster/combat/damage model. See EclipseStateService.

export type EclipseState = "Calm" | "Warning" | "Lockdown" | "Assault" | "Recovery"

local EclipseStateConfig = {}

EclipseStateConfig.States = { "Calm", "Warning", "Lockdown", "Assault", "Recovery" } :: { EclipseState }

-- Seconds spent in each phase before automatically advancing. Calm has no
-- fixed duration here (it ends when the next cycle is scheduled/triggered);
-- kept as a large placeholder so a naive loop never spins on it.
EclipseStateConfig.PhaseDurationSeconds = {
	Calm = 0, -- advanced externally (scheduling), not by a fixed timer
	Warning = 8 * 60, -- "approximately 5-10 minutes" per the brief
	Lockdown = 90,
	Assault = 6 * 60,
	Recovery = 3 * 60,
}

-- Players at or below this base level are exempt from being targeted by an
-- assault (new-player protection).
EclipseStateConfig.MinBaseLevelForAssault = 5

-- Co-op difficulty scaling by active participating defender count — tunable,
-- not a simple health multiplier (see BasePermissionService/DefenseReserveService
-- consumers for how "active" is determined).
EclipseStateConfig.CoopScalingMultiplier = {
	[1] = 1.0,
	[2] = 1.6,
	[3] = 2.2,
	[4] = 2.8,
}

return EclipseStateConfig
