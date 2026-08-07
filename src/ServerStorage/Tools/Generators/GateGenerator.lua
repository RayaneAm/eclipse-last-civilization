--!strict
-- Portal Expedition Zone rework: builds one round biome portal recessed into
-- a shallow alcove carved into the colosseum wall (see ColosseumWallGenerator
-- for the surrounding solid wall piers, which this file's alcove is designed
-- to slot into exactly). Replaces the old rectangular pylon-crossbeam-
-- keystone "doorway" gate and its separate depth-illusion teaser props
-- (deleted: PortalTeaserGenerator.luau, buildVistaTeaser, buildBreachCornerSeals)
-- with: a real alcove (2 side walls + a back wall, all solid, all real
-- collision — no invisible-cube hack needed anymore), a fixed round stone/
-- metal ring frame, a small separately-animated inner energy ring, and a
-- circular energy disc that doubles as the existing GateBarrier part.
--
-- The 4 archStyle decorate*/atmosphere biome-flavor functions are unchanged
-- from before — only what CFrame/height/width they're attached to changed
-- (the alcove's side walls instead of pylons). Same reasoning: these already
-- read well per-biome; only the core shape needed to become round.
--
-- The GateAnchor part this places is what src/client/Controllers/GateController
-- hooks into (CollectionService tag "BiomeGate" + BiomeId attribute), and its
-- ActivationLight/ActivationParticles children are what that controller's
-- lock-state visuals and activation pulse animate — unchanged contract.

local CollectionService = game:GetService("CollectionService")
local GeneratorKit = require(script.Parent.GeneratorKit)
local PortalThresholdGenerator = require(script.Parent.PortalThresholdGenerator)

-- Alcove/ring dimensions. ALCOVE width formula must match
-- ColosseumWallGenerator.luau's own copy exactly — see that file's header
-- comment for why this is a small duplicated constant, not a shared module.
local BASE_ALCOVE_WIDTH = 22
local ALCOVE_WIDTH_MARGIN = 8
local ALCOVE_DEPTH = 8 -- shallow recess into the wall
local WALL_HEIGHT = 40 -- must match ColosseumWallGenerator.WALL_HEIGHT exactly, so silhouettes line up
local RING_OUTER_RADIUS_BASE = 11 -- x biome.gate.scale
local RING_THICKNESS = 2.2
local RING_GROUND_CLEARANCE = 3
local RING_SIDE_CLEARANCE = 1 -- gap between the ring's outer edge and the alcove side wall

-- Correction pass: the alcove floor used to sit flush with the plaza
-- (top surface ~0.6), while the ring already floated RING_GROUND_CLEARANCE
-- studs above that same ground reference — a real, visible ~2.4-stud gap
-- between the walkable floor and the ring's own bottom edge. Raising the
-- floor's top surface to exactly RING_GROUND_CLEARANCE means the ring now
-- sits flush on it, and it's also exactly where PortalThresholdGenerator's
-- new staircase's top step lands (that file's own STAIR_TOTAL_HEIGHT is a
-- duplicated copy of this same value — see its header comment).
local FLOOR_HEIGHT = RING_GROUND_CLEARANCE

-- Correction pass: matches ColosseumWallGenerator's own WALL_OVERLAP_STUDS —
-- the alcove's side walls now extend outward past the alcove's nominal
-- half-width by this much, so they deliberately overlap the wall piers
-- (which now build a few studs into the alcove's angular footprint from the
-- other side) instead of the two structures merely touching at an exact
-- theoretical seam.
local WALL_OVERLAP_STUDS = 4

local GateGenerator = {}

type GateBiome = {
	id: string,
	name: string,
	gate: {
		archStyle: "Organic" | "Shattered" | "Brutalist" | "Molten",
		primaryMaterial: Enum.Material,
		secondaryMaterial: Enum.Material,
		primaryColor: Color3,
		accentColor: Color3,
		scale: number,
	},
	isEndgame: boolean,
}

-- ---------------------------------------------------------------------
-- Alcove + ring core shape
-- ---------------------------------------------------------------------

