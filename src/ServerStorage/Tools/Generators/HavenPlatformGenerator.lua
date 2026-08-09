--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HavenLayoutConfig = require(ReplicatedStorage.Shared.Config.HavenLayoutConfig)
local GeneratorKit = require(script.Parent.GeneratorKit)
local HavenGroundGenerator = require(script.Parent.HavenGroundGenerator)

local HavenPlatformGenerator = {}

-- One height contract owns the final ground. Base surface tiles meet edge to
-- edge; navigation plates sit clearly above them and never overlap each other
-- coplanarly.
local PALETTE = HavenGroundGenerator.Palette
local PATH_TOP = HavenGroundGenerator.PATH_TOP
local SURFACE_TOP = HavenGroundGenerator.SURFACE_TOP
local CURB = Color3.fromRGB(52, 47, 41)
local PATH_THICKNESS = PATH_TOP - SURFACE_TOP

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	material: Enum.Material,
	color: Color3,
	collide: boolean?
): Part
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

-- A thin route plate with its top at PATH_TOP, so it sits a hair proud of
-- the settlement surface: enough to read as a laid path, far too little to
-- read as a curb (the previous floor left a 0.48 stud lip around every route).
local function path(parent: Instance, origin: CFrame, name: string, center: Vector3, size: Vector3)
	local route = part(
		parent,
		name,
		Vector3.new(size.X, PATH_THICKNESS, size.Z),
		origin * CFrame.new(center.X, PATH_TOP - PATH_THICKNESS / 2, center.Z),
		Enum.Material.Concrete,
		PALETTE.Pavement,
		false
	)
	route:SetAttribute("HavenNavigationSurface", true)
end

local function pathBetween(
	parent: Instance,
	origin: CFrame,
	name: string,
	a: Vector3,
	b: Vector3,
	width: number,
	endTrim: number?
)
	local worldA = origin:PointToWorldSpace(a)
	local worldB = origin:PointToWorldSpace(b)
	local direction = (worldB - worldA).Unit
	-- Dirt seams make angled survivor-laid connections intentional and keep
	-- their rectangular caps physically separate. The front forecourt uses a
	-- wider seam because its short segments change direction more sharply.
	local trim = endTrim or 0.3
	local trimmedA = worldA + direction * trim
	local trimmedB = worldB - direction * trim
	local midpoint = (trimmedA + trimmedB) / 2 + Vector3.new(0, PATH_TOP - PATH_THICKNESS / 2, 0)
	local route = part(
		parent,
		name,
		Vector3.new(width, PATH_THICKNESS, (trimmedB - trimmedA).Magnitude),
		CFrame.lookAt(midpoint, Vector3.new(trimmedB.X, midpoint.Y, trimmedB.Z)),
		Enum.Material.Concrete,
		PALETTE.PavementWorn,
		false
	)
	route:SetAttribute("HavenNavigationSurface", true)
end

local function repairPlate(parent: Instance, origin: CFrame, name: string, position: Vector3, size: Vector3, angle: number)
	part(parent, name, size, origin * CFrame.new(position.X, PATH_TOP + size.Y / 2, position.Z) * CFrame.Angles(0, math.rad(angle), 0), Enum.Material.CorrodedMetal, Color3.fromRGB(88, 78, 66), false)
end

local function surfaceTile(
	parent: Instance,
	origin: CFrame,
	name: string,
	minX: number,
	maxX: number,
	minZ: number,
	maxZ: number,
	material: Enum.Material,
	color: Color3
)
	local tile = part(
		parent,
		name,
		Vector3.new(maxX - minX, 1, maxZ - minZ),
		origin * CFrame.new((minX + maxX) / 2, SURFACE_TOP - 0.5, (minZ + maxZ) / 2),
		material,
		color
	)
	tile:SetAttribute("HavenGroundSurface", true)
end

