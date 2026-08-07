--!strict
-- One-shot world-build orchestrator for Survivor Haven. This is NOT part of
-- the runtime game — it lives in ServerStorage.Tools (synced via Rojo so
-- it's git-tracked and editable in VSCode, but ServerStorage never
-- auto-executes anything) and only runs when deliberately triggered.
--
-- Preferred: the ECLIPSE TOOLS Studio plugin's "Build Survivor Haven" /
-- "Build Complete World" buttons (see plugin/), which call this same Run()
-- via PluginBuildRunner — no building logic is duplicated there.
--
-- Command Bar fallback (kept only as a fallback, not the primary workflow):
--
--   require(game:GetService("ServerStorage").Tools.BuildSurvivorHaven).Run()
--
-- Exports Run() rather than executing at module-load time because
-- require() caches its result per Instance — calling require() a second
-- time in the same session without a file change would silently do nothing.
-- Calling .Run() explicitly re-executes every time, which the plugin relies
-- on for repeated button clicks.
--
-- Safe to re-run any time: the whole SurvivorHaven_Generated model is wiped
-- and rebuilt, but each sub-generator only touches its own named model, so
-- anything a builder renamed out of the generated namespace (see
-- architecture decision #7 in the Prompt 1 plan) survives untouched.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BiomeConfig = require(ReplicatedStorage.Shared.Config.BiomeConfig)
local WorldMapConfig = require(ReplicatedStorage.Shared.Config.WorldMapConfig)
local HavenLayoutConfig = require(ReplicatedStorage.Shared.Config.HavenLayoutConfig)
local HavenFacilityConfig = require(ReplicatedStorage.Shared.Config.HavenFacilityConfig)

local GeneratorKit = require(script.Parent.Generators.GeneratorKit)
local HavenPlatformGenerator = require(script.Parent.Generators.HavenPlatformGenerator)
local EclipseCoreGenerator = require(script.Parent.Generators.EclipseCoreGenerator)
local GateGenerator = require(script.Parent.Generators.GateGenerator)
local LeaderboardHallGenerator = require(script.Parent.Generators.LeaderboardHallGenerator)
local PlazaDetailGenerator = require(script.Parent.Generators.PlazaDetailGenerator)
local ColosseumWallGenerator = require(script.Parent.Generators.ColosseumWallGenerator)
local ExpeditionBarrierGenerator = require(script.Parent.Generators.ExpeditionBarrierGenerator)

local ROOT_NAME = "SurvivorHaven_Generated"
local ORIGIN = WorldMapConfig.WORLD_ORIGIN
local PLAZA_LAMP_RADIUS = 45
local PLAZA_LAMP_COUNT = 6

-- Portal Expedition Zone rework: names used by the old rectangular-gate
-- depth-illusion system (PortalTeaserGenerator.luau, deleted, and
-- GateGenerator.buildVistaTeaser, removed) that could still be sitting
-- somewhere in Workspace from a Studio session that predates this rework.
-- The normal rebuild path already handles this for free (the whole
-- SurvivorHaven_Generated root is destroyed and rebuilt below, old Gate_*
-- models included), but this sweep is a defensive extra pass so nothing
-- from an older, unmanaged build state can survive.
local OBSOLETE_PORTAL_TEASER_PROP_NAMES = { "DistantSilhouette", "DepthHaze", "TeaserSeal", "VistaTeaser" }

local function sweepObsoletePortalTeaserProps()
	local removed = 0
	for _, descendant in Workspace:GetDescendants() do
		if table.find(OBSOLETE_PORTAL_TEASER_PROP_NAMES, descendant.Name) then
			descendant:Destroy()
			removed += 1
		end
	end
	print(`[BuildSurvivorHaven] Portal-zone cleanup completed: removed {removed} obsolete preview prop(s).`)
end

local function buildPlazaLamps(parent: Instance, plazaCenter: CFrame)
	local lampsModel = Instance.new("Model")
	lampsModel.Name = "PlazaLamps"

	for i = 0, PLAZA_LAMP_COUNT - 1 do
		local angle = (i / PLAZA_LAMP_COUNT) * math.pi * 2
		local lampCFrame = plazaCenter * CFrame.new(math.cos(angle) * PLAZA_LAMP_RADIUS, 0, math.sin(angle) * PLAZA_LAMP_RADIUS)

		GeneratorKit.NewPart({
			Name = `LampPost{i}`,
			Size = Vector3.new(0.6, 8, 0.6),
			CFrame = lampCFrame * CFrame.new(0, 4, 0),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(50, 48, 46),
			Parent = lampsModel,
		})

		local globe = GeneratorKit.NewPart({
			Name = `LampGlobe{i}`,
			Size = Vector3.new(1.4, 1.4, 1.4),
			CFrame = lampCFrame * CFrame.new(0, 8.3, 0),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255, 214, 160),
			Shape = Enum.PartType.Ball,
			CanCollide = false,
			Parent = lampsModel,
		})

		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 200, 140)
		light.Brightness = 2.5
		light.Range = 20
		light.Parent = globe
		CollectionService:AddTag(light, "AmbientFlicker")
	end

	lampsModel.Parent = parent
	return lampsModel
