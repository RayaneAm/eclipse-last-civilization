--!strict
-- Phase 4A: builds one player's personal base — the starter layout (ground,
-- perimeter markers, entrance, Civilization Core, starter shelter, basic
-- storage/workbench/generator markers, trader terminal, defense-control
-- marker, future survivor/production zone pads, Eclipse Assault foundation
-- anchors) plus every already-placed StructureInstance from that player's
-- BaseSessionData. Runs LIVE, at runtime, on the server (via BaseService,
-- required from ServerStorage.Tools — tools/ ships into the live game per
-- default.project.json) — not a Studio-only one-shot Build*.luau script,
-- since a base must be creatable for any of potentially thousands of
-- players, not hand-authored.
--
-- Follows GeneratorKit's conventions exactly (NewPart/CleanupPrevious/
-- Seeded/Finalize) for consistency with every other generator in this
-- project. Root organization: one player-keyed sub-Model under the shared
-- PersonalBases_Generated root (created by BaseService), individually
-- rebuilt via GeneratorKit.CleanupPrevious(root, tostring(userId)) — never a
-- whole-root wipe, so one player's rebuild can't touch another's.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GeneratorKit = require(script.Parent.GeneratorKit)
local PortalDestinationGenerator = require(script.Parent.PortalDestinationGenerator)
local BuildingConfig = require(ReplicatedStorage.Shared.Config.BuildingConfig)
local BlueprintLayoutConfig = require(ReplicatedStorage.Shared.Config.BlueprintLayoutConfig)
local PersonalBaseConfig = require(ReplicatedStorage.Shared.Config.PersonalBaseConfig)
local ProductionRecipeConfig = require(ReplicatedStorage.Shared.Config.ProductionRecipeConfig)

local ROOT_NAME = "PersonalBases_Generated"

-- Must match PersonalBaseConfig.CoreLocalPosition exactly — see that file's
-- header comment for why this is a small duplicated constant, not a shared
-- module (same convention already established elsewhere in this project).
local CORE_OFFSET = PersonalBaseConfig.CoreLocalPosition

local WORLD_WIDTH = PersonalBaseConfig.WorldWidth
local WORLD_DEPTH = PersonalBaseConfig.WorldDepth
local SETTLEMENT_WIDTH = PersonalBaseConfig.SettlementWidth
local SETTLEMENT_DEPTH = PersonalBaseConfig.SettlementDepth
local FOREST_INNER_HALF_WIDTH = PersonalBaseConfig.ForestInnerHalfWidth
local FOREST_INNER_HALF_DEPTH = PersonalBaseConfig.ForestInnerHalfDepth
local FOREST_OUTER_HALF_WIDTH = PersonalBaseConfig.ForestOuterHalfWidth
local FOREST_OUTER_HALF_DEPTH = PersonalBaseConfig.ForestOuterHalfDepth
local BASE_RETURN_PORTAL_LOCAL_POSITION = Vector3.new(24, 0, -8)

local BASE_PALETTE = {
	ForestFloor = Color3.fromRGB(46, 52, 40),
	Clearing = Color3.fromRGB(96, 84, 64),
	PatrolGround = Color3.fromRGB(67, 70, 57),
	PackedPath = Color3.fromRGB(135, 114, 82),
	PathEdge = Color3.fromRGB(75, 58, 41),
	Timber = Color3.fromRGB(74, 55, 38),
	TimberDark = Color3.fromRGB(52, 40, 30),
	Foliage = Color3.fromRGB(45, 67, 39),
	FoliageDark = Color3.fromRGB(31, 51, 31),
	FoliageLight = Color3.fromRGB(59, 80, 45),
	Rock = Color3.fromRGB(66, 68, 62),
}

local PersonalBaseGenerator = {}

-- ---------------------------------------------------------------------
-- Shared lookups (also used by BuildStructure/RemoveStructure, called
-- later and independently by BuildingService, not just during the initial
-- full Build).
-- ---------------------------------------------------------------------

local function findRoot(): Model?
	local root = Workspace:FindFirstChild(ROOT_NAME)
	return if root and root:IsA("Model") then root else nil
end

local function findBaseModel(userId: number): Model?
	local root = findRoot()
	if not root then
		return nil
	end
	local baseModel = root:FindFirstChild(tostring(userId))
	return if baseModel and baseModel:IsA("Model") then baseModel else nil
end

local function structuresContainer(userId: number): Model?
	local baseModel = findBaseModel(userId)
	if not baseModel then
		return nil
	end
	local container = baseModel:FindFirstChild("Structures")
	if not container then
		container = Instance.new("Model")
		container.Name = "Structures"
		container.Parent = baseModel
	end
	return container :: Model
end

-- ---------------------------------------------------------------------
-- Civilization Core — a real Eclipse-survivor identity, not a generic
-- glowing cube: reinforced base, visible support struts, cable runs, a ring
-- of status lights, one upgradeable outer-ring detail.
-- ---------------------------------------------------------------------

local CORE_HEIGHT = 22
local CORE_RADIUS = 8

local function buildCivilizationCore(parent: Instance, baseCFrame: CFrame)
	local model = Instance.new("Model")
	model.Name = "CivilizationCore"

	local plinth = GeneratorKit.NewPart({
		Name = "Plinth",
		Size = Vector3.new(CORE_RADIUS * 2.4, 2, CORE_RADIUS * 2.4),
		CFrame = baseCFrame * CFrame.new(0, 1, 0),
		Material = Enum.Material.DiamondPlate,
		Color = Color3.fromRGB(60, 58, 62),
		Parent = model,
	})

	-- Opens the Base Management UI (BaseUIController) — the Core's status
	-- display doubles as the main access point, per the brief's "provides
	-- access to base overview information."
	local corePrompt = Instance.new("ProximityPrompt")
	corePrompt.Name = "BaseCorePrompt"
	corePrompt.ObjectText = "Civilization Core"
	corePrompt.ActionText = "Manage Base"
	corePrompt.MaxActivationDistance = 16
	corePrompt.RequiresLineOfSight = false
	corePrompt.Parent = plinth
	CollectionService:AddTag(plinth, "BaseCoreTerminal")

	GeneratorKit.NewPart({
		Name = "CoreShell",
		Size = Vector3.new(CORE_RADIUS * 1.6, CORE_HEIGHT, CORE_RADIUS * 1.6),
		CFrame = baseCFrame * CFrame.new(0, 2 + CORE_HEIGHT / 2, 0),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(46, 44, 50),
		Parent = model,
	})

	-- Support struts, 4 angled braces.
	for i = 0, 3 do
		local angle = math.rad(90 * i + 45)
		GeneratorKit.NewPart({
			Name = `Strut{i}`,
			Size = Vector3.new(1, CORE_HEIGHT * 0.7, 1.2),
			CFrame = baseCFrame * CFrame.new(math.cos(angle) * CORE_RADIUS * 1.3, 2 + CORE_HEIGHT * 0.35, math.sin(angle) * CORE_RADIUS * 1.3) * CFrame.Angles(0, angle, math.rad(8)),
			Material = Enum.Material.CorrodedMetal,
			Color = Color3.fromRGB(70, 66, 60),
			Parent = model,
		})
	end

	-- Cable runs from the plinth up to the shell.
	for i = 1, 3 do
		local angle = math.rad(120 * i)
		GeneratorKit.NewPart({
			Name = `Cable{i}`,
			Size = Vector3.new(0.3, CORE_HEIGHT * 0.6, 0.3),
			CFrame = baseCFrame * CFrame.new(math.cos(angle) * CORE_RADIUS * 0.9, 2 + CORE_HEIGHT * 0.3, math.sin(angle) * CORE_RADIUS * 0.9),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(30, 28, 30),
			CanCollide = false,
			Parent = model,
		})
	end

	-- Restrained status fixtures keep the Core readable without an eight-light
	-- bloom halo dominating the settlement.
	for i = 0, 3 do
		local angle = math.rad(90 * i + 45)
		local light = GeneratorKit.NewPart({
			Name = `StatusLight{i}`,
			Size = Vector3.new(0.6, 0.6, 0.6),
			CFrame = baseCFrame * CFrame.new(math.cos(angle) * CORE_RADIUS * 0.85, 2 + CORE_HEIGHT * 0.55, math.sin(angle) * CORE_RADIUS * 0.85),
			Material = Enum.Material.SmoothPlastic,
			Color = Color3.fromRGB(111, 98, 166),
			Shape = Enum.PartType.Ball,
			CanCollide = false,
			Parent = model,
		})
		local pointLight = Instance.new("PointLight")
		pointLight.Color = Color3.fromRGB(178, 166, 224)
		pointLight.Brightness = 0.4
		pointLight.Range = 9
		pointLight.Parent = light
	end

	-- Upgradeable outer ring detail (static — matches this project's
	-- established rule that only small secondary energy details rotate,
	-- never the main architectural silhouette).
	for _, side in { -1, 1 } do
		local fixture = GeneratorKit.NewPart({
			Name = "CoreWorkLight",
			Size = Vector3.new(2.6, 0.45, 0.8),
			CFrame = baseCFrame * CFrame.new(side * 5.2, 8, -6.2),
			Material = Enum.Material.Glass,
			Color = Color3.fromRGB(232, 193, 132),
			CanCollide = false,
			Parent = model,
		})
		local practical = Instance.new("PointLight")
		practical.Color = Color3.fromRGB(255, 208, 146)
		practical.Brightness = 1.1
		practical.Range = 26
		practical.Shadows = true
		practical.Parent = fixture
	end

	-- Eclipse Assault foundation: the Core doubles as the future assault
	-- objective reference — inert until a real assault system exists.
	CollectionService:AddTag(plinth, "EclipseAssaultObjective")

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CoreLabel"
	billboard.Size = UDim2.fromOffset(200, 36)
	billboard.StudsOffset = Vector3.new(0, CORE_HEIGHT + 4, 0)
	billboard.MaxDistance = 120
	billboard.LightInfluence = 0
	billboard.Parent = plinth

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = "CIVILIZATION CORE"
	label.Parent = billboard

	model.Parent = parent
