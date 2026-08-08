--!strict
-- Spawns a modest number of runtime resource nodes and resolves harvest
-- requests. Nodes are runtime gameplay objects (cooldown/depletion state) —
-- they are NOT part of the "_Generated" build-tool namespace and are
-- recreated fresh every server start, unlike Haven/terrain/districts, which
-- are authored once via the ECLIPSE TOOLS plugin. Node geometry is a plain,
-- clearly-functional primitive per resource type — not an art pass, see
-- Prompt 4A's explicit boundary.
--
-- BuildTutorialZone authors six deterministic spawn anchors inside the
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

local function newPart(size: Vector3, cframe: CFrame, color: Color3, name: string): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.Rock
	part.Anchored = true
	part.CanCollide = true
	part.Parent = Workspace
	return part
end

local function buildNodeGeometry(resourceId: string, cframe: CFrame): BasePart
	local resource = ResourceConfig.Get(resourceId)
	assert(resource, `ResourceService: unknown resource "{resourceId}"`)

	if resourceId == "Wood" then
		return newPart(Vector3.new(3, 2.4, 3), cframe * CFrame.new(0, 1.2, 0), resource.nodeColor, "WoodNode")
	elseif resourceId == "Stone" then
		return newPart(Vector3.new(3.2, 2, 3.2), cframe * CFrame.new(0, 1, 0), resource.nodeColor, "StoneNode")
	else
		return newPart(Vector3.new(2.4, 1.6, 2.4), cframe * CFrame.new(0, 0.8, 0), resource.nodeColor, "FoodNode")
	end
end

-- Nodes sit on the Tutorial Zone's own small flat ground platform (built by
-- tools/BuildTutorialZone.luau at WorldMapConfig.RealOrigin.Tutorial, y=0
-- relative to that origin), not out on procedural Terrain — so this places
-- them directly at ground height rather than routing through TerrainSurface
-- (which only raycasts against Terrain, and the Tutorial Zone has none).
local function spawnNodeAt(parent: Instance, resourceId: string, surfacePosition: Vector3, areaId: string)
	local part = buildNodeGeometry(resourceId, CFrame.new(surfacePosition))
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
	local root = Instance.new("Folder")
	root.Name = ROOT_NAME
	root.Parent = Workspace

	local anchors = CollectionService:GetTagged(RESOURCE_SPAWN_TAG)
	if #anchors == 0 then
		warn("ResourceService: no authored Tutorial resource anchors found; run Build Complete World before playtesting")
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
