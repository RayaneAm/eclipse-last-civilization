--!strict
-- The Personal Base camp: a believable ridge-pole tent with a lived-in camp
-- around it, and the settlement's travel terminal tucked beside the entrance.
--
-- WHY THIS SHAPE. The previous tent was two flat 10x16 fabric slabs crossed at
-- +/-34 degrees with nothing closing the ends, so it read as intersecting
-- triangles floating over the ground rather than a shelter. Everything here is
-- derived from one A-frame profile instead:
--
--        ridge (RIDGE_HEIGHT)
--            /\
--           /  \        slope length + pitch are COMPUTED from the profile, so
--          /    \       the two tarp panels always meet exactly at the ridge
--         /      \      and always land exactly on the eaves. No eyeballed
--   eave +--------+ eave    angles, no gaps, no overshoot.
--
-- The rear is closed by a stepped stack of scavenged planks rather than a
-- clean wedge: it reads as survivor-built, and it sidesteps the fragile
-- WedgePart orientation maths that makes generated gables look wrong.
--
-- GAMEPLAY CONTRACT (unchanged, and load-bearing — see ValidateWorldComposition):
--   * Model named "PersonalBaseTent" with attribute IsSurvivalTent = true
--   * a part tagged "BaseGatePortal" carrying a ProximityPrompt
--   * a "ReturnLanding_PersonalBase" landing pad in front of the tent

local CollectionService = game:GetService("CollectionService")
local GeneratorKit = require(script.Parent.GeneratorKit)
local WorldFacilityLabelGenerator = require(script.Parent.WorldFacilityLabelGenerator)

local SurvivorTentGenerator = {}

-- The single A-frame profile every panel is derived from. Local -Z is the open
-- front (the side the player approaches from); +Z is the closed rear.
local HALF_WIDTH = 5.4
local EAVE_HEIGHT = 3.7
local RIDGE_HEIGHT = 8.2
local DEPTH = 15
local TARP_THICKNESS = 0.3
local TARP_OVERHANG = 1.1 -- how far the tarp projects past the poles at each end

local RISE = RIDGE_HEIGHT - EAVE_HEIGHT
local SLOPE_LENGTH = math.sqrt(HALF_WIDTH * HALF_WIDTH + RISE * RISE)
local SLOPE_ANGLE = math.atan2(RISE, HALF_WIDTH)

local CANVAS = Color3.fromRGB(96, 100, 78)
local CANVAS_SHADED = Color3.fromRGB(80, 85, 66)
local TIMBER = Color3.fromRGB(74, 57, 41)
local TIMBER_DARK = Color3.fromRGB(58, 45, 33)
local ROPE = Color3.fromRGB(139, 124, 96)

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

-- A thin box stretched between two local points. Used for guy ropes and
-- diagonal bracing, where an axis-aligned box would obviously be wrong.
local function strut(parent: Instance, name: string, cf: CFrame, from: Vector3, to: Vector3, thickness: number, material: Enum.Material, color: Color3)
	local worldFrom = cf:PointToWorldSpace(from)
	local worldTo = cf:PointToWorldSpace(to)
	local length = (worldTo - worldFrom).Magnitude
	part(parent, name, Vector3.new(thickness, thickness, length), CFrame.lookAt((worldFrom + worldTo) / 2, worldTo), material, color, false)
end

local function buildFrame(model: Instance, cf: CFrame)
	-- Four corner poles carry the eaves; two taller gable posts carry the ridge.
	for _, x in { -HALF_WIDTH, HALF_WIDTH } do
		for _, z in { -DEPTH / 2 + 1, DEPTH / 2 - 1 } do
			part(model, "TentCornerPole", Vector3.new(0.55, EAVE_HEIGHT, 0.55), cf * CFrame.new(x, EAVE_HEIGHT / 2, z), Enum.Material.Wood, TIMBER)
		end
	end
	for _, z in { -DEPTH / 2 + 1, DEPTH / 2 - 1 } do
		part(model, "TentGablePost", Vector3.new(0.6, RIDGE_HEIGHT, 0.6), cf * CFrame.new(0, RIDGE_HEIGHT / 2, z), Enum.Material.Wood, TIMBER_DARK)
	end
	part(model, "TentRidgePole", Vector3.new(0.6, 0.6, DEPTH + 2), cf * CFrame.new(0, RIDGE_HEIGHT, 0), Enum.Material.Wood, TIMBER_DARK)

	-- Eave purlins the tarp visibly rests on, so the fabric has something to be
	-- supported BY instead of hanging in space.
	for _, x in { -HALF_WIDTH, HALF_WIDTH } do
		part(model, "TentEavePurlin", Vector3.new(0.4, 0.4, DEPTH), cf * CFrame.new(x, EAVE_HEIGHT, 0), Enum.Material.Wood, TIMBER)
	end
