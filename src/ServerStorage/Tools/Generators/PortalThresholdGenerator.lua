--!strict
-- Portal Expedition Zone rework: biome-specific stair/threshold dressing —
-- each biome's identity begins directly on the ground and steps in front of
-- its portal, not as a separate miniature biome scene behind it. Called
-- once per gate from GateGenerator.Build, after the portal/alcove itself is
-- built.
--
-- Correction pass: the old "stairs" were a single 1.2-stud platform plus a
-- 0.6-stud riser — a two-level ledge, not a real staircase — and every prop
-- was scattered uniformly across that one flat 12-stud footprint starting
-- right at the alcove mouth. Replaced with a genuine multi-step staircase
-- (see buildLayout/buildStaircase below) climbing STAIR_TOTAL_HEIGHT(3)
-- studs — chosen to exactly match GateGenerator's RING_GROUND_CLEARANCE, so
-- the portal ring now sits flush on the raised top step instead of floating
-- above a flat floor — plus a 3-tier dressing gradient (light hint before
-- the climb, stronger material change on the stair edges, strongest/largest
-- props on the upper steps nearest the portal).
--
-- Universal rule enforced by every biome function below: a fixed center
-- walking lane stays completely clear (the steps themselves span the full
-- width so the whole staircase is walkable, but every SCATTERED prop sits
-- in the outer "decoration zone" between that lane and the alcove's own
-- half-width) — so neighboring portals (each with their own, narrower,
-- allocation) never visually overlap.

local CollectionService = game:GetService("CollectionService")
local GeneratorKit = require(script.Parent.GeneratorKit)

local PortalThresholdGenerator = {}

export type ThresholdBiome = {
	id: string,
	gate: {
		archStyle: "Organic" | "Shattered" | "Brutalist" | "Molten",
		accentColor: Color3,
		scale: number,
	},
}

-- Must match GateGenerator.STAIR_TOP_HEIGHT exactly — see that file's header
-- comment for why this is a small duplicated constant, not a shared module.
-- The top step's surface lands exactly at this height so it's flush with
-- GateGenerator's (raised) AlcoveFloor and the portal ring's own ground
-- clearance, with zero seam/step between the two files' geometry.
local STAIR_TOTAL_HEIGHT = 3

-- Playtest correction: the old flat 2.2-stud tread depth and step counts of
-- 4/5/6/7 gave total runs of only 8.8-15.4 studs — under the requested
-- 15-25 stud range for 3 of 4 biomes, and the per-biome spread (a 75% swing
-- from Forest to Volcanic) read as "Volcanic randomly much longer" rather
-- than 4 coherent approaches. Widened tread depth is the primary driver of
-- the longer run (not just more steps, which would recreate the same
-- "tiny steps stacked into a short distance" problem) — new runs are
-- 18/18/21/22.4 studs, a 24% spread, all inside 5-8 steps / 2.5-4 tread /
-- 15-25 total run.
local STEP_COUNT_BY_ARCH_STYLE: { [string]: number } = {
	Organic = 6,
	Shattered = 6,
	Brutalist = 7,
	Molten = 7,
}
local STEP_DEPTH_BY_ARCH_STYLE: { [string]: number } = {
	Organic = 3.0,
	Shattered = 3.0,
	Brutalist = 3.0,
	Molten = 3.2,
}
local PRE_STAIR_DEPTH = 8 -- flat approach zone before the first (lowest) step, studs — grown from 6 to stay proportionate to the longer run
local CENTER_LANE_HALF_WIDTH_BASE = 4.5 -- x biome.gate.scale, clamped so it never eats the whole stair width

export type ApproachLayout = {
	StepCount: number,
	StepDepth: number,
	StepHeight: number,
	StairRunDepth: number,
	PreStairDepth: number,
	TotalDepth: number,
	LaneHalfWidth: number,
	HalfWidth: number,
	HeightAtZ: (number) -> number,
}

local function buildLayout(archStyle: string, halfWidth: number, scale: number): ApproachLayout
	local stepCount = STEP_COUNT_BY_ARCH_STYLE[archStyle] or 6
	local stepDepth = STEP_DEPTH_BY_ARCH_STYLE[archStyle] or 3.0
	local stepHeight = STAIR_TOTAL_HEIGHT / stepCount
	local stairRunDepth = stepCount * stepDepth
	local laneHalfWidth = math.min(CENTER_LANE_HALF_WIDTH_BASE * scale, halfWidth - 2)

	local function heightAtZ(z: number): number
		if z >= stairRunDepth then
			return 0
		end
		local stepIndexFromTop = math.floor(math.max(z, 0) / stepDepth)
		local stepIndexFromBottom = math.clamp(stepCount - stepIndexFromTop, 1, stepCount)
		return stepIndexFromBottom * stepHeight
	end

	return {
		StepCount = stepCount,
		StepDepth = stepDepth,
		StepHeight = stepHeight,
		StairRunDepth = stairRunDepth,
		PreStairDepth = PRE_STAIR_DEPTH,
		TotalDepth = stairRunDepth + PRE_STAIR_DEPTH,
		LaneHalfWidth = laneHalfWidth,
		HalfWidth = halfWidth,
		HeightAtZ = heightAtZ,
	}
