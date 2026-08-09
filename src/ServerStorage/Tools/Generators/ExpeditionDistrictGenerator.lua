--!strict
-- Secured Expedition staging area: a straight gateway/causeway opens into a
-- broad progression-ordered portal fan framed by reinforced district walls.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HavenLayoutConfig = require(ReplicatedStorage.Shared.Config.HavenLayoutConfig)
local GeneratorKit = require(script.Parent.GeneratorKit)

local ExpeditionDistrictGenerator = {}

local DISTRICT_WALL_HEIGHT = 22
local POCKET_WALL_HEIGHT = 15
local POCKET_DEPTH = 38
local BACK_WALL_RADIUS = 118
local ARC_WALL_SEGMENTS = 14
local DISTRICT_WIDTH = 260
local DISTRICT_SIDE_X = DISTRICT_WIDTH / 2 - 1
local THEMED_APPROACH_LENGTH = 36
local GATHERING_DIAMETER = 24
local GATHERING_RADIUS = GATHERING_DIAMETER / 2
local CONNECTOR_START_RADIUS = 20

-- The slab's front still meets Haven's own perimeter; its rear is derived from
-- the arc so translating the fan toward Haven can never leave the curved
-- defense wall hanging off the back of the foundation, nor drag a hundred
-- studs of empty slab along behind it. Front and rear are the only Z values
-- this generator fixes itself — everything else reads the arc.
local DISTRICT_FRONT_Z = HavenLayoutConfig.EXPEDITION_GATEWAY_LOCAL_POSITION.Z + 5
local DISTRICT_REAR_Z = HavenLayoutConfig.EXPEDITION_ARC_CENTER_LOCAL_POSITION.Z - BACK_WALL_RADIUS - 10
local DISTRICT_DEPTH = DISTRICT_FRONT_Z - DISTRICT_REAR_Z
local DISTRICT_CENTER_Z = (DISTRICT_FRONT_Z + DISTRICT_REAR_Z) / 2

local PORTAL_ORDER = {
	"ForestWildlands",
	"FrozenWasteland",
	"NuclearCity",
	"VolcanicCore",
}

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

local function pathBetween(parent: Instance, origin: CFrame, name: string, a: Vector3, b: Vector3, width: number)
	local worldA = origin:PointToWorldSpace(a)
	local worldB = origin:PointToWorldSpace(b)
	local midpoint = (worldA + worldB) / 2 + Vector3.new(0, 0.79, 0)
	part(parent, name, Vector3.new(width, 0.58, (worldB - worldA).Magnitude), CFrame.lookAt(midpoint, Vector3.new(worldB.X, midpoint.Y, worldB.Z)), Enum.Material.Pavement, Color3.fromRGB(96, 95, 90))
end

local function worldSegment(parent: Instance, name: string, a: Vector3, b: Vector3, width: number, height: number, y: number, material: Enum.Material, color: Color3)
	local flatA = Vector3.new(a.X, y, a.Z)
	local flatB = Vector3.new(b.X, y, b.Z)
	local midpoint = (flatA + flatB) / 2
	part(parent, name, Vector3.new(width, height, (flatB - flatA).Magnitude + 0.5), CFrame.lookAt(midpoint, flatB), material, color)
end

local function pocketTheme(biomeId: string): (Enum.Material, Color3, Color3)
	if biomeId == "ForestWildlands" then
		return Enum.Material.Ground, Color3.fromRGB(73, 91, 65), Color3.fromRGB(65, 91, 57)
	elseif biomeId == "FrozenWasteland" then
		return Enum.Material.Snow, Color3.fromRGB(166, 181, 188), Color3.fromRGB(132, 174, 190)
	elseif biomeId == "NuclearCity" then
		return Enum.Material.Concrete, Color3.fromRGB(78, 77, 69), Color3.fromRGB(128, 144, 66)
	end
	return Enum.Material.Basalt, Color3.fromRGB(55, 48, 47), Color3.fromRGB(135, 68, 48)
end

local function localDecorPart(parent: Instance, name: string, size: Vector3, cf: CFrame, offset: Vector3, material: Enum.Material, color: Color3): Part
	return part(parent, name, size, cf * CFrame.new(offset + Vector3.new(0, 1, 0)), material, color, false)
end

