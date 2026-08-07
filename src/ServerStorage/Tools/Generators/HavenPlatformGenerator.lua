--!strict
-- Builds Survivor Haven's foundation: the plaza floor, a crenellated
-- perimeter wall with 4 gate breaches and 4 watchtowers, and paved paths
-- radiating from the plaza center out to each gate. Returns the anchor
-- CFrames the orchestrator hands to the other generators, so this is always
-- built first.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BiomeConfig = require(ReplicatedStorage.Shared.Config.BiomeConfig)
local WorldMapConfig = require(ReplicatedStorage.Shared.Config.WorldMapConfig)
local HavenLayoutConfig = require(ReplicatedStorage.Shared.Config.HavenLayoutConfig)
local GeneratorKit = require(script.Parent.GeneratorKit)

local PLAZA_RADIUS = WorldMapConfig.HAVEN_PLAZA_RADIUS
local PLAZA_THICKNESS = 8
local WALL_HEIGHT = 26
local WALL_THICKNESS = 5
local WALL_SEGMENTS = 32
local GATE_BREACH_DEGREES = WorldMapConfig.GATE_BREACH_DEGREES
local TOWER_RADIUS = 9

-- Phase 2: the floor is 3 concentric material zones (dais surround, main
-- walking area, outer ring near the wall) instead of one flat disc — see
-- buildPlazaFloor. Each zone is a smaller disc stacked slightly above the
-- previous one (same non-collide "cap" trick the old InlayRing/ArrivalPlate
-- pair already used), so the base part stays the sole collision surface.
local ZONE_A_OUTER_RADIUS = 36 -- matches CANOPY_PILLAR_RADIUS(32) + a few studs of margin
local ZONE_B_OUTER_RADIUS = 90
local WALL_TRIM_RADIUS = PLAZA_RADIUS - 2

-- Arrival Terrace (Phase 2): a real raised platform at the spawn end of the
-- Forward path instead of a lone floating SpawnLocation pad. Radius/angle
-- numbers here are read by BuildSurvivorHaven.buildSpawn too — keep them in
-- sync if either changes (same duplicated-constant pattern the Leaderboard/
-- Base Gate angle already uses across files).
local ARRIVAL_TERRACE_INNER_RADIUS = 92
local ARRIVAL_TERRACE_OUTER_RADIUS = 128
local ARRIVAL_TERRACE_WIDTH = 36
local ARRIVAL_TERRACE_HEIGHT = 1
local ARRIVAL_TERRACE_RAMP_DEPTH = 6

local HavenPlatformGenerator = {}

export type BuildResult = {
	Model: Model,
	PlazaCenter: CFrame,
	GateAnchors: { [string]: CFrame },
}

-- Sparse Metal trim seams across Zone B — enough to break up "one perfectly
-- uniform circle" without reading as a tile grid.
local ZONE_B_SEAM_COUNT = 8
local ZONE_B_SEAM_INNER_RADIUS = ZONE_A_OUTER_RADIUS
local ZONE_B_SEAM_OUTER_RADIUS = ZONE_B_OUTER_RADIUS - 4

local function buildZoneBSeams(parent: Instance, origin: CFrame)
	local seamModel = Instance.new("Model")
	seamModel.Name = "ZoneBSeams"

	local length = ZONE_B_SEAM_OUTER_RADIUS - ZONE_B_SEAM_INNER_RADIUS
	for i = 0, ZONE_B_SEAM_COUNT - 1 do
		local angleDeg = 22.5 + i * (360 / ZONE_B_SEAM_COUNT)
		GeneratorKit.NewPart({
			Name = `Seam{i}`,
			Size = Vector3.new(1.2, 0.1, length),
			CFrame = origin * CFrame.Angles(0, math.rad(angleDeg), 0) * CFrame.new(0, 0.4, -(ZONE_B_SEAM_INNER_RADIUS + length / 2)),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(52, 50, 54),
			CanCollide = false,
			Parent = seamModel,
		})
	end

	seamModel.Parent = parent
	return seamModel
