--!strict
-- Focused art pass for the authored Small Hangout tutorial map. It keeps the
-- spawn, Guide, bridges, workbench facility anchor, and resource contracts in
-- place while removing a few broken imported set pieces and replacing only the
-- pieces that benefit from clearer handcrafted silhouettes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldMapConfig = require(ReplicatedStorage.Shared.Config.WorldMapConfig)

local PolishTutorialZone = {}

local ROOT_NAME = "TutorialZone_Generated"
local ENVIRONMENT_NAME = "SmallHangout_Environment"
local POLISH_NAME = "TutorialPolish_Generated"
local WORKBENCH_VISUAL_NAME = "WorkbenchVisual_Generated"

local P = {
	Grass = Color3.fromRGB(73, 108, 69),
	Rock = Color3.fromRGB(72, 77, 76),
	Timber = Color3.fromRGB(105, 75, 48),
	TimberLight = Color3.fromRGB(132, 94, 58),
	TimberDark = Color3.fromRGB(69, 52, 38),
	MetalLight = Color3.fromRGB(116, 125, 123),
	MetalDark = Color3.fromRGB(45, 51, 52),
	Accent = Color3.fromRGB(202, 132, 61),
	Foliage = Color3.fromRGB(63, 94, 61),
	FoliageLight = Color3.fromRGB(76, 108, 69),
	Water = Color3.fromRGB(48, 78, 104),
}

local function newPart(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	material: Enum.Material,
	color: Color3,
	canCollide: boolean?
): Part
	local result = Instance.new("Part")
	result.Name = name
	result.Size = size
	result.CFrame = cframe
	result.Material = material
	result.Color = color
	result.Anchored = true
	result.CanCollide = if canCollide == nil then true else canCollide
	result.CanTouch = result.CanCollide
	result.CanQuery = result.CanCollide
	result.CastShadow = true
	result.TopSurface = Enum.SurfaceType.Smooth
	result.BottomSurface = Enum.SurfaceType.Smooth
	result.Parent = parent
	return result
end

local function beam(
	parent: Instance,
	name: string,
	a: Vector3,
	b: Vector3,
	thickness: number,
	material: Enum.Material,
	color: Color3,
	canCollide: boolean?
): Part
	local delta = b - a
	return newPart(
		parent,
		name,
		Vector3.new(thickness, thickness, delta.Magnitude),
		CFrame.lookAt(a + delta / 2, b),
		material,
		color,
		canCollide
	)
end

local function getSurfaceY(environment: Model): number
	local surfaceY = -math.huge
	for _, child in environment:GetChildren() do
		if child:IsA("BasePart")
			and child.Material == Enum.Material.Grass
			and child.Size.X >= 40
			and child.Size.Z >= 40
		then
			surfaceY = math.max(surfaceY, child.Position.Y + child.Size.Y / 2)
		end
	end
	assert(surfaceY > -math.huge, "PolishTutorialZone: authored main grass surface is missing")
	return surfaceY
end

local function tuneAuthoredMaterials(environment: Model)
	for _, child in environment:GetChildren() do
		if child:IsA("BasePart") then
			if child.Name == "Water" then
				child.Material = Enum.Material.Glass
				child.Color = P.Water
				child.Transparency = 0.24
				child.Reflectance = 0.03
				child.CanCollide = false
			elseif child.Material == Enum.Material.Grass then
				-- The source place mixes several saturated stock greens. Keep every
				-- authored piece, but pull terrain plates and foliage into one range.
				if child.Size.X >= 40 and child.Size.Z >= 40 then
					child.Color = P.Grass
				elseif child:IsA("MeshPart") or child.Size.Y > 2 then
					child.Color = P.FoliageLight
				else
					child.Color = Color3.fromRGB(62, 96, 60)
				end
			elseif child.Material == Enum.Material.Slate and child.Size.Y >= 3 then
				child.Color = P.Rock
			end
		end
	end
	for _, descendant in environment:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Material == Enum.Material.Wood then
			descendant.Color = if descendant.Size.Y >= 6 then P.TimberDark else P.Timber
		end
	end
