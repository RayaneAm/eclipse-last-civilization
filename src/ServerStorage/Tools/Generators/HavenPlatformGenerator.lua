--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HavenLayoutConfig = require(ReplicatedStorage.Shared.Config.HavenLayoutConfig)
local GeneratorKit = require(script.Parent.GeneratorKit)

local HavenPlatformGenerator = {}
local FLOOR = Color3.fromRGB(72, 76, 82)
local PATH = Color3.fromRGB(105, 105, 99)
local CURB = Color3.fromRGB(46, 50, 56)

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	material: Enum.Material,
	color: Color3,
	collide: boolean?
): Part
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

local function path(parent: Instance, origin: CFrame, name: string, center: Vector3, size: Vector3)
	part(parent, name, size, origin * CFrame.new(center.X, 0.58, center.Z), Enum.Material.Pavement, PATH)
end

local function pathBetween(parent: Instance, origin: CFrame, name: string, a: Vector3, b: Vector3, width: number)
	local worldA = origin:PointToWorldSpace(a)
	local worldB = origin:PointToWorldSpace(b)
	local midpoint = (worldA + worldB) / 2 + Vector3.new(0, 0.58, 0)
	part(
		parent,
		name,
		Vector3.new(width, 1, (worldB - worldA).Magnitude),
		CFrame.lookAt(midpoint, Vector3.new(worldB.X, midpoint.Y, worldB.Z)),
		Enum.Material.Pavement,
		PATH
	)
end

local function repairPlate(parent: Instance, origin: CFrame, name: string, position: Vector3, size: Vector3, angle: number)
	part(parent, name, size, origin * CFrame.new(position.X, 1.1, position.Z) * CFrame.Angles(0, math.rad(angle), 0), Enum.Material.CorrodedMetal, Color3.fromRGB(73, 75, 73), false)
end

local function buildGuideForecourtSweep(parent: Instance, origin: CFrame)
	-- Two gently broken survivor-made branches frame, but never cross, the
	-- dominant sixteen-stud central arrival lane.
	local guideCenters = {
		Vector3.new(7, 0, 98),
		Vector3.new(13, 0, 94),
		Vector3.new(19, 0, 89),
		HavenLayoutConfig.GUIDE_LOCAL_POSITION,
	}
	for index = 1, #guideCenters - 1 do
		pathBetween(parent, origin, `GuideForecourtSweep{index}`, guideCenters[index], guideCenters[index + 1], 7 + index)
	end
	local baseCenters = {
		Vector3.new(-7, 0, 98),
		Vector3.new(-13, 0, 94),
		Vector3.new(-20, 0, 89),
		HavenLayoutConfig.BASE_GATE_LOCAL_POSITION,
	}
	for index = 1, #baseCenters - 1 do
		local name = if index == #baseCenters - 1 then "BaseApproach" else `BaseForecourtSweep{index}`
		pathBetween(parent, origin, name, baseCenters[index], baseCenters[index + 1], 7 + index)
	end
	repairPlate(parent, origin, "ArrivalRepairPlate1", Vector3.new(-3.5, 0, 102), Vector3.new(5, 0.16, 7), -7)
	repairPlate(parent, origin, "ArrivalRepairPlate2", Vector3.new(3.7, 0, 94), Vector3.new(4.5, 0.16, 6), 8)
	repairPlate(parent, origin, "ArrivalRepairPlate3", Vector3.new(-3, 0, 86), Vector3.new(5, 0.16, 6), 4)
end

local function buildCheckpoint(parent: Instance, origin: CFrame)
	local checkpoint = Instance.new("Model")
	checkpoint.Name = "ArrivalCheckpoint"
	path(checkpoint, origin, "ArrivalTerrace", Vector3.new(0, 0, 104), Vector3.new(34, 1, 18))
	for _, x in { -15, 15 } do
		part(
			checkpoint,
			"CanopyPost",
			Vector3.new(1, 8, 1),
			origin * CFrame.new(x, 4.5, 110),
			Enum.Material.Metal,
			CURB
		)
	end
	part(
		checkpoint,
		"CheckpointCanopy",
		Vector3.new(32, 0.8, 8),
		origin * CFrame.new(0, 8.7, 110),
		Enum.Material.Metal,
		Color3.fromRGB(52, 57, 64)
	)
	part(
		checkpoint,
		"HavenInsignia",
		Vector3.new(8, 0.25, 3),
		origin * CFrame.new(0, 8.15, 105.9) * CFrame.Angles(math.rad(90), 0, 0),
		Enum.Material.DiamondPlate,
		Color3.fromRGB(150, 128, 82),
		false
	)
	local board = part(
		checkpoint,
		"ArrivalSign",
		Vector3.new(13, 5, 0.4),
		origin * CFrame.new(-9, 4.8, 109.4),
		Enum.Material.Metal,
		Color3.fromRGB(30, 34, 40),
		false
	)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(650, 250)
	gui.LightInfluence = 0.3
	gui.MaxDistance = 75
	gui.Parent = board
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(232, 222, 198)
	text.Text = "SURVIVOR HAVEN\nBASE  ↖    MAIN STREET  ↑"
	text.Parent = gui
	for _, x in { -15, 15 } do
		local lamp = part(
			checkpoint,
			"AmberCheckpointLamp",
			Vector3.new(0.8, 1.1, 0.8),
			origin * CFrame.new(x, 7.3, 106),
			Enum.Material.Neon,
			Color3.fromRGB(215, 155, 78),
			false
		)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 192, 120)
		light.Brightness = 0.8
		light.Range = 14
		light.Parent = lamp
	end
	for _, x in { -15, 15 } do
		part(
			checkpoint,
			"SideLuggage",
			Vector3.new(3.2, 1.7, 2),
			origin * CFrame.new(x, 1.9, 100),
			Enum.Material.WoodPlanks,
			Color3.fromRGB(86, 68, 49)
		)
	end
	checkpoint.Parent = parent