local function buildApproachTransitionFloor(parent: Instance, cf: CFrame, biomeId: string)
	local materials: { Enum.Material }
	local colors: { Color3 }
	if biomeId == "ForestWildlands" then
		materials = { Enum.Material.CrackedLava, Enum.Material.Ground, Enum.Material.Grass }
		colors = { Color3.fromRGB(82, 82, 73), Color3.fromRGB(74, 86, 64), Color3.fromRGB(64, 91, 55) }
	elseif biomeId == "FrozenWasteland" then
		materials = { Enum.Material.Concrete, Enum.Material.Snow, Enum.Material.Ice }
		colors = { Color3.fromRGB(112, 119, 122), Color3.fromRGB(183, 196, 201), Color3.fromRGB(143, 184, 199) }
	elseif biomeId == "NuclearCity" then
		materials = { Enum.Material.Concrete, Enum.Material.DiamondPlate, Enum.Material.CorrodedMetal }
		colors = { Color3.fromRGB(81, 80, 73), Color3.fromRGB(75, 75, 68), Color3.fromRGB(68, 66, 59) }
	else
		materials = { Enum.Material.Concrete, Enum.Material.Basalt, Enum.Material.CrackedLava }
		colors = { Color3.fromRGB(72, 68, 66), Color3.fromRGB(51, 45, 45), Color3.fromRGB(45, 36, 35) }
	end
	for index = 1, 3 do
		part(
			parent,
			`ApproachTransitionFloor{index}`,
			Vector3.new(12 + index * 2, 0.14, THEMED_APPROACH_LENGTH / 3 - 0.4),
			cf * CFrame.new(0, 1.08, 12 - (index - 1) * 12),
			materials[index],
			colors[index],
			false
		)
	end
end

local function buildForestApproach(parent: Instance, cf: CFrame)
	for index, data in {
		{ -6.6, 0.08, 9, 4.5, 6 },
		{ 6.4, 0.09, 2, 5.5, 8 },
		{ -5.8, 0.08, -7, 6, 5 },
	} do
		local patch = localDecorPart(parent, `ForestMossPatch{index}`, Vector3.new(data[4], 0.12, data[5]), cf, Vector3.new(data[1], data[2], data[3]), Enum.Material.Grass, Color3.fromRGB(68, 92, 55))
		patch.Transparency = 0.08
	end
	for index, z in { 7, -5 } do
		local root = localDecorPart(parent, `ForestRoot{index}`, Vector3.new(0.65, 0.45, 6), cf, Vector3.new(if index == 1 then -6.2 else 6.4, 0.3, z), Enum.Material.Wood, Color3.fromRGB(70, 51, 34))
		root.CFrame *= CFrame.Angles(0, math.rad(if index == 1 then -16 else 18), math.rad(4))
	end
	for index, data in { { -5.5, 4, -9 }, { 5.7, -6, 12 } } do
		local road = localDecorPart(parent, `ForestBrokenRoad{index}`, Vector3.new(3.8, 0.18, 5), cf, Vector3.new(data[1], 0.12, data[2]), Enum.Material.Pavement, Color3.fromRGB(82, 82, 76))
		road.CFrame *= CFrame.Angles(0, math.rad(data[3]), math.rad(2))
	end
	for index, data in { { -9.2, 5 }, { 9.5, -7 } } do
		local trunk = localDecorPart(parent, `ForestSaplingTrunk{index}`, Vector3.new(1.1, 5.5, 1.1), cf, Vector3.new(data[1], 2.75, data[2]), Enum.Material.Wood, Color3.fromRGB(68, 50, 34))
		local crown = localDecorPart(parent, `ForestSaplingCrown{index}`, Vector3.new(4.6, 4.6, 4.6), trunk.CFrame, Vector3.new(0, 3.8, 0), Enum.Material.Grass, Color3.fromRGB(55, 84, 49))
		crown.Shape = Enum.PartType.Ball
	end
end

