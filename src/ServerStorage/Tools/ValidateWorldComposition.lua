--!strict
-- Final composed-world validation. Run after all BuildCompleteWorld stages so
-- config geometry and the actual generated Workspace hierarchy are checked.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BiomeConfig = require(ReplicatedStorage.Shared.Config.BiomeConfig)
local DailyQuestConfig = require(ReplicatedStorage.Shared.Config.DailyQuestConfig)
local HavenFacilityConfig = require(ReplicatedStorage.Shared.Config.HavenFacilityConfig)
local HavenFacilityEnvelopeConfig = require(ReplicatedStorage.Shared.Config.HavenFacilityEnvelopeConfig)
local HavenLayoutConfig = require(ReplicatedStorage.Shared.Config.HavenLayoutConfig)
local LeaderboardConfig = require(ReplicatedStorage.Shared.Config.LeaderboardConfig)

local ValidateWorldComposition = {}

local DIMENSION_TOLERANCE = 0.01

export type ValidationReport = {
	Passed: boolean,
	Checks: { string },
	Measurements: { [string]: number },
	PortalSeparations: { [string]: number },
}

local function horizontalDistance(a: Vector3, b: Vector3): number
	return (Vector2.new(a.X, a.Z) - Vector2.new(b.X, b.Z)).Magnitude
end

local function check(report: ValidationReport, condition: boolean, message: string)
	if not condition then
		report.Passed = false
		error(`[WorldComposition] {message}`, 2)
	end
	table.insert(report.Checks, message)
end

local function required(parent: Instance, name: string): Instance
	local instance = parent:FindFirstChild(name, true)
	assert(instance, `[WorldComposition] required instance "{name}" missing below {parent:GetFullName()}`)
	return instance
end

local function colorsClose(a: Color3, b: Color3): boolean
	return math.abs(a.R - b.R) < 0.005 and math.abs(a.G - b.G) < 0.005 and math.abs(a.B - b.B) < 0.005
end

