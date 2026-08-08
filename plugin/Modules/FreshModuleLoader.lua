--!strict
-- Roblox caches require() by ModuleScript identity. Build from a private clone
-- graph so every action sees current Rojo Source without detaching, destroying,
-- renaming, or reparenting any canonical synced Instance.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local FreshModuleLoader = {}

export type WorldBuildGraph = {
	Root: Folder,
	Tools: Instance,
	Destroyed: boolean,
}

local function requiredChild(parent: Instance, name: string): Instance
	local child = parent:FindFirstChild(name)
	if not child then
		error(`FreshModuleLoader: missing {parent:GetFullName()}.{name}`, 3)
	end
	return child
end

local function requiredModuleScript(parent: Instance, name: string): ModuleScript
	local child = requiredChild(parent, name)
	if not child:IsA("ModuleScript") then
		error(`FreshModuleLoader: expected {child:GetFullName()} to be a ModuleScript, got {child.ClassName}`, 3)
	end
	return child
end

local function folder(name: string, parent: Instance): Folder
	local result = Instance.new("Folder")
	result.Name = name
	result.Parent = parent
	return result
end

local function rewriteModuleSource(moduleScript: ModuleScript, graphName: string)
	local source = moduleScript.Source
	for _, serviceName in { "ReplicatedStorage", "ServerScriptService", "ServerStorage" } do
		local pattern = `game:GetService%("{serviceName}"%)`
		local replacement = `script:FindFirstAncestor("{graphName}"):WaitForChild("{serviceName}")`
		source = string.gsub(source, pattern, replacement)
	end
	moduleScript.Source = source
end

local function rewriteCloneTree(root: Instance, graphName: string)
	if root:IsA("ModuleScript") then
		rewriteModuleSource(root, graphName)
	end
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("ModuleScript") then
			rewriteModuleSource(descendant, graphName)
		end
	end
end

local function cloneRoot(source: Instance, parent: Instance, graphName: string): Instance
	local clone = source:Clone()
	rewriteCloneTree(clone, graphName)
	clone.Parent = parent
	return clone
end

function FreshModuleLoader.CreateWorldBuildGraph(): WorldBuildGraph
	local graphName = `__EclipseFreshWorldGraph_{HttpService:GenerateGUID(false)}`
	local root = folder(graphName, ServerStorage)

	local ok, result = xpcall(function()
		local shared = requiredChild(ReplicatedStorage, "Shared")
		local server = requiredChild(ServerScriptService, "Server")
		local services = requiredChild(server, "Services")
		local tools = requiredChild(ServerStorage, "Tools")

		local replicatedStorageClone = folder("ReplicatedStorage", root)
		local sharedClone = folder("Shared", replicatedStorageClone)
		cloneRoot(requiredChild(shared, "Config"), sharedClone, graphName)
		cloneRoot(requiredChild(shared, "Modules"), sharedClone, graphName)

		local serverScriptServiceClone = folder("ServerScriptService", root)
		local serverClone = folder("Server", serverScriptServiceClone)
		local servicesClone = folder("Services", serverClone)
		cloneRoot(requiredModuleScript(services, "EnvironmentService"), servicesClone, graphName)

		local serverStorageClone = folder("ServerStorage", root)
		return cloneRoot(tools, serverStorageClone, graphName)
	end, debug.traceback)

	if not ok then
		-- The root is plugin-owned and has never entered a ChangeHistory
		-- recording. Destroying it is sufficient; never reconstruct/reparent any
		-- child after a partial clone failure.
		if root.Parent ~= nil then
			root:Destroy()
		end
		error(`FreshModuleLoader: could not create temporary build graph:\n{result}`, 2)
	end

	local graph: WorldBuildGraph = {
		Root = root,
		Tools = result :: Instance,
		Destroyed = false,
	}
	print(`[ECLIPSE TOOLS] Loaded fresh modules in private graph {graphName}; canonical Rojo instances were not mutated.`)
	return graph
end

function FreshModuleLoader.DestroyWorldBuildGraph(graph: WorldBuildGraph)
	if graph.Destroyed then
		return
	end

	-- Parent=nil means the temporary root was already removed. It may also be a
	-- destroyed Instance whose Parent is permanently locked; either way cleanup
	-- is complete and must never attempt to restore it.
	if graph.Root.Parent ~= nil then
		graph.Root:Destroy()
	end
	graph.Destroyed = true
end

return FreshModuleLoader
