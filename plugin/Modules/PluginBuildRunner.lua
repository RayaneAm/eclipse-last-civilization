--!strict

local ChangeHistoryService = game:GetService("ChangeHistoryService")

local FreshModuleLoader = require(script.Parent.FreshModuleLoader)
local PluginValidator = require(script.Parent.PluginValidator)
local WorkspaceBuildTransaction = require(script.Parent.WorkspaceBuildTransaction)

local PluginBuildRunner = {}

local function beginRecording(displayName: string): string
	local recording = ChangeHistoryService:TryBeginRecording(`EclipseTools_{displayName}`, displayName)
	if not recording then
		error(`[ECLIPSE TOOLS] Could not start ChangeHistory recording for {displayName}`, 3)
	end
	return recording
end

function PluginBuildRunner.Run(toolName: string, displayName: string, recordChanges: boolean): (boolean, any)
	local recording: string? = nil
	local graph: FreshModuleLoader.WorldBuildGraph? = nil
	local workspaceTransaction: WorkspaceBuildTransaction.Transaction? = nil
	local ok, result = xpcall(function()
		PluginValidator.Preflight(toolName)
		print("[ECLIPSE TOOLS] Loading fresh Rojo-synced world modules...")
		graph = FreshModuleLoader.CreateWorldBuildGraph()

		local tools = (graph :: FreshModuleLoader.WorldBuildGraph).Tools
		local moduleInstance = tools:FindFirstChild(toolName)
		assert(moduleInstance and moduleInstance:IsA("ModuleScript"), `[ECLIPSE TOOLS] Temporary graph is missing ModuleScript Tools.{toolName}`)
		local moduleScript = moduleInstance :: ModuleScript
		-- Requiring the entry tool loads its complete dependency graph. Keep this
		-- before the change recording and Run() so a preflight/module-load failure
		-- cannot execute a builder or touch any Workspace content.
		local liveTool = require(moduleScript)
		if type(liveTool) ~= "table" or type(liveTool.Run) ~= "function" then
			error(`[ECLIPSE TOOLS] {moduleScript:GetFullName()} must return a table with Run()`, 0)
		end
		if recordChanges then
			workspaceTransaction = WorkspaceBuildTransaction.Begin(toolName)
			recording = beginRecording(displayName)
		end
		return liveTool.Run()
	end, debug.traceback)

	local recordingFinalized = true
	if recording then
		local finishedRecording = recording
		recording = nil
		local finishOk, finishProblem = pcall(function()
			ChangeHistoryService:FinishRecording(
				finishedRecording,
				if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel
			)
		end)
		if not finishOk then
			recordingFinalized = false
			ok = false
			result = `{tostring(result)}\n[ECLIPSE TOOLS] ChangeHistory finalization failed: {tostring(finishProblem)}`
		end
	end

	if workspaceTransaction then
		local transactionOk, transactionProblem = pcall(
			WorkspaceBuildTransaction.Finish,
			workspaceTransaction,
			ok and recordingFinalized
		)
		if not transactionOk then
			ok = false
			result = `{tostring(result)}\n[ECLIPSE TOOLS] Workspace transaction cleanup failed: {tostring(transactionProblem)}`
		end
	end

	-- Finish the recording exactly once before deleting the private module
	-- graph. The graph predates the recording and owns no Workspace content.
	if graph then
		local cleanupOk, cleanupProblem = pcall(FreshModuleLoader.DestroyWorldBuildGraph, graph)
		if not cleanupOk then
			ok = false
			result = `{tostring(result)}\n[ECLIPSE TOOLS] Temporary module cleanup failed: {tostring(cleanupProblem)}`
		end
	end

	return ok, result
end

return PluginBuildRunner