end

-- Survivor Haven redesign Phase 1: spawn moved from dead-center (radius 0,
-- under the canopy) to the hub's far edge (angle 180deg, radius 110) —
-- a real off-center position again, so it goes back to orienting by looking
-- at plazaCenter.Position (origin), which now gives a valid, non-degenerate
-- look vector and naturally faces the player north, toward the portal arc.
--
-- Phase 2: the single floating neon pad is replaced by SPAWN_POINT_COUNT
-- flush, invisible spawn points fanned across a shallow arc on top of the
-- new Arrival Terrace (see HavenPlatformGenerator.buildArrivalTerrace,
-- whose radius/width must stay wide enough to contain this arc). Multiple
-- players can spawn at once without stacking, and there's no visible
-- default pad since each point matches the terrace's own floor color
-- instead of standing out from it. The center point keeps the exact
-- SPAWN_ANGLE_DEGREES/SPAWN_RADIUS position Phase 1 locked in.
local SPAWN_ARC_SPAN_DEGREES = 36
local SPAWN_POINT_COUNT = 5
local SPAWN_MIDDLE_INDEX = (SPAWN_POINT_COUNT - 1) // 2

local function buildSpawn(parent: Instance, plazaCenter: CFrame): SpawnLocation
	local spawnsModel = Instance.new("Model")
	spawnsModel.Name = "HavenSpawns"

	local primarySpawn: SpawnLocation? = nil
	for i = 0, SPAWN_POINT_COUNT - 1 do
		local t = i / (SPAWN_POINT_COUNT - 1) - 0.5
		local angleDegrees = HavenLayoutConfig.SPAWN_ANGLE_DEGREES + t * SPAWN_ARC_SPAN_DEGREES
		local direction = WorldMapConfig.DirectionForAngle(math.rad(angleDegrees))
		local position = plazaCenter.Position + direction * HavenLayoutConfig.SPAWN_RADIUS + Vector3.new(0, 0.5, 0)

		local spawn = Instance.new("SpawnLocation")
		spawn.Name = `HavenSpawn{i}`
		spawn.Size = Vector3.new(8, 0.4, 8)
		spawn.CFrame = CFrame.new(position, plazaCenter.Position)
		spawn.Material = Enum.Material.Concrete
		spawn.Color = Color3.fromRGB(100, 96, 92)
		spawn.Transparency = 1
		spawn.CanCollide = true
		spawn.Anchored = true
		spawn.Duration = 0
		spawn.Neutral = true
		spawn.TopSurface = Enum.SurfaceType.Smooth
		spawn.Parent = spawnsModel

		if i == SPAWN_MIDDLE_INDEX then
			primarySpawn = spawn
		end
	end

	spawnsModel.Parent = parent
	assert(primarySpawn, "BuildSurvivorHaven: buildSpawn produced no primary spawn point")
	return primarySpawn