local function buildAlcove(
	parent: Instance,
	anchorCFrame: CFrame,
	alcoveHalfWidth: number,
	sideWallInnerX: number,
	material: Enum.Material,
	color: Color3
): (CFrame, CFrame)
	local sideWallWidth = alcoveHalfWidth - sideWallInnerX
	local leftBaseCFrame = anchorCFrame * CFrame.new(-(sideWallInnerX + sideWallWidth / 2), 0, -ALCOVE_DEPTH / 2)
	local rightBaseCFrame = anchorCFrame * CFrame.new(sideWallInnerX + sideWallWidth / 2, 0, -ALCOVE_DEPTH / 2)

	-- The built wall part itself extends WALL_OVERLAP_STUDS further outward
	-- than the alcove's nominal half-width (matching ColosseumWallGenerator's
	-- own overlap budget), so it deliberately overlaps the wall pier instead
	-- of just touching it at the theoretical seam. leftBaseCFrame/
	-- rightBaseCFrame (returned below) stay at the nominal, un-widened
	-- position — decorations still attach exactly where they always did.
	local wallPartWidth = sideWallWidth + WALL_OVERLAP_STUDS
	local leftWallCFrame = anchorCFrame * CFrame.new(-(sideWallInnerX + wallPartWidth / 2), 0, -ALCOVE_DEPTH / 2)
	local rightWallCFrame = anchorCFrame * CFrame.new(sideWallInnerX + wallPartWidth / 2, 0, -ALCOVE_DEPTH / 2)

	for _, side in { { CFrame = leftWallCFrame, Name = "AlcoveWallLeft" }, { CFrame = rightWallCFrame, Name = "AlcoveWallRight" } } do
		GeneratorKit.NewPart({
			Name = side.Name,
			Size = Vector3.new(wallPartWidth, WALL_HEIGHT, ALCOVE_DEPTH),
			CFrame = side.CFrame * CFrame.new(0, WALL_HEIGHT / 2, 0),
			Material = material,
			Color = color,
			Parent = parent,
		})
	end

	GeneratorKit.NewPart({
		Name = "AlcoveBackWall",
		Size = Vector3.new(alcoveHalfWidth * 2, WALL_HEIGHT, 1.5),
		CFrame = anchorCFrame * CFrame.new(0, WALL_HEIGHT / 2, -ALCOVE_DEPTH),
		Material = material,
		Color = color,
		Parent = parent,
	})

	GeneratorKit.NewPart({
		Name = "AlcoveFloor",
		Size = Vector3.new(alcoveHalfWidth * 2, 0.6, ALCOVE_DEPTH),
		CFrame = anchorCFrame * CFrame.new(0, FLOOR_HEIGHT - 0.3, -ALCOVE_DEPTH / 2),
		Material = material,
		Color = color,
		Parent = parent,
	})

	-- Ground-level reference CFrames for decorate*/atmosphere attachment —
	-- same convention the old pylon-based leftCFrame/rightCFrame used
	-- (origin at ground level, decoration functions measure height upward
	-- from there), just repositioned to the alcove's own side walls.
	return leftBaseCFrame, rightBaseCFrame
end

-- Segmented ring (no native torus primitive in Roblox — same technique
-- EclipseCoreGenerator.buildOrbitRing already proved, written fresh here
-- since this ring is a thicker architectural frame in a different plane,
-- not a thin orbiting ring, different enough to not force a shared helper).
-- Lies in `centerCFrame`'s local XY plane (segments arranged around its Z
-- axis), so `centerCFrame`'s -Z should already point the way the ring faces.
local function buildRing(parent: Instance, name: string, centerCFrame: CFrame, radius: number, partThickness: number, segments: number, material: Enum.Material, color: Color3): Model
	local ringModel = Instance.new("Model")
	ringModel.Name = name

	local arcLength = (2 * math.pi * radius) / segments * 0.92
	for i = 0, segments - 1 do
		local angle = (i / segments) * math.pi * 2
		local segCFrame = centerCFrame * CFrame.new(math.cos(angle) * radius, math.sin(angle) * radius, 0) * CFrame.Angles(0, 0, angle)

		GeneratorKit.NewPart({
			Name = `Segment{i}`,
			Size = Vector3.new(partThickness, arcLength, partThickness * 0.7),
			CFrame = segCFrame,
			Material = material,
			Color = color,
			CanCollide = false,
			Parent = ringModel,
		})
	end

	ringModel.Parent = parent
	return ringModel
end

