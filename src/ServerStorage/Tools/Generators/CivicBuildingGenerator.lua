--!strict
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HavenFacilityConfig = require(ReplicatedStorage.Shared.Config.HavenFacilityConfig)
local HavenFacilityEnvelopeConfig = require(ReplicatedStorage.Shared.Config.HavenFacilityEnvelopeConfig)
local HavenLayoutConfig = require(ReplicatedStorage.Shared.Config.HavenLayoutConfig)
local GeneratorKit = require(script.Parent.GeneratorKit)
local SurvivorFigureGenerator = require(script.Parent.SurvivorFigureGenerator)
local WorldFacilityLabelGenerator = require(script.Parent.WorldFacilityLabelGenerator)

local CivicBuildingGenerator = {}
local MODULE_WIDTH = HavenFacilityEnvelopeConfig.Width
local MODULE_DEPTH = HavenFacilityEnvelopeConfig.Depth
local SHELL_HEIGHT = HavenFacilityEnvelopeConfig.WallHeight
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
local function localCFrame(origin: CFrame, facility: HavenFacilityConfig.FacilityDefinition, position: Vector3): CFrame
	local pos = position
	local target = position + origin:VectorToWorldSpace(facility.frontDirection)
	return CFrame.lookAt(pos, Vector3.new(target.X, pos.Y, target.Z))
end
local function anchor(model: Model, cf: CFrame, facility: HavenFacilityConfig.FacilityDefinition, accent: Color3)
	local a = part(model, "FacilityAnchor", Vector3.new(4, 5, 1), cf, Enum.Material.ForceField, accent, false)
	a.Transparency = 1
	a:SetAttribute("FacilityId", facility.id)
	CollectionService:AddTag(a, "HavenFacility")
end
local function practical(parent: Instance, cf: CFrame, color: Color3)
	local fixture = part(parent, "PracticalLight", Vector3.new(0.6, 0.6, 0.6), cf, Enum.Material.Neon, color, false)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 0.75
	light.Range = 13
	light.Parent = fixture
end
local function shell(
	model: Model,
	cf: CFrame,
	accent: Color3,
	title: string,
	subtitle: string
)
	model:SetAttribute("EnvelopeWidth", MODULE_WIDTH)
	model:SetAttribute("EnvelopeHeight", HavenFacilityEnvelopeConfig.OverallHeight)
	model:SetAttribute("EnvelopeDepth", MODULE_DEPTH)
	model:SetAttribute("FrontOpeningHeight", HavenFacilityEnvelopeConfig.FrontOpeningHeight)
	part(
		model,
		"FacilityFloor",
		Vector3.new(MODULE_WIDTH, 1, MODULE_DEPTH),
		cf * CFrame.new(0, 0.5, 0),
		Enum.Material.DiamondPlate,
		Color3.fromRGB(55, 59, 64)
	)
	part(
		model,
		"RearWall",
		Vector3.new(MODULE_WIDTH, SHELL_HEIGHT, 1),
		cf * CFrame.new(0, SHELL_HEIGHT / 2, MODULE_DEPTH / 2),
		Enum.Material.Metal,
		Color3.fromRGB(46, 50, 56)
	)
	for _, x in {
		-MODULE_WIDTH / 2 + HavenFacilityEnvelopeConfig.StructuralPostWidth / 2,
		MODULE_WIDTH / 2 - HavenFacilityEnvelopeConfig.StructuralPostWidth / 2,
	} do
		part(
			model,
			"SideFrame",
			Vector3.new(HavenFacilityEnvelopeConfig.StructuralPostWidth, SHELL_HEIGHT, MODULE_DEPTH),
			cf * CFrame.new(x, SHELL_HEIGHT / 2, 0),
			Enum.Material.Metal,
			Color3.fromRGB(42, 46, 52)
		)
	end
	part(
		model,
		"Canopy",
		Vector3.new(
			MODULE_WIDTH + HavenFacilityEnvelopeConfig.RoofOverhang * 2,
			HavenFacilityEnvelopeConfig.RoofThickness,
			MODULE_DEPTH + HavenFacilityEnvelopeConfig.RoofOverhang * 2
		),
		cf * CFrame.new(0, SHELL_HEIGHT, 0),
		Enum.Material.Metal,
		Color3.fromRGB(61, 63, 66)
	)
	part(
		model,
		"FrontFacadeHeader",
		Vector3.new(MODULE_WIDTH, HavenFacilityEnvelopeConfig.FrontHeaderHeight, 1),
		cf * CFrame.new(
			0,
			HavenFacilityEnvelopeConfig.FrontOpeningHeight + HavenFacilityEnvelopeConfig.FrontHeaderHeight / 2,
			-MODULE_DEPTH / 2
		),
		Enum.Material.Metal,
		Color3.fromRGB(42, 46, 52)
	)
	local sign = WorldFacilityLabelGenerator.Build(
		model,
		cf * CFrame.new(0, HavenFacilityEnvelopeConfig.SignCenterHeight, -MODULE_DEPTH / 2 - 0.55),
		{ Title = title, Subtitle = subtitle, AccentColor = accent, Width = HavenFacilityEnvelopeConfig.SignWidth }
	)
	sign:SetAttribute("FacilityId", model.Name)
	sign:SetAttribute("ConfiguredCenterHeight", HavenFacilityEnvelopeConfig.SignCenterHeight)
