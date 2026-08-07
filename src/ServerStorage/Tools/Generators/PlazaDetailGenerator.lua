--!strict
-- Survivor Haven Phase 2: small social/waiting spaces scattered across the
-- plaza's open ground — benches, low seating walls, planters, a memorial
-- plinth, a utility table, a notice board. Deliberately placed between
-- existing facility clusters (never on top of a reserved footprint or a
-- main path) so this file never has to touch facility placement itself.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WorldMapConfig = require(ReplicatedStorage.Shared.Config.WorldMapConfig)
local HavenLayoutConfig = require(ReplicatedStorage.Shared.Config.HavenLayoutConfig)
local GeneratorKit = require(script.Parent.GeneratorKit)

local PlazaDetailGenerator = {}

-- Watch Terrace: left side, between Quest Giver (165°/85) and Daily Rewards
-- (145°/100) but pulled well inside their radius so it never touches either
-- facility's own approach.
local WATCH_TERRACE_ANGLE_DEGREES = 155
local WATCH_TERRACE_RADIUS = 55

-- Market Rest Nook: right side, between Leaderboard Hall (-160°/85) and
-- Survivor Market (-132°/100), same reasoning.
--
-- Phase 3A: nudged from -146°/r55 to -138°/r48 — the Leaderboard Hall grew
-- into a landmark (bounding radius ~16 -> ~26) and the original position
-- was no longer clear of it (verified via the same chord-distance check
-- used throughout this project: ~34.3 studs apart, needed ~40). The new
-- position is ~44.3 studs from the Hall (clear) and still well clear of
-- Survivor Market. This is the one position change in Phase 3A, and it's a
-- decorative social-space prop, not a HavenFacilityConfig facility.
local MARKET_NOOK_ANGLE_DEGREES = -138
local MARKET_NOOK_RADIUS = 48

-- Core-side Terraces: 2 small platforms flanking the Forward path, offset
-- far enough laterally to clear both the path (16 wide) and the canopy
-- pillar ring (radius 32, only ~6 studs off-axis near this radius).
--
-- Playtest correction: widened from 16 to 20 — at offset 16 (radius 50,
-- Forward path half-width 8) the real clearance once each terrace's own
-- ~4-stud half-width was netted out was thin enough to flag during a
-- walkability pass.
local CORE_SIDE_TERRACE_ANGLE_OFFSET = 20
local CORE_SIDE_TERRACE_RADIUS = 50

local function buildBench(parent: Instance, cframe: CFrame, name: string)
	GeneratorKit.NewPart({
		Name = `{name}_Seat`,
		Size = Vector3.new(4, 0.4, 1.4),
		CFrame = cframe * CFrame.new(0, 1.1, 0),
		Material = Enum.Material.WoodPlanks,
		Color = Color3.fromRGB(74, 56, 40),
		Parent = parent,
	})
	GeneratorKit.NewPart({
		Name = `{name}_Back`,
		Size = Vector3.new(4, 1.2, 0.25),
		CFrame = cframe * CFrame.new(0, 1.9, 0.6),
		Material = Enum.Material.WoodPlanks,
		Color = Color3.fromRGB(74, 56, 40),
		CanCollide = false,
		Parent = parent,
	})
	for _, side in { -1, 1 } do
		GeneratorKit.NewPart({
			Name = `{name}_Leg{side}`,
			Size = Vector3.new(0.3, 1.1, 1.2),
			CFrame = cframe * CFrame.new(side * 1.7, 0.55, 0),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(40, 38, 42),
			Parent = parent,
		})
	end
end

local function buildPlanter(parent: Instance, cframe: CFrame, name: string)
	GeneratorKit.NewPart({
		Name = `{name}_Box`,
		Size = Vector3.new(3, 1.6, 3),
		CFrame = cframe * CFrame.new(0, 0.8, 0),
		Material = Enum.Material.Concrete,
		Color = Color3.fromRGB(80, 78, 82),
		Parent = parent,
	})
	GeneratorKit.NewPart({
		Name = `{name}_Foliage`,
		Size = Vector3.new(2.3, 1.3, 2.3),
		CFrame = cframe * CFrame.new(0, 1.9, 0),
		Material = Enum.Material.Grass,
		Color = Color3.fromRGB(72, 112, 62),
		Shape = Enum.PartType.Ball,
		CanCollide = false,
		Parent = parent,
	})
