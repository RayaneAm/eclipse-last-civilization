--!strict
-- Two-phase Init/Start service loader. Every ModuleScript directly under the
-- given folder is required, then ALL modules run :Init() (synchronous, for
-- setting up state other services may depend on), and only once every module
-- has finished Init does :Start() run (spawned, so long-running loops in one
-- service never block another service's startup).
--
-- This ordering guarantee is the reason cross-service references (e.g.
-- BiomeGateService reading a config another service owns) are safe regardless
-- of file load order.
--
-- One module's require()/Init()/Start() failure never stops the others —
-- each is individually pcall'd. Failure warnings name the exact module and,
-- for modules that opt in via IsOptional = true (validation/environment
-- services like WorldStreamingService, where a misconfigured setting isn't a
-- real gameplay bug), are worded as non-fatal so Output makes clear which
-- failures need attention and which don't.

local Loader = {}

export type ServiceModule = {
	Init: ((self: any) -> ())?,
	Start: ((self: any) -> ())?,
	IsOptional: boolean?,
	[string]: any,
}

type LoadedEntry = { Name: string, Module: ServiceModule }

local function describeFailure(name: string, module: ServiceModule, phase: string, err: string): string
	local kind = if module.IsOptional then "non-fatal/optional service" else "service"
	return `Loader: {phase} failed for {kind} "{name}": {err}`
end

function Loader.LoadChildren(container: Instance): { ServiceModule }
	local loaded: { LoadedEntry } = {}

	for _, child in container:GetChildren() do
		if child:IsA("ModuleScript") then
			local ok, result = pcall(require, child)
			if ok and typeof(result) == "table" then
				table.insert(loaded, { Name = child.Name, Module = result :: ServiceModule })
			elseif not ok then
				warn(`Loader: failed to require "{child.Name}" ({child:GetFullName()}): {result}`)
			end
		end
	end

	for _, entry in loaded do
		if typeof(entry.Module.Init) == "function" then
			local ok, err = pcall(entry.Module.Init, entry.Module)
			if not ok then
				warn(describeFailure(entry.Name, entry.Module, "Init", tostring(err)))
			end
		end
	end

	for _, entry in loaded do
		if typeof(entry.Module.Start) == "function" then
			task.spawn(function()
				local ok, err = pcall(entry.Module.Start, entry.Module)
				if not ok then
					warn(describeFailure(entry.Name, entry.Module, "Start", tostring(err)))
				end
			end)
		end
	end

	local modules = {}
	for _, entry in loaded do
		table.insert(modules, entry.Module)
	end
	return modules
end

return Loader
