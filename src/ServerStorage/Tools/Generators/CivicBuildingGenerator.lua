--!strict
-- Phase 3A: replaced the old "one shared skeleton, N decorations" pattern
-- (a Concrete plinth + Metal box + colored glass front + canopy, identical
-- for every facility, with a small themed prop cluster stuck on in front)
-- with a bespoke, silhouette-first structure per facility kind — the same
-- approach GuidanceGenerator's Quest Stage and LeaderboardHallGenerator's
-- ranking wall already used successfully (neither of them is "a box"). Each
-- structure below is sized to fit inside its facility's already-verified
-- clearance budget from the Phase 1 correction pass, so no facility moves.
--
-- QuestNPC/Leaderboard/EventPavilion+SeasonEvent are not handled here — see
-- GuidanceGenerator.luau and LeaderboardHallGenerator.luau. GamepassShowcase
-- and StarterPack are UI-first as of Phase 3B (see ShopController) and have
-- no world structure at all anymore.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HavenFacilityConfig = require(ReplicatedStorage.Shared.Config.HavenFacilityConfig)
local HavenLayoutConfig = require(ReplicatedStorage.Shared.Config.HavenLayoutConfig)
local GeneratorKit = require(script.Parent.GeneratorKit)
local SurvivorFigureGenerator = require(script.Parent.SurvivorFigureGenerator)

local CivicBuildingGenerator = {}

local function buildFacilityAnchor(model: Model, anchorCFrame: CFrame, facility: HavenFacilityConfig.FacilityDefinition, accentColor: Color3)
	local anchor = GeneratorKit.NewPart({
		Name = "FacilityAnchor",
		Size = Vector3.new(4, 5, 1),
		CFrame = anchorCFrame,
		Material = Enum.Material.ForceField,
		Color = accentColor,
		Transparency = 1,
		CanCollide = false,
		Parent = model,
	})
	anchor:SetAttribute("FacilityId", facility.id)
	CollectionService:AddTag(anchor, "HavenFacility")
	return anchor
end

-- A modest sign attached directly to the structure — tight MaxDistance so
-- signs stay private to whoever's actually approaching, per the "no floating
-- white text cloud" rule. The building should read fine with this hidden.
local function buildSignBoard(parent: Instance, signCFrame: CFrame, text: string, accentColor: Color3, width: number, height: number, maxDistance: number)
	local signPart = GeneratorKit.NewPart({
		Name = "Nameplate",
		Size = Vector3.new(width, height, 0.2),
		CFrame = signCFrame,
		Material = Enum.Material.Neon,
		Color = accentColor,
		Transparency = 0.15,
		CanCollide = false,
		Parent = parent,
	})

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "NameplateLabel"
	billboard.Size = UDim2.fromOffset(160, 26)
	billboard.MaxDistance = maxDistance
	billboard.LightInfluence = 0
	billboard.Parent = signPart

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 16
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = string.upper(text)
	label.Parent = billboard

	return signPart
end

-- SURVIVOR MARKET: an open-front trading post -- 4 posts, an angled awning,
-- a waist-height counter spanning the whole open front, rear shelving, a
-- Merchant standing behind the counter. No walls at all; the shape itself
-- reads as "market."
-- Phase 3B: enlarged (15x9 -> 20x12, posts 6.5 -> 8 tall, clearly taller
-- than the player) -- still well inside the facility's ~18-radius clearance
-- budget (bounding radius now ~13.4).
local MARKET_WIDTH = 20
local MARKET_DEPTH = 12
local MARKET_POST_HEIGHT = 8

