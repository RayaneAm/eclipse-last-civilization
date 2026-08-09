--!strict
-- Focused validation for the runtime-generated Personal Base. Static config
-- checks run without a live base; pass a generated player model to also audit
-- forest, ground, pad, portal and hidden-assault geometry in Studio.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BuildingConfig = require(ReplicatedStorage.Shared.Config.BuildingConfig)
local BlueprintLayoutConfig = require(ReplicatedStorage.Shared.Config.BlueprintLayoutConfig)
local PersonalBaseConfig = require(ReplicatedStorage.Shared.Config.PersonalBaseConfig)

export type ValidationReport = {
	Passed: boolean,
	Checks: number,
	Errors: { string },
	Measurements: { [string]: number },
	RuntimeChecksSkipped: boolean,
}

local ValidatePersonalBaseLayout = {}
local BOUNDS_TOLERANCE = 0.01

local function check(report: ValidationReport, condition: boolean, message: string)
	report.Checks += 1
	if not condition then
		report.Passed = false
		table.insert(report.Errors, message)
	end
end

local function footprintRadius(pad: BlueprintLayoutConfig.BlueprintPad): number
	local size = BlueprintLayoutConfig.GetFootprintSize(pad)
	return math.sqrt((size.X / 2) ^ 2 + (size.Z / 2) ^ 2)
end

local function orientedExtents(cframe: CFrame, size: Vector3): (number, number)
	local right = cframe.RightVector
	local look = cframe.LookVector
	local halfX = math.abs(right.X) * size.X / 2 + math.abs(look.X) * size.Z / 2
	local halfZ = math.abs(right.Z) * size.X / 2 + math.abs(look.Z) * size.Z / 2
	return halfX, halfZ
end

local function footprintExtents(pad: BlueprintLayoutConfig.BlueprintPad, buildingId: string?): (number, number)
	return orientedExtents(BlueprintLayoutConfig.GetStructureLocalCFrame(pad, buildingId), BlueprintLayoutConfig.GetFootprintSize(pad, buildingId))
end

local function isInsideLegalBounds(cframe: CFrame, size: Vector3): boolean
	local halfX, halfZ = orientedExtents(cframe, size)
	return math.abs(cframe.Position.X) + halfX <= PersonalBaseConfig.PlotBounds.HalfWidth + BOUNDS_TOLERANCE
		and math.abs(cframe.Position.Z) + halfZ <= PersonalBaseConfig.PlotBounds.HalfDepth + BOUNDS_TOLERANCE
end

local function matchesOuterFace(group: string, cframe: CFrame, halfX: number, halfZ: number): boolean
	if group == "Front" or group == "Gate" then
		return math.abs((cframe.Position.Z - halfZ) + PersonalBaseConfig.PlotBounds.HalfDepth) <= BOUNDS_TOLERANCE
	elseif group == "Back" then
		return math.abs((cframe.Position.Z + halfZ) - PersonalBaseConfig.PlotBounds.HalfDepth) <= BOUNDS_TOLERANCE
	elseif group == "Left" then
		return math.abs((cframe.Position.X - halfX) + PersonalBaseConfig.PlotBounds.HalfWidth) <= BOUNDS_TOLERANCE
	elseif group == "Right" then
		return math.abs((cframe.Position.X + halfX) - PersonalBaseConfig.PlotBounds.HalfWidth) <= BOUNDS_TOLERANCE
	end
	return true
end

local function horizontalUnit(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z).Unit
end