end

local function varyExistingTrees(root: Model, environment: Model)
	if root:GetAttribute("TutorialTreeVariationVersion") == 2 then
		return
	end
	local trees = {}
	for _, child in environment:GetChildren() do
		if child:IsA("Model") then
			local _, size = child:GetBoundingBox()
			local meshCount = 0
			for _, descendant in child:GetDescendants() do
				if descendant:IsA("MeshPart") then
					meshCount += 1
				end
			end
			if meshCount >= 5 and size.Y >= 16 and size.X <= 16 and size.Z <= 16 then
				table.insert(trees, child)
			end
		end
	end
	table.sort(trees, function(a: Model, b: Model): boolean
		local aBox = a:GetBoundingBox()
		local bBox = b:GetBoundingBox()
		local aPosition = aBox.Position
		local bPosition = bBox.Position
		return aPosition.X == bPosition.X and aPosition.Z < bPosition.Z or aPosition.X < bPosition.X
	end)
	local scales = { 0.94, 1.05, 0.98, 1.07, 0.92, 1.02 }
	local yaws = { -11, 8, 17, -7, 13, -16 }
	for index, tree in trees do
		-- The imported Models carry stale WorldPivots. Transform each visible
		-- descendant around the real bounding-box base so trunks stay planted.
		local box, boxSize = tree:GetBoundingBox()
		local base = CFrame.new(box.Position.X, box.Position.Y - boxSize.Y / 2, box.Position.Z)
		local scale = scales[(index - 1) % #scales + 1]
		local yaw = CFrame.Angles(0, math.rad(yaws[(index - 1) % #yaws + 1]), 0)
		for _, descendant in tree:GetDescendants() do
			if descendant:IsA("BasePart") then
				local localCFrame = base:ToObjectSpace(descendant.CFrame)
				descendant.Size *= scale
				descendant.CFrame = base
					* yaw
					* CFrame.new(localCFrame.Position * scale)
					* localCFrame.Rotation
				if string.find(string.lower(descendant.Name), "leaf") then
					descendant.Material = Enum.Material.LeafyGrass
					descendant.Color = if index % 2 == 0 then P.FoliageLight else P.Foliage
				elseif descendant.Material == Enum.Material.Wood then
					descendant.Color = if index % 3 == 0 then P.TimberLight else P.Timber
				end
			end
		end
	end
	root:SetAttribute("TutorialTreeVariationApplied", true)
	root:SetAttribute("TutorialTreeVariationVersion", 2)
	root:SetAttribute("TutorialTreeCount", #trees)
end

local function removeOversizedImportedSign(root: Model, environment: Model)
	local importedSign = environment:FindFirstChild("Meshes/uploads_files_818717_wooden_sign")
	if importedSign then
		importedSign:Destroy()
	end
	root:SetAttribute("OversizedImportedSignRemoved", true)
end

local function flattenRaisedCamp(root: Model, environment: Model, origin: CFrame, surfaceY: number)
	if root:GetAttribute("TutorialCampDaisFlattened") == true then
		return
	end

	local expectedCenter = origin:PointToWorldSpace(Vector3.new(9.7, 0, 45.66))
	local pillar: BasePart? = nil
	local cap: BasePart? = nil
	local campModel: Model? = nil
	for _, child in environment:GetChildren() do
		if child:IsA("BasePart")
			and (Vector2.new(child.Position.X, child.Position.Z) - Vector2.new(expectedCenter.X, expectedCenter.Z)).Magnitude < 1
			and math.abs(child.Size.X - 9.65) < 0.25
			and math.abs(child.Size.Z - 9.65) < 0.25
		then
			if child.Material == Enum.Material.Slate and child.Size.Y > 8 then
				pillar = child
			elseif child.Material == Enum.Material.Grass and child.Size.Y < 1 then
				cap = child
			end
		elseif child:IsA("Model") then
			local box, boxSize = child:GetBoundingBox()
			if (Vector2.new(box.Position.X, box.Position.Z) - Vector2.new(expectedCenter.X, expectedCenter.Z)).Magnitude < 3
				and boxSize.Y >= 7
				and boxSize.Y <= 11
				and child:FindFirstChildWhichIsA("PointLight", true)
			then
				campModel = child
			end
		end
	end
	assert(pillar and cap and campModel, "PolishTutorialZone: raised authored camp dais is incomplete")

	local raisedSurfaceY = cap.Position.Y + cap.Size.Y / 2
	local inwardOffset = Vector3.new(2.4, surfaceY - raisedSurfaceY, -3.2)
	for _, descendant in campModel:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CFrame += inwardOffset
		end
	end
	pillar:Destroy()
	cap:Destroy()
	root:SetAttribute("TutorialCampDaisFlattened", true)
	root:SetAttribute("TutorialCampMovedInward", true)
end

local function tuneImportedFire(root: Model, environment: Model)
	local guideAnchor = root:FindFirstChild("QuestGiverAnchor")
	if root:GetAttribute("TutorialTorchCleanupApplied") ~= true then
		local torches = {}
		for _, child in environment:GetChildren() do
			if child:IsA("Model") and child.Name == "Torch" then
				table.insert(torches, child)
			end
		end
		if guideAnchor and guideAnchor:IsA("BasePart") and #torches > 1 then
			table.sort(torches, function(a: Model, b: Model): boolean
				local aBox = a:GetBoundingBox()
				local bBox = b:GetBoundingBox()
				return (aBox.Position - guideAnchor.Position).Magnitude < (bBox.Position - guideAnchor.Position).Magnitude
			end)
			torches[1]:Destroy()
			table.remove(torches, 1)
		end

		for _, torch in torches do
			local box, boxSize = torch:GetBoundingBox()
			local bottomY = box.Position.Y - boxSize.Y / 2
			for _, descendant in torch:GetDescendants() do
				if descendant:IsA("BasePart") then
					local position = descendant.Position
					descendant.Size = Vector3.new(descendant.Size.X * 0.88, descendant.Size.Y * 0.78, descendant.Size.Z * 0.88)
					descendant.CFrame = CFrame.new(position.X, bottomY + (position.Y - bottomY) * 0.78, position.Z)
						* descendant.CFrame.Rotation
					descendant.CanCollide = false
					descendant.CanTouch = false
					descendant.CanQuery = false
				end
			end
		end
		root:SetAttribute("TutorialTorchCleanupApplied", true)
	end

	for _, descendant in environment:GetDescendants() do
		if descendant:IsA("PointLight") then
			local inTorch = descendant:FindFirstAncestor("Torch") ~= nil
			descendant.Color = Color3.fromRGB(255, 166, 102)
			descendant.Brightness = if inTorch then 1.15 else 1.55
			descendant.Range = if inTorch then 10 else 12
			descendant.Shadows = false
		elseif descendant:IsA("ParticleEmitter") and descendant.Name == "Fire" then
			descendant.Texture = "rbxasset://textures/particles/fire_main.dds"
			descendant.Color = ColorSequence.new(Color3.fromRGB(255, 193, 111), Color3.fromRGB(206, 92, 45))
			descendant.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.32),
				NumberSequenceKeypoint.new(0.45, 0.78),
				NumberSequenceKeypoint.new(1, 0),
			})
			descendant.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.08),
				NumberSequenceKeypoint.new(0.7, 0.18),
				NumberSequenceKeypoint.new(1, 1),
			})
			descendant.Lifetime = NumberRange.new(0.35, 0.7)
			descendant.Rate = 7
			descendant.Speed = NumberRange.new(1.4, 2.2)
			descendant.Drag = 1.5
			descendant.SpreadAngle = Vector2.new(8, 8)
			descendant.LightEmission = 0.65
		end
	end
