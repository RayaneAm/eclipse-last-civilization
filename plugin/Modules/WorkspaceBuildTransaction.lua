--!strict
-- Preserves builder-owned generated roots across a failed ChangeHistory
-- recording without ever asking Studio to reparent an Instance after Destroy().

local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")

local WorkspaceBuildTransaction = {}

local ROOTS_BY_TOOL: { [string]: { string } } = {
	BuildCompleteWorld = {
		"WorldMap_Generated",
		"SurvivorHaven_Generated",
		"HavenDistricts_Generated",
		"TutorialZone_Generated",
	},
	BuildSurvivorHaven = {
		"SurvivorHaven_Generated",
	},
}

export type Transaction = {
	BackupRoot: Folder,
	Entries: { Instance },
	RootNames: { string },
	WorkspaceCleared: boolean,
	Closed: boolean,
}

local function rootNameSet(names: { string }): { [string]: boolean }
	local result: { [string]: boolean } = {}
	for _, name in names do
		result[name] = true
	end
	return result
end

local function instanceSet(entries: { Instance }): { [Instance]: boolean }
	local result: { [Instance]: boolean } = {}
	for _, entry in entries do
		result[entry] = true
	end
	return result
end

local function destroyCurrentGeneratedRoots(names: { string }, preservedEntries: { Instance })
	local namesSet = rootNameSet(names)
	local preservedSet = instanceSet(preservedEntries)
	for _, child in Workspace:GetChildren() do
		-- ChangeHistory cancellation may make a preserved identity visible in
		-- Workspace again. Names identify generated-root roles; identity tells us
		-- whether a root is the old preserved world or a new build product.
		if namesSet[child.Name] and not preservedSet[child] then
			child:Destroy()
		end
	end
end

function WorkspaceBuildTransaction.Begin(toolName: string): Transaction?
	local configuredNames = ROOTS_BY_TOOL[toolName]
	if not configuredNames then
		return nil
	end

	local backupRoot = Instance.new("Folder")
	backupRoot.Name = `__EclipseWorkspaceBackup_{HttpService:GenerateGUID(false)}`
	-- Intentionally leave this transaction-owned folder outside the DataModel.
	-- Builders can only discover active generated roots through Workspace, and
	-- FreshModuleLoader cannot clone or traverse this private holding graph.
	local transaction: Transaction = {
		BackupRoot = backupRoot,
		Entries = {},
		RootNames = table.clone(configuredNames),
		WorkspaceCleared = false,
		Closed = false,
	}
	local namesSet = rootNameSet(configuredNames)

	local ok, problem = xpcall(function()
		for _, child in Workspace:GetChildren() do
			if namesSet[child.Name] then
				table.insert(transaction.Entries, child)
				child.Parent = backupRoot
			end
		end
	end, debug.traceback)
	if not ok then
		-- These entries were parked, never destroyed, so restoring their Parent is
		-- valid. Do not touch an entry that some external actor already removed.
		for _, entry in transaction.Entries do
			if entry.Parent == backupRoot then
				entry.Parent = Workspace
			end
		end
		backupRoot:Destroy()
		error(`[ECLIPSE TOOLS] Could not preserve existing generated roots:\n{problem}`, 2)
	end

	return transaction
end

function WorkspaceBuildTransaction.Finish(transaction: Transaction, keepNewWorld: boolean)
	if transaction.Closed then
		return
	end

	if keepNewWorld then
		-- BackupRoot is intentionally unparented, so Parent == nil is not a
		-- destruction signal. The transaction owns it and destroys it exactly once.
		transaction.BackupRoot:Destroy()
		transaction.Closed = true
		return
	end

	-- ChangeHistory has already been cancelled once. Remove any surviving new
	-- roots outside that recording, then restore only the intact originals that
	-- are still owned by this backup. WorkspaceCleared makes retries idempotent.
	if not transaction.WorkspaceCleared then
		destroyCurrentGeneratedRoots(transaction.RootNames, transaction.Entries)
		transaction.WorkspaceCleared = true
	end
	for _, entry in transaction.Entries do
		if entry.Parent == transaction.BackupRoot then
			entry.Parent = Workspace
		elseif entry.Parent ~= Workspace then
			error(
				`[ECLIPSE TOOLS] Preserved root {entry.Name} is no longer intact; refusing to reparent a removed/destroyed Instance`,
				2
			)
		end
	end

	transaction.BackupRoot:Destroy()
	transaction.Closed = true
end

return WorkspaceBuildTransaction