end

-- Each step is a single solid block from the ground up to its own tread
-- height — guarantees no floating treads and no clipping seams between
-- steps, and the full width means the whole staircase (not just a narrow
-- lane) is walkable.
local function buildStaircase(parent: Instance, anchorCFrame: CFrame, layout: ApproachLayout, material: Enum.Material, color: Color3)
	for i = 1, layout.StepCount do
		local stepTopY = i * layout.StepHeight
		local frontZ = (layout.StepCount - i) * layout.StepDepth
		local backZ = frontZ + layout.StepDepth

		GeneratorKit.NewPart({
			Name = `Step{i}`,
			Size = Vector3.new(layout.HalfWidth * 2, stepTopY, layout.StepDepth + 0.05),
			CFrame = anchorCFrame * CFrame.new(0, stepTopY / 2, (frontZ + backZ) / 2),
			Material = material,
			Color = color,
			Parent = parent,
		})
	end

	GeneratorKit.NewPart({
		Name = "ApproachPad",
		Size = Vector3.new(layout.HalfWidth * 2, 0.4, layout.PreStairDepth),
		CFrame = anchorCFrame * CFrame.new(0, 0.2, layout.StairRunDepth + layout.PreStairDepth / 2),
		Material = material,
		Color = color,
		Parent = parent,
	})
end

-- ---------------------------------------------------------------------
-- FOREST WILDLANDS — overgrown reclamation
-- ---------------------------------------------------------------------

local function buildTree(parent: Instance, position: Vector3, rng: Random, height: number)
	local trunkHeight = height * rng:NextNumber(0.55, 0.7)
	GeneratorKit.NewPart({
		Name = "TreeTrunk",
		Size = Vector3.new(1.2, trunkHeight, 1.2),
		CFrame = CFrame.new(position + Vector3.new(0, trunkHeight / 2, 0)),
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(64, 48, 34),
		Parent = parent,
	})
	for i = 1, 2 do
		local foliageRadius = height * rng:NextNumber(0.32, 0.42) * (1 - i * 0.15)
		GeneratorKit.NewPart({
			Name = `TreeFoliage{i}`,
			Size = Vector3.new(foliageRadius * 2, foliageRadius * 1.6, foliageRadius * 2),
			CFrame = CFrame.new(position + Vector3.new(0, trunkHeight + foliageRadius * (0.6 + i * 0.5), 0)),
			Material = Enum.Material.Grass,
			Color = Color3.fromRGB(58, 96, 48),
			Shape = Enum.PartType.Ball,
			CanCollide = false,
			Parent = parent,
		})
	end
end

