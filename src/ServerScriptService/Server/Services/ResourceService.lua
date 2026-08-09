--!strict
-- Spawns a modest number of runtime resource nodes and resolves harvest
-- requests. Nodes are runtime gameplay objects (cooldown/depletion state) —
-- they are NOT part of the "_Generated" build-tool namespace and are
-- recreated fresh every server start, unlike Haven/terrain/districts, which
-- are authored once via the ECLIPSE TOOLS plugin. A transparent gameplay
-- hitbox owns each node while a small grounded visual cluster supplies its
-- readable wood, stone, or food silhouette.
--
-- The authored Tutorial Zone keeps six deterministic spawn anchors inside the
-- first-login clearing. Runtime nodes are created exactly at those anchors,
-- keeping the central walking lane clean and validation reproducible.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local Signal = require(ReplicatedStorage.Shared.Modules.Signal)
local ResourceConfig = require(ReplicatedStorage.Shared.Config.ResourceConfig)
local InventoryService = require(script.Parent.InventoryService)
local ToolService = require(script.Parent.ToolService)

local ResourceService = {}

-- Fired once per successful harvest, AFTER every distance/cooldown check has
-- passed. Distinct from InventoryService.ItemAdded on purpose: that counts
-- ITEMS (and fires for crafting, trades and rewards too), this counts NODES,
-- which is what a "harvest N nodes" objective actually means.
ResourceService.NodeHarvested = Signal.new() -- (player, resourceId, amountGranted)

local NODE_TAG = "ResourceNode"
local ROOT_NAME = "ResourceNodes_Runtime"
local TUTORIAL_ROOT_NAME = "TutorialZone_Generated"
local VISUAL_ROOT_NAME = "NodeVisual_Generated"
local MAX_HARVEST_DISTANCE = 14 -- studs; anti-teleport-harvest sanity check

local RESOURCE_SPAWN_TAG = "TutorialResourceSpawn"