local function buildPortalCore(model: Model, anchorCFrame: CFrame, ringCenterY: number, ringOuterRadius: number, biome: GateBiome)
	local ringCenterCFrame = anchorCFrame * CFrame.new(0, ringCenterY, 0)

	-- Fixed, structural — never rotates or moves.
	buildRing(model, "PortalRing", ringCenterCFrame, ringOuterRadius, RING_THICKNESS, 20, biome.gate.primaryMaterial, biome.gate.primaryColor)
	buildRing(model, "PortalRingTrim", ringCenterCFrame * CFrame.new(0, 0, 0.3), ringOuterRadius - RING_THICKNESS * 0.8, RING_THICKNESS * 0.5, 20, biome.gate.secondaryMaterial, biome.gate.accentColor)

	-- The only rotating geometry in the whole portal — a small, clearly
	-- secondary energy detail, not the architectural frame.
	local innerRingRadius = ringOuterRadius - RING_THICKNESS * 1.6
	local innerRing = buildRing(model, "InnerEnergyRing", ringCenterCFrame * CFrame.new(0, 0, 0.6), innerRingRadius, 0.6, 16, Enum.Material.Neon, biome.gate.accentColor)
	innerRing:SetAttribute("Speed", 12)
	CollectionService:AddTag(innerRing, "SlowSpin")

	-- Energy opening — doubles as the existing GateBarrier part (same tag/
	-- attribute/Transparency contract GateController.applyBarrierVisual
	-- already tweens between locked/unlocked).
	local barrierRadius = innerRingRadius - 0.8
	local barrier = GeneratorKit.NewPart({
		Name = "GateBarrier",
		Size = Vector3.new(barrierRadius * 2, 0.5, barrierRadius * 2),
		CFrame = ringCenterCFrame * CFrame.new(0, 0, 0.9) * CFrame.Angles(math.rad(90), 0, 0),
		Material = Enum.Material.ForceField,
		Color = biome.gate.accentColor,
		Shape = Enum.PartType.Cylinder,
		Transparency = 0.6,
		CanCollide = true,
		Parent = model,
	})
	barrier:SetAttribute("BiomeId", biome.id)
	CollectionService:AddTag(barrier, "GateBarrier")

	return ringCenterCFrame
end

-- ---------------------------------------------------------------------
-- Biome flavor: unchanged from the previous pylon-based gate, only ever
-- called with a different (alcove side wall) CFrame/height/width now.
-- ---------------------------------------------------------------------

local function decorateOrganic(parent: Instance, sideLabel: string, pylonCFrame: CFrame, height: number, width: number, rng: Random, biome: GateBiome)
	local detailModel = Instance.new("Model")
	detailModel.Name = `Detailing_{sideLabel}`
	detailModel.Parent = parent

	for arm = 1, 3 do
		local sideSign = if arm % 2 == 0 then 1 else -1
		local startAngle = rng:NextNumber(-0.3, 0.3)
		local segments = 8
		for s = 1, segments do
			local t = s / segments
			local curve = math.sin(t * math.pi * 0.7 + startAngle) * width * 0.9
			local segCFrame = pylonCFrame
				* CFrame.new(sideSign * (width * 0.5 + curve * 0.3), height * (1 - t) - 1, curve * sideSign * 0.4)
				* CFrame.Angles(0, rng:NextNumber(0, math.pi), math.rad(t * 25))

			GeneratorKit.NewPart({
				Name = `Root{arm}_{s}`,
				Size = Vector3.new((1 - t * 0.6) * 1.6, height / segments * 1.1, (1 - t * 0.6) * 1.6),
				CFrame = segCFrame,
				Material = Enum.Material.Wood,
				Color = Color3.fromRGB(58, 46, 34),
				CanCollide = false,
				Parent = detailModel,
			})
		end
	end

	for i = 1, 5 do
		local light = Instance.new("PointLight")
		light.Color = biome.gate.accentColor
		light.Brightness = 1.5
		light.Range = 10

		local shard = GeneratorKit.NewPart({
			Name = `MossShard{i}`,
			Size = Vector3.new(0.8, 0.8, 0.8),
			CFrame = pylonCFrame * CFrame.new(rng:NextNumber(-width, width) * 0.6, rng:NextNumber(2, height - 2), rng:NextNumber(-2, 2)),
			Material = Enum.Material.Neon,
			Color = biome.gate.accentColor,
			CanCollide = false,
			Parent = detailModel,
		})
		light.Parent = shard
		CollectionService:AddTag(light, "AmbientFlicker")
	end
end