end

local function buildTarp(model: Instance, cf: CFrame)
	-- Both panels share the computed slope, so they meet on the ridge line
	-- exactly. `side` flips the pitch; nothing here is hand-tuned.
	for _, side in { -1, 1 } do
		local panel = part(
			model,
			if side < 0 then "TentTarpLeft" else "TentTarpRight",
			Vector3.new(SLOPE_LENGTH, TARP_THICKNESS, DEPTH + TARP_OVERHANG * 2),
			cf
				* CFrame.new(side * HALF_WIDTH / 2, (EAVE_HEIGHT + RIDGE_HEIGHT) / 2, 0)
				* CFrame.Angles(0, 0, math.rad(-side * math.deg(SLOPE_ANGLE))),
			Enum.Material.Fabric,
			if side < 0 then CANVAS else CANVAS_SHADED,
			false
		)
		panel.CanTouch = false
		panel.CanQuery = false

		-- Three lashing bands per side break up the flat fabric plane and sell
		-- "canvas tied down over a frame".
		for index, z in { -DEPTH / 3, 0, DEPTH / 3 } do
			part(
				model,
				`TentLashingBand{index}`,
				Vector3.new(SLOPE_LENGTH + 0.2, 0.12, 0.35),
				cf
					* CFrame.new(side * HALF_WIDTH / 2, (EAVE_HEIGHT + RIDGE_HEIGHT) / 2 + 0.24, z)
					* CFrame.Angles(0, 0, math.rad(-side * math.deg(SLOPE_ANGLE))),
				Enum.Material.Fabric,
				ROPE,
				false
			)
		end
	end
	part(model, "TentRidgeCap", Vector3.new(1.5, 0.3, DEPTH + TARP_OVERHANG * 2), cf * CFrame.new(0, RIDGE_HEIGHT + 0.28, 0), Enum.Material.Fabric, CANVAS_SHADED, false)
end

-- Closes the rear with a stack of salvaged planks whose widths follow the same
-- A-frame profile. Reads as boarded-up scrap, and cannot go geometrically wrong
-- the way a rotated WedgePart gable can.
local function buildRearGable(model: Instance, cf: CFrame)
	local plankCount = 5
	local plankHeight = RISE / plankCount
	local plankTones = {
		Color3.fromRGB(96, 72, 49),
		Color3.fromRGB(84, 63, 43),
		Color3.fromRGB(103, 79, 54),
		Color3.fromRGB(78, 60, 42),
		Color3.fromRGB(91, 68, 46),
	}
	for index = 1, plankCount do
		local y = EAVE_HEIGHT + (index - 0.5) * plankHeight
		local halfWidth = HALF_WIDTH * (RIDGE_HEIGHT - y) / RISE
		part(
			model,
			`TentGablePlank{index}`,
			Vector3.new(math.max(halfWidth * 2, 0.8), plankHeight + 0.05, 0.3),
			cf * CFrame.new(0, y, DEPTH / 2 - 0.9),
			Enum.Material.WoodPlanks,
			plankTones[index],
			false
		)
	end
	-- Solid canvas wall below the plank gable, so the rear is genuinely closed.
	part(model, "TentRearWall", Vector3.new(HALF_WIDTH * 2, EAVE_HEIGHT, 0.25), cf * CFrame.new(0, EAVE_HEIGHT / 2, DEPTH / 2 - 0.9), Enum.Material.Fabric, CANVAS_SHADED, false)
end

-- Rolled-back entrance flaps: the tent is open, and it visibly reads as open
-- ON PURPOSE rather than unfinished.
local function buildEntrance(model: Instance, cf: CFrame)
	local frontZ = -DEPTH / 2 - TARP_OVERHANG + 0.4
	for _, side in { -1, 1 } do
		local flap = part(
			model,
			"TentDoorFlap",
			Vector3.new(1.7, EAVE_HEIGHT + 1.6, 0.28),
			cf * CFrame.new(side * (HALF_WIDTH - 0.9), (EAVE_HEIGHT + 1.6) / 2, frontZ) * CFrame.Angles(0, math.rad(side * 18), 0),
			Enum.Material.Fabric,
			CANVAS,
			false
		)
		flap.CanTouch = false
		local roll = part(
			model,
			"TentRolledFlap",
			Vector3.new(0.9, 0.9, 2.4),
			cf * CFrame.new(side * (HALF_WIDTH - 1.4), EAVE_HEIGHT + 1.2, frontZ) * CFrame.Angles(0, 0, math.rad(90)),
			Enum.Material.Fabric,
			CANVAS_SHADED,
			false
		)
		roll.Shape = Enum.PartType.Cylinder
	end
