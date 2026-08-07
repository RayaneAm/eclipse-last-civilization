--!strict
-- Spawns a modest number of runtime resource nodes and resolves harvest
-- requests. Nodes are runtime gameplay objects (cooldown/depletion state) —
-- they are NOT part of the "_Generated" build-tool namespace and are
-- recreated fresh every server start, unlike Haven/terrain/districts, which
-- are authored once via the ECLIPSE TOOLS plugin. Node geometry is a plain,
-- clearly-functional primitive per resource type — not an art pass, see
-- Prompt 4A's explicit boundary.
--
-- PROMPT 4A.1 FIX (superseded by Prompt 2, see below): nodes previously
-- spawned at BIOME_START_RADIUS+40..260 — physically beyond the Forest
-- gate's barrier. A tier-0 player could never reach them, so "Gather
-- Wood/Stone" could never complete.
--
-- PROMPT 2: the tutorial moved out of the main plaza entirely, into its own
-- isolated Tutorial Zone (tools/BuildTutorialZone.luau) at
-- WorldMapConfig.RealOrigin.Tutorial — "move beginner resource piles out of
-- the main plaza and into the tutorial zone." Nodes now spawn scattered
-- around that zone's own small ground platform instead of near Haven's
-- Onboarding District.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local WorldMapConfig = require(ReplicatedStorage.Shared.Config.WorldMapConfig)
local ResourceConfig = require(ReplicatedStorage.Shared.Config.ResourceConfig)
local InventoryService = require(script.Parent.InventoryService)
local ToolService = require(script.Parent.ToolService)

local ResourceService = {}

local NODE_TAG = "ResourceNode"
local ROOT_NAME = "ResourceNodes_Runtime"
local MAX_HARVEST_DISTANCE = 14 -- studs; anti-teleport-harvest sanity check

local NODE_COUNTS = {
	{ resourceId = "Wood", count = 6 },
	{ resourceId = "Stone", count = 4 },
	{ resourceId = "Food", count = 4 },
}

-- Scattered around the Tutorial Zone's own small ground platform (see
-- tools/BuildTutorialZone.luau) — past the arrival platform (radius 22) and
-- clear of the return portal (offset 30 along +X from origin), well inside
-- the zone's sealing boundary.
local NODE_MIN_RADIUS = 26
local NODE_MAX_RADIUS = 48

type NodeState = {
	part: BasePart,
	resourceId: string,
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
local function spawnNode(parent: Instance, resourceId: string, origin: CFrame, rng: Random)
	local angle = rng:NextNumber(0, math.pi * 2)
	local sampleDirection = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local radius = rng:NextNumber(NODE_MIN_RADIUS, NODE_MAX_RADIUS)

	local surfacePosition = origin.Position + sampleDirection * radius

	local part = buildNodeGeometry(resourceId, CFrame.new(surfacePosition))
	part.Parent = parent
	part:SetAttribute("ResourceId", resourceId)
	part:SetAttribute("Depleted", false)
	CollectionService:AddTag(part, NODE_TAG)

	nodesByPart[part] = { part = part, resourceId = resourceId, readyAt = 0 }
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

	local tutorialOrigin = WorldMapConfig.RealOrigin.Tutorial
	local rng = Random.new(9)
	for _, entry in NODE_COUNTS do
		for _ = 1, entry.count do
			spawnNode(root, entry.resourceId, tutorialOrigin, rng)
		end
	end

	Net.GetFunction("HarvestResourceNode").OnServerInvoke = function(player: Player, nodeInstance: Instance)
		return tryHarvest(player, nodeInstance)
	end
end

return ResourceService
