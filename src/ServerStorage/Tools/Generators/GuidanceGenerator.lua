--!strict
-- Builds the Guidance District's Quest NPC stage (platform, banner,
-- holographic quest-marker beacon, NPC anchor, FacilityAnchor) and the
-- Tutorial path signage arcing from the player's spawn point to it. Lighter
-- weight than CivicBuildingGenerator's full building skeleton on purpose —
-- see Prompt 3 plan's Deliverables list.
--
-- The quest marker is an abstract glowing "!" shape (a bar + a ball), not
-- literal iconography — same reasoning as EclipseCoreGenerator's glyph ring:
-- a readable symbol without needing image/texture assets outside a
-- code-only pipeline.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldMapConfig = require(ReplicatedStorage.Shared.Config.WorldMapConfig)
local HavenLayoutConfig = require(ReplicatedStorage.Shared.Config.HavenLayoutConfig)
local HavenFacilityConfig = require(ReplicatedStorage.Shared.Config.HavenFacilityConfig)
local BiomeConfig = require(ReplicatedStorage.Shared.Config.BiomeConfig)
local GeneratorKit = require(script.Parent.GeneratorKit)
local SurvivorFigureGenerator = require(script.Parent.SurvivorFigureGenerator)

local SIGNPOST_COUNT = 5
local SIGNPOST_ARC_RADIUS = 60

-- Prompt 4A.1: a second, shorter signpost run continuing the guidance chain
-- from the Quest Giver onward to the Forest gate (Quest Giver -> Forest
-- Gate -> Forest Wildlands), reusing the exact same signpost technique.
local FOREST_PATH_SIGNPOST_COUNT = 3
local FOREST_PATH_ARC_RADIUS = 100 -- between the district ring (78) and the wall (130)

local GuidanceGenerator = {}

local function findQuestFacility(): HavenFacilityConfig.FacilityDefinition
	for _, facility in HavenFacilityConfig do
		if facility.kind == "QuestNPC" then
			return facility
		end
	end
	error("GuidanceGenerator: no QuestNPC facility declared in HavenFacilityConfig")
end

-- Phase 3B: replaced with a real, solid "Survivor Guide" figure —
-- backpack + binoculars, an explorer/guide silhouette — instead of the
-- translucent hologram this used to be. The brief is explicit that this NPC
-- should be "instantly readable as a person," not rely on an abstract
-- projection; the interaction anchors below (QuestGiverAnchor/FacilityAnchor)
-- are untouched, only this visual changed.
local function buildQuestGiverFigure(parent: Instance, stageCFrame: CFrame, accentColor: Color3)
	local figureCFrame = stageCFrame * CFrame.new(3, 0, 0)
	local figure = SurvivorFigureGenerator.Build(parent, figureCFrame, {
		Backpack = true,
		Binoculars = true,
		AccentColor = accentColor,
	})
	figure.Name = "QuestGiverFigure"
end

