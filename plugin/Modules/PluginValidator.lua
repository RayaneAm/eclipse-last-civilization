--!strict
-- Plugin-only preflight checks. World correctness remains owned by the live
-- ServerStorage.Tools.ValidateWorldComposition module.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local PluginValidator = {}

local function expectChild(parent: Instance, name: string): Instance
	local child = parent:FindFirstChild(name)
	if not child then
		error(`[ECLIPSE TOOLS] Expected {parent:GetFullName()}.{name}. Is Rojo connected?`, 3)
	end
	return child
end

local function expectModuleScript(parent: Instance, name: string): ModuleScript
	local child = expectChild(parent, name)
	if not child:IsA("ModuleScript") then
		error(
			`[ECLIPSE TOOLS] Expected {child:GetFullName()} to be a ModuleScript, but Rojo produced {child.ClassName}.`,
			3
		)
	end
	return child
end

function PluginValidator.Preflight(toolName: string)
	if RunService:IsRunning() then
		error("[ECLIPSE TOOLS] World-building actions are edit-mode only. Stop the play session first.", 2)
	end

	-- Container instances are validated by their required descendants, not by
	-- ClassName. In this project Server is a Script because it owns
	-- init.server.lua, while its Services child is still a valid container.
	local shared = expectChild(ReplicatedStorage, "Shared")
	expectChild(shared, "Config")
	expectChild(shared, "Modules")
	local server = expectChild(ServerScriptService, "Server")
	local services = expectChild(server, "Services")
	expectModuleScript(services, "EnvironmentService")

	local tools = expectChild(ServerStorage, "Tools")
	expectModuleScript(tools, "BuildCompleteWorld")
	expectModuleScript(tools, "BuildHavenDistricts")
	expectModuleScript(tools, "BuildSurvivorHaven")
	expectModuleScript(tools, "ValidateWorldComposition")
	local generators = expectChild(tools, "Generators")
	expectModuleScript(generators, "LeaderboardHallGenerator")
	expectModuleScript(tools, toolName)
end

function PluginValidator.DescribeReport(result: any): string
	if type(result) == "table" and type(result.Checks) == "table" then
		return `{#result.Checks} world-composition checks passed`
	end
	return "action completed"
end

return PluginValidator
