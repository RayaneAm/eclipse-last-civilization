--!strict
-- One-shot authored Survivor Haven world build. Safe to re-run.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local BiomeConfig = require(ReplicatedStorage.Shared.Config.BiomeConfig)
local HavenLayoutConfig = require(ReplicatedStorage.Shared.Config.HavenLayoutConfig)
local WorldMapConfig = require(ReplicatedStorage.Shared.Config.WorldMapConfig)
local GeneratorKit = require(script.Parent.Generators.GeneratorKit)
local HavenPlatformGenerator = require(script.Parent.Generators.HavenPlatformGenerator)
local EclipseCoreGenerator = require(script.Parent.Generators.EclipseCoreGenerator)
local GateGenerator = require(script.Parent.Generators.GateGenerator)
local ColosseumWallGenerator = require(script.Parent.Generators.ColosseumWallGenerator)
local ExpeditionBarrierGenerator = require(script.Parent.Generators.ExpeditionBarrierGenerator)
local ExpeditionDistrictGenerator = require(script.Parent.Generators.ExpeditionDistrictGenerator)
local WorldFacilityLabelGenerator = require(script.Parent.Generators.WorldFacilityLabelGenerator)

local BuildSurvivorHaven = {}
local ROOT_NAME = "SurvivorHaven_Generated"
local ORIGIN = WorldMapConfig.WORLD_ORIGIN

local function buildSpawns(parent: Instance): SpawnLocation
	local mainRoute = ORIGIN:PointToWorldSpace(Vector3.new(0, 0, HavenLayoutConfig.GUIDE_LOCAL_POSITION.Z - 12))
	local center = ORIGIN:PointToWorldSpace(HavenLayoutConfig.SPAWN_LOCAL_POSITION)
	local primary: SpawnLocation? = nil
	for index, x in HavenLayoutConfig.SPAWN_OFFSETS_X do
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = if index == 3 then "HavenSpawn" else `HavenSpawn{index}`
		spawn.Size = Vector3.new(HavenLayoutConfig.SPAWN_PAD_SIZE, 0.4, HavenLayoutConfig.SPAWN_PAD_SIZE)
		local spawnPosition = center + Vector3.new(x, HavenLayoutConfig.SPAWN_SURFACE_HEIGHT + 0.2, 0)
		spawn.CFrame = CFrame.lookAt(spawnPosition, Vector3.new(mainRoute.X, spawnPosition.Y, mainRoute.Z))
		spawn.Transparency = 1
		spawn.CanCollide = false
		spawn.Anchored = true
		spawn.Neutral = true
		spawn.AllowTeamChangeOnTouch = false
		spawn.Parent = parent
		if index == 3 then
			primary = spawn
		end
	end
	local arrivalAnchor = GeneratorKit.NewPart({
		Name = "HavenArrivalAnchor",
		Size = Vector3.new(2, 0.2, 2),
		CFrame = CFrame.lookAt(
			center + Vector3.new(0, HavenLayoutConfig.SPAWN_SURFACE_HEIGHT + 0.2, 0),
			Vector3.new(mainRoute.X, HavenLayoutConfig.SPAWN_SURFACE_HEIGHT + 0.2, mainRoute.Z)
		),
		Transparency = 1,
		CanCollide = false,
		Parent = parent,
	})
	arrivalAnchor.CanTouch = false
	return assert(primary, "BuildSurvivorHaven: center Haven spawn was not created")
end