local function buildMarket(model: Model, buildingCFrame: CFrame, facility: HavenFacilityConfig.FacilityDefinition, accentColor: Color3)
	local halfWidth = MARKET_WIDTH / 2

	GeneratorKit.NewPart({
		Name = "MarketFloor",
		Size = Vector3.new(MARKET_WIDTH + 1, 0.4, MARKET_DEPTH + 1),
		CFrame = buildingCFrame * CFrame.new(0, 0.2, 0),
		Material = Enum.Material.WoodPlanks,
		Color = Color3.fromRGB(90, 68, 48),
		Parent = model,
	})

	for _, xSign in { -1, 1 } do
		for _, zSign in { -1, 1 } do
			GeneratorKit.NewPart({
				Name = `Post_{xSign}_{zSign}`,
				Size = Vector3.new(0.6, MARKET_POST_HEIGHT, 0.6),
				CFrame = buildingCFrame * CFrame.new(xSign * (halfWidth - 0.5), MARKET_POST_HEIGHT / 2 + 0.4, zSign * (MARKET_DEPTH / 2 - 0.5)),
				Material = Enum.Material.Wood,
				Color = Color3.fromRGB(74, 56, 40),
				Parent = model,
			})
		end
	end

	-- Angled awning roof, sloping down toward the open front (-Z, toward
	-- the plaza).
	local awning = GeneratorKit.NewPart({
		Name = "Awning",
		Size = Vector3.new(MARKET_WIDTH + 1.5, 0.3, MARKET_DEPTH + 1),
		CFrame = buildingCFrame * CFrame.new(0, MARKET_POST_HEIGHT + 0.6, 0) * CFrame.Angles(math.rad(-10), 0, 0),
		Material = Enum.Material.Fabric,
		Color = accentColor,
		CanCollide = false,
		Parent = model,
	})
	CollectionService:AddTag(awning, "AmbientSway")

	local awningLight = Instance.new("PointLight")
	awningLight.Color = Color3.fromRGB(255, 220, 170)
	awningLight.Brightness = 1.8
	awningLight.Range = 18
	awningLight.Parent = awning
	CollectionService:AddTag(awningLight, "AmbientFlicker")

	-- Waist-height counter spanning the open front -- the bar a player
	-- trades across, not a door.
	local counter = GeneratorKit.NewPart({
		Name = "Counter",
		Size = Vector3.new(MARKET_WIDTH - 1, 2.1, 1.3),
		CFrame = buildingCFrame * CFrame.new(0, 1.05, -(MARKET_DEPTH / 2 - 0.7)),
		Material = Enum.Material.WoodPlanks,
		Color = Color3.fromRGB(96, 74, 52),
		Parent = model,
	})
	GeneratorKit.NewPart({
		Name = "CounterTop",
		Size = Vector3.new(MARKET_WIDTH - 0.8, 0.2, 1.6),
		CFrame = counter.CFrame * CFrame.new(0, 1.15, 0),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(70, 68, 66),
		CanCollide = false,
		Parent = model,
	})

	-- Rear shelving unit -- the back wall the market never has.
	local shelfCFrame = buildingCFrame * CFrame.new(0, 0, MARKET_DEPTH / 2 - 0.6)
	for shelfIndex = 1, 3 do
		GeneratorKit.NewPart({
			Name = `Shelf{shelfIndex}`,
			Size = Vector3.new(MARKET_WIDTH - 2, 0.15, 1),
			CFrame = shelfCFrame * CFrame.new(0, 1.2 + shelfIndex * 1.3, 0),
			Material = Enum.Material.WoodPlanks,
			Color = Color3.fromRGB(80, 60, 44),
			CanCollide = false,
			Parent = model,
		})
	end

	-- Goods sacks + a slow-spinning display ring either side of the counter.
	for i = 1, 2 do
		local side = if i == 1 then -1 else 1
		local goodsCFrame = counter.CFrame * CFrame.new(side * (MARKET_WIDTH / 2 - 2), 1.4, 0)

		GeneratorKit.NewPart({
			Name = `GoodsSack{i}`,
			Size = Vector3.new(1.1, 1, 1),
			CFrame = goodsCFrame * CFrame.Angles(0, 0, math.rad(90 + side * 8)),
			Material = Enum.Material.Fabric,
			Color = Color3.fromRGB(150, 120, 80),
			Shape = Enum.PartType.Cylinder,
			Parent = model,
		})

		local ring = GeneratorKit.NewPart({
			Name = `DisplayRing{i}`,
			Size = Vector3.new(0.12, 1.3, 1.3),
			CFrame = shelfCFrame * CFrame.new(side * (MARKET_WIDTH / 2 - 2), 2.4, 0.2) * CFrame.Angles(0, 0, math.rad(90)),
			Material = Enum.Material.Neon,
			Color = accentColor,
			Shape = Enum.PartType.Cylinder,
			CanCollide = false,
			Parent = model,
		})
		ring:SetAttribute("Speed", 25)
		CollectionService:AddTag(ring, "SlowSpin")
	end

	-- Survivor Merchant, standing behind the counter (toward the shelves,
	-- facing the plaza/customers) -- the brief is explicit this should read
	-- as a real trading post, not just props.
	SurvivorFigureGenerator.Build(model, buildingCFrame * CFrame.new(0, 0, 0.6), {
		Apron = true,
		AccentColor = accentColor,
	})

	buildSignBoard(model, buildingCFrame * CFrame.new(0, MARKET_POST_HEIGHT + 1.7, -(MARKET_DEPTH / 2 + 0.1)), facility.name, accentColor, 8.5, 1.4, 60)
	buildFacilityAnchor(model, buildingCFrame * CFrame.new(0, 3, -(MARKET_DEPTH / 2 + 2)), facility, accentColor)
