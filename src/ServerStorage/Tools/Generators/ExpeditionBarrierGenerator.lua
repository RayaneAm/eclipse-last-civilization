--!strict
-- Portal Expedition Zone rework: the Eclipse security checkpoint across the
-- shared approach to the 4-portal arc. This file builds world geometry
-- only — the actual per-player collision comes from BiomeGateService's
-- "Barrier_ExpeditionSecurity" PhysicsService group (this file just tags
-- the field segments), and the per-player visual fade comes from the
-- client's ExpeditionBarrierController. Neither of those needs anything
-- from this file beyond the tag/attribute contract below.
--
-- Nothing here rotates or translates — the pylons, field segments, and
-- warning stripes are all fixed in world space. "Moving diagonal lines" is
-- a restrained Transparency pulse (AmbientController's AmbientPulse tag)
-- instead of any physical motion.

local CollectionService = game:GetService("CollectionService")
local GeneratorKit = require(script.Parent.GeneratorKit)

local ExpeditionBarrierGenerator = {}

local BARRIER_TAG = "ExpeditionSecurityBarrier"

local BARRIER_RADIUS = 80
-- Correction pass: was 50, narrower than the arc it's meant to gate (+-67deg,
-- see ColosseumWallGenerator.ARC_HALF_SPAN_DEGREES) — that left an
-- unguarded ~12-17deg wedge on each side, between the barrier and where the
-- plain perimeter wall reliably takes over, that a player could simply walk
-- through from the central plaza. Widened to +-69deg: matches/exceeds the
-- arc's real span with a small safety overlap so there is no gap left.
local BARRIER_HALF_SPAN_DEGREES = 69
local SEGMENT_COUNT = 10
local BARRIER_HEIGHT = 10

-- Playtest correction: the old single-point GuardBlock at exactly
-- +-BARRIER_HALF_SPAN_DEGREES didn't actually close anything — between the
-- barrier (radius 80) and the colosseum wall (radius ~140) there was ~60
-- studs of completely open plaza floor at every angle, so a player just
-- walked around the block. Replaced with two permanent pieces per side that
-- start exactly where the Tier-gated field's own real edge ends (so neither
-- can ever pinch a Tier 1+ player walking through the field) and together
-- close every radius/angle between the field and the real wall:
--   1. a short permanent end-cap arc, BARRIER_HALF_SPAN_DEGREES -> +END_CAP_SPAN_DEGREES,
--      at the field's own radius/height;
--   2. a permanent radial wing wall at the end-cap's own outer angle,
--      spanning from just inside the field out past the real wall's inner face.
local END_CAP_SPAN_DEGREES = 3
local WING_WALL_ANGLE_DEGREES = BARRIER_HALF_SPAN_DEGREES + END_CAP_SPAN_DEGREES
local WING_WALL_INNER_RADIUS = 76
local WING_WALL_OUTER_RADIUS = 145 -- overlaps into ColosseumWallGenerator's wall (inner face ~140, thickness 16)
local WING_WALL_THICKNESS = 4
local WING_WALL_HEIGHT = BARRIER_HEIGHT + 2

local FIELD_COLOR = Color3.fromRGB(220, 50, 50)
local PYLON_COLOR = Color3.fromRGB(38, 36, 40)

local function buildFieldSegment(parent: Instance, origin: CFrame, angleDeg: number, segmentSpanDeg: number)
	local segmentCFrame = origin * CFrame.Angles(0, math.rad(angleDeg), 0) * CFrame.new(0, BARRIER_HEIGHT / 2, -BARRIER_RADIUS)
	local segmentWidth = 2 * BARRIER_RADIUS * math.sin(math.rad(segmentSpanDeg / 2)) * 1.05

	local field = GeneratorKit.NewPart({
		Name = `Field{angleDeg}`,
		Size = Vector3.new(segmentWidth, BARRIER_HEIGHT, 1),
		CFrame = segmentCFrame,
		Material = Enum.Material.ForceField,
		Color = FIELD_COLOR,
		Transparency = 0.55,
		CanCollide = true,
		Parent = parent,
	})
	CollectionService:AddTag(field, BARRIER_TAG)

	-- Diagonal warning stripes — fixed geometry; only their Transparency
	-- pulses (AmbientPulse), nothing physically moves.
	local stripeCount = 4
	for i = 1, stripeCount do
		local t = (i - 0.5) / stripeCount
		local stripe = GeneratorKit.NewPart({
			Name = `Stripe{i}`,
			Size = Vector3.new(segmentWidth * 0.16, BARRIER_HEIGHT * 1.05, 0.15),
			CFrame = segmentCFrame * CFrame.new((t - 0.5) * segmentWidth, 0, -0.5) * CFrame.Angles(0, 0, math.rad(28)),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255, 210, 60),
			Transparency = 0.5,
			CanCollide = false,
			Parent = parent,
		})
		stripe:SetAttribute("PulseSpeed", 1 + i * 0.15)
		stripe:SetAttribute("PulseAmplitude", 0.2)
		CollectionService:AddTag(stripe, "AmbientPulse")
	end
