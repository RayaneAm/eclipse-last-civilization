--!strict
-- Phase 4A: Base Gate interaction — discovered via CollectionService tag
-- "BaseGatePortal" (set by BuildSurvivorHaven.luau), mirroring
-- TutorialPortalController's tag-driven pattern almost exactly. Always
-- available, no lock state, always travels to the LOCAL player's own base
-- (portalId "PersonalBase_<own userId>") — visiting a friend's base is a
-- separate flow (future Base UI "Visit" action), not this gate.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local Trove = require(ReplicatedStorage.Shared.Modules.Trove)

local BASE_GATE_TAG = "BaseGatePortal"

local BaseGateController = {}

local travelRequestInFlight = false

local function setupBaseGate(instance: Instance, trove: any)
	if not instance:IsA("BasePart") then
		return
	end

	local prompt = instance:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		warn(`BaseGateController: "{instance:GetFullName()}" is tagged {BASE_GATE_TAG} but has no ProximityPrompt`)
		return
	end

	trove:Add(prompt.Triggered:Connect(function()
		if travelRequestInFlight then
			return
		end
		travelRequestInFlight = true

		task.spawn(function()
			local portalId = `PersonalBase_{Players.LocalPlayer.UserId}`
			local ok, reason = Net.GetFunction("RequestPortalTravel"):InvokeServer(portalId)
			if not ok then
				warn(`BaseGateController: travel to your base failed: {tostring(reason)}`)
			end
			travelRequestInFlight = false
		end)
	end))
end

function BaseGateController:Init()
	self._trove = Trove.new()
end

function BaseGateController:Start()
	for _, instance in CollectionService:GetTagged(BASE_GATE_TAG) do
		setupBaseGate(instance, self._trove)
	end
	CollectionService:GetInstanceAddedSignal(BASE_GATE_TAG):Connect(function(instance)
		setupBaseGate(instance, self._trove)
	end)
end

return BaseGateController
