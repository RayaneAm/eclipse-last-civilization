--!strict
-- A small library of grouped environmental-storytelling clusters — not
-- scattered individual props. Each cluster communicates one small story
-- (survivors repairing gear, keeping watch, stockpiling supplies) rather
-- than being decoration for its own sake.
--
-- Placed at 4 angles that deliberately avoid the gate angles (0/90/180/270)
-- and the district angles (45/135/225/315) so they read as their own minor
-- landmarks instead of crowding either.
--
-- Playtest correction: a shared radius/angle pair put LookoutPost (112.5deg)
-- only 2.5deg off HavenPlatformGenerator's LeftBranch path centerline
-- (110deg) while inside that path's own radius 32-60 span — its deck and
-- legs were standing directly in the path. RepairBay (22.5deg) also cleared
-- the Forest radial path (15deg) by well under a stud once its own footprint
-- was netted out. Each cluster now carries its own angle/radius instead of
-- sharing one.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldMapConfig = require(ReplicatedStorage.Shared.Config.WorldMapConfig)
local GeneratorKit = require(script.Parent.GeneratorKit)

local CLUSTERS = {
	{ Type = "RepairBay", AngleDegrees = 28.5, Radius = 58 }, -- nudged from 22.5: clears the Forest radial path (15deg, half-width 4) with a comfortable margin
	{ Type = "LookoutPost", AngleDegrees = 112.5, Radius = 72 }, -- pushed from 58: clears LeftBranch's path, which doesn't extend past radius 60 at all
	{ Type = "SupplyCache", AngleDegrees = 202.5, Radius = 58 },
	{ Type = "RepairBay", AngleDegrees = 292.5, Radius = 58 },
}

local StorytellingClusterGenerator = {}

local function buildRepairBay(parent: Instance, clusterCFrame: CFrame, rng: Random)
	GeneratorKit.NewPart({
		Name = "DamagedChassis",
		Size = Vector3.new(4, 2, 2.5),
		CFrame = clusterCFrame * CFrame.new(-1.5, 1, 0) * CFrame.Angles(0, math.rad(rng:NextNumber(-10, 10)), 0),
		Material = Enum.Material.CorrodedMetal,
		Color = Color3.fromRGB(80, 78, 74),
		Parent = parent,
	})

	GeneratorKit.ScatterRubble(parent, clusterCFrame * CFrame.new(2, 0, 1), 2.5, 4, rng, Enum.Material.WoodPlanks, Color3.fromRGB(110, 90, 70))

	local generator = GeneratorKit.NewPart({
		Name = "GeneratorUnit",
		Size = Vector3.new(1.6, 1.8, 1.6),
		CFrame = clusterCFrame * CFrame.new(2.6, 0.9, -1.5),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(55, 58, 56),
		Parent = parent,
	})
	local generatorLight = Instance.new("PointLight")
	generatorLight.Color = Color3.fromRGB(255, 200, 80)
	generatorLight.Brightness = 1.5
	generatorLight.Range = 8
	generatorLight.Parent = generator
	CollectionService:AddTag(generatorLight, "AmbientFlicker")

	local tarp = GeneratorKit.NewPart({
		Name = "Tarp",
		Size = Vector3.new(3.5, 0.1, 2.5),
		CFrame = clusterCFrame * CFrame.new(-1.5, 2.1, 0) * CFrame.Angles(0, 0, math.rad(6)),
		Material = Enum.Material.Fabric,
		Color = Color3.fromRGB(70, 76, 64),
		CanCollide = false,
		Parent = parent,
	})
	CollectionService:AddTag(tarp, "AmbientSway")
end