end
local function buildMarket(model: Model, cf: CFrame, accent: Color3)
	shell(model, cf, accent, "Survivor Market", "Merchant • Field Trade")
	part(
		model,
		"BroadReclaimedAwning",
		Vector3.new(22, 0.45, 5),
		cf * CFrame.new(0, 7.5, -6),
		Enum.Material.Fabric,
		Color3.fromRGB(104, 78, 56),
		false
	)
	for i = -2, 2 do
		part(
			model,
			"HangingFieldGoods",
			Vector3.new(0.8, 1.8, 0.6),
			cf * CFrame.new(i * 2.4, 6.4, -5.8),
			Enum.Material.Fabric,
			Color3.fromRGB(88 + i * 4, 80, 63),
			false
		)
	end
	part(
		model,
		"MerchantCounter",
		Vector3.new(16, 3, 2),
		cf * CFrame.new(0, 2, -3),
		Enum.Material.WoodPlanks,
		Color3.fromRGB(91, 65, 43)
	)
	for _, x in { -7, 0, 7 } do
		part(
			model,
			"OrganizedRearShelf",
			Vector3.new(4, 5, 1.5),
			cf * CFrame.new(x, 3, 5.2),
			Enum.Material.WoodPlanks,
			Color3.fromRGB(74, 57, 42)
		)
	end
	for _, x in { -7, 7 } do
		part(
			model,
			"CargoCrate",
			Vector3.new(2.5, 2.2, 2.5),
			cf * CFrame.new(x, 1.6, 1.5),
			Enum.Material.WoodPlanks,
			Color3.fromRGB(100, 76, 51)
		)
	end
	part(
		model,
		"TradeScale",
		Vector3.new(1.4, 0.3, 1.2),
		cf * CFrame.new(4, 3.65, -3),
		Enum.Material.Metal,
		Color3.fromRGB(120, 122, 115),
		false
	)
	SurvivorFigureGenerator.Build(model, cf * CFrame.new(-3, 1, 0.3), "Merchant")
	practical(model, cf * CFrame.new(0, 7.8, -1), Color3.fromRGB(240, 181, 112))
end
local function buildUpgrade(model: Model, cf: CFrame, accent: Color3)
	shell(model, cf, accent, "Upgrade Station", "Engineer • Repairs")
	part(
		model,
		"WorkshopGantry",
		Vector3.new(18, 1, 1),
		cf * CFrame.new(0, 10.5, 1),
		Enum.Material.Metal,
		Color3.fromRGB(70, 75, 79)
	)
	part(
		model,
		"WorkshopPipe",
		Vector3.new(0.7, 7, 0.7),
		cf * CFrame.new(-8.5, 4, 6.8),
		Enum.Material.Metal,
		Color3.fromRGB(96, 86, 72),
		false
	)
	part(
		model,
		"PartsStorage",
		Vector3.new(4, 5, 3),
		cf * CFrame.new(7, 3, 5.5),
		Enum.Material.Metal,
		Color3.fromRGB(55, 60, 64)
	)
	part(
		model,
		"Workbench",
		Vector3.new(15, 3, 3),
		cf * CFrame.new(0, 2, 4.8),
		Enum.Material.Metal,
		Color3.fromRGB(64, 69, 72)
	)
	for i = -3, 3 do
		part(
			model,
			"ToolWallTool",
			Vector3.new(0.3, 2, 0.3),
			cf * CFrame.new(i * 1.5, 5, 7.8),
			Enum.Material.Metal,
			Color3.fromRGB(190, 150, 76),
			false
		)
	end
	part(
		model,
		"Forge",
		Vector3.new(4, 4, 4),
		cf * CFrame.new(-7, 2.5, 0),
		Enum.Material.Metal,
		Color3.fromRGB(51, 52, 55)
	)
	part(
		model,
		"RepairArm",
		Vector3.new(0.8, 7, 0.8),
		cf * CFrame.new(7, 4, 1),
		Enum.Material.Metal,
		Color3.fromRGB(96, 102, 105)
	)
	part(
		model,
		"GaugeBank",
		Vector3.new(4, 2.4, 0.5),
		cf * CFrame.new(7, 5, 7.4),
		Enum.Material.Glass,
		Color3.fromRGB(93, 174, 188),
		false
	)
	SurvivorFigureGenerator.Build(model, cf * CFrame.new(2, 1, -1), "Engineer")
	practical(model, cf * CFrame.new(-6.8, 5, 0), Color3.fromRGB(235, 132, 67))