local function decorateShattered(parent: Instance, sideLabel: string, pylonCFrame: CFrame, height: number, width: number, depth: number, rng: Random, biome: GateBiome)
	local detailModel = Instance.new("Model")
	detailModel.Name = `Detailing_{sideLabel}`
	detailModel.Parent = parent

	GeneratorKit.NewPart({
		Name = "IceShell",
		Size = Vector3.new(width * 1.25, height * 1.02, depth * 1.25),
		CFrame = pylonCFrame * CFrame.new(0, height / 2, 0),
		Material = Enum.Material.Ice,
		Color = Color3.fromRGB(210, 235, 245),
		Transparency = 0.35,
		CanCollide = false,
		Parent = detailModel,
	})

	for i = 1, 5 do
		local icicleHeight = rng:NextNumber(2, 5)
		GeneratorKit.NewPart({
			Name = `Icicle{i}`,
			Size = Vector3.new(0.6, icicleHeight, 0.6),
			CFrame = pylonCFrame * CFrame.new(rng:NextNumber(-width, width) * 0.4, height - icicleHeight / 2, rng:NextNumber(-1, 1)),
			Material = Enum.Material.Ice,
			Color = Color3.fromRGB(220, 240, 250),
			Transparency = 0.1,
			CanCollide = false,
			Parent = detailModel,
		})
	end

	for i = 1, 4 do
		local light = Instance.new("PointLight")
		light.Color = biome.gate.accentColor
		light.Brightness = 1.2
		light.Range = 8

		local crack = GeneratorKit.NewPart({
			Name = `Crack{i}`,
			Size = Vector3.new(0.3, rng:NextNumber(3, 7), 0.3),
			CFrame = pylonCFrame
				* CFrame.new(rng:NextNumber(-width, width) * 0.4, rng:NextNumber(4, height - 4), depth * 0.55)
				* CFrame.Angles(0, 0, math.rad(rng:NextNumber(-20, 20))),
			Material = Enum.Material.Neon,
			Color = biome.gate.accentColor,
			CanCollide = false,
			Parent = detailModel,
		})
		light.Parent = crack
		CollectionService:AddTag(light, "AmbientFlicker")
	end
end

local function decorateBrutalist(parent: Instance, sideLabel: string, pylonCFrame: CFrame, height: number, width: number, depth: number, rng: Random, biome: GateBiome)
	local detailModel = Instance.new("Model")
	detailModel.Name = `Detailing_{sideLabel}`
	detailModel.Parent = parent

	for i = 1, 4 do
		GeneratorKit.NewPart({
			Name = `Rebar{i}`,
			Size = Vector3.new(0.35, rng:NextNumber(2, 4), 0.35),
			CFrame = pylonCFrame
				* CFrame.new(width / 2 * (if i % 2 == 0 then 1 else -1), rng:NextNumber(3, height - 3), depth / 2)
				* CFrame.Angles(math.rad(rng:NextNumber(20, 50)), 0, math.rad(rng:NextNumber(-15, 15))),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(70, 62, 58),
			CanCollide = false,
			Parent = detailModel,
		})
	end

	for i = 1, 2 do
		GeneratorKit.NewPart({
			Name = `Pipe{i}`,
			Size = Vector3.new(height * 0.85, 0.9, 0.9),
			CFrame = pylonCFrame
				* CFrame.new(width / 2 * (if i == 1 then 1 else -1) * 0.8, height * 0.45, depth / 2 + 0.6)
				* CFrame.Angles(0, 0, math.rad(90)),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(60, 60, 64),
			Shape = Enum.PartType.Cylinder,
			CanCollide = false,
			Parent = detailModel,
		})
	end

	local light = Instance.new("PointLight")
	light.Color = biome.gate.accentColor
	light.Brightness = 2
	light.Range = 14

	local strip = GeneratorKit.NewPart({
		Name = "HazardStrip",
		Size = Vector3.new(0.3, height * 0.8, 0.3),
		CFrame = pylonCFrame * CFrame.new(0, height * 0.5, depth / 2 + 0.2),
		Material = Enum.Material.Neon,
		Color = biome.gate.accentColor,
		CanCollide = false,
		Parent = detailModel,
	})
	light.Parent = strip
	CollectionService:AddTag(light, "AmbientFlicker")
end

