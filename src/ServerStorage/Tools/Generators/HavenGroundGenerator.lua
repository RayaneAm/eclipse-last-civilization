--!strict
-- Non-surface dressing for Haven's final ground composition. The actual base
-- tiles and navigation surfaces are owned by HavenPlatformGenerator. This
-- module deliberately creates no broad dirt/concrete overlays: the previous
-- random patch field, old-road slabs and path chips overlapped coplanarly and
-- produced severe z-fighting during movement.

local GeneratorKit = require(script.Parent.GeneratorKit)

local HavenGroundGenerator = {}

HavenGroundGenerator.SURFACE_TOP = 1
HavenGroundGenerator.PATH_TOP = 1.14

HavenGroundGenerator.Palette = {
	Foundation = Color3.fromRGB(48, 41, 34),
	Earth = Color3.fromRGB(78, 66, 51),
	EarthDark = Color3.fromRGB(64, 54, 42),
	Dust = Color3.fromRGB(120, 106, 82),
	Sand = Color3.fromRGB(139, 123, 94),
	Gravel = Color3.fromRGB(96, 92, 86),
	Pavement = Color3.fromRGB(112, 106, 96),
	PavementWorn = Color3.fromRGB(94, 89, 81),
	Plank = Color3.fromRGB(96, 72, 49),
	PlankDark = Color3.fromRGB(78, 59, 41),
	Moss = Color3.fromRGB(86, 100, 68),
}

local P = HavenGroundGenerator.Palette
local PLANK_THICKNESS = 0.16
local PLANK_TOP = HavenGroundGenerator.PATH_TOP + PLANK_THICKNESS

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

local function plank(
	parent: Instance,
	name: string,
	origin: CFrame,
	x: number,
	z: number,
	sizeX: number,
	sizeZ: number,
	color: Color3
)
	local board = part(
		parent,
		name,
		Vector3.new(sizeX, PLANK_THICKNESS, sizeZ),
		origin * CFrame.new(x, PLANK_TOP - PLANK_THICKNESS / 2, z),
		Enum.Material.WoodPlanks,
		color,
		false
	)
	board:SetAttribute("StableGroundDetail", true)
end

-- Short reclaimed boardwalks mark service entrances. Boards have real gaps,
-- no random rotation and therefore no same-height intersection.
local function buildBoardwalk(
	model: Instance,
	origin: CFrame,
	name: string,
	centerX: number,
	centerZ: number,
	length: number
)
	local boardCount = math.floor(length / 1.35)
	local step = length / boardCount
	for index = 1, boardCount do
		local x = centerX - length / 2 + (index - 0.5) * step
		plank(model, `{name}Board{index}`, origin, x, centerZ, 1.1, 8.5, if index % 4 == 0 then P.PlankDark else P.Plank)
	end
	for _, zOffset in { -4.55, 4.55 } do
		plank(model, `{name}RetainingBeam`, origin, centerX, centerZ + zOffset, length + 0.8, 0.55, P.PlankDark)
	end
end

local function buildBoardwalks(model: Instance, origin: CFrame)
	buildBoardwalk(model, origin, "MarketBoardwalk", -33.5, 52, 12)
	buildBoardwalk(model, origin, "CosmeticBoardwalk", -33.5, 26, 12)
	buildBoardwalk(model, origin, "LaboratoryBoardwalk", -33.5, 0, 12)
	buildBoardwalk(model, origin, "UpgradeBoardwalk", 33.5, 52, 12)
	buildBoardwalk(model, origin, "RewardsBoardwalk", 33.5, 25, 12)
end

