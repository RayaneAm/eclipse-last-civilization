--!strict
-- Parametric hero landmarks: one signature silhouette per biome, visible
-- from a meaningful distance to satisfy "no empty spaces" without
-- attempting full POI content (see Prompt 2 plan decision #6 — that's
-- reserved for dedicated per-biome prompts). Volcanic deliberately has no
-- entry here: its landmark is the terrain caldera built by TerrainGenerator.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BiomeConfig = require(ReplicatedStorage.Shared.Config.BiomeConfig)
local WorldMapConfig = require(ReplicatedStorage.Shared.Config.WorldMapConfig)
local TerrainSurface = require(ReplicatedStorage.Shared.Modules.TerrainSurface)
local GeneratorKit = require(script.Parent.GeneratorKit)

local LandmarkGenerator = {}

-- Forest Wildlands: an ancient ruin tower reclaimed by roots, leaning
-- slightly with age. Reuses the same "stacked jittered blocks" language as
-- Prompt 1's organic gate, at hero scale.
local function buildElderSpire(parent: Instance, position: Vector3, biome: BiomeConfig.BiomeDefinition)
	GeneratorKit.CleanupPrevious(parent, "ElderSpire")

	local model = Instance.new("Model")
	model.Name = "ElderSpire"

	local rng = GeneratorKit.Seeded(101)
	local baseCFrame = CFrame.new(position)
	local blockCount = 9
	local height = 140
	local blockHeight = height / blockCount
	local radius = 16

	for i = 1, blockCount do
		local taper = 1 - (i / blockCount) * 0.45
		GeneratorKit.NewPart({
			Name = `Block{i}`,
			Size = Vector3.new(radius * 2 * taper, blockHeight * 1.05, radius * 2 * taper),
			CFrame = baseCFrame
				* CFrame.new(rng:NextNumber(-3, 3), blockHeight * (i - 0.5), rng:NextNumber(-3, 3))
				* CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
			Material = Enum.Material.Rock,
			Color = Color3.fromRGB(80, 74, 62),
			Parent = model,
		})
	end

	-- Root/vine tendrils spiraling up the spire.
	local rootsModel = Instance.new("Model")
	rootsModel.Name = "Roots"
	rootsModel.Parent = model
	for arm = 1, 4 do
		local baseAngle = (arm / 4) * math.pi * 2
		for s = 1, 10 do
			local t = s / 10
			local segHeight = height * (0.15 + t * 0.8)
			local wrapAngle = baseAngle + t * math.pi * 1.2
			local wrapRadius = radius * (1.15 - t * 0.35)

			GeneratorKit.NewPart({
				Name = `Root{arm}_{s}`,
				Size = Vector3.new(1.6, height / 10 * 1.1, 1.6),
				CFrame = baseCFrame * CFrame.new(math.cos(wrapAngle) * wrapRadius, segHeight, math.sin(wrapAngle) * wrapRadius) * CFrame.Angles(0, wrapAngle, math.rad(15)),
				Material = Enum.Material.Wood,
				Color = Color3.fromRGB(52, 42, 30),
				CanCollide = false,
				Parent = rootsModel,
			})
		end
	end

	-- Glowing ancient emblem near the top.
	local emblem = GeneratorKit.NewPart({
		Name = "AncientEmblem",
		Size = Vector3.new(6, 6, 1.5),
		CFrame = baseCFrame * CFrame.new(0, height * 0.92, radius * 0.9),
		Material = Enum.Material.Neon,
		Color = biome.gate.accentColor,
		CanCollide = false,
		Parent = model,
	})
	local emblemLight = Instance.new("PointLight")
	emblemLight.Color = biome.gate.accentColor
	emblemLight.Brightness = 2
	emblemLight.Range = 40
	emblemLight.Parent = emblem
	CollectionService:AddTag(emblemLight, "AmbientFlicker")

	GeneratorKit.ScatterRubble(model, baseCFrame, radius * 2.5, 14, rng, Enum.Material.Rock, Color3.fromRGB(70, 65, 56))
	GeneratorKit.Finalize(model, "Block1")
	model.Parent = parent
end