local function buildFrozenApproach(parent: Instance, cf: CFrame)
	for index, data in {
		{ -6.2, 9, 5, 7 },
		{ 6.5, 1, 5.5, 8 },
		{ -5.8, -8, 6, 5 },
	} do
		local frost = localDecorPart(parent, `FrozenFrostPatch{index}`, Vector3.new(data[3], 0.12, data[4]), cf, Vector3.new(data[1], 0.08, data[2]), Enum.Material.Snow, Color3.fromRGB(189, 202, 207))
		frost.Transparency = 0.12
	end
	for index, data in { { -7.2, 3, -12 }, { 7, -7, 14 } } do
		local slab = localDecorPart(parent, `FrozenIceSlab{index}`, Vector3.new(3.5, 0.35, 5.5), cf, Vector3.new(data[1], 0.22, data[2]), Enum.Material.Ice, Color3.fromRGB(147, 187, 202))
		slab.CFrame *= CFrame.Angles(0, math.rad(data[3]), 0)
	end
	for index, data in { { -9.2, 8 }, { 9.2, -6 } } do
		local post = localDecorPart(parent, `FrozenColdLampPost{index}`, Vector3.new(0.55, 5.5, 0.55), cf, Vector3.new(data[1], 2.75, data[2]), Enum.Material.Metal, Color3.fromRGB(65, 76, 84))
		local lamp = localDecorPart(parent, `FrozenColdLamp{index}`, Vector3.new(1.3, 0.55, 1.3), post.CFrame, Vector3.new(0, 3, 0), Enum.Material.Neon, Color3.fromRGB(148, 205, 224))
		local light = Instance.new("PointLight")
		light.Color = lamp.Color
		light.Brightness = 0.55
		light.Range = 11
		light.Parent = lamp
	end
end

local function buildNuclearApproach(parent: Instance, cf: CFrame)
	for index, z in { 10, 3, -4, -11 } do
		local stripe = localDecorPart(parent, `NuclearHazardStripe{index}`, Vector3.new(2.2, 0.1, 0.65), cf, Vector3.new(if index % 2 == 0 then 6.8 else -6.8, 0.08, z), Enum.Material.SmoothPlastic, Color3.fromRGB(183, 162, 40))
		stripe.CFrame *= CFrame.Angles(0, math.rad(if index % 2 == 0 then 30 else -30), 0)
	end
	for index, data in { { -8.6, 6 }, { 8.6, -6 } } do
		local pipe = localDecorPart(parent, `NuclearContainmentPipe{index}`, Vector3.new(1.1, 1.1, 8), cf, Vector3.new(data[1], 0.65, data[2]), Enum.Material.Metal, Color3.fromRGB(72, 79, 75))
		local collar = localDecorPart(parent, `NuclearPipeCollar{index}`, Vector3.new(1.5, 1.5, 0.6), pipe.CFrame, Vector3.new(0, 0, -2.2), Enum.Material.Metal, Color3.fromRGB(112, 117, 102))
		collar.CFrame *= CFrame.Angles(0, 0, math.rad(90))
	end
	for index, data in { { -6.7, -8, -11 }, { 6.5, 8, 14 } } do
		local concrete = localDecorPart(parent, `NuclearBrokenConcrete{index}`, Vector3.new(3.5, 0.65, 4.8), cf, Vector3.new(data[1], 0.35, data[2]), Enum.Material.Concrete, Color3.fromRGB(91, 90, 83))
		concrete.CFrame *= CFrame.Angles(0, math.rad(data[3]), math.rad(2))
	end
end

local function buildVolcanicApproach(parent: Instance, cf: CFrame)
	for index, data in {
		{ -6.4, 8, 5, 6 },
		{ 6.2, 1, 5, 8 },
		{ -5.8, -9, 6, 5 },
	} do
		local ash = localDecorPart(parent, `VolcanicAshPatch{index}`, Vector3.new(data[3], 0.14, data[4]), cf, Vector3.new(data[1], 0.09, data[2]), Enum.Material.Basalt, Color3.fromRGB(48, 43, 43))
		ash.Transparency = 0.05
	end
	for index, data in { { -6.5, 2, -10 }, { 6.3, -8, 13 } } do
		local fissure = localDecorPart(parent, `VolcanicFissure{index}`, Vector3.new(0.28, 0.13, 6), cf, Vector3.new(data[1], 0.13, data[2]), Enum.Material.Neon, Color3.fromRGB(184, 67, 33))
		fissure.CFrame *= CFrame.Angles(0, math.rad(data[3]), 0)
	end
	for index, data in { { -9, 7 }, { 9, -7 } } do
		local ventBase = localDecorPart(parent, `VolcanicVentBase{index}`, Vector3.new(2.2, 0.8, 2.2), cf, Vector3.new(data[1], 0.4, data[2]), Enum.Material.Basalt, Color3.fromRGB(55, 48, 47))
		local vent = localDecorPart(parent, `VolcanicHeatVent{index}`, Vector3.new(1, 2.2, 1), ventBase.CFrame, Vector3.new(0, 1.5, 0), Enum.Material.Metal, Color3.fromRGB(61, 56, 54))
		local smoke = Instance.new("ParticleEmitter")
		smoke.Color = ColorSequence.new(Color3.fromRGB(98, 91, 89))
		smoke.Lifetime = NumberRange.new(1.1, 1.7)
		smoke.Rate = 2
		smoke.Speed = NumberRange.new(1.5, 2.2)
		smoke.SpreadAngle = Vector2.new(10, 10)
		smoke.Parent = vent
	end
