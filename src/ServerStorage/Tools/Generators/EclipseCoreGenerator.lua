--!strict
-- Builds the Eclipse Core: the floating hero landmark visible from anywhere
-- in the Haven and the emotional/visual anchor of the whole cinematic reveal.
-- A crystalline neon core, an inner shard cluster, two tilted orbiting rings
-- (segmented — Roblox has no native torus primitive), and glowing tether
-- beams anchoring it to a raised dais below.

local CollectionService = game:GetService("CollectionService")
local GeneratorKit = require(script.Parent.GeneratorKit)

-- Phase 2: 85 -> 62. At 85 studs with only a 30-stud canopy the sphere read
-- as a disconnected floating object far above its own canopy's roofline —
-- the single biggest contributor to "oversized floating sphere." 62 (paired
-- with the taller 36-stud canopy below) still floats dramatically above and
-- through the skylight opening, but now relates to the canopy's own scale.
-- Core sphere size/dais radius/XY position are untouched — gameplay role,
-- backend, and central position are unaffected by this.
local CORE_HEIGHT_ABOVE_PLAZA = 62
local CORE_RADIUS = 16
local DAIS_RADIUS = 22
local DAIS_HEIGHT = 6
local DAIS_SKIRT_HEIGHT = 1.5
local DAIS_SKIRT_RADIUS = DAIS_RADIUS + 6

-- Central Arrival Canopy (Prompt 2): a partial, ring-supported roof over the
-- Central Arrival Core only — NOT a full dome over the whole plaza, so
-- districts/gates/sky all stay open per the redesign's explicit roof rules.
-- Pillars sit at a radius comfortably inside HavenLayoutConfig's district
-- ring, and their angle is deliberately offset 11.25° from every 22.5°
-- multiple already spoken for by a gate (0/90/180/270), a district/watchtower
-- (45/135/225/315), or a storytelling cluster (22.5/112.5/202.5/292.5) — so
-- no pillar ever sits directly in an existing sightline.
-- Phase 1 correction: pillar radius reduced 40 -> 32 (matches
-- HavenLayoutConfig.CENTRAL_ARRIVAL_RADIUS exactly) so the Core's own
-- footprint doesn't eat into the plaza's usable walking space now that the
-- whole hub is more compact — Core sphere/dais/tether/orbit-ring art itself
-- is untouched, only the canopy's reserved ring shrank.
local CANOPY_PILLAR_COUNT = 8
local CANOPY_PILLAR_RADIUS = 32
local CANOPY_PILLAR_ANGLE_OFFSET = 11.25
-- Phase 2: 30 -> 36 — a taller landmark that better frames the now-lower
-- Core (see CORE_HEIGHT_ABOVE_PLAZA above) and leaves more camera headroom.
local CANOPY_HEIGHT = 36
local CANOPY_SKYLIGHT_RADIUS = 26 -- kept larger than DAIS_RADIUS so the dais/rim stay fully visible through the aperture
local CANOPY_CROSSBEAM_HEIGHT_FRACTION = 0.65 -- ~23 studs up: well above head/camera height, well below the roofline

local EclipseCoreGenerator = {}

export type BuildResult = {
	Model: Model,
	CoreCFrame: CFrame,
}