-- Frozen Wasteland: a shattered skyscraper frozen mid-collapse, leaning hard
-- with each successive floor, encased in a translucent ice shell.
local function buildFrostfallSpire(parent: Instance, position: Vector3, biome: BiomeConfig.BiomeDefinition)
	GeneratorKit.CleanupPrevious(parent, "FrostfallSpire")

	local model = Instance.new("Model")
	model.Name = "FrostfallSpire"

	local rng = GeneratorKit.Seeded(202)
	local baseCFrame = CFrame.new(position)
	local floorCount = 11
	local height = 170
	local floorHeight = height / floorCount
	local width = 26

	local leanAccum = 0
	for i = 1, floorCount do
		leanAccum += rng:NextNumber(0.4, 1.4)
		local leanRadians = math.rad(leanAccum)

		GeneratorKit.NewPart({
			Name = `Floor{i}`,
			Size = Vector3.new(width * rng:NextNumber(0.9, 1.05), floorHeight * 1.06, width * 0.7),
			CFrame = baseCFrame * CFrame.new(0, floorHeight * (i - 0.5), 0) * CFrame.Angles(0, 0, leanRadians),
			Material = Enum.Material.Concrete,
			Color = Color3.fromRGB(72, 74, 78),
			Parent = model,
		})
	end

	-- Ice shell wrapping the whole tower.
	GeneratorKit.NewPart({
		Name = "IceShell",
		Size = Vector3.new(width * 1.4, height * 1.02, width * 1.1),
		CFrame = baseCFrame * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.rad(leanAccum * 0.55)),
		Material = Enum.Material.Ice,
		Color = Color3.fromRGB(210, 235, 245),
		Transparency = 0.35,
		CanCollide = false,
		Parent = model,
	})

	-- Icicles hanging from the leaning edge.
	local iciclesModel = Instance.new("Model")
	iciclesModel.Name = "Icicles"
	iciclesModel.Parent = model
	for i = 1, 8 do
		local icicleHeight = rng:NextNumber(6, 14)
		GeneratorKit.NewPart({
			Name = `Icicle{i}`,
			Size = Vector3.new(1.4, icicleHeight, 1.4),
			CFrame = baseCFrame
				* CFrame.new(rng:NextNumber(-width / 2, width / 2), rng:NextNumber(height * 0.3, height * 0.85), width * 0.4)
				* CFrame.Angles(0, 0, math.rad(leanAccum * 0.55) + math.pi),
			Material = Enum.Material.Ice,
			Color = Color3.fromRGB(220, 240, 250),
			Transparency = 0.1,
			CanCollide = false,
			Parent = iciclesModel,
		})
	end

	local crackLight = Instance.new("PointLight")
	crackLight.Color = biome.gate.accentColor
	crackLight.Brightness = 1.5
	crackLight.Range = 35
	crackLight.Parent = model:FindFirstChild(`Floor{floorCount}`)
	CollectionService:AddTag(crackLight, "AmbientFlicker")

	GeneratorKit.ScatterRubble(model, baseCFrame, width * 2, 12, rng, Enum.Material.Concrete, Color3.fromRGB(80, 82, 86))
	GeneratorKit.Finalize(model, "Floor1")
	model.Parent = parent
end

-- Nuclear City: a collapsed broadcast tower, its mast toppled at a dramatic
-- angle into a debris field, still crowned with a blinking warning light.
local function buildBroadcastTower(parent: Instance, position: Vector3, biome: BiomeConfig.BiomeDefinition)
	GeneratorKit.CleanupPrevious(parent, "BroadcastTower")

	local model = Instance.new("Model")
	model.Name = "BroadcastTower"

	local rng = GeneratorKit.Seeded(303)
	local baseCFrame = CFrame.new(position)
	local mastLength = 210
	local tiltRadians = math.rad(58)

	local mastCFrame = baseCFrame * CFrame.new(0, mastLength / 2 * math.cos(tiltRadians), mastLength / 2 * math.sin(tiltRadians)) * CFrame.Angles(tiltRadians, 0, 0)

	GeneratorKit.NewPart({
		Name = "Mast",
		Size = Vector3.new(4, mastLength, 4),
		CFrame = mastCFrame,
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(58, 58, 62),
		Parent = model,
	})

	-- Cross-braces along the mast for a lattice-truss silhouette.
	local bracesModel = Instance.new("Model")
	bracesModel.Name = "Braces"
	bracesModel.Parent = model
	for i = 1, 7 do
		local t = i / 8
		GeneratorKit.NewPart({
			Name = `Brace{i}`,
			Size = Vector3.new(9, 1, 1),
			CFrame = mastCFrame * CFrame.new(0, -mastLength / 2 + mastLength * t, 0) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-8, 8))),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(50, 50, 54),
			CanCollide = false,
			Parent = bracesModel,
		})
	end

	-- Blinking warning light at the tip.
	local tip = GeneratorKit.NewPart({
		Name = "WarningLight",
		Size = Vector3.new(2.5, 2.5, 2.5),
		CFrame = mastCFrame * CFrame.new(0, mastLength / 2 + 1.5, 0),
		Material = Enum.Material.Neon,
		Color = biome.gate.accentColor,
		Shape = Enum.PartType.Ball,
		CanCollide = false,
		Parent = model,
	})
	local warningLight = Instance.new("PointLight")
	warningLight.Color = biome.gate.accentColor
	warningLight.Brightness = 3
	warningLight.Range = 45
	warningLight.Parent = tip
	CollectionService:AddTag(warningLight, "AmbientFlicker")

	GeneratorKit.ScatterRubble(model, baseCFrame, 45, 20, rng, Enum.Material.Concrete, Color3.fromRGB(66, 66, 70))
	GeneratorKit.Finalize(model, "Mast")
	model.Parent = parent
end

-- Builds ONE biome's landmark around its own independent origin (see
-- WorldMapConfig.RealOrigin) — Prompt 2's portal architecture moved each
-- biome off Haven's shared origin, so this is now called once per biome
-- (from tools/BuildWorldMap.luau) rather than looping all 4 off one origin.
function LandmarkGenerator.Build(parent: Instance, origin: CFrame, biome: BiomeConfig.BiomeDefinition)
	local position = TerrainSurface.FindSurfacePosition(WorldMapConfig.GetLandmarkPosition(origin, biome))

	if biome.id == "ForestWildlands" then
		buildElderSpire(parent, position, biome)
	elseif biome.id == "FrozenWasteland" then
		buildFrostfallSpire(parent, position, biome)
	elseif biome.id == "NuclearCity" then
		buildBroadcastTower(parent, position, biome)
	end
	-- VolcanicCore intentionally has no part-based landmark — its terrain
	-- caldera (built by TerrainGenerator) is the landmark.
end

return LandmarkGenerator