end

function HavenPlatformGenerator.Build(parent: Instance, origin: CFrame): { Model: Model, PlazaCenter: CFrame }
	GeneratorKit.CleanupPrevious(parent, "HavenPlatform")
	local model = Instance.new("Model")
	model.Name = "HavenPlatform"
	part(
		model,
		"SettlementFoundation",
		Vector3.new(160, 3, 160),
		origin * CFrame.new(0, -1.5, 38),
		Enum.Material.Slate,
		Color3.fromRGB(55, 60, 67)
	)
	part(
		model,
		"SettlementSurface",
		Vector3.new(156, 1, 156),
		origin * CFrame.new(0, 0.1, 38),
		Enum.Material.Asphalt,
		FLOOR
	)
	-- Authored navigation spine and service pockets.
	path(model, origin, "ArrivalLane", Vector3.new(0, 0, 91), Vector3.new(16, 1, 38))
	path(model, origin, "SouthServiceSpine", Vector3.new(0, 0, 57), Vector3.new(14, 1, 36))
	path(model, origin, "CentralServiceSpine", Vector3.new(0, 0, 17), Vector3.new(14, 1, 48))
	path(model, origin, "ExpeditionApproach", Vector3.new(0, 0, -24), Vector3.new(18, 1, 36))
	-- Two offset service walks and staggered connectors keep every wall-backed
	-- entrance easy to reach without reading as three identical kiosk rows.
	path(model, origin, "WestServiceWalk", Vector3.new(-47, 0, 18), Vector3.new(10, 1, 72))
	path(model, origin, "EastServiceWalk", Vector3.new(45, 0, 23), Vector3.new(10, 1, 72))
	pathBetween(model, origin, "MarketBranch", Vector3.new(-6, 0, 47), Vector3.new(-47, 0, 45), 10)
	pathBetween(model, origin, "UpgradeBranch", Vector3.new(6, 0, 53), Vector3.new(45, 0, 50), 10)
	pathBetween(model, origin, "CosmeticBranch", Vector3.new(-6, 0, 18), Vector3.new(-47, 0, 15), 10)
	pathBetween(model, origin, "RewardsBranch", Vector3.new(6, 0, 21), Vector3.new(45, 0, 23), 10)
	pathBetween(model, origin, "LaboratoryBranch", Vector3.new(-6, 0, -7), Vector3.new(-47, 0, -11), 10)
	pathBetween(model, origin, "LeaderboardBranch", Vector3.new(6, 0, -6), Vector3.new(43, 0, -17), 10)
	buildGuideForecourtSweep(model, origin)
	-- Physical side and south retaining boundaries keep the settlement legible.
	local wallThickness = HavenLayoutConfig.PERIMETER_WALL_THICKNESS
	local wallHeight = HavenLayoutConfig.PERIMETER_WALL_HEIGHT
	for _, x in { HavenLayoutConfig.HAVEN_MIN_X, HavenLayoutConfig.HAVEN_MAX_X } do
		part(
			model,
			"SideRetainingWall",
			Vector3.new(wallThickness, wallHeight, 168),
			origin * CFrame.new(x, wallHeight / 2, 38),
			Enum.Material.Concrete,
			CURB
		)
	end
	part(
		model,
		"SouthRetainingWall",
		Vector3.new(168, wallHeight, wallThickness),
		origin * CFrame.new(0, wallHeight / 2, HavenLayoutConfig.HAVEN_MAX_Z),
		Enum.Material.Concrete,
		CURB
	)
	buildCheckpoint(model, origin)
	GeneratorKit.Finalize(model, "SettlementFoundation")
	model.Parent = parent
	return { Model = model, PlazaCenter = origin }
end

return HavenPlatformGenerator