end

-- Semicircle of benches facing a small memorial/beacon plinth — a quiet nod
-- to survivors lost before the Haven, not an interactive facility.
local function buildWatchTerrace(parent: Instance, plazaCenter: CFrame)
	local model = Instance.new("Model")
	model.Name = "WatchTerrace"

	local direction = WorldMapConfig.DirectionForAngle(math.rad(WATCH_TERRACE_ANGLE_DEGREES))
	local center = plazaCenter.Position + direction * WATCH_TERRACE_RADIUS
	local faceCFrame = CFrame.new(center, plazaCenter.Position)

	GeneratorKit.NewPart({
		Name = "TerraceDeck",
		Size = Vector3.new(11, 0.3, 8),
		CFrame = faceCFrame * CFrame.new(0, 0.15, 1),
		Material = Enum.Material.WoodPlanks,
		Color = Color3.fromRGB(78, 60, 44),
		CanCollide = false,
		Parent = model,
	})

	local plinth = GeneratorKit.NewPart({
		Name = "MemorialPlinth",
		Size = Vector3.new(1.6, 2.4, 1.6),
		CFrame = faceCFrame * CFrame.new(0, 1.2, -2.5),
		Material = Enum.Material.Basalt,
		Color = Color3.fromRGB(44, 42, 48),
		Parent = model,
	})

	local beacon = Instance.new("PointLight")
	beacon.Color = Color3.fromRGB(150, 120, 255)
	beacon.Brightness = 1.3
	beacon.Range = 14
	beacon.Parent = plinth
	CollectionService:AddTag(beacon, "AmbientFlicker")

	for i, benchAngleDeg in { -50, 0, 50 } do
		local benchCFrame = faceCFrame * CFrame.new(0, 0, 2.5) * CFrame.Angles(0, math.rad(benchAngleDeg), 0)
		buildBench(model, benchCFrame, `Bench{i}`)
	end

	buildPlanter(model, faceCFrame * CFrame.new(-4.5, 0, 3), "WatchPlanterLeft")
	buildPlanter(model, faceCFrame * CFrame.new(4.5, 0, 3), "WatchPlanterRight")

	model.Parent = parent
	return model
end

-- Curved low seating wall + a utility table + a notice board — the right-
-- side counterpart to the Watch Terrace.
local function buildMarketRestNook(parent: Instance, plazaCenter: CFrame)
	local model = Instance.new("Model")
	model.Name = "MarketRestNook"

	local direction = WorldMapConfig.DirectionForAngle(math.rad(MARKET_NOOK_ANGLE_DEGREES))
	local center = plazaCenter.Position + direction * MARKET_NOOK_RADIUS
	local faceCFrame = CFrame.new(center, plazaCenter.Position)

	GeneratorKit.NewPart({
		Name = "NookDeck",
		Size = Vector3.new(10, 0.3, 7),
		CFrame = faceCFrame * CFrame.new(0, 0.15, 0.5),
		Material = Enum.Material.Concrete,
		Color = Color3.fromRGB(92, 88, 84),
		CanCollide = false,
		Parent = model,
	})

	for i, wallAngleDeg in { -40, 0, 40 } do
		local segmentCFrame = faceCFrame * CFrame.new(0, 0, 2.8) * CFrame.Angles(0, math.rad(wallAngleDeg), 0) * CFrame.new(0, 0, 1.6)
		GeneratorKit.NewPart({
			Name = `SeatWall{i}`,
			Size = Vector3.new(3.4, 1.2, 0.8),
			CFrame = segmentCFrame,
			Material = Enum.Material.Concrete,
			Color = Color3.fromRGB(84, 80, 76),
			Parent = model,
		})
	end

	-- Playtest correction (Survivor Notices cleanup): was dead-center at the
	-- nook's front (facing the plaza), directly in a player's approach.
	-- Moved to one edge — a deliberate supply stack beside the seating, not
	-- across the entrance — mirrored away from the NoticeBoard's own side.
	GeneratorKit.NewPart({
		Name = "UtilityTable",
		Size = Vector3.new(2.6, 1, 2.6),
		CFrame = faceCFrame * CFrame.new(3, 0.5, 1),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(60, 58, 62),
		Parent = model,
	})

	local noticeBoard = GeneratorKit.NewPart({
		Name = "NoticeBoard",
		Size = Vector3.new(3.2, 2.4, 0.2),
		CFrame = faceCFrame * CFrame.new(-3.5, 1.4, -1.5) * CFrame.Angles(0, math.rad(20), 0),
		Material = Enum.Material.WoodPlanks,
		Color = Color3.fromRGB(70, 54, 40),
		CanCollide = false,
		Parent = model,
	})

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "NoticeLabel"
	billboard.Size = UDim2.fromOffset(160, 30)
	billboard.StudsOffset = Vector3.new(0, 1.6, 0)
	billboard.MaxDistance = 45
	billboard.LightInfluence = 0
	billboard.Parent = noticeBoard

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.Gotham
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = "SURVIVOR NOTICES"
	label.Parent = billboard

	model.Parent = parent
	return model
