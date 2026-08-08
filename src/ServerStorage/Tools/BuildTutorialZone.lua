--!strict
-- Compact first-login survivor training base at the existing remote Tutorial
-- origin. Gameplay resource nodes are spawned at authored anchors by
-- ResourceService; this builder owns only stable world composition/contracts.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local HavenLayoutConfig = require(ReplicatedStorage.Shared.Config.HavenLayoutConfig)
local PortalDestinationConfig = require(ReplicatedStorage.Shared.Config.PortalDestinationConfig)
local WorldMapConfig = require(ReplicatedStorage.Shared.Config.WorldMapConfig)
local GeneratorKit = require(script.Parent.Generators.GeneratorKit)
local SurvivorFigureGenerator = require(script.Parent.Generators.SurvivorFigureGenerator)
local WorldFacilityLabelGenerator = require(script.Parent.Generators.WorldFacilityLabelGenerator)

local BuildTutorialZone = {}

local ROOT_NAME = "TutorialZone_Generated"
local TOTAL_SIZE = 66
local PLAYABLE_SIZE = 52
local SPAWN_LOCAL = Vector3.new(0, 0, 21)
local GUIDE_LOCAL = Vector3.new(0, 0, 7)
local WORKBENCH_LOCAL = Vector3.new(9, 0, -5)

local RESOURCE_ANCHORS = {
	{ Id = "Wood", Position = Vector3.new(-18, 0, 3) },
	{ Id = "Wood", Position = Vector3.new(-17, 0, -8) },
	{ Id = "Wood", Position = Vector3.new(-13, 0, 14) },
	{ Id = "Stone", Position = Vector3.new(17, 0, 4) },
	{ Id = "Stone", Position = Vector3.new(19, 0, -8) },
	{ Id = "Stone", Position = Vector3.new(14, 0, 14) },
}

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, material: Enum.Material, color: Color3, collide: boolean?): Part
	return GeneratorKit.NewPart({
		Name = name,
		Size = size,
		CFrame = cframe,
		Material = material,
		Color = color,
		CanCollide = collide,
		Parent = parent,
	})
end

local function buildGround(parent: Instance, origin: CFrame)
	part(parent, "TutorialFoundation", Vector3.new(TOTAL_SIZE, 3, TOTAL_SIZE), origin * CFrame.new(0, -1.5, 0), Enum.Material.Rock, Color3.fromRGB(63, 65, 58))
	part(parent, "TutorialGrass", Vector3.new(TOTAL_SIZE - 2, 1, TOTAL_SIZE - 2), origin * CFrame.new(0, 0, 0), Enum.Material.Grass, Color3.fromRGB(78, 102, 64))
	part(parent, "SpawnFootpath", Vector3.new(7, 0.22, 27), origin * CFrame.new(0, 0.62, 12), Enum.Material.Ground, Color3.fromRGB(108, 91, 67), false)
	part(parent, "WorkbenchFootpath", Vector3.new(14, 0.2, 5), origin * CFrame.new(5, 0.63, 1), Enum.Material.Ground, Color3.fromRGB(108, 91, 67), false)
	part(parent, "GuideClearing", Vector3.new(13, 0.2, 13), origin * CFrame.new(0, 0.64, 7), Enum.Material.Ground, Color3.fromRGB(112, 94, 69), false)
	for _, patch in {
		{ Vector3.new(-16, 0.64, 3), Vector3.new(15, 0.18, 23) },
		{ Vector3.new(16, 0.64, 3), Vector3.new(15, 0.18, 23) },
	} do
		part(parent, "ResourcePatch", patch[2], origin * CFrame.new(patch[1]), Enum.Material.Ground, Color3.fromRGB(91, 78, 61), false)
	end
end

local function buildTree(parent: Instance, origin: CFrame, x: number, z: number, height: number)
	part(parent, "BoundaryTreeTrunk", Vector3.new(1.8, height * 0.58, 1.8), origin * CFrame.new(x, height * 0.29, z), Enum.Material.Wood, Color3.fromRGB(62, 47, 34))
	for tier = 1, 3 do
		local radius = 5.8 - tier * 0.75
		part(
			parent,
			"BoundaryTreeCrown",
			Vector3.new(radius * 2, 4.5, radius * 2),
			origin * CFrame.new(x, height * 0.5 + tier * 2.6, z),
			Enum.Material.LeafyGrass,
			Color3.fromRGB(49 + tier * 3, 77 + tier * 4, 43),
			false
		).Shape = Enum.PartType.Ball
	end
end