end

local function buildGuyRopes(model: Instance, cf: CFrame)
	for _, side in { -1, 1 } do
		for _, z in { -DEPTH / 2 + 1.5, DEPTH / 2 - 1.5 } do
			local anchorPoint = Vector3.new(side * (HALF_WIDTH + 3.3), 0.35, z + side * 0.6)
			strut(model, "TentGuyRope", cf, Vector3.new(side * HALF_WIDTH, EAVE_HEIGHT + 0.2, z), anchorPoint, 0.12, Enum.Material.Fabric, ROPE)
			part(model, "TentGroundPeg", Vector3.new(0.3, 0.9, 0.3), cf * CFrame.new(anchorPoint.X, 0.45, anchorPoint.Z) * CFrame.Angles(math.rad(side * 12), 0, 0), Enum.Material.Wood, TIMBER_DARK, false)
		end
	end
end

local function buildCampInterior(model: Instance, cf: CFrame)
	-- Plank sleeping platform, so the bedroll is not lying in the dirt.
	for index = -2, 2 do
		part(model, "TentFloorPlank", Vector3.new(1.5, 0.25, 7.4), cf * CFrame.new(index * 1.62, 0.75, 3.1), Enum.Material.WoodPlanks, Color3.fromRGB(88, 66, 45), false)
	end
	part(model, "TentBedroll", Vector3.new(3.1, 0.7, 6.4), cf * CFrame.new(-1.6, 1.22, 3.1), Enum.Material.Fabric, Color3.fromRGB(104, 96, 74), false)
	part(model, "TentBlanketFold", Vector3.new(3.2, 0.4, 2), cf * CFrame.new(-1.6, 1.75, 1.2), Enum.Material.Fabric, Color3.fromRGB(122, 79, 62), false)
	part(model, "TentPillowRoll", Vector3.new(2.9, 0.8, 0.9), cf * CFrame.new(-1.6, 1.85, 5.9), Enum.Material.Fabric, Color3.fromRGB(132, 124, 100), false)

	part(model, "StorageCrate", Vector3.new(2.6, 2.1, 2.4), cf * CFrame.new(3.4, 1.05, 4.6), Enum.Material.WoodPlanks, Color3.fromRGB(97, 72, 48), false)
	part(model, "StorageCrateLid", Vector3.new(2.8, 0.3, 2.6), cf * CFrame.new(3.4, 2.25, 4.6), Enum.Material.WoodPlanks, Color3.fromRGB(80, 60, 41), false)
	part(model, "SupplySack", Vector3.new(1.7, 1.5, 1.5), cf * CFrame.new(3.6, 0.75, 2.1), Enum.Material.Fabric, Color3.fromRGB(120, 108, 82), false)
	part(model, "SurvivalBackpack", Vector3.new(1.7, 2.2, 1.3), cf * CFrame.new(3.5, 3.4, 5.4), Enum.Material.Fabric, Color3.fromRGB(88, 72, 54), false)
	part(model, "UtilityBox", Vector3.new(2.2, 1.2, 1.8), cf * CFrame.new(-3.8, 0.6, 0.4), Enum.Material.Metal, Color3.fromRGB(70, 74, 72), false)
	part(model, "WaterCanister", Vector3.new(1.1, 1.6, 1.1), cf * CFrame.new(-3.9, 0.8, -1.8), Enum.Material.Metal, Color3.fromRGB(96, 106, 98), false)

	-- Lantern hung from the ridge, which is also the tent's warm key light.
	strut(model, "LanternHook", cf, Vector3.new(1.4, RIDGE_HEIGHT - 0.4, -2.2), Vector3.new(1.4, RIDGE_HEIGHT - 2.1, -2.2), 0.1, Enum.Material.Metal, Color3.fromRGB(70, 70, 74))
	local lantern = part(model, "FieldLantern", Vector3.new(0.95, 1.3, 0.95), cf * CFrame.new(1.4, RIDGE_HEIGHT - 2.7, -2.2), Enum.Material.Glass, Color3.fromRGB(255, 206, 138), false)
	local lanternLight = Instance.new("PointLight")
	lanternLight.Color = Color3.fromRGB(255, 196, 126)
	lanternLight.Brightness = 1.1
	lanternLight.Range = 20
	lanternLight.Shadows = true
	lanternLight.Parent = lantern
	part(model, "LanternCap", Vector3.new(1.1, 0.3, 1.1), cf * CFrame.new(1.4, RIDGE_HEIGHT - 1.95, -2.2), Enum.Material.Metal, Color3.fromRGB(78, 66, 50), false)