end

-- 2 small +1-stud platforms flanking the Forward path near the Core — a
-- place to sit while waiting, kept well outside the path's own width.
local function buildCoreSideTerraces(parent: Instance, plazaCenter: CFrame)
	local model = Instance.new("Model")
	model.Name = "CoreSideTerraces"

	for _, sign in { -1, 1 } do
		-- Left (sign<0) leans toward the positive-angle facility cluster,
		-- Right (sign>0) toward the negative-angle cluster — matching this
		-- codebase's left=positive/right=negative angle convention.
		local angleDegrees = if sign < 0
			then HavenLayoutConfig.SPAWN_ANGLE_DEGREES - CORE_SIDE_TERRACE_ANGLE_OFFSET
			else HavenLayoutConfig.SPAWN_ANGLE_DEGREES + CORE_SIDE_TERRACE_ANGLE_OFFSET
		local direction = WorldMapConfig.DirectionForAngle(math.rad(angleDegrees))
		local center = plazaCenter.Position + direction * CORE_SIDE_TERRACE_RADIUS
		local faceCFrame = CFrame.new(center, plazaCenter.Position)
		local name = if sign < 0 then "CoreSideTerraceLeft" else "CoreSideTerraceRight"

		GeneratorKit.NewPart({
			Name = `{name}_Deck`,
			Size = Vector3.new(8, 1, 6),
			CFrame = faceCFrame * CFrame.new(0, 0.5, 0),
			Material = Enum.Material.Concrete,
			Color = Color3.fromRGB(96, 92, 88),
			Parent = model,
		})

		-- Single shallow step on the outward-facing side, away from the
		-- Forward path.
		GeneratorKit.NewPart({
			Name = `{name}_Step`,
			Size = Vector3.new(8, 0.5, 1.6),
			CFrame = faceCFrame * CFrame.new(0, 0.25, 3.8),
			Material = Enum.Material.Concrete,
			Color = Color3.fromRGB(96, 92, 88),
			Parent = model,
		})

		buildBench(model, faceCFrame * CFrame.new(-1.8, 1, -1.2), `{name}_Bench1`)
		buildBench(model, faceCFrame * CFrame.new(1.8, 1, -1.2), `{name}_Bench2`)
		buildPlanter(model, faceCFrame * CFrame.new(0, 1, -2.6), `{name}_Planter`)
	end

	model.Parent = parent
	return model
end

function PlazaDetailGenerator.Build(parent: Instance, plazaCenter: CFrame): Model
	GeneratorKit.CleanupPrevious(parent, "PlazaDetails")

	local model = Instance.new("Model")
	model.Name = "PlazaDetails"

	buildWatchTerrace(model, plazaCenter)
	buildMarketRestNook(model, plazaCenter)
	buildCoreSideTerraces(model, plazaCenter)

	model.Parent = parent
	return model
end

return PlazaDetailGenerator
