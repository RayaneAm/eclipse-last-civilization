--!strict
-- Eclipse Assault foundation state machine (Phase 4A) — architecture only:
-- Calm/Warning/Lockdown/Assault/Recovery transitions, broadcast to clients,
-- Studio-only debug hooks to force/skip a phase for testing. No enemy
-- spawning, no combat, no damage model, no contribution/reward payout —
-- those are explicitly deferred (see the Phase 4A plan).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local EclipseStateConfig = require(ReplicatedStorage.Shared.Config.EclipseStateConfig)

local EclipseStateService = {}

local currentState: EclipseStateConfig.EclipseState = "Calm"

function EclipseStateService.GetState(): EclipseStateConfig.EclipseState
	return currentState
end

local function setState(newState: EclipseStateConfig.EclipseState)
	currentState = newState
	Net.GetEvent("EclipseStateChanged"):FireAllClients(newState)
end

-- Advances Warning -> Lockdown -> Assault -> Recovery -> Calm on their
-- configured durations. Calm itself has no fixed duration (advanced
-- externally by a future scheduling system) — this loop just idles while Calm.
local function runPhaseLoop()
	while true do
		local duration = EclipseStateConfig.PhaseDurationSeconds[currentState]
		if currentState == "Calm" or duration <= 0 then
			task.wait(5)
		else
			task.wait(duration)
			local nextIndex = table.find(EclipseStateConfig.States, currentState) + 1
			local nextState = EclipseStateConfig.States[nextIndex] or "Calm"
			setState(nextState)
		end
	end
end

-- Studio-only: force or skip a phase from the command bar, e.g.
-- `require(game.ServerScriptService.Server.Services.EclipseStateService).DebugForceState("Assault")`.
function EclipseStateService.DebugForceState(state: EclipseStateConfig.EclipseState)
	if not RunService:IsStudio() then
		warn("EclipseStateService.DebugForceState is Studio-only")
		return
	end
	setState(state)
end

function EclipseStateService:Init()
	task.spawn(runPhaseLoop)
end

return EclipseStateService