end

local function buildThemedApproach(parent: Instance, origin: CFrame, biomeId: string)
	local placement = HavenLayoutConfig.PortalPlacement(biomeId)
	local gatheringWorld = origin:PointToWorldSpace(HavenLayoutConfig.EXPEDITION_GATHERING_LOCAL_POSITION)
	local approachWorld = origin:PointToWorldSpace(placement.approachLocalPosition)
	local direction = (approachWorld - gatheringWorld).Unit
	local center = approachWorld - direction * (THEMED_APPROACH_LENGTH / 2)
	local cf = CFrame.lookAt(center, approachWorld)
	local decor = Instance.new("Model")
	decor.Name = `{biomeId}ApproachDecor`
	decor:SetAttribute("TransitionLength", THEMED_APPROACH_LENGTH)
	buildApproachTransitionFloor(decor, cf, biomeId)
	if biomeId == "ForestWildlands" then
		buildForestApproach(decor, cf)
	elseif biomeId == "FrozenWasteland" then
		buildFrozenApproach(decor, cf)
	elseif biomeId == "NuclearCity" then
		buildNuclearApproach(decor, cf)
	else
		buildVolcanicApproach(decor, cf)
	end
	decor.Parent = parent
end

local function buildPortalPocket(parent: Instance, origin: CFrame, biomeId: string)
	local placement = HavenLayoutConfig.PortalPlacement(biomeId)
	local world = origin:PointToWorldSpace(placement.localPosition)
	local worldApproach = origin:PointToWorldSpace(placement.approachLocalPosition)
	-- GateGenerator approaches from local +Z, so local -Z points toward its
	-- rear wall while every front faces the central gathering area.
	local cf = CFrame.lookAt(world, world + (world - worldApproach))
	local floorMaterial, floorColor, accent = pocketTheme(biomeId)
	local pocket = Instance.new("Model")
	pocket.Name = `{biomeId}Pocket`
	pocket:SetAttribute("PocketWidth", placement.pocketWidth)
	pocket:SetAttribute("PocketDepth", POCKET_DEPTH)
	pocket:SetAttribute("ArcAngleDegrees", placement.arcAngleDegrees)

	part(pocket, "PocketApron", Vector3.new(placement.pocketWidth, 0.8, POCKET_DEPTH), cf * CFrame.new(0, 0.45, POCKET_DEPTH / 2 - 3), floorMaterial, floorColor)
	for _, side in { -1, 1 } do
		part(pocket, "PortalMachinery", Vector3.new(3.5, 6, 4), cf * CFrame.new(side * (placement.pocketWidth / 2 - 2.5), 3, -5), Enum.Material.Metal, Color3.fromRGB(52, 56, 60))
	end
	part(pocket, "RestrictedRearBarrier", Vector3.new(placement.pocketWidth + 1, POCKET_WALL_HEIGHT, 1.5), cf * CFrame.new(0, POCKET_WALL_HEIGHT / 2, -12), Enum.Material.Metal, Color3.fromRGB(42, 46, 51))
	for index = -1, 1 do
		part(pocket, "RestrictedBiomeTeaser", Vector3.new(3.5 + math.abs(index), 3 + math.abs(index) * 2, 3.5), cf * CFrame.new(index * 6, 1.8, -16), if biomeId == "FrozenWasteland" then Enum.Material.Ice else floorMaterial, accent, false)
	end
	local marker = part(pocket, "LocalPocketPractical", Vector3.new(0.55, 0.55, 0.55), cf * CFrame.new(-placement.pocketWidth / 2 + 2.5, 3.5, POCKET_DEPTH - 7), Enum.Material.Neon, accent, false)
	local light = Instance.new("PointLight")
	light.Color = accent
	light.Brightness = 0.6
	light.Range = 10
	light.Parent = marker
	pocket.Parent = parent
end