end

local function buildBridgeRails(parent: Instance, origin: CFrame)
	local rails = Instance.new("Model")
	rails.Name = "BridgeRails_Generated"
	local bridges = {
		{ index = 2, x = 37.6, z = 56.1, halfWidth = 4.2, halfLength = 8.3, deckY = -1.27 },
	}
	for _, bridgeDefinition in bridges do
		local bridgeIndex = bridgeDefinition.index
		for _, side in { -1, 1 } do
			local x = bridgeDefinition.x + side * bridgeDefinition.halfWidth
			local startPosition = origin:PointToWorldSpace(Vector3.new(x, bridgeDefinition.deckY, bridgeDefinition.z - bridgeDefinition.halfLength))
			local endPosition = origin:PointToWorldSpace(Vector3.new(x, bridgeDefinition.deckY, bridgeDefinition.z + bridgeDefinition.halfLength))
			for postIndex, postPosition in { startPosition, endPosition } do
				newPart(
					rails,
					`Bridge{bridgeIndex}Post{side}_{postIndex}`,
					Vector3.new(0.48, 3.4, 0.48),
					origin
						* CFrame.new(x, bridgeDefinition.deckY + 1.65, bridgeDefinition.z + (if postIndex == 1 then -bridgeDefinition.halfLength else bridgeDefinition.halfLength))
						* CFrame.Angles(0, 0, math.rad(side * (postIndex == 1 and 3 or -3))),
					Enum.Material.Wood,
					P.TimberDark,
					false
				)
			end
			local ropeStart = startPosition + Vector3.new(0, 2.65, 0)
			local ropeEnd = endPosition + Vector3.new(0, 2.65, 0)
			local ropeMiddle = (startPosition + endPosition) / 2 + Vector3.new(0, 1.95, 0)
			beam(
				rails,
				`Bridge{bridgeIndex}Rope{side}A`,
				ropeStart,
				ropeMiddle,
				0.16,
				Enum.Material.Fabric,
				Color3.fromRGB(132, 111, 78),
				false
			)
			beam(rails, `Bridge{bridgeIndex}Rope{side}B`, ropeMiddle, ropeEnd, 0.16, Enum.Material.Fabric, Color3.fromRGB(132, 111, 78), false)
		end
	end
	rails.Parent = parent