end

local function buildPylon(parent: Instance, origin: CFrame, angleDeg: number)
	local pylonCFrame = origin * CFrame.Angles(0, math.rad(angleDeg), 0) * CFrame.new(0, 0, -BARRIER_RADIUS)
	local pylonHeight = BARRIER_HEIGHT + 2

	GeneratorKit.NewPart({
		Name = `Pylon{angleDeg}`,
		Size = Vector3.new(1.6, pylonHeight, 1.6),
		CFrame = pylonCFrame * CFrame.new(0, pylonHeight / 2, 0),
		Material = Enum.Material.Metal,
		Color = PYLON_COLOR,
		Parent = parent,
	})

	local light = GeneratorKit.NewPart({
		Name = `PylonLight{angleDeg}`,
		Size = Vector3.new(0.5, 0.5, 0.5),
		CFrame = pylonCFrame * CFrame.new(0, pylonHeight + 0.4, 0),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 60, 60),
		Shape = Enum.PartType.Ball,
		CanCollide = false,
		Parent = parent,
	})
	local pointLight = Instance.new("PointLight")
	pointLight.Color = Color3.fromRGB(255, 70, 70)
	pointLight.Brightness = 2
	pointLight.Range = 16
	pointLight.Parent = light
	CollectionService:AddTag(pointLight, "AmbientFlicker")
end

-- Permanent (never Tier-gated) arc segment filling exactly
-- [BARRIER_HALF_SPAN_DEGREES, WING_WALL_ANGLE_DEGREES] on each side, at the
-- same radius/height as the Tier-gated field. Starting precisely at the
-- field's own real edge — not a fraction earlier — means this can never
-- clip a Tier 1+ player walking through the field itself; the handoff from
-- "conditionally open" to "permanently solid" is exact.
local function buildEndCapSegment(parent: Instance, origin: CFrame, sign: number)
	local centerAngleDeg = sign * (BARRIER_HALF_SPAN_DEGREES + END_CAP_SPAN_DEGREES / 2)
	local segmentCFrame = origin * CFrame.Angles(0, math.rad(centerAngleDeg), 0) * CFrame.new(0, BARRIER_HEIGHT / 2, -BARRIER_RADIUS)
	local segmentWidth = 2 * BARRIER_RADIUS * math.sin(math.rad(END_CAP_SPAN_DEGREES / 2)) * 1.05

	local cap = GeneratorKit.NewPart({
		Name = `EndCap{centerAngleDeg}`,
		Size = Vector3.new(segmentWidth, BARRIER_HEIGHT, 1.5),
		CFrame = segmentCFrame,
		Material = Enum.Material.Concrete,
		Color = PYLON_COLOR,
		CanCollide = true,
		Parent = parent,
	})

	GeneratorKit.NewPart({
		Name = `EndCapTrim{centerAngleDeg}`,
		Size = Vector3.new(segmentWidth + 0.6, 0.6, 2.1),
		CFrame = segmentCFrame * CFrame.new(0, BARRIER_HEIGHT / 2 + 0.3, 0),
		Material = Enum.Material.Metal,
		Color = FIELD_COLOR,
		CanCollide = false,
		Parent = parent,
	})

	return cap
end