local function buildDistrictSideEnclosure(parent: Instance, origin: CFrame)
	local gatewayZ = HavenLayoutConfig.EXPEDITION_GATEWAY_LOCAL_POSITION.Z
	local havenHalfWidth = HavenLayoutConfig.FORTIFICATION_HALF_WIDTH
	for _, side in { -1, 1 } do
		local points = {
			origin:PointToWorldSpace(Vector3.new(side * havenHalfWidth, 0, gatewayZ)),
			origin:PointToWorldSpace(Vector3.new(side * (havenHalfWidth + 11), 0, gatewayZ - 5)),
			origin:PointToWorldSpace(Vector3.new(side * (havenHalfWidth + 31), 0, gatewayZ - 15)),
			origin:PointToWorldSpace(Vector3.new(side * DISTRICT_SIDE_X, 0, gatewayZ - 26)),
		}
		for index = 1, #points - 1 do
			local wallA = points[index]
			local wallB = points[index + 1]
			worldSegment(parent, "FlaredSideFacade", wallA, wallB, 4.5, DISTRICT_WALL_HEIGHT + 2, wallA.Y + (DISTRICT_WALL_HEIGHT + 2) / 2, Enum.Material.Concrete, Color3.fromRGB(45, 49, 55))
			worldSegment(parent, "FlaredFacadeFoot", wallA, wallB, 9, 4, wallA.Y + 2, Enum.Material.Slate, Color3.fromRGB(54, 58, 64))
			worldSegment(parent, "FlaredFacadeCap", wallA, wallB, 5.5, 1.2, wallA.Y + DISTRICT_WALL_HEIGHT + 2.6, Enum.Material.Metal, Color3.fromRGB(37, 42, 48))
		end
		for index = 2, #points do
			part(parent, "FlaredFacadeButtress", Vector3.new(7, DISTRICT_WALL_HEIGHT + 7, 7), CFrame.new(points[index].X, points[index].Y + (DISTRICT_WALL_HEIGHT + 7) / 2, points[index].Z), Enum.Material.Metal, Color3.fromRGB(39, 43, 49))
		end

		-- Start stays welded to the flare that meets Haven's wall; the end
		-- follows the slab so the side security wall always encloses exactly
		-- as much district as there is district.
		local sideWallStart = gatewayZ - 26
		local sideWallEnd = DISTRICT_REAR_Z + 5
		local sideWallCenter = (sideWallStart + sideWallEnd) / 2
		local sideWallLength = math.abs(sideWallEnd - sideWallStart)
		part(parent, "DistrictSideSecurity", Vector3.new(3.5, DISTRICT_WALL_HEIGHT, sideWallLength), origin * CFrame.new(side * DISTRICT_SIDE_X, DISTRICT_WALL_HEIGHT / 2, sideWallCenter), Enum.Material.Metal, Color3.fromRGB(39, 43, 49))
		part(parent, "DistrictSideCap", Vector3.new(5, 1.2, sideWallLength), origin * CFrame.new(side * DISTRICT_SIDE_X, DISTRICT_WALL_HEIGHT + 0.6, sideWallCenter), Enum.Material.Metal, Color3.fromRGB(31, 36, 42))
		for z = sideWallStart - 18, sideWallEnd, -36 do
			part(parent, "DistrictSideButtress", Vector3.new(7, DISTRICT_WALL_HEIGHT + 5, 7), origin * CFrame.new(side * DISTRICT_SIDE_X, (DISTRICT_WALL_HEIGHT + 5) / 2, z), Enum.Material.Concrete, Color3.fromRGB(48, 52, 58))
		end
	end
end

local function buildCurvedDefenseWall(parent: Instance, origin: CFrame)
	local center = HavenLayoutConfig.EXPEDITION_ARC_CENTER_LOCAL_POSITION
	local minAngle = -78
	local maxAngle = 78
	local step = (maxAngle - minAngle) / ARC_WALL_SEGMENTS
	local segmentWidth = math.rad(step) * BACK_WALL_RADIUS * 1.04
	for index = 1, ARC_WALL_SEGMENTS do
		local angle = math.rad(minAngle + (index - 0.5) * step)
		local localPosition = center + Vector3.new(math.sin(angle) * BACK_WALL_RADIUS, 0, -math.cos(angle) * BACK_WALL_RADIUS)
		local worldPosition = origin:PointToWorldSpace(localPosition)
		local worldCenter = origin:PointToWorldSpace(center)
		local cf = CFrame.lookAt(worldPosition, Vector3.new(worldCenter.X, worldPosition.Y, worldCenter.Z))
		part(parent, "CurvedDefenseSegment", Vector3.new(segmentWidth, DISTRICT_WALL_HEIGHT, 4), cf * CFrame.new(0, DISTRICT_WALL_HEIGHT / 2, 0), Enum.Material.Concrete, Color3.fromRGB(45, 49, 55))
		if index % 3 == 1 then
			part(parent, "DefenseButtress", Vector3.new(4, DISTRICT_WALL_HEIGHT + 6, 7), cf * CFrame.new(0, (DISTRICT_WALL_HEIGHT + 6) / 2, 0), Enum.Material.Metal, Color3.fromRGB(39, 43, 49))
		end
	end
	for _, side in { -1, 1 } do
		local angle = math.rad(side * maxAngle)
		local localEndpoint = center + Vector3.new(math.sin(angle) * BACK_WALL_RADIUS, 0, -math.cos(angle) * BACK_WALL_RADIUS)
		local worldEndpoint = origin:PointToWorldSpace(localEndpoint)
		local worldSide = origin:PointToWorldSpace(Vector3.new(side * DISTRICT_SIDE_X, 0, localEndpoint.Z))
		worldSegment(parent, "DefenseWallReturn", worldEndpoint, worldSide, 4, DISTRICT_WALL_HEIGHT, worldEndpoint.Y + DISTRICT_WALL_HEIGHT / 2, Enum.Material.Concrete, Color3.fromRGB(45, 49, 55))
	end