local function buildBaseGate(parent: Instance)
	local cf = HavenLayoutConfig.CFrameFacing(
		ORIGIN,
		HavenLayoutConfig.BASE_GATE_LOCAL_POSITION,
		HavenLayoutConfig.BASE_GATE_APPROACH_LOCAL_POSITION
	)
	local model = Instance.new("Model")
	model.Name = "PersonalBaseTent"
	model:SetAttribute("IsSurvivalTent", true)
	GeneratorKit.NewPart({
		Name = "TentGroundPatch",
		Size = Vector3.new(22, 1, 16),
		CFrame = cf * CFrame.new(0, 0.5, 0),
		Material = Enum.Material.Ground,
		Color = Color3.fromRGB(73, 69, 57),
		Parent = model,
	})
	for _, x in { -8, 8 } do
		GeneratorKit.NewPart({
			Name = "TentFrontSupportPole",
			Size = Vector3.new(0.7, 6.4, 0.7),
			CFrame = cf * CFrame.new(x, 3.2, -6),
			Material = Enum.Material.Wood,
			Color = Color3.fromRGB(67, 53, 40),
			Parent = model,
		})
		GeneratorKit.NewPart({
			Name = "TentRearSupportPole",
			Size = Vector3.new(0.7, 6.4, 0.7),
			CFrame = cf * CFrame.new(x, 3.2, 6),
			Material = Enum.Material.Wood,
			Color = Color3.fromRGB(67, 53, 40),
			Parent = model,
		})
		local lamp = GeneratorKit.NewPart({
			Name = "TentRopeMarker",
			Size = Vector3.new(0.55, 0.55, 0.55),
			CFrame = cf * CFrame.new(x, 5.5, -6),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(210, 157, 87),
			CanCollide = false,
			Parent = model,
		})
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(242, 186, 111)
		light.Brightness = 0.35
		light.Range = 9
		light.Parent = lamp
	end
	GeneratorKit.NewPart({
		Name = "TentRidgePole",
		Size = Vector3.new(0.65, 0.65, 16),
		CFrame = cf * CFrame.new(0, 8.5, 0),
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(63, 50, 38),
		Parent = model,
	})
	GeneratorKit.NewPart({
		Name = "TentTarpLeft",
		Size = Vector3.new(10.5, 0.35, 16),
		CFrame = cf * CFrame.new(-4.2, 6.2, 0) * CFrame.Angles(0, 0, math.rad(-34)),
		Material = Enum.Material.Fabric,
		Color = Color3.fromRGB(77, 83, 63),
		Transparency = 0,
		CanCollide = false,
		Parent = model,
	})
	local energyDepth = GeneratorKit.NewPart({
		Name = "TentTarpRight",
		Size = Vector3.new(10.5, 0.35, 16),
		CFrame = cf * CFrame.new(4.2, 6.2, 0) * CFrame.Angles(0, 0, math.rad(34)),
		Material = Enum.Material.Fabric,
		Color = Color3.fromRGB(66, 73, 57),
		Transparency = 0,
		CanCollide = false,
		Parent = model,
	})
	energyDepth.CanTouch = false
	energyDepth.CanQuery = false
	local lantern = GeneratorKit.NewPart({
		Name = "FieldLantern",
		Size = Vector3.new(0.9, 1.3, 0.9),
		CFrame = cf * CFrame.new(0, 5.4, -2.8),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(107, 84, 54),
		CanCollide = false,
		Parent = model,
	})
	local portalLight = Instance.new("SurfaceLight")
	portalLight.Name = "TentLanternFill"
	portalLight.Face = Enum.NormalId.Front
	portalLight.Color = Color3.fromRGB(231, 178, 105)
	portalLight.Brightness = 0.3
	portalLight.Range = 10
	portalLight.Angle = 105
	portalLight.Shadows = true
	portalLight.Parent = lantern
	for _, supply in {
		{ Name = "TentBedroll", Size = Vector3.new(9, 1.1, 3.2), Offset = Vector3.new(0, 1.05, 2.2), Material = Enum.Material.Fabric, Color = Color3.fromRGB(91, 94, 77) },
		{ Name = "SurvivalBackpack", Size = Vector3.new(2.2, 3, 1.6), Offset = Vector3.new(-5.5, 1.8, 2), Material = Enum.Material.Fabric, Color = Color3.fromRGB(83, 69, 53) },
		{ Name = "StorageCrate", Size = Vector3.new(3, 2.2, 3), Offset = Vector3.new(5.2, 1.6, 2.8), Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(91, 67, 45) },
		{ Name = "UtilityBox", Size = Vector3.new(2.5, 1.4, 2.2), Offset = Vector3.new(-5.4, 1.2, -2.5), Material = Enum.Material.Metal, Color = Color3.fromRGB(65, 69, 67) },
	} do
		local prop = GeneratorKit.NewPart({
			Name = supply.Name,
			Size = supply.Size,
			CFrame = cf * CFrame.new(supply.Offset),
			Material = supply.Material,
			Color = supply.Color,
			CanCollide = false,
			Parent = model,
		})
		prop.CanTouch = false
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BaseTentPrompt"
	prompt.ObjectText = "Personal Base"
	prompt.ActionText = "Enter"
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	local terminal = GeneratorKit.NewPart({
		Name = "BaseTravelTerminal",
		Size = Vector3.new(2.4, 3.2, 2),
		CFrame = cf * CFrame.new(5.5, 2.1, -4.8),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(55, 63, 65),
		Parent = model,
	})
	prompt.Parent = terminal
	CollectionService:AddTag(terminal, "BaseGatePortal")
	GeneratorKit.NewPart({
		Name = "BaseTerminalStatus",
		Size = Vector3.new(0.8, 0.35, 0.18),
		CFrame = terminal.CFrame * CFrame.new(0, 0.7, -1.05),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(80, 181, 116),
		CanCollide = false,
		Parent = model,
	})
	WorldFacilityLabelGenerator.Build(model, cf * CFrame.new(0, 6, -7.3), {
		Title = "Personal Base",
		Subtitle = "Your Settlement",
		AccentColor = Color3.fromRGB(115, 202, 166),
		Width = 11,
		MaxDistance = 85,
	})
	GeneratorKit.NewPart({
		Name = "ReturnLanding_PersonalBase",
		Size = Vector3.new(6, 0.5, 6),
		CFrame = cf * CFrame.new(0, 0.8, -9),
		Material = Enum.Material.Pavement,
		Color = Color3.fromRGB(70, 95, 85),
		Transparency = 0.25,
		CanCollide = false,
		Parent = model,
	})
	model.Parent = parent