end

local function buildGuideMarker(parent: Instance, root: Model, surfaceY: number)
	local spawn = root:FindFirstChild("TutorialSpawn")
	local guide = root:FindFirstChild("Guide")
	if not (spawn and spawn:IsA("BasePart") and guide and guide:IsA("Model")) then
		return
	end
	local guideBox = guide:GetBoundingBox()
	local direction = Vector3.new(guideBox.Position.X - spawn.Position.X, 0, guideBox.Position.Z - spawn.Position.Z)
	if direction.Magnitude < 0.01 then
		return
	end
	local away = direction.Unit
	local side = Vector3.new(-away.Z, 0, away.X)
	-- Compose against the visible character rather than its deliberately offset
	-- interaction anchor. A full sign-width of separation keeps the Guide's
	-- silhouette clear from the spawn approach.
	local center = Vector3.new(guideBox.Position.X, surfaceY, guideBox.Position.Z) - side * 4.8
	local frame = CFrame.lookAt(center, Vector3.new(spawn.Position.X, surfaceY, spawn.Position.Z))
	local marker = Instance.new("Model")
	marker.Name = "GuideMarker_Generated"
	newPart(marker, "GuideSignPost", Vector3.new(0.48, 3.8, 0.48), frame * CFrame.new(0, 1.9, 0.18), Enum.Material.Wood, P.TimberDark, false)
	local board = newPart(marker, "GuideSignBoard", Vector3.new(4.9, 1.5, 0.28), frame * CFrame.new(0, 3.25, 0), Enum.Material.WoodPlanks, P.Timber, false)

	local surface = Instance.new("SurfaceGui")
	surface.Name = "GuideSignSurface"
	surface.Face = Enum.NormalId.Front
	surface.CanvasSize = Vector2.new(640, 190)
	surface.LightInfluence = 0
	surface.MaxDistance = 42
	surface.Parent = board
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromScale(0.04, 0.08)
	title.Size = UDim2.fromScale(0.92, 0.55)
	title.Font = Enum.Font.GothamBold
	title.Text = "SURVIVOR GUIDE"
	title.TextColor3 = Color3.fromRGB(247, 232, 199)
	title.TextScaled = true
	title.Parent = surface
	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.BackgroundTransparency = 1
	subtitle.Position = UDim2.fromScale(0.04, 0.62)
	subtitle.Size = UDim2.fromScale(0.92, 0.26)
	subtitle.Font = Enum.Font.GothamBold
	subtitle.Text = "START HERE"
	subtitle.TextColor3 = P.Accent
	subtitle.TextScaled = true
	subtitle.Parent = surface

	beam(marker, "LanternBracket", frame:PointToWorldSpace(Vector3.new(2.1, 2.95, 0)), frame:PointToWorldSpace(Vector3.new(2.1, 2.45, -0.52)), 0.16, Enum.Material.Metal, P.MetalDark, false)
	newPart(marker, "GuideLanternHousing", Vector3.new(0.62, 0.78, 0.58), frame * CFrame.new(2.1, 2.23, -0.55), Enum.Material.Metal, P.MetalDark, false)
	local lantern = newPart(marker, "GuideLanternGlow", Vector3.new(0.34, 0.46, 0.34), frame * CFrame.new(2.1, 2.23, -0.86), Enum.Material.Neon, Color3.fromRGB(226, 151, 76), false)
	lantern.CastShadow = false
	local light = Instance.new("PointLight")
	light.Name = "GuideWarmLight"
	light.Color = Color3.fromRGB(255, 184, 109)
	light.Brightness = 0.38
	light.Range = 8
	light.Shadows = false
	light.Parent = lantern
	marker:SetAttribute("Purpose", "ReadableGuideLandmark")
	marker.Parent = parent