local function buildSettlementSurface(parent: Instance, origin: CFrame)
	-- Nine edge-matched tiles replace the old 156x156 cement/earth plate plus
	-- hundreds of coplanar overlays. Materials shift by settlement zone without
	-- any two top faces occupying the same X/Z area.
	local wallInset = HavenLayoutConfig.PERIMETER_WALL_THICKNESS / 2
	local xBands = {
		HavenLayoutConfig.HAVEN_MIN_X + wallInset,
		-40,
		40,
		HavenLayoutConfig.HAVEN_MAX_X - wallInset,
	}
	local zBands = {
		HavenLayoutConfig.HAVEN_MIN_Z + wallInset,
		12,
		70,
		HavenLayoutConfig.HAVEN_MAX_Z - wallInset,
	}
	local styles = {
		{
			{ Enum.Material.Ground, PALETTE.EarthDark, "NorthWestGround" },
			{ Enum.Material.Slate, PALETTE.Gravel, "NorthApproachGround" },
			{ Enum.Material.Ground, PALETTE.EarthDark, "NorthEastGround" },
		},
		{
			{ Enum.Material.Ground, PALETTE.EarthDark, "WestSettlementGround" },
			{ Enum.Material.Ground, PALETTE.Earth, "SettlementSurface" },
			{ Enum.Material.Ground, PALETTE.EarthDark, "EastSettlementGround" },
		},
		{
			{ Enum.Material.Ground, PALETTE.Dust, "ArrivalWestGround" },
			{ Enum.Material.Sand, PALETTE.Sand, "ArrivalGround" },
			{ Enum.Material.Ground, PALETTE.Dust, "ArrivalEastGround" },
		},
	}
	for zIndex = 1, 3 do
		for xIndex = 1, 3 do
			local style = styles[zIndex][xIndex]
			surfaceTile(
				parent,
				origin,
				style[3] :: string,
				xBands[xIndex],
				xBands[xIndex + 1],
				zBands[zIndex],
				zBands[zIndex + 1],
				style[1] :: Enum.Material,
				style[2] :: Color3
			)
		end
	end
end

local function buildCampForecourtSweep(parent: Instance, origin: CFrame)
	-- Two gently broken survivor-made branches frame, but never cross, the
	-- dominant sixteen-stud central arrival lane. The east branch used to run
	-- to the Haven Guide booth; it now opens onto the camp fire circle.
	local campCenters = {
		Vector3.new(12.5, 0, 98),
		Vector3.new(16, 0, 94),
		Vector3.new(20, 0, 89),
		HavenLayoutConfig.CAMP_CIRCLE_LOCAL_POSITION,
	}
	for index = 1, #campCenters - 1 do
		pathBetween(parent, origin, `CampForecourtSweep{index}`, campCenters[index], campCenters[index + 1], 7 + index, 1.3)
	end
	local baseCenters = {
		Vector3.new(-12.5, 0, 98),
		Vector3.new(-19, 0, 93),
		Vector3.new(-29, 0, 86),
		HavenLayoutConfig.BASE_GATE_LOCAL_POSITION,
	}
	for index = 1, #baseCenters - 1 do
		local name = if index == #baseCenters - 1 then "BaseApproach" else `BaseForecourtSweep{index}`
		pathBetween(parent, origin, name, baseCenters[index], baseCenters[index + 1], 7 + index, 1.3)
	end
	repairPlate(parent, origin, "ArrivalRepairPlate1", Vector3.new(-3.5, 0, 102), Vector3.new(5, 0.16, 7), -7)
	repairPlate(parent, origin, "ArrivalRepairPlate2", Vector3.new(3.7, 0, 94), Vector3.new(4.5, 0.16, 6), 8)
	repairPlate(parent, origin, "ArrivalRepairPlate3", Vector3.new(-3, 0, 86), Vector3.new(5, 0.16, 6), 4)
end

