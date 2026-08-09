--!strict
-- The settlement's communal fire circle. This plot used to hold the Haven
-- Guide (NPC, booth, map stand, direction board, "HAVEN GUIDE" sign); that
-- whole installation is gone.
--
-- It is deliberately NOT replaced by another service. An arrival plaza in a
-- survivor camp wants somewhere to STAND — the spot every hub screenshot worth
-- imitating has players clustered around. Everything here is seating, warmth
-- and lived-in clutter: no prompts, no labels, no signage competing with the
-- Personal Base camp facing it across the arrival lane.

local GeneratorKit = require(script.Parent.GeneratorKit)

local CampCircleGenerator = {}

local SEAT_RING_RADIUS = 7.2
local STONE_RING_RADIUS = 2.6

local TIMBER = Color3.fromRGB(84, 63, 43)
local TIMBER_DARK = Color3.fromRGB(63, 48, 35)

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, material: Enum.Material, color: Color3, collide: boolean?): Part
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

local function buildFire(model: Instance, cf: CFrame)
	for index = 1, 11 do
		local angle = (index / 11) * math.pi * 2
		part(
			model,
			`FireRingStone{index}`,
			Vector3.new(1.05, 0.75 + (index % 3) * 0.12, 0.95),
			cf * CFrame.new(math.cos(angle) * STONE_RING_RADIUS, 1.05, math.sin(angle) * STONE_RING_RADIUS) * CFrame.Angles(0, angle, math.rad((index % 4) * 3)),
			Enum.Material.Rock,
			if index % 2 == 0 then Color3.fromRGB(110, 106, 99) else Color3.fromRGB(94, 90, 85),
			false
		)
	end
	for index, rotation in { 0, 58, 116, 174 } do
		part(model, `FireLog{index}`, Vector3.new(0.7, 0.7, 4), cf * CFrame.new(0, 1.25, 0) * CFrame.Angles(0, math.rad(rotation), math.rad(13)), Enum.Material.Wood, TIMBER_DARK, false)
	end
	local embers = part(model, "CampfireEmbers", Vector3.new(2.6, 0.6, 2.6), cf * CFrame.new(0, 1.1, 0), Enum.Material.Neon, Color3.fromRGB(238, 132, 54), false)
	embers.CastShadow = false
	local light = Instance.new("PointLight")
	light.Name = "CampfireLight"
	light.Color = Color3.fromRGB(255, 162, 88)
	light.Brightness = 2.2
	light.Range = 40
	light.Shadows = true
	light.Parent = embers

	local flame = Instance.new("ParticleEmitter")
	flame.Name = "CampfireFlame"
	flame.Color = ColorSequence.new(Color3.fromRGB(255, 189, 96), Color3.fromRGB(198, 74, 30))
	flame.Size = NumberSequence.new(2.2, 0)
	flame.Lifetime = NumberRange.new(0.6, 1.1)
	flame.Rate = 22
	flame.Speed = NumberRange.new(3.2, 4.6)
	flame.SpreadAngle = Vector2.new(11, 11)
	flame.LightEmission = 0.8
	flame.Parent = embers

	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "CampfireSmoke"
	smoke.Color = ColorSequence.new(Color3.fromRGB(120, 112, 106))
	smoke.Size = NumberSequence.new(1.6, 6)
	smoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	smoke.Lifetime = NumberRange.new(2.4, 3.6)
	smoke.Rate = 5
	smoke.Speed = NumberRange.new(3.5, 5)
	smoke.SpreadAngle = Vector2.new(14, 14)
	smoke.Parent = embers
end