end

-- A handful of irregular "survivor-built patch" repairs scattered across
-- Zone B — seeded so rebuilds are deterministic, per GeneratorKit's usual
-- rubble-scatter convention.
local ZONE_B_PATCH_COUNT = 4

local function buildZoneBPatches(parent: Instance, origin: CFrame)
	local patchModel = Instance.new("Model")
	patchModel.Name = "ZoneBPatches"

	local rng = GeneratorKit.Seeded(53)
	for i = 1, ZONE_B_PATCH_COUNT do
		local angleDeg = rng:NextNumber(0, 360)
		local radius = rng:NextNumber(ZONE_A_OUTER_RADIUS + 6, ZONE_B_OUTER_RADIUS - 8)
		local width = rng:NextNumber(2.5, 4.5)
		local depth = rng:NextNumber(2.5, 4.5)

		GeneratorKit.NewPart({
			Name = `Patch{i}`,
			Size = Vector3.new(width, 0.08, depth),
			CFrame = origin
				* CFrame.Angles(0, math.rad(angleDeg), 0)
				* CFrame.new(0, 0.4, -radius)
				* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0),
			Material = if i % 2 == 0 then Enum.Material.DiamondPlate else Enum.Material.Concrete,
			Color = Color3.fromRGB(70, 68, 66),
			CanCollide = false,
			Parent = patchModel,
		})
	end

	patchModel.Parent = parent
	return patchModel
end