local function buildBoundary(parent: Instance, origin: CFrame)
	local boundary = Instance.new("Model")
	boundary.Name = "NaturalBoundary"
	local treePoints = {
		{ -29, -29 }, { -19, -31 }, { -8, -30 }, { 8, -31 }, { 20, -30 }, { 30, -28 },
		{ -30, -18 }, { -31, -6 }, { -30, 8 }, { -31, 20 }, { -29, 30 },
		{ 30, -17 }, { 31, -5 }, { 30, 8 }, { 31, 20 }, { 29, 30 },
		{ -19, 31 }, { -8, 30 }, { 9, 31 }, { 20, 30 },
	}
	for index, point in treePoints do
		buildTree(boundary, origin, point[1], point[2], 12 + (index % 3) * 2)
	end
	for _, rock in {
		{ -25, 25, 7, 4 }, { 25, 24, 8, 5 }, { -25, -20, 6, 5 }, { 25, -23, 7, 4 },
	} do
		part(boundary, "BoundaryRock", Vector3.new(rock[3], rock[4], 5), origin * CFrame.new(rock[1], rock[4] / 2, rock[2]) * CFrame.Angles(0, math.rad(rock[1]), 0), Enum.Material.Rock, Color3.fromRGB(76, 74, 68))
	end
	part(boundary, "FallenBoundaryLog", Vector3.new(15, 2.2, 2.2), origin * CFrame.new(-20, 1.1, 27) * CFrame.Angles(0, math.rad(18), 0), Enum.Material.Wood, Color3.fromRGB(69, 51, 35))
	for _, x in { -11, -4, 4, 11 } do
		part(boundary, "RuinedFencePost", Vector3.new(0.7, 5, 0.7), origin * CFrame.new(x, 2.5, -29), Enum.Material.CorrodedMetal, Color3.fromRGB(70, 72, 68))
	end
	for _, wall in {
		{ Vector3.new(TOTAL_SIZE, 12, 1), Vector3.new(0, 6, -TOTAL_SIZE / 2) },
		{ Vector3.new(TOTAL_SIZE, 12, 1), Vector3.new(0, 6, TOTAL_SIZE / 2) },
		{ Vector3.new(1, 12, TOTAL_SIZE), Vector3.new(-TOTAL_SIZE / 2, 6, 0) },
		{ Vector3.new(1, 12, TOTAL_SIZE), Vector3.new(TOTAL_SIZE / 2, 6, 0) },
	} do
		local backup = part(boundary, "BoundaryCollisionBackup", wall[1], origin * CFrame.new(wall[2]), Enum.Material.SmoothPlastic, Color3.new(), true)
		backup.Transparency = 1
	end
	boundary:SetAttribute("TotalFootprint", TOTAL_SIZE)
	boundary:SetAttribute("PlayableFootprint", PLAYABLE_SIZE)
	boundary.Parent = parent
end

local function buildShelter(parent: Instance, origin: CFrame)
	local shelter = Instance.new("Model")
	shelter.Name = "SurvivorTrainingShelter"
	local center = origin * CFrame.new(0, 0, -12)
	part(shelter, "ShelterDeck", Vector3.new(30, 1, 20), center * CFrame.new(0, 0.5, 0), Enum.Material.WoodPlanks, Color3.fromRGB(78, 62, 46))
	for _, x in { -13.5, 13.5 } do
		for _, z in { -8, 8 } do
			part(shelter, "ReinforcedPost", Vector3.new(1.2, 10, 1.2), center * CFrame.new(x, 5.5, z), Enum.Material.Metal, Color3.fromRGB(62, 67, 68))
		end
	end
	part(shelter, "ReclaimedRoof", Vector3.new(32, 1.2, 21), center * CFrame.new(0, 10.6, 0), Enum.Material.CorrodedMetal, Color3.fromRGB(70, 75, 70))
	part(shelter, "RoofCap", Vector3.new(28, 0.5, 17), center * CFrame.new(0, 11.3, 0), Enum.Material.Metal, Color3.fromRGB(53, 59, 58), false)
	part(shelter, "RearWall", Vector3.new(28, 7, 1), center * CFrame.new(0, 4, -8.5), Enum.Material.WoodPlanks, Color3.fromRGB(73, 59, 45))
	for _, x in { -14, 14 } do
		part(shelter, "ShelterSideWall", Vector3.new(1, 7, 12), center * CFrame.new(x, 4, -2.5), Enum.Material.CorrodedMetal, Color3.fromRGB(69, 72, 69))
		part(shelter, "FrontReturnWall", Vector3.new(5, 6, 1), center * CFrame.new(x * 0.82, 3.5, 8.5), Enum.Material.WoodPlanks, Color3.fromRGB(76, 60, 44))
	end
	part(shelter, "OutpostFascia", Vector3.new(30, 1.2, 1.2), center * CFrame.new(0, 8.4, 8.5), Enum.Material.Metal, Color3.fromRGB(50, 56, 58))
	part(shelter, "RadioTable", Vector3.new(5, 2.5, 2.2), center * CFrame.new(-8, 1.8, -5), Enum.Material.Metal, Color3.fromRGB(57, 61, 63))
	part(shelter, "FieldRadio", Vector3.new(1.4, 1.1, 0.8), center * CFrame.new(-8, 3.5, -5), Enum.Material.Metal, Color3.fromRGB(35, 39, 41), false)
	part(shelter, "MapBoard", Vector3.new(6, 4, 0.4), center * CFrame.new(-5, 5, -8), Enum.Material.WoodPlanks, Color3.fromRGB(91, 69, 47), false)
	part(shelter, "StorageShelf", Vector3.new(5, 6, 1.5), center * CFrame.new(10, 3.5, -7), Enum.Material.Metal, Color3.fromRGB(55, 61, 61))
	part(shelter, "TrainingBench", Vector3.new(6, 1.2, 1.8), center * CFrame.new(-9, 1.2, 3), Enum.Material.WoodPlanks, Color3.fromRGB(86, 66, 46))
	for _, x in { -11, 11 } do
		local lamp = part(shelter, "WarmShelterPractical", Vector3.new(0.7, 0.7, 0.7), center * CFrame.new(x, 8.4, 4), Enum.Material.Neon, Color3.fromRGB(220, 158, 83), false)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 193, 121)
		light.Brightness = 0.8
		light.Range = 15
		light.Parent = lamp
	end
	local outpostLabelPosition = center:PointToWorldSpace(Vector3.new(0, 9.1, 8.75))
	local spawnPosition = origin:PointToWorldSpace(SPAWN_LOCAL)
	WorldFacilityLabelGenerator.Build(shelter, CFrame.lookAt(outpostLabelPosition, Vector3.new(spawnPosition.X, outpostLabelPosition.Y, spawnPosition.Z)), {
		Title = "BEGINNER OUTPOST",
		Subtitle = "Gather  |  Craft  |  Survive",
		AccentColor = Color3.fromRGB(214, 169, 94),
		Width = 18,
		MaxDistance = 70,
	})
	shelter.Parent = parent