function HavenPlatformGenerator.Build(parent: Instance, origin: CFrame): { Model: Model, PlazaCenter: CFrame }
	GeneratorKit.CleanupPrevious(parent, "HavenPlatform")
	local model = Instance.new("Model")
	model.Name = "HavenPlatform"
	local havenWidth = HavenLayoutConfig.HAVEN_MAX_X - HavenLayoutConfig.HAVEN_MIN_X
	local havenDepth = HavenLayoutConfig.HAVEN_MAX_Z - HavenLayoutConfig.HAVEN_MIN_Z
	local havenCenterX = (HavenLayoutConfig.HAVEN_MIN_X + HavenLayoutConfig.HAVEN_MAX_X) / 2
	local havenCenterZ = (HavenLayoutConfig.HAVEN_MIN_Z + HavenLayoutConfig.HAVEN_MAX_Z) / 2
	part(
		model,
		"SettlementFoundation",
		Vector3.new(havenWidth, 3, havenDepth),
		origin * CFrame.new(havenCenterX, -1.5, havenCenterZ),
		Enum.Material.Slate,
		PALETTE.Foundation
	)
	buildSettlementSurface(model, origin)
	-- Authored navigation spine and service pockets.
	path(model, origin, "ArrivalLane", Vector3.new(0, 0, 93), Vector3.new(16, 1, 34))
	path(model, origin, "SouthServiceSpine", Vector3.new(0, 0, 59), Vector3.new(14, 1, 34))
	path(model, origin, "CentralServiceSpine", Vector3.new(0, 0, 27), Vector3.new(14, 1, 30))
	path(model, origin, "ExpeditionApproach", Vector3.new(0, 0, 0), Vector3.new(18, 1, 24))
	-- Two offset service walks and staggered connectors keep every wall-backed
	-- entrance easy to reach without reading as three identical kiosk rows.
	path(model, origin, "WestServiceWalk", Vector3.new(-31, 0, 26), Vector3.new(8, 1, 74))
	path(model, origin, "EastServiceWalk", Vector3.new(31, 0, 38.5), Vector3.new(8, 1, 49))
	pathBetween(model, origin, "MarketBranch", Vector3.new(-7.2, 0, 52), Vector3.new(-26.8, 0, 52), 9)
	pathBetween(model, origin, "UpgradeBranch", Vector3.new(7.2, 0, 52), Vector3.new(26.8, 0, 52), 9)
	pathBetween(model, origin, "CosmeticBranch", Vector3.new(-7.2, 0, 26), Vector3.new(-26.8, 0, 26), 9)
	pathBetween(model, origin, "RewardsBranch", Vector3.new(7.2, 0, 25), Vector3.new(26.8, 0, 25), 9)
	pathBetween(model, origin, "LaboratoryBranch", Vector3.new(-9.2, 0, 0), Vector3.new(-26.8, 0, 0), 9)
	pathBetween(model, origin, "LeaderboardBranch", Vector3.new(10.2, 0, -6), Vector3.new(17, 0, -7), 9)
	buildCampForecourtSweep(model, origin)
	-- Raised boardwalk transitions, edge clutter and practical string lights;
	-- this generator no longer creates any competing broad floor layer.
	HavenGroundGenerator.Build(model, origin)
	-- Physical side and south retaining boundaries keep the settlement legible.
	local wallThickness = HavenLayoutConfig.PERIMETER_WALL_THICKNESS
	local wallHeight = HavenLayoutConfig.PERIMETER_WALL_HEIGHT
	for _, x in { HavenLayoutConfig.HAVEN_MIN_X, HavenLayoutConfig.HAVEN_MAX_X } do
		part(
			model,
			"SideRetainingWall",
			Vector3.new(wallThickness, wallHeight, havenDepth + wallThickness),
			origin * CFrame.new(x, wallHeight / 2, havenCenterZ),
			Enum.Material.Concrete,
			CURB
		)
	end
	part(
		model,
		"SouthRetainingWall",
		Vector3.new(havenWidth + wallThickness, wallHeight, wallThickness),
		origin * CFrame.new(0, wallHeight / 2, HavenLayoutConfig.HAVEN_MAX_Z),
		Enum.Material.Concrete,
		CURB
	)
	GeneratorKit.Finalize(model, "SettlementFoundation")
	model.Parent = parent
	return { Model = model, PlazaCenter = origin }
end

return HavenPlatformGenerator