local function buildQuestStage(parent: Instance, origin: CFrame, stageCFrame: CFrame, accentColor: Color3, facility: HavenFacilityConfig.FacilityDefinition)
	GeneratorKit.NewPart({
		Name = "Platform",
		Size = Vector3.new(12, 1, 12),
		CFrame = stageCFrame * CFrame.new(0, 0.5, 0),
		Material = Enum.Material.Concrete,
		Color = Color3.fromRGB(70, 70, 74),
		Parent = parent,
	})

	GeneratorKit.NewPart({
		Name = "PlatformRim",
		Size = Vector3.new(0.4, 12.4, 12.4),
		CFrame = stageCFrame * CFrame.new(0, 1.05, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Neon,
		Color = accentColor,
		Shape = Enum.PartType.Cylinder,
		CanCollide = false,
		Parent = parent,
	})

	-- Banner pole (reuses AmbientSway, same as CivicBuildingGenerator's event banner).
	GeneratorKit.NewPart({
		Name = "BannerPole",
		Size = Vector3.new(0.3, 7, 0.3),
		CFrame = stageCFrame * CFrame.new(-4, 4.5, 0),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(50, 50, 54),
		Parent = parent,
	})
	local banner = GeneratorKit.NewPart({
		Name = "Banner",
		Size = Vector3.new(2.4, 3.4, 0.15),
		CFrame = stageCFrame * CFrame.new(-2.9, 5.5, 0),
		Material = Enum.Material.Fabric,
		Color = accentColor,
		CanCollide = false,
		Parent = parent,
	})
	CollectionService:AddTag(banner, "AmbientSway")

	-- Abstract holographic quest-marker beacon, hovering and slowly spinning.
	local beacon = Instance.new("Model")
	beacon.Name = "QuestBeacon"
	local beaconBar = GeneratorKit.NewPart({
		Name = "BeaconBar",
		Size = Vector3.new(0.6, 2.2, 0.6),
		CFrame = stageCFrame * CFrame.new(0, 8, 0),
		Material = Enum.Material.Neon,
		Color = accentColor,
		CanCollide = false,
		Parent = beacon,
	})
	GeneratorKit.NewPart({
		Name = "BeaconDot",
		Size = Vector3.new(0.7, 0.7, 0.7),
		CFrame = stageCFrame * CFrame.new(0, 6.4, 0),
		Material = Enum.Material.Neon,
		Color = accentColor,
		Shape = Enum.PartType.Ball,
		CanCollide = false,
		Parent = beacon,
	})
	beacon.Parent = parent
	-- No explicit PivotTo here: BeaconBar/BeaconDot are already placed at
	-- their correct final world CFrames above, and Model:PivotTo() *moves*
	-- a model's parts to align its current pivot with the given target — it
	-- doesn't just relabel the pivot. Calling it after-the-fact on an
	-- asymmetric 2-part assembly like this would nudge both parts by the gap
	-- between the model's real (bounding-box) pivot and whatever CFrame was
	-- passed in. AmbientController's SlowSpin instead reads whatever
	-- GetPivot() naturally resolves to at Start() time, which is fine here.
	beacon:SetAttribute("Speed", 20)
	CollectionService:AddTag(beacon, "SlowSpin")

	local beaconLight = Instance.new("PointLight")
	beaconLight.Color = accentColor
	beaconLight.Brightness = 3
	beaconLight.Range = 24
	beaconLight.Parent = beaconBar
	CollectionService:AddTag(beaconLight, "AmbientFlicker")

	buildQuestGiverFigure(parent, stageCFrame, accentColor)

	-- Quest giver stands here — no character model, per the established stub
	-- convention (Prompt 1's spawn NPC anchors, CivicBuildingGenerator's
	-- scientist anchor). Tagged both "NPC" (generic anchor convention) and
	-- "QuestGiver" (Prompt 4A: lets QuestGiverController find this exact
	-- instance without also attaching to other "NPC"-tagged anchors, e.g.
	-- the Capsule Lab's scientist spot). Kept separate from the visible
	-- figure above — this part is purely the interaction hitbox/anchor, not
	-- the visual, same separation GateAnchor already has from its gate's
	-- decorative geometry.
	local npcAnchor = GeneratorKit.NewPart({
		Name = "QuestGiverAnchor",
		Size = Vector3.new(2, 2, 2),
		CFrame = stageCFrame * CFrame.new(3, 1, 0),
		Transparency = 1,
		CanCollide = false,
		Parent = parent,
	})
	CollectionService:AddTag(npcAnchor, "NPC")
	CollectionService:AddTag(npcAnchor, "QuestGiver")

	local facilityAnchor = GeneratorKit.NewPart({
		Name = "FacilityAnchor",
		Size = Vector3.new(4, 5, 1),
		CFrame = CFrame.new(stageCFrame.Position + Vector3.new(0, 3, 0), origin.Position),
		Material = Enum.Material.ForceField,
		Color = accentColor,
		Transparency = 1,
		CanCollide = false,
		Parent = parent,
	})
	facilityAnchor:SetAttribute("FacilityId", facility.id)
	CollectionService:AddTag(facilityAnchor, "HavenFacility")
end

-- Generalized signpost-arc builder — a lightweight, readable breadcrumb
-- trail rather than a literal straight line or a giant floating arrow.
-- Reused for BOTH guidance segments (Prompt 4A.1): spawn -> Quest Giver,
-- and Quest Giver -> Forest Gate, so the "never use giant floating arrows
-- everywhere" guidance stays a single consistent visual language instead of
-- two different implementations. Each post faces the actual destination
-- (not "the next post along the arc") — simpler, and it avoids a
-- degenerate CFrame.new(pos, pos) at the final post, where a lookahead
-- would otherwise point back at itself.
local function buildSignpostPath(
	parent: Instance,
	pathName: string,
	origin: CFrame,
	startAngleDegrees: number,
	endAngleDegrees: number,
	arcRadius: number,
	destination: Vector3,
	postCount: number,
	arrowColor: Color3
)
	local pathModel = Instance.new("Model")
	pathModel.Name = pathName

	for i = 0, postCount - 1 do
		local t = i / (postCount - 1)
		local angleDegrees = startAngleDegrees + (endAngleDegrees - startAngleDegrees) * t
		local direction = WorldMapConfig.DirectionForAngle(math.rad(angleDegrees))
		local position = origin.Position + direction * arcRadius

		local postCFrame = CFrame.new(position, destination)

		GeneratorKit.NewPart({
			Name = `SignPost{i}`,
			Size = Vector3.new(0.3, 4, 0.3),
			CFrame = postCFrame * CFrame.new(0, 2, 0),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(60, 60, 64),
			Parent = pathModel,
		})

		local arrow = Instance.new("WedgePart")
		arrow.Name = `SignArrow{i}`
		arrow.Size = Vector3.new(1.4, 0.8, 1)
		arrow.CFrame = postCFrame * CFrame.new(0, 3.6, 0) * CFrame.Angles(0, math.rad(90), 0)
		arrow.Material = Enum.Material.Neon
		arrow.Color = arrowColor
		arrow.Anchored = true
		arrow.CanCollide = false
		arrow.CastShadow = false
		arrow.Parent = pathModel
	end

	pathModel.Parent = parent
	return pathModel
end

-- Prompt 2: a separate Tutorial Portal, placed further along the Onboarding
-- District's own angle than the Quest Stage (a natural "next step, deeper
-- into the district" spatial narrative) — not inside the main central
-- spawn focal point. Tagged distinctly from BiomeGate (CollectionService
-- "TutorialPortal") so BiomeGateService's collision-group logic never
-- touches it; it has no lock state at all, it's always active. Also builds
-- ReturnLanding_Tutorial right beside it — the spot a player lands on when
-- they come back from the Tutorial Zone, distinct from HavenSpawn and from
-- every biome's own ReturnLanding_<BiomeId>.
local TUTORIAL_PORTAL_RADIUS_OFFSET = 25
local TUTORIAL_PORTAL_HEIGHT = 14
local TUTORIAL_PORTAL_WIDTH = 8

local function buildTutorialPortal(parent: Instance, origin: CFrame, districtCenter: Vector3, districtAngleDegrees: number, accentColor: Color3)
	GeneratorKit.CleanupPrevious(parent, "TutorialPortal")

	local direction = WorldMapConfig.DirectionForAngle(math.rad(districtAngleDegrees))
	local portalPosition = districtCenter + direction * TUTORIAL_PORTAL_RADIUS_OFFSET
	local portalCFrame = CFrame.new(portalPosition, origin.Position)

	local model = Instance.new("Model")
	model.Name = "TutorialPortal"

	GeneratorKit.NewPart({
		Name = "Foundation",
		Size = Vector3.new(TUTORIAL_PORTAL_WIDTH + 4, 1, 6),
		CFrame = portalCFrame * CFrame.new(0, 0.5, 0),
		Material = Enum.Material.Concrete,
		Color = Color3.fromRGB(70, 70, 74),
		Parent = model,
	})

	for _, side in { -1, 1 } do
		GeneratorKit.NewPart({
			Name = if side < 0 then "PylonLeft" else "PylonRight",
			Size = Vector3.new(2, TUTORIAL_PORTAL_HEIGHT, 2),
			CFrame = portalCFrame * CFrame.new(side * TUTORIAL_PORTAL_WIDTH / 2, TUTORIAL_PORTAL_HEIGHT / 2 + 1, 0),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(60, 58, 62),
			Parent = model,
		})
	end

	GeneratorKit.NewPart({
		Name = "Crossbeam",
		Size = Vector3.new(TUTORIAL_PORTAL_WIDTH + 2, 1.5, 2),
		CFrame = portalCFrame * CFrame.new(0, TUTORIAL_PORTAL_HEIGHT + 1, 0),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(60, 58, 62),
		Parent = model,
	})

	local membrane = GeneratorKit.NewPart({
		Name = "PortalMembrane",
		Size = Vector3.new(TUTORIAL_PORTAL_WIDTH - 1, TUTORIAL_PORTAL_HEIGHT - 0.5, 0.6),
		CFrame = portalCFrame * CFrame.new(0, TUTORIAL_PORTAL_HEIGHT / 2 + 1, 0),
		Material = Enum.Material.ForceField,
		Color = accentColor,
		Transparency = 0.5,
		CanCollide = false,
		Parent = model,
	})
	CollectionService:AddTag(membrane, "TutorialPortal")

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TutorialPortalPrompt"
	prompt.ObjectText = "Tutorial Zone"
	prompt.ActionText = "Enter"
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = membrane

	GeneratorKit.NewPart({
		Name = "ReturnLanding_Tutorial",
		Size = Vector3.new(6, 0.5, 6),
		CFrame = portalCFrame * CFrame.new(0, 0.25, 8),
		Material = Enum.Material.Neon,
		Color = accentColor,
		Transparency = 0.5,
		CanCollide = false,
		Parent = model,
	})

	model.Parent = parent
end

local function findForestBiome(): BiomeConfig.BiomeDefinition
	for _, biome in BiomeConfig do
		if biome.id == "ForestWildlands" then
			return biome
		end
	end
	error("GuidanceGenerator: ForestWildlands missing from BiomeConfig")
end

function GuidanceGenerator.Build(parent: Instance, origin: CFrame, districtCenter: Vector3, districtAngleDegrees: number, accentColor: Color3)
	GeneratorKit.CleanupPrevious(parent, "QuestStage")
	GeneratorKit.CleanupPrevious(parent, "TutorialPath")
	GeneratorKit.CleanupPrevious(parent, "ForestGuidancePath")

	local questFacility = findQuestFacility()

	local stageModel = Instance.new("Model")
	stageModel.Name = "QuestStage"
	local stageCFrame = CFrame.new(districtCenter, origin.Position)
	buildQuestStage(stageModel, origin, stageCFrame, accentColor, questFacility)
	GeneratorKit.Finalize(stageModel, "Platform")
	stageModel.Parent = parent

	buildTutorialPortal(parent, origin, districtCenter, districtAngleDegrees, accentColor)

	-- Segment 1: spawn -> Quest Giver.
	buildSignpostPath(
		parent,
		"TutorialPath",
		origin,
		HavenLayoutConfig.SPAWN_ANGLE_DEGREES,
		districtAngleDegrees,
		SIGNPOST_ARC_RADIUS,
		districtCenter,
		SIGNPOST_COUNT,
		Color3.fromRGB(120, 220, 140)
	)

	-- Segment 2: Quest Giver -> Forest Gate, completing the requested
	-- Quest Giver -> Forest Gate -> Forest Wildlands chain. Uses the
	-- Forest gate's own accent color (not the Guidance District's) so the
	-- path visually reads as "leading toward Forest," not as more Guidance
	-- District signage.
	-- Survivor Haven redesign Phase 1: Forest's real gate angle now comes
	-- from HavenLayoutConfig.GateAngleForOrder (the new tight portal-arc
	-- formula), not WorldMapConfig.AngleForOrder (the old cardinal-90deg
	-- formula, still used elsewhere for the independent far-biome-origin
	-- landmark direction, but no longer where Haven's own gates actually
	-- sit) — using the old formula here would point this signpost path at
	-- the wrong angle entirely, disconnected from where the Forest gate
	-- really is.
	local forestBiome = findForestBiome()
	local forestGateAngle = HavenLayoutConfig.GateAngleForOrder(forestBiome.order)
	local forestGatePosition = origin.Position + WorldMapConfig.DirectionForAngle(math.rad(forestGateAngle)) * WorldMapConfig.HAVEN_PLAZA_RADIUS
	local forestAccentColor = forestBiome.gate.accentColor
	buildSignpostPath(
		parent,
		"ForestGuidancePath",
		origin,
		districtAngleDegrees,
		forestGateAngle,
		FOREST_PATH_ARC_RADIUS,
		forestGatePosition,
		FOREST_PATH_SIGNPOST_COUNT,
		forestAccentColor
	)
end

return GuidanceGenerator