local function decorateMolten(parent: Instance, sideLabel: string, pylonCFrame: CFrame, height: number, width: number, depth: number, rng: Random, biome: GateBiome)
	local detailModel = Instance.new("Model")
	detailModel.Name = `Detailing_{sideLabel}`
	detailModel.Parent = parent

	for i = 1, 5 do
		local light = Instance.new("PointLight")
		light.Color = biome.gate.accentColor
		light.Brightness = 2.5
		light.Range = 12

		local crack = GeneratorKit.NewPart({
			Name = `LavaCrack{i}`,
			Size = Vector3.new(0.4, rng:NextNumber(4, 9), 0.4),
			CFrame = pylonCFrame
				* CFrame.new(rng:NextNumber(-width, width) * 0.45, rng:NextNumber(3, height - 3), depth * 0.5)
				* CFrame.Angles(0, 0, math.rad(rng:NextNumber(-15, 15))),
			Material = Enum.Material.Neon,
			Color = biome.gate.accentColor,
			CanCollide = false,
			Parent = detailModel,
		})
		light.Parent = crack
		CollectionService:AddTag(light, "AmbientFlicker")
	end
end

local function buildForestAtmosphere(parent: Instance, anchorCFrame: CFrame, leftCFrame: CFrame, pylonWidth: number, rng: Random)
	local machineCFrame = leftCFrame * CFrame.new(pylonWidth * 0.9, 3, 2) * CFrame.Angles(0, rng:NextNumber(0, math.pi), math.rad(12))
	GeneratorKit.NewPart({
		Name = "BrokenMachinery",
		Size = Vector3.new(4, 3, 3),
		CFrame = machineCFrame,
		Material = Enum.Material.CorrodedMetal,
		Color = Color3.fromRGB(84, 90, 70),
		CanCollide = false,
		Parent = parent,
	})
	GeneratorKit.NewPart({
		Name = "BrokenMachineryGear",
		Size = Vector3.new(1.8, 1.8, 0.4),
		CFrame = machineCFrame * CFrame.new(1.2, 1, 1.6) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(60, 64, 56),
		Shape = Enum.PartType.Cylinder,
		CanCollide = false,
		Parent = parent,
	})

	local leaves = Instance.new("ParticleEmitter")
	leaves.Name = "DriftingLeaves"
	leaves.Color = ColorSequence.new(Color3.fromRGB(140, 180, 90))
	leaves.Lifetime = NumberRange.new(6, 10)
	leaves.Rate = 4
	leaves.Speed = NumberRange.new(0.5, 1.5)
	leaves.SpreadAngle = Vector2.new(35, 35)
	leaves.Size = NumberSequence.new(0.5)
	leaves.Acceleration = Vector3.new(0, -2, 0)
	leaves.Parent = GeneratorKit.NewPart({
		Name = "LeafEmitterAnchor",
		Size = Vector3.new(1, 1, 1),
		CFrame = anchorCFrame * CFrame.new(0, 22, 0),
		Transparency = 1,
		CanCollide = false,
		Parent = parent,
	})
end

local function buildFrozenAtmosphere(parent: Instance, anchorCFrame: CFrame, leftCFrame: CFrame, rightCFrame: CFrame, pylonHeight: number)
	local cablesModel = Instance.new("Model")
	cablesModel.Name = "FrozenCables"
	for i = 1, 3 do
		local t = i / 4
		local sag = 3 + i * 1.5
		local startPos = leftCFrame.Position + Vector3.new(0, pylonHeight * 0.7, 0)
		local endPos = rightCFrame.Position + Vector3.new(0, pylonHeight * (0.7 - 0.1 * i), 0)
		local sagPoint = startPos:Lerp(endPos, t) - Vector3.new(0, sag, 0)

		for _, segment in { { From = startPos, To = sagPoint }, { From = sagPoint, To = endPos } } do
			local segMid = segment.From:Lerp(segment.To, 0.5)
			GeneratorKit.NewPart({
				Name = `Cable{i}Segment`,
				Size = Vector3.new(0.4, 0.4, (segment.To - segment.From).Magnitude),
				CFrame = CFrame.new(segMid, segment.To),
				Material = Enum.Material.Ice,
				Color = Color3.fromRGB(200, 225, 235),
				Transparency = 0.2,
				CanCollide = false,
				Parent = cablesModel,
			})
		end
	end
	cablesModel.Parent = parent

	local mist = Instance.new("ParticleEmitter")
	mist.Name = "GroundMist"
	mist.Color = ColorSequence.new(Color3.fromRGB(210, 225, 235))
	mist.Lifetime = NumberRange.new(4, 7)
	mist.Rate = 6
	mist.Speed = NumberRange.new(0.3, 0.8)
	mist.SpreadAngle = Vector2.new(60, 60)
	mist.Size = NumberSequence.new(4, 7)
	mist.Transparency = NumberSequence.new(0.7, 1)
	mist.Parent = GeneratorKit.NewPart({
		Name = "MistEmitterAnchor",
		Size = Vector3.new(1, 1, 1),
		CFrame = anchorCFrame * CFrame.new(0, 1, 0),
		Transparency = 1,
		CanCollide = false,
		Parent = parent,
	})
