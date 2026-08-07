--!strict
-- Validates Workspace streaming configuration. Deliberately does NOT write
-- StreamingEnabled/StreamingMinRadius/StreamingTargetRadius: recent Roblox
-- engine versions restrict those properties to Plugin capability, and a
-- normal runtime Script — even a trusted server Script in
-- ServerScriptService — throws "lacking capability Plugin" if it tries.
-- That's an engine restriction, not a bug to work around here.
--
-- Setting these values is now the ECLIPSE TOOLS Studio plugin's job (see
-- plugin/Modules/PluginValidator.luau, which runs with Plugin capability and
-- can write them), or a one-time manual edit in the Properties panel — see
-- PLUGIN_SETUP.md and the recommended values in
-- src/shared/Config/StreamingConfig.luau, the single source of truth both
-- this service and the plugin read.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StreamingConfig = require(ReplicatedStorage.Shared.Config.StreamingConfig)

local WorldStreamingService = {}

-- Validation-only: a misconfigured streaming setting is never a reason to
-- treat this service's failure the same as a real gameplay service failing.
-- See Loader.luau's IsOptional handling.
WorldStreamingService.IsOptional = true

function WorldStreamingService:Init()
	local recommended = StreamingConfig.Recommended
	local mismatches = {}

	if Workspace.StreamingEnabled ~= recommended.Enabled then
		table.insert(mismatches, `StreamingEnabled = {tostring(Workspace.StreamingEnabled)} (want {tostring(recommended.Enabled)})`)
	end
	if Workspace.StreamingMinRadius ~= recommended.MinRadius then
		table.insert(mismatches, `StreamingMinRadius = {Workspace.StreamingMinRadius} (want {recommended.MinRadius})`)
	end
	if Workspace.StreamingTargetRadius ~= recommended.TargetRadius then
		table.insert(mismatches, `StreamingTargetRadius = {Workspace.StreamingTargetRadius} (want {recommended.TargetRadius})`)
	end

	if #mismatches > 0 then
		warn(
			"WorldStreamingService: Workspace streaming settings don't match the recommended values, and a "
				.. "runtime script cannot change them (Roblox restricts these properties to Plugin capability). "
				.. "Fix via the ECLIPSE TOOLS \"Validate Project\" button (it can apply them for you), or manually: "
				.. "select Workspace in the Explorer, open the Properties panel, and set -> "
				.. table.concat(mismatches, "; ")
		)
	end
end

return WorldStreamingService