local function buildGroundClutter(model: Instance, origin: CFrame)
	local props = {
		{ "SupplyPallet", -21, 69, 4.4, 0.5, 3.6, Enum.Material.WoodPlanks, P.Plank, 16 },
		{ "SupplyPallet", 22, 11, 4.4, 0.5, 3.6, Enum.Material.WoodPlanks, P.PlankDark, -24 },
		{ "RustBarrel", -20, 37, 2, 2.9, 2, Enum.Material.CorrodedMetal, Color3.fromRGB(102, 84, 62), 0 },
		{ "RustBarrel", 21, 69, 2, 2.9, 2, Enum.Material.CorrodedMetal, Color3.fromRGB(94, 80, 60), 0 },
		{ "ScrapCrate", 20, -5, 2.8, 2.3, 2.6, Enum.Material.WoodPlanks, P.Plank, 12 },
		{ "ScrapCrate", -22, 10, 2.6, 2.1, 2.4, Enum.Material.WoodPlanks, P.PlankDark, -18 },
		{ "BoundaryRock", -52, 74, 3.4, 1.6, 2.8, Enum.Material.Rock, Color3.fromRGB(76, 73, 66), 11 },
		{ "BoundaryRock", 53, 91, 2.8, 1.4, 3.3, Enum.Material.Rock, Color3.fromRGB(70, 69, 64), -17 },
		{ "SalvageBundle", -18, 19, 3.8, 1.2, 2.2, Enum.Material.CorrodedMetal, Color3.fromRGB(80, 73, 62), 8 },
	}
	for index, prop in props do
		part(
			model,
			`{prop[1]}{index}`,
			Vector3.new(prop[4] :: number, prop[5] :: number, prop[6] :: number),
			origin * CFrame.new(prop[2] :: number, HavenGroundGenerator.SURFACE_TOP + (prop[5] :: number) / 2, prop[3] :: number)
				* CFrame.Angles(0, math.rad(prop[9] :: number), 0),
			prop[7] :: Enum.Material,
			prop[8] :: Color3,
			false
		)
	end

	local rng = GeneratorKit.Seeded(80826)
	for index = 1, 24 do
		local side = if index % 2 == 0 then 1 else -1
		part(
			model,
			`WallTuft{index}`,
			Vector3.new(rng:NextNumber(1.6, 3), rng:NextNumber(0.5, 1), rng:NextNumber(1.4, 2.8)),
			origin * CFrame.new(side * rng:NextNumber(52, 57), HavenGroundGenerator.SURFACE_TOP + 0.3, rng:NextNumber(68, 112)),
			Enum.Material.LeafyGrass,
			P.Moss,
			false
		)
	end
end

local function cable(parent: Instance, name: string, a: Vector3, b: Vector3)
	local midpoint = (a + b) / 2
	part(
		parent,
		name,
		Vector3.new(0.1, 0.1, (b - a).Magnitude),
		CFrame.lookAt(midpoint, b),
		Enum.Material.Fabric,
		Color3.fromRGB(38, 34, 30),
		false
	)
end

local function buildStringLights(model: Instance, origin: CFrame)
	-- Keep the north end of the central route open. The former z=8 span put
	-- its east timber post directly across the player-height sightline to the
	-- first Leaderboard panel.
	for spanIndex, z in { 68, 52, 38, 24 } do
		local width = 26
		for _, side in { -1, 1 } do
			part(
				model,
				`StringLightPost{spanIndex}`,
				Vector3.new(0.55, 13, 0.55),
				origin * CFrame.new(side * width / 2, HavenGroundGenerator.SURFACE_TOP + 6.5, z),
				Enum.Material.Wood,
				P.PlankDark
			)
		end
		local cableLeft = origin:PointToWorldSpace(Vector3.new(-width / 2, 11.6, z))
		local cableMiddle = origin:PointToWorldSpace(Vector3.new(0, 10.7, z))
		local cableRight = origin:PointToWorldSpace(Vector3.new(width / 2, 11.6, z))
		cable(model, `StringLightCable{spanIndex}A`, cableLeft, cableMiddle)
		cable(model, `StringLightCable{spanIndex}B`, cableMiddle, cableRight)
		for index = 1, 6 do
			local x = -width / 2 + index * (width / 7)
			local bulb = part(
				model,
				`StringLightBulb{spanIndex}_{index}`,
				Vector3.new(0.45, 0.6, 0.45),
				origin * CFrame.new(x, HavenGroundGenerator.SURFACE_TOP + 10.8 - (if index == 1 or index == 6 then 0.2 else 0.9), z),
				Enum.Material.Neon,
				Color3.fromRGB(255, 214, 156),
				false
			)
			bulb.CastShadow = false
			if index % 2 == 1 then
				local light = Instance.new("PointLight")
				light.Color = Color3.fromRGB(255, 206, 148)
				light.Brightness = 0.75
				light.Range = 20
				light.Parent = bulb
			end
		end
	end
end

function HavenGroundGenerator.Build(parent: Instance, origin: CFrame): Model
	GeneratorKit.CleanupPrevious(parent, "SettlementGround")
	local model = Instance.new("Model")
	model.Name = "SettlementGround"
	model:SetAttribute("CreatesBroadFloorOverlays", false)
	buildBoardwalks(model, origin)
	buildGroundClutter(model, origin)
	buildStringLights(model, origin)
	model.Parent = parent
	return model
end

return HavenGroundGenerator