local function buildPlazaFloor(parent: Instance, origin: CFrame)
	-- Base disc (collidable — every other layer below is a thin non-collide
	-- overlay riding on top of this one, so players always stand at y=0).
	GeneratorKit.NewPart({
		Name = "PlazaFloor",
		Size = Vector3.new(PLAZA_THICKNESS, PLAZA_RADIUS * 2, PLAZA_RADIUS * 2),
		CFrame = origin * CFrame.new(0, -PLAZA_THICKNESS / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(66, 64, 68),
		Shape = Enum.PartType.Cylinder,
		Parent = parent,
	})

	-- Zone C — Outer Ring: Concrete, with a 2-stud Metal trim border left
	-- showing at the very edge (the base disc peeking out beyond this one).
	GeneratorKit.NewPart({
		Name = "ZoneC_OuterRing",
		Size = Vector3.new(0.4, WALL_TRIM_RADIUS * 2, WALL_TRIM_RADIUS * 2),
		CFrame = origin * CFrame.new(0, 0.05, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Concrete,
		Color = Color3.fromRGB(98, 94, 88),
		Shape = Enum.PartType.Cylinder,
		CanCollide = false,
		Parent = parent,
	})

	-- Zone B — Mid Plaza: Cobblestone, the main walking surface.
	GeneratorKit.NewPart({
		Name = "ZoneB_MidPlaza",
		Size = Vector3.new(0.4, ZONE_B_OUTER_RADIUS * 2, ZONE_B_OUTER_RADIUS * 2),
		CFrame = origin * CFrame.new(0, 0.15, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Cobblestone,
		Color = Color3.fromRGB(96, 92, 88),
		Shape = Enum.PartType.Cylinder,
		CanCollide = false,
		Parent = parent,
	})

	buildZoneBSeams(parent, origin)
	buildZoneBPatches(parent, origin)

	-- Zone A — Central Ring: dark reinforced base with a restrained purple
	-- inlay band left visible at its outer edge (the ring between this disc
	-- and the smaller plain cap on top) — this is also where the dais
	-- (built by EclipseCoreGenerator) visually rises from.
	GeneratorKit.NewPart({
		Name = "ZoneA_CentralRing",
		Size = Vector3.new(0.4, ZONE_A_OUTER_RADIUS * 2, ZONE_A_OUTER_RADIUS * 2),
		CFrame = origin * CFrame.new(0, 0.25, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Basalt,
		Color = Color3.fromRGB(72, 58, 96),
		Shape = Enum.PartType.Cylinder,
		CanCollide = false,
		Parent = parent,
	})

	GeneratorKit.NewPart({
		Name = "ArrivalPlate",
		Size = Vector3.new(0.4, HavenLayoutConfig.CENTRAL_ARRIVAL_RADIUS * 2, HavenLayoutConfig.CENTRAL_ARRIVAL_RADIUS * 2),
		CFrame = origin * CFrame.new(0, 0.35, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Basalt,
		Color = Color3.fromRGB(40, 38, 42),
		Shape = Enum.PartType.Cylinder,
		CanCollide = false,
		Parent = parent,
	})
end

-- Low Metal curb trim along a path's edges — "raised borders" per the Phase
-- 2 brief. `pathCFrame` is already rotated to the path's bearing but not yet
-- offset outward (so `-radius` still measures distance from the plaza
-- center along the path).
local function buildPathCurbs(parent: Instance, pathCFrame: CFrame, width: number, length: number, innerRadius: number)
	for _, side in { -1, 1 } do
		GeneratorKit.NewPart({
			Name = if side < 0 then "CurbLeft" else "CurbRight",
			Size = Vector3.new(0.8, 0.5, length),
			CFrame = pathCFrame * CFrame.new(side * (width / 2 + 0.4), 0.7, -(innerRadius + length / 2)),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(64, 62, 66),
			Parent = parent,
		})
	end
end

-- A handful of embedded warm accent lights along a path — deliberately not a
-- centerline neon strip, just small practical fixtures set into the curb.
local function buildPathAccentLights(parent: Instance, pathCFrame: CFrame, width: number, innerRadius: number, length: number, count: number)
	for i = 1, count do
		local t = i / (count + 1)
		local dist = innerRadius + length * t
		local side = if i % 2 == 0 then 1 else -1

		local holder = GeneratorKit.NewPart({
			Name = `PathLight{i}`,
			Size = Vector3.new(0.5, 0.3, 0.5),
			CFrame = pathCFrame * CFrame.new(side * (width / 2 + 0.4), 0.95, -dist),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255, 200, 140),
			CanCollide = false,
			Parent = parent,
		})

		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 190, 130)
		light.Brightness = 1.2
		light.Range = 10
		light.Parent = holder
		CollectionService:AddTag(light, "AmbientFlicker")
	end
end

-- A short, widened stub where a path meets the central ring — softens the
-- sharp rectangular joint into something closer to a deliberate flare.
local function buildPathFlare(parent: Instance, pathCFrame: CFrame, width: number, innerRadius: number)
	GeneratorKit.NewPart({
		Name = "InnerFlare",
		Size = Vector3.new(width * 1.3, 0.3, 6),
		CFrame = pathCFrame * CFrame.new(0, 0.45, -(innerRadius + 3)),
		Material = Enum.Material.Pavement,
		Color = Color3.fromRGB(118, 114, 108),
		CanCollide = false,
		Parent = parent,
	})
end

-- Arrival Terrace: a raised, textured podium at the spawn end of the Forward
-- path with a wide, shallow 2-step ramp down to the main plaza — replaces
-- the bare ground the single floating spawn pad used to sit on. Actual
-- SpawnLocations are built by BuildSurvivorHaven.buildSpawn on top of this.
local function buildArrivalTerrace(parent: Instance, origin: CFrame)
	local model = Instance.new("Model")
	model.Name = "ArrivalTerrace"

	local terraceCFrame = origin * CFrame.Angles(0, math.rad(HavenLayoutConfig.SPAWN_ANGLE_DEGREES), 0)
	local terraceLength = ARRIVAL_TERRACE_OUTER_RADIUS - ARRIVAL_TERRACE_INNER_RADIUS
	local terraceCenterRadius = (ARRIVAL_TERRACE_INNER_RADIUS + ARRIVAL_TERRACE_OUTER_RADIUS) / 2

	GeneratorKit.NewPart({
		Name = "TerracePlatform",
		Size = Vector3.new(ARRIVAL_TERRACE_WIDTH, ARRIVAL_TERRACE_HEIGHT, terraceLength),
		CFrame = terraceCFrame * CFrame.new(0, ARRIVAL_TERRACE_HEIGHT / 2, -terraceCenterRadius),
		Material = Enum.Material.Concrete,
		Color = Color3.fromRGB(100, 96, 92),
		Parent = model,
	})

	-- 2 shallow steps (0.5 studs each) down to the main plaza at the
	-- terrace's forward edge — well within default auto-step, never blocks
	-- movement, but reads as a deliberate stepped entrance.
	for stepIndex = 1, 2 do
		local stepHeight = ARRIVAL_TERRACE_HEIGHT - stepIndex * (ARRIVAL_TERRACE_HEIGHT / 2)
		local stepOuterRadius = ARRIVAL_TERRACE_INNER_RADIUS - (stepIndex - 1) * (ARRIVAL_TERRACE_RAMP_DEPTH / 2)
		local stepDepth = ARRIVAL_TERRACE_RAMP_DEPTH / 2
		GeneratorKit.NewPart({
			Name = `RampStep{stepIndex}`,
			Size = Vector3.new(ARRIVAL_TERRACE_WIDTH, math.max(stepHeight, 0.2), stepDepth),
			CFrame = terraceCFrame * CFrame.new(0, math.max(stepHeight, 0.2) / 2, -(stepOuterRadius - stepDepth / 2)),
			Material = Enum.Material.Concrete,
			Color = Color3.fromRGB(100, 96, 92),
			Parent = model,
		})
	end

	-- 2 lamp posts + 2 planters flanking the terrace's outer corners — the
	-- only props in the arrival area itself, framing it without crowding it.
	for _, side in { -1, 1 } do
		local cornerCFrame = terraceCFrame * CFrame.new(side * (ARRIVAL_TERRACE_WIDTH / 2 - 1.5), 0, -ARRIVAL_TERRACE_OUTER_RADIUS + 3)

		GeneratorKit.NewPart({
			Name = if side < 0 then "TerraceLampPostLeft" else "TerraceLampPostRight",
			Size = Vector3.new(0.6, 8, 0.6),
			CFrame = cornerCFrame * CFrame.new(0, 4, 0),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(50, 48, 46),
			Parent = model,
		})

		local globe = GeneratorKit.NewPart({
			Name = if side < 0 then "TerraceLampGlobeLeft" else "TerraceLampGlobeRight",
			Size = Vector3.new(1.4, 1.4, 1.4),
			CFrame = cornerCFrame * CFrame.new(0, 8.3, 0),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255, 214, 160),
			Shape = Enum.PartType.Ball,
			CanCollide = false,
			Parent = model,
		})

		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 200, 140)
		light.Brightness = 2
		light.Range = 18
		light.Parent = globe
		CollectionService:AddTag(light, "AmbientFlicker")

		local planterCFrame = terraceCFrame * CFrame.new(side * (ARRIVAL_TERRACE_WIDTH / 2 + 1.5), 0, -ARRIVAL_TERRACE_INNER_RADIUS + 2)
		GeneratorKit.NewPart({
			Name = if side < 0 then "TerracePlanterLeft" else "TerracePlanterRight",
			Size = Vector3.new(3, 1.6, 3),
			CFrame = planterCFrame * CFrame.new(0, 0.8, 0),
			Material = Enum.Material.Concrete,
			Color = Color3.fromRGB(80, 78, 82),
			Parent = model,
		})
		GeneratorKit.NewPart({
			Name = if side < 0 then "TerraceFoliageLeft" else "TerraceFoliageRight",
			Size = Vector3.new(2.3, 1.3, 2.3),
			CFrame = planterCFrame * CFrame.new(0, 1.9, 0),
			Material = Enum.Material.Grass,
			Color = Color3.fromRGB(70, 110, 60),
			Shape = Enum.PartType.Ball,
			CanCollide = false,
			Parent = model,
		})
	end

	model.Parent = parent
	return model
end

-- Survivor Haven redesign Phase 1: 3 wide, deliberate paved branch paths —
-- forward (spawn -> plaza), left (plaza -> the Tutorial/Rewards cluster),
-- right (plaza -> the Leaderboard/Base Gate cluster). Phase 2: each route
-- widened and given curbs/an inner flare/accent lighting instead of being a
-- bare flat strip. The upper route toward the portal arc is still served by
-- buildRadialPaths below.
local FORWARD_PATH_WIDTH = 16
local BRANCH_PATH_WIDTH = 13
local PATH_ACCENT_LIGHT_COUNT = 3

local function buildMainPaths(parent: Instance, origin: CFrame)
	local model = Instance.new("Model")
	model.Name = "MainPaths"

	-- Phase 1 correction: LeftBranch/RightBranch aim at each cluster's
	-- actual angular center (110/-115, matching HavenFacilityConfig's
	-- corrected positions) and stop at radius 60 — short of every facility's
	-- own radius (nearest is Starter Pack at 75) so the paved strip never
	-- runs into a building.
	local routes = {
		{ Name = "Forward", AngleDegrees = HavenLayoutConfig.SPAWN_ANGLE_DEGREES, OuterRadius = HavenLayoutConfig.SPAWN_RADIUS, Width = FORWARD_PATH_WIDTH },
		{ Name = "LeftBranch", AngleDegrees = 110, OuterRadius = 60, Width = BRANCH_PATH_WIDTH },
		{ Name = "RightBranch", AngleDegrees = -115, OuterRadius = 60, Width = BRANCH_PATH_WIDTH },
	}

	for _, route in routes do
		local innerRadius = HavenLayoutConfig.CENTRAL_ARRIVAL_RADIUS
		local length = route.OuterRadius - innerRadius
		local pathCFrame = origin * CFrame.Angles(0, math.rad(route.AngleDegrees), 0)

		GeneratorKit.NewPart({
			Name = `Path_{route.Name}`,
			Size = Vector3.new(route.Width, 0.3, length),
			CFrame = pathCFrame * CFrame.new(0, 0.45, -(innerRadius + length / 2)),
			Material = Enum.Material.Pavement,
			Color = Color3.fromRGB(112, 108, 102),
			CanCollide = false,
			Parent = model,
		})

		buildPathFlare(model, pathCFrame, route.Width, innerRadius)
		buildPathCurbs(model, pathCFrame, route.Width, length, innerRadius)
		buildPathAccentLights(model, pathCFrame, route.Width, innerRadius, length, PATH_ACCENT_LIGHT_COUNT)
	end

	model.Parent = parent
	return model
end

local function gateAngles(): { [string]: number }
	local angles = {}
	for _, biome in BiomeConfig do
		angles[biome.id] = math.rad(HavenLayoutConfig.GateAngleForOrder(biome.order))
	end
	return angles
end

local function isNearAnyGate(angleDeg: number, angles: { [string]: number }): boolean
	for _, gateAngleRad in angles do
		local gateAngleDeg = math.deg(gateAngleRad)
		local delta = math.abs(((angleDeg - gateAngleDeg + 180) % 360) - 180)
		if delta <= GATE_BREACH_DEGREES then
			return true
		end
	end
	return false
end

local function buildPerimeterWall(parent: Instance, origin: CFrame, angles: { [string]: number })
	local wallModel = Instance.new("Model")
	wallModel.Name = "PerimeterWall"

	local segmentWidth = (2 * math.pi * PLAZA_RADIUS) / WALL_SEGMENTS

	for i = 0, WALL_SEGMENTS - 1 do
		local angleDeg = (i / WALL_SEGMENTS) * 360
		if not isNearAnyGate(angleDeg, angles) then
			local segmentCFrame = origin
				* CFrame.Angles(0, math.rad(angleDeg), 0)
				* CFrame.new(0, WALL_HEIGHT / 2, -PLAZA_RADIUS)

			GeneratorKit.NewPart({
				Name = `WallSegment{i}`,
				Size = Vector3.new(segmentWidth * 1.02, WALL_HEIGHT, WALL_THICKNESS),
				CFrame = segmentCFrame,
				Material = Enum.Material.Rock,
				Color = Color3.fromRGB(84, 80, 76),
				Parent = wallModel,
			})

			-- Alternating merlons along the rampart for a real fortress silhouette.
			for _, sign in { -1, 1 } do
				GeneratorKit.NewPart({
					Name = `Merlon{i}_{sign}`,
					Size = Vector3.new(segmentWidth * 0.32, 3, WALL_THICKNESS + 0.6),
					CFrame = segmentCFrame * CFrame.new(sign * segmentWidth * 0.28, WALL_HEIGHT / 2 + 1.5, 0),
					Material = Enum.Material.Rock,
					Color = Color3.fromRGB(84, 80, 76),
					Parent = wallModel,
				})
			end

			-- Diagonal support beam between the merlons — reinforces the
			-- "defensive, load-bearing" silhouette rather than a smooth wall top.
			GeneratorKit.NewPart({
				Name = `SupportBeam{i}`,
				Size = Vector3.new(segmentWidth * 0.5, 1.2, WALL_THICKNESS * 0.5),
				CFrame = segmentCFrame * CFrame.new(0, WALL_HEIGHT / 2 + 0.5, 0) * CFrame.Angles(0, 0, math.rad(12)),
				Material = Enum.Material.Metal,
				Color = Color3.fromRGB(60, 58, 62),
				CanCollide = false,
				Parent = wallModel,
			})
		end
	end

	wallModel.Parent = parent
	return wallModel
end

local function buildWatchtowers(parent: Instance, origin: CFrame)
	local towerModel = Instance.new("Model")
	towerModel.Name = "Watchtowers"

	-- Survivor Haven redesign Phase 1: reduced from 4 (fixed 45/135/225/315,
	-- the old midpoint-between-cardinal-gates convention) to 2, flanking the
	-- new tight portal arc (see HavenLayoutConfig.WATCHTOWER_ANGLES_DEGREES)
	-- instead of colliding with it — a watchtower at 45deg would otherwise
	-- land exactly on the new Forest gate.
	for i, angleDeg in HavenLayoutConfig.WATCHTOWER_ANGLES_DEGREES do
		local towerCFrame = origin * CFrame.Angles(0, math.rad(angleDeg), 0) * CFrame.new(0, 0, -PLAZA_RADIUS)

		GeneratorKit.NewPart({
			Name = `TowerBase{i}`,
			Size = Vector3.new(TOWER_RADIUS * 2, WALL_HEIGHT * 1.6, TOWER_RADIUS * 2),
			CFrame = towerCFrame * CFrame.new(0, WALL_HEIGHT * 0.8, 0),
			Material = Enum.Material.Concrete,
			Color = Color3.fromRGB(74, 70, 68),
			Shape = Enum.PartType.Cylinder,
			Parent = towerModel,
		})

		GeneratorKit.BuildPyramidRoof(
			towerModel,
			towerCFrame * CFrame.new(0, WALL_HEIGHT * 1.6 + 0.5, 0),
			TOWER_RADIUS * 2.4,
			10,
			Enum.Material.Slate,
			Color3.fromRGB(52, 48, 50)
		)

		-- Observation ledge just below the roof + a hanging banner facing the
		-- plaza — "stronger wall silhouettes... observation platforms...
		-- banners" per the redesign brief.
		GeneratorKit.NewPart({
			Name = `ObservationLedge{i}`,
			Size = Vector3.new(TOWER_RADIUS * 2.6, 0.6, TOWER_RADIUS * 2.6),
			CFrame = towerCFrame * CFrame.new(0, WALL_HEIGHT * 1.6 - 1.5, 0),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(58, 56, 60),
			CanCollide = false,
			Parent = towerModel,
		})

		local banner = GeneratorKit.NewPart({
			Name = `TowerBanner{i}`,
			Size = Vector3.new(TOWER_RADIUS * 1.1, TOWER_RADIUS * 1.6, 0.15),
			CFrame = towerCFrame * CFrame.new(0, WALL_HEIGHT * 0.7, TOWER_RADIUS + 0.2),
			Material = Enum.Material.Fabric,
			Color = Color3.fromRGB(120, 90, 255),
			CanCollide = false,
			Parent = towerModel,
		})
		CollectionService:AddTag(banner, "AmbientSway")

		local light = Instance.new("PointLight")
		light.Name = "TowerBeacon"
		light.Color = Color3.fromRGB(255, 200, 140)
		light.Brightness = 2
		light.Range = 24
		light.Parent = towerModel:FindFirstChild(`TowerBase{i}`)
		CollectionService:AddTag(light, "AmbientFlicker")
	end

	towerModel.Parent = parent
	return towerModel
end

local function gateAccentColors(): { [string]: Color3 }
	local colors = {}
	for _, biome in BiomeConfig do
		colors[biome.id] = biome.gate.accentColor
	end
	return colors
end

-- Prompt 4A.1: a thin Neon centerline down each path, colored with that
-- biome's own accent color (BiomeConfig.gate.accentColor). This is the
-- "subtle ground guidance" requested — each path visibly leads toward a
-- distinctly colored destination without a single floating arrow. Phase 2
-- adds the same curb trim the main paths got, for visual consistency.
local function buildRadialPaths(parent: Instance, origin: CFrame, angles: { [string]: number })
	local pathModel = Instance.new("Model")
	pathModel.Name = "RadialPaths"

	local accentColors = gateAccentColors()

	for biomeId, angle in angles do
		local pathCFrame = origin * CFrame.Angles(0, angle, 0)

		GeneratorKit.NewPart({
			Name = `Path_{biomeId}`,
			Size = Vector3.new(8, 0.3, PLAZA_RADIUS),
			CFrame = pathCFrame * CFrame.new(0, 0.45, -PLAZA_RADIUS / 2),
			Material = Enum.Material.Pavement,
			Color = Color3.fromRGB(110, 106, 100),
			CanCollide = false,
			Parent = pathModel,
		})

		GeneratorKit.NewPart({
			Name = `PathInlay_{biomeId}`,
			Size = Vector3.new(1, 0.05, PLAZA_RADIUS - 6),
			CFrame = pathCFrame * CFrame.new(0, 0.63, -PLAZA_RADIUS / 2),
			Material = Enum.Material.Neon,
			Color = accentColors[biomeId],
			CanCollide = false,
			Parent = pathModel,
		})

		buildPathCurbs(pathModel, pathCFrame, 8, PLAZA_RADIUS, 0)
	end

	pathModel.Parent = parent
	return pathModel
end

function HavenPlatformGenerator.Build(parent: Instance, origin: CFrame): BuildResult
	GeneratorKit.CleanupPrevious(parent, "HavenPlatform")

	local model = Instance.new("Model")
	model.Name = "HavenPlatform"

	local angles = gateAngles()

	buildPlazaFloor(model, origin)
	buildPerimeterWall(model, origin, angles)
	buildWatchtowers(model, origin)
	buildRadialPaths(model, origin, angles)
	buildMainPaths(model, origin)
	buildArrivalTerrace(model, origin)

	local gateAnchors: { [string]: CFrame } = {}
	for biomeId, angle in angles do
		gateAnchors[biomeId] = origin * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -PLAZA_RADIUS)
	end

	model.Parent = parent

	return {
		Model = model,
		PlazaCenter = origin,
		GateAnchors = gateAnchors,
	}
end

return HavenPlatformGenerator