end

local function addCameraWaypoint(
	parent: Instance,
	order: number,
	position: Vector3,
	lookAt: Vector3,
	holdTime: number,
	segmentTime: number
)
	local waypoint = Instance.new("Part")
	waypoint.Name = `CameraWaypoint{order}`
	waypoint.Size = Vector3.one
	waypoint.Transparency = 1
	waypoint.Anchored = true
	waypoint.CanCollide = false
	waypoint.CFrame = CFrame.lookAt(position, lookAt)
	waypoint:SetAttribute("Order", order)
	waypoint:SetAttribute("HoldTime", holdTime)
	waypoint:SetAttribute("SegmentTime", segmentTime)
	CollectionService:AddTag(waypoint, "CameraWaypoint")
	waypoint.Parent = parent
end
local function buildCameraSweep(parent: Instance, spawn: SpawnLocation)
	local model = Instance.new("Model")
	model.Name = "CameraWaypoints"
	model.Parent = parent
	local spawnPos = spawn.Position
	local guide = ORIGIN:PointToWorldSpace(HavenLayoutConfig.GUIDE_LOCAL_POSITION) + Vector3.new(0, 4, 0)
	local base = ORIGIN:PointToWorldSpace(HavenLayoutConfig.BASE_GATE_LOCAL_POSITION) + Vector3.new(0, 7, 0)
	-- Spawn framing keeps both diagonal landmarks readable while the final view
	-- returns to the open centerline instead of turning the player toward one.
	addCameraWaypoint(model, 1, spawnPos + Vector3.new(-18, 14, 15), (guide + base) / 2, 0.7, 0)
	addCameraWaypoint(model, 2, spawnPos + Vector3.new(12, 9, 8), (guide + base) / 2, 0.7, 2.8)
	addCameraWaypoint(model, 3, spawnPos + Vector3.new(0, 6, 11), (guide + base) / 2, 0.4, 2.5)
end

function BuildSurvivorHaven.Run()
	GeneratorKit.CleanupPrevious(Workspace, ROOT_NAME)
	local root = Instance.new("Model")
	root.Name = ROOT_NAME
	root.Parent = Workspace
	local platform = HavenPlatformGenerator.Build(root, ORIGIN)
	ColosseumWallGenerator.Build(root, ORIGIN)
	ExpeditionDistrictGenerator.Build(root, ORIGIN)
	ExpeditionBarrierGenerator.Build(root, ORIGIN)
	EclipseCoreGenerator.Build(root, ORIGIN)
	for _, biome in BiomeConfig do
		local placement = HavenLayoutConfig.PortalPlacement(biome.id)
		local position = ORIGIN:PointToWorldSpace(placement.localPosition)
		local approach = ORIGIN:PointToWorldSpace(placement.approachLocalPosition)
		-- GateGenerator's established shrine convention uses local +Z as its
		-- open/approach side (new civic structures use local -Z).
		GateGenerator.Build(root, biome, CFrame.lookAt(position, position + (position - approach)))
	end
	buildBaseGate(root)
	local spawn = buildSpawns(root)
	buildCameraSweep(root, spawn)
	print(`[BuildSurvivorHaven] Built zoned Haven with {#HavenLayoutConfig.SPAWN_OFFSETS_X} integrated arrival spawns.`)
	return platform.Model
end
return BuildSurvivorHaven