end
local function buildCapsule(model: Model, cf: CFrame, accent: Color3)
	shell(model, cf, accent, "Capsule Laboratory", "Scientist • Analysis")
	part(
		model,
		"LaboratoryCrown",
		Vector3.new(12, 1.2, 8),
		cf * CFrame.new(1, 12.4, 2.5),
		Enum.Material.Metal,
		Color3.fromRGB(54, 66, 71)
	)
	for _, x in { -7, 7 } do
		part(
			model,
			"VentilationStack",
			Vector3.new(1.2, 10, 1.2),
			cf * CFrame.new(x, 6, 6),
			Enum.Material.Metal,
			Color3.fromRGB(77, 84, 88),
			false
		)
		part(
			model,
			"SampleRack",
			Vector3.new(3, 4, 1.5),
			cf * CFrame.new(x, 2.5, 3.5),
			Enum.Material.Metal,
			Color3.fromRGB(50, 59, 63)
		)
	end
	part(
		model,
		"CapsuleFeedPipe",
		Vector3.new(8, 0.6, 0.6),
		cf * CFrame.new(1, 10.5, 2.5),
		Enum.Material.Metal,
		Color3.fromRGB(91, 101, 104),
		false
	)
	part(
		model,
		"AnalysisCounter",
		Vector3.new(9, 3, 2),
		cf * CFrame.new(0, 2, -3),
		Enum.Material.Metal,
		Color3.fromRGB(54, 65, 69)
	)
	local capsule = part(
		model,
		"ContainmentCapsule",
		Vector3.new(6, 11, 6),
		cf * CFrame.new(1, 6, 2.5),
		Enum.Material.Glass,
		Color3.fromRGB(97, 181, 195),
		false
	)
	capsule.Transparency = 0.45
	for _, x in { -4, 6 } do
		part(
			model,
			"PressureTank",
			Vector3.new(2.5, 7, 2.5),
			cf * CFrame.new(x, 4, 5.5),
			Enum.Material.Metal,
			Color3.fromRGB(72, 79, 83)
		)
	end
	part(
		model,
		"AnalysisScreen",
		Vector3.new(4, 2.8, 0.4),
		cf * CFrame.new(-6, 4.2, 7.5),
		Enum.Material.Glass,
		Color3.fromRGB(55, 132, 151),
		false
	)
	for _, x in { -8, 8 } do
		part(
			model,
			"RestrictedRail",
			Vector3.new(0.6, 4, 12),
			cf * CFrame.new(x, 2, 2),
			Enum.Material.Metal,
			Color3.fromRGB(45, 49, 54)
		)
	end
	SurvivorFigureGenerator.Build(model, cf * CFrame.new(-3.5, 1, -2), "Scientist")
	practical(model, cf * CFrame.new(1, 9, 2.5), Color3.fromRGB(111, 204, 220))
