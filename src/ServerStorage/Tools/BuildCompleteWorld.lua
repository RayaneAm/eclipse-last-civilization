--!strict
-- Canonical one-click edit-mode world build. Keep orchestration here so the
-- Studio plugin remains a thin launcher for the live Rojo-synced modules.

local ServerScriptService = game:GetService("ServerScriptService")

local BuildWorldMap = require(script.Parent.BuildWorldMap)
local BuildSurvivorHaven = require(script.Parent.BuildSurvivorHaven)
local BuildHavenDistricts = require(script.Parent.BuildHavenDistricts)
local BuildTutorialZone = require(script.Parent.BuildTutorialZone)
local ValidateWorldComposition = require(script.Parent.ValidateWorldComposition)
local ValidatePlayerSessionProfile = require(script.Parent.ValidatePlayerSessionProfile)
local ValidateDailyQuests = require(script.Parent.ValidateDailyQuests)
local ValidatePersonalBaseLayout = require(script.Parent.ValidatePersonalBaseLayout)
local ValidatePersonalBaseSystems = require(script.Parent.ValidatePersonalBaseSystems)
local EnvironmentService = require(ServerScriptService.Server.Services.EnvironmentService)

local BuildCompleteWorld = {}

-- Every stage dependency above is eagerly required before Run() can be
-- invoked. A missing/stale generator therefore fails during module loading,
-- before any build stage is allowed to mutate Workspace.

local function runStage<T>(label: string, callback: () -> T): T
	print(`[ECLIPSE TOOLS] {label}...`)
	local ok, result = xpcall(callback, debug.traceback)
	if not ok then
		error(`[BuildCompleteWorld] Failed during {label}:\n{result}`, 0)
	end
	return result :: T
end

function BuildCompleteWorld.Run()
	runStage("Validating PlayerSession profile schema", ValidatePlayerSessionProfile.Run)
	runStage("Validating Daily Quest pool + selection", ValidateDailyQuests.Run)
	runStage("Validating Personal Base data + production", ValidatePersonalBaseSystems.Run)
	runStage("Validating Personal Base layout config", function()
		local report = ValidatePersonalBaseLayout.Run(nil)
		assert(report.Passed, `[BuildCompleteWorld] Personal Base layout invalid: {table.concat(report.Errors, "; ")}`)
		return report
	end)
	-- The remote terrain pass comes first: it is the slowest/destructive stage
	-- and owns the one-time cleanup of legacy terrain outside the Haven core.
	runStage("Building remote biome world", BuildWorldMap.Run)

	-- These layers have separate generated roots and deliberately do not replace
	-- one another: infrastructure, staffed services, and the remote tutorial.
	runStage("Building Survivor Haven infrastructure", BuildSurvivorHaven.Run)
	runStage("Building Haven service districts", BuildHavenDistricts.Run)
	runStage("Building remote tutorial destination", BuildTutorialZone.Run)

	-- Apply the same service-owned preset used at runtime. No lighting values are
	-- duplicated in the plugin or this orchestrator.
	runStage("Applying the Default environment preset", function()
		EnvironmentService:ApplyPreset("Default")
	end)

	-- This must be the last stage so it evaluates the final composed result.
	local report = runStage("Running final world-composition validation", ValidateWorldComposition.Run)
	assert(report.Passed, "[BuildCompleteWorld] Final world-composition validation did not pass")

	print(`[ECLIPSE TOOLS] Validation passed: {#report.Checks} composition checks.`)
	print("[ECLIPSE TOOLS] Build Complete World finished successfully.")
	return report
end

return BuildCompleteWorld