end

-- Leaderboard is a "bespoke" facility (see HavenFacilityConfig) — built
-- directly here rather than through BuildHavenDistricts' generic loop.
-- Phase 1 correction: repositioned to match HavenFacilityConfig's
-- "Leaderboards" entry (angleDegrees=-160, radius=85) — closest-to-spawn on
-- the right, verified clear of Base Gate/Survivor Market by real bounding
-- circles, not just an angle/radius guess. Kept as its own constants here
-- since the physical build call lives in this file, not the generic
-- facility loop.
local LEADERBOARD_RADIUS = 85
local LEADERBOARD_ANGLE_DEGREES = -160

local function buildLeaderboard(parent: Instance, plazaCenter: CFrame)
	-- Spawn polish pass: replaced CivicBuildingGenerator.Build (a generic
	-- kiosk skeleton with a small monument in front of it) with a dedicated
	-- LeaderboardHallGenerator — a wide, always-legible ranking wall, not a
	-- building. Accent color still borrowed from the Progression district
	-- (where the Leaderboards facility is logically categorized in
	-- HavenFacilityConfig) for continuity, even though the hall itself sits
	-- near the Central Arrival Core, not the district ring.
	local progressionDistrict = HavenLayoutConfig.GetDistrict("Progression")
	local direction = WorldMapConfig.DirectionForAngle(math.rad(LEADERBOARD_ANGLE_DEGREES))
	local position = plazaCenter.Position + direction * LEADERBOARD_RADIUS
	LeaderboardHallGenerator.Build(parent, plazaCenter, position, progressionDistrict.accentColor)
end

