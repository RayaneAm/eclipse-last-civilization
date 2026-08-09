--!strict
-- Rebuilds the authored Small Hangout tutorial from its saved ServerStorage
-- template, then applies the focused generated art pass. The pristine template
-- is intentionally a Studio-authored model because Workspace is not Rojo-
-- mapped and this tutorial's island/bridge layout must remain intact.

local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local PolishTutorialZone = require(script.Parent.PolishTutorialZone)

local BuildTutorialZone = {}

local ROOT_NAME = "TutorialZone_Generated"
local TEMPLATE_NAME = "TutorialZoneAuthoredTemplate"

function BuildTutorialZone.Run(): Model
	local existing = Workspace:FindFirstChild(ROOT_NAME)
	local template = ServerStorage:FindFirstChild(TEMPLATE_NAME)
	if not template
		and existing
		and existing:IsA("Model")
		and existing:GetAttribute("ArtDirectionVersion") == nil
	then
		-- First run against the imported place: capture the untouched authored
		-- map before any polish is applied, making every later rebuild reversible.
		template = existing:Clone()
		template.Name = TEMPLATE_NAME
		template:SetAttribute("TemplateVersion", 1)
		template:SetAttribute("Purpose", "PristineSmallHangoutTutorialBaseline")
		template.Parent = ServerStorage
	end
	local root: Model
	if template and template:IsA("Model") then
		if existing then
			existing:Destroy()
		end
		root = template:Clone()
		root.Name = ROOT_NAME
		root.Parent = Workspace
	else
		assert(
			existing and existing:IsA("Model"),
			`BuildTutorialZone: neither ServerStorage.{TEMPLATE_NAME} nor Workspace.{ROOT_NAME} exists`
		)
		root = existing :: Model
	end

	PolishTutorialZone.Run(root)
	print("[BuildTutorialZone] Restored the authored tutorial and applied the clean handcrafted camp polish.")
	return root
end

return BuildTutorialZone
