--!strict
-- Portal Expedition Zone rework: completes Survivor Haven's perimeter wall
-- across the arc HavenPlatformGenerator's own perimeter wall already leaves
-- open. That file's wall-skip range — ±(HavenLayoutConfig.
-- GATE_ARC_HALF_SPAN_DEGREES(45) + WorldMapConfig.GATE_BREACH_DEGREES(22)) =
-- ±67° — already matches exactly what this file fills, so
-- HavenPlatformGenerator.luau itself needs no changes at all; the seam is
-- exact by construction.
--
-- This file builds only the solid "pier" sections of a thick fortress wall
-- across that arc. Each gate's own alcove recess (the notch its portal sits
-- in) is built by GateGenerator itself, using the exact same alcove-width
-- formula duplicated below, so the two files always agree on exactly where
-- the wall has a gap — no shared module for a 2-line calculation, matching
-- this project's existing small-duplicated-constant convention (e.g. the
-- Leaderboard Hall / Base Gate angle constants).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BiomeConfig = require(ReplicatedStorage.Shared.Config.BiomeConfig)
local WorldMapConfig = require(ReplicatedStorage.Shared.Config.WorldMapConfig)
local HavenLayoutConfig = require(ReplicatedStorage.Shared.Config.HavenLayoutConfig)
local GeneratorKit = require(script.Parent.GeneratorKit)

local ColosseumWallGenerator = {}

local PLAZA_RADIUS = WorldMapConfig.HAVEN_PLAZA_RADIUS
local ARC_HALF_SPAN_DEGREES = HavenLayoutConfig.GATE_ARC_HALF_SPAN_DEGREES + WorldMapConfig.GATE_BREACH_DEGREES