end

local function buildResourceLandmarks(parent: Instance, origin: CFrame)
	local woodCenter = origin * CFrame.new(-16, 0, 3)
	for _, offset in {
		Vector3.new(-4, 1, -8),
		Vector3.new(2, 1, 8),
		Vector3.new(4, 1, -2),
	} do
		part(parent, "WoodGroveLog", Vector3.new(5, 1.5, 1.5), woodCenter * CFrame.new(offset) * CFrame.Angles(0, math.rad(18), 0), Enum.Material.Wood, Color3.fromRGB(79, 57, 38))
	end
	local stoneCenter = origin * CFrame.new(16, 0, 3)
	for index, offset in {
		Vector3.new(-3, 1.3, -9),
		Vector3.new(4, 1.7, 8),
		Vector3.new(4, 1.1, -2),
	} do
		local marker = part(parent, "StoneOutcropMarker", Vector3.new(3.5, 2.2 + index * 0.25, 3), stoneCenter * CFrame.new(offset) * CFrame.Angles(0, math.rad(index * 23), math.rad(6)), Enum.Material.Rock, Color3.fromRGB(91, 92, 86))
		marker.Shape = Enum.PartType.Ball
	end
	local routeTarget = origin:PointToWorldSpace(Vector3.new(0, 5, 11))
	local woodLabelPosition = origin:PointToWorldSpace(Vector3.new(-16, 5, 15))
	WorldFacilityLabelGenerator.Build(parent, CFrame.lookAt(woodLabelPosition, routeTarget), {
		Title = "WOOD GROVE",
		Subtitle = "Gather Wood",
		AccentColor = Color3.fromRGB(205, 157, 91),
		Width = 11,
		MaxDistance = 55,
	})
	local stoneLabelPosition = origin:PointToWorldSpace(Vector3.new(16, 5, 15))
	WorldFacilityLabelGenerator.Build(parent, CFrame.lookAt(stoneLabelPosition, routeTarget), {
		Title = "STONE OUTCROP",
		Subtitle = "Gather Stone",
		AccentColor = Color3.fromRGB(181, 193, 189),
		Width = 12,
		MaxDistance = 55,
	})
end

local function buildGuide(parent: Instance, origin: CFrame)
	local guidePosition = origin:PointToWorldSpace(GUIDE_LOCAL)
	local spawnPosition = origin:PointToWorldSpace(SPAWN_LOCAL)
	local guideCFrame = CFrame.lookAt(guidePosition + Vector3.new(0, 1, 0), spawnPosition)
	SurvivorFigureGenerator.Build(parent, guideCFrame, "Guide")
	local anchor = part(parent, "QuestGiverAnchor", Vector3.new(4, 7, 3), guideCFrame * CFrame.new(0, 3, 0), Enum.Material.ForceField, Color3.fromRGB(120, 220, 140), false)
	anchor.Transparency = 1
	CollectionService:AddTag(anchor, "NPC")
	CollectionService:AddTag(anchor, "QuestGiver")
	WorldFacilityLabelGenerator.Build(parent, guideCFrame * CFrame.new(0, 7.5, 0), {
		Title = "Survivor Guide",
		Subtitle = "First Survival Steps",
		AccentColor = Color3.fromRGB(194, 153, 88),
		Width = 13,
		MaxDistance = 58,
	})