end

local function buildNuclearAtmosphere(parent: Instance, leftCFrame: CFrame, pylonWidth: number, pylonHeight: number)
	local hologramPanel = GeneratorKit.NewPart({
		Name = "BrokenHologram",
		Size = Vector3.new(3.5, 5, 0.2),
		CFrame = leftCFrame * CFrame.new(-pylonWidth * 0.9, pylonHeight * 0.5, 2.5) * CFrame.Angles(0, math.rad(20), 0),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(140, 220, 60),
		Transparency = 0.3,
		CanCollide = false,
		Parent = parent,
	})
	local hologramLight = Instance.new("PointLight")
	hologramLight.Color = Color3.fromRGB(140, 220, 60)
	hologramLight.Brightness = 2
	hologramLight.Range = 16
	hologramLight.Parent = hologramPanel
	CollectionService:AddTag(hologramLight, "AmbientFlicker")

	local armCFrame = leftCFrame * CFrame.new(pylonWidth * 0.7, pylonHeight * 0.85, 2)
	GeneratorKit.NewPart({
		Name = "CameraArm",
		Size = Vector3.new(0.3, 0.3, 2.5),
		CFrame = armCFrame,
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(50, 50, 54),
		CanCollide = false,
		Parent = parent,
	})
	local cameraHead = GeneratorKit.NewPart({
		Name = "CameraHead",
		Size = Vector3.new(1, 1, 1.4),
		CFrame = armCFrame * CFrame.new(0, 0, -1.5) * CFrame.Angles(0, math.rad(30), 0),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(40, 40, 44),
		CanCollide = false,
		Parent = parent,
	})
	local cameraLight = Instance.new("PointLight")
	cameraLight.Color = Color3.fromRGB(255, 60, 60)
	cameraLight.Brightness = 1.5
	cameraLight.Range = 6
	cameraLight.Parent = cameraHead
	CollectionService:AddTag(cameraLight, "AmbientFlicker")
end

local function buildVolcanicAtmosphere(parent: Instance, anchorCFrame: CFrame, pylonWidth: number, rng: Random)
	for i = 1, 2 do
		local offset = Vector3.new(rng:NextNumber(-pylonWidth * 3, pylonWidth * 3), rng:NextNumber(14, 24), rng:NextNumber(-4, 6))
		local rockCFrame = anchorCFrame * CFrame.new(offset) * CFrame.Angles(rng:NextNumber(0, math.pi), rng:NextNumber(0, math.pi), 0)

		GeneratorKit.NewPart({
			Name = `SuspendedRock{i}`,
			Size = Vector3.new(rng:NextNumber(2, 4), rng:NextNumber(1.5, 3), rng:NextNumber(2, 4)),
			CFrame = rockCFrame,
			Material = Enum.Material.Basalt,
			Color = Color3.fromRGB(40, 36, 38),
			CanCollide = false,
			Parent = parent,
		})

		local glow = GeneratorKit.NewPart({
			Name = `SuspendedRockGlow{i}`,
			Size = Vector3.new(1.2, 0.2, 1.2),
			CFrame = rockCFrame * CFrame.new(0, -1.2, 0),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255, 110, 40),
			Transparency = 0.4,
			CanCollide = false,
			Parent = parent,
		})
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 110, 40)
		light.Brightness = 1.5
		light.Range = 10
		light.Parent = glow
		CollectionService:AddTag(light, "AmbientFlicker")
	end

	for i = 1, 2 do
		local embers = Instance.new("ParticleEmitter")
		embers.Name = `Embers{i}`
		embers.Color = ColorSequence.new(Color3.fromRGB(255, 130, 50))
		embers.Lifetime = NumberRange.new(2, 4)
		embers.Rate = 8
		embers.Speed = NumberRange.new(2, 5)
		embers.SpreadAngle = Vector2.new(15, 15)
		embers.Size = NumberSequence.new(0.3)
		embers.Parent = GeneratorKit.NewPart({
			Name = `EmberAnchor{i}`,
			Size = Vector3.new(1, 1, 1),
			CFrame = anchorCFrame * CFrame.new(rng:NextNumber(-6, 6), 0.5, rng:NextNumber(-2, 4)),
			Transparency = 1,
			CanCollide = false,
			Parent = parent,
		})
	end