-- Permanent radial wing wall at the end-cap's own outer angle, spanning from
-- just inside the field/end-cap radius out past the real arena wall's inner
-- face — a single continuous slab, so no radius between WING_WALL_INNER_
-- RADIUS and WING_WALL_OUTER_RADIUS lets a player cross from inside this
-- angle to outside it. Always solid: Tier 1+ players already pass through
-- the field itself and never need these to open.
local function buildWingWall(parent: Instance, origin: CFrame, sign: number)
	local angleDeg = sign * WING_WALL_ANGLE_DEGREES
	local midRadius = (WING_WALL_INNER_RADIUS + WING_WALL_OUTER_RADIUS) / 2
	local wallLength = WING_WALL_OUTER_RADIUS - WING_WALL_INNER_RADIUS
	local wallCFrame = origin * CFrame.Angles(0, math.rad(angleDeg), 0) * CFrame.new(0, WING_WALL_HEIGHT / 2, -midRadius)

	GeneratorKit.NewPart({
		Name = `WingWall{angleDeg}`,
		Size = Vector3.new(WING_WALL_THICKNESS, WING_WALL_HEIGHT, wallLength),
		CFrame = wallCFrame,
		Material = Enum.Material.Concrete,
		Color = PYLON_COLOR,
		CanCollide = true,
		Parent = parent,
	})

	GeneratorKit.NewPart({
		Name = `WingWallCap{angleDeg}`,
		Size = Vector3.new(WING_WALL_THICKNESS + 0.6, 0.6, wallLength + 0.6),
		CFrame = wallCFrame * CFrame.new(0, WING_WALL_HEIGHT / 2 + 0.3, 0),
		Material = Enum.Material.Metal,
		Color = FIELD_COLOR,
		CanCollide = false,
		Parent = parent,
	})
end

local function buildSign(parent: Instance, origin: CFrame)
	local signCFrame = origin * CFrame.new(0, BARRIER_HEIGHT + 2.8, -BARRIER_RADIUS)

	local frame = GeneratorKit.NewPart({
		Name = "CheckpointSignFrame",
		Size = Vector3.new(16, 3.6, 0.6),
		CFrame = signCFrame,
		Material = Enum.Material.Metal,
		Color = PYLON_COLOR,
		CanCollide = false,
		Parent = parent,
	})

	local trim = GeneratorKit.NewPart({
		Name = "CheckpointSignTrim",
		Size = Vector3.new(16.3, 0.2, 0.7),
		CFrame = signCFrame * CFrame.new(0, -1.9, 0),
		Material = Enum.Material.Neon,
		Color = FIELD_COLOR,
		CanCollide = false,
		Parent = parent,
	})
	CollectionService:AddTag(trim, "AmbientPulse")

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CheckpointLabel"
	billboard.Size = UDim2.fromOffset(380, 74)
	billboard.MaxDistance = 100
	billboard.LightInfluence = 0
	billboard.Parent = frame
	CollectionService:AddTag(billboard, "ExpeditionCheckpointSign")

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = billboard

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 36)
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(245, 245, 250)
	title.TextStrokeColor3 = FIELD_COLOR
	title.TextStrokeTransparency = 0.35
	title.LayoutOrder = 1
	title.Text = "ECLIPSE SECURITY CHECKPOINT"
	title.Parent = billboard

	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.BackgroundTransparency = 1
	subtitle.Size = UDim2.new(1, 0, 0, 26)
	subtitle.Font = Enum.Font.GothamBold
	subtitle.TextScaled = true
	subtitle.TextColor3 = Color3.fromRGB(255, 160, 160)
	subtitle.LayoutOrder = 2
	subtitle.Text = "TUTORIAL REQUIRED"
	subtitle.Parent = billboard
end

function ExpeditionBarrierGenerator.Build(parent: Instance, origin: CFrame): Model
	GeneratorKit.CleanupPrevious(parent, "ExpeditionBarrier")

	local model = Instance.new("Model")
	model.Name = "ExpeditionBarrier"

	local segmentSpan = (BARRIER_HALF_SPAN_DEGREES * 2) / SEGMENT_COUNT
	for i = 0, SEGMENT_COUNT - 1 do
		local angleDeg = -BARRIER_HALF_SPAN_DEGREES + segmentSpan * (i + 0.5)
		buildFieldSegment(model, origin, angleDeg, segmentSpan)
	end

	for i = 0, SEGMENT_COUNT do
		local angleDeg = -BARRIER_HALF_SPAN_DEGREES + segmentSpan * i
		if i % 2 == 0 then
			buildPylon(model, origin, angleDeg)
		end
	end

	buildEndCapSegment(model, origin, -1)
	buildEndCapSegment(model, origin, 1)
	buildWingWall(model, origin, -1)
	buildWingWall(model, origin, 1)

	buildSign(model, origin)

	GeneratorKit.Finalize(model, nil)
	model.Parent = parent

	print(`[ExpeditionBarrierGenerator] Security barrier built: {BARRIER_HALF_SPAN_DEGREES * 2} degree span at radius {BARRIER_RADIUS}, {SEGMENT_COUNT} field segments.`)

	return model
end

return ExpeditionBarrierGenerator
