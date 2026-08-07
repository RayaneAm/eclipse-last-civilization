--!strict
-- Single source of truth for recommended Workspace streaming settings.
--
-- Read-only from runtime code: recent Roblox engine versions restrict
-- writes to Workspace.StreamingEnabled/StreamingMinRadius/StreamingTargetRadius
-- to scripts running with Plugin capability. A normal server Script (even in
-- ServerScriptService) cannot write them — see
-- src/server/Services/WorldStreamingService.luau, which only validates
-- against these numbers. The Studio plugin (plugin/) DOES have Plugin
-- capability and can apply these values directly — see
-- plugin/Modules/PluginValidator.luau.

export type StreamingSettings = {
	Enabled: boolean,
	MinRadius: number,
	TargetRadius: number,
}

local StreamingConfig = {}

StreamingConfig.Recommended = {
	Enabled = true,
	MinRadius = 192,
	TargetRadius = 512,
} :: StreamingSettings

return StreamingConfig
