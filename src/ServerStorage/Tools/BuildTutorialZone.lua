--!strict
-- One-shot world-build orchestrator for the Tutorial Zone (Prompt 2): a
-- small, isolated, sealed area at its own independent hidden origin
-- (WorldMapConfig.RealOrigin.Tutorial) — "the Tutorial Zone should use the
-- same destination pattern" as the 4 real biomes. Builds only the greybox
-- container; gathering/crafting/equipping are entirely handled by the
-- already-existing ResourceService/InventoryService/CraftingService and
-- ToolService — this file only builds the physical space they run inside.
--
-- Preferred: the ECLIPSE TOOLS Studio plugin's "Build Tutorial Zone" /
-- "Build Complete World" buttons (see plugin/), which call this same Run().
--
-- Command Bar fallback:
--
--   require(game:GetService("ServerStorage").Tools.BuildTutorialZone).Run()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WorldMapConfig = require(ReplicatedStorage.Shared.Config.WorldMapConfig)
local PortalDestinationConfig = require(ReplicatedStorage.Shared.Config.PortalDestinationConfig)
local HavenFacilityConfig = require(ReplicatedStorage.Shared.Config.HavenFacilityConfig)

local GeneratorKit = require(script.Parent.Generators.GeneratorKit)
local PortalDestinationGenerator = require(script.Parent.Generators.PortalDestinationGenerator)
local CivicBuildingGenerator = require(script.Parent.Generators.CivicBuildingGenerator)

local ROOT_NAME = "TutorialZone_Generated"
local GROUND_RADIUS = 55
local GROUND_THICKNESS = 4
local WALL_HEIGHT = 20
local WALL_THICKNESS = 3
local UPGRADE_STATION_ANGLE_DEGREES = 200 -- clear of the return portal (which sits along +X, angle 0) and the arrival platform at center

local function buildGround(parent: Instance, origin: CFrame)
	GeneratorKit.NewPart({
		Name = "TutorialGround",
		Size = Vector3.new(GROUND_THICKNESS, GROUND_RADIUS * 2, GROUND_RADIUS * 2),
		CFrame = origin * CFrame.new(0, -GROUND_THICKNESS / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Ground,
		Color = Color3.fromRGB(90, 100, 70),
		Shape = Enum.PartType.Cylinder,
		Parent = parent,
	})
end

-- A simple, fully-solid wall ring — no breaches, no gates. The return
-- portal is the intended (and only) way out, so this just needs to be
-- "impossible to exit except through the intended route" per the brief,
-- not an architectural showpiece like Haven's perimeter wall.
local function buildBoundary(parent: Instance, origin: CFrame)
	local model = Instance.new("Model")
	model.Name = "Boundary"

	local segments = 20
	local segmentWidth = (2 * math.pi * GROUND_RADIUS) / segments

	for i = 0, segments - 1 do
		local angleDeg = (i / segments) * 360
		local segmentCFrame = origin * CFrame.Angles(0, math.rad(angleDeg), 0) * CFrame.new(0, WALL_HEIGHT / 2, -GROUND_RADIUS)

		GeneratorKit.NewPart({
			Name = `BoundarySegment{i}`,
			Size = Vector3.new(segmentWidth * 1.02, WALL_HEIGHT, WALL_THICKNESS),
			CFrame = segmentCFrame,
			Material = Enum.Material.Rock,
			Color = Color3.fromRGB(70, 66, 62),
			Parent = model,
		})
	end

	model.Parent = parent
	return model
end

local function buildUpgradeStation(parent: Instance, origin: CFrame)
	local definition
	for _, entry in HavenFacilityConfig do
		if entry.id == "UpgradeStation" then
			definition = entry
			break
		end
	end
	assert(definition, `BuildTutorialZone: HavenFacilityConfig has no "UpgradeStation" entry`)

	local direction = WorldMapConfig.DirectionForAngle(math.rad(UPGRADE_STATION_ANGLE_DEGREES))
	local position = origin.Position + direction * (GROUND_RADIUS * 0.55)
	CivicBuildingGenerator.Build(parent, origin, definition, position)
end

local BuildTutorialZone = {}

function BuildTutorialZone.Run()
	GeneratorKit.CleanupPrevious(Workspace, ROOT_NAME)

	local root = Instance.new("Model")
	root.Name = ROOT_NAME

	local origin = WorldMapConfig.RealOrigin.Tutorial
	local destination = PortalDestinationConfig.Get("Tutorial")
	assert(destination, "BuildTutorialZone: PortalDestinationConfig has no \"Tutorial\" entry")

	buildGround(root, origin)
	buildBoundary(root, origin)
	buildUpgradeStation(root, origin)

	-- Correction pass: this used to hardcode the literal "PortalDestination"
	-- instead of the registered destination.id ("Tutorial") — that wrong id
	-- became the return portal's PortalId attribute, so ReturnPortalController
	-- sent "PortalDestination" to the server, which correctly rejected it
	-- (PortalDestinationConfig.Get("PortalDestination") is nil) as
	-- "UnknownPortal". Defensive cleanup for any stale copy from that old
	-- bug — GeneratorKit.CleanupPrevious(Workspace, ROOT_NAME) above already
	-- wipes the entire previous root every rebuild, so this is redundant in
	-- practice, but kept for certainty and as a record of the fix.
	GeneratorKit.CleanupPrevious(root, "PortalDestination")

	PortalDestinationGenerator.Build(root, {
		id = destination.id,
		displayName = destination.displayName,
		realOrigin = origin,
		arrivalAnchorName = destination.arrivalAnchorName,
		returnAnchorName = destination.returnAnchorName,
		accentColor = Color3.fromRGB(140, 110, 255),
	})

	root.Parent = Workspace

	print("[BuildTutorialZone] Built the Tutorial Zone: ground, boundary, Upgrade Station, arrival platform, return portal. Re-run any time to regenerate.")
end

return BuildTutorialZone
