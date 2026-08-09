--!strict
-- Client-local Personal Base feedback: one nearby construction label/ghost
-- preview at a time, affordability color, and lightweight nearby production
-- rotor animation. No per-lot scripts and no permanent map-wide billboards.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local Trove = require(ReplicatedStorage.Shared.Modules.Trove)
local BuildingConfig = require(ReplicatedStorage.Shared.Config.BuildingConfig)
local BlueprintLayoutConfig = require(ReplicatedStorage.Shared.Config.BlueprintLayoutConfig)
local PersonalBaseConfig = require(ReplicatedStorage.Shared.Config.PersonalBaseConfig)

local BaseWorldFeedbackController = {}

local trackedPads: { [BasePart]: boolean } = {}
local activePad: BasePart? = nil
local previewModel: Model? = nil
local baseSession: any = nil
local scrapBalance = 0
local elapsed = 0

local function ownerUserId(instance: Instance): number?
	local cursor: Instance? = instance
	while cursor do
		local value = cursor:GetAttribute("OwnerUserId")
		if typeof(value) == "number" then
			return value
		end
		cursor = cursor.Parent
	end
	return nil
end

local function clearPreview()
	if previewModel then
		previewModel:Destroy()
		previewModel = nil
	end
end

local function previewPart(parent: Instance, name: string, size: Vector3, cframe: CFrame)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.ForceField
	part.Color = Color3.fromRGB(143, 194, 177)
	part.Transparency = 0.68
	part.Parent = parent
	return part
end

local function createPreview(anchor: BasePart)
	clearPreview()
	local padId = anchor:GetAttribute("PadId")
	if typeof(padId) ~= "string" then
		return
	end
	local pad = BlueprintLayoutConfig.Get(padId)
	local lot = anchor.Parent
	local futureWorldCFrame = lot and lot:GetAttribute("FutureWorldCFrame")
	if not pad or typeof(futureWorldCFrame) ~= "CFrame" then
		return
	end
	local footprint = BlueprintLayoutConfig.GetFootprintSize(pad)
	local groundCFrame = futureWorldCFrame :: CFrame
	local model = Instance.new("Model")
	model.Name = "LocalConstructionPreview"

	previewPart(model, "Foundation", Vector3.new(footprint.X, 0.35, footprint.Z), groundCFrame * CFrame.new(0, 0.22, 0))
	if pad.BuildingId == "EntranceGate" then
		for _, side in { -1, 1 } do
			previewPart(model, "GatePost", Vector3.new(2.4, footprint.Y, footprint.Z), groundCFrame * CFrame.new(side * (footprint.X / 2 - 1.2), footprint.Y / 2, 0))
		end
		previewPart(model, "GateHeader", Vector3.new(footprint.X, 1.4, footprint.Z), groundCFrame * CFrame.new(0, footprint.Y - 0.7, 0))
	elseif pad.BuildingId == "Wall" then
		previewPart(model, "Wall", Vector3.new(footprint.X, footprint.Y, footprint.Z), groundCFrame * CFrame.new(0, footprint.Y / 2, 0))
	else
		local bodyHeight = math.max(3.5, footprint.Y)
		previewPart(model, "Body", Vector3.new(math.max(1, footprint.X - 1), bodyHeight, math.max(1, footprint.Z - 1)), groundCFrame * CFrame.new(0, 0.5 + bodyHeight / 2, 0))
		previewPart(model, "Roof", Vector3.new(footprint.X + 0.6, 0.55, footprint.Z + 0.6), groundCFrame * CFrame.new(0, bodyHeight + 0.78, 0))
	end

	model.Parent = Workspace
	previewModel = model
end

local function canAffordPad(anchor: BasePart): boolean
	if not baseSession then
		return false
	end
	local buildingId = anchor:GetAttribute("BuildingId")
	if typeof(buildingId) ~= "string" then
		return false
	end
	local definition = BuildingConfig.Get(buildingId)
	if not definition or scrapBalance < definition.Cost.Scrap then
		return false
	end
	for itemId, amount in definition.Cost.Materials do
		if (baseSession.Storage[itemId] or 0) < amount then
			return false
		end
	end
	return true
end

local function updatePadState(anchor: BasePart)
	local lot = anchor.Parent
	local indicator = lot and lot:FindFirstChild("BeaconIndicator")
	if not indicator or not indicator:IsA("BasePart") then
		return
	end
	local affordable = canAffordPad(anchor)
	indicator.Color = if affordable then Color3.fromRGB(104, 205, 121) else Color3.fromRGB(132, 112, 81)
	local light = indicator:FindFirstChild("BeaconLight")
	if light and light:IsA("PointLight") then
		light.Color = indicator.Color
		light.Brightness = if affordable then 0.35 else 0.16
	end
	anchor:SetAttribute("ClientAffordable", affordable)
end