end

-- The travel terminal is the one piece of technology in the camp, so it is
-- dressed as scavenged kit on a plank bench rather than a clean kiosk.
local function buildTravelTerminal(model: Instance, cf: CFrame): Part
	part(model, "TerminalBench", Vector3.new(3.6, 1.6, 2.2), cf * CFrame.new(HALF_WIDTH - 1.1, 0.8, -4.6), Enum.Material.WoodPlanks, Color3.fromRGB(84, 63, 43))
	local terminal = part(model, "BaseTravelTerminal", Vector3.new(2.3, 2.6, 1.7), cf * CFrame.new(HALF_WIDTH - 1.1, 2.9, -4.6), Enum.Material.CorrodedMetal, Color3.fromRGB(66, 74, 76))
	part(model, "TerminalAntenna", Vector3.new(0.16, 3.4, 0.16), cf * CFrame.new(HALF_WIDTH - 0.2, 5.4, -4.6) * CFrame.Angles(math.rad(9), 0, math.rad(7)), Enum.Material.Metal, Color3.fromRGB(88, 92, 96), false)
	local status = part(model, "BaseTerminalStatus", Vector3.new(1.2, 0.5, 0.16), cf * CFrame.new(HALF_WIDTH - 1.1, 3.5, -5.5), Enum.Material.Neon, Color3.fromRGB(112, 214, 150), false)
	status.CastShadow = false
	local statusLight = Instance.new("PointLight")
	statusLight.Color = Color3.fromRGB(126, 226, 162)
	statusLight.Brightness = 0.7
	statusLight.Range = 11
	statusLight.Parent = status

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BaseTentPrompt"
	prompt.ObjectText = "Personal Base"
	prompt.ActionText = "Enter"
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = terminal
	CollectionService:AddTag(terminal, "BaseGatePortal")
	return terminal
end