end

local function buildWorkbench(root: Model)
	local workbench = root:FindFirstChild("TutorialWorkbench")
	if not (workbench and workbench:IsA("Model")) then
		return
	end
	local legacyBench = workbench:FindFirstChild("Workbench")
	local legacyRack = workbench:FindFirstChild("ToolRack")
	if not (legacyBench and legacyBench:IsA("BasePart")) then
		return
	end
	local oldVisual = workbench:FindFirstChild(WORKBENCH_VISUAL_NAME)
	if oldVisual then
		oldVisual:Destroy()
	end
	for _, legacy in { legacyBench, legacyRack } do
		if legacy and legacy:IsA("BasePart") then
			legacy.Transparency = 1
			legacy.CanCollide = false
			legacy.CanTouch = false
			legacy.CanQuery = false
			legacy.CastShadow = false
		end
	end

	local frame = legacyBench.CFrame * CFrame.new(0, -legacyBench.Size.Y / 2, 0)
	local visual = Instance.new("Model")
	visual.Name = WORKBENCH_VISUAL_NAME

	-- Keep the old 8x3x3 gameplay envelope exactly, but separate it from the
	-- new thin visual pieces so trestles and mechanisms cannot snag a player.
	local collision = newPart(
		visual,
		"WorkbenchCollision",
		legacyBench.Size,
		legacyBench.CFrame,
		Enum.Material.SmoothPlastic,
		Color3.new(),
		true
	)
	collision.Transparency = 1
	collision.CastShadow = false
	collision.CanTouch = false
	collision.CanQuery = false

	-- Broad A-frame trestles and negative space replace the featureless chest.
	for _, x in { -2.8, 2.8 } do
		beam(visual, "TrestleLeg", frame:PointToWorldSpace(Vector3.new(x, 0, -1.22)), frame:PointToWorldSpace(Vector3.new(x, 2.68, -0.68)), 0.56, Enum.Material.Wood, P.TimberDark, false)
		beam(visual, "TrestleLeg", frame:PointToWorldSpace(Vector3.new(x, 0, 1.22)), frame:PointToWorldSpace(Vector3.new(x, 2.68, 0.68)), 0.56, Enum.Material.Wood, P.TimberDark, false)
	end
	beam(visual, "WorkbenchStretcher", frame:PointToWorldSpace(Vector3.new(-2.9, 0.68, 0.12)), frame:PointToWorldSpace(Vector3.new(2.9, 0.68, 0.12)), 0.42, Enum.Material.Wood, P.Timber, false)
	beam(visual, "RearDiagonalBrace", frame:PointToWorldSpace(Vector3.new(-2.85, 0.65, 0.88)), frame:PointToWorldSpace(Vector3.new(2.75, 2.28, 0.88)), 0.24, Enum.Material.CorrodedMetal, P.MetalDark, false)
	newPart(visual, "LowerShelf", Vector3.new(5.7, 0.32, 1.9), frame * CFrame.new(0, 1.08, 0), Enum.Material.WoodPlanks, Color3.fromRGB(92, 66, 44), false)
	for index, z in { -1.05, 0, 1.05 } do
		newPart(
			visual,
			`WorkbenchPlank{index}`,
			Vector3.new(if index == 2 then 7.45 else 7.75, if index == 2 then 0.44 else 0.4, if index == 2 then 0.96 else 0.92),
			frame * CFrame.new((index - 2) * 0.12, if index == 2 then 2.83 else 2.8, z) * CFrame.Angles(0, math.rad(({ 1.5, -1, 0.8 })[index]), 0),
			Enum.Material.WoodPlanks,
			if index == 2 then P.TimberLight else P.Timber,
			false
		)
	end

	-- An open asymmetric rack gives the station height without a detached roof.
	beam(visual, "ToolWallPostLeft", frame:PointToWorldSpace(Vector3.new(-3.2, 2.86, 0.82)), frame:PointToWorldSpace(Vector3.new(-3.02, 5.55, 0.82)), 0.4, Enum.Material.Wood, P.TimberDark, false)
	beam(visual, "ToolWallPostRight", frame:PointToWorldSpace(Vector3.new(3.15, 2.86, 0.82)), frame:PointToWorldSpace(Vector3.new(2.94, 5.15, 0.82)), 0.4, Enum.Material.Wood, P.TimberDark, false)
	beam(visual, "ToolWallCrossrail", frame:PointToWorldSpace(Vector3.new(-3.02, 5.55, 0.82)), frame:PointToWorldSpace(Vector3.new(2.94, 5.15, 0.82)), 0.34, Enum.Material.Wood, P.Timber, false)

	-- One hero grindstone and one in-progress hatchet communicate crafting more
	-- clearly than a repeated row of rectangular tools.
	local wheel = newPart(visual, "GrindingWheel", Vector3.new(0.3, 1.65, 1.65), frame * CFrame.new(2.25, 3.72, 0.05) * CFrame.Angles(0, math.rad(90), 0), Enum.Material.Slate, Color3.fromRGB(82, 86, 83), false)
	wheel.Shape = Enum.PartType.Cylinder
	local axle = newPart(visual, "GrindingWheelAxle", Vector3.new(0.42, 0.46, 0.46), frame * CFrame.new(2.25, 3.72, 0.05) * CFrame.Angles(0, math.rad(90), 0), Enum.Material.Metal, P.MetalDark, false)
	axle.Shape = Enum.PartType.Cylinder
	for _, x in { 1.48, 3.02 } do
		beam(visual, "GrindingWheelSupport", frame:PointToWorldSpace(Vector3.new(x, 2.98, 0.08)), frame:PointToWorldSpace(Vector3.new(2.25, 3.72, 0.05)), 0.22, Enum.Material.Metal, P.MetalDark, false)
	end
	newPart(visual, "HatchetHandle", Vector3.new(0.2, 1.75, 0.2), frame * CFrame.new(-1.35, 3.68, -0.15) * CFrame.Angles(0, 0, math.rad(-62)), Enum.Material.Wood, P.TimberLight, false)
	local hatchetHead = Instance.new("WedgePart")
	hatchetHead.Name = "HatchetHead"
	hatchetHead.Size = Vector3.new(0.35, 0.8, 0.75)
	hatchetHead.CFrame = frame * CFrame.new(-0.62, 4.03, -0.15) * CFrame.Angles(0, math.rad(90), math.rad(28))
	hatchetHead.Material = Enum.Material.Metal
	hatchetHead.Color = P.MetalLight
	hatchetHead.Anchored = true
	hatchetHead.CanCollide = false
	hatchetHead.CanTouch = false
	hatchetHead.CanQuery = false
	hatchetHead.Parent = visual
	beam(visual, "TaskLampBracket", frame:PointToWorldSpace(Vector3.new(2.92, 4.68, 0.78)), frame:PointToWorldSpace(Vector3.new(2.72, 4.62, 0.28)), 0.14, Enum.Material.Metal, P.MetalDark, false)
	newPart(visual, "TaskLampHousing", Vector3.new(0.58, 0.7, 0.5), frame * CFrame.new(2.7, 4.53, 0.05), Enum.Material.Metal, P.MetalDark, false)
	local taskGlow = newPart(visual, "TaskLampGlow", Vector3.new(0.3, 0.4, 0.12), frame * CFrame.new(2.7, 4.45, -0.23), Enum.Material.Neon, P.Accent, false)
	taskGlow.CastShadow = false

	local worldLabel = workbench:FindFirstChild("WorldLabel")
	if worldLabel and worldLabel:IsA("BasePart") then
		if workbench:GetAttribute("AppearanceVersion") ~= 3 then
			worldLabel.CFrame += Vector3.new(0, 0.72, 0)
		end
		worldLabel.Anchored = true
		worldLabel.CanCollide = false
		worldLabel.CanTouch = false
		worldLabel.CanQuery = false
		worldLabel:SetAttribute("ConfiguredWidth", worldLabel.Size.X)
		worldLabel:SetAttribute("ConfiguredHeight", worldLabel.Size.Y)
		worldLabel.Material = Enum.Material.WoodPlanks
		worldLabel.Color = P.TimberDark
	end
	visual:SetAttribute("Appearance", "HandBuiltTrestleGrindstone")
	visual.Parent = workbench
	workbench:SetAttribute("AppearanceVersion", 3)