-- Survivor Haven redesign Phase 1 reserved this footprint as a pure
-- blockout. Phase 4A turns it into the real personal-base travel point —
-- same footprint/silhouette, now tagged (mirroring TutorialPortal's
-- tag-driven pattern, not HavenFacility's hologram-panel pattern, since
-- this is a travel point, not a shop) and given a ProximityPrompt.
-- BaseGateController (client) calls the EXISTING RequestPortalTravel remote
-- with portalId "PersonalBase_<own userId>" — no new remote needed.
--
-- Phase 1 correction: enlarged from an 8-wide toy frame (the "tiny floating
-- sign" complaint) to an 18-wide reserved footprint — still well under a
-- biome gate's own ~96-stud wall-breach scale so it never competes with the
-- portals, but now a real reserved structure rather than a token marker.
-- Same angle as Leaderboard Hall (both "closest to spawn" on the right,
-- mirroring Quest Giver/Tutorial Portal on the left), pushed to a radius
-- verified clear of the Hall's own enlarged footprint.
local BASE_GATE_RADIUS = 122
local BASE_GATE_ANGLE_DEGREES = -160
local BASE_GATE_WIDTH = 18
local BASE_GATE_HEIGHT = 14

local function buildBaseGate(parent: Instance, plazaCenter: CFrame)
	local direction = WorldMapConfig.DirectionForAngle(math.rad(BASE_GATE_ANGLE_DEGREES))
	local position = plazaCenter.Position + direction * BASE_GATE_RADIUS
	local gateCFrame = CFrame.new(position, plazaCenter.Position)

	local model = Instance.new("Model")
	model.Name = "BaseGate"

	for _, side in { -1, 1 } do
		GeneratorKit.NewPart({
			Name = if side < 0 then "PylonLeft" else "PylonRight",
			Size = Vector3.new(2.2, BASE_GATE_HEIGHT, 2.2),
			CFrame = gateCFrame * CFrame.new(side * BASE_GATE_WIDTH / 2, BASE_GATE_HEIGHT / 2, 0),
			Material = Enum.Material.Concrete,
			Color = Color3.fromRGB(80, 78, 82),
			Parent = model,
		})
	end

	GeneratorKit.NewPart({
		Name = "Lintel",
		Size = Vector3.new(BASE_GATE_WIDTH + 3, 1.6, 2.2),
		CFrame = gateCFrame * CFrame.new(0, BASE_GATE_HEIGHT, 0),
		Material = Enum.Material.Concrete,
		Color = Color3.fromRGB(80, 78, 82),
		Parent = model,
	})

	local marker = GeneratorKit.NewPart({
		Name = "GateMembrane",
		Size = Vector3.new(BASE_GATE_WIDTH - 1, BASE_GATE_HEIGHT - 1.5, 0.3),
		CFrame = gateCFrame * CFrame.new(0, BASE_GATE_HEIGHT / 2, 0),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(120, 220, 140),
		Transparency = 0.6,
		CanCollide = false,
		Parent = model,
	})

	-- Phase 4A: real interactive travel point, mirroring TutorialPortal's
	-- tag-driven pattern (BaseGateController reads this tag client-side,
	-- same convention as TutorialPortalController).
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BaseGatePrompt"
	prompt.ObjectText = "Personal Base"
	prompt.ActionText = "Enter"
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = marker
	CollectionService:AddTag(marker, "BaseGatePortal")

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "BaseGateLabel"
	billboard.Size = UDim2.fromOffset(220, 40)
	billboard.StudsOffset = Vector3.new(0, 2, 0)
	billboard.MaxDistance = 140
	billboard.LightInfluence = 0
	billboard.Parent = marker

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = "BASE GATE"
	label.Parent = billboard

	-- Haven-side landing spot for returning FROM a personal base — resolved
	-- by name (Workspace:FindFirstChild(..., true)) by PortalService,
	-- exactly like every other destination's returnAnchorName. One shared
	-- spot for all base returns, owner or visitor (see
	-- PortalDestinationConfig.luau's personalBaseDestination).
	GeneratorKit.NewPart({
		Name = "ReturnLanding_PersonalBase",
		Size = Vector3.new(6, 0.5, 6),
		CFrame = gateCFrame * CFrame.new(0, 0.25, 12),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(120, 220, 140),
		Transparency = 0.5,
		CanCollide = false,
		Parent = model,
	})

	model.Parent = parent
	return model
end

local function addCameraWaypoint(parent: Instance, order: number, position: Vector3, lookAt: Vector3, holdTime: number?, segmentTime: number?)
	local part = Instance.new("Part")
	part.Name = `CameraWaypoint{order}`
	part.Size = Vector3.new(1, 1, 1)
	part.Transparency = 1
	part.CanCollide = false
	part.Anchored = true
	part.CFrame = CFrame.new(position, lookAt)
	part:SetAttribute("Order", order)
	if holdTime then
		part:SetAttribute("HoldTime", holdTime)
	end
	if segmentTime then
		part:SetAttribute("SegmentTime", segmentTime)
	end
	CollectionService:AddTag(part, "CameraWaypoint")
	part.Parent = parent
	return part
end

-- Survivor Haven redesign Phase 1: re-composed for the amphitheater layout
-- (was a symmetric full-ring sweep, tuned to look reasonable from any
-- angle — now the portal arc sits north and the facility clusters sit
-- west/east, so the sweep is deliberately redirected to actually show that
-- content, not just linearly rescaled). Still 4 camera moves total —
-- "short," "not disorienting," "not overly dramatic" per the original
-- brief. These are a starting composition to eyeball in Studio, not final.
local function buildCameraSweep(parent: Instance, plazaCenter: CFrame, coreCFrame: CFrame, spawnCFrame: CFrame)
	local waypointsModel = Instance.new("Model")
	waypointsModel.Name = "CameraWaypoints"
	waypointsModel.Parent = parent

	local corePos = coreCFrame.Position
	local plazaPos = plazaCenter.Position
	local spawnPos = spawnCFrame.Position

	local questGiverAngle
	for _, facility in HavenFacilityConfig do
		if facility.id == "QuestGiver" then
			questGiverAngle = facility.angleDegrees
			break
		end
	end
	assert(questGiverAngle, `BuildSurvivorHaven: HavenFacilityConfig has no "QuestGiver" entry`)
	local guidanceDirection = WorldMapConfig.DirectionForAngle(math.rad(questGiverAngle))

	-- 1: wide establishing shot from above and behind spawn (south), taking
	-- in the whole compact hub — plaza, both clusters, and the arc ahead.
	addCameraWaypoint(waypointsModel, 1, corePos + Vector3.new(0, 145, 130), plazaPos, 1.4)
	-- 2: sweep down close past the Eclipse Core (core-relative, unaffected by
	-- the layout redesign).
	addCameraWaypoint(waypointsModel, 2, corePos + Vector3.new(5, 6, 48), corePos, 1, 4)
	-- 3: pan across the portal arc specifically (north, slightly west-biased
	-- for an angled view of the clustered gates instead of a flat frontal one).
	addCameraWaypoint(waypointsModel, 3, plazaPos + Vector3.new(-40, 45, -130), plazaPos, 0.8, 4.5)
	-- 4: sweep past the right-hand facility cluster (Leaderboard/Base Gate),
	-- briefly framing it before settling on spawn.
	addCameraWaypoint(waypointsModel, 4, plazaPos + Vector3.new(100, 55, 40), plazaPos, 0.6, 4)
	-- 5: settle behind the player's spawn point, gesturing toward the
	-- Tutorial Portal / Quest Giver (where the first quest is) rather than
	-- dead ahead — guides the player without a UI marker, per "guide players
	-- naturally".
	addCameraWaypoint(waypointsModel, 5, spawnPos + Vector3.new(0, 6, 10), plazaPos + guidanceDirection * 20, 0, 3)
end

local BuildSurvivorHaven = {}

function BuildSurvivorHaven.Run()
	sweepObsoletePortalTeaserProps()
	GeneratorKit.CleanupPrevious(Workspace, ROOT_NAME)

	local root = Instance.new("Model")
	root.Name = ROOT_NAME

	local platform = HavenPlatformGenerator.Build(root, ORIGIN)
	ColosseumWallGenerator.Build(root, platform.PlazaCenter)
	local core = EclipseCoreGenerator.Build(root, platform.PlazaCenter)

	local gatesFolder = Instance.new("Folder")
	gatesFolder.Name = "Gates"
	gatesFolder.Parent = root

	local gateAngleSummary = {}
	for _, biome in BiomeConfig do
		local anchorCFrame = platform.GateAnchors[biome.id]
		assert(anchorCFrame, `BuildSurvivorHaven: HavenPlatformGenerator produced no gate anchor for "{biome.id}"`)
		GateGenerator.Build(gatesFolder, biome, anchorCFrame)
		table.insert(gateAngleSummary, `{biome.name}={HavenLayoutConfig.GateAngleForOrder(biome.order)}deg`)
	end
	print(`[BuildSurvivorHaven] Active portal angles: {table.concat(gateAngleSummary, ", ")}`)
	print(`[BuildSurvivorHaven] Biome threshold dressing built for all {#BiomeConfig} portals.`)

	ExpeditionBarrierGenerator.Build(root, platform.PlazaCenter)

	buildPlazaLamps(root, platform.PlazaCenter)
	buildLeaderboard(root, platform.PlazaCenter)
	buildBaseGate(root, platform.PlazaCenter)
	PlazaDetailGenerator.Build(root, platform.PlazaCenter)
	local spawn = buildSpawn(root, platform.PlazaCenter)
	buildCameraSweep(root, platform.PlazaCenter, core.CoreCFrame, spawn.CFrame)

	root.Parent = Workspace

	print(
		`[BuildSurvivorHaven] Built Survivor Haven: platform, Eclipse Core, {#BiomeConfig} biome gates, `
			.. `{#CollectionService:GetTagged("CameraWaypoint")} camera waypoints. Re-run any time to regenerate.`
	)
end

return BuildSurvivorHaven