end

-- ---------------------------------------------------------------------
-- Starter layout — deliberately incomplete-but-hopeful: a small surviving
-- outpost, not a finished fortress.
-- ---------------------------------------------------------------------

local function buildGround(parent: Instance, baseCFrame: CFrame)
	local model = Instance.new("Model")
	model.Name = "SettlementGround"
	model:SetAttribute("StableSurfaceLayers", true)

	GeneratorKit.NewPart({
		Name = "Ground",
		Size = Vector3.new(WORLD_WIDTH, 1, WORLD_DEPTH),
		CFrame = baseCFrame * CFrame.new(0, -0.5, 0),
		Material = Enum.Material.Ground,
		Color = BASE_PALETTE.ForestFloor,
		Parent = model,
	})

	GeneratorKit.NewPart({
		Name = "SettlementField",
		Size = Vector3.new(SETTLEMENT_WIDTH, 0.2, SETTLEMENT_DEPTH),
		CFrame = baseCFrame * CFrame.new(0, 0.2, 0),
		Material = Enum.Material.Ground,
		Color = BASE_PALETTE.Clearing,
		Parent = model,
	})

	GeneratorKit.NewPart({
		Name = "OuterPatrolGround",
		Size = Vector3.new(FOREST_INNER_HALF_WIDTH * 2, 0.16, FOREST_INNER_HALF_DEPTH * 2),
		CFrame = baseCFrame * CFrame.new(0, 0.08, 0),
		Material = Enum.Material.Ground,
		Color = BASE_PALETTE.PatrolGround,
		Parent = model,
	})

	local function path(name: string, x: number, z: number, width: number, depth: number)
		GeneratorKit.NewPart({
			Name = name,
			Size = Vector3.new(width, 0.12, depth),
			CFrame = baseCFrame * CFrame.new(x, 0.36, z),
			Material = Enum.Material.Sand,
			Color = BASE_PALETTE.PackedPath,
			Parent = model,
		})
	end

	-- Edge-matched paths and lanes. Intersections terminate at one another
	-- instead of stacking coplanar rectangles.
	path("SouthGateTrail", 0, -48, 12, 60)
	path("CoreApproach", 0, 22, 14, 16)
	path("CoreNorthSpur", 0, 70, 12, 16)
	path("WestLogisticsApproach", -20, 12, 24, 7)
	path("EastLogisticsApproach", 20, 12, 24, 7)
	path("WestProductionLane", -30, 55, 8, 38)
	path("EastSupportLane", 30, 55, 8, 38)
	path("WestProductionLink", -40, 42, 12, 7)
	path("EastSupportLink", 40, 42, 12, 7)
	path("WestProcessorLink", -40, 68, 12, 7)
	path("EastQuartersLink", 40, 68, 12, 7)

	GeneratorKit.NewPart({
		Name = "CorePlaza",
		Size = Vector3.new(0.14, 36, 36),
		CFrame = baseCFrame * CFrame.new(0, 0.38, CORE_OFFSET.Z) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(94, 90, 78),
		Shape = Enum.PartType.Cylinder,
		Parent = model,
	})

	model.Parent = parent
end

local function buildForestPerimeter(parent: Instance, baseCFrame: CFrame)
	local model = Instance.new("Model")
	model.Name = "HostileForestPerimeter"
	local rng = GeneratorKit.Seeded(PersonalBaseConfig.WorldSeed)
	local treeCount = 0
	local bands = {
		{ Count = 80, HalfWidth = FOREST_INNER_HALF_WIDTH, HalfDepth = FOREST_INNER_HALF_DEPTH },
		{ Count = 95, HalfWidth = 205, HalfDepth = 172.5 },
		{ Count = PersonalBaseConfig.ForestTreeTarget - 175, HalfWidth = FOREST_OUTER_HALF_WIDTH, HalfDepth = FOREST_OUTER_HALF_DEPTH },
	}

	for bandIndex, band in bands do
		for index = 1, band.Count do
			local baseAngle = (index - 1) / band.Count * math.pi * 2
			local clusterDrift = math.sin(index * 1.73 + bandIndex * 2.1) * 0.025
			local angle = baseAngle + rng:NextNumber(-0.05, 0.05) + clusterDrift + bandIndex * 0.027
			local directionX, directionZ = math.cos(angle), math.sin(angle)
			local edgeScale = 1
				/ math.max(math.abs(directionX) / band.HalfWidth, math.abs(directionZ) / band.HalfDepth)
			local x = directionX * edgeScale
			local z = directionZ * edgeScale
			local outward = if bandIndex == 1 then rng:NextNumber(0, 4.5) else rng:NextNumber(-4.5, 4.5)
			local tangent = rng:NextNumber(-4.5, 4.5)
			-- Inner-edge trees can cluster along the edge, but never wander into
			-- the guaranteed open patrol buffer.
			if math.abs(directionX) / band.HalfWidth >= math.abs(directionZ) / band.HalfDepth then
				x += math.sign(directionX) * outward
				z += tangent
			else
				x += tangent
				z += math.sign(directionZ) * outward
			end
			treeCount += 1
			local height = rng:NextNumber(24, 38)
			local diameter = rng:NextNumber(2.8, 4.8)
			local trunk = GeneratorKit.NewPart({
				Name = `ForestTreeTrunk{treeCount}`,
				Size = Vector3.new(height, diameter, diameter),
				CFrame = baseCFrame * CFrame.new(x, height / 2, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), math.rad(90)),
				Material = Enum.Material.Wood,
				Color = if treeCount % 3 == 0 then BASE_PALETTE.TimberDark else BASE_PALETTE.Timber,
				Shape = Enum.PartType.Cylinder,
				CanCollide = bandIndex == 1,
				Parent = model,
			})
			trunk.CastShadow = bandIndex < 3
			local crownCount = if treeCount % 4 == 0 then 2 else 1
			for crownIndex = 1, crownCount do
				local crown = GeneratorKit.NewPart({
					Name = `ForestTreeCrown{treeCount}_{crownIndex}`,
						Size = Vector3.new(rng:NextNumber(17, 24), rng:NextNumber(15, 21), rng:NextNumber(17, 24)),
					CFrame = baseCFrame * CFrame.new(x + rng:NextNumber(-2.5, 2.5), height - 2 + (crownIndex - 1) * 6, z + rng:NextNumber(-2.5, 2.5)),
					Material = Enum.Material.LeafyGrass,
					Color = if crownIndex == 1 then BASE_PALETTE.FoliageDark else BASE_PALETTE.Foliage,
					Shape = Enum.PartType.Ball,
					CanCollide = false,
					Parent = model,
				})
				crown.CastShadow = bandIndex < 3
			end
		end
	end

	local function forestBandPoint(): (number, number)
		if rng:NextNumber() < 0.58 then
			local side = if rng:NextNumber() < 0.5 then -1 else 1
			return rng:NextNumber(-FOREST_OUTER_HALF_WIDTH, FOREST_OUTER_HALF_WIDTH),
				side * rng:NextNumber(FOREST_INNER_HALF_DEPTH, FOREST_OUTER_HALF_DEPTH)
		end
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		return side * rng:NextNumber(FOREST_INNER_HALF_WIDTH, FOREST_OUTER_HALF_WIDTH),
			rng:NextNumber(-FOREST_INNER_HALF_DEPTH, FOREST_INNER_HALF_DEPTH)
	end

	for index = 1, 110 do
		local x, z = forestBandPoint()
		local size = rng:NextNumber(2.5, 5.5)
		GeneratorKit.NewPart({
			Name = `ForestBush{index}`,
			Size = Vector3.new(size, size * 0.65, size),
			CFrame = baseCFrame * CFrame.new(x, size * 0.28, z),
			Material = Enum.Material.LeafyGrass,
			Color = if index % 4 == 0 then BASE_PALETTE.FoliageLight else BASE_PALETTE.FoliageDark,
			Shape = Enum.PartType.Ball,
			CanCollide = false,
			Parent = model,
		})
	end

	for index = 1, 45 do
		local x, z = forestBandPoint()
		local size = rng:NextNumber(1.8, 4.2)
		GeneratorKit.NewPart({
			Name = `ForestRock{index}`,
			Size = Vector3.new(size, size * 0.55, size * rng:NextNumber(0.7, 1.2)),
			CFrame = baseCFrame * CFrame.new(x, size * 0.22, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), rng:NextNumber(-0.2, 0.2)),
			Material = Enum.Material.Rock,
			Color = BASE_PALETTE.Rock,
			CanCollide = false,
			Parent = model,
		})
	end

	for index = 1, 22 do
		local x, z = forestBandPoint()
		local length = rng:NextNumber(8, 15)
		GeneratorKit.NewPart({
			Name = `FallenLog{index}`,
			Size = Vector3.new(length, 2.2, 2.2),
			CFrame = baseCFrame * CFrame.new(x, 1.1, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0),
			Material = Enum.Material.Wood,
			Color = BASE_PALETTE.TimberDark,
			Shape = Enum.PartType.Cylinder,
			CanCollide = false,
			Parent = model,
		})
	end

	for index = 1, 18 do
		local x, z = forestBandPoint()
		GeneratorKit.NewPart({
			Name = `ForestStump{index}`,
			Size = Vector3.new(2, 3.2, 3.2),
			CFrame = baseCFrame * CFrame.new(x, 1, z) * CFrame.Angles(0, 0, math.rad(90)),
			Material = Enum.Material.Wood,
			Color = BASE_PALETTE.TimberDark,
			Shape = Enum.PartType.Cylinder,
			CanCollide = false,
			Parent = model,
		})
	end

	model:SetAttribute("LargeTreeCount", treeCount)
	model:SetAttribute("ForestInnerHalfWidth", FOREST_INNER_HALF_WIDTH)
	model:SetAttribute("ForestInnerHalfDepth", FOREST_INNER_HALF_DEPTH)
	model:SetAttribute("ForestOuterHalfWidth", FOREST_OUTER_HALF_WIDTH)
	model:SetAttribute("ForestOuterHalfDepth", FOREST_OUTER_HALF_DEPTH)
	model:SetAttribute("PerimeterShape", "Rectangle")
	model.Parent = parent