local function footprintsOverlap(a: BlueprintLayoutConfig.BlueprintPad, b: BlueprintLayoutConfig.BlueprintPad): boolean
	local aSize = BlueprintLayoutConfig.GetFootprintSize(a)
	local bSize = BlueprintLayoutConfig.GetFootprintSize(b)
	local aRight, aLook = horizontalUnit(a.LocalCFrame.RightVector), horizontalUnit(a.LocalCFrame.LookVector)
	local bRight, bLook = horizontalUnit(b.LocalCFrame.RightVector), horizontalUnit(b.LocalCFrame.LookVector)
	local delta = Vector3.new(b.LocalCFrame.Position.X - a.LocalCFrame.Position.X, 0, b.LocalCFrame.Position.Z - a.LocalCFrame.Position.Z)
	for _, axis in { aRight, aLook, bRight, bLook } do
		local distance = math.abs(delta:Dot(axis))
		local aRadius = math.abs(aRight:Dot(axis)) * aSize.X / 2 + math.abs(aLook:Dot(axis)) * aSize.Z / 2
		local bRadius = math.abs(bRight:Dot(axis)) * bSize.X / 2 + math.abs(bLook:Dot(axis)) * bSize.Z / 2
		if distance >= aRadius + bRadius - 0.01 then
			return false
		end
	end
	return true
end

local function horizontalDistance(a: Vector3, b: Vector3): number
	return (Vector3.new(a.X, 0, a.Z) - Vector3.new(b.X, 0, b.Z)).Magnitude
end

local function required(parent: Instance, name: string): Instance
	local instance = parent:FindFirstChild(name, true)
	assert(instance, `ValidatePersonalBaseLayout: missing {name}`)
	return instance
end