-- Deliberately thicker/taller than HavenPlatformGenerator's plain wall
-- (5 studs / 26 tall) — a heavier "bastion" profile where the portals live,
-- with enough thickness to hold a real 8-stud alcove recess plus an 8-stud
-- solid backstop behind it (see GateGenerator's ALCOVE_DEPTH).
local WALL_THICKNESS = 16
local WALL_HEIGHT = 40
local WALL_CENTER_RADIUS = PLAZA_RADIUS + WALL_THICKNESS / 2 -- inner face at PLAZA_RADIUS (flush with each gate's anchor), outer face at PLAZA_RADIUS + WALL_THICKNESS

local SEGMENT_ANGLE_STEP = 5 -- degrees per solid pier sample
local BUTTRESS_ANGLE_STEP = 15 -- coarser interval for protruding buttress piers

-- Correction pass: the exclusion zone used to be alcoveHalfAngle + a full
-- extra SEGMENT_ANGLE_STEP(5deg) of margin, which skipped piers well past
-- where GateGenerator's alcove actually reaches — leaving a real, unfilled
-- ~5deg-half-angle sliver of open space beside every alcove (8 gaps total).
-- Fixed by shrinking the exclusion zone instead: piers are now allowed to
-- build a few studs *into* the alcove's own angular footprint, guaranteeing
-- overlap with GateGenerator's alcove side walls (which are widened by the
-- same margin, in studs, on that file's side) rather than leaving a gap.
local WALL_OVERLAP_STUDS = 4 -- angular overlap budget between pier and alcove, converted to degrees below
local SEGMENT_WIDTH_OVERLAP_STUDS = 1.5 -- extra fixed pad on top of the existing chord-match ratio, so pier-to-pier seams overlap rather than just touch
local TRANSITION_OVERLAP_DEGREES = 6 -- how far past ARC_HALF_SPAN_DEGREES this file actually builds, so its own end overlaps HavenPlatformGenerator's nearest surviving plain-wall segment (confirmed centered at +-67.5deg, spanning roughly +-61.9deg to +-73.1deg) instead of ending exactly at the theoretical boundary

-- Must match GateGenerator.luau's own ALCOVE_WIDTH formula exactly.
local BASE_ALCOVE_WIDTH = 22
local ALCOVE_WIDTH_MARGIN = 8

type ExclusionZone = { AngleDegrees: number, HalfAngleDegrees: number }

local function alcoveHalfAngleDegrees(scale: number): number
	local width = BASE_ALCOVE_WIDTH * scale + ALCOVE_WIDTH_MARGIN
	return math.deg(math.asin((width / 2) / PLAZA_RADIUS))
end

local function overlapAngleDegrees(radius: number): number
	return math.deg(WALL_OVERLAP_STUDS / radius)
end

local function gateExclusionZones(): { ExclusionZone }
	local zones = {}
	for _, biome in BiomeConfig do
		table.insert(zones, {
			AngleDegrees = HavenLayoutConfig.GateAngleForOrder(biome.order),
			HalfAngleDegrees = alcoveHalfAngleDegrees(biome.gate.scale),
		})
	end
	return zones
end

local function isNearAnyZone(angleDeg: number, zones: { ExclusionZone }): boolean
	for _, zone in zones do
		local delta = math.abs(((angleDeg - zone.AngleDegrees + 180) % 360) - 180)
		local exclusionHalfAngle = math.max(zone.HalfAngleDegrees - overlapAngleDegrees(PLAZA_RADIUS), 0)
		if delta <= exclusionHalfAngle then
			return true
		end
	end
	return false
end

local function buildPierSegment(parent: Instance, origin: CFrame, angleDeg: number)
	local segmentCFrame = origin * CFrame.Angles(0, math.rad(angleDeg), 0) * CFrame.new(0, WALL_HEIGHT / 2, -WALL_CENTER_RADIUS)
	local segmentWidth = 2 * WALL_CENTER_RADIUS * math.sin(math.rad(SEGMENT_ANGLE_STEP / 2)) * 1.05 + SEGMENT_WIDTH_OVERLAP_STUDS

	GeneratorKit.NewPart({
		Name = `Pier{angleDeg}`,
		Size = Vector3.new(segmentWidth, WALL_HEIGHT, WALL_THICKNESS),
		CFrame = segmentCFrame,
		Material = Enum.Material.Concrete,
		Color = Color3.fromRGB(82, 80, 78),
		Parent = parent,
	})

	-- Merlon crenellations along the top, same idiom as HavenPlatformGenerator's plain wall.
	for _, sign in { -1, 1 } do
		GeneratorKit.NewPart({
			Name = `Merlon{angleDeg}_{sign}`,
			Size = Vector3.new(segmentWidth * 0.32, 3.6, WALL_THICKNESS * 0.55),
			CFrame = segmentCFrame * CFrame.new(sign * segmentWidth * 0.28, WALL_HEIGHT / 2 + 1.8, WALL_THICKNESS * 0.1),
			Material = Enum.Material.Concrete,
			Color = Color3.fromRGB(82, 80, 78),
			Parent = parent,
		})
	end
end

-- A protruding buttress pier — real "reinforced concrete... structural
-- detail" the brief asks for, spaced coarser than the base wall segments.
local function buildButtress(parent: Instance, origin: CFrame, angleDeg: number)
	local buttressCFrame = origin * CFrame.Angles(0, math.rad(angleDeg), 0) * CFrame.new(0, WALL_HEIGHT * 0.42, -(WALL_CENTER_RADIUS + WALL_THICKNESS * 0.35))

	GeneratorKit.NewPart({
		Name = `Buttress{angleDeg}`,
		Size = Vector3.new(4.5, WALL_HEIGHT * 0.85, WALL_THICKNESS * 0.7),
		CFrame = buttressCFrame,
		Material = Enum.Material.Rock,
		Color = Color3.fromRGB(74, 72, 70),
		Parent = parent,
	})

	GeneratorKit.NewPart({
		Name = `ButtressTrim{angleDeg}`,
		Size = Vector3.new(5, 0.6, WALL_THICKNESS * 0.75),
		CFrame = buttressCFrame * CFrame.new(0, WALL_HEIGHT * 0.42 + 0.3, 0),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(56, 54, 58),
		CanCollide = false,
		Parent = parent,
	})
end

-- A wider, deeper pilaster block exactly where this arc wall meets
-- HavenPlatformGenerator's plain wall (±ARC_HALF_SPAN_DEGREES) — the plain
-- wall is centered on PLAZA_RADIUS (thickness 5) while this arc is centered
-- further out (thickness 16, inner face at PLAZA_RADIUS), so the two
-- profiles genuinely differ; a deliberate pilaster at the seam reads as
-- "this is where the fortress bastion begins" instead of an accidental step.
local function buildTransitionPilaster(parent: Instance, origin: CFrame, angleDeg: number)
	local pilasterCFrame = origin * CFrame.Angles(0, math.rad(angleDeg), 0) * CFrame.new(0, WALL_HEIGHT / 2, -WALL_CENTER_RADIUS)

	GeneratorKit.NewPart({
		Name = `TransitionPilaster{angleDeg}`,
		Size = Vector3.new(10, WALL_HEIGHT + 2, WALL_THICKNESS + 3),
		CFrame = pilasterCFrame,
		Material = Enum.Material.Concrete,
		Color = Color3.fromRGB(70, 68, 66),
		Parent = parent,
	})
end

function ColosseumWallGenerator.Build(parent: Instance, origin: CFrame): Model
	GeneratorKit.CleanupPrevious(parent, "ColosseumWall")

	local model = Instance.new("Model")
	model.Name = "ColosseumWall"

	local zones = gateExclusionZones()

	-- Builds a few degrees past +-ARC_HALF_SPAN_DEGREES (see
	-- TRANSITION_OVERLAP_DEGREES) so this arc's own end deliberately overlaps
	-- HavenPlatformGenerator's nearest surviving plain-wall segment instead of
	-- ending exactly at the theoretical seam.
	local buildHalfSpanDegrees = ARC_HALF_SPAN_DEGREES + TRANSITION_OVERLAP_DEGREES

	local angleDeg = -buildHalfSpanDegrees
	while angleDeg <= buildHalfSpanDegrees do
		if not isNearAnyZone(angleDeg, zones) then
			buildPierSegment(model, origin, angleDeg)
		end
		angleDeg += SEGMENT_ANGLE_STEP
	end

	local buttressAngle = -buildHalfSpanDegrees + BUTTRESS_ANGLE_STEP / 2
	while buttressAngle <= buildHalfSpanDegrees do
		if not isNearAnyZone(buttressAngle, zones) then
			buildButtress(model, origin, buttressAngle)
		end
		buttressAngle += BUTTRESS_ANGLE_STEP
	end

	buildTransitionPilaster(model, origin, -buildHalfSpanDegrees)
	buildTransitionPilaster(model, origin, buildHalfSpanDegrees)

	model.Parent = parent

	print(`[ColosseumWallGenerator] Colosseum wall section rebuilt: {buildHalfSpanDegrees * 2} degree arc, {WALL_THICKNESS}-stud thickness, 4 alcove openings reserved for GateGenerator.`)

	return model
end

return ColosseumWallGenerator