-- Everything outside the tent walls: the trodden ground it sits on, a small
-- cook fire, firewood and a drying line. This is what turns one shelter into
-- a camp.
local function buildCampSurroundings(model: Instance, cf: CFrame)
	-- Cook fire, offset from the entrance so it lights the approach.
	local fireCenter = cf * CFrame.new(-HALF_WIDTH - 3.4, 0, -3.2)
	for index = 1, 8 do
		local angle = (index / 8) * math.pi * 2
		part(model, `CampFireStone{index}`, Vector3.new(0.85, 0.6, 0.85), fireCenter * CFrame.new(math.cos(angle) * 1.85, 0.9, math.sin(angle) * 1.85) * CFrame.Angles(0, angle, 0), Enum.Material.Rock, Color3.fromRGB(104, 100, 94), false)
	end
	for index, rotation in { 20, -35, 75 } do
		part(model, `CampFireLog{index}`, Vector3.new(0.55, 0.55, 2.6), fireCenter * CFrame.new(0, 1.05, 0) * CFrame.Angles(0, math.rad(rotation), math.rad(11)), Enum.Material.Wood, TIMBER_DARK, false)
	end
	local embers = part(model, "CampFireEmbers", Vector3.new(1.5, 0.5, 1.5), fireCenter * CFrame.new(0, 0.95, 0), Enum.Material.Neon, Color3.fromRGB(232, 126, 52), false)
	embers.CastShadow = false
	local fireLight = Instance.new("PointLight")
	fireLight.Color = Color3.fromRGB(255, 158, 84)
	fireLight.Brightness = 1.4
	fireLight.Range = 24
	fireLight.Shadows = true
	fireLight.Parent = embers
	local flame = Instance.new("ParticleEmitter")
	flame.Name = "CampFireFlame"
	flame.Color = ColorSequence.new(Color3.fromRGB(255, 176, 82), Color3.fromRGB(196, 82, 34))
	flame.Size = NumberSequence.new(1.1, 0)
	flame.Lifetime = NumberRange.new(0.5, 0.9)
	flame.Rate = 14
	flame.Speed = NumberRange.new(2.4, 3.4)
	flame.SpreadAngle = Vector2.new(9, 9)
	flame.LightEmission = 0.75
	flame.Parent = embers

	-- Tripod + pot over the fire.
	for _, offset in { Vector3.new(-1.5, 0, -1.5), Vector3.new(1.5, 0, -1.5), Vector3.new(0, 0, 1.9) } do
		strut(model, "CookTripodLeg", fireCenter, offset + Vector3.new(0, 0.2, 0), Vector3.new(0, 3.5, 0), 0.16, Enum.Material.Metal, Color3.fromRGB(72, 70, 68))
	end
	part(model, "CookPot", Vector3.new(1.5, 1.2, 1.5), fireCenter * CFrame.new(0, 2.35, 0), Enum.Material.Metal, Color3.fromRGB(58, 58, 60), false)

	-- Firewood stack and a chopping block.
	for row = 0, 2 do
		for index = 0, 2 - row do
			part(model, "FirewoodLog", Vector3.new(0.5, 0.5, 2.4), cf * CFrame.new(-HALF_WIDTH - 3.2 + index * 0.56 + row * 0.28, 0.45 + row * 0.52, 2.6) * CFrame.Angles(0, math.rad(4), 0), Enum.Material.Wood, Color3.fromRGB(92, 70, 48), false)
		end
	end
	part(model, "ChoppingBlock", Vector3.new(1.6, 1.4, 1.6), cf * CFrame.new(-HALF_WIDTH - 5.4, 0.7, 0.6), Enum.Material.Wood, Color3.fromRGB(78, 58, 40), false)
	part(model, "SplittingAxe", Vector3.new(0.18, 1.9, 0.18), cf * CFrame.new(-HALF_WIDTH - 5.4, 2.2, 0.6) * CFrame.Angles(math.rad(24), 0, math.rad(13)), Enum.Material.Wood, Color3.fromRGB(96, 76, 52), false)

	-- Drying line between the tent and a leaning post.
	part(model, "DryingLinePost", Vector3.new(0.4, 5.4, 0.4), cf * CFrame.new(HALF_WIDTH + 4.6, 2.7, 2.4) * CFrame.Angles(0, 0, math.rad(-5)), Enum.Material.Wood, TIMBER, false)
	strut(model, "DryingLine", cf, Vector3.new(HALF_WIDTH, EAVE_HEIGHT + 1.3, 2.4), Vector3.new(HALF_WIDTH + 4.5, 5.1, 2.4), 0.08, Enum.Material.Fabric, ROPE)
	for index, data in { { 1.4, 1.5, 1.9 }, { 2.6, 1.1, 1.5 }, { 3.7, 1.3, 1.7 } } do
		part(model, `DryingCloth{index}`, Vector3.new(data[3], data[2], 0.14), cf * CFrame.new(HALF_WIDTH + data[1], 4.95 - data[2] / 2, 2.4), Enum.Material.Fabric, if index == 2 then Color3.fromRGB(126, 108, 86) else Color3.fromRGB(104, 112, 92), false)
	end
end

function SurvivorTentGenerator.Build(parent: Instance, tentCFrame: CFrame): Model
	GeneratorKit.CleanupPrevious(parent, "PersonalBaseTent")
	-- The old local dirt/scuff plates are gone. Raise the authored shelter just
	-- enough to rest cleanly on Haven's single top surface instead of sinking
	-- its interior floor into it.
	tentCFrame += Vector3.new(0, 0.32, 0)
	local model = Instance.new("Model")
	model.Name = "PersonalBaseTent"
	model:SetAttribute("IsSurvivalTent", true)

	buildCampSurroundings(model, tentCFrame)
	buildFrame(model, tentCFrame)
	buildTarp(model, tentCFrame)
	buildRearGable(model, tentCFrame)
	buildEntrance(model, tentCFrame)
	buildGuyRopes(model, tentCFrame)
	buildCampInterior(model, tentCFrame)
	buildTravelTerminal(model, tentCFrame)

	-- Floating world label rather than a sign board bolted to the tent: the
	-- camp silhouette stays clean and readable from the arrival lane.
	WorldFacilityLabelGenerator.Build(model, tentCFrame * CFrame.new(0, RIDGE_HEIGHT + 2.4, -DEPTH / 2 - 1.4), {
		Title = "Personal Base",
		Subtitle = "Your Settlement",
		AccentColor = Color3.fromRGB(126, 208, 172),
		Width = 12,
		MaxDistance = 95,
	})

	GeneratorKit.NewPart({
		Name = "ReturnLanding_PersonalBase",
		Size = Vector3.new(6, 0.5, 6),
		CFrame = tentCFrame * CFrame.new(0, 1.15, -DEPTH / 2 - 2.5),
		Material = Enum.Material.Pavement,
		Color = Color3.fromRGB(78, 100, 90),
		Transparency = 0.25,
		CanCollide = false,
		Parent = model,
	})

	GeneratorKit.Finalize(model, "BaseTravelTerminal")
	model.Parent = parent
	return model
end

return SurvivorTentGenerator