function ValidatePersonalBaseLayout.Run(baseModel: Model?): ValidationReport
	local report: ValidationReport = {
		Passed = true,
		Checks = 0,
		Errors = {},
		Measurements = {},
		RuntimeChecksSkipped = baseModel == nil,
	}

	local padIds: { [string]: boolean } = {}
	local districtCounts: { [string]: number } = {}
	local perimeterCount = 0
	local minimumInteriorClearance = math.huge
	local minimumForestBuffer = math.huge
	local defenseGroups: { [string]: number } = {}
	for index, pad in BlueprintLayoutConfig.All do
		check(report, not padIds[pad.PadId], `Duplicate blueprint PadId: {pad.PadId}`)
		padIds[pad.PadId] = true
		districtCounts[pad.District] = (districtCounts[pad.District] or 0) + 1
		if pad.District == "Perimeter" then
			perimeterCount += 1
		end
		if pad.DefenseGroup then
			defenseGroups[pad.DefenseGroup] = (defenseGroups[pad.DefenseGroup] or 0) + 1
		end
		check(report, BuildingConfig.Get(pad.BuildingId) ~= nil, `{pad.PadId} references a real building`)
		local padCFrame = BlueprintLayoutConfig.GetStructureLocalCFrame(pad)
		local padFootprint = BlueprintLayoutConfig.GetFootprintSize(pad)
		local halfX, halfZ = footprintExtents(pad)
		check(
			report,
			isInsideLegalBounds(padCFrame, padFootprint),
			`{pad.PadId} footprint stays inside the legal Base bounds`
		)
		local forestBufferX = PersonalBaseConfig.ForestInnerHalfWidth - (math.abs(padCFrame.Position.X) + halfX)
		local forestBufferZ = PersonalBaseConfig.ForestInnerHalfDepth - (math.abs(padCFrame.Position.Z) + halfZ)
		minimumForestBuffer = math.min(minimumForestBuffer, forestBufferX, forestBufferZ)
		if pad.AllowedBuildingIds then
			for _, buildingId in pad.AllowedBuildingIds do
				local tierCFrame = BlueprintLayoutConfig.GetStructureLocalCFrame(pad, buildingId)
				local tierFootprint = BlueprintLayoutConfig.GetFootprintSize(pad, buildingId)
				local tierHalfX, tierHalfZ = footprintExtents(pad, buildingId)
				check(report, isInsideLegalBounds(tierCFrame, tierFootprint), `{pad.PadId} keeps {buildingId} inside the max base range`)
				if pad.DefenseGroup then
					check(report, matchesOuterFace(pad.DefenseGroup, tierCFrame, tierHalfX, tierHalfZ), `{pad.PadId} keeps the {buildingId} outer face exactly on the legal boundary`)
				end

				local cornerDirection = if pad.PadId == "Wall_0" or pad.PadId == "Wall_3"
					then -1
					elseif pad.PadId == "Wall_1" or pad.PadId == "Wall_2" then 1
					else 0
				if cornerDirection ~= 0 then
					local cornerWidth = BuildingConfig.GetFootprintSize("Wall").Z
					local cornerSize = Vector3.new(cornerWidth, tierFootprint.Y, tierFootprint.Z)
					local cornerCFrame = tierCFrame * CFrame.new(cornerDirection * (tierFootprint.X / 2 + cornerWidth / 2), 0, 0)
					check(report, isInsideLegalBounds(cornerCFrame, cornerSize), `{pad.PadId} keeps the {buildingId} corner cap inside the max base range`)
				end
			end
		end
		for otherIndex = index + 1, #BlueprintLayoutConfig.All do
			local other = BlueprintLayoutConfig.All[otherIndex]
			check(report, not footprintsOverlap(pad, other), `{pad.PadId} overlaps {other.PadId}`)
			if pad.District ~= "Perimeter" and other.District ~= "Perimeter" then
				local clearance = horizontalDistance(pad.LocalCFrame.Position, other.LocalCFrame.Position)
					- footprintRadius(pad)
					- footprintRadius(other)
				minimumInteriorClearance = math.min(minimumInteriorClearance, clearance)
			end
		end
	end

	report.Measurements.BlueprintPadCount = #BlueprintLayoutConfig.All
	report.Measurements.MinimumInteriorPadClearance = minimumInteriorClearance
	report.Measurements.MinimumForestBuffer = minimumForestBuffer
	report.Measurements.ExpandableWidth = PersonalBaseConfig.FreeformZone.MaxX - PersonalBaseConfig.FreeformZone.MinX
	report.Measurements.ExpandableDepth = PersonalBaseConfig.FreeformZone.MaxZ - PersonalBaseConfig.FreeformZone.MinZ
	check(report, #BlueprintLayoutConfig.All == 15, "Base keeps seven guided structure pads plus eight defensive wall pads")
	check(report, districtCounts.Entrance == 1 and districtCounts.Logistics == 2 and districtCounts.Production == 2 and districtCounts.Support == 2, "Seven starter lots branch across entrance/logistics/production/support")
	check(report, perimeterCount == 8, "Defensive perimeter keeps exactly eight wall build slots")
	check(report, minimumInteriorClearance >= 8, "Interior building footprints retain at least eight studs of clear spacing")
	check(report, defenseGroups.Front == 2 and defenseGroups.Back == 2 and defenseGroups.Left == 2 and defenseGroups.Right == 2 and defenseGroups.Gate == 1, "Perimeter sockets cover four sides plus one south gate")
	check(report, math.abs(minimumForestBuffer - 55) < 0.01, "Wall and gate exterior faces sit on the true max-range edge with fifty-five studs to the first tree centers")
	check(report, minimumForestBuffer >= 50, "Eventual perimeter keeps at least fifty studs of patrol ground before dense forest")
	check(report, report.Measurements.ExpandableWidth >= 220 and report.Measurements.ExpandableDepth >= 160, "Inner settlement preserves a large future co-op/freeform build region")
	check(report, PersonalBaseConfig.ForestInnerHalfWidth - PersonalBaseConfig.SettlementWidth / 2 >= 40 and PersonalBaseConfig.ForestInnerHalfDepth - PersonalBaseConfig.SettlementDepth / 2 >= 40, "Forest never enters the buildable settlement rectangle")
	check(report, PersonalBaseConfig.ForestOuterHalfWidth - PersonalBaseConfig.ForestInnerHalfWidth >= 50 and PersonalBaseConfig.ForestOuterHalfDepth - PersonalBaseConfig.ForestInnerHalfDepth >= 50, "Forest belt is at least fifty studs deep on every side")

	if not baseModel then
		return report
	end

	check(report, baseModel:GetAttribute("BaseLayoutVersion") == 6, "Runtime Base uses definitive layout version 6")
	check(report, baseModel:GetAttribute("CoopReady") == true, "Runtime Base declares co-op-ready spacing")
	check(report, baseModel:GetAttribute("WorldShape") == "Rectangle", "Personal Base world declares a rectangular layout")
	check(report, baseModel:GetAttribute("WorldWidth") == 480 and baseModel:GetAttribute("WorldDepth") == 410, "Outer Base world measures 480 by 410 studs")
	check(report, baseModel:GetAttribute("SettlementWidth") == 240 and baseModel:GetAttribute("SettlementDepth") == 180, "Inner settlement measures 240 by 180 studs")
	check(report, (baseModel:GetAttribute("SettlementToForestBufferX") :: number) >= 55 and (baseModel:GetAttribute("SettlementToForestBufferZ") :: number) >= 55, "Runtime Base exposes a visible fifty-five stud patrol buffer")
	local ground = required(baseModel, "SettlementGround")
	local forest = required(baseModel, "HostileForestPerimeter")
	check(report, ground:GetAttribute("StableSurfaceLayers") == true, "Base ground declares stable non-coplanar layers")
	local groundFloor = required(ground, "Ground") :: BasePart
	local settlementField = required(ground, "SettlementField") :: BasePart
	local patrolGround = required(ground, "OuterPatrolGround") :: BasePart
	check(report, groundFloor:IsA("BasePart") and groundFloor.Size.X == 480 and groundFloor.Size.Z == 410, "Forest floor hides the void across the full 480 by 410 world")
	check(report, settlementField:IsA("BasePart") and settlementField.Size.X == 240 and settlementField.Size.Z == 180, "Settlement uses one centered rectangular 240 by 180 field")
	check(report, patrolGround:IsA("BasePart") and patrolGround.Size.X == 350 and patrolGround.Size.Z == 290, "Outer patrol ground visibly separates settlement and forest")
	for _, routeName in { "SouthGateTrail", "CoreApproach", "CoreNorthSpur", "WestProductionLane", "EastSupportLane", "CorePlaza" } do
		local route = required(ground, routeName)
		check(report, route:IsA("BasePart"), `{routeName} exists`)
		if route:IsA("BasePart") then
			local walkingWidth = if routeName == "CorePlaza" then math.min(route.Size.Y, route.Size.Z) else math.min(route.Size.X, route.Size.Z)
			check(report, walkingWidth >= 8, `{routeName} preserves at least eight studs of co-op walking width`)
		end
	end
	check(report, ground:FindFirstChild("SharedBuildYard") == nil, "Old shared-yard slab is absent")
	check(report, forest:GetAttribute("PerimeterShape") == "Rectangle", "Hostile forest follows a rectangle rather than a loose circular ring")
	local treeCount = forest:GetAttribute("LargeTreeCount") :: number
	check(report, treeCount == 280, "Hostile forest uses the mobile-conscious 280-tree target")
	check(report, forest:GetAttribute("ForestInnerHalfWidth") == 175 and forest:GetAttribute("ForestInnerHalfDepth") == 145, "Dense forest begins beyond the patrol buffer")
	check(report, forest:GetAttribute("ForestOuterHalfWidth") == 235 and forest:GetAttribute("ForestOuterHalfDepth") == 200, "Dense forest reaches the outer world edges")

	local pads = required(baseModel, "BlueprintPads")
	for _, ghost in pads:GetChildren() do
		if ghost:IsA("Model") then
			local anchor = ghost:FindFirstChild("ConstructionBeacon")
			check(report, anchor ~= nil and anchor:IsA("BasePart") and CollectionService:HasTag(anchor, "BaseBlueprintPad") and anchor:GetAttribute("ConstructionBeacon") == true, `{ghost.Name} uses one compact tagged construction beacon`)
			check(report, ghost:FindFirstChild("PurchasePad") ~= nil and ghost:FindFirstChild("PurchasePadTrim") ~= nil, `{ghost.Name} uses a compact circular tycoon node instead of a full-footprint floor lot`)
			local labelGui = ghost:FindFirstChild("ConstructionLabel", true)
			check(report, labelGui ~= nil and labelGui:IsA("BillboardGui") and labelGui.MaxDistance <= 25 and labelGui.Enabled == false, `{ghost.Name} label is proximity-limited and client-selective`)
			check(report, ghost:GetAttribute("ConstructionLot") == true, `{ghost.Name} declares the construction-lot contract`)
			check(report, typeof(ghost:GetAttribute("FutureWorldCFrame")) == "CFrame", `{ghost.Name} preserves the exact future structure transform for its local preview`)
		end
	end
	check(report, baseModel:FindFirstChild("ZoneLabel", true) == nil, "Base has no permanent zone-instruction billboards")

	local core = required(baseModel, "CivilizationCore")
	check(report, core:FindFirstChild("OuterRing", true) == nil, "Civilization Core has no filled ForceField glow disc")
	check(report, baseModel:FindFirstChild("MarketplaceAccessTerminal", true) == nil and baseModel:FindFirstChild("Mailbox (Coming Soon)", true) == nil, "Base contains no irrelevant marketplace or coming-soon placeholder noise")

	local destination = required(baseModel, string.match(baseModel.Name, "^%d+$") and `PersonalBase_{baseModel.Name}` or "PersonalBase")
	local platform = required(destination, "ArrivalPlatform") :: BasePart
	local rim = required(destination, "ArrivalPlatformRim") :: BasePart
	check(report, platform.Size == Vector3.new(1, 28, 28), "Personal Base arrival platform uses a compact readable landing disc")
	check(report, rim.Material ~= Enum.Material.Neon and rim:FindFirstChildOfClass("PointLight") == nil, "Personal Base arrival has no oversized neon disc or bloom light")
	local anchor = required(destination, "Arrival_PersonalBase") :: BasePart
	local coreDirection = Vector3.new(PersonalBaseConfig.CoreLocalPosition.X, 0, PersonalBaseConfig.CoreLocalPosition.Z).Unit
	local anchorDirection = Vector3.new(anchor.CFrame.LookVector.X, 0, anchor.CFrame.LookVector.Z).Unit
	check(report, anchorDirection:Dot(coreDirection) > 0.99, "Players arrive facing the Civilization Core")
	local returnPortal = required(destination, "ReturnPortalMembrane") :: BasePart
	local returnFrame = required(destination, "ReturnPortalFrame") :: BasePart
	local returnApron = required(destination, "ReturnPortalApron") :: BasePart
	local returnPrompt = returnPortal:FindFirstChild("ReturnPrompt")
	local returnOffset = returnPortal.Position - platform.Position
	local horizontalReturnDistance = Vector3.new(returnOffset.X, 0, returnOffset.Z).Magnitude
	check(report, destination:GetAttribute("BaseReturnPortalLandmark") == true, "Base return portal declares its landmark treatment")
	check(report, horizontalReturnDistance >= 20 and horizontalReturnDistance <= 30, "Return portal sits close to arrival without crowding the spawn platform")
	check(report, CollectionService:HasTag(returnPortal, "ReturnPortal") and typeof(returnPortal:GetAttribute("PortalId")) == "string", "Return portal preserves the shared travel contract")
	check(report, returnFrame.Transparency == 0 and returnFrame:FindFirstChild("ReturnToHubSign") ~= nil, "Return portal has a visible frame and readable hub sign")
	check(report, returnApron.Size.X >= 12 and returnApron.Size.Z >= 8, "Return portal has a clear approach apron")
	check(report, returnPrompt ~= nil and returnPrompt:IsA("ProximityPrompt") and returnPrompt.ObjectText == "SURVIVOR HAVEN" and returnPrompt.ActionText == "Return to Hub", "Return portal prompt clearly identifies its destination")

	for index = 0, 3 do
		local route = required(baseModel, `EclipseAttackRoute{index}`) :: BasePart
		local assaultSpawn = required(baseModel, `EclipseAssaultSpawn{index}`) :: BasePart
		check(report, route.Transparency == 1 and assaultSpawn.Transparency == 1, `Eclipse assault lane {index} preserves tags without visible neon noise`)
	end

	return report
end

return ValidatePersonalBaseLayout