function ValidateWorldComposition.Run(): ValidationReport
	local report: ValidationReport = { Passed = true, Checks = {}, Measurements = {}, PortalSeparations = {} }

	-- Tutorial ---------------------------------------------------------
	local tutorial = Workspace:FindFirstChild("TutorialZone_Generated")
	check(report, tutorial ~= nil and tutorial:IsA("Model"), "Tutorial root exists")
	local tutorialRoot = tutorial :: Model
	check(report, tutorialRoot:GetAttribute("TotalFootprint") == 66, "Tutorial total footprint is 66x66")
	check(report, tutorialRoot:GetAttribute("PlayableFootprint") == 52, "Tutorial playable footprint is 52x52")
	local tutorialSpawn = required(tutorialRoot, "TutorialSpawn")
	check(report, tutorialSpawn:IsA("SpawnLocation"), "Tutorial has a real SpawnLocation")
	local guide = required(tutorialRoot, "Guide")
	check(report, guide:IsA("Model") and required(guide, "Humanoid"):IsA("Humanoid"), "Tutorial Guide is a Humanoid character")
	local guideAnchor = required(tutorialRoot, "QuestGiverAnchor")
	check(report, guideAnchor:IsA("BasePart"), "Tutorial Guide has a canonical interaction anchor")
	local workbench = required(tutorialRoot, "TutorialWorkbench")
	local workbenchAnchor = required(workbench, "FacilityAnchor")
	check(report, workbench:IsA("Model") and workbenchAnchor:IsA("BasePart") and workbenchAnchor:GetAttribute("FacilityId") == "UpgradeStation", "Tutorial workbench preserves crafting facility contract")
	check(report, required(tutorialRoot, "NaturalBoundary"):IsA("Model"), "Tutorial has visible natural containment")
	local resourceAnchors = required(tutorialRoot, "ResourceSpawnAnchors")
	check(report, #resourceAnchors:GetChildren() == 6, "Tutorial has six authored resource-node anchors")
	-- Navigation checks use the actual interaction volumes rather than a
	-- pitched NPC model pivot or a decorative table block. They intentionally
	-- measure XZ walking distance; anchor height is irrelevant to floor routing.
	local tutorialGuideDistance = horizontalDistance((tutorialSpawn :: BasePart).Position, (guideAnchor :: BasePart).Position)
	local guideWorkbenchDistance = horizontalDistance((guideAnchor :: BasePart).Position, (workbenchAnchor :: BasePart).Position)
	report.Measurements.TutorialSpawnToGuide = tutorialGuideDistance
	report.Measurements.TutorialGuideToWorkbench = guideWorkbenchDistance
	check(
		report,
		tutorialGuideDistance >= 10 and tutorialGuideDistance <= 18,
		`Tutorial Spawn -> Guide expected 10-18 studs, actual {string.format("%.2f", tutorialGuideDistance)} studs`
	)
	check(
		report,
		guideWorkbenchDistance >= 8 and guideWorkbenchDistance <= 15,
		`Tutorial Guide -> Workbench expected 8-15 studs, actual {string.format("%.2f", guideWorkbenchDistance)} studs`
	)

	-- Haven ------------------------------------------------------------
	local haven = Workspace:FindFirstChild("SurvivorHaven_Generated")
	local districts = Workspace:FindFirstChild("HavenDistricts_Generated")
	check(report, haven ~= nil and haven:IsA("Model"), "Survivor Haven root exists")
	check(report, districts ~= nil and districts:IsA("Model"), "Haven service root exists")
	local havenRoot = haven :: Model
	local districtRoot = districts :: Model
	local havenSpawn = required(havenRoot, "HavenSpawn")
	local leaderboardCount = 0
	local leaderboardHall: Model? = nil
	for _, descendant in Workspace:GetDescendants() do
		if descendant.Name == "Leaderboards" and descendant:IsA("Model") then
			leaderboardCount += 1
			leaderboardHall = descendant
		end
	end
	check(report, leaderboardCount == 1, "Exactly one generated Leaderboards hall exists")
	check(report, leaderboardHall ~= nil and leaderboardHall.Parent == districtRoot, "Leaderboards hall uses Workspace.HavenDistricts_Generated.Leaderboards")
	local hall = leaderboardHall :: Model
	local rankingWall = required(hall, "RankingWall") :: BasePart
	local headerBacking = required(hall, "RecordsHeaderBacking") :: BasePart
	report.Measurements.LeaderboardHallWidth = rankingWall.Size.X
	check(report, rankingWall.Size.X >= 47 and rankingWall.Size.X <= 49, "Leaderboards backing wall uses the compact approximately 48-stud width")
	check(report, headerBacking.Size.X >= 43, "Leaderboards retains a strong backing facade without hiding its outer panels")
	local hallLook = Vector3.new(rankingWall.CFrame.LookVector.X, 0, rankingWall.CFrame.LookVector.Z).Unit
	local spawnWorld = (havenSpawn :: BasePart).Position
	local hallToSpawn = Vector3.new(spawnWorld.X - rankingWall.Position.X, 0, spawnWorld.Z - rankingWall.Position.Z).Unit
	check(report, hallLook:Dot(hallToSpawn) > 0.99 and math.abs(hallLook.X) > 0.2, "Leaderboards hall is angled toward the actual Haven spawn")
	check(report, #LeaderboardConfig.Categories == 3, "Leaderboards retains all three records categories")
	local medalColors = { Color3.fromRGB(231, 184, 61), Color3.fromRGB(190, 201, 213), Color3.fromRGB(193, 119, 68) }
	for panelIndex, _ in LeaderboardConfig.Categories do
		local panel = hall:FindFirstChild(`LeaderboardPanel{panelIndex}`)
		check(report, panel ~= nil and panel:IsA("BasePart"), `Leaderboard panel {panelIndex} exists`)
		local panelPart = panel :: BasePart
		local horizontalOffset = math.abs((panelPart.Position - rankingWall.Position):Dot(rankingWall.CFrame.RightVector))
		check(report, horizontalOffset + panelPart.Size.X / 2 <= rankingWall.Size.X / 2, `Leaderboard panel {panelIndex} stays fully inside the compact backing facade`)
		local panelForwardOffset = (panelPart.Position - rankingWall.Position):Dot(rankingWall.CFrame.LookVector)
		check(report, panelForwardOffset >= 3.1, `Leaderboard panel {panelIndex} sits forward of every structural surface`)
		check(report, panelPart:GetAttribute("LeaderboardRowCount") == 10, `Leaderboard panel {panelIndex} declares Top 10`)
		check(report, panelPart:GetAttribute("PanelBottomWorldHeight") == 4.4, `Leaderboard panel {panelIndex} clears the foreground apron`)
		local display = panelPart:FindFirstChild("TopTenDisplay")
		check(report, display ~= nil and display:IsA("SurfaceGui"), `Leaderboard panel {panelIndex} has a Top 10 world display`)
		local displayGui = display :: SurfaceGui
		check(report, displayGui.LightInfluence == 0 and displayGui.Brightness >= 1.35, `Leaderboard panel {panelIndex} remains readable in evening lighting`)
		for rank = 1, 10 do
			local row = displayGui:FindFirstChild(`Rank{rank}`)
			check(report, row ~= nil and row:IsA("Frame"), `Leaderboard panel {panelIndex} includes rank {rank}`)
			local rowFrame = row :: Frame
			check(report, rowFrame.Size.Y.Scale >= 0.069 and rowFrame.BackgroundTransparency == 0, `Leaderboard panel {panelIndex} rank {rank} uses the enlarged high-contrast row`)
			if rank <= 3 then
				local medal = rowFrame:FindFirstChild("Medal")
				local award = rowFrame:FindFirstChild("Award")
				check(
					report,
					medal ~= nil and medal:IsA("TextLabel") and colorsClose(medal.BackgroundColor3, medalColors[rank]),
					`Leaderboard panel {panelIndex} rank {rank} has the approved medal highlight`
				)
				check(report, award ~= nil and award:IsA("TextLabel") and award.Text == ({ "GOLD", "SILVER", "BRONZE" })[rank], `Leaderboard panel {panelIndex} rank {rank} keeps its award name`)
			else
				check(report, rowFrame:FindFirstChild("Award") == nil and rowFrame:GetAttribute("AwardType") == "", `Leaderboard panel {panelIndex} rank {rank} contains no rank/ten suffix`)
			end
			if rank == 10 then
				local rowBottom = rowFrame.Position.Y.Scale + rowFrame.Size.Y.Scale
				check(report, rowBottom <= 0.94, `Leaderboard panel {panelIndex} rank 10 keeps readable bottom padding`)
			end
		end
	end
	check(report, hall:FindFirstChild("RecordsHallTower", true) == nil and hall:FindFirstChild("ViewingRail", true) == nil, "Leaderboard Hall contains no visible side pillar or rail that can cover a display")
	for index = 1, 2 do
		local blocker = required(hall, `RecordsRearAccessBlocker{index}`) :: BasePart
		check(
			report,
			blocker.Transparency == 1
				and blocker.CanCollide
				and not blocker.CanQuery
				and blocker.Size.Z >= 28
				and blocker:GetAttribute("PhysicsOnlyRearClosure") == true,
			`Leaderboard rear access blocker {index} prevents entry without obstructing the camera`
		)
	end
	check(report, havenSpawn:IsA("SpawnLocation"), "Haven Arrival spawn exists")
	check(report, required(havenRoot, "HavenArrivalAnchor"):IsA("BasePart"), "Haven transition arrival anchor exists")
	local spawnCount = 0
	for _, descendant in havenRoot:GetDescendants() do
		if descendant:IsA("SpawnLocation") and string.match(descendant.Name, "^HavenSpawn") then
			spawnCount += 1
		end
	end
	check(report, spawnCount == HavenLayoutConfig.SPAWN_POINT_COUNT, "Exactly five integrated Haven spawns exist")
	local spawn = HavenLayoutConfig.SPAWN_LOCAL_POSITION
	local base = HavenLayoutConfig.BASE_GATE_LOCAL_POSITION
	local campLocal = HavenLayoutConfig.CAMP_CIRCLE_LOCAL_POSITION
	local dailyBoardLocal = HavenLayoutConfig.NOTICE_BOARD_LOCAL_POSITION
	local leaderboardLocal = HavenLayoutConfig.LEADERBOARD_LOCAL_POSITION
	local expeditionDecision = HavenLayoutConfig.EXPEDITION_GATHERING_LOCAL_POSITION
	report.Measurements.HavenActiveWidth = HavenLayoutConfig.HAVEN_MAX_X - HavenLayoutConfig.HAVEN_MIN_X
	report.Measurements.HavenActiveDepth = HavenLayoutConfig.HAVEN_MAX_Z - HavenLayoutConfig.HAVEN_MIN_Z
	report.Measurements.SpawnToBase = horizontalDistance(spawn, base)
	report.Measurements.SpawnToCampCircle = horizontalDistance(spawn, campLocal)
	report.Measurements.SpawnToDailyQuests = horizontalDistance(spawn, dailyBoardLocal)
	report.Measurements.SpawnToLeaderboard = horizontalDistance(spawn, leaderboardLocal)
	report.Measurements.SpawnToExpeditionDecision = horizontalDistance(spawn, expeditionDecision)
	check(report, report.Measurements.HavenActiveWidth == 124 and report.Measurements.HavenActiveDepth == 134, "Main Haven active footprint is compacted to 124x134 studs")
	check(report, report.Measurements.SpawnToBase >= 40 and report.Measurements.SpawnToBase <= 52, "Haven Spawn -> Personal Base is approximately a three-second walk")
	check(report, report.Measurements.SpawnToDailyQuests >= 45 and report.Measurements.SpawnToDailyQuests <= 60, "Haven Spawn -> Daily Quests is approximately a three-to-four-second walk")
	check(report, dailyBoardLocal.X >= 45 and dailyBoardLocal.Z >= 90, "Daily Quests occupies the protected south-east spawn corner")
	check(report, report.Measurements.SpawnToLeaderboard <= 120, "Haven Spawn -> Leaderboards stays below a 7.5-second direct walk")
	check(report, report.Measurements.SpawnToExpeditionDecision <= 130, "Haven Spawn -> Expedition decision area stays near eight seconds")
	check(report, base.X < spawn.X and base.Z < spawn.Z, "Personal Base is diagonally left and forward from arrival")
	check(report, report.Measurements.SpawnToCampCircle >= 25 and report.Measurements.SpawnToCampCircle <= 40, "Haven Spawn -> camp fire circle is 25-40 studs")
	check(report, campLocal.X > spawn.X and campLocal.Z < spawn.Z, "Camp fire circle is diagonally right and forward from arrival")
	local baseTent = required(havenRoot, "PersonalBaseTent")
	check(report, baseTent:IsA("Model") and baseTent:GetAttribute("IsSurvivalTent") == true, "Personal Base uses the canonical survival tent")
	local tentCount = 0
	for _, root in { havenRoot, districtRoot } do
		for _, descendant in root:GetDescendants() do
			if descendant:IsA("Model") and descendant:GetAttribute("IsSurvivalTent") == true then
				tentCount += 1
			end
		end
	end
	check(report, tentCount == 1, "Exactly one survival tent exists in Haven")
	check(report, havenRoot:FindFirstChild("BaseGate", true) == nil and havenRoot:FindFirstChild("BaseGateField", true) == nil, "Old giant Personal Base portal geometry is absent")

	-- The tent redesign, asserted structurally. The old version was two bare
	-- tarp slabs with open ends and no rigging; each of these is a piece it was
	-- missing, so a regression to that silhouette fails here.
	check(report, required(baseTent, "TentRidgePole"):IsA("BasePart") and required(baseTent, "TentEavePurlin"):IsA("BasePart"), "Survival tent has a real ridge-and-purlin frame")
	local gablePlanks, guyRopes, tarpPanels = 0, 0, 0
	for _, descendant in baseTent:GetDescendants() do
		if descendant:IsA("BasePart") then
			if string.match(descendant.Name, "^TentGablePlank%d+$") then
				gablePlanks += 1
			elseif descendant.Name == "TentGuyRope" then
				guyRopes += 1
			elseif descendant.Name == "TentTarpLeft" or descendant.Name == "TentTarpRight" then
				tarpPanels += 1
			end
		end
	end
	check(report, tarpPanels == 2 and gablePlanks >= 4, "Survival tent closes its rear gable instead of leaving the ends open")
	check(report, guyRopes >= 4, "Survival tent is guyed down to ground pegs")
	check(report, required(baseTent, "TentBedroll"):IsA("BasePart") and required(baseTent, "FieldLantern"):IsA("BasePart") and required(baseTent, "CampFireEmbers"):IsA("BasePart"), "Personal Base reads as an inhabited camp, not a bare shelter")
	-- The Haven Guide installation is gone on purpose. These assert its ABSENCE
	-- so it cannot quietly come back: no Guidance model, no Guide figure in the
	-- districts, and nothing still claiming the QuestGiver facility contract
	-- inside Haven (the tutorial's own Guide is a separate zone and untouched).
	check(report, districtRoot:FindFirstChild("Guidance") == nil, "Haven Guide installation is fully removed")
	check(report, districtRoot:FindFirstChild("Guide", true) == nil, "No Haven Guide figure remains")
	check(report, districtRoot:FindFirstChild("HavenGuideAnchor", true) == nil and districtRoot:FindFirstChild("ExpeditionDirectionBoard", true) == nil, "Haven Guide booth props and signage are gone")
	for _, tagged in CollectionService:GetTagged("HavenFacility") do
		if tagged:IsDescendantOf(havenRoot) or tagged:IsDescendantOf(districtRoot) then
			check(report, tagged:GetAttribute("FacilityId") ~= "QuestGiver", "No Haven facility still claims the removed QuestGiver contract")
		end
	end

	-- The fire circle that reclaimed the plot.
	local campCircle = required(districtRoot, "CampCircle")
	check(report, campCircle:IsA("Model") and required(campCircle, "CampfireEmbers"):IsA("BasePart"), "Camp fire circle occupies the former Guide plot without a competing clearing floor")
	check(report, campCircle:FindFirstChild("CampClearing", true) == nil, "Camp fire circle uses the canonical Haven ground beneath it")
	check(report, required(campCircle, "CampfireEmbers"):FindFirstChildOfClass("PointLight") ~= nil, "Camp fire circle carries its own warm practical light")
	local seatCount = 0
	for _, descendant in campCircle:GetDescendants() do
		if descendant:IsA("BasePart") and string.match(descendant.Name, "^Seating") then
			seatCount += 1
		end
	end
	check(report, seatCount >= 7, "Camp fire circle provides a real ring of seating")
	local baseTravelTagged = false
	for _, tagged in CollectionService:GetTagged("BaseGatePortal") do
		if tagged:IsDescendantOf(baseTent) and tagged:FindFirstChildOfClass("ProximityPrompt") then
			baseTravelTagged = true
		end
	end
	check(report, baseTravelTagged, "Personal Base Tent preserves the existing BaseGatePortal travel contract")
	local platform = required(havenRoot, "HavenPlatform")
	local settlementFoundation = required(platform, "SettlementFoundation") :: BasePart
	check(report, settlementFoundation.Size.X == 124 and settlementFoundation.Size.Z == 134, "Generated Haven foundation matches the compact active footprint")
	for _, pathName in { "ArrivalLane", "SouthServiceSpine", "CentralServiceSpine", "ExpeditionApproach", "BaseApproach" } do
		check(report, required(platform, pathName):IsA("BasePart"), `{pathName} navigation path exists`)
	end
	for index = 1, 3 do
		check(report, required(platform, `CampForecourtSweep{index}`):IsA("BasePart"), `Camp forecourt sweep chord {index} exists`)
	end
	local arrivalLane = required(platform, "ArrivalLane") :: BasePart
	report.Measurements.HavenCentralRouteWidth = arrivalLane.Size.X
	check(report, arrivalLane.Size.X >= 16 and base.X <= -20 and campLocal.X >= 20, "At least sixteen studs of straight central arrival route remain clear")
	check(report, platform:FindFirstChild("ArrivalCheckpoint", true) == nil, "Obsolete arrival checkpoint, canopy and direction sign are absent behind Spawn")
	local campForecourtStart = required(platform, "CampForecourtSweep1") :: BasePart
	local baseForecourtStart = required(platform, "BaseForecourtSweep1") :: BasePart
	local function worldXHalfExtent(route: BasePart): number
		return math.abs(route.CFrame.RightVector.X) * route.Size.X / 2
			+ math.abs(route.CFrame.LookVector.X) * route.Size.Z / 2
	end
	local laneHalfWidth = arrivalLane.Size.X / 2
	check(report, campForecourtStart.Position.X - worldXHalfExtent(campForecourtStart) > arrivalLane.Position.X + laneHalfWidth, "Camp forecourt starts beyond the central cement lane")
	check(report, baseForecourtStart.Position.X + worldXHalfExtent(baseForecourtStart) < arrivalLane.Position.X - laneHalfWidth, "Base forecourt starts beyond the central cement lane")
	check(report, platform:FindFirstChild("GuideForecourtEdge", true) == nil, "No black placeholder edge strip crosses the Haven floor")
	check(report, havenRoot:FindFirstChild("ColosseumWall", true) == nil, "Main Haven has no old circular colosseum root")
	check(report, havenRoot:FindFirstChild("EclipseCore", true) == nil, "Main Haven has no giant old Eclipse Core")

	-- Ground language. The base is now a single edge-matched tile composition,
	-- never a full slab plus coplanar random overlays.
	local ground = required(platform, "SettlementGround")
	local settlementSurface = required(platform, "SettlementSurface") :: BasePart
	check(report, settlementSurface.Material == Enum.Material.Ground, "Settlement floor is compacted earth, not an asphalt baseplate")
	check(report, ground:GetAttribute("CreatesBroadFloorOverlays") == false, "Ground dressing creates no competing broad floor layer")
	local surfaceTiles: { BasePart } = {}
	local surfaceMaterials: { [Enum.Material]: boolean } = {}
	for _, child in platform:GetChildren() do
		if child:IsA("BasePart") and child:GetAttribute("HavenGroundSurface") == true then
			table.insert(surfaceTiles, child)
			surfaceMaterials[child.Material] = true
			local top = child.Position.Y + child.Size.Y / 2
			check(report, math.abs(top - 1) < 0.001, `{child.Name} shares the canonical stable ground top`)
		end
	end
	check(report, #surfaceTiles == 9, "Haven base surface is exactly nine edge-matched material zones")
	for firstIndex = 1, #surfaceTiles do
		local first = surfaceTiles[firstIndex]
		for secondIndex = firstIndex + 1, #surfaceTiles do
			local second = surfaceTiles[secondIndex]
			local overlapX = math.min(first.Position.X + first.Size.X / 2, second.Position.X + second.Size.X / 2)
				- math.max(first.Position.X - first.Size.X / 2, second.Position.X - second.Size.X / 2)
			local overlapZ = math.min(first.Position.Z + first.Size.Z / 2, second.Position.Z + second.Size.Z / 2)
				- math.max(first.Position.Z - first.Size.Z / 2, second.Position.Z - second.Size.Z / 2)
			check(report, overlapX <= 0.001 or overlapZ <= 0.001, `{first.Name} and {second.Name} do not overlap`)
		end
	end
	local surfaceMaterialCount = 0
	for _ in surfaceMaterials do
		surfaceMaterialCount += 1
	end
	check(report, surfaceMaterialCount >= 3, "Haven base zones use earth, dust/sand and gravel materials")
	check(report, ground:FindFirstChild("OldRoadSlab1", true) == nil, "Old road floor slabs no longer compete with the final ground")
	local boardwalkPlanks = 0
	local stringLightCables = 0
	local survivalDetails = 0
	for _, descendant in ground:GetDescendants() do
		if descendant:IsA("BasePart") and string.match(descendant.Name, "Board%d+$") then
			boardwalkPlanks += 1
		elseif descendant:IsA("BasePart") and string.match(descendant.Name, "^StringLightCable") then
			stringLightCables += 1
		elseif descendant:IsA("BasePart") and (string.match(descendant.Name, "^BoundaryRock") or string.match(descendant.Name, "^SalvageBundle")) then
			survivalDetails += 1
		end
	end
	check(report, boardwalkPlanks >= 40, "Plank boardwalks are built board-by-board, not as one slab")
	check(report, stringLightCables == 8, "Four practical-light spans retain physical survivor-rigged cables")
	check(report, ground:FindFirstChild("StringLightPost5", true) == nil, "No string-light post obstructs the first Leaderboard panel")
	check(report, survivalDetails >= 3, "Compact Haven retains purposeful rocks and salvage dressing")
	local southSpine = required(platform, "SouthServiceSpine") :: BasePart
	local centralSpine = required(platform, "CentralServiceSpine") :: BasePart
	local expeditionApproach = required(platform, "ExpeditionApproach") :: BasePart
	check(report, arrivalLane.Position.Z - arrivalLane.Size.Z / 2 >= southSpine.Position.Z + southSpine.Size.Z / 2 - 0.001, "Arrival and south route plates meet without coplanar overlap")
	check(report, southSpine.Position.Z - southSpine.Size.Z / 2 >= centralSpine.Position.Z + centralSpine.Size.Z / 2 - 0.001, "South and central route plates meet without coplanar overlap")
	check(report, centralSpine.Position.Z - centralSpine.Size.Z / 2 >= expeditionApproach.Position.Z + expeditionApproach.Size.Z / 2 - 0.001, "Central and Expedition route plates meet without coplanar overlap")

	-- The Eclipse Relay is gone; the survivor task board took the plot.
	check(report, havenRoot:FindFirstChild("EclipseRelay") == nil, "Eclipse Relay is fully removed from Haven")
	check(report, havenRoot:FindFirstChild("RelayCoreColumn", true) == nil and havenRoot:FindFirstChild("RelayCorePedestal", true) == nil and havenRoot:FindFirstChild("RelayDeck", true) == nil, "Eclipse Relay pedestal, column and deck are gone")
	local questBoard = required(havenRoot, "DailyQuestBoard")
	check(report, questBoard:IsA("Model"), "Daily Quests board exists in Haven")
	local boardAnchor = required(questBoard, "FacilityAnchor")
	check(report, boardAnchor:GetAttribute("FacilityId") == "DailyQuests" and CollectionService:HasTag(boardAnchor, "HavenFacility"), "Daily Quests board uses the standard HavenFacility interaction contract")
	check(report, questBoard:GetAttribute("QuestSlots") == 3 and DailyQuestConfig.QUESTS_PER_DAY == 3, "Daily Quests board and gameplay both use exactly three slots")
	local display = required(questBoard, "QuestDisplay")
	local surface = required(display, "QuestDisplaySurface")
	check(report, surface:IsA("SurfaceGui") and (surface :: SurfaceGui).CanvasSize.X >= 1200, "Daily Quests board uses a large readable display")
	check(report, required(surface, "ResetTimer"):IsA("TextLabel"), "Daily Quests board shows a visible reset timer")
	for index = 1, 3 do
		local row = required(surface, `QuestRow{index}`)
		check(report, row:IsA("Frame") and typeof(row:GetAttribute("RewardScrap")) == "number", `Daily quest row {index} represents one shared active quest`)
		check(report, required(row, "QuestName"):IsA("TextLabel") and required(row, "Objective"):IsA("TextLabel"), `Daily quest row {index} shows its quest text`)
		local reward = required(row, "Reward") :: TextLabel
		check(report, string.find(string.upper(reward.Text), "SCRAP") ~= nil, `Daily quest row {index} shows its reward directly`)
		local track = required(row, "ProgressTrack")
		check(report, required(row, "Status"):IsA("TextLabel") and required(track, "ProgressFill"):IsA("Frame"), `Daily quest row {index} has status and progress presentation`)
	end

	local facilities = required(districtRoot, "Facilities")
	local nearestServiceDistance = math.huge
	local uniqueFacilitySignature = {
		SurvivorMarket = "MerchantCounter",
		CosmeticShop = "DisplayMannequin",
		CapsuleLaboratory = "ContainmentCapsule",
		DailyRewards = "SupplyChest",
		UpgradeStation = "Workbench",
	}
	local workingSurfaceByFacility = {
		SurvivorMarket = "MerchantCounter",
		CosmeticShop = "StoreCounter",
		CapsuleLaboratory = "AnalysisCounter",
		DailyRewards = "ClaimCounter",
		UpgradeStation = "Workbench",
	}
	for _, definition in HavenFacilityConfig do
		if not definition.bespoke then
			local facility = facilities:FindFirstChild(definition.id)
			check(report, facility ~= nil and facility:IsA("Model"), `{definition.id} physical facility exists`)
			local facilityModel = facility :: Model
			check(report, required(facilityModel, "FacilityAnchor"):GetAttribute("FacilityId") == definition.id, `{definition.id} preserves HavenFacility contract`)
			local floor = required(facilityModel, "FacilityFloor") :: BasePart
			local rearWall = required(facilityModel, "RearWall") :: BasePart
			local canopy = required(facilityModel, "Canopy") :: BasePart
			local header = required(facilityModel, "FrontFacadeHeader") :: BasePart
			-- The staffed-facility sign is a canonical direct child of its shell.
			-- Do not recursively select an unrelated label from bespoke interior
			-- content, and do not compare float32 Part dimensions for exact equality.
			local signInstance = facilityModel:FindFirstChild("WorldLabel")
			check(
				report,
				signInstance ~= nil and signInstance:IsA("BasePart"),
				`{definition.id} canonical direct-child WorldLabel exists`
			)
			local sign = signInstance :: BasePart
			local facilityGround = floor.Position.Y - floor.Size.Y / 2
			local actualSignCenterHeight = sign.Position.Y - facilityGround
			local hasCanonicalContract = sign:GetAttribute("IsCanonicalWorldFacilityLabel") == true
				and sign:GetAttribute("FacilityId") == definition.id
			local signMatchesEnvelope = math.abs(sign.Size.X - HavenFacilityEnvelopeConfig.SignWidth) < DIMENSION_TOLERANCE
				and math.abs(sign.Size.Y - HavenFacilityEnvelopeConfig.SignHeight) < DIMENSION_TOLERANCE
				and math.abs(actualSignCenterHeight - HavenFacilityEnvelopeConfig.SignCenterHeight) < DIMENSION_TOLERANCE
			check(report, floor.Size.X == HavenFacilityEnvelopeConfig.Width and floor.Size.Z == HavenFacilityEnvelopeConfig.Depth, `{definition.id} uses the standardized 22x18 footprint`)
			check(report, rearWall.Size.Y == HavenFacilityEnvelopeConfig.WallHeight and facilityModel:GetAttribute("EnvelopeHeight") == HavenFacilityEnvelopeConfig.OverallHeight, `{definition.id} uses the standardized fourteen-stud roofline`)
			check(report, canopy.Size.X == HavenFacilityEnvelopeConfig.Width + HavenFacilityEnvelopeConfig.RoofOverhang * 2 and canopy.Size.Z == HavenFacilityEnvelopeConfig.Depth + HavenFacilityEnvelopeConfig.RoofOverhang * 2, `{definition.id} uses the standardized roof overhang`)
			check(report, header.Size.X == HavenFacilityEnvelopeConfig.Width and header.Size.Y == HavenFacilityEnvelopeConfig.FrontHeaderHeight, `{definition.id} uses the standardized front facade header`)
			check(
				report,
				hasCanonicalContract and signMatchesEnvelope,
				string.format(
					"%s sign expected %.2fx%.2f at local Y=%.2f with canonical contract, actual %.9fx%.9f at local Y=%.9f (canonical=%s, FacilityId=%s)",
					definition.id,
					HavenFacilityEnvelopeConfig.SignWidth,
					HavenFacilityEnvelopeConfig.SignHeight,
					HavenFacilityEnvelopeConfig.SignCenterHeight,
					sign.Size.X,
					sign.Size.Y,
					actualSignCenterHeight,
					tostring(sign:GetAttribute("IsCanonicalWorldFacilityLabel")),
					tostring(sign:GetAttribute("FacilityId"))
				)
			)
			check(report, required(facilityModel, uniqueFacilitySignature[definition.id]):IsA("BasePart"), `{definition.id} retains its unique functional identity`)
			local workingSurface = required(facilityModel, workingSurfaceByFacility[definition.id]) :: BasePart
			local workingTop = workingSurface.Position.Y + workingSurface.Size.Y / 2
			check(report, math.abs((workingTop - facilityGround) - HavenFacilityEnvelopeConfig.CounterTopHeight) < 0.01, `{definition.id} working surface is standardized at 3.5 studs`)
			local entrance = definition.localPosition + definition.frontDirection * (HavenFacilityEnvelopeConfig.Depth / 2)
			local serviceWalkX = if definition.localPosition.X < 0 then -31 else 31
			local pathToEntrance = math.abs(entrance.X - serviceWalkX)
			nearestServiceDistance = math.min(nearestServiceDistance, horizontalDistance(spawn, entrance))
			check(report, pathToEntrance >= 8 and pathToEntrance <= 10, `{definition.id} front facade shares the compact service-walk setback`)
		end
	end
	report.Measurements.SpawnToNearestService = nearestServiceDistance
	check(report, nearestServiceDistance >= 60 and nearestServiceDistance <= 80, "Spawn -> nearest staffed service is approximately four-to-five seconds")
	check(report, facilities:FindFirstChild("GamepassShowcase") == nil and facilities:FindFirstChild("StarterPack") == nil, "UI-only commerce has no physical buildings")
	local havenHumanoids = 0
	for _, descendant in districtRoot:GetDescendants() do
		if descendant:IsA("Humanoid") then
			havenHumanoids += 1
		end
	end
	-- Five, not six: the Haven Guide was removed this pass. The remaining NPCs
	-- are the staffed civic facilities (Merchant, Engineer, Scientist,
	-- Outfitter, Reward Officer), each of which backs a real service.
	check(report, havenHumanoids == 5, "Haven has exactly five staffed Humanoid NPCs")
	local duplicatedTutorialPortal = false
	for _, tagged in CollectionService:GetTagged("TutorialPortal") do
		if tagged:IsDescendantOf(havenRoot) or tagged:IsDescendantOf(districtRoot) then
			duplicatedTutorialPortal = true
		end
	end
	check(report, not duplicatedTutorialPortal, "No Tutorial portal/compound remains inside Haven")

	-- Expeditions ------------------------------------------------------
	local gateway = HavenLayoutConfig.EXPEDITION_GATEWAY_LOCAL_POSITION
	local gathering = HavenLayoutConfig.EXPEDITION_GATHERING_LOCAL_POSITION
	report.Measurements.CentralServicesToGateway = horizontalDistance(Vector3.new(0, 0, 18), gateway)
	check(report, report.Measurements.CentralServicesToGateway >= 30 and report.Measurements.CentralServicesToGateway <= 38, "Central services -> Expeditions Gateway is compacted to 30-38 studs")
	check(report, required(havenRoot, "NorthernFortification"):IsA("Model"), "Fortified Expeditions Gateway exists")
	local securityBarrier = required(havenRoot, "ExpeditionBarrier")
	local fieldCount = 0
	for _, descendant in securityBarrier:GetDescendants() do
		if descendant:IsA("BasePart") and string.match(descendant.Name, "^Field") then
			fieldCount += 1
		end
	end
	check(report, fieldCount == 6, "Gateway security field closes the complete bypass opening")
	local expedition = required(havenRoot, "ExpeditionDistrict")
	local curvedCount = 0
	local flaredFacadeCount = 0
	local defenseReturnCount = 0
	for _, descendant in expedition:GetDescendants() do
		if descendant.Name == "CurvedDefenseSegment" then
			curvedCount += 1
		elseif descendant.Name == "FlaredSideFacade" then
			flaredFacadeCount += 1
		elseif descendant.Name == "DefenseWallReturn" then
			defenseReturnCount += 1
		end
	end
	check(report, curvedCount == 14, "Expedition portal fan has fourteen curved defensive wall segments")
	check(report, expedition:GetAttribute("DistrictWidth") == 260, "Expedition district is 260 studs wide")
	check(report, expedition:GetAttribute("PortalArcRadius") == 95, "Expedition compaction preserves the approved 95-stud portal radius")
	local gatheringDisc = required(expedition, "CentralExpeditionGathering") :: BasePart
	check(report, gatheringDisc.Size.Y == 24 and gatheringDisc.Size.Z == 24, "Expedition decision platform is compacted without a broad overlapping plaza")
	check(report, expedition:FindFirstChild("GatewayCauseway") == nil, "Gateway opens directly onto the compact decision platform without dead causeway pavement")
	check(report, flaredFacadeCount == 6, "Both outer side gaps use three reinforced facade sections")
	check(report, defenseReturnCount == 2, "Rear defensive arc connects into both Expedition side structures")
	check(report, expedition:FindFirstChild("VisibleSideBarrier", true) == nil and expedition:FindFirstChild("PocketEntryCurb", true) == nil and expedition:FindFirstChild("EntryCurbMarker", true) == nil, "Portal entries have no artificial stair cutoffs")

	local placements = {}
	local viewAngles = {}
	local expectedProgression = { "ForestWildlands", "FrozenWasteland", "NuclearCity", "VolcanicCore" }
	for _, biome in BiomeConfig do
		local placement = HavenLayoutConfig.PortalPlacement(biome.id)
		report.Measurements[`SpawnToPortal_{biome.id}`] = horizontalDistance(spawn, placement.localPosition)
		table.insert(placements, { Id = biome.id, Position = placement.localPosition, Width = placement.pocketWidth, Angle = placement.arcAngleDegrees })
		local radius = horizontalDistance(placement.localPosition, HavenLayoutConfig.EXPEDITION_ARC_CENTER_LOCAL_POSITION)
		check(report, math.abs(radius - HavenLayoutConfig.EXPEDITION_ARC_RADIUS) < 0.01, `{biome.id} lies on the configured portal arc`)
		check(report, horizontalDistance(placement.approachLocalPosition, HavenLayoutConfig.EXPEDITION_ARC_CENTER_LOCAL_POSITION) < radius, `{biome.id} approach faces the central gathering area`)
		local pocket = expedition:FindFirstChild(`{biome.id}Pocket`)
		check(report, pocket ~= nil and pocket:IsA("Model"), `{biome.id} has an independent portal pocket`)
		local approachDecor = expedition:FindFirstChild(`{biome.id}ApproachDecor`)
		check(report, approachDecor ~= nil and approachDecor:IsA("Model") and approachDecor:GetAttribute("TransitionLength") == 36, `{biome.id} theme uses a meaningful 36-stud approach transition`)
		local transitionFloorCount = 0
		for _, child in (approachDecor :: Model):GetChildren() do
			if string.match(child.Name, "^ApproachTransitionFloor") then
				transitionFloorCount += 1
			end
		end
		check(report, transitionFloorCount == 3, `{biome.id} approach has three progressive floor stages`)
		local gate = required(havenRoot, `Gate_{biome.id}`)
		check(report, gate:IsA("Model") and gate:GetAttribute("PortalShape") == "Circular", `{biome.id} uses the shared circular portal technology`)
		local portalRing = required(gate, "PortalRing")
		check(report, portalRing:IsA("Model") and #portalRing:GetChildren() == 24, `{biome.id} has a complete 24-segment structural ring`)
		check(report, gate:FindFirstChild("InnerEnergyRing", true) == nil, `{biome.id} has no detached spinning energy ring`)
		check(report, math.abs((gate:GetAttribute("RingOuterDiameter") :: number) - 22 * biome.gate.scale) < 0.01, `{biome.id} circular ring uses its configured progression scale`)
		local barrier = required(gate, "GateBarrier")
		check(report, barrier:IsA("Part") and (barrier :: Part).Shape == Enum.PartType.Cylinder, `{biome.id} has a circular energy membrane`)
		local worldLabel = required(gate, "WorldLabel") :: BasePart
		check(report, worldLabel.Position.Y > (required(gate, "GateAnchor") :: BasePart).Position.Y + 5, `{biome.id} status label stays above rather than across the ring`)
		check(report, placement.status == (if biome.id == "ForestWildlands" then "BETA" else "COMING SOON"), `{biome.id} status is correct`)
		local gateAnchor = required(gate, "GateAnchor") :: BasePart
		check(report, gate:FindFirstChild("PortalDoorPost", true) == nil and gate:FindFirstChild("WarningPylon", true) == nil, `{biome.id} has no obsolete rectangular frame or stair pylons`)
		local frontDirection = -gateAnchor.CFrame.LookVector
		local approachDirection = (HavenLayoutConfig.PositionFromLocal(CFrame.identity, placement.approachLocalPosition) - HavenLayoutConfig.PositionFromLocal(CFrame.identity, placement.localPosition)).Unit
		check(report, frontDirection:Dot(approachDirection) > 0.98, `{biome.id} portal front faces its central approach`)
		local fromGateway = placement.localPosition - gateway
		table.insert(viewAngles, math.deg(math.atan2(fromGateway.X, -fromGateway.Z)))
	end
	check(report, report.Measurements.SpawnToPortal_ForestWildlands <= 192, "Spawn -> first biome portal is at most approximately twelve seconds")
	table.sort(placements, function(a, b)
		return a.Angle < b.Angle
	end)
	for index, expectedBiomeId in expectedProgression do
		check(report, placements[index].Id == expectedBiomeId, `Portal position {index} follows gameplay progression ({expectedBiomeId})`)
	end
	for index = 1, #placements - 1 do
		local a = placements[index]
		local b = placements[index + 1]
		local angularSeparation = b.Angle - a.Angle
		local centerDistance = horizontalDistance(a.Position, b.Position)
		local clearance = centerDistance - (a.Width + b.Width) / 2
		report.PortalSeparations[`{a.Id}->{b.Id}`] = clearance
		check(report, angularSeparation >= 44 and angularSeparation <= 46, `{a.Id} -> {b.Id} angular separation is approximately 45 degrees`)
		check(report, clearance >= 10, `{a.Id} -> {b.Id} portal pockets have at least 10 studs free clearance`)
	end
	table.sort(viewAngles)
	for index = 1, #viewAngles - 1 do
		check(report, viewAngles[index + 1] - viewAngles[index] >= 15, "Portal silhouettes do not share a Gateway-view centerline")
	end
	check(report, horizontalDistance(gathering, HavenLayoutConfig.EXPEDITION_ARC_CENTER_LOCAL_POSITION) <= 10, "Central Expedition gathering area anchors the portal fan")

	return report
end

return ValidateWorldComposition
