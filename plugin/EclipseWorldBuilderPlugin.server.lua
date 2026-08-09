--!strict

local LogService = game:GetService("LogService")

local modules = script:WaitForChild("Modules")
local PluginBuildRunner = require(modules:WaitForChild("PluginBuildRunner"))
local PluginDialog = require(modules:WaitForChild("PluginDialog"))
local PluginValidator = require(modules:WaitForChild("PluginValidator"))

local toolbar = plugin:CreateToolbar("ECLIPSE TOOLS")
local buildCompleteButton = toolbar:CreateButton(
	"BuildCompleteWorld",
	"Rebuild the complete Eclipse world from the current Rojo-synced source",
	"",
	"BUILD COMPLETE WORLD"
)
local buildHavenButton = toolbar:CreateButton(
	"BuildSurvivorHaven",
	"Rebuild Survivor Haven from the current Rojo-synced source",
	"",
	"BUILD SURVIVOR HAVEN"
)
local buildTutorialButton = toolbar:CreateButton(
	"BuildTutorialZone",
	"Restore the authored tutorial template and apply the current Rojo-synced polish",
	"",
	"BUILD TUTORIAL ZONE"
)
local validateButton = toolbar:CreateButton(
	"ValidateWorld",
	"Run the live world-composition validator",
	"",
	"VALIDATE WORLD"
)

buildCompleteButton.ClickableWhenViewportHidden = true
buildHavenButton.ClickableWhenViewportHidden = true
buildTutorialButton.ClickableWhenViewportHidden = true
validateButton.ClickableWhenViewportHidden = true

local busy = false

local function run(toolName: string, displayName: string, recordChanges: boolean)
	if busy then
		warn("[ECLIPSE TOOLS] Another action is already running.")
		return
	end
	busy = true
	LogService:ClearOutput()
	print(`[ECLIPSE TOOLS] {displayName} started.`)

	local ok, result = PluginBuildRunner.Run(toolName, displayName, recordChanges)
	if ok then
		local summary = PluginValidator.DescribeReport(result)
		print(`[ECLIPSE TOOLS] SUCCESS: {displayName} — {summary}.`)
		PluginDialog.Notify("ECLIPSE TOOLS", `{displayName}: {summary}.`)
	else
		warn(`[ECLIPSE TOOLS] FAILED: {displayName}\n{tostring(result)}`)
		PluginDialog.Notify("ECLIPSE TOOLS — FAILED", `{displayName} stopped. See Output for the traceback.`)
	end
	busy = false
end

buildCompleteButton.Click:Connect(function()
	local confirmed = PluginDialog.Confirm(
		plugin,
		"Build Complete World",
		"This rebuilds generated Haven, biome terrain, districts, and the tutorial destination. Continue?"
	)
	if confirmed then
		run("BuildCompleteWorld", "Build Complete World", true)
	end
end)

buildHavenButton.Click:Connect(function()
	run("BuildSurvivorHaven", "Build Survivor Haven", true)
end)

buildTutorialButton.Click:Connect(function()
	run("BuildTutorialZone", "Build Tutorial Zone", true)
end)

validateButton.Click:Connect(function()
	run("ValidateWorldComposition", "Validate World", false)
end)