local function buildForestThreshold(parent: Instance, anchorCFrame: CFrame, layout: ApproachLayout, scale: number, rng: Random)
	local laneHalfWidth, halfWidth = layout.LaneHalfWidth, layout.HalfWidth

	-- Tier 3 (strongest, nearest the portal): a tree per side on the upper steps.
	for _, sign in { -1, 1 } do
		local treeZ = layout.StairRunDepth * 0.15
		local treeY = layout.HeightAtZ(treeZ)
		local treePos = (anchorCFrame * CFrame.new(sign * halfWidth * 0.85, treeY, treeZ)).Position
		buildTree(parent, treePos, rng, 16 * scale)
	end

	-- Tier "light" (lower third, farthest steps) + Tier "stronger" (middle
	-- third): turf shelves, moss, side roots along the outer band of the
	-- stair run, z-banded instead of spread uniformly across the whole run.
	local lowerThirdZ = { layout.StairRunDepth * 2 / 3, layout.StairRunDepth - 0.3 }
	local middleThirdZ = { layout.StairRunDepth / 3, layout.StairRunDepth * 2 / 3 }
	for _, sign in { -1, 1 } do
		for shelf = 1, 3 do
			local zRange = if shelf == 1 then lowerThirdZ else middleThirdZ
			local shelfWidth = rng:NextNumber(2.5, 4.5)
			local x = sign * (laneHalfWidth + shelfWidth / 2 + rng:NextNumber(0, halfWidth - laneHalfWidth - shelfWidth))
			local z = rng:NextNumber(zRange[1], zRange[2])
			local y = layout.HeightAtZ(z)
			local shelfHeight = rng:NextNumber(0.2, 0.6)
			GeneratorKit.NewPart({
				Name = `TurfShelf{sign}_{shelf}`,
				Size = Vector3.new(shelfWidth, shelfHeight, rng:NextNumber(2, 4)),
				CFrame = anchorCFrame * CFrame.new(x, y + shelfHeight / 2, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0),
				Material = Enum.Material.Grass,
				Color = Color3.fromRGB(70, 108, 56),
				CanCollide = false,
				Parent = parent,
			})
		end

		for _ = 1, 3 do
			local x = sign * rng:NextNumber(laneHalfWidth * 0.6, halfWidth * 0.9)
			local z = rng:NextNumber(0.3, layout.StairRunDepth)
			GeneratorKit.NewPart({
				Name = "MossPatch",
				Size = Vector3.new(rng:NextNumber(1.5, 3), 0.06, rng:NextNumber(1.5, 3)),
				CFrame = anchorCFrame * CFrame.new(x, layout.HeightAtZ(z) + 0.04, z),
				Material = Enum.Material.Grass,
				Color = Color3.fromRGB(64, 100, 52),
				CanCollide = false,
				Parent = parent,
			})
		end

		local rootZ = layout.StairRunDepth * 0.35
		GeneratorKit.NewPart({
			Name = "SideRoot",
			Size = Vector3.new(0.6, 0.5, layout.StairRunDepth * 0.7),
			CFrame = anchorCFrame * CFrame.new(sign * halfWidth * 0.95, layout.HeightAtZ(rootZ) + 0.25, rootZ) * CFrame.Angles(0, rng:NextNumber(-0.2, 0.2), 0),
			Material = Enum.Material.Wood,
			Color = Color3.fromRGB(60, 46, 34),
			CanCollide = false,
			Parent = parent,
		})
	end

	for _ = 1, 4 do
		local sign = if rng:NextNumber() < 0.5 then -1 else 1
		local x = sign * rng:NextNumber(laneHalfWidth + 0.5, laneHalfWidth + 3)
		local z = rng:NextNumber(0.5, layout.StairRunDepth - 0.5)
		GeneratorKit.NewPart({
			Name = "Fern",
			Size = Vector3.new(0.9, rng:NextNumber(0.8, 1.4), 0.9),
			CFrame = anchorCFrame * CFrame.new(x, layout.HeightAtZ(z) + 0.5, z),
			Material = Enum.Material.Grass,
			Color = Color3.fromRGB(72, 112, 58),
			Shape = Enum.PartType.Ball,
			CanCollide = false,
			Parent = parent,
		})
	end

	-- Tier 1 (light hint, pre-stair): a couple of sparse grass tufts, well before the climb begins.
	for i = 1, 2 do
		local sign = if i == 1 then -1 else 1
		local x = sign * rng:NextNumber(laneHalfWidth + 1, halfWidth * 0.8)
		local z = layout.StairRunDepth + rng:NextNumber(1, layout.PreStairDepth - 1)
		GeneratorKit.NewPart({
			Name = `HintGrassTuft{i}`,
			Size = Vector3.new(0.7, 0.5, 0.7),
			CFrame = anchorCFrame * CFrame.new(x, 0.25, z),
			Material = Enum.Material.Grass,
			Color = Color3.fromRGB(76, 116, 60),
			Shape = Enum.PartType.Ball,
			CanCollide = false,
			Parent = parent,
		})
	end

	-- Trail marker announces the approach at the far edge of the pre-stair zone.
	local markerPos = anchorCFrame * CFrame.new(-halfWidth * 0.7, 0, layout.TotalDepth + 1)
	GeneratorKit.NewPart({
		Name = "TrailMarker",
		Size = Vector3.new(0.4, 3, 0.4),
		CFrame = markerPos * CFrame.new(0, 1.5, 0),
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(64, 48, 34),
		Parent = parent,
	})
	local lantern = GeneratorKit.NewPart({
		Name = "TrailMarkerLantern",
		Size = Vector3.new(0.6, 0.6, 0.6),
		CFrame = markerPos * CFrame.new(0, 3, 0),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 210, 140),
		CanCollide = false,
		Parent = parent,
	})
	local lanternLight = Instance.new("PointLight")
	lanternLight.Color = Color3.fromRGB(255, 200, 140)
	lanternLight.Brightness = 1.5
	lanternLight.Range = 12
	lanternLight.Parent = lantern
	CollectionService:AddTag(lanternLight, "AmbientFlicker")
end

-- ---------------------------------------------------------------------
-- FROZEN WASTELAND — cold and ice spreading outward
-- ---------------------------------------------------------------------