end

local function buildWorkbench(parent: Instance, origin: CFrame)
	local position = origin:PointToWorldSpace(WORKBENCH_LOCAL)
	local cf = CFrame.lookAt(position, origin:PointToWorldSpace(GUIDE_LOCAL))
	local model = Instance.new("Model")
	model.Name = "TutorialWorkbench"
	part(model, "Workbench", Vector3.new(8, 3, 3), cf * CFrame.new(0, 1.5, 0), Enum.Material.Metal, Color3.fromRGB(63, 67, 68))
	part(model, "ToolRack", Vector3.new(8, 4, 0.6), cf * CFrame.new(0, 4, 1.2), Enum.Material.WoodPlanks, Color3.fromRGB(78, 60, 43))
	for x = -2, 2 do
		part(model, "RackTool", Vector3.new(0.25, 1.8, 0.25), cf * CFrame.new(x * 1.2, 4.2, 0.8), Enum.Material.Metal, Color3.fromRGB(171, 131, 70), false)
	end
	local anchor = part(model, "FacilityAnchor", Vector3.new(5, 5, 3), cf * CFrame.new(0, 3, -2.5), Enum.Material.ForceField, HavenLayoutConfig.GetDistrict("Progression").accentColor, false)
	anchor.Transparency = 1
	anchor:SetAttribute("FacilityId", "UpgradeStation")
	CollectionService:AddTag(anchor, "HavenFacility")
	WorldFacilityLabelGenerator.Build(model, cf * CFrame.new(0, 6.7, 1.5), {
		Title = "Field Workbench",
		Subtitle = "Craft Field Hatchet",
		AccentColor = Color3.fromRGB(216, 142, 72),
		Width = 12,
		MaxDistance = 52,
	})
	model.Parent = parent
end

local function buildResourceAnchors(parent: Instance, origin: CFrame)
	local folder = Instance.new("Folder")
	folder.Name = "ResourceSpawnAnchors"
	for index, definition in RESOURCE_ANCHORS do
		local anchor = part(folder, `ResourceSpawnAnchor{index}`, Vector3.new(1, 1, 1), origin * CFrame.new(definition.Position), Enum.Material.SmoothPlastic, Color3.new(), false)
		anchor.Transparency = 1
		anchor:SetAttribute("ResourceId", definition.Id)
		CollectionService:AddTag(anchor, "TutorialResourceSpawn")
	end
	folder.Parent = parent
end

local function buildSpawn(parent: Instance, origin: CFrame, arrivalAnchorName: string)
	local spawnPosition = origin:PointToWorldSpace(SPAWN_LOCAL) + Vector3.new(0, 0.8, 0)
	local guidePosition = origin:PointToWorldSpace(GUIDE_LOCAL)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "TutorialSpawn"
	spawn.Size = Vector3.new(6, 0.4, 6)
	spawn.CFrame = CFrame.lookAt(spawnPosition, Vector3.new(guidePosition.X, spawnPosition.Y, guidePosition.Z))
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.AllowTeamChangeOnTouch = false
	spawn.Parent = parent
	local arrival = part(parent, arrivalAnchorName, Vector3.new(2, 0.2, 2), spawn.CFrame, Enum.Material.SmoothPlastic, Color3.new(), false)
	arrival.Transparency = 1
end

function BuildTutorialZone.Run()
	GeneratorKit.CleanupPrevious(Workspace, ROOT_NAME)
	local root = Instance.new("Model")
	root.Name = ROOT_NAME
	local origin = WorldMapConfig.RealOrigin.Tutorial
	local destination = assert(PortalDestinationConfig.Get("Tutorial"), "BuildTutorialZone: missing Tutorial destination")
	buildGround(root, origin)
	buildBoundary(root, origin)
	buildShelter(root, origin)
	buildGuide(root, origin)
	buildWorkbench(root, origin)
	buildResourceLandmarks(root, origin)
	buildResourceAnchors(root, origin)
	buildSpawn(root, origin, destination.arrivalAnchorName)
	root:SetAttribute("TotalFootprint", TOTAL_SIZE)
	root:SetAttribute("PlayableFootprint", PLAYABLE_SIZE)
	root.Parent = Workspace
	print("[BuildTutorialZone] Built 66x66 first-login survivor training base with natural containment, Guide, workbench, and resource anchors.")
end

return BuildTutorialZone
