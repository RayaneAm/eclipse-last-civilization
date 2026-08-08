--!strict
-- Final composed-world validation. Run after all BuildCompleteWorld stages so
-- config geometry and the actual generated Workspace hierarchy are checked.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BiomeConfig = require(ReplicatedStorage.Shared.Config.BiomeConfig)
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
	check(report, rankingWall.Size.X >= 58 and rankingWall.Size.X <= 62, "Leaderboards backing wall is approximately 60 studs wide")
	check(report, headerBacking.Size.X >= 54, "Leaderboards has a large backing facade that overpowers the retaining wall")
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
		check(report, panelPart:GetAttribute("LeaderboardRowCount") == 10, `Leaderboard panel {panelIndex} declares Top 10`)
		check(report, panelPart:GetAttribute("PanelBottomWorldHeight") == 4.4, `Leaderboard panel {panelIndex} clears the foreground apron`)
		local display = panelPart:FindFirstChild("TopTenDisplay")
		check(report, display ~= nil and display:IsA("SurfaceGui"), `Leaderboard panel {panelIndex} has a Top 10 world display`)
		for rank = 1, 10 do
			local row = (display :: SurfaceGui):FindFirstChild(`Rank{rank}`)
			check(report, row ~= nil and row:IsA("Frame"), `Leaderboard panel {panelIndex} includes rank {rank}`)
			local rowFrame = row :: Frame
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
	local guideLocal = HavenLayoutConfig.GUIDE_LOCAL_POSITION
	report.Measurements.SpawnToBase = horizontalDistance(spawn, base)
	report.Measurements.SpawnToFirstService = horizontalDistance(spawn, guideLocal)
	check(report, report.Measurements.SpawnToBase >= 25 and report.Measurements.SpawnToBase <= 35, "Haven Spawn -> Personal Base is 25-35 studs")
	check(report, base.X < spawn.X and base.Z < spawn.Z, "Personal Base is diagonally left and forward from arrival")
	check(report, report.Measurements.SpawnToFirstService >= 25 and report.Measurements.SpawnToFirstService <= 40, "Haven Spawn -> first service is 25-40 studs")
	check(report, guideLocal.X > spawn.X and guideLocal.Z < spawn.Z, "Survival Guide is diagonally right and forward from arrival")
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
	local guidance = required(districtRoot, "Guidance")
	check(report, required(guidance, "Guide"):IsA("Model"), "Exactly one open-air Survival Guide presentation exists")
	check(report, guidance:FindFirstChild("GuideShelter", true) == nil and guidance:FindFirstChild("ShelterPost", true) == nil and guidance:FindFirstChild("TentTarpLeft", true) == nil, "Survival Guide has no tent or shelter")
	local baseTravelTagged = false
	for _, tagged in CollectionService:GetTagged("BaseGatePortal") do
		if tagged:IsDescendantOf(baseTent) and tagged:FindFirstChildOfClass("ProximityPrompt") then
			baseTravelTagged = true
		end
	end
	check(report, baseTravelTagged, "Personal Base Tent preserves the existing BaseGatePortal travel contract")
	local platform = required(havenRoot, "HavenPlatform")
	for _, pathName in { "ArrivalLane", "SouthServiceSpine", "CentralServiceSpine", "ExpeditionApproach", "BaseApproach" } do
		check(report, required(platform, pathName):IsA("BasePart"), `{pathName} navigation path exists`)
	end
	for index = 1, 3 do
		check(report, required(platform, `GuideForecourtSweep{index}`):IsA("BasePart"), `Guide forecourt sweep chord {index} exists`)
	end
	local arrivalLane = required(platform, "ArrivalLane") :: BasePart
	report.Measurements.HavenCentralRouteWidth = arrivalLane.Size.X
	check(report, arrivalLane.Size.X >= 16 and base.X <= -20 and guideLocal.X >= 20, "At least sixteen studs of straight central arrival route remain clear")
	check(report, platform:FindFirstChild("GuideForecourtEdge", true) == nil, "No black placeholder edge strip crosses the Haven floor")
	check(report, havenRoot:FindFirstChild("ColosseumWall", true) == nil, "Main Haven has no old circular colosseum root")
	check(report, havenRoot:FindFirstChild("EclipseCore", true) == nil, "Main Haven has no giant old Eclipse Core")
	local relay = required(havenRoot, "EclipseRelay")
	local relayDeck = required(relay, "RelayDeck") :: BasePart
	check(report, relayDeck.Size.X <= 14 and relayDeck.Size.Z <= 14, "Eclipse Relay remains a small secondary landmark")

	local facilities = required(districtRoot, "Facilities")
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
			local serviceWalkX = if definition.localPosition.X < 0 then -47 else 45
			local pathToEntrance = math.abs(entrance.X - serviceWalkX)
			check(report, pathToEntrance >= 10 and pathToEntrance <= 14, `{definition.id} front facade shares the standardized service-walk setback`)
		end
	end
	check(report, facilities:FindFirstChild("GamepassShowcase") == nil and facilities:FindFirstChild("StarterPack") == nil, "UI-only commerce has no physical buildings")
	local havenHumanoids = 0
	for _, descendant in districtRoot:GetDescendants() do
		if descendant:IsA("Humanoid") then
			havenHumanoids += 1
		end
	end
	check(report, havenHumanoids == 6, "Haven has exactly six staffed Humanoid NPCs")
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
	check(report, report.Measurements.CentralServicesToGateway >= 45 and report.Measurements.CentralServicesToGateway <= 60, "Central services -> Expeditions Gateway is 45-60 studs")
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
	check(report, flaredFacadeCount == 6, "Both outer side gaps use three reinforced facade sections")
	check(report, defenseReturnCount == 2, "Rear defensive arc connects into both Expedition side structures")
	check(report, expedition:FindFirstChild("VisibleSideBarrier", true) == nil and expedition:FindFirstChild("PocketEntryCurb", true) == nil and expedition:FindFirstChild("EntryCurbMarker", true) == nil, "Portal entries have no artificial stair cutoffs")

	local placements = {}
	local viewAngles = {}
	local expectedProgression = { "ForestWildlands", "FrozenWasteland", "NuclearCity", "VolcanicCore" }
	for _, biome in BiomeConfig do
		local placement = HavenLayoutConfig.PortalPlacement(biome.id)
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