end

local function buildGateAmbience(parent: Instance, anchorCFrame: CFrame)
	local hum = Instance.new("Sound")
	hum.Name = "GateAmbience"
	hum.SoundId = "" -- Needs a real uploaded asset ID — see BiomeConfig's note on audio.
	hum.Looped = true
	hum.Playing = true
	hum.Volume = 0.3
	hum.RollOffMode = Enum.RollOffMode.InverseTapered
	hum.RollOffMinDistance = 15
	hum.RollOffMaxDistance = 100
	hum.Parent = GeneratorKit.NewPart({
		Name = "AmbienceAnchor",
		Size = Vector3.new(1, 1, 1),
		CFrame = anchorCFrame,
		Transparency = 1,
		CanCollide = false,
		Parent = parent,
	})
end

-- ---------------------------------------------------------------------
-- Anchor / return landing / name label
-- ---------------------------------------------------------------------

local RETURN_LANDING_SIDE_OFFSET = 25
local RETURN_LANDING_FORWARD_OFFSET = 15

local function buildReturnLanding(parent: Instance, anchorCFrame: CFrame, biome: GateBiome)
	GeneratorKit.NewPart({
		Name = `ReturnLanding_{biome.id}`,
		Size = Vector3.new(6, 0.5, 6),
		CFrame = anchorCFrame * CFrame.new(RETURN_LANDING_SIDE_OFFSET, 0.25, RETURN_LANDING_FORWARD_OFFSET),
		Material = Enum.Material.Neon,
		Color = biome.gate.accentColor,
		Transparency = 0.5,
		CanCollide = false,
		Parent = parent,
	})
end

local function buildAnchor(parent: Instance, anchorCFrame: CFrame, ringCenterY: number, biome: GateBiome): BasePart
	local anchor = GeneratorKit.NewPart({
		Name = "GateAnchor",
		Size = Vector3.new(4, 6, 1),
		CFrame = anchorCFrame * CFrame.new(0, ringCenterY, 3),
		Material = Enum.Material.ForceField,
		Color = biome.gate.accentColor,
		Transparency = 1,
		CanCollide = false,
		Parent = parent,
	})
	anchor:SetAttribute("BiomeId", biome.id)
	CollectionService:AddTag(anchor, "BiomeGate")

	local activationLight = Instance.new("PointLight")
	activationLight.Name = "ActivationLight"
	activationLight.Color = biome.gate.accentColor
	activationLight.Brightness = 3
	activationLight.Range = 30
	activationLight.Enabled = false
	activationLight.Parent = anchor

	local activationParticles = Instance.new("ParticleEmitter")
	activationParticles.Name = "ActivationParticles"
	activationParticles.Color = ColorSequence.new(biome.gate.accentColor)
	activationParticles.Lifetime = NumberRange.new(1.5, 2.5)
	activationParticles.Speed = NumberRange.new(3, 6)
	activationParticles.Size = NumberSequence.new(0.3)
	activationParticles.Rate = 0
	activationParticles:SetAttribute("BaseRate", 14)
	activationParticles.Enabled = false
	activationParticles.Parent = anchor

	return anchor
end

local NAME_LABEL_FORWARD_OFFSET = 7
local NAME_LABEL_MAX_DISTANCE = 120