end
local function buildCosmetic(model: Model, cf: CFrame, accent: Color3)
	shell(model, cf, accent, "Cosmetic Shop", "Outfitter • Fieldwear")
	part(
		model,
		"LayeredStoreAwning",
		Vector3.new(20, 0.5, 4),
		cf * CFrame.new(0, 7.4, -5.8),
		Enum.Material.Fabric,
		Color3.fromRGB(70, 111, 106),
		false
	)
	part(
		model,
		"DisplayHelmet",
		Vector3.new(1.5, 1.2, 1.4),
		cf * CFrame.new(-5.5, 5.6, 3.5),
		Enum.Material.SmoothPlastic,
		Color3.fromRGB(73, 96, 99),
		false
	)
	part(
		model,
		"DisplayBackpack",
		Vector3.new(1.8, 2.4, 1),
		cf * CFrame.new(5.5, 4.7, 3.8),
		Enum.Material.Fabric,
		Color3.fromRGB(108, 72, 69),
		false
	)
	part(
		model,
		"StoreCounter",
		Vector3.new(13, 3, 2),
		cf * CFrame.new(0, 2, -2.5),
		Enum.Material.WoodPlanks,
		Color3.fromRGB(72, 63, 57)
	)
	for _, x in { -5.5, 5.5 } do
		part(
			model,
			"DisplayMannequin",
			Vector3.new(1.4, 4.5, 0.9),
			cf * CFrame.new(x, 2.8, 3.5),
			Enum.Material.SmoothPlastic,
			Color3.fromRGB(112, 118, 121),
			false
		)
	end
	part(
		model,
		"OutfitRack",
		Vector3.new(6, 4, 1),
		cf * CFrame.new(0, 3, 5.5),
		Enum.Material.Metal,
		Color3.fromRGB(57, 67, 70)
	)
	part(
		model,
		"FieldMirror",
		Vector3.new(3, 5, 0.3),
		cf * CFrame.new(7.8, 3.3, 4.2),
		Enum.Material.Glass,
		Color3.fromRGB(160, 184, 190),
		false
	)
	SurvivorFigureGenerator.Build(model, cf * CFrame.new(-2, 1, 0.3), "Outfitter")
	practical(model, cf * CFrame.new(0, 7.8, 0), Color3.fromRGB(105, 194, 184))
end
local function buildRewards(model: Model, cf: CFrame, accent: Color3)
	shell(model, cf, accent, "Daily Rewards", "7-Day Supply Claim")
	part(
		model,
		"RewardBannerMast",
		Vector3.new(0.6, 12, 0.6),
		cf * CFrame.new(7, 6, -4),
		Enum.Material.Metal,
		Color3.fromRGB(64, 67, 74)
	)
	part(
		model,
		"SevenDayBanner",
		Vector3.new(4, 6, 0.2),
		cf * CFrame.new(5, 8.5, -4),
		Enum.Material.Fabric,
		Color3.fromRGB(111, 82, 54),
		false
	)
	part(
		model,
		"RewardShelf",
		Vector3.new(7, 4, 1.5),
		cf * CFrame.new(-3, 2.5, 4.7),
		Enum.Material.WoodPlanks,
		Color3.fromRGB(78, 62, 48)
	)
	part(
		model,
		"ClaimCounter",
		Vector3.new(10, 3, 2),
		cf * CFrame.new(0, 2, -2.2),
		Enum.Material.Metal,
		Color3.fromRGB(62, 65, 72)
	)
	part(
		model,
		"SupplyChest",
		Vector3.new(3, 2, 2),
		cf * CFrame.new(4.5, 1.5, 3.5),
		Enum.Material.WoodPlanks,
		Color3.fromRGB(112, 82, 46)
	)
	for i = 1, 7 do
		part(
			model,
			"DayPip",
			Vector3.new(0.75, 0.75, 0.25),
			cf * CFrame.new(-4.5 + i * 1.1, 6.2, 5.55),
			Enum.Material.Neon,
			if i == 1 then accent else Color3.fromRGB(78, 80, 84),
			false
		)
	end
	SurvivorFigureGenerator.Build(model, cf * CFrame.new(-2.5, 1, 0.3), "RewardOfficer")
	practical(model, cf * CFrame.new(0, 7.7, 0), Color3.fromRGB(239, 192, 100))
end

function CivicBuildingGenerator.Build(
	parent: Instance,
	origin: CFrame,
	facility: HavenFacilityConfig.FacilityDefinition,
	position: Vector3
): Model
	GeneratorKit.CleanupPrevious(parent, facility.id)
	local model = Instance.new("Model")
	model.Name = facility.id
	local cf = localCFrame(origin, facility, position)
	local accent = HavenLayoutConfig.GetDistrict(facility.district).accentColor
	if facility.kind == "Market" then
		buildMarket(model, cf, accent)
	elseif facility.kind == "UpgradeStation" then
		buildUpgrade(model, cf, accent)
	elseif facility.kind == "CapsuleLab" then
		buildCapsule(model, cf, accent)
	elseif facility.kind == "CosmeticShop" then
		buildCosmetic(model, cf, accent)
	elseif facility.kind == "DailyRewards" then
		buildRewards(model, cf, accent)
	else
		error(`Unsupported physical facility {facility.kind}`)
	end
	anchor(model, cf * CFrame.new(0, 3, -8), facility, accent)
	GeneratorKit.Finalize(model, "FacilityAnchor")
	model.Parent = parent
	return model
end
return CivicBuildingGenerator