local function buildLookoutPost(parent: Instance, clusterCFrame: CFrame)
	GeneratorKit.NewPart({
		Name = "PostDeck",
		Size = Vector3.new(6, 0.6, 6),
		CFrame = clusterCFrame * CFrame.new(0, 3.3, 0),
		Material = Enum.Material.WoodPlanks,
		Color = Color3.fromRGB(90, 76, 58),
		Parent = parent,
	})

	-- Non-collide: thin (0.4-stud) ankle-height support posts don't need
	-- their own collision — the deck above doesn't functionally require it,
	-- and this is exactly the "ankle-height invisible blocker" pattern the
	-- accessibility pass targets.
	for i = 0, 3 do
		local legCFrame = clusterCFrame * CFrame.new(2.4 * (if i % 2 == 0 then 1 else -1), 1.5, 2.4 * (if i < 2 then 1 else -1))
		GeneratorKit.NewPart({
			Name = `Leg{i}`,
			Size = Vector3.new(0.4, 3, 0.4),
			CFrame = legCFrame,
			Material = Enum.Material.Wood,
			Color = Color3.fromRGB(70, 58, 44),
			CanCollide = false,
			Parent = parent,
		})
	end

	for i = 0, 3 do
		local angle = math.rad(i * 90)
		GeneratorKit.NewPart({
			Name = `Railing{i}`,
			Size = Vector3.new(6, 1.2, 0.2),
			CFrame = clusterCFrame * CFrame.new(0, 4.2, 0) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -3),
			Material = Enum.Material.Wood,
			Color = Color3.fromRGB(70, 58, 44),
			CanCollide = false,
			Parent = parent,
		})
	end

	GeneratorKit.NewPart({
		Name = "LookoutLampPost",
		Size = Vector3.new(0.4, 2.5, 0.4),
		CFrame = clusterCFrame * CFrame.new(2, 4.9, 2),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(50, 48, 46),
		Parent = parent,
	})
	local lampGlobe = GeneratorKit.NewPart({
		Name = "LookoutLampGlobe",
		Size = Vector3.new(0.9, 0.9, 0.9),
		CFrame = clusterCFrame * CFrame.new(2, 6.2, 2),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 210, 150),
		Shape = Enum.PartType.Ball,
		CanCollide = false,
		Parent = parent,
	})
	local lampLight = Instance.new("PointLight")
	lampLight.Color = Color3.fromRGB(255, 200, 140)
	lampLight.Brightness = 2
	lampLight.Range = 16
	lampLight.Parent = lampGlobe
	CollectionService:AddTag(lampLight, "AmbientFlicker")
end

local function buildSupplyCache(parent: Instance, clusterCFrame: CFrame, rng: Random)
	for i = 1, 5 do
		local stackHeight = rng:NextNumber(0, 1)
		GeneratorKit.NewPart({
			Name = `Crate{i}`,
			Size = Vector3.new(1.6, 1.4, 1.6),
			CFrame = clusterCFrame * CFrame.new(rng:NextNumber(-2, 2), 0.7 + math.floor(stackHeight * 2) * 1.5, rng:NextNumber(-2, 2))
				* CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
			Material = Enum.Material.WoodPlanks,
			Color = Color3.fromRGB(100, 82, 60),
			Parent = parent,
		})
	end

	-- A small perched drone — static (no hover animation) but reads as
	-- watching over the cache.
	local drone = GeneratorKit.NewPart({
		Name = "PerchedDrone",
		Size = Vector3.new(1.2, 0.4, 1.2),
		CFrame = clusterCFrame * CFrame.new(0, 2.4, 0),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(60, 62, 66),
		CanCollide = false,
		Parent = parent,
	})
	local droneLight = Instance.new("PointLight")
	droneLight.Color = Color3.fromRGB(120, 200, 255)
	droneLight.Brightness = 1.5
	droneLight.Range = 6
	droneLight.Parent = drone
	CollectionService:AddTag(droneLight, "AmbientFlicker")

	GeneratorKit.ScatterRubble(parent, clusterCFrame, 3, 3, rng, Enum.Material.Metal, Color3.fromRGB(64, 64, 68))
end

function StorytellingClusterGenerator.Build(parent: Instance, origin: CFrame)
	GeneratorKit.CleanupPrevious(parent, "StorytellingClusters")

	local clustersModel = Instance.new("Model")
	clustersModel.Name = "StorytellingClusters"

	for i, cluster in CLUSTERS do
		local direction = WorldMapConfig.DirectionForAngle(math.rad(cluster.AngleDegrees))
		local position = origin.Position + direction * cluster.Radius
		local clusterCFrame = CFrame.new(position, origin.Position)
		local rng = GeneratorKit.Seeded(cluster.AngleDegrees * 13 + 3)

		local clusterModel = Instance.new("Model")
		local clusterType = cluster.Type
		clusterModel.Name = `Cluster{i}_{clusterType}`

		if clusterType == "RepairBay" then
			buildRepairBay(clusterModel, clusterCFrame, rng)
		elseif clusterType == "LookoutPost" then
			buildLookoutPost(clusterModel, clusterCFrame)
		elseif clusterType == "SupplyCache" then
			buildSupplyCache(clusterModel, clusterCFrame, rng)
		end

		clusterModel.Parent = clustersModel
	end

	clustersModel.Parent = parent
	return clustersModel
end

return StorytellingClusterGenerator