end

local function buildEntrance(parent: Instance, baseCFrame: CFrame)
	local entranceCFrame = baseCFrame * CFrame.new(PersonalBaseConfig.EntranceLocalPosition)
	local model = Instance.new("Model")
	model.Name = "Entrance"

	for _, side in { -1, 1 } do
		GeneratorKit.NewPart({
			Name = if side < 0 then "PylonLeft" else "PylonRight",
			Size = Vector3.new(1.4, 6, 1.4),
			CFrame = entranceCFrame * CFrame.new(side * 10.5, 3, 0),
			Material = Enum.Material.WoodPlanks,
			Color = BASE_PALETTE.TimberDark,
			Parent = model,
		})
	end

	model.Parent = parent
end

local function buildWayfindingAndLights(parent: Instance, baseCFrame: CFrame)
	local model = Instance.new("Model")
	model.Name = "SettlementLighting"

	-- Pad placement and color carry the zone hierarchy. Permanent zone
	-- billboards are intentionally absent so the settlement reads as a world,
	-- not as a floating project plan.

	for index, position in {
		Vector3.new(-8, 0, -74),
		Vector3.new(8, 0, -74),
		Vector3.new(-8, 0, -28),
		Vector3.new(8, 0, -28),
		Vector3.new(-16, 0, 24),
		Vector3.new(16, 0, 24),
	} do
		GeneratorKit.NewPart({
			Name = `PathLanternPost{index}`,
			Size = Vector3.new(0.5, 5.5, 0.5),
			CFrame = baseCFrame * CFrame.new(position + Vector3.new(0, 2.75, 0)),
			Material = Enum.Material.Wood,
			Color = BASE_PALETTE.TimberDark,
			CanCollide = false,
			Parent = model,
		})
		local lantern = GeneratorKit.NewPart({
			Name = `PathLantern{index}`,
			Size = Vector3.new(0.8, 1, 0.8),
			CFrame = baseCFrame * CFrame.new(position + Vector3.new(0, 5.2, 0)),
			Material = Enum.Material.Glass,
			Color = Color3.fromRGB(230, 184, 119),
			CanCollide = false,
			Parent = model,
		})
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 205, 142)
		light.Brightness = 0.5
		light.Range = 15
		light.Shadows = true
		light.Parent = lantern
	end

	for index, localPosition in {
		Vector3.new(-72, 0, 18),
		Vector3.new(72, 0, 18),
		Vector3.new(-72, 0, 78),
		Vector3.new(72, 0, 78),
	} do
		GeneratorKit.NewPart({
			Name = `SettlementFloodlightPost{index}`,
			Size = Vector3.new(0.7, 11, 0.7),
			CFrame = baseCFrame * CFrame.new(localPosition + Vector3.new(0, 5.5, 0)),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(53, 55, 52),
			CanCollide = false,
			Parent = model,
		})
		local fixturePosition = baseCFrame:PointToWorldSpace(localPosition + Vector3.new(0, 10.5, 0))
		local targetPosition = baseCFrame:PointToWorldSpace(Vector3.new(0, 1, 12))
		local fixture = GeneratorKit.NewPart({
			Name = `SettlementFloodlight{index}`,
			Size = Vector3.new(1.8, 1.2, 1),
			CFrame = CFrame.lookAt(fixturePosition, targetPosition),
			Material = Enum.Material.Glass,
			Color = Color3.fromRGB(197, 190, 163),
			CanCollide = false,
			Parent = model,
		})
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Front
		light.Color = Color3.fromRGB(222, 217, 194)
		light.Brightness = 0.65
		light.Range = 44
		light.Angle = 70
		light.Shadows = true
		light.Parent = fixture
	end

	model.Parent = parent
end

local function buildStarterShelter(parent: Instance, baseCFrame: CFrame)
	local shelterCFrame = baseCFrame * CFrame.new(-22, 0, 72)
	local model = Instance.new("Model")
	model.Name = "StarterShelter"

	GeneratorKit.NewPart({
		Name = "Floor",
		Size = Vector3.new(14, 0.5, 14),
		CFrame = shelterCFrame * CFrame.new(0, 0.25, 0),
		Material = Enum.Material.WoodPlanks,
		Color = Color3.fromRGB(84, 66, 48),
		Parent = model,
	})
	for _, offset in { Vector3.new(-6.5, 0, -6.5), Vector3.new(6.5, 0, -6.5), Vector3.new(-6.5, 0, 6.5), Vector3.new(6.5, 0, 6.5) } do
		GeneratorKit.NewPart({
			Name = "Wall",
			Size = Vector3.new(0.6, 6, 14),
			CFrame = shelterCFrame * CFrame.new(offset) * CFrame.Angles(0, if math.abs(offset.X) > math.abs(offset.Z) then math.rad(90) else 0, 0),
			Material = Enum.Material.Fabric,
			Color = Color3.fromRGB(90, 84, 70),
			Transparency = 0.1,
			CanCollide = false,
			Parent = model,
		})
	end
	GeneratorKit.BuildPyramidRoof(model, shelterCFrame * CFrame.new(0, 6, 0), 15, 4, Enum.Material.Fabric, Color3.fromRGB(70, 62, 50))

	model.Parent = parent
end

local function buildMarkerBuilding(parent: Instance, cframe: CFrame, name: string, color: Color3, size: Vector3)
	local model = Instance.new("Model")
	model.Name = name

	GeneratorKit.NewPart({
		Name = "Body",
		Size = size,
		CFrame = cframe * CFrame.new(0, size.Y / 2, 0),
		Material = Enum.Material.Concrete,
		Color = color,
		Parent = model,
	})

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(160, 30)
	billboard.StudsOffset = Vector3.new(0, size.Y + 1.5, 0)
	billboard.MaxDistance = 70
	billboard.LightInfluence = 0
	billboard.Parent = model.Body

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = string.upper(name)
	label.Parent = billboard

	model.Parent = parent
	return model
end

local function buildTraderTerminal(parent: Instance, baseCFrame: CFrame)
	local terminalCFrame = baseCFrame * CFrame.new(22, 0, 72)
	local model = buildMarkerBuilding(parent, terminalCFrame, "TraderTerminal", Color3.fromRGB(90, 76, 58), Vector3.new(4, 5, 3))

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TraderPrompt"
	prompt.ObjectText = "Trader"
	prompt.ActionText = "Trade"
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = model.Body
	CollectionService:AddTag(model.Body, "BaseTraderTerminal")
end

-- ---------------------------------------------------------------------
-- Blueprint pads (Phase 4A.1) — guided-progression build slots. Each
-- unbuilt pad renders as a translucent footprint outline + name label +
-- a "BaseBlueprintPad"-tagged ProximityPrompt carrying a PadId attribute
-- (BaseUIController listens for this tag). A pad that already has a
-- linked StructureInstance (structure.PadId == pad.PadId, set either by a
-- real RequestBuildBlueprint build or by BaseService's migration of a
-- pre-4A.1 freeform structure) is skipped entirely here — the real
-- structure itself is drawn by the ordinary BuildStructure per-structure
-- loop in Build below, exactly like any other structure.
-- ---------------------------------------------------------------------

local function compactCostText(cost: BuildingConfig.BuildingCost): string
	local materialIds = {}
	for itemId in cost.Materials do
		table.insert(materialIds, itemId)
	end
	table.sort(materialIds)
	local parts = {}
	for _, itemId in materialIds do
		table.insert(parts, `{cost.Materials[itemId]} {itemId}`)
	end
	if cost.Scrap > 0 then
		table.insert(parts, `{cost.Scrap} Scrap`)
	end
	return if #parts > 0 then table.concat(parts, "  •  ") else "READY"
end

