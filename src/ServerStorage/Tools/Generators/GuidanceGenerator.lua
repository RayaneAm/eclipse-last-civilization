--!strict
-- Small open-air Haven information point. The Guide deliberately has no
-- shelter: the one survival tent in this arrival composition belongs to the
-- Personal Base entrance.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HavenLayoutConfig = require(ReplicatedStorage.Shared.Config.HavenLayoutConfig)
local GeneratorKit = require(script.Parent.GeneratorKit)
local SurvivorFigureGenerator = require(script.Parent.SurvivorFigureGenerator)
local WorldFacilityLabelGenerator = require(script.Parent.WorldFacilityLabelGenerator)

local GuidanceGenerator = {}

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, material: Enum.Material, color: Color3, collide: boolean?): Part
	return GeneratorKit.NewPart({
		Name = name,
		Size = size,
		CFrame = cf,
		Material = material,
		Color = color,
		CanCollide = collide,
		Parent = parent,
	})
end

local function buildGuide(parent: Instance, origin: CFrame, accent: Color3)
	local cf = HavenLayoutConfig.CFrameFacing(origin, HavenLayoutConfig.GUIDE_LOCAL_POSITION, HavenLayoutConfig.SPAWN_LOCAL_POSITION)
	part(parent, "GuideRepairPatch", Vector3.new(10, 1, 8), cf * CFrame.new(0, 0.55, 0), Enum.Material.Concrete, Color3.fromRGB(78, 76, 69))
	for _, x in { -4, 4 } do
		part(parent, "GuideSupplyCrate", Vector3.new(2.2, 1.7, 2), cf * CFrame.new(x, 1.4, 2.5), Enum.Material.WoodPlanks, Color3.fromRGB(78, 60, 43))
	end
	part(parent, "HavenMapStand", Vector3.new(4.2, 2.8, 2.4), cf * CFrame.new(-3.5, 1.9, -1), Enum.Material.WoodPlanks, Color3.fromRGB(92, 69, 46))
	part(parent, "GuideFieldRadio", Vector3.new(1.5, 1.2, 1), cf * CFrame.new(3.2, 1.4, -1.5), Enum.Material.Metal, Color3.fromRGB(59, 65, 64))
	part(parent, "ExpeditionDirectionBoard", Vector3.new(4.5, 3.2, 0.45), cf * CFrame.new(4.5, 2.8, 3.2), Enum.Material.WoodPlanks, Color3.fromRGB(84, 64, 45))
	SurvivorFigureGenerator.Build(parent, cf * CFrame.new(0, 1, -1), "Guide")
	local npcAnchor = part(parent, "HavenGuideAnchor", Vector3.new(4, 6, 2), cf * CFrame.new(0, 3.5, -2), Enum.Material.ForceField, accent, false)
	npcAnchor.Transparency = 1
	CollectionService:AddTag(npcAnchor, "NPC")
	local facilityAnchor = part(parent, "FacilityAnchor", Vector3.new(4, 5, 1), cf * CFrame.new(0, 3, -4), Enum.Material.ForceField, accent, false)
	facilityAnchor.Transparency = 1
	facilityAnchor:SetAttribute("FacilityId", "QuestGiver")
	CollectionService:AddTag(facilityAnchor, "HavenFacility")
	WorldFacilityLabelGenerator.Build(parent, cf * CFrame.new(0, 5.8, -4.1), {
		Title = "Haven Guide",
		Subtitle = "Bases • Services • Expeditions",
		AccentColor = accent,
		Width = 14,
		MaxDistance = 68,
	})
	local fixture = part(parent, "GuidePractical", Vector3.new(0.55, 0.55, 0.55), cf * CFrame.new(3.2, 2.3, -1.5), Enum.Material.Neon, Color3.fromRGB(190, 133, 72), false)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 199, 126)
	light.Brightness = 0.45
	light.Range = 9
	light.Parent = fixture
end

function GuidanceGenerator.Build(parent: Instance, origin: CFrame, _districtCenter: Vector3, accentColor: Color3): Model
	GeneratorKit.CleanupPrevious(parent, "Guidance")
	local model = Instance.new("Model")
	model.Name = "Guidance"
	buildGuide(model, origin, accentColor)
	model.Parent = parent
	return model
end

return GuidanceGenerator