end

function ExpeditionDistrictGenerator.Build(parent: Instance, origin: CFrame): Model
	GeneratorKit.CleanupPrevious(parent, "ExpeditionDistrict")
	local model = Instance.new("Model")
	model.Name = "ExpeditionDistrict"
	model:SetAttribute("DistrictWidth", DISTRICT_WIDTH)
	-- Was EXPEDITION_PORTAL_ARC_RADIUS, which has never existed on
	-- HavenLayoutConfig — the attribute silently resolved to nil and was never
	-- written. Corrected here since this is the district's own record of the
	-- radius the move above must not have changed.
	model:SetAttribute("PortalArcRadius", HavenLayoutConfig.EXPEDITION_ARC_RADIUS)
	model:SetAttribute("PortalOrder", table.concat(PORTAL_ORDER, ","))
	part(model, "DistrictFoundation", Vector3.new(DISTRICT_WIDTH, 3, DISTRICT_DEPTH), origin * CFrame.new(0, -1.5, DISTRICT_CENTER_Z), Enum.Material.Slate, Color3.fromRGB(47, 52, 59))
	part(model, "DistrictSurface", Vector3.new(DISTRICT_WIDTH - 4, 1, DISTRICT_DEPTH - 4), origin * CFrame.new(0, 0, DISTRICT_CENTER_Z), Enum.Material.Asphalt, Color3.fromRGB(66, 70, 75))
	local gathering = HavenLayoutConfig.EXPEDITION_GATHERING_LOCAL_POSITION
	-- Runs from Haven's gateway to the plaza center, so it shortens exactly as
	-- much as the district moves forward instead of leaving dead pavement.
	local causewayFromZ = HavenLayoutConfig.EXPEDITION_GATEWAY_LOCAL_POSITION.Z
	local gatheringFrontZ = gathering.Z + GATHERING_RADIUS
	local gatewayToGathering = math.abs(gathering.Z - causewayFromZ)
	local causewayLength = gatewayToGathering - GATHERING_RADIUS
	if causewayLength > 1 then
		part(
			model,
			"GatewayCauseway",
			Vector3.new(24, 0.58, causewayLength),
			origin * CFrame.new(0, 0.79, (causewayFromZ + gatheringFrontZ) / 2),
			Enum.Material.Pavement,
			Color3.fromRGB(99, 98, 92)
		)
	end
	local gatheringDisc = part(model, "CentralExpeditionGathering", Vector3.new(0.16, GATHERING_DIAMETER, GATHERING_DIAMETER), origin * CFrame.new(gathering + Vector3.new(0, 0.92, 0)) * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.DiamondPlate, Color3.fromRGB(76, 80, 83))
	gatheringDisc.Shape = Enum.PartType.Cylinder
	for _, biomeId in PORTAL_ORDER do
		local placement = HavenLayoutConfig.PortalPlacement(biomeId)
		local connectorDirection = (placement.approachLocalPosition - gathering).Unit
		local connectorStart = gathering + connectorDirection * CONNECTOR_START_RADIUS
		pathBetween(model, origin, `{biomeId}Connector`, connectorStart, placement.approachLocalPosition, 14)
		buildThemedApproach(model, origin, biomeId)
		buildPortalPocket(model, origin, biomeId)
	end
	buildDistrictSideEnclosure(model, origin)
	buildCurvedDefenseWall(model, origin)
	model.Parent = parent
	return model
end

return ExpeditionDistrictGenerator