end

function PolishTutorialZone.Run(rootOverride: Model?): Model
	local root = rootOverride or workspace:FindFirstChild(ROOT_NAME)
	assert(root and root:IsA("Model"), `PolishTutorialZone: Workspace.{ROOT_NAME} is missing`)
	local environment = root:FindFirstChild(ENVIRONMENT_NAME)
	assert(environment and environment:IsA("Model"), `PolishTutorialZone: authored {ENVIRONMENT_NAME} is missing`)

	local previous = root:FindFirstChild(POLISH_NAME)
	if previous then
		previous:Destroy()
	end
	local polish = Instance.new("Model")
	polish.Name = POLISH_NAME
	local origin = WorldMapConfig.RealOrigin.Tutorial
	local surfaceY = getSurfaceY(environment)

	tuneAuthoredMaterials(environment)
	removeOversizedImportedSign(root, environment)
	flattenRaisedCamp(root, environment, origin, surfaceY)
	tuneImportedFire(root, environment)
	varyExistingTrees(root, environment)
	buildBridgeRails(polish, origin)
	buildGuideMarker(polish, root, surfaceY)
	buildWorkbench(root)

	local generatedPartCount = 0
	for _, descendant in polish:GetDescendants() do
		if descendant:IsA("BasePart") then
			generatedPartCount += 1
		end
	end
	polish:SetAttribute("ArtDirection", "CleanAuthoredTutorialPolish")
	polish:SetAttribute("PreservesGameplayContracts", true)
	polish:SetAttribute("GeneratedPartCount", generatedPartCount)
	polish.Parent = root
	root:SetAttribute("ArtDirectionVersion", 4)
	root:SetAttribute("VisualTheme", "CleanHandcraftedTutorialCamp")
	return root
end

return PolishTutorialZone