end

-- UPGRADE STATION: an open workshop bay -- lean-to roof, waist-height side
-- rails instead of walls, a central bench, a forge/coil, a tool rack.
-- Phase 3B: enlarged (13x11 -> 17x14, posts 6 -> 7.5 tall) -- still inside
-- the facility's ~15.5-radius budget (bounding radius now ~12.3).
local UPGRADE_WIDTH = 17
local UPGRADE_DEPTH = 14
local UPGRADE_POST_HEIGHT = 7.5

local function buildUpgradeStation(model: Model, buildingCFrame: CFrame, facility: HavenFacilityConfig.FacilityDefinition, accentColor: Color3)
	GeneratorKit.NewPart({
		Name = "BayFloor",
		Size = Vector3.new(UPGRADE_WIDTH + 1, 0.4, UPGRADE_DEPTH + 1),
		CFrame = buildingCFrame * CFrame.new(0, 0.2, 0),
		Material = Enum.Material.DiamondPlate,
		Color = Color3.fromRGB(58, 58, 62),
		Parent = model,
	})

	for _, side in { -1, 1 } do
		GeneratorKit.NewPart({
			Name = if side < 0 then "SideRailLeft" else "SideRailRight",
			Size = Vector3.new(0.5, 1.3, UPGRADE_DEPTH),
			CFrame = buildingCFrame * CFrame.new(side * (UPGRADE_WIDTH / 2), 1.05, 0),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(50, 50, 54),
			Parent = model,
		})

		GeneratorKit.NewPart({
			Name = if side < 0 then "RoofPostLeft" else "RoofPostRight",
			Size = Vector3.new(0.5, UPGRADE_POST_HEIGHT, 0.5),
			CFrame = buildingCFrame * CFrame.new(side * (UPGRADE_WIDTH / 2 - 0.6), UPGRADE_POST_HEIGHT / 2 + 0.4, UPGRADE_DEPTH / 2 - 0.6),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(50, 50, 54),
			Parent = model,
		})
	end

	-- Lean-to roof, sloping toward the open front.
	GeneratorKit.NewPart({
		Name = "BayRoof",
		Size = Vector3.new(UPGRADE_WIDTH + 1, 0.3, UPGRADE_DEPTH * 0.75),
		CFrame = buildingCFrame * CFrame.new(0, UPGRADE_POST_HEIGHT + 0.6, UPGRADE_DEPTH * 0.12) * CFrame.Angles(math.rad(8), 0, 0),
		Material = Enum.Material.CorrodedMetal,
		Color = Color3.fromRGB(52, 52, 56),
		CanCollide = false,
		Parent = model,
	})

	-- Central bench/pedestal -- the "gear gets improved here" focal point.
	local benchCFrame = buildingCFrame
	GeneratorKit.NewPart({
		Name = "ConsolePedestal",
		Size = Vector3.new(1.8, 2.6, 1.2),
		CFrame = benchCFrame * CFrame.new(0, 1.7, 0),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(55, 55, 60),
		Parent = model,
	})

	local screen = GeneratorKit.NewPart({
		Name = "ConsoleScreen",
		Size = Vector3.new(1.5, 1.1, 0.15),
		CFrame = benchCFrame * CFrame.new(0, 3.1, 0) * CFrame.Angles(math.rad(-25), 0, 0),
		Material = Enum.Material.Neon,
		Color = accentColor,
		Transparency = 0.2,
		CanCollide = false,
		Parent = model,
	})
	local screenLight = Instance.new("PointLight")
	screenLight.Color = accentColor
	screenLight.Brightness = 1.6
	screenLight.Range = 12
	screenLight.Parent = screen
	CollectionService:AddTag(screenLight, "AmbientFlicker")

	-- Forge / power coil to one side, cables running to the bench.
	local forgeCFrame = buildingCFrame * CFrame.new(-3.6, 0, 2.5)
	local coil = GeneratorKit.NewPart({
		Name = "ForgeCoil",
		Size = Vector3.new(1.6, 2.2, 1.6),
		CFrame = forgeCFrame * CFrame.new(0, 1.1, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Glass,
		Color = accentColor,
		Transparency = 0.35,
		Shape = Enum.PartType.Cylinder,
		CanCollide = false,
		Parent = model,
	})
	local coilLight = Instance.new("PointLight")
	coilLight.Color = accentColor
	coilLight.Brightness = 2.2
	coilLight.Range = 16
	coilLight.Parent = coil
	CollectionService:AddTag(coilLight, "AmbientFlicker")

	for i = 0, 2 do
		local pipeStart = forgeCFrame.Position + Vector3.new(0, 0.6 + i * 0.3, 0)
		local pipeEnd = benchCFrame.Position + Vector3.new(-0.7, 1 + i * 0.3, 0)
		local pipeMid = pipeStart:Lerp(pipeEnd, 0.5)
		GeneratorKit.NewPart({
			Name = `Pipe{i}`,
			Size = Vector3.new(0.2, 0.2, (pipeEnd - pipeStart).Magnitude),
			CFrame = CFrame.new(pipeMid, pipeEnd),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(70, 70, 74),
			CanCollide = false,
			Parent = model,
		})
	end

	-- Tool rack on the opposite side.
	local rackCFrame = buildingCFrame * CFrame.new(3.8, 0, 2.5)
	GeneratorKit.NewPart({
		Name = "ToolRackFrame",
		Size = Vector3.new(0.2, 3, 2),
		CFrame = rackCFrame * CFrame.new(0, 1.9, 0),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(46, 46, 50),
		CanCollide = false,
		Parent = model,
	})
	local toolRng = GeneratorKit.Seeded(31)
	for toolIndex = 1, 4 do
		GeneratorKit.NewPart({
			Name = `Tool{toolIndex}`,
			Size = Vector3.new(0.12, toolRng:NextNumber(0.9, 1.4), 0.12),
			CFrame = rackCFrame * CFrame.new(0.15, 2.6 - toolIndex * 0.6, (toolIndex - 2.5) * 0.4) * CFrame.Angles(0, 0, toolRng:NextNumber(-0.2, 0.2)),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(90, 90, 94),
			CanCollide = false,
			Parent = model,
		})
	end

	buildSignBoard(model, buildingCFrame * CFrame.new(0, UPGRADE_POST_HEIGHT + 1.6, -(UPGRADE_DEPTH / 2 - 0.6)), facility.name, accentColor, 8, 1.3, 60)
	buildFacilityAnchor(model, buildingCFrame * CFrame.new(0, 3, -(UPGRADE_DEPTH / 2 + 2)), facility, accentColor)
end

-- DAILY REWARDS: a compact round reward dais -- no walls. A central claim
-- pod under a small canopy, a 7-pip streak ring wrapped around the platform
-- edge, one chest.
-- Phase 3B: enlarged (radius 6 -> 7.5, pod 4.5 -> 5.5) and given a canopy
-- frame over the pod -- the flat platform+capsule alone read too much like
-- "just a glowing circle" per the brief; the canopy gives it real vertical
-- silhouette as a claim station. Still inside the ~18-radius budget.
local REWARDS_PLATFORM_RADIUS = 7.5
local REWARDS_POD_HEIGHT = 5.5
local REWARDS_CANOPY_HEIGHT = 7.5
local REWARDS_STREAK_PIPS = 7
local REWARDS_CLAIMED_TODAY = 3 -- placeholder -- no backend, purely a greybox value

local function buildDailyRewards(model: Model, buildingCFrame: CFrame, facility: HavenFacilityConfig.FacilityDefinition, accentColor: Color3)
	GeneratorKit.NewPart({
		Name = "RewardPlatform",
		Size = Vector3.new(0.6, REWARDS_PLATFORM_RADIUS * 2, REWARDS_PLATFORM_RADIUS * 2),
		CFrame = buildingCFrame * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Basalt,
		Color = Color3.fromRGB(52, 44, 30),
		Shape = Enum.PartType.Cylinder,
		Parent = model,
	})
	GeneratorKit.NewPart({
		Name = "RewardPlatformRim",
		Size = Vector3.new(0.15, REWARDS_PLATFORM_RADIUS * 2 + 0.4, REWARDS_PLATFORM_RADIUS * 2 + 0.4),
		CFrame = buildingCFrame * CFrame.new(0, 0.62, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Neon,
		Color = accentColor,
		Shape = Enum.PartType.Cylinder,
		CanCollide = false,
		Parent = model,
	})

	-- 7-pip daily streak ring wrapped around the platform's edge -- the
	-- clearest "reward station" signal, on the platform itself now instead
	-- of hidden on a console face.
	for i = 1, REWARDS_STREAK_PIPS do
		local claimed = i <= REWARDS_CLAIMED_TODAY
		local angle = math.rad((i - 1) / REWARDS_STREAK_PIPS * 360)
		local pipPos = Vector3.new(math.cos(angle), 0, math.sin(angle)) * (REWARDS_PLATFORM_RADIUS - 0.7)
		local pip = GeneratorKit.NewPart({
			Name = `StreakPip{i}`,
			Size = Vector3.new(0.5, 0.5, 0.5),
			CFrame = buildingCFrame * CFrame.new(pipPos.X, 0.9, pipPos.Z),
			Material = Enum.Material.Neon,
			Color = if claimed then accentColor else Color3.fromRGB(60, 58, 56),
			Shape = Enum.PartType.Ball,
			CanCollide = false,
			Parent = model,
		})
		if claimed then
			CollectionService:AddTag(pip, "AmbientFlicker")
		end
	end

	-- Central claim pod -- a vertical capsule, the reward shrine's focal point.
	GeneratorKit.NewPart({
		Name = "PodBase",
		Size = Vector3.new(1.6, 0.5, 1.6),
		CFrame = buildingCFrame * CFrame.new(0, 0.85, 0),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(60, 58, 56),
		Parent = model,
	})

	local pod = GeneratorKit.NewPart({
		Name = "ClaimPod",
		Size = Vector3.new(1.4, REWARDS_POD_HEIGHT, 1.4),
		CFrame = buildingCFrame * CFrame.new(0, 0.85 + REWARDS_POD_HEIGHT / 2, 0),
		Material = Enum.Material.Glass,
		Color = accentColor,
		Transparency = 0.3,
		Shape = Enum.PartType.Cylinder,
		CanCollide = false,
		Parent = model,
	})
	pod:SetAttribute("Speed", 8)
	CollectionService:AddTag(pod, "SlowSpin")

	local podCore = GeneratorKit.NewPart({
		Name = "PodCore",
		Size = Vector3.new(0.6, 0.6, 0.6),
		CFrame = buildingCFrame * CFrame.new(0, 0.85 + REWARDS_POD_HEIGHT / 2, 0),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 210, 120),
		Shape = Enum.PartType.Ball,
		CanCollide = false,
		Parent = model,
	})
	local podLight = Instance.new("PointLight")
	podLight.Color = Color3.fromRGB(255, 210, 140)
	podLight.Brightness = 2.4
	podLight.Range = 16
	podLight.Parent = podCore
	CollectionService:AddTag(podLight, "AmbientFlicker")

	GeneratorKit.NewPart({
		Name = "PodCap",
		Size = Vector3.new(1.7, 0.3, 1.7),
		CFrame = buildingCFrame * CFrame.new(0, 0.85 + REWARDS_POD_HEIGHT, 0),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(70, 60, 40),
		CanCollide = false,
		Parent = model,
	})

	-- Canopy frame over the pod -- 2 posts + a small peaked roof, the
	-- vertical silhouette that turns "a platform and a capsule" into a real
	-- claim station.
	for _, side in { -1, 1 } do
		GeneratorKit.NewPart({
			Name = if side < 0 then "CanopyPostLeft" else "CanopyPostRight",
			Size = Vector3.new(0.4, REWARDS_CANOPY_HEIGHT, 0.4),
			CFrame = buildingCFrame * CFrame.new(side * 2.4, REWARDS_CANOPY_HEIGHT / 2, 0),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(50, 48, 46),
			CanCollide = false,
			Parent = model,
		})
	end
	GeneratorKit.NewPart({
		Name = "CanopyRoof",
		Size = Vector3.new(5.6, 0.3, 3.2),
		CFrame = buildingCFrame * CFrame.new(0, REWARDS_CANOPY_HEIGHT + 0.2, 0),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(46, 44, 40),
		CanCollide = false,
		Parent = model,
	})
	GeneratorKit.NewPart({
		Name = "CanopyTrim",
		Size = Vector3.new(5.6, 0.12, 0.12),
		CFrame = buildingCFrame * CFrame.new(0, REWARDS_CANOPY_HEIGHT + 0.03, 1.62),
		Material = Enum.Material.Neon,
		Color = accentColor,
		CanCollide = false,
		Parent = model,
	})

	-- One supporting reward chest to the side -- secondary prop only.
	local chestCFrame = buildingCFrame * CFrame.new(-3.6, 0, 2)
	GeneratorKit.NewPart({
		Name = "RewardChest",
		Size = Vector3.new(1.4, 1, 1),
		CFrame = chestCFrame * CFrame.new(0, 0.85, 0),
		Material = Enum.Material.WoodPlanks,
		Color = Color3.fromRGB(90, 68, 46),
		Parent = model,
	})
	GeneratorKit.NewPart({
		Name = "RewardChestTrim",
		Size = Vector3.new(1.5, 0.15, 1.1),
		CFrame = chestCFrame * CFrame.new(0, 1.38, 0),
		Material = Enum.Material.Metal,
		Color = accentColor,
		CanCollide = false,
		Parent = model,
	})

	buildSignBoard(model, buildingCFrame * CFrame.new(0, REWARDS_POD_HEIGHT + 3, 0), facility.name, accentColor, 7.5, 1.3, 55)
	buildFacilityAnchor(model, buildingCFrame * CFrame.new(0, 2.5, -(REWARDS_PLATFORM_RADIUS + 1.5)), facility, accentColor)
end

-- CAPSULE LABORATORY: a round machine platform -- the glass capsule
-- chamber IS the structure, not a small prop in front of an unrelated box.
-- Phase 3B: enlarged moderately (radius 6.5 -> 8.5) with the housing/struts
-- scaled up proportionally -- still inside the ~18-radius budget.
local CAPSULE_PLATFORM_RADIUS = 8.5
local CAPSULE_HOUSING_HEIGHT = 3

local function buildCapsuleLab(model: Model, buildingCFrame: CFrame, facility: HavenFacilityConfig.FacilityDefinition, accentColor: Color3)
	GeneratorKit.NewPart({
		Name = "LabPlatform",
		Size = Vector3.new(0.6, CAPSULE_PLATFORM_RADIUS * 2, CAPSULE_PLATFORM_RADIUS * 2),
		CFrame = buildingCFrame * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Basalt,
		Color = Color3.fromRGB(40, 38, 46),
		Shape = Enum.PartType.Cylinder,
		Parent = model,
	})
	GeneratorKit.NewPart({
		Name = "LabPlatformRim",
		Size = Vector3.new(0.15, CAPSULE_PLATFORM_RADIUS * 2 + 0.4, CAPSULE_PLATFORM_RADIUS * 2 + 0.4),
		CFrame = buildingCFrame * CFrame.new(0, 0.62, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Neon,
		Color = accentColor,
		Shape = Enum.PartType.Cylinder,
		CanCollide = false,
		Parent = model,
	})

	GeneratorKit.NewPart({
		Name = "CapsuleMachineBase",
		Size = Vector3.new(3.5, 1, 3.5),
		CFrame = buildingCFrame * CFrame.new(0, 1.1, 0),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(55, 55, 60),
		Parent = model,
	})

	local housing = GeneratorKit.NewPart({
		Name = "CapsuleMachineHousing",
		Size = Vector3.new(5.5, CAPSULE_HOUSING_HEIGHT, CAPSULE_HOUSING_HEIGHT),
		CFrame = buildingCFrame * CFrame.new(0, 3.8, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Glass,
		Color = accentColor,
		Transparency = 0.3,
		Shape = Enum.PartType.Cylinder,
		CanCollide = false,
		Parent = model,
	})
	housing:SetAttribute("Speed", 10)
	CollectionService:AddTag(housing, "SlowSpin")

	-- Visible mechanical struts around the housing.
	for i = 0, 2 do
		local angle = math.rad(i * 120)
		GeneratorKit.NewPart({
			Name = `Strut{i}`,
			Size = Vector3.new(0.3, 5.5, 0.3),
			CFrame = buildingCFrame * CFrame.new(math.cos(angle) * 1.8, 3.8, math.sin(angle) * 1.8),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(70, 70, 74),
			CanCollide = false,
			Parent = model,
		})
	end

	local core = GeneratorKit.NewPart({
		Name = "CapsuleMachineCore",
		Size = Vector3.new(0.9, 0.9, 0.9),
		CFrame = buildingCFrame * CFrame.new(0, 3.8, 0),
		Material = Enum.Material.Neon,
		Color = accentColor,
		Shape = Enum.PartType.Ball,
		CanCollide = false,
		Parent = model,
	})
	local coreLight = Instance.new("PointLight")
	coreLight.Color = accentColor
	coreLight.Brightness = 2.6
	coreLight.Range = 20
	coreLight.Parent = core
	CollectionService:AddTag(coreLight, "AmbientFlicker")

	-- Display rack of suspended capsule spheres -- "collection preview," so
	-- this reads as a summon/research chamber, not one glowing tube alone.
	local rackCFrame = buildingCFrame * CFrame.new(0, 1.9, -4)
	GeneratorKit.NewPart({
		Name = "CapsuleRack",
		Size = Vector3.new(3.4, 0.15, 0.6),
		CFrame = rackCFrame,
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(60, 60, 64),
		CanCollide = false,
		Parent = model,
	})
	local rackTints = { accentColor, Color3.fromRGB(255, 255, 255), accentColor:Lerp(Color3.new(1, 1, 1), 0.5) }
	for i, tint in rackTints do
		local offsetX = (i - 2) * 1.1
		local capsule = GeneratorKit.NewPart({
			Name = `CapsulePreview{i}`,
			Size = Vector3.new(0.7, 0.7, 0.7),
			CFrame = rackCFrame * CFrame.new(offsetX, 0.55, 0),
			Material = Enum.Material.Glass,
			Color = tint,
			Shape = Enum.PartType.Ball,
			Transparency = 0.2,
			CanCollide = false,
			Parent = model,
		})
		capsule:SetAttribute("FloatAmplitude", 0.2)
		capsule:SetAttribute("FloatSpeed", 1 + i * 0.15)
		CollectionService:AddTag(capsule, "AmbientFloat")
	end

	-- Control terminal to the side.
	local terminalCFrame = buildingCFrame * CFrame.new(5, 0, 1)
	GeneratorKit.NewPart({
		Name = "TerminalPedestal",
		Size = Vector3.new(1.5, 2.4, 1),
		CFrame = terminalCFrame * CFrame.new(0, 1.2, 0),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(55, 55, 60),
		Parent = model,
	})
	local terminalScreen = GeneratorKit.NewPart({
		Name = "TerminalScreen",
		Size = Vector3.new(1.2, 0.9, 0.12),
		CFrame = terminalCFrame * CFrame.new(0, 2.4, 0) * CFrame.Angles(math.rad(-25), 0, 0),
		Material = Enum.Material.Neon,
		Color = accentColor,
		Transparency = 0.2,
		CanCollide = false,
		Parent = model,
	})
	local terminalLight = Instance.new("PointLight")
	terminalLight.Color = accentColor
	terminalLight.Brightness = 1.4
	terminalLight.Range = 10
	terminalLight.Parent = terminalScreen
	CollectionService:AddTag(terminalLight, "AmbientFlicker")

	-- Scientist anchor, no character model -- same stub convention used
	-- elsewhere in this project.
	local npcAnchor = GeneratorKit.NewPart({
		Name = "ScientistAnchor",
		Size = Vector3.new(2, 2, 2),
		CFrame = buildingCFrame * CFrame.new(-4, 1, 1),
		Transparency = 1,
		CanCollide = false,
		Parent = model,
	})
	CollectionService:AddTag(npcAnchor, "NPC")

	buildSignBoard(model, buildingCFrame * CFrame.new(0, CAPSULE_HOUSING_HEIGHT + 5, 0), facility.name, accentColor, 8, 1.3, 60)
	buildFacilityAnchor(model, buildingCFrame * CFrame.new(0, 2.5, -(CAPSULE_PLATFORM_RADIUS + 1.5)), facility, accentColor)
end

-- COSMETIC SHOP: a small boutique stand -- dainty canopy, mannequin
-- centerpiece, mirror, a display shelf.
local COSMETIC_WIDTH = 9
local COSMETIC_DEPTH = 7
local COSMETIC_POST_HEIGHT = 5.5

local function buildCosmeticShop(model: Model, buildingCFrame: CFrame, facility: HavenFacilityConfig.FacilityDefinition, accentColor: Color3)
	GeneratorKit.NewPart({
		Name = "BoutiqueFloor",
		Size = Vector3.new(COSMETIC_WIDTH, 0.35, COSMETIC_DEPTH),
		CFrame = buildingCFrame * CFrame.new(0, 0.18, 0),
		Material = Enum.Material.Marble,
		Color = Color3.fromRGB(210, 190, 210),
		Parent = model,
	})

	for _, xSign in { -1, 1 } do
		GeneratorKit.NewPart({
			Name = if xSign < 0 then "PostLeft" else "PostRight",
			Size = Vector3.new(0.4, COSMETIC_POST_HEIGHT, 0.4),
			CFrame = buildingCFrame * CFrame.new(xSign * (COSMETIC_WIDTH / 2 - 0.4), COSMETIC_POST_HEIGHT / 2 + 0.35, COSMETIC_DEPTH / 2 - 0.4),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(70, 60, 74),
			Parent = model,
		})
	end

	local canopy = GeneratorKit.NewPart({
		Name = "BoutiqueCanopy",
		Size = Vector3.new(COSMETIC_WIDTH + 0.8, 0.25, COSMETIC_DEPTH * 0.6),
		CFrame = buildingCFrame * CFrame.new(0, COSMETIC_POST_HEIGHT + 0.5, COSMETIC_DEPTH / 4) * CFrame.Angles(math.rad(-8), 0, 0),
		Material = Enum.Material.Fabric,
		Color = accentColor,
		CanCollide = false,
		Parent = model,
	})
	CollectionService:AddTag(canopy, "AmbientSway")

	-- Mannequin/armor stand centerpiece.
	local bust = GeneratorKit.NewPart({
		Name = "MannequinBust",
		Size = Vector3.new(0.7, 1.4, 0.5),
		CFrame = buildingCFrame * CFrame.new(0, 1.45, -1),
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(230, 230, 235),
		Parent = model,
	})
	bust:SetAttribute("Speed", 22)
	CollectionService:AddTag(bust, "SlowSpin")

	local trail = GeneratorKit.NewPart({
		Name = "CosmeticTrail",
		Size = Vector3.new(0.08, 1.6, 0.08),
		CFrame = buildingCFrame * CFrame.new(0, 1.95, -1.5) * CFrame.Angles(math.rad(20), 0, 0),
		Material = Enum.Material.Neon,
		Color = accentColor,
		Transparency = 0.3,
		CanCollide = false,
		Parent = model,
	})
	local trailLight = Instance.new("PointLight")
	trailLight.Color = accentColor
	trailLight.Brightness = 1.4
	trailLight.Range = 10
	trailLight.Parent = trail
	CollectionService:AddTag(trailLight, "AmbientFlicker")

	-- Circular mirror/hologram panel behind the mannequin.
	GeneratorKit.NewPart({
		Name = "HoloMirror",
		Size = Vector3.new(0.1, 2.2, 2.2),
		CFrame = buildingCFrame * CFrame.new(0, 1.75, 1.4) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Glass,
		Color = accentColor,
		Transparency = 0.4,
		Shape = Enum.PartType.Cylinder,
		CanCollide = false,
		Parent = model,
	})

	-- Small display shelf.
	GeneratorKit.NewPart({
		Name = "DisplayShelf",
		Size = Vector3.new(2.4, 0.15, 0.6),
		CFrame = buildingCFrame * CFrame.new(2.8, 1.35, 0.8),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(60, 58, 64),
		CanCollide = false,
		Parent = model,
	})

	buildSignBoard(model, buildingCFrame * CFrame.new(0, COSMETIC_POST_HEIGHT + 1.4, -(COSMETIC_DEPTH / 2 - 0.6)), facility.name, accentColor, 6.5, 1.1, 45)
	buildFacilityAnchor(model, buildingCFrame * CFrame.new(0, 2.2, -(COSMETIC_DEPTH / 2 + 1.5)), facility, accentColor)
end

function CivicBuildingGenerator.Build(parent: Instance, origin: CFrame, facility: HavenFacilityConfig.FacilityDefinition, position: Vector3): Model
	GeneratorKit.CleanupPrevious(parent, facility.id)

	local model = Instance.new("Model")
	model.Name = facility.id

	local district = HavenLayoutConfig.GetDistrict(facility.district)

	-- Faces the plaza center regardless of which quadrant it's in.
	local buildingCFrame = CFrame.new(position, origin.Position)

	local primaryPartName = "FacilityAnchor"
	if facility.kind == "Market" then
		buildMarket(model, buildingCFrame, facility, district.accentColor)
		primaryPartName = "MarketFloor"
	elseif facility.kind == "UpgradeStation" then
		buildUpgradeStation(model, buildingCFrame, facility, district.accentColor)
		primaryPartName = "BayFloor"
	elseif facility.kind == "DailyRewards" then
		buildDailyRewards(model, buildingCFrame, facility, district.accentColor)
		primaryPartName = "RewardPlatform"
	elseif facility.kind == "CapsuleLab" then
		buildCapsuleLab(model, buildingCFrame, facility, district.accentColor)
		primaryPartName = "LabPlatform"
	elseif facility.kind == "CosmeticShop" then
		buildCosmeticShop(model, buildingCFrame, facility, district.accentColor)
		primaryPartName = "BoutiqueFloor"
	end

	GeneratorKit.Finalize(model, primaryPartName)
	model.Parent = parent

	return model
end

return CivicBuildingGenerator