local function setActivePad(nextPad: BasePart?)
	if activePad == nextPad then
		return
	end
	if activePad then
		local oldLabel = activePad:FindFirstChild("ConstructionLabel")
		if oldLabel and oldLabel:IsA("BillboardGui") then
			oldLabel.Enabled = false
		end
	end
	activePad = nextPad
	clearPreview()
	if activePad then
		local label = activePad:FindFirstChild("ConstructionLabel")
		if label and label:IsA("BillboardGui") then
			label.Enabled = true
		end
		createPreview(activePad)
	end
end

local function trackPad(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local prompt = instance:FindFirstChildOfClass("ProximityPrompt")
	local isOwner = ownerUserId(instance) == Players.LocalPlayer.UserId
	if prompt and not isOwner then
		prompt.Enabled = false
	end
	if isOwner then
		trackedPads[instance] = true
		updatePadState(instance)
	end
end

local function refreshSessions()
	local player = Players.LocalPlayer
	local baseOk, baseResult = pcall(function()
		return Net.GetFunction("RequestBaseState"):InvokeServer(player.UserId)
	end)
	if baseOk and baseResult then
		baseSession = baseResult.Session
	end
	local playerOk, playerResult = pcall(function()
		return Net.GetFunction("RequestPlayerSession"):InvokeServer()
	end)
	if playerOk and playerResult then
		scrapBalance = playerResult.Currencies.Scrap
	end
	for anchor in trackedPads do
		updatePadState(anchor)
	end
end

local function promoteReadyState(machine: BasePart, structureModel: Model)
	structureModel:SetAttribute("ProductionState", "Ready")
	machine:SetAttribute("ProductionState", "Ready")
	local lamp = structureModel:FindFirstChild("ProductionStatusLamp", true)
	if lamp and lamp:IsA("BasePart") then
		lamp.Color = Color3.fromRGB(107, 201, 111)
		local light = lamp:FindFirstChild("StatusLight")
		if light and light:IsA("PointLight") then
			light.Color = lamp.Color
			light.Enabled = true
		end
	end
	local output = structureModel:FindFirstChild("OutputCrate", true)
	if output and output:IsA("BasePart") then
		output.Transparency = 0
	end
	local prompt = machine:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.ActionText = "Collect Output"
	end
end

function BaseWorldFeedbackController:Init()
	self._trove = Trove.new()
end

function BaseWorldFeedbackController:Start()
	for _, instance in CollectionService:GetTagged("BaseBlueprintPad") do
		trackPad(instance)
	end
	self._trove:Add(CollectionService:GetInstanceAddedSignal("BaseBlueprintPad"):Connect(trackPad))
	self._trove:Add(CollectionService:GetInstanceRemovedSignal("BaseBlueprintPad"):Connect(function(instance)
		if instance:IsA("BasePart") then
			trackedPads[instance] = nil
			if activePad == instance then
				setActivePad(nil)
			end
		end
	end))

	self._trove:Add(Net.GetEvent("BaseStateChanged").OnClientEvent:Connect(function(session: any)
		baseSession = session
		for anchor in trackedPads do
			updatePadState(anchor)
		end
	end))
	self._trove:Add(Net.GetEvent("CurrencyChanged").OnClientEvent:Connect(function(newScrap: number)
		scrapBalance = newScrap
		for anchor in trackedPads do
			updatePadState(anchor)
		end
	end))

	task.spawn(refreshSessions)
	self._trove:Add(RunService.Heartbeat:Connect(function(deltaTime)
		elapsed += deltaTime
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			setActivePad(nil)
			return
		end

		-- Nearby production motion is client-only and uses no per-machine loops.
		for _, machine in CollectionService:GetTagged("BaseProductionMachine") do
			if machine:IsA("BasePart") and (machine.Position - root.Position).Magnitude <= 90 then
				local structureModel = machine.Parent
				if structureModel and structureModel:IsA("Model") and structureModel:GetAttribute("ProductionState") == "Running" then
					local completesAt = structureModel:GetAttribute("ProductionCompletesAt")
					if typeof(completesAt) == "number" and completesAt > 0 and os.time() >= completesAt then
						promoteReadyState(machine, structureModel)
					end
				end
				local rotor = structureModel and structureModel:FindFirstChild("MachineRotor", true)
				if structureModel and structureModel:GetAttribute("ProductionState") == "Running" and rotor and rotor:IsA("BasePart") then
					rotor.CFrame *= CFrame.Angles(deltaTime * 1.7, 0, 0)
				end
			end
		end

		if elapsed < 0.15 then
			return
		end
		elapsed = 0
		local nearest: BasePart? = nil
		local nearestDistance = PersonalBaseConfig.ConstructionPreviewDistance
		for anchor in trackedPads do
			if anchor.Parent then
				local distance = (anchor.Position - root.Position).Magnitude
				if distance <= nearestDistance then
					nearest = anchor
					nearestDistance = distance
				end
			else
				trackedPads[anchor] = nil
			end
		end
		setActivePad(nearest)
	end))
end

return BaseWorldFeedbackController