local function buildNameLabel(parent: Instance, anchorCFrame: CFrame, biome: GateBiome, ringCenterY: number)
	local floatAnchor = GeneratorKit.NewPart({
		Name = "NameLabelAnchor",
		Size = Vector3.new(0.2, 0.2, 0.2),
		CFrame = anchorCFrame * CFrame.new(0, ringCenterY, NAME_LABEL_FORWARD_OFFSET),
		Transparency = 1,
		CanCollide = false,
		Parent = parent,
	})
	floatAnchor.CanQuery = false
	floatAnchor:SetAttribute("FloatAmplitude", 0.4)
	floatAnchor:SetAttribute("FloatSpeed", 0.6)
	CollectionService:AddTag(floatAnchor, "AmbientFloat")

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "NameLabel"
	billboard.Size = UDim2.fromOffset(260, 44)
	billboard.MaxDistance = NAME_LABEL_MAX_DISTANCE
	billboard.LightInfluence = 0
	billboard.Parent = floatAnchor

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 1, -8)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(245, 245, 250)
	label.TextStrokeColor3 = biome.gate.accentColor
	label.TextStrokeTransparency = 0.35
	label.Text = string.upper(biome.name)
	label.Parent = billboard

	local underline = Instance.new("Frame")
	underline.Name = "Underline"
	underline.AnchorPoint = Vector2.new(0.5, 0)
	underline.Position = UDim2.new(0.5, 0, 1, -4)
	underline.Size = UDim2.new(0.6, 0, 0, 2)
	underline.BackgroundColor3 = biome.gate.accentColor
	underline.BorderSizePixel = 0
	underline.Parent = billboard

	local nameLight = Instance.new("PointLight")
	nameLight.Color = biome.gate.accentColor
	nameLight.Brightness = 1.5
	nameLight.Range = 20
	nameLight.Parent = floatAnchor
	CollectionService:AddTag(nameLight, "AmbientFlicker")
end

function GateGenerator.Build(parent: Instance, biome: GateBiome, anchorCFrame: CFrame): Model
	local modelName = `Gate_{biome.id}`
	GeneratorKit.CleanupPrevious(parent, modelName)

	local model = Instance.new("Model")
	model.Name = modelName

	local scale = biome.gate.scale
	local alcoveHalfWidth = (BASE_ALCOVE_WIDTH * scale + ALCOVE_WIDTH_MARGIN) / 2
	local ringOuterRadius = RING_OUTER_RADIUS_BASE * scale
	local ringCenterY = ringOuterRadius + RING_GROUND_CLEARANCE
	local sideWallInnerX = ringOuterRadius + RING_SIDE_CLEARANCE

	local rng = GeneratorKit.Seeded(#biome.id * 97 + 13)

	local leftCFrame, rightCFrame = buildAlcove(model, anchorCFrame, alcoveHalfWidth, sideWallInnerX, biome.gate.primaryMaterial, biome.gate.primaryColor)
	buildPortalCore(model, anchorCFrame, ringCenterY, ringOuterRadius, biome)

	-- Decoration stays concentrated near the portal (up to just above the
	-- ring), not spread all the way up the full 40-stud wall.
	local decorationHeight = ringCenterY + ringOuterRadius + 4
	local decorationWidth = alcoveHalfWidth - sideWallInnerX

	for _, side in { { CFrame = leftCFrame, Label = "Left" }, { CFrame = rightCFrame, Label = "Right" } } do
		if biome.gate.archStyle == "Organic" then
			decorateOrganic(model, side.Label, side.CFrame, decorationHeight, decorationWidth, rng, biome)
		elseif biome.gate.archStyle == "Shattered" then
			decorateShattered(model, side.Label, side.CFrame, decorationHeight, decorationWidth, ALCOVE_DEPTH, rng, biome)
		elseif biome.gate.archStyle == "Brutalist" then
			decorateBrutalist(model, side.Label, side.CFrame, decorationHeight, decorationWidth, ALCOVE_DEPTH, rng, biome)
		elseif biome.gate.archStyle == "Molten" then
			decorateMolten(model, side.Label, side.CFrame, decorationHeight, decorationWidth, ALCOVE_DEPTH, rng, biome)
		end
	end

	buildAnchor(model, anchorCFrame, ringCenterY, biome)
	buildReturnLanding(model, anchorCFrame, biome)
	buildNameLabel(model, anchorCFrame, biome, ringCenterY)
	buildGateAmbience(model, anchorCFrame)

	if biome.gate.archStyle == "Organic" then
		buildForestAtmosphere(model, anchorCFrame, leftCFrame, decorationWidth, rng)
	elseif biome.gate.archStyle == "Shattered" then
		buildFrozenAtmosphere(model, anchorCFrame, leftCFrame, rightCFrame, decorationHeight)
	elseif biome.gate.archStyle == "Brutalist" then
		buildNuclearAtmosphere(model, leftCFrame, decorationWidth, decorationHeight)
	elseif biome.gate.archStyle == "Molten" then
		buildVolcanicAtmosphere(model, anchorCFrame, decorationWidth, rng)
	end

	PortalThresholdGenerator.Build(model, anchorCFrame, biome, alcoveHalfWidth, rng)

	GeneratorKit.Finalize(model, "AlcoveBackWall")
	model.Parent = parent

	return model
end

return GateGenerator
