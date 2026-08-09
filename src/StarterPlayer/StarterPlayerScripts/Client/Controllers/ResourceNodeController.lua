--!strict
-- ProximityPrompt-driven harvesting for ResourceService's runtime-spawned
-- nodes. Matches GateController/FacilityController's existing
-- ProximityPrompt+label pattern rather than inventing new UI — a real
-- harvest/crafting HUD is a future prompt's job (see Prompt 4A's explicit
-- "no crafting/quest UI yet" boundary); this is enough to make the loop
-- actually playable and testable in the meantime.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local ResourceConfig = require(ReplicatedStorage.Shared.Config.ResourceConfig)
local Trove = require(ReplicatedStorage.Shared.Modules.Trove)
local IconGlyphs = require(script.Parent.Parent.UI.IconGlyphs)
local NotificationController = require(script.Parent.NotificationController)

local NODE_TAG = "ResourceNode"
local VISUAL_ROOT_NAME = "NodeVisual_Generated"

local ResourceNodeController = {}

local function buildLabel(node: BasePart, resourceName: string): BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ResourceLabel"
	billboard.Size = UDim2.fromOffset(108, 24)
	billboard.StudsOffset = Vector3.new(0, 1.55, 0)
	billboard.MaxDistance = 22
	billboard.LightInfluence = 0

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 13
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.Text = resourceName
	label.Parent = billboard

	billboard.Parent = node
	return billboard
end

local function setupNode(node: Instance, trove: any)
	if not node:IsA("BasePart") then
		return
	end

	local resourceId = node:GetAttribute("ResourceId") :: string?
	if not resourceId then
		return
	end

	local resource = ResourceConfig.Get(resourceId)
	if not resource then
		warn(`ResourceNodeController: unknown ResourceId "{resourceId}" on {node:GetFullName()}`)
		return
	end

	local visualParts: { BasePart } = {}
	local restingColors: { [BasePart]: Color3 } = {}
	local restingTransparencies: { [BasePart]: number } = {}
	local function rememberVisualPart(visualPart: BasePart)
		if restingColors[visualPart] == nil then
			table.insert(visualParts, visualPart)
			restingColors[visualPart] = visualPart.Color
			restingTransparencies[visualPart] = visualPart.Transparency
		end
	end
	local function refreshVisualParts()
		local visualRoot = node:FindFirstChild(VISUAL_ROOT_NAME)
		if visualRoot then
			for _, descendant in visualRoot:GetDescendants() do
				if descendant:IsA("BasePart") then
					rememberVisualPart(descendant)
				end
			end
		end
	end
	refreshVisualParts()

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HarvestPrompt"
	prompt.ObjectText = resource.name
	prompt.ActionText = "Harvest"
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = node
	trove:Add(prompt)

	local resourceLabel = buildLabel(node, resource.name)
	trove:Add(resourceLabel)

	local function applyDepletedState()
		-- CollectionService can replicate the tag before the visual descendants.
		-- Refresh here so streamed-in pieces still receive depletion and flash FX.
		refreshVisualParts()
		local depleted = node:GetAttribute("Depleted") == true
		prompt.Enabled = not depleted
		resourceLabel.Enabled = not depleted
		for _, visualPart in visualParts do
			local restingTransparency = restingTransparencies[visualPart]
			if restingTransparency ~= nil then
				TweenService:Create(
					visualPart,
					TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Transparency = if depleted then math.max(restingTransparency, 0.72) else restingTransparency }
				):Play()
			end
		end
	end
	applyDepletedState()
	trove:Add(node:GetAttributeChangedSignal("Depleted"):Connect(applyDepletedState))
	trove:Add(node.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") and descendant:FindFirstAncestor(VISUAL_ROOT_NAME) then
			rememberVisualPart(descendant)
			if node:GetAttribute("Depleted") == true then
				descendant.Transparency = math.max(restingTransparencies[descendant], 0.72)
			end
		end
	end))

	trove:Add(prompt.Triggered:Connect(function()
		local ok, resultOrReason = Net.GetFunction("HarvestResourceNode"):InvokeServer(node)
		if ok then
			refreshVisualParts()
			for _, visualPart in visualParts do
				local restingColor = restingColors[visualPart]
				if restingColor then
					visualPart.Color = restingColor:Lerp(Color3.new(1, 1, 1), 0.72)
					TweenService:Create(
						visualPart,
						TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
						{ Color = restingColor }
					):Play()
				end
			end

			local display = IconGlyphs.Get(resourceId)
			NotificationController.Toast("ResourceCollected", `+{resultOrReason} {resource.name}`, {
				Icon = display.Icon,
				AccentColor = display.AccentColor,
			})
		else
			print(`Harvest failed: {tostring(resultOrReason)}`)
		end
	end))
end

function ResourceNodeController:Init()
	self._trove = Trove.new()
end

function ResourceNodeController:Start()
	for _, instance in CollectionService:GetTagged(NODE_TAG) do
		setupNode(instance, self._trove)
	end

	CollectionService:GetInstanceAddedSignal(NODE_TAG):Connect(function(instance)
		setupNode(instance, self._trove)
	end)
end

return ResourceNodeController