-- Seating deliberately does NOT close the ring: two gaps keep the fire
-- approachable from the arrival lane and from the main street.
local function buildSeating(model: Instance, cf: CFrame)
	local seats = {
		{ angle = 30, kind = "log" },
		{ angle = 75, kind = "crate" },
		{ angle = 120, kind = "log" },
		{ angle = 205, kind = "log" },
		{ angle = 250, kind = "stump" },
		{ angle = 295, kind = "crate" },
		{ angle = 340, kind = "log" },
	}
	for index, seat in seats do
		local angle = math.rad(seat.angle)
		local seatCFrame = cf
			* CFrame.new(math.cos(angle) * SEAT_RING_RADIUS, 0, math.sin(angle) * SEAT_RING_RADIUS)
			* CFrame.Angles(0, -angle, 0)
		if seat.kind == "log" then
			part(model, `SeatingLog{index}`, Vector3.new(0.9, 0.9, 4.6), seatCFrame * CFrame.new(0, 1.5, 0) * CFrame.Angles(0, math.rad(90), 0), Enum.Material.Wood, Color3.fromRGB(92, 70, 48))
			for _, support in { -1.7, 1.7 } do
				part(model, "SeatingLogChock", Vector3.new(0.7, 1.1, 0.7), seatCFrame * CFrame.new(support, 0.9, 0), Enum.Material.Wood, TIMBER_DARK, false)
			end
		elseif seat.kind == "crate" then
			part(model, `SeatingCrate{index}`, Vector3.new(2.4, 1.9, 2.4), seatCFrame * CFrame.new(0, 1.4, 0) * CFrame.Angles(0, math.rad(11), 0), Enum.Material.WoodPlanks, Color3.fromRGB(99, 74, 50))
			part(model, "SeatingCrateCloth", Vector3.new(2.5, 0.2, 2.5), seatCFrame * CFrame.new(0, 2.4, 0) * CFrame.Angles(0, math.rad(11), 0), Enum.Material.Fabric, Color3.fromRGB(122, 108, 84), false)
		else
			part(model, `SeatingStump{index}`, Vector3.new(2.1, 1.9, 2.1), seatCFrame * CFrame.new(0, 1.4, 0), Enum.Material.Wood, Color3.fromRGB(84, 64, 44))
			part(model, "SeatingStumpTop", Vector3.new(2.2, 0.18, 2.2), seatCFrame * CFrame.new(0, 2.42, 0), Enum.Material.Wood, Color3.fromRGB(128, 101, 68), false)
		end
	end
end

-- Camp clutter at the clearing edge. Reads as "people live here" and gives the
-- silhouette some vertical interest without blocking any route.
local function buildCampClutter(model: Instance, cf: CFrame)
	part(model, "CampWoodStack", Vector3.new(3.4, 0.6, 2.6), cf * CFrame.new(-9.5, 0.95, 6.4), Enum.Material.Wood, Color3.fromRGB(94, 72, 50), false)
	for row = 0, 2 do
		for index = 0, 2 - row do
			part(model, "CampFirewood", Vector3.new(0.52, 0.52, 3), cf * CFrame.new(-9.5 + index * 0.58 + row * 0.29, 1.5 + row * 0.54, 6.4), Enum.Material.Wood, Color3.fromRGB(88, 66, 45), false)
		end
	end
	part(model, "CampBarrel", Vector3.new(2, 2.8, 2), cf * CFrame.new(9.8, 1.4, -5.6), Enum.Material.CorrodedMetal, Color3.fromRGB(96, 82, 62), false)
	part(model, "CampBarrelLid", Vector3.new(2.1, 0.24, 2.1), cf * CFrame.new(9.8, 2.9, -5.6), Enum.Material.Metal, Color3.fromRGB(72, 68, 62), false)
	part(model, "CampWaterTrough", Vector3.new(4.4, 1.4, 2.2), cf * CFrame.new(9.2, 0.9, 3.4) * CFrame.Angles(0, math.rad(-14), 0), Enum.Material.WoodPlanks, Color3.fromRGB(80, 62, 44), false)
	part(model, "CampWaterSurface", Vector3.new(4, 0.12, 1.8), cf * CFrame.new(9.2, 1.55, 3.4) * CFrame.Angles(0, math.rad(-14), 0), Enum.Material.Glass, Color3.fromRGB(88, 116, 118), false)

	-- Two leaning lantern posts frame the circle and carry the warm landmark
	-- light out past the fire's own falloff.
	for _, data in { { -10.5, -6.5, 6 }, { 10.2, 7.4, -7 } } do
		local postCFrame = cf * CFrame.new(data[1], 0, data[2]) * CFrame.Angles(0, 0, math.rad(data[3] * 0.5))
		part(model, "CampLanternPost", Vector3.new(0.45, 7.4, 0.45), postCFrame * CFrame.new(0, 3.7, 0), Enum.Material.Wood, TIMBER, false)
		part(model, "CampLanternArm", Vector3.new(1.8, 0.25, 0.25), postCFrame * CFrame.new(0.8, 7.1, 0), Enum.Material.Metal, Color3.fromRGB(74, 70, 66), false)
		local lantern = part(model, "CampLantern", Vector3.new(0.9, 1.2, 0.9), postCFrame * CFrame.new(1.5, 6.5, 0), Enum.Material.Glass, Color3.fromRGB(255, 205, 141), false)
		lantern.CastShadow = false
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 198, 132)
		light.Brightness = 1
		light.Range = 22
		light.Parent = lantern
	end
end

function CampCircleGenerator.Build(parent: Instance, campCFrame: CFrame): Model
	GeneratorKit.CleanupPrevious(parent, "CampCircle")
	local model = Instance.new("Model")
	model.Name = "CampCircle"
	buildFire(model, campCFrame)
	buildSeating(model, campCFrame)
	buildCampClutter(model, campCFrame)

	GeneratorKit.Finalize(model, "CampfireEmbers")
	model.Parent = parent
	return model
end

return CampCircleGenerator