local function buildDais(parent: Instance, plazaCenter: CFrame)
	-- Phase 2: a wider, shorter skirt ring at the dais's base blends it into
	-- HavenPlatformGenerator's new Zone A floor treatment — the dais now
	-- rises from the floor via a graduated step instead of a hard-edged
	-- cylinder dropped on top of a flat disc. The main dais body shrinks by
	-- exactly the skirt's height so the top (CoreDaisRim, tethers, core
	-- height math) stays at the same DAIS_HEIGHT it always was.
	GeneratorKit.NewPart({
		Name = "CoreDaisSkirt",
		Size = Vector3.new(DAIS_SKIRT_HEIGHT, DAIS_SKIRT_RADIUS * 2, DAIS_SKIRT_RADIUS * 2),
		CFrame = plazaCenter * CFrame.new(0, DAIS_SKIRT_HEIGHT / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Basalt,
		Color = Color3.fromRGB(46, 42, 48),
		Shape = Enum.PartType.Cylinder,
		CanCollide = false,
		Parent = parent,
	})

	local daisBodyHeight = DAIS_HEIGHT - DAIS_SKIRT_HEIGHT
	GeneratorKit.NewPart({
		Name = "CoreDais",
		Size = Vector3.new(daisBodyHeight, DAIS_RADIUS * 2, DAIS_RADIUS * 2),
		CFrame = plazaCenter * CFrame.new(0, DAIS_SKIRT_HEIGHT + daisBodyHeight / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Basalt,
		Color = Color3.fromRGB(40, 38, 42),
		Shape = Enum.PartType.Cylinder,
		Parent = parent,
	})

	GeneratorKit.NewPart({
		Name = "CoreDaisRim",
		Size = Vector3.new(1, DAIS_RADIUS * 2 + 1, DAIS_RADIUS * 2 + 1),
		CFrame = plazaCenter * CFrame.new(0, DAIS_HEIGHT + 0.5, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(120, 90, 255),
		Shape = Enum.PartType.Cylinder,
		CanCollide = false,
		Parent = parent,
	})
end

local function buildCoreBody(parent: Instance, coreCFrame: CFrame): BasePart
	local core = GeneratorKit.NewPart({
		Name = "CoreSphere",
		Size = Vector3.new(CORE_RADIUS * 2, CORE_RADIUS * 2, CORE_RADIUS * 2),
		CFrame = coreCFrame,
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(110, 80, 240),
		Shape = Enum.PartType.Ball,
		CanCollide = false,
		Parent = parent,
	})

	local light = Instance.new("PointLight")
	light.Name = "CoreLight"
	light.Color = Color3.fromRGB(150, 120, 255)
	light.Brightness = 4
	light.Range = 90
	light.Parent = core
	CollectionService:AddTag(light, "AmbientFlicker")

	local rng = GeneratorKit.Seeded(7)
	local shardCluster = Instance.new("Model")
	shardCluster.Name = "ShardCluster"
	for i = 1, 7 do
		local shardSize = rng:NextNumber(3, 7)
		GeneratorKit.NewPart({
			Name = `Shard{i}`,
			Size = Vector3.new(shardSize, shardSize * 1.8, shardSize),
			CFrame = coreCFrame
				* CFrame.Angles(rng:NextNumber(0, math.pi * 2), rng:NextNumber(0, math.pi * 2), rng:NextNumber(0, math.pi * 2))
				* CFrame.new(0, rng:NextNumber(-4, 4), 0),
			Material = Enum.Material.Glass,
			Color = Color3.fromRGB(200, 180, 255),
			Transparency = 0.25,
			CanCollide = false,
			Parent = shardCluster,
		})
	end
	shardCluster.Parent = parent

	return core
end

-- A segmented ring (short beveled blocks arranged in a circle) since Roblox
-- has no native torus/ring primitive.
--
-- Correction pass: these used to be tagged SlowSpin (continuously rotating
-- via AmbientController's PivotTo loop) — per explicit user correction, ALL
-- decorative rotating geometry around the central Haven/Core reads as
-- clutter and must stop, not just the 3 largest ones. Kept as static
-- architecture instead of deleted (still contributes to the Core's "ancient
-- energy containment" identity) — geometry/tilt/segments/color unchanged,
-- it just no longer spins.
local function buildOrbitRing(
	parent: Instance,
	name: string,
	coreCFrame: CFrame,
	radius: number,
	tiltDegrees: number,
	segments: number,
	color: Color3
)
	local ringModel = Instance.new("Model")
	ringModel.Name = name

	local tilt = CFrame.Angles(math.rad(tiltDegrees), 0, 0)

	for i = 0, segments - 1 do
		local angle = (i / segments) * math.pi * 2
		local segmentCFrame = coreCFrame
			* tilt
			* CFrame.Angles(0, angle, 0)
			* CFrame.new(0, 0, -radius)

		GeneratorKit.NewPart({
			Name = `RingSegment{i}`,
			Size = Vector3.new(2.5, 0.6, (2 * math.pi * radius) / segments * 0.85),
			CFrame = segmentCFrame,
			Material = Enum.Material.Metal,
			Color = color,
			CanCollide = false,
			Parent = ringModel,
		})
	end

	ringModel.Parent = parent
	ringModel:PivotTo(coreCFrame)

	return ringModel
end

-- A couple of larger, irregular cracked chunks orbiting further out than the
-- shard cluster — "cracked planetary fragments" per the Prompt 3 brief,
-- reinforcing "ancient, unstable energy source tied to the destruction of
-- civilization." Each carries a thin embedded Neon crack line.
local function buildFragments(parent: Instance, coreCFrame: CFrame, rng: Random)
	local fragmentsModel = Instance.new("Model")
	fragmentsModel.Name = "Fragments"

	for i = 1, 3 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = rng:NextNumber(CORE_RADIUS * 2.6, CORE_RADIUS * 3.4)
		local height = rng:NextNumber(-10, 10)
		local size = rng:NextNumber(9, 14)
		local position = coreCFrame.Position + Vector3.new(math.cos(angle) * distance, height, math.sin(angle) * distance)
		local fragmentCFrame = CFrame.new(position) * CFrame.Angles(rng:NextNumber(0, math.pi), rng:NextNumber(0, math.pi), rng:NextNumber(0, math.pi))

		GeneratorKit.NewPart({
			Name = `Fragment{i}`,
			Size = Vector3.new(size, size * 0.7, size * 0.9),
			CFrame = fragmentCFrame,
			Material = Enum.Material.Basalt,
			Color = Color3.fromRGB(46, 42, 48),
			CanCollide = false,
			Parent = fragmentsModel,
		})

		GeneratorKit.NewPart({
			Name = `Fragment{i}Crack`,
			Size = Vector3.new(size * 0.85, 0.4, 0.4),
			CFrame = fragmentCFrame * CFrame.new(0, size * 0.1, size * 0.46),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(150, 120, 255),
			CanCollide = false,
			Parent = fragmentsModel,
		})
	end

	fragmentsModel.Parent = parent
	return fragmentsModel
end

-- Restrained Beam "energy arcs" between a couple of fixed Attachment points
-- near the core — a controlled discharge, not chaotic lightning.
local function buildEnergyArcs(parent: Instance, core: BasePart, coreCFrame: CFrame, rng: Random)
	local arcsModel = Instance.new("Model")
	arcsModel.Name = "EnergyArcs"

	local coreAttachment = Instance.new("Attachment")
	coreAttachment.Name = "ArcOrigin"
	coreAttachment.Parent = core

	for i = 1, 2 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = rng:NextNumber(CORE_RADIUS * 1.6, CORE_RADIUS * 2.1)
		local targetPosition = coreCFrame.Position + Vector3.new(math.cos(angle) * distance, rng:NextNumber(-6, 6), math.sin(angle) * distance)

		local anchor = GeneratorKit.NewPart({
			Name = `ArcTarget{i}`,
			Size = Vector3.new(0.4, 0.4, 0.4),
			CFrame = CFrame.new(targetPosition),
			Material = Enum.Material.Neon,
			Transparency = 1,
			CanCollide = false,
			Parent = arcsModel,
		})

		local targetAttachment = Instance.new("Attachment")
		targetAttachment.Parent = anchor

		local beam = Instance.new("Beam")
		beam.Name = `Arc{i}`
		beam.Attachment0 = coreAttachment
		beam.Attachment1 = targetAttachment
		beam.Width0 = 0.35
		beam.Width1 = 0.1
		beam.Color = ColorSequence.new(Color3.fromRGB(180, 150, 255))
		beam.Transparency = NumberSequence.new(0.35)
		beam.FaceCamera = true
		beam.Segments = 12
		beam.CurveSize0 = rng:NextNumber(-3, 3)
		beam.CurveSize1 = rng:NextNumber(-3, 3)
		beam.Parent = anchor
		CollectionService:AddTag(beam, "QualityGatedEffect")
	end

	arcsModel.Parent = parent
	return arcsModel
end

-- Small flat holographic glyph panels projected in a ring beneath the core.
-- Correction pass: used to slowly counter-rotate against the orbit rings for
-- a "scanning ancient archive" read — per explicit user correction this is
-- also in-scope for the central-Core rotating-ring cleanup (no exception for
-- being smaller than the 3 orbit rings), so it's now static too.
local function buildGlyphRing(parent: Instance, coreCFrame: CFrame)
	local glyphModel = Instance.new("Model")
	glyphModel.Name = "GlyphRing"

	local radius = CORE_RADIUS * 1.4
	local count = 6

	for i = 0, count - 1 do
		local angle = (i / count) * math.pi * 2
		local glyphCFrame = coreCFrame
			* CFrame.Angles(math.rad(70), 0, 0)
			* CFrame.Angles(0, angle, 0)
			* CFrame.new(0, 0, -radius)
			* CFrame.Angles(0, 0, math.rad(45))

		GeneratorKit.NewPart({
			Name = `Glyph{i}`,
			Size = Vector3.new(2.2, 2.2, 0.15),
			CFrame = glyphCFrame,
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(190, 170, 255),
			Transparency = 0.25,
			CanCollide = false,
			Parent = glyphModel,
		})
	end

	glyphModel.Parent = parent
	glyphModel:PivotTo(coreCFrame)

	return glyphModel
end

-- Soft, highly-transparent angled beams suggesting light falling from the
-- core toward the dais — a cheap, mobile-safe stand-in for true volumetrics.
local function buildLightShafts(parent: Instance, plazaCenter: CFrame, coreCFrame: CFrame)
	local shaftsModel = Instance.new("Model")
	shaftsModel.Name = "LightShafts"

	local length = coreCFrame.Position.Y - plazaCenter.Position.Y
	for i = 0, 3 do
		local angle = math.rad(i * 90 + 30)
		local lean = 6
		local shaftCFrame = CFrame.new(coreCFrame.Position, coreCFrame.Position - Vector3.new(math.cos(angle) * lean, length, math.sin(angle) * lean))
			* CFrame.new(0, 0, -length / 2)

		GeneratorKit.NewPart({
			Name = `Shaft{i}`,
			Size = Vector3.new(6, 6, length),
			CFrame = shaftCFrame,
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(200, 190, 255),
			Transparency = 0.9,
			CanCollide = false,
			Parent = shaftsModel,
		})
	end

	shaftsModel.Parent = parent
	return shaftsModel
end

local function buildAmbience(core: BasePart)
	local hum = Instance.new("Sound")
	hum.Name = "CoreHum"
	hum.SoundId = "" -- Needs a real uploaded asset ID — see BiomeConfig's note on audio.
	hum.Looped = true
	hum.Playing = true -- harmless no-op while SoundId is empty; starts working the moment a real ID is set
	hum.Volume = 0.4
	hum.RollOffMode = Enum.RollOffMode.InverseTapered
	hum.RollOffMinDistance = 25
	hum.RollOffMaxDistance = 160
	hum.Parent = core
end

local function buildTethers(parent: Instance, plazaCenter: CFrame, coreCFrame: CFrame)
	local tetherModel = Instance.new("Model")
	tetherModel.Name = "Tethers"

	local topY = coreCFrame.Position.Y - CORE_RADIUS
	local bottomY = plazaCenter.Position.Y + DAIS_HEIGHT
	local length = topY - bottomY
	local center = plazaCenter.Position + Vector3.new(0, DAIS_HEIGHT + length / 2, 0)

	for i = 0, 3 do
		local angle = math.rad(i * 90 + 20)
		local radialOffset = Vector3.new(math.cos(angle) * (DAIS_RADIUS * 0.5), 0, math.sin(angle) * (DAIS_RADIUS * 0.5))

		GeneratorKit.NewPart({
			Name = `Tether{i}`,
			Size = Vector3.new(0.8, length, 0.8),
			CFrame = CFrame.new(center + radialOffset),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(140, 110, 255),
			CanCollide = false,
			Transparency = 0.2,
			Parent = tetherModel,
		})
	end

	tetherModel.Parent = parent
	return tetherModel
end

-- 8 radial "ribs" running from a skylight ring directly above the dais out
-- to 8 support pillars, plus (Phase 2) a ring of crossbeams and reinforced
-- roof panels between them — a real framed canopy rather than bare spokes,
-- but still open: the skylight opening and every gap between pillars stay
-- unpaneled, so the arrival area reads as sheltered without going dark or
-- cramped. Uses the same "CFrame.new(midpoint, endpoint)" two-point segment
-- idiom already proven throughout the generators (e.g. GateGenerator's
-- cable segments).
local function buildArrivalCanopy(parent: Instance, plazaCenter: CFrame)
	local canopyModel = Instance.new("Model")
	canopyModel.Name = "ArrivalCanopy"

	local ribHeight = plazaCenter.Position + Vector3.new(0, CANOPY_HEIGHT, 0)
	local crossbeamHeight = CANOPY_HEIGHT * CANOPY_CROSSBEAM_HEIGHT_FRACTION

	local pillarTopPositions = {}
	local ribInnerPositions = {}
	local crossbeamPositions = {}

	for i = 0, CANOPY_PILLAR_COUNT - 1 do
		local angle = math.rad(CANOPY_PILLAR_ANGLE_OFFSET + i * (360 / CANOPY_PILLAR_COUNT))
		local outwardDirection = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local pillarGroundPos = plazaCenter.Position + outwardDirection * CANOPY_PILLAR_RADIUS
		local pillarTopPos = pillarGroundPos + Vector3.new(0, CANOPY_HEIGHT, 0)
		local ribInnerPos = ribHeight + outwardDirection * CANOPY_SKYLIGHT_RADIUS
		pillarTopPositions[i] = pillarTopPos
		ribInnerPositions[i] = ribInnerPos
		crossbeamPositions[i] = pillarGroundPos + Vector3.new(0, crossbeamHeight, 0)

		GeneratorKit.NewPart({
			Name = `CanopyPillar{i}`,
			Size = Vector3.new(2, CANOPY_HEIGHT, 2),
			CFrame = CFrame.new(pillarGroundPos + Vector3.new(0, CANOPY_HEIGHT / 2, 0)),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(58, 56, 62),
			Parent = canopyModel,
		})

		local ribMid = pillarTopPos:Lerp(ribInnerPos, 0.5)
		GeneratorKit.NewPart({
			Name = `CanopyRib{i}`,
			Size = Vector3.new(4, 0.8, (pillarTopPos - ribInnerPos).Magnitude),
			CFrame = CFrame.new(ribMid, ribInnerPos),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(44, 42, 48),
			CanCollide = false,
			Parent = canopyModel,
		})
	end

	-- Phase 2: a ring of horizontal crossbeams + reinforced roof panels
	-- turns the previous "8 bare ribs" into a structurally believable
	-- frame. Panels only span the band between the pillar ring and the
	-- skylight ring — the skylight opening itself stays unpaneled, so sky
	-- and the Core stay visible from below and every gap between pillars
	-- (toward Forward/Left/Right/the portal arc) stays fully open at ground
	-- level. Both loops stay well above head/camera height.
	for i = 0, CANOPY_PILLAR_COUNT - 1 do
		local nextI = (i + 1) % CANOPY_PILLAR_COUNT
		local beamStart = crossbeamPositions[i]
		local beamEnd = crossbeamPositions[nextI]
		local beamMid = beamStart:Lerp(beamEnd, 0.5)

		GeneratorKit.NewPart({
			Name = `CanopyCrossbeam{i}`,
			Size = Vector3.new(1.4, 1.4, (beamEnd - beamStart).Magnitude),
			CFrame = CFrame.new(beamMid, beamEnd),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(50, 48, 54),
			CanCollide = false,
			Parent = canopyModel,
		})

		local panelOuter = pillarTopPositions[i]:Lerp(pillarTopPositions[nextI], 0.5)
		local panelInner = ribInnerPositions[i]:Lerp(ribInnerPositions[nextI], 0.5)
		local panelMid = panelOuter:Lerp(panelInner, 0.5)

		GeneratorKit.NewPart({
			Name = `CanopyRoofPanel{i}`,
			Size = Vector3.new((pillarTopPositions[nextI] - pillarTopPositions[i]).Magnitude * 0.95, 0.4, (panelOuter - panelInner).Magnitude),
			CFrame = CFrame.new(panelMid, panelInner) * CFrame.Angles(math.rad(-8), 0, 0),
			Material = Enum.Material.DiamondPlate,
			Color = Color3.fromRGB(52, 50, 56),
			CanCollide = false,
			Parent = canopyModel,
		})
	end

	-- 4 hanging utility lights (warm, chain-hung look) and 2 modest banners,
	-- hung from the crossbeam ring facing the routes between pillars rather
	-- than straight down a sightline.
	for lightIndex = 0, 3 do
		local i = lightIndex * 2
		local rodTop = crossbeamPositions[i]
		local rodBottom = rodTop + Vector3.new(0, -1.8, 0)
		local rodMid = rodTop:Lerp(rodBottom, 0.5)

		GeneratorKit.NewPart({
			Name = `CanopyLampRod{lightIndex}`,
			Size = Vector3.new(0.25, 1.8, 0.25),
			CFrame = CFrame.new(rodMid, rodBottom),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(40, 38, 42),
			CanCollide = false,
			Parent = canopyModel,
		})

		local bulb = GeneratorKit.NewPart({
			Name = `CanopyLampBulb{lightIndex}`,
			Size = Vector3.new(0.9, 0.9, 0.9),
			CFrame = CFrame.new(rodBottom),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255, 205, 150),
			Shape = Enum.PartType.Ball,
			CanCollide = false,
			Parent = canopyModel,
		})

		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 195, 140)
		light.Brightness = 1.4
		light.Range = 16
		light.Parent = bulb
		CollectionService:AddTag(light, "AmbientFlicker")
	end

	for bannerIndex = 0, 1 do
		local i = bannerIndex * 4 + 1
		local bannerCFrame = CFrame.new(crossbeamPositions[i], plazaCenter.Position) * CFrame.new(0, -2, 0.3)
		local banner = GeneratorKit.NewPart({
			Name = `CanopyBanner{bannerIndex}`,
			Size = Vector3.new(2.6, 4.5, 0.12),
			CFrame = bannerCFrame,
			Material = Enum.Material.Fabric,
			Color = Color3.fromRGB(120, 90, 255),
			CanCollide = false,
			Parent = canopyModel,
		})
		CollectionService:AddTag(banner, "AmbientSway")
	end

	local skylightRim = GeneratorKit.NewPart({
		Name = "SkylightRim",
		Size = Vector3.new(1, CANOPY_SKYLIGHT_RADIUS * 2 + 1, CANOPY_SKYLIGHT_RADIUS * 2 + 1),
		CFrame = plazaCenter * CFrame.new(0, CANOPY_HEIGHT, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(140, 110, 255),
		Shape = Enum.PartType.Cylinder,
		CanCollide = false,
		Parent = canopyModel,
	})

	local rimLight = Instance.new("PointLight")
	rimLight.Color = Color3.fromRGB(150, 120, 255)
	rimLight.Brightness = 2
	rimLight.Range = 45
	rimLight.Parent = skylightRim
	CollectionService:AddTag(rimLight, "AmbientFlicker")

	canopyModel.Parent = parent
	return canopyModel
end

function EclipseCoreGenerator.Build(parent: Instance, plazaCenter: CFrame): BuildResult
	GeneratorKit.CleanupPrevious(parent, "EclipseCore")

	local model = Instance.new("Model")
	model.Name = "EclipseCore"

	local coreCFrame = plazaCenter * CFrame.new(0, CORE_HEIGHT_ABOVE_PLAZA, 0)

	local rng = GeneratorKit.Seeded(23)

	buildDais(model, plazaCenter)
	buildArrivalCanopy(model, plazaCenter)
	buildTethers(model, plazaCenter, coreCFrame)
	local core = buildCoreBody(model, coreCFrame)
	buildOrbitRing(model, "OrbitRingInner", coreCFrame, CORE_RADIUS * 1.8, 12, 40, Color3.fromRGB(170, 150, 255))
	buildOrbitRing(model, "OrbitRingMid", coreCFrame, CORE_RADIUS * 2.3, -18, 48, Color3.fromRGB(120, 100, 220))
	buildOrbitRing(model, "OrbitRingOuter", coreCFrame, CORE_RADIUS * 2.9, 34, 56, Color3.fromRGB(90, 75, 170))
	buildFragments(model, coreCFrame, rng)
	buildEnergyArcs(model, core, coreCFrame, rng)
	buildGlyphRing(model, coreCFrame)
	buildLightShafts(model, plazaCenter, coreCFrame)
	buildAmbience(core)

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "EmberDrift"
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(180, 150, 255))
	emitter.Lifetime = NumberRange.new(3, 5)
	emitter.Rate = 12
	emitter.Speed = NumberRange.new(2, 4)
	emitter.SpreadAngle = Vector2.new(20, 20)
	emitter.Size = NumberSequence.new(0.4)
	emitter.Parent = core

	GeneratorKit.Finalize(model, "CoreSphere")
	model.Parent = parent

	return {
		Model = model,
		CoreCFrame = coreCFrame,
	}
end

return EclipseCoreGenerator