-- Which gameplay area a node belongs to. Anchors may declare an `AreaId`
-- attribute; the tutorial anchor tag predates that and is the only spawner
-- today, so it falls back to the Tutorial area. A future biome node spawner
-- sets AreaId to its BiomeConfig id and everything downstream (notably
-- DailyQuestService's accessibility check) picks it up with no further change.
ResourceService.TUTORIAL_AREA_ID = "Tutorial"

type NodeState = {
	part: BasePart,
	resourceId: string,
	areaId: string,
	readyAt: number,
}

local nodesByPart: { [BasePart]: NodeState } = {}

local function newVisualPart(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	material: Enum.Material,
	color: Color3,
	shape: Enum.PartType
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Shape = shape
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function addWoodVisuals(parent: Instance, base: CFrame, resourceColor: Color3)
	local bark = resourceColor:Lerp(Color3.fromRGB(121, 82, 48), 0.58)
	local barkDark = Color3.fromRGB(73, 53, 37)
	local cutWood = Color3.fromRGB(173, 128, 76)

	local lowerLog = base
		* CFrame.new(-0.2, 0.39, -0.34)
		* CFrame.Angles(0, math.rad(18), math.rad(-2))
	newVisualPart(
		parent,
		"LowerLog",
		Vector3.new(2.9, 0.72, 0.72),
		lowerLog,
		Enum.Material.Wood,
		bark,
		Enum.PartType.Cylinder
	)

	local upperLog = base
		* CFrame.new(0.25, 0.77, 0.22)
		* CFrame.Angles(0, math.rad(-16), math.rad(2))
	newVisualPart(
		parent,
		"UpperLog",
		Vector3.new(2.55, 0.64, 0.64),
		upperLog,
		Enum.Material.Wood,
		barkDark,
		Enum.PartType.Cylinder
	)

	local stump = base
		* CFrame.new(-0.92, 0.66, 0.66)
		* CFrame.Angles(0, math.rad(-9), math.rad(90))
	newVisualPart(
		parent,
		"SplitStump",
		Vector3.new(1.32, 1.08, 1.08),
		stump,
		Enum.Material.Wood,
		bark,
		Enum.PartType.Cylinder
	)
	newVisualPart(
		parent,
		"SplitStumpCut",
		Vector3.new(0.055, 0.98, 0.98),
		stump * CFrame.new(0.687, 0, 0),
		Enum.Material.WoodPlanks,
		cutWood,
		Enum.PartType.Cylinder
	)
end

local function addStoneVisuals(parent: Instance, base: CFrame, resourceColor: Color3)
	local lightStone = resourceColor:Lerp(Color3.fromRGB(155, 153, 143), 0.48)
	local darkStone = resourceColor:Lerp(Color3.fromRGB(76, 82, 80), 0.54)

	local stones = {
		{
			name = "FoundationStone",
			size = Vector3.new(1.85, 1.26, 1.5),
			offset = Vector3.new(-0.42, 0.53, 0.03),
			rotation = Vector3.new(8, 23, -7),
			color = resourceColor,
			material = Enum.Material.Slate,
		},
		{
			name = "ShoulderStone",
			size = Vector3.new(1.28, 0.98, 1.14),
			offset = Vector3.new(0.82, 0.4, 0.28),
			rotation = Vector3.new(-5, -31, 11),
			color = lightStone,
			material = Enum.Material.Rock,
		},
		{
			name = "LowStone",
			size = Vector3.new(1.2, 0.78, 1.42),
			offset = Vector3.new(0.18, 0.3, -0.82),
			rotation = Vector3.new(6, 41, 4),
			color = darkStone,
			material = Enum.Material.Slate,
		},
		{
			name = "ChipStone",
			size = Vector3.new(0.82, 0.62, 0.75),
			offset = Vector3.new(-1.05, 0.24, -0.65),
			rotation = Vector3.new(-9, -12, 8),
			color = lightStone,
			material = Enum.Material.Rock,
		},
	}

	for _, stone in stones do
		newVisualPart(
			parent,
			stone.name,
			stone.size,
			base
				* CFrame.new(stone.offset)
				* CFrame.Angles(
					math.rad(stone.rotation.X),
					math.rad(stone.rotation.Y),
					math.rad(stone.rotation.Z)
				),
			stone.material,
			stone.color,
			Enum.PartType.Ball
		)
	end
end

local function addFoodVisuals(parent: Instance, base: CFrame, resourceColor: Color3)
	local leafColor = resourceColor:Lerp(Color3.fromRGB(77, 113, 65), 0.5)
	local berryColor = Color3.fromRGB(157, 82, 64)

	for index, offset in {
		Vector3.new(-0.38, 0.36, 0.05),
		Vector3.new(0.33, 0.31, -0.18),
	} do
		newVisualPart(
			parent,
			`LeafCluster{index}`,
			Vector3.new(1.05, 0.62, 0.9),
			base * CFrame.new(offset) * CFrame.Angles(0, math.rad(index * 37), math.rad(index * 5)),
			Enum.Material.Grass,
			leafColor,
			Enum.PartType.Ball
		)
	end

	for index, offset in {
		Vector3.new(-0.28, 0.71, -0.02),
		Vector3.new(0.22, 0.64, 0.06),
	} do
		newVisualPart(
			parent,
			`Berry{index}`,
			Vector3.new(0.28, 0.28, 0.28),
			base * CFrame.new(offset),
			Enum.Material.SmoothPlastic,
			berryColor,
			Enum.PartType.Ball
		)
	end
end

local function buildNodeGeometry(resourceId: string, surfaceCFrame: CFrame): BasePart
	local resource = ResourceConfig.Get(resourceId)
	assert(resource, `ResourceService: unknown resource "{resourceId}"`)

	local hitbox = Instance.new("Part")
	hitbox.Name = `{resourceId}Node`
	hitbox.Size = if resourceId == "Wood"
		then Vector3.new(4.1, 2.35, 4.1)
		elseif resourceId == "Stone" then Vector3.new(3.9, 2.05, 3.9)
		else Vector3.new(3.2, 1.8, 3.2)
	hitbox.CFrame = surfaceCFrame * CFrame.new(0, hitbox.Size.Y / 2, 0)
	hitbox.Transparency = 1
	hitbox.Material = Enum.Material.SmoothPlastic
	hitbox.Color = resource.nodeColor
	hitbox.Anchored = true
	hitbox.CanCollide = false
	hitbox.CanTouch = false
	hitbox.CanQuery = true
	hitbox.CastShadow = false
	hitbox.TopSurface = Enum.SurfaceType.Smooth
	hitbox.BottomSurface = Enum.SurfaceType.Smooth

	local visualRoot = Instance.new("Model")
	visualRoot.Name = VISUAL_ROOT_NAME
	visualRoot.Parent = hitbox

	if resourceId == "Wood" then
		addWoodVisuals(visualRoot, surfaceCFrame, resource.nodeColor)
	elseif resourceId == "Stone" then
		addStoneVisuals(visualRoot, surfaceCFrame, resource.nodeColor)
	else
		addFoodVisuals(visualRoot, surfaceCFrame, resource.nodeColor)
	end

	return hitbox
end

-- Nodes sit on the Tutorial Zone's authored floating-island map, not on procedural
-- Terrain. Each invisible anchor already carries the exact surface height for
-- its wood/stone clearing, so this uses that authored position instead of
-- routing through TerrainSurface (which only raycasts against Terrain).
local function spawnNodeAt(parent: Instance, resourceId: string, surfacePosition: Vector3, areaId: string)
	local visualSeed = math.floor(math.abs(surfacePosition.X * 11 + surfacePosition.Z * 17))
	local yaw = math.rad((visualSeed % 9 - 4) * 7)
	local part = buildNodeGeometry(
		resourceId,
		CFrame.new(surfacePosition) * CFrame.Angles(0, yaw, 0)
	)
	part.Parent = parent
	part:SetAttribute("ResourceId", resourceId)
	part:SetAttribute("AreaId", areaId)
	part:SetAttribute("Depleted", false)
	CollectionService:AddTag(part, NODE_TAG)

	nodesByPart[part] = { part = part, resourceId = resourceId, areaId = areaId, readyAt = 0 }
end

-- What can actually be farmed in this server, grouped by the AREA it sits in:
-- areaId -> set of resourceIds. Read by DailyQuestService, which then keeps
-- only the areas a given player can genuinely reach through normal gameplay —
-- "a node exists somewhere" is not the same as "this player can go get it",
-- and a daily built on the wrong one is unfinishable (or worse, sends a
-- finished player back into the Tutorial Zone).
--
-- Deliberately reports raw availability only; it owns no accessibility policy.
-- Nodes are created once in Init and only ever deplete/respawn (never leave),
-- so this mapping is stable for the life of the server.
function ResourceService.GetHarvestableResourceIdsByArea(): { [string]: { [string]: boolean } }
	local byArea: { [string]: { [string]: boolean } } = {}
	for _, state in nodesByPart do
		local resources = byArea[state.areaId]
		if not resources then
			resources = {}
			byArea[state.areaId] = resources
		end
		resources[state.resourceId] = true
	end
	return byArea
end

local function tryHarvest(player: Player, nodeInstance: Instance): (boolean, string | number)
	if typeof(nodeInstance) ~= "Instance" or not nodeInstance:IsA("BasePart") then
		return false, "InvalidNode"
	end

	local state = nodesByPart[nodeInstance]
	if not state then
		return false, "UnknownNode"
	end

	if os.clock() < state.readyAt then
		return false, "OnCooldown"
	end

	local character = player.Character
	local rootPart = character and (character:FindFirstChild("HumanoidRootPart") :: BasePart?)
	if not rootPart then
		return false, "NoCharacter"
	end
	if (rootPart.Position - state.part.Position).Magnitude > MAX_HARVEST_DISTANCE then
		return false, "TooFar"
	end

	local resource = ResourceConfig.Get(state.resourceId)
	assert(resource, `ResourceService: node references unknown resource "{state.resourceId}"`)

	local multiplier = ToolService.GetHarvestMultiplier(player, state.resourceId)
	local amount = math.max(1, math.floor(resource.baseYield * multiplier + 0.5))

	InventoryService.AddItem(player, state.resourceId, amount)
	ResourceService.NodeHarvested:Fire(player, state.resourceId, amount)

	state.readyAt = os.clock() + resource.respawnSeconds
	state.part:SetAttribute("Depleted", true)
	task.delay(resource.respawnSeconds, function()
		if state.part.Parent then
			state.part:SetAttribute("Depleted", false)
		end
	end)

	return true, amount
end

function ResourceService:Init()
	local priorRoot = Workspace:FindFirstChild(ROOT_NAME)
	if priorRoot then
		priorRoot:Destroy()
	end
	table.clear(nodesByPart)

	local root = Instance.new("Folder")
	root.Name = ROOT_NAME
	root.Parent = Workspace

	local tutorialRoot = Workspace:FindFirstChild(TUTORIAL_ROOT_NAME)
	local anchors: { BasePart } = {}
	if tutorialRoot then
		for _, instance in CollectionService:GetTagged(RESOURCE_SPAWN_TAG) do
			if instance:IsA("BasePart") and instance:IsDescendantOf(tutorialRoot) then
				table.insert(anchors, instance)
			end
		end
	end
	table.sort(anchors, function(a, b)
		return a:GetFullName() < b:GetFullName()
	end)

	if #anchors == 0 then
		warn("ResourceService: no live authored Tutorial resource anchors found; run Build Complete World before playtesting")
	end
	for _, anchor in anchors do
		if anchor:IsA("BasePart") then
			local resourceId = anchor:GetAttribute("ResourceId")
			local areaId = anchor:GetAttribute("AreaId")
			if typeof(resourceId) == "string" and ResourceConfig.Get(resourceId) then
				spawnNodeAt(
					root,
					resourceId,
					anchor.Position,
					if typeof(areaId) == "string" then areaId else ResourceService.TUTORIAL_AREA_ID
				)
			else
				warn(`ResourceService: invalid Tutorial resource anchor {anchor:GetFullName()}`)
			end
		end
	end

	Net.GetFunction("HarvestResourceNode").OnServerInvoke = function(player: Player, nodeInstance: Instance)
		return tryHarvest(player, nodeInstance)
	end
end

return ResourceService