local function buildPadGhost(container: Instance, baseCFrame: CFrame, pad: BlueprintLayoutConfig.BlueprintPad)
	local definition = BuildingConfig.Get(pad.BuildingId)
	local padCFrame = baseCFrame * pad.LocalCFrame
	local districtColors = {
		Entrance = Color3.fromRGB(196, 158, 91),
		Logistics = Color3.fromRGB(91, 181, 184),
		Production = Color3.fromRGB(203, 137, 67),
		Support = Color3.fromRGB(114, 169, 103),
		Perimeter = Color3.fromRGB(179, 94, 76),
	}
	local accent = districtColors[pad.District]

	local lot = Instance.new("Model")
	lot.Name = pad.PadId
	lot:SetAttribute("PadId", pad.PadId)
	lot:SetAttribute("District", pad.District)
	lot:SetAttribute("BuildingId", pad.BuildingId)
	lot:SetAttribute("ConstructionLot", true)
	lot:SetAttribute("FutureWorldCFrame", padCFrame)

	local trim = GeneratorKit.NewPart({
		Name = "PurchasePadTrim",
		Size = Vector3.new(0.18, 7.4, 7.4),
		CFrame = padCFrame * CFrame.new(0, 0.33, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.CorrodedMetal,
		Color = Color3.fromRGB(43, 48, 47),
		Shape = Enum.PartType.Cylinder,
		CanCollide = false,
		Parent = lot,
	})
	local purchasePad = GeneratorKit.NewPart({
		Name = "PurchasePad",
		Size = Vector3.new(0.24, 6.4, 6.4),
		CFrame = padCFrame * CFrame.new(0, 0.46, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Pebble,
		Color = Color3.fromRGB(67, 68, 60),
		Shape = Enum.PartType.Cylinder,
		CanCollide = false,
		Parent = lot,
	})
	trim.CastShadow = false
	purchasePad.CastShadow = false

	-- A single reclaimed marker makes the node feel survivor-built without
	-- drawing a full-size rectangle over the eventual structure footprint.
	GeneratorKit.NewPart({
		Name = "ReclaimedMarkerBoard",
		Size = Vector3.new(5.2, 0.18, 0.72),
		CFrame = padCFrame * CFrame.new(0, 0.65, 0) * CFrame.Angles(0, math.rad(-14), 0),
		Material = Enum.Material.WoodPlanks,
		Color = BASE_PALETTE.Timber,
		CanCollide = false,
		Parent = lot,
	})

	local terminalX = -2.55
	local terminalZ = -2.55
	GeneratorKit.NewPart({
		Name = "BeaconPost",
		Size = Vector3.new(0.55, 2.5, 0.55),
		CFrame = padCFrame * CFrame.new(terminalX, 1.65, terminalZ),
		Material = Enum.Material.CorrodedMetal,
		Color = Color3.fromRGB(53, 55, 52),
		CanCollide = false,
		Parent = lot,
	})
	local anchor = GeneratorKit.NewPart({
		Name = "ConstructionBeacon",
		Size = Vector3.new(2.6, 1.2, 0.9),
		CFrame = padCFrame * CFrame.new(terminalX, 3.05, terminalZ),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(38, 43, 43),
		CanCollide = false,
		Parent = lot,
	})
	local indicator = GeneratorKit.NewPart({
		Name = "BeaconIndicator",
		Size = Vector3.new(2.1, 0.16, 0.94),
		CFrame = anchor.CFrame * CFrame.new(0, 0.53, 0),
		Material = Enum.Material.Glass,
		Color = accent,
		CanCollide = false,
		Parent = lot,
	})
	local indicatorLight = Instance.new("PointLight")
	indicatorLight.Name = "BeaconLight"
	indicatorLight.Color = accent
	indicatorLight.Brightness = 0.2
	indicatorLight.Range = 6
	indicatorLight.Shadows = false
	indicatorLight.Parent = indicator

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BlueprintPrompt"
	prompt.ObjectText = if definition then definition.Name else pad.BuildingId
	prompt.ActionText = "Build"
	prompt.MaxActivationDistance = 11
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor
	anchor:SetAttribute("PadId", pad.PadId)
	anchor:SetAttribute("District", pad.District)
	anchor:SetAttribute("BuildingId", pad.BuildingId)
	anchor:SetAttribute("ConstructionBeacon", true)
	anchor:SetAttribute("CostText", if definition then compactCostText(definition.Cost) else "")
	CollectionService:AddTag(anchor, "BaseBlueprintPad")

	local iconSurface = Instance.new("SurfaceGui")
	iconSurface.Name = "BuildIcon"
	iconSurface.Face = Enum.NormalId.Front
	iconSurface.CanvasSize = Vector2.new(180, 76)
	iconSurface.LightInfluence = 0
	iconSurface.Parent = anchor
	local icon = Instance.new("TextLabel")
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromScale(1, 1)
	icon.Font = Enum.Font.GothamBlack
	icon.TextScaled = true
	icon.TextColor3 = accent
	icon.Text = "+  BUILD"
	icon.Parent = iconSurface

	local labelGui = Instance.new("BillboardGui")
	labelGui.Name = "ConstructionLabel"
	labelGui.Size = UDim2.fromOffset(230, 54)
	labelGui.StudsOffset = Vector3.new(0, 2.4, 0)
	labelGui.MaxDistance = PersonalBaseConfig.ConstructionLabelDistance
	labelGui.AlwaysOnTop = false
	labelGui.LightInfluence = 0
	labelGui.Enabled = false
	labelGui.Parent = anchor
	local title = Instance.new("TextLabel")
	title.BackgroundColor3 = Color3.fromRGB(20, 23, 23)
	title.BackgroundTransparency = 0.08
	title.Size = UDim2.fromScale(1, 0.58)
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(238, 239, 233)
	title.Text = if definition then string.upper(definition.Name) else string.upper(pad.BuildingId)
	title.Parent = labelGui
	local cost = Instance.new("TextLabel")
	cost.BackgroundColor3 = accent
	cost.BackgroundTransparency = 0.08
	cost.Position = UDim2.fromScale(0, 0.58)
	cost.Size = UDim2.fromScale(1, 0.42)
	cost.Font = Enum.Font.GothamBold
	cost.TextScaled = true
	cost.TextColor3 = Color3.fromRGB(24, 26, 24)
	cost.Text = if definition then compactCostText(definition.Cost) else ""
	cost.Parent = labelGui

	lot.Parent = container
	return anchor
end

local function buildStarterDropBox(parent: Instance, baseCFrame: CFrame)
	local model = Instance.new("Model")
	model.Name = "StarterDropBox"
	local body = GeneratorKit.NewPart({
		Name = "Body",
		Size = Vector3.new(4.5, 2.8, 3.5),
		CFrame = baseCFrame * CFrame.new(-13, 1.4, 10),
		Material = Enum.Material.WoodPlanks,
		Color = Color3.fromRGB(92, 70, 48),
		Parent = model,
	})
	GeneratorKit.NewPart({
		Name = "MetalBands",
		Size = Vector3.new(4.8, 0.35, 3.8),
		CFrame = baseCFrame * CFrame.new(-13, 2.65, 10),
		Material = Enum.Material.CorrodedMetal,
		Color = Color3.fromRGB(66, 67, 62),
		CanCollide = false,
		Parent = model,
	})
	body:SetAttribute("OwnerUserId", tonumber(parent.Name) or 0)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StoragePrompt"
	prompt.ObjectText = "Field Cache"
	prompt.ActionText = "Deposit Materials"
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = body
	CollectionService:AddTag(body, "BaseStorageTerminal")
	model.Parent = parent
end

-- Idempotent by construction: derives ghost-vs-built state purely from the
-- already-migrated session.Structures/PadId linkage passed in, never from
-- any local/generator-side memory of what it last drew — a linked/built
-- pad never gets a ghost, an unbuilt pad is never duplicated, and calling
-- this twice (e.g. via a full rebuild) produces the same result every time
-- since the whole per-player model is destroyed via GeneratorKit.CleanupPrevious
-- before Build recreates it.
local function buildBlueprintPads(parent: Instance, baseCFrame: CFrame, session: any?)
	local model = Instance.new("Model")
	model.Name = "BlueprintPads"

	local builtPadIds: { [string]: boolean } = {}
	if session then
		for _, structure in session.Structures do
			if structure.PadId then
				builtPadIds[structure.PadId] = true
			end
		end
	end

	for _, pad in BlueprintLayoutConfig.All do
		local structures = if session then session.Structures else {}
		if not builtPadIds[pad.PadId] and BlueprintLayoutConfig.IsUnlocked(pad, structures) then
			buildPadGhost(model, baseCFrame, pad)
		end
	end

	model.Parent = parent
end

-- Called by BuildingService.requestDismantleBuilding when a pad-linked
-- structure is torn down mid-session (no full rebuild) — restores that
-- one pad's ghost so the guided-progression slot is buildable again,
-- without touching any other pad's state. No-ops if a ghost for this pad
-- is already present (idempotent, same guarantee as buildBlueprintPads).
function PersonalBaseGenerator.RefreshBlueprintPads(userId: number, origin: CFrame, session: any)
	local baseModel = findBaseModel(userId)
	if not baseModel then
		return
	end
	local existing = baseModel:FindFirstChild("BlueprintPads")
	if existing then
		existing:Destroy()
	end
	buildBlueprintPads(baseModel, origin, session)
end

local function buildAttackRouteAnchors(parent: Instance, baseCFrame: CFrame)
	-- Eclipse Assault foundation: tagged-but-inert reference anchors a
	-- future assault-combat phase will use — do nothing on their own.
	local model = Instance.new("Model")
	model.Name = "EclipseAssaultAnchors"

	for i = 0, 3 do
		local angle = math.rad(90 * i)
		local directionX, directionZ = math.cos(angle), math.sin(angle)
		local spawnDistance = if math.abs(directionX) > 0.5 then FOREST_INNER_HALF_WIDTH - 5 else FOREST_INNER_HALF_DEPTH - 5
		local perimeterDistance = if math.abs(directionX) > 0.5 then PersonalBaseConfig.PlotBounds.HalfWidth else PersonalBaseConfig.PlotBounds.HalfDepth
		local routeLength = spawnDistance - perimeterDistance
		local routeCenter = (spawnDistance + perimeterDistance) / 2
		local anchor = GeneratorKit.NewPart({
			Name = `EclipseAssaultSpawn{i}`,
			Size = Vector3.new(2, 0.2, 2),
			CFrame = baseCFrame * CFrame.new(directionX * spawnDistance, 0.1, directionZ * spawnDistance),
			Material = Enum.Material.SmoothPlastic,
			Color = Color3.fromRGB(90, 45, 42),
			Transparency = 1,
			CanCollide = false,
			Parent = model,
		})
		CollectionService:AddTag(anchor, "EclipseAssaultSpawn")
		anchor.CanQuery = false
		anchor.CanTouch = false
		anchor.CastShadow = false

		local route = GeneratorKit.NewPart({
			Name = `EclipseAttackRoute{i}`,
			Size = Vector3.new(4, 0.1, routeLength),
			CFrame = baseCFrame * CFrame.new(directionX * routeCenter, 0.05, directionZ * routeCenter) * CFrame.Angles(0, if math.abs(directionX) > 0.5 then math.rad(90) else 0, 0),
			Material = Enum.Material.SmoothPlastic,
			Color = Color3.fromRGB(90, 45, 42),
			Transparency = 1,
			CanCollide = false,
			Parent = model,
		})
		CollectionService:AddTag(route, "EclipseAttackRoute")
		route.CanQuery = false
		route.CanTouch = false
		route.CastShadow = false
	end

	model.Parent = parent
end

-- ---------------------------------------------------------------------
-- Player-placed structures — generic per-category placeholder geometry
-- plus a name label (no bespoke art per building this phase, per the
-- Phase 4A plan's foundation-only scoping).
-- ---------------------------------------------------------------------

local CATEGORY_COLOR = {
	Structural = Color3.fromRGB(120, 108, 90),
	Utility = Color3.fromRGB(90, 110, 120),
	Production = Color3.fromRGB(140, 120, 60),
	Defense = Color3.fromRGB(130, 60, 60),
	Civilization = Color3.fromRGB(120, 100, 180),
}

function PersonalBaseGenerator.BuildStructure(userId: number, origin: CFrame, structure: any, animateConstruction: boolean?)
	local container = structuresContainer(userId)
	if not container then
		return
	end
	local existing = container:FindFirstChild(structure.Id)
	if existing then
		existing:Destroy()
	end

	local definition = BuildingConfig.Get(structure.BuildingId)
	local color = if definition then CATEGORY_COLOR[definition.Category] else Color3.fromRGB(100, 100, 100)
	local authoredPad = structure.PadId and BlueprintLayoutConfig.Get(structure.PadId) or nil
	local structureCFrame = if authoredPad then BlueprintLayoutConfig.GetStructureLocalCFrame(authoredPad, structure.BuildingId) else structure.CFrame
	local worldCFrame = origin * structureCFrame

	local model = Instance.new("Model")
	model.Name = structure.Id
	model:SetAttribute("StructureId", structure.Id)
	model:SetAttribute("BuildingId", structure.BuildingId)
	model:SetAttribute("OwnerUserId", userId)
	model:SetAttribute("ConstructionSequence", "FoundationMajorDetails")
	model:SetAttribute("DefenseTier", if definition and definition.DefenseTier then definition.DefenseTier else 0)
	model:SetAttribute("MaxHealth", BuildingConfig.GetMaxHealth(structure.BuildingId))

	local footprint = if authoredPad then BlueprintLayoutConfig.GetFootprintSize(authoredPad, structure.BuildingId) else BuildingConfig.GetFootprintSize(structure.BuildingId)
	local sizeY = math.max(3.5, footprint.Y + (structure.Level - 1) * 0.5)
	local defenseTier = if definition and definition.DefenseTier then definition.DefenseTier else 0
	local isGate = defenseTier > 0 and string.find(structure.BuildingId, "Gate") ~= nil
	local isPerimeterWall = defenseTier > 0 and string.find(structure.BuildingId, "Wall") ~= nil
	local material = if definition and definition.Category == "Structural"
		then Enum.Material.WoodPlanks
		elseif definition and definition.Category == "Production" then Enum.Material.CorrodedMetal
		else Enum.Material.Metal
	local labelHost: BasePart
	local labelOffsetY = sizeY / 2 + 2

	if isGate then
		local gateMaterial = if defenseTier == 1 then Enum.Material.WoodPlanks elseif defenseTier == 2 then Enum.Material.Slate else Enum.Material.Metal
		local gateColor = if defenseTier == 1
			then Color3.fromRGB(104, 78, 52)
			elseif defenseTier == 2 then Color3.fromRGB(103, 101, 92)
			elseif defenseTier == 3 then Color3.fromRGB(65, 70, 72)
			else Color3.fromRGB(42, 50, 56)
		for _, side in { -1, 1 } do
			GeneratorKit.NewPart({
				Name = "GatePost",
				Size = Vector3.new(2.4, sizeY, footprint.Z),
				CFrame = worldCFrame * CFrame.new(side * (footprint.X / 2 - 1.2), sizeY / 2, 0),
				Material = gateMaterial,
				Color = gateColor,
				Parent = model,
			})
			if defenseTier >= 2 then
				GeneratorKit.NewPart({
					Name = "GateFoundation",
					Size = Vector3.new(4.2, 1.4 + defenseTier * 0.25, footprint.Z + 1.2),
					CFrame = worldCFrame * CFrame.new(side * (footprint.X / 2 - 1.2), 0.8, 0),
					Material = if defenseTier == 2 then Enum.Material.Rock else Enum.Material.DiamondPlate,
					Color = Color3.fromRGB(75, 77, 75),
					Parent = model,
				})
			end
		end
		labelHost = GeneratorKit.NewPart({
			Name = "Body",
			Size = Vector3.new(footprint.X, 1.4 + defenseTier * 0.22, footprint.Z),
			CFrame = worldCFrame * CFrame.new(0, sizeY - 0.7, 0),
			Material = gateMaterial,
			Color = gateColor,
			Parent = model,
		})
		if defenseTier >= 3 then
			for _, side in { -1, 1 } do
				GeneratorKit.NewPart({
					Name = "GateIndustrialBrace",
					Size = Vector3.new(0.7, sizeY - 2, footprint.Z + 0.6),
					CFrame = worldCFrame * CFrame.new(side * (footprint.X / 2 - 3.4), sizeY / 2, 0) * CFrame.Angles(0, 0, math.rad(side * 12)),
					Material = Enum.Material.DiamondPlate,
					Color = Color3.fromRGB(91, 96, 97),
					CanCollide = false,
					Parent = model,
				})
			end
		end
		if defenseTier >= 4 then
			GeneratorKit.NewPart({
				Name = "PoweredGateStatus",
				Size = Vector3.new(footprint.X - 6, 0.38, footprint.Z + 0.12),
				CFrame = worldCFrame * CFrame.new(0, sizeY - 1.75, -(footprint.Z / 2 + 0.08)),
				Material = Enum.Material.Glass,
				Color = Color3.fromRGB(88, 184, 188),
				CanCollide = false,
				Parent = model,
			})
		end
		labelOffsetY = 2.2
	elseif isPerimeterWall then
		local wallMaterial = if defenseTier == 1 then Enum.Material.WoodPlanks elseif defenseTier == 2 then Enum.Material.Slate else Enum.Material.Metal
		local wallColor = if defenseTier == 1
			then Color3.fromRGB(104, 78, 52)
			elseif defenseTier == 2 then Color3.fromRGB(105, 104, 96)
			elseif defenseTier == 3 then Color3.fromRGB(64, 69, 71)
			else Color3.fromRGB(41, 49, 55)
		labelHost = GeneratorKit.NewPart({
			Name = "Body",
			Size = Vector3.new(footprint.X, sizeY, footprint.Z),
			CFrame = worldCFrame * CFrame.new(0, sizeY / 2, 0),
			Material = wallMaterial,
			Color = wallColor,
			Parent = model,
		})
		local cornerDirection = if authoredPad and (authoredPad.PadId == "Wall_0" or authoredPad.PadId == "Wall_3")
			then -1
			elseif authoredPad and (authoredPad.PadId == "Wall_1" or authoredPad.PadId == "Wall_2") then 1
			else 0
		if cornerDirection ~= 0 then
			local cornerWidth = BuildingConfig.GetFootprintSize("Wall").Z
			GeneratorKit.NewPart({
				Name = "PerimeterCornerCap",
				Size = Vector3.new(cornerWidth, sizeY, footprint.Z),
				CFrame = worldCFrame * CFrame.new(cornerDirection * (footprint.X / 2 + cornerWidth / 2), sizeY / 2, 0),
				Material = wallMaterial,
				Color = wallColor,
				Parent = model,
			})
		end
		local braceSpacing = if footprint.X > 30 then 12 else 3
		for x = -footprint.X / 2 + 2, footprint.X / 2 - 2, braceSpacing do
			GeneratorKit.NewPart({
				Name = "WallBrace",
				Size = Vector3.new(if defenseTier >= 3 then 0.9 else 0.55, sizeY + 0.8, footprint.Z + 0.5),
				CFrame = worldCFrame * CFrame.new(x, (sizeY + 0.8) / 2, 0),
				Material = if defenseTier == 1 then Enum.Material.Wood else Enum.Material.DiamondPlate,
				Color = Color3.fromRGB(58, 55, 50),
				CanCollide = false,
				Parent = model,
			})
		end
		if defenseTier >= 2 then
			GeneratorKit.NewPart({
				Name = "WallFoundation",
				Size = Vector3.new(footprint.X, 1.6 + defenseTier * 0.22, footprint.Z + 1.2),
				CFrame = worldCFrame * CFrame.new(0, 0.8, 0),
				Material = if defenseTier == 2 then Enum.Material.Rock else Enum.Material.DiamondPlate,
				Color = Color3.fromRGB(72, 74, 73),
				Parent = model,
			})
		end
		if defenseTier >= 3 then
			GeneratorKit.NewPart({
				Name = "WallArmorBand",
				Size = Vector3.new(footprint.X - 1, 1.15, footprint.Z + 0.35),
				CFrame = worldCFrame * CFrame.new(0, sizeY * 0.66, 0),
				Material = Enum.Material.DiamondPlate,
				Color = Color3.fromRGB(86, 92, 93),
				CanCollide = false,
				Parent = model,
			})
		end
		if defenseTier >= 4 then
			GeneratorKit.NewPart({
				Name = "PoweredWallStatus",
				Size = Vector3.new(footprint.X - 3, 0.34, 0.24),
				CFrame = worldCFrame * CFrame.new(0, sizeY - 1.25, -(footprint.Z / 2 + 0.14)),
				Material = Enum.Material.Glass,
				Color = Color3.fromRGB(88, 184, 188),
				CanCollide = false,
				Parent = model,
			})
			for x = -footprint.X / 2 + 12, footprint.X / 2 - 8, 24 do
				GeneratorKit.NewPart({
					Name = "FutureDefenseMount",
					Size = Vector3.new(2.2, 0.8, footprint.Z + 1),
					CFrame = worldCFrame * CFrame.new(x, sizeY + 0.4, 0),
					Material = Enum.Material.Metal,
					Color = Color3.fromRGB(58, 68, 73),
					CanCollide = false,
					Parent = model,
				})
			end
		end
	else
		GeneratorKit.NewPart({
			Name = "StructureFoundation",
			Size = Vector3.new(footprint.X, 0.5, footprint.Z),
			CFrame = worldCFrame * CFrame.new(0, 0.25, 0),
			Material = Enum.Material.Slate,
			Color = Color3.fromRGB(62, 60, 55),
			Parent = model,
		})
		labelHost = GeneratorKit.NewPart({
			Name = "Body",
			Size = Vector3.new(footprint.X - 1, sizeY, footprint.Z - 1),
			CFrame = worldCFrame * CFrame.new(0, 0.5 + sizeY / 2, 0),
			Material = material,
			Color = color:Lerp(Color3.fromRGB(54, 54, 51), 0.22),
			Parent = model,
		})
		GeneratorKit.NewPart({
			Name = "RoofCap",
			Size = Vector3.new(footprint.X + 0.6, 0.55, footprint.Z + 0.6),
			CFrame = worldCFrame * CFrame.new(0, sizeY + 0.775, 0),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(46, 49, 49),
			Parent = model,
		})
		GeneratorKit.NewPart({
			Name = "CategoryAccent",
			Size = Vector3.new(footprint.X - 2, 0.4, 0.22),
			CFrame = worldCFrame * CFrame.new(0, sizeY * 0.72, -(footprint.Z - 1) / 2 - 0.12),
			Material = Enum.Material.Glass,
			Color = color,
			CanCollide = false,
			Parent = model,
		})
	end

	-- Distinct functional silhouettes keep the settlement readable without
	-- relying on labels. These lightweight props sit inside the configured
	-- footprint and also provide world-state anchors for Storage/Production.
	if structure.BuildingId == "Storage" then
		for index, offset in {
			Vector3.new(-2.1, 1.1, -1.8),
			Vector3.new(1.8, 1.1, -1.6),
			Vector3.new(0, 1.1, 1.8),
		} do
			GeneratorKit.NewPart({
				Name = `SupplyCrate{index}`,
				Size = Vector3.new(2.5, 2.2, 2.2),
				CFrame = worldCFrame * CFrame.new(offset),
				Material = Enum.Material.WoodPlanks,
				Color = Color3.fromRGB(105, 78, 49),
				CanCollide = false,
				Parent = model,
			})
		end
		local storagePrompt = Instance.new("ProximityPrompt")
		storagePrompt.Name = "StoragePrompt"
		storagePrompt.ObjectText = "Base Storage"
		storagePrompt.ActionText = "Deposit / Withdraw"
		storagePrompt.MaxActivationDistance = 12
		storagePrompt.RequiresLineOfSight = false
		storagePrompt.Parent = labelHost
		labelHost:SetAttribute("OwnerUserId", userId)
		CollectionService:AddTag(labelHost, "BaseStorageTerminal")
	elseif structure.BuildingId == "Workbench" then
		GeneratorKit.NewPart({
			Name = "WorkSurface",
			Size = Vector3.new(7.5, 0.5, 3.4),
			CFrame = worldCFrame * CFrame.new(0, 3.1, -0.8),
			Material = Enum.Material.WoodPlanks,
			Color = Color3.fromRGB(102, 73, 46),
			CanCollide = false,
			Parent = model,
		})
		for index, x in { -2.2, 0, 2.2 } do
			GeneratorKit.NewPart({
				Name = `BenchTool{index}`,
				Size = Vector3.new(0.35, 0.35, 2.1),
				CFrame = worldCFrame * CFrame.new(x, 3.55, -0.8) * CFrame.Angles(0, math.rad(index * 18), 0),
				Material = Enum.Material.Metal,
				Color = Color3.fromRGB(133, 136, 130),
				CanCollide = false,
				Parent = model,
			})
		end
	elseif structure.BuildingId == "Generator" then
		local engine = GeneratorKit.NewPart({
			Name = "GeneratorEngine",
			Size = Vector3.new(6.5, 4.2, 5.5),
			CFrame = worldCFrame * CFrame.new(0, 3, 0),
			Material = Enum.Material.CorrodedMetal,
			Color = Color3.fromRGB(82, 76, 60),
			CanCollide = false,
			Parent = model,
		})
		GeneratorKit.NewPart({
			Name = "GeneratorCoil",
			Size = Vector3.new(4.8, 2.2, 2.2),
			CFrame = worldCFrame * CFrame.new(0, 3.2, -3) * CFrame.Angles(0, 0, math.rad(90)),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(173, 121, 55),
			Shape = Enum.PartType.Cylinder,
			CanCollide = false,
			Parent = model,
		})
		local generatorLight = Instance.new("PointLight")
		generatorLight.Color = Color3.fromRGB(239, 176, 89)
		generatorLight.Brightness = 0.35
		generatorLight.Range = 8
		generatorLight.Shadows = false
		generatorLight.Parent = engine
	elseif structure.BuildingId == "ResourceProcessor" then
		local productionProfile = definition and definition.ProductionProfile
		model:SetAttribute("ProductionState", "Empty")
		model:SetAttribute("ProductionCompletesAt", 0)
		model:SetAttribute("MachineAppearanceTier", if productionProfile then productionProfile.AppearanceTier else 1)
		GeneratorKit.NewPart({
			Name = "InputCrate",
			Size = Vector3.new(3.2, 2.2, 3),
			CFrame = worldCFrame * CFrame.new(-4, 1.35, -2.8),
			Material = Enum.Material.WoodPlanks,
			Color = Color3.fromRGB(104, 75, 48),
			CanCollide = false,
			Parent = model,
		})
		local outputCrate = GeneratorKit.NewPart({
			Name = "OutputCrate",
			Size = Vector3.new(3.2, 2.2, 3),
			CFrame = worldCFrame * CFrame.new(4, 1.35, -2.8),
			Material = Enum.Material.WoodPlanks,
			Color = Color3.fromRGB(112, 88, 51),
			Transparency = 0.55,
			CanCollide = false,
			Parent = model,
		})
		local rotor = GeneratorKit.NewPart({
			Name = "MachineRotor",
			Size = Vector3.new(3.6, 3.6, 3.6),
			CFrame = worldCFrame * CFrame.new(0, 5, -4.1) * CFrame.Angles(0, 0, math.rad(90)),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(118, 112, 91),
			Shape = Enum.PartType.Cylinder,
			CanCollide = false,
			Parent = model,
		})
		rotor:SetAttribute("ProductionRotor", true)
		local statusPanel = GeneratorKit.NewPart({
			Name = "ProductionStatusPanel",
			Size = Vector3.new(3.2, 2.2, 0.6),
			CFrame = worldCFrame * CFrame.new(0, 4.2, -(footprint.Z - 1) / 2 - 0.5),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(40, 44, 43),
			CanCollide = false,
			Parent = model,
		})
		local statusLamp = GeneratorKit.NewPart({
			Name = "ProductionStatusLamp",
			Size = Vector3.new(0.65, 0.65, 0.3),
			CFrame = statusPanel.CFrame * CFrame.new(0, 0.45, -0.46),
			Material = Enum.Material.Glass,
			Color = Color3.fromRGB(112, 109, 92),
			CanCollide = false,
			Parent = model,
		})
		local lampLight = Instance.new("PointLight")
		lampLight.Name = "StatusLight"
		lampLight.Brightness = 0.25
		lampLight.Range = 7
		lampLight.Shadows = false
		lampLight.Parent = statusLamp
		local productionPrompt = Instance.new("ProximityPrompt")
		productionPrompt.Name = "ProductionPrompt"
		productionPrompt.ObjectText = "Resource Processor • EMPTY"
		productionPrompt.ActionText = "Manage Production"
		productionPrompt.MaxActivationDistance = 12
		productionPrompt.RequiresLineOfSight = false
		productionPrompt.Parent = statusPanel
		statusPanel:SetAttribute("OwnerUserId", userId)
		statusPanel:SetAttribute("StructureId", structure.Id)
		statusPanel:SetAttribute("OutputCrateName", outputCrate.Name)
		statusPanel:SetAttribute("ProductionState", "Empty")
		statusPanel:SetAttribute("CompletesAt", 0)
		CollectionService:AddTag(statusPanel, "BaseProductionMachine")
	elseif structure.BuildingId == "DefenseControl" then
		GeneratorKit.NewPart({
			Name = "WarningMast",
			Size = Vector3.new(0.6, 8, 0.6),
			CFrame = worldCFrame * CFrame.new(0, 5, 0),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(74, 72, 66),
			CanCollide = false,
			Parent = model,
		})
		GeneratorKit.NewPart({
			Name = "WarningBar",
			Size = Vector3.new(3.5, 0.45, 0.45),
			CFrame = worldCFrame * CFrame.new(0, 8.8, 0),
			Material = Enum.Material.Glass,
			Color = Color3.fromRGB(176, 86, 67),
			CanCollide = false,
			Parent = model,
		})
	elseif structure.BuildingId == "SurvivorQuarters" then
		for index, x in { -3.5, 0, 3.5 } do
			GeneratorKit.NewPart({
				Name = `QuarterWindow{index}`,
				Size = Vector3.new(2.1, 1.6, 0.25),
				CFrame = worldCFrame * CFrame.new(x, 3.6, -(footprint.Z - 1) / 2 - 0.14),
				Material = Enum.Material.Glass,
				Color = Color3.fromRGB(221, 180, 116),
				CanCollide = false,
				Parent = model,
			})
		end
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(150, 26)
	billboard.StudsOffset = Vector3.new(0, labelOffsetY, 0)
	billboard.MaxDistance = 38
	billboard.LightInfluence = 0
	billboard.Parent = labelHost

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = if definition and definition.DefenseTier
		then `{definition.Name}  •  T{definition.DefenseTier} {definition.TierLabel or ""}`
		elseif definition then `{definition.Name} (Lv{structure.Level})`
		else structure.BuildingId
	label.Parent = billboard

	if definition and definition.NextTierBuildingId then
		labelHost:SetAttribute("OwnerUserId", userId)
		labelHost:SetAttribute("StructureId", structure.Id)
		labelHost:SetAttribute("BuildingId", structure.BuildingId)
		local upgradePrompt = Instance.new("ProximityPrompt")
		upgradePrompt.Name = "UpgradePrompt"
		upgradePrompt.ObjectText = if definition.TierLabel then `{definition.Name} • {definition.TierLabel}` else definition.Name
		upgradePrompt.ActionText = "Upgrade"
		upgradePrompt.MaxActivationDistance = 14
		upgradePrompt.RequiresLineOfSight = false
		upgradePrompt.Parent = labelHost
		CollectionService:AddTag(labelHost, "BaseUpgradeableStructure")
	end

	model.Parent = container

	if animateConstruction then
		model:SetAttribute("ConstructionState", "Building")
		CollectionService:AddTag(model, "BaseConstructionInProgress")
		local foundations: { BasePart } = {}
		local majorPieces: { BasePart } = {}
		local details: { BasePart } = {}
		local finalTransparency: { [BasePart]: number } = {}
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				finalTransparency[descendant] = descendant.Transparency
				descendant.Transparency = 1
				if string.find(descendant.Name, "Foundation") or string.find(descendant.Name, "Crate") then
					table.insert(foundations, descendant)
				elseif descendant.Name == "Body" or descendant.Name == "GatePost" or descendant.Name == "GeneratorEngine" then
					table.insert(majorPieces, descendant)
				else
					table.insert(details, descendant)
				end
			end
		end
		local smokeHost = foundations[1] or majorPieces[1] or details[1]
		if smokeHost then
			local dust = Instance.new("Smoke")
			dust.Name = "ConstructionDust"
			dust.Color = Color3.fromRGB(151, 132, 101)
			dust.Opacity = 0.18
			dust.RiseVelocity = 3
			dust.Size = 5
			dust.Parent = smokeHost
			task.delay(0.9, function()
				if dust.Parent then
					dust:Destroy()
				end
			end)
		end
		local function reveal(parts: { BasePart })
			for _, part in parts do
				if part.Parent then
					part.Transparency = finalTransparency[part] or 0
				end
			end
		end
		reveal(foundations)
		task.spawn(function()
			task.wait(0.28)
			reveal(majorPieces)
			task.wait(0.42)
			reveal(details)
			task.wait(0.35)
			if model.Parent then
				model:SetAttribute("ConstructionState", "Complete")
				model:SetAttribute("ConstructionCompletedAt", Workspace:GetServerTimeNow())
				CollectionService:RemoveTag(model, "BaseConstructionInProgress")
				CollectionService:AddTag(model, "BaseConstructionCompleted")
			end
		end)
	else
		model:SetAttribute("ConstructionState", "Complete")
	end

	-- A pad-linked structure is now real geometry — its ghost (if any is
	-- still present; migrated structures never had one) must not linger
	-- alongside it. Safe no-op if already removed.
	if structure.PadId then
		local baseModel = findBaseModel(userId)
		local padsContainer = baseModel and baseModel:FindFirstChild("BlueprintPads")
		local ghost = padsContainer and padsContainer:FindFirstChild(structure.PadId)
		if ghost then
			ghost:Destroy()
		end
	end
end

function PersonalBaseGenerator.UpdateProductionVisual(userId: number, session: any)
	local container = structuresContainer(userId)
	if not container then
		return
	end
	for structureId, structure in session.Structures do
		if structure.BuildingId == "ResourceProcessor" then
			local model = container:FindFirstChild(structureId)
			if model and model:IsA("Model") then
				local activeJob = nil
				for _, job in session.ProductionJobs do
					if job.MachineStructureId == structureId and not job.Collected then
						activeJob = job
						break
					end
				end
				local state = "Empty"
				if activeJob then
					state = if os.time() >= activeJob.CompletesAt then "Ready" else "Running"
				end
				model:SetAttribute("ProductionState", state)
				model:SetAttribute("ProductionCompletesAt", if activeJob then activeJob.CompletesAt else 0)
				model:SetAttribute("ProductionRecipeId", if activeJob then activeJob.RecipeId else "")
				local panel = model:FindFirstChild("ProductionStatusPanel", true)
				local lamp = model:FindFirstChild("ProductionStatusLamp", true)
				local outputCrate = model:FindFirstChild("OutputCrate", true)
				local stateColor = if state == "Ready"
					then Color3.fromRGB(107, 201, 111)
					elseif state == "Running" then Color3.fromRGB(226, 165, 76)
					else Color3.fromRGB(112, 109, 92)
				if lamp and lamp:IsA("BasePart") then
					lamp.Color = stateColor
					local light = lamp:FindFirstChild("StatusLight")
					if light and light:IsA("PointLight") then
						light.Color = stateColor
						light.Enabled = state ~= "Empty"
					end
				end
				if outputCrate and outputCrate:IsA("BasePart") then
					outputCrate.Transparency = if state == "Ready" then 0 else 0.55
				end
				if panel and panel:IsA("BasePart") then
					panel:SetAttribute("ProductionState", state)
					panel:SetAttribute("CompletesAt", if activeJob then activeJob.CompletesAt else 0)
					local prompt = panel:FindFirstChild("ProductionPrompt")
					if prompt and prompt:IsA("ProximityPrompt") then
						local recipe = if activeJob then ProductionRecipeConfig.Get(activeJob.RecipeId) else nil
						prompt.ObjectText = if recipe then `{recipe.Name} • {string.upper(state)}` else `Resource Processor • {string.upper(state)}`
						prompt.ActionText = if state == "Ready" then "Collect Output" else "Manage Production"
					end
				end
			end
		end
	end
end

function PersonalBaseGenerator.RemoveStructure(userId: number, structureId: string)
	local container = structuresContainer(userId)
	if not container then
		return
	end
	local existing = container:FindFirstChild(structureId)
	if existing then
		existing:Destroy()
	end
end

-- ---------------------------------------------------------------------
-- Top-level Build
-- ---------------------------------------------------------------------

function PersonalBaseGenerator.Build(root: Model, userId: number, origin: CFrame, session: any?): Model
	GeneratorKit.CleanupPrevious(root, tostring(userId))

	local model = Instance.new("Model")
	model.Name = tostring(userId)
	model:SetAttribute("BaseLayoutVersion", 6)
	model:SetAttribute("OwnerUserId", userId)
	model:SetAttribute("DesignLanguage", "SurvivalTycoon")
	model:SetAttribute("CoopReady", true)
	model:SetAttribute("WorldShape", "Rectangle")
	model:SetAttribute("WorldWidth", WORLD_WIDTH)
	model:SetAttribute("WorldDepth", WORLD_DEPTH)
	model:SetAttribute("SettlementWidth", SETTLEMENT_WIDTH)
	model:SetAttribute("SettlementDepth", SETTLEMENT_DEPTH)
	model:SetAttribute("SettlementToForestBufferX", FOREST_INNER_HALF_WIDTH - PersonalBaseConfig.PlotBounds.HalfWidth)
	model:SetAttribute("SettlementToForestBufferZ", FOREST_INNER_HALF_DEPTH - PersonalBaseConfig.PlotBounds.HalfDepth)
	model:SetAttribute("ForestBandThicknessX", FOREST_OUTER_HALF_WIDTH - FOREST_INNER_HALF_WIDTH)
	model:SetAttribute("ForestBandThicknessZ", FOREST_OUTER_HALF_DEPTH - FOREST_INNER_HALF_DEPTH)

	-- The Civilization Core sits forward of the raw origin — PortalDestinationGenerator
	-- builds the arrival platform + return portal AT the raw origin (see
	-- below), so the Core (and PersonalBaseConfig.CoreLocalPosition, which
	-- BuildingService's protected-zone check uses) is deliberately offset to
	-- avoid overlapping that arrival geometry.
	buildGround(model, origin)
	buildForestPerimeter(model, origin)
	buildEntrance(model, origin)
	buildWayfindingAndLights(model, origin)
	buildCivilizationCore(model, origin * CFrame.new(CORE_OFFSET))
	buildStarterShelter(model, origin)
	buildStarterDropBox(model, origin)
	buildTraderTerminal(model, origin)
	buildBlueprintPads(model, origin, session)
	buildAttackRouteAnchors(model, origin)

	model.Parent = root

	-- Arrival platform + the interactable ReturnPortal back to Haven — reuses
	-- the exact same generator every biome/Tutorial destination already
	-- uses, so travel back to Haven works via the identical, already-proven
	-- ReturnPortalController/PortalService contract (PortalId = the same
	-- "PersonalBase_<userId>" id PortalDestinationConfig.Get parses).
	local destinationResult = PortalDestinationGenerator.Build(model, {
		id = `PersonalBase_{userId}`,
		displayName = "Personal Base",
		realOrigin = origin,
		arrivalAnchorName = "Arrival_PersonalBase",
		returnAnchorName = "ReturnLanding_PersonalBase",
		accentColor = Color3.fromRGB(140, 110, 255),
	})

	-- Personal Base-specific portal treatment. The shared destination builder
	-- remains unchanged for biome worlds; only this Base instance loses the
	-- oversized emissive arrival disc and excessive point-light bloom.
	local arrivalPlatform = destinationResult.Model:FindFirstChild("ArrivalPlatform")
	if arrivalPlatform and arrivalPlatform:IsA("BasePart") then
		arrivalPlatform.Size = Vector3.new(1, 28, 28)
		arrivalPlatform.CFrame = origin * CFrame.new(0, -0.5, 0) * CFrame.Angles(0, 0, math.rad(90))
		arrivalPlatform.Material = Enum.Material.Pavement
		arrivalPlatform.Color = Color3.fromRGB(88, 84, 75)
	end
	local arrivalRim = destinationResult.Model:FindFirstChild("ArrivalPlatformRim")
	if arrivalRim and arrivalRim:IsA("BasePart") then
		arrivalRim.Size = Vector3.new(0.24, 29, 29)
		arrivalRim.CFrame = origin * CFrame.new(0, 0.12, 0) * CFrame.Angles(0, 0, math.rad(90))
		arrivalRim.Material = Enum.Material.DiamondPlate
		arrivalRim.Color = Color3.fromRGB(101, 94, 80)
		arrivalRim.Transparency = 0
		local oldGlow = arrivalRim:FindFirstChildOfClass("PointLight")
		if oldGlow then
			oldGlow:Destroy()
		end
	end
	local returnMembrane = destinationResult.Model:FindFirstChild("ReturnPortalMembrane")
	if returnMembrane and returnMembrane:IsA("BasePart") then
		local portalPosition = origin:PointToWorldSpace(BASE_RETURN_PORTAL_LOCAL_POSITION)
		local portalCFrame = CFrame.lookAt(portalPosition, Vector3.new(origin.Position.X, portalPosition.Y, origin.Position.Z))
		destinationResult.Model:SetAttribute("BaseReturnPortalLandmark", true)
		destinationResult.Model:SetAttribute("ReturnPortalLocalPosition", BASE_RETURN_PORTAL_LOCAL_POSITION)

		returnMembrane.Size = Vector3.new(7.2, 9.2, 0.45)
		returnMembrane.CFrame = portalCFrame * CFrame.new(0, 5, 0)
		returnMembrane.Color = Color3.fromRGB(128, 112, 190)
		returnMembrane.Transparency = 0.43
		local prompt = returnMembrane:FindFirstChild("ReturnPrompt")
		if prompt and prompt:IsA("ProximityPrompt") then
			prompt.ObjectText = "SURVIVOR HAVEN"
			prompt.ActionText = "Return to Hub"
			prompt.MaxActivationDistance = 16
			prompt.HoldDuration = 0.15
		end

		local frameHeader = destinationResult.Model:FindFirstChild("ReturnPortalFrame")
		if frameHeader and frameHeader:IsA("BasePart") then
			frameHeader.Size = Vector3.new(10.4, 1.5, 1.3)
			frameHeader.CFrame = portalCFrame * CFrame.new(0, 10.35, 0)
			frameHeader.Material = Enum.Material.CorrodedMetal
			frameHeader.Color = Color3.fromRGB(56, 61, 64)
			frameHeader.Transparency = 0

			local sign = Instance.new("BillboardGui")
			sign.Name = "ReturnToHubSign"
			sign.Size = UDim2.fromOffset(280, 66)
			sign.StudsOffset = Vector3.new(0, 2.1, 0)
			sign.MaxDistance = 75
			sign.LightInfluence = 0
			sign.AlwaysOnTop = false
			sign.Parent = frameHeader
			local signBackground = Instance.new("Frame")
			signBackground.Size = UDim2.fromScale(1, 1)
			signBackground.BackgroundColor3 = Color3.fromRGB(18, 22, 24)
			signBackground.BackgroundTransparency = 0.08
			signBackground.BorderSizePixel = 0
			signBackground.Parent = sign
			local signCorner = Instance.new("UICorner")
			signCorner.CornerRadius = UDim.new(0, 7)
			signCorner.Parent = signBackground
			local signStroke = Instance.new("UIStroke")
			signStroke.Color = Color3.fromRGB(126, 202, 205)
			signStroke.Thickness = 1.5
			signStroke.Transparency = 0.15
			signStroke.Parent = signBackground
			local signTitle = Instance.new("TextLabel")
			signTitle.BackgroundTransparency = 1
			signTitle.Size = UDim2.fromScale(1, 0.62)
			signTitle.Font = Enum.Font.GothamBlack
			signTitle.TextScaled = true
			signTitle.TextColor3 = Color3.fromRGB(235, 240, 237)
			signTitle.Text = "RETURN TO HUB"
			signTitle.Parent = signBackground
			local signSubtitle = Instance.new("TextLabel")
			signSubtitle.BackgroundTransparency = 1
			signSubtitle.Position = UDim2.fromScale(0, 0.6)
			signSubtitle.Size = UDim2.fromScale(1, 0.34)
			signSubtitle.Font = Enum.Font.GothamBold
			signSubtitle.TextScaled = true
			signSubtitle.TextColor3 = Color3.fromRGB(126, 202, 205)
			signSubtitle.Text = "SURVIVOR HAVEN"
			signSubtitle.Parent = signBackground
		end

		GeneratorKit.NewPart({
			Name = "ReturnPortalApron",
			Size = Vector3.new(14, 0.3, 10),
			CFrame = portalCFrame * CFrame.new(0, 0.15, 0),
			Material = Enum.Material.DiamondPlate,
			Color = Color3.fromRGB(74, 73, 67),
			Parent = destinationResult.Model,
		})
		for _, side in { -1, 1 } do
			local post = GeneratorKit.NewPart({
				Name = if side < 0 then "ReturnPortalPostLeft" else "ReturnPortalPostRight",
				Size = Vector3.new(1.35, 10.4, 1.35),
				CFrame = portalCFrame * CFrame.new(side * 4.45, 5.2, 0),
				Material = Enum.Material.CorrodedMetal,
				Color = Color3.fromRGB(56, 61, 64),
				Parent = destinationResult.Model,
			})
			local lamp = GeneratorKit.NewPart({
				Name = "ReturnPortalLamp",
				Size = Vector3.new(0.8, 1.2, 0.55),
				CFrame = post.CFrame * CFrame.new(0, 3.55, -0.75),
				Material = Enum.Material.Glass,
				Color = Color3.fromRGB(126, 202, 205),
				CanCollide = false,
				Parent = destinationResult.Model,
			})
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(151, 217, 215)
			light.Brightness = 0.65
			light.Range = 16
			light.Shadows = true
			light.Parent = lamp
		end
	end
	local arrivalAnchor = destinationResult.ArrivalAnchor
	local coreWorld = origin:PointToWorldSpace(CORE_OFFSET)
	arrivalAnchor.CFrame = CFrame.lookAt(
		arrivalAnchor.Position,
		Vector3.new(coreWorld.X, arrivalAnchor.Position.Y, coreWorld.Z)
	)

	local container = Instance.new("Model")
	container.Name = "Structures"
	container.Parent = model

	if session then
		for _, structure in session.Structures do
			-- The Core's bespoke visual is already built above via
			-- buildCivilizationCore — skip it here so the generic
			-- placeholder-box builder doesn't draw a second, overlapping
			-- object for it.
			if structure.BuildingId ~= "CivilizationCore" then
				PersonalBaseGenerator.BuildStructure(userId, origin, structure)
			end
		end
		PersonalBaseGenerator.UpdateProductionVisual(userId, session)
	end

	return model
end

return PersonalBaseGenerator
