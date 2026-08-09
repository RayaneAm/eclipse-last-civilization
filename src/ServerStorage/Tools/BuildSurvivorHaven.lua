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
local GateGenerator = require(script.Parent.Generators.GateGenerator)
local ColosseumWallGenerator = require(script.Parent.Generators.ColosseumWallGenerator)
local ExpeditionBarrierGenerator = require(script.Parent.Generators.ExpeditionBarrierGenerator)
local ExpeditionDistrictGenerator = require(script.Parent.Generators.ExpeditionDistrictGenerator)
local SurvivorTentGenerator = require(script.Parent.Generators.SurvivorTentGenerator)
local DailyQuestBoardGenerator = require(script.Parent.Generators.DailyQuestBoardGenerator)

local BuildSurvivorHaven = {}
local ROOT_NAME = "SurvivorHaven_Generated"
local ORIGIN = WorldMapConfig.WORLD_ORIGIN

local function buildSpawns(parent: Instance): SpawnLocation
	local mainRoute = ORIGIN:PointToWorldSpace(Vector3.new(0, 0, HavenLayoutConfig.CAMP_CIRCLE_LOCAL_POSITION.Z - 12))
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

-- The Personal Base entrance. All geometry lives in SurvivorTentGenerator;
-- this only resolves which way the camp faces. The tent keeps the
-- BaseGatePortal prompt and the ReturnLanding_PersonalBase pad, so the travel
-- contract is unchanged by the visual redesign.
local function buildBaseCamp(parent: Instance)
	SurvivorTentGenerator.Build(
		parent,
		HavenLayoutConfig.CFrameFacing(
			ORIGIN,
			HavenLayoutConfig.BASE_GATE_LOCAL_POSITION,
			HavenLayoutConfig.BASE_GATE_APPROACH_LOCAL_POSITION
		)
	)
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
	local camp = ORIGIN:PointToWorldSpace(HavenLayoutConfig.CAMP_CIRCLE_LOCAL_POSITION) + Vector3.new(0, 4, 0)
	local base = ORIGIN:PointToWorldSpace(HavenLayoutConfig.BASE_GATE_LOCAL_POSITION) + Vector3.new(0, 7, 0)
	-- Spawn framing keeps both diagonal landmarks readable while the final view
	-- returns to the open centerline instead of turning the player toward one.
	addCameraWaypoint(model, 1, spawnPos + Vector3.new(-18, 14, 15), (camp + base) / 2, 0.7, 0)
	addCameraWaypoint(model, 2, spawnPos + Vector3.new(12, 9, 8), (camp + base) / 2, 0.7, 2.8)
	addCameraWaypoint(model, 3, spawnPos + Vector3.new(0, 6, 11), (camp + base) / 2, 0.4, 2.5)
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
	-- The survivor task board stands where the Eclipse Relay pedestal used to.
	DailyQuestBoardGenerator.Build(
		root,
		HavenLayoutConfig.CFrameFacing(
			ORIGIN,
			HavenLayoutConfig.NOTICE_BOARD_LOCAL_POSITION,
			HavenLayoutConfig.SPAWN_LOCAL_POSITION
		)
	)
	for _, biome in BiomeConfig do
		local placement = HavenLayoutConfig.PortalPlacement(biome.id)
		local position = ORIGIN:PointToWorldSpace(placement.localPosition)
		local approach = ORIGIN:PointToWorldSpace(placement.approachLocalPosition)
		-- GateGenerator's established shrine convention uses local +Z as its
		-- open/approach side (new civic structures use local -Z).
		GateGenerator.Build(root, biome, CFrame.lookAt(position, position + (position - approach)))
	end
	buildBaseCamp(root)
	local spawn = buildSpawns(root)
	buildCameraSweep(root, spawn)
	print(`[BuildSurvivorHaven] Built zoned Haven with {#HavenLayoutConfig.SPAWN_OFFSETS_X} integrated arrival spawns.`)
	return platform.Model
end
return BuildSurvivorHaven