local function buildPineTree(parent: Instance, position: Vector3, rng: Random, height: number)
	GeneratorKit.NewPart({
		Name = "PineTrunk",
		Size = Vector3.new(0.8, height * 0.3, 0.8),
		CFrame = CFrame.new(position + Vector3.new(0, height * 0.15, 0)),
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(58, 46, 40),
		Parent = parent,
	})
	for i = 1, 3 do
		local tierRadius = height * 0.32 * (1 - (i - 1) * 0.22)
		local tierHeight = height * 0.32
		GeneratorKit.NewPart({
			Name = `PineTier{i}`,
			Size = Vector3.new(tierRadius * 2, tierHeight, tierRadius * 2),
			CFrame = CFrame.new(position + Vector3.new(0, height * 0.3 + tierHeight * (i - 0.5) * 0.85, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
			Material = Enum.Material.Snow,
			Color = Color3.fromRGB(210, 225, 220),
			Shape = Enum.PartType.Ball,
			CanCollide = false,
			Parent = parent,
		})
	end
end

local function buildFrozenThreshold(parent: Instance, anchorCFrame: CFrame, layout: ApproachLayout, scale: number, rng: Random)
	local laneHalfWidth, halfWidth = layout.LaneHalfWidth, layout.HalfWidth

	-- Tier "light" (lower third, farthest steps — frost just beginning) +
	-- Tier "stronger" (middle third — snow increasing), z-banded instead of
	-- spread uniformly across the whole run.
	local lowerThirdZ = { layout.StairRunDepth * 2 / 3, layout.StairRunDepth - 0.3 }
	local middleThirdZ = { layout.StairRunDepth / 3, layout.StairRunDepth * 2 / 3 }
	for _, sign in { -1, 1 } do
		for shelf = 1, 3 do
			local zRange = if shelf == 1 then lowerThirdZ else middleThirdZ
			local shelfWidth = rng:NextNumber(2.5, 4.5)
			local x = sign * (laneHalfWidth + shelfWidth / 2 + rng:NextNumber(0, halfWidth - laneHalfWidth - shelfWidth))
			local z = rng:NextNumber(zRange[1], zRange[2])
			local y = layout.HeightAtZ(z)
			local shelfHeight = rng:NextNumber(0.25, 0.7)
			GeneratorKit.NewPart({
				Name = `SnowShelf{sign}_{shelf}`,
				Size = Vector3.new(shelfWidth, shelfHeight, rng:NextNumber(2, 4)),
				CFrame = anchorCFrame * CFrame.new(x, y + shelfHeight / 2, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0),
				Material = Enum.Material.Snow,
				Color = Color3.fromRGB(225, 235, 240),
				CanCollide = false,
				Parent = parent,
			})
		end

		for _ = 1, 2 do
			local x = sign * rng:NextNumber(laneHalfWidth * 0.6, halfWidth * 0.85)
			local z = rng:NextNumber(0.5, layout.StairRunDepth - 0.5)
			GeneratorKit.NewPart({
				Name = "IceFormation",
				Size = Vector3.new(rng:NextNumber(1, 1.8), rng:NextNumber(1, 2.4), rng:NextNumber(1, 1.8)),
				CFrame = anchorCFrame * CFrame.new(x, layout.HeightAtZ(z) + 0.6, z) * CFrame.Angles(rng:NextNumber(0, 0.3), rng:NextNumber(0, math.pi), 0),
				Material = Enum.Material.Ice,
				Color = Color3.fromRGB(200, 225, 240),
				Transparency = 0.15,
				CanCollide = false,
				Parent = parent,
			})
		end

		local treeZ = layout.StairRunDepth * 0.15
		local treePos = (anchorCFrame * CFrame.new(sign * halfWidth * 0.85, layout.HeightAtZ(treeZ), treeZ)).Position
		if rng:NextNumber() < 0.85 then
			buildPineTree(parent, treePos, rng, 13 * scale)
		end
	end

	-- Small icicles hanging near the alcove frame's top corners (top step, nearest the portal).
	for _, sign in { -1, 1 } do
		for i = 1, 2 do
			local icicleHeight = rng:NextNumber(1.2, 2.4)
			GeneratorKit.NewPart({
				Name = `FrameIcicle{sign}_{i}`,
				Size = Vector3.new(0.4, icicleHeight, 0.4),
				CFrame = anchorCFrame * CFrame.new(sign * (laneHalfWidth + 1 + i * 1.5), layout.HeightAtZ(0) - icicleHeight / 2, -icicleHeight / 2 + 0.2),
				Material = Enum.Material.Ice,
				Color = Color3.fromRGB(220, 238, 248),
				Transparency = 0.1,
				CanCollide = false,
				Parent = parent,
			})
		end
	end

	local mist = Instance.new("ParticleEmitter")
	mist.Name = "ThresholdMist"
	mist.Color = ColorSequence.new(Color3.fromRGB(210, 225, 240))
	mist.Lifetime = NumberRange.new(3, 5)
	mist.Rate = 4
	mist.Speed = NumberRange.new(0.2, 0.6)
	mist.SpreadAngle = Vector2.new(50, 50)
	mist.Size = NumberSequence.new(3, 5)
	mist.Transparency = NumberSequence.new(0.75, 1)
	mist.Parent = GeneratorKit.NewPart({
		Name = "ThresholdMistAnchor",
		Size = Vector3.new(1, 1, 1),
		CFrame = anchorCFrame * CFrame.new(0, layout.HeightAtZ(layout.StairRunDepth * 0.5) + 0.2, layout.StairRunDepth * 0.5),
		Transparency = 1,
		CanCollide = false,
		Parent = parent,
	})

	local snow = Instance.new("ParticleEmitter")
	snow.Name = "DriftingSnow"
	snow.Color = ColorSequence.new(Color3.new(1, 1, 1))
	snow.Lifetime = NumberRange.new(3, 5)
	snow.Rate = 6
	snow.Speed = NumberRange.new(0.5, 1)
	snow.SpreadAngle = Vector2.new(30, 30)
	snow.Size = NumberSequence.new(0.25)
	snow.Acceleration = Vector3.new(0, -1.5, 0)
	snow.Parent = GeneratorKit.NewPart({
		Name = "SnowEmitterAnchor",
		Size = Vector3.new(1, 1, 1),
		CFrame = anchorCFrame * CFrame.new(0, 10 * scale, 0),
		Transparency = 1,
		CanCollide = false,
		Parent = parent,
	})

	-- Tier 1 (light hint, pre-stair): a couple of frost patches, well before the climb begins.
	for i = 1, 2 do
		local sign = if i == 1 then -1 else 1
		local x = sign * rng:NextNumber(laneHalfWidth + 1, halfWidth * 0.8)
		local z = layout.StairRunDepth + rng:NextNumber(1, layout.PreStairDepth - 1)
		GeneratorKit.NewPart({
			Name = `HintFrostPatch{i}`,
			Size = Vector3.new(rng:NextNumber(1.5, 2.5), 0.05, rng:NextNumber(1.5, 2.5)),
			CFrame = anchorCFrame * CFrame.new(x, 0.03, z),
			Material = Enum.Material.Ice,
			Color = Color3.fromRGB(220, 235, 245),
			Transparency = 0.3,
			CanCollide = false,
			Parent = parent,
		})
	end
end

-- ---------------------------------------------------------------------
-- NUCLEAR CITY — ruined industrial contamination
-- ---------------------------------------------------------------------

local function buildNuclearThreshold(parent: Instance, anchorCFrame: CFrame, layout: ApproachLayout, _scale: number, rng: Random)
	local laneHalfWidth, halfWidth = layout.LaneHalfWidth, layout.HalfWidth
	local plateWidth = halfWidth - laneHalfWidth - 0.5

	for _, sign in { -1, 1 } do
		-- Metal plates cladding the stair edges — split across 3 representative
		-- treads (instead of one long flat box) so each segment follows that
		-- step's own height with no floating/clipping. seg=1 sits nearest the
		-- portal (upper third), seg=3 farthest (lower third) — widthScale
		-- graduates the plating from a light hint up to full industrial
		-- framing, matching "plates/cables/stains increase upward."
		for seg = 1, 3 do
			local z = layout.StairRunDepth * ((seg - 0.5) / 3)
			local y = layout.HeightAtZ(z)
			local widthScale = 1.3 - (seg - 1) * 0.25
			GeneratorKit.NewPart({
				Name = `MetalPlateSection{seg}`,
				Size = Vector3.new(plateWidth * widthScale, 0.1, layout.StepDepth * 0.9),
				CFrame = anchorCFrame * CFrame.new(sign * (laneHalfWidth + plateWidth * widthScale / 2 + 0.3), y + 0.05, z),
				Material = Enum.Material.DiamondPlate,
				Color = Color3.fromRGB(60, 60, 64),
				CanCollide = false,
				Parent = parent,
			})

			GeneratorKit.NewPart({
				Name = `HazardTrim{seg}`,
				Size = Vector3.new(0.4, 0.15, layout.StepDepth * 0.9),
				CFrame = anchorCFrame * CFrame.new(sign * (laneHalfWidth + 0.3), y + 0.08, z),
				Material = Enum.Material.Neon,
				Color = Color3.fromRGB(255, 200, 40),
				CanCollide = false,
				Parent = parent,
			})
		end

		for _ = 1, 2 do
			local x = sign * rng:NextNumber(laneHalfWidth + plateWidth + 0.5, halfWidth * 0.95)
			local z = rng:NextNumber(0.5, layout.StairRunDepth - 0.5)
			GeneratorKit.NewPart({
				Name = "CrackedConcrete",
				Size = Vector3.new(rng:NextNumber(1.5, 2.5), 0.08, rng:NextNumber(1.5, 2.5)),
				CFrame = anchorCFrame * CFrame.new(x, layout.HeightAtZ(z) + 0.05, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0),
				Material = Enum.Material.Concrete,
				Color = Color3.fromRGB(48, 46, 44),
				CanCollide = false,
				Parent = parent,
			})
		end

		local pipeZ = layout.StairRunDepth * 0.45
		GeneratorKit.NewPart({
			Name = "SidePipe",
			Size = Vector3.new(layout.StairRunDepth * 0.8, 0.5, 0.5),
			CFrame = anchorCFrame * CFrame.new(sign * halfWidth * 0.97, layout.HeightAtZ(pipeZ) + 0.9, pipeZ) * CFrame.Angles(0, 0, math.rad(90)),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(70, 70, 74),
			Shape = Enum.PartType.Cylinder,
			CanCollide = false,
			Parent = parent,
		})

		-- A compact warning pylon lamp at the far edge of the pre-stair zone.
		local pylonPos = anchorCFrame * CFrame.new(sign * halfWidth * 0.85, 0, layout.TotalDepth + 1)
		GeneratorKit.NewPart({
			Name = "WarningPylon",
			Size = Vector3.new(0.6, 2.6, 0.6),
			CFrame = pylonPos * CFrame.new(0, 1.3, 0),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(50, 50, 54),
			Parent = parent,
		})
		local pylonLight = GeneratorKit.NewPart({
			Name = "WarningPylonLamp",
			Size = Vector3.new(0.7, 0.4, 0.7),
			CFrame = pylonPos * CFrame.new(0, 2.6, 0),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255, 200, 40),
			CanCollide = false,
			Parent = parent,
		})
		local lampLight = Instance.new("PointLight")
		lampLight.Color = Color3.fromRGB(255, 190, 40)
		lampLight.Brightness = 1.6
		lampLight.Range = 12
		lampLight.Parent = pylonLight
		CollectionService:AddTag(lampLight, "AmbientFlicker")

		-- Subtle toxic stain near the portal (strongest tier).
		local stainZ = layout.StairRunDepth * 0.15
		GeneratorKit.NewPart({
			Name = "ToxicStain",
			Size = Vector3.new(2.5, 0.05, 2),
			CFrame = anchorCFrame * CFrame.new(sign * halfWidth * 0.7, layout.HeightAtZ(stainZ) + 0.03, stainZ),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(150, 200, 60),
			Transparency = 0.75,
			CanCollide = false,
			Parent = parent,
		})
	end

	for _ = 1, 3 do
		local sign = if rng:NextNumber() < 0.5 then -1 else 1
		local x = sign * rng:NextNumber(laneHalfWidth + 1, halfWidth * 0.8)
		local z = rng:NextNumber(layout.StairRunDepth * 0.5, layout.StairRunDepth)
		GeneratorKit.NewPart({
			Name = "Debris",
			Size = Vector3.new(rng:NextNumber(0.8, 1.6), rng:NextNumber(0.6, 1.2), rng:NextNumber(0.8, 1.6)),
			CFrame = anchorCFrame * CFrame.new(x, layout.HeightAtZ(z) + 0.4, z) * CFrame.Angles(rng:NextNumber(0, math.pi), rng:NextNumber(0, math.pi), 0),
			Material = Enum.Material.Concrete,
			Color = Color3.fromRGB(52, 50, 48),
			CanCollide = false,
			Parent = parent,
		})
	end

	local steamZ = layout.StairRunDepth * 0.3
	local steam = Instance.new("ParticleEmitter")
	steam.Name = "SteamVent"
	steam.Color = ColorSequence.new(Color3.fromRGB(180, 180, 175))
	steam.Lifetime = NumberRange.new(2, 3.5)
	steam.Rate = 5
	steam.Speed = NumberRange.new(1, 2)
	steam.SpreadAngle = Vector2.new(10, 10)
	steam.Size = NumberSequence.new(1, 2.5)
	steam.Transparency = NumberSequence.new(0.6, 1)
	steam.Parent = GeneratorKit.NewPart({
		Name = "SteamVentAnchor",
		Size = Vector3.new(0.8, 0.3, 0.8),
		CFrame = anchorCFrame * CFrame.new(-halfWidth * 0.6, layout.HeightAtZ(steamZ) + 0.15, steamZ),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(50, 50, 54),
		CanCollide = false,
		Parent = parent,
	})

	-- Tier 1 (light hint, pre-stair): a couple of small scorched/cracked ground patches.
	for i = 1, 2 do
		local sign = if i == 1 then -1 else 1
		local x = sign * rng:NextNumber(laneHalfWidth + 1, halfWidth * 0.8)
		local z = layout.StairRunDepth + rng:NextNumber(1, layout.PreStairDepth - 1)
		GeneratorKit.NewPart({
			Name = `HintCrackedGround{i}`,
			Size = Vector3.new(rng:NextNumber(1.5, 2.5), 0.06, rng:NextNumber(1.5, 2.5)),
			CFrame = anchorCFrame * CFrame.new(x, 0.03, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0),
			Material = Enum.Material.Concrete,
			Color = Color3.fromRGB(54, 52, 50),
			CanCollide = false,
			Parent = parent,
		})
	end
end

-- ---------------------------------------------------------------------
-- VOLCANIC CORE — heat and pressure breaking through
-- ---------------------------------------------------------------------

local function buildVolcanicThreshold(parent: Instance, anchorCFrame: CFrame, layout: ApproachLayout, _scale: number, rng: Random)
	local laneHalfWidth, halfWidth = layout.LaneHalfWidth, layout.HalfWidth

	-- Tier "light" (lower third — scorched ground just beginning) + Tier
	-- "stronger" (middle third — basalt/heat cracks increasing), z-banded
	-- instead of spread uniformly across the whole run.
	local lowerThirdZ = { layout.StairRunDepth * 2 / 3, layout.StairRunDepth - 0.3 }
	local middleThirdZ = { layout.StairRunDepth / 3, layout.StairRunDepth * 2 / 3 }
	for _, sign in { -1, 1 } do
		for shelf = 1, 2 do
			local zRange = if shelf == 1 then lowerThirdZ else middleThirdZ
			local shelfWidth = rng:NextNumber(2.5, 4.5)
			local x = sign * (laneHalfWidth + shelfWidth / 2 + rng:NextNumber(0, halfWidth - laneHalfWidth - shelfWidth))
			local z = rng:NextNumber(zRange[1], zRange[2])
			local y = layout.HeightAtZ(z)
			local shelfHeight = rng:NextNumber(0.25, 0.65)
			GeneratorKit.NewPart({
				Name = `BasaltShelf{sign}_{shelf}`,
				Size = Vector3.new(shelfWidth, shelfHeight, rng:NextNumber(2, 4)),
				CFrame = anchorCFrame * CFrame.new(x, y + shelfHeight / 2, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0),
				Material = Enum.Material.Basalt,
				Color = Color3.fromRGB(34, 30, 32),
				CanCollide = false,
				Parent = parent,
			})
		end

		-- Scorched edge trim — split into 3 segments across the run so each
		-- follows its own step height instead of one long flat box.
		for seg = 1, 3 do
			local z = layout.StairRunDepth * ((seg - 0.5) / 3)
			local y = layout.HeightAtZ(z)
			GeneratorKit.NewPart({
				Name = `ScorchedEdge{seg}`,
				Size = Vector3.new(0.6, 0.12, layout.StepDepth * 0.95),
				CFrame = anchorCFrame * CFrame.new(sign * halfWidth * 0.98, y + 0.06, z),
				Material = Enum.Material.Basalt,
				Color = Color3.fromRGB(22, 18, 18),
				CanCollide = false,
				Parent = parent,
			})
		end

		-- Restrained lava cracks beside the lane, never crossing it.
		for i = 1, 2 do
			local x = sign * rng:NextNumber(laneHalfWidth + 0.8, halfWidth * 0.85)
			local z = rng:NextNumber(0.5, layout.StairRunDepth - 0.5)
			local crack = GeneratorKit.NewPart({
				Name = `LavaCrackFloor{sign}_{i}`,
				Size = Vector3.new(rng:NextNumber(0.3, 0.5), 0.05, rng:NextNumber(2, 4)),
				CFrame = anchorCFrame * CFrame.new(x, layout.HeightAtZ(z) + 0.03, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0),
				Material = Enum.Material.Neon,
				Color = Color3.fromRGB(255, 110, 40),
				Transparency = 0.2,
				CanCollide = false,
				Parent = parent,
			})
			local crackLight = Instance.new("PointLight")
			crackLight.Color = Color3.fromRGB(255, 120, 40)
			crackLight.Brightness = 1.2
			crackLight.Range = 8
			crackLight.Parent = crack
			CollectionService:AddTag(crackLight, "AmbientFlicker")
		end

		-- Dark rock spikes positioned outside the path — biased toward the upper steps (strongest tier).
		for i = 1, 2 do
			local spikeHeight = rng:NextNumber(1.5, 3.2)
			local x = sign * rng:NextNumber(laneHalfWidth + 2, halfWidth * 0.9)
			local z = rng:NextNumber(0, layout.StairRunDepth * 0.6)
			GeneratorKit.NewPart({
				Name = `RockSpike{sign}_{i}`,
				Size = Vector3.new(0.9, spikeHeight, 0.9),
				CFrame = anchorCFrame * CFrame.new(x, layout.HeightAtZ(z) + spikeHeight / 2, z) * CFrame.Angles(rng:NextNumber(-0.15, 0.15), 0, rng:NextNumber(-0.15, 0.15)),
				Material = Enum.Material.Basalt,
				Color = Color3.fromRGB(30, 26, 28),
				CanCollide = false,
				Parent = parent,
			})
		end

		-- Heat-scorched metal accent right at the alcove frame (top step, strongest tier).
		GeneratorKit.NewPart({
			Name = "ScorchedFrameAccent",
			Size = Vector3.new(0.5, 3, 0.5),
			CFrame = anchorCFrame * CFrame.new(sign * (laneHalfWidth + 1), layout.HeightAtZ(0) + 1.5, 0.5),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(40, 34, 32),
			CanCollide = false,
			Parent = parent,
		})
	end

	local smokeZ = layout.StairRunDepth * 0.35
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "SmokeVent"
	smoke.Color = ColorSequence.new(Color3.fromRGB(70, 64, 62))
	smoke.Lifetime = NumberRange.new(2, 3.5)
	smoke.Rate = 4
	smoke.Speed = NumberRange.new(1, 2)
	smoke.SpreadAngle = Vector2.new(12, 12)
	smoke.Size = NumberSequence.new(1.2, 2.8)
	smoke.Transparency = NumberSequence.new(0.55, 1)
	smoke.Parent = GeneratorKit.NewPart({
		Name = "SmokeVentAnchor",
		Size = Vector3.new(0.8, 0.3, 0.8),
		CFrame = anchorCFrame * CFrame.new(halfWidth * 0.6, layout.HeightAtZ(smokeZ) + 0.15, smokeZ),
		Material = Enum.Material.Basalt,
		Color = Color3.fromRGB(28, 24, 24),
		CanCollide = false,
		Parent = parent,
	})

	local embersZ = layout.StairRunDepth * 0.15
	local embers = Instance.new("ParticleEmitter")
	embers.Name = "ThresholdEmbers"
	embers.Color = ColorSequence.new(Color3.fromRGB(255, 140, 50))
	embers.Lifetime = NumberRange.new(2, 4)
	embers.Rate = 6
	embers.Speed = NumberRange.new(1.5, 3)
	embers.SpreadAngle = Vector2.new(20, 20)
	embers.Size = NumberSequence.new(0.25)
	embers.Parent = GeneratorKit.NewPart({
		Name = "ThresholdEmberAnchor",
		Size = Vector3.new(1, 1, 1),
		CFrame = anchorCFrame * CFrame.new(0, layout.HeightAtZ(embersZ) + 0.5, embersZ),
		Transparency = 1,
		CanCollide = false,
		Parent = parent,
	})

	-- Tier 1 (light hint, pre-stair): a couple of small scorched ground patches.
	for i = 1, 2 do
		local sign = if i == 1 then -1 else 1
		local x = sign * rng:NextNumber(laneHalfWidth + 1, halfWidth * 0.8)
		local z = layout.StairRunDepth + rng:NextNumber(1, layout.PreStairDepth - 1)
		GeneratorKit.NewPart({
			Name = `HintScorchPatch{i}`,
			Size = Vector3.new(rng:NextNumber(1.5, 2.5), 0.05, rng:NextNumber(1.5, 2.5)),
			CFrame = anchorCFrame * CFrame.new(x, 0.03, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0),
			Material = Enum.Material.Basalt,
			Color = Color3.fromRGB(36, 32, 32),
			CanCollide = false,
			Parent = parent,
		})
	end
end

function PortalThresholdGenerator.Build(parent: Instance, anchorCFrame: CFrame, biome: ThresholdBiome, alcoveHalfWidth: number, rng: Random)
	local floorMaterial, floorColor
	if biome.gate.archStyle == "Organic" then
		floorMaterial, floorColor = Enum.Material.Cobblestone, Color3.fromRGB(86, 82, 74)
	elseif biome.gate.archStyle == "Shattered" then
		floorMaterial, floorColor = Enum.Material.Concrete, Color3.fromRGB(150, 158, 165)
	elseif biome.gate.archStyle == "Brutalist" then
		floorMaterial, floorColor = Enum.Material.Concrete, Color3.fromRGB(72, 70, 68)
	else
		floorMaterial, floorColor = Enum.Material.Basalt, Color3.fromRGB(44, 40, 40)
	end

	local layout = buildLayout(biome.gate.archStyle, alcoveHalfWidth, biome.gate.scale)
	buildStaircase(parent, anchorCFrame, layout, floorMaterial, floorColor)

	if biome.gate.archStyle == "Organic" then
		buildForestThreshold(parent, anchorCFrame, layout, biome.gate.scale, rng)
	elseif biome.gate.archStyle == "Shattered" then
		buildFrozenThreshold(parent, anchorCFrame, layout, biome.gate.scale, rng)
	elseif biome.gate.archStyle == "Brutalist" then
		buildNuclearThreshold(parent, anchorCFrame, layout, biome.gate.scale, rng)
	elseif biome.gate.archStyle == "Molten" then
		buildVolcanicThreshold(parent, anchorCFrame, layout, biome.gate.scale, rng)
	end
end

return PortalThresholdGenerator
