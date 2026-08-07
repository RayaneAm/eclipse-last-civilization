--!strict
-- Handles the always-open return portal at each hidden destination (biome
-- regions + Tutorial Zone) — the "come back to Haven" side of Prompt 2's
-- portal system. Discovers via CollectionService tag "ReturnPortal" (set by
-- PortalDestinationGenerator), mirroring GateController's tag-driven
-- discovery pattern. No lock state at all — these are always usable, so
-- there's no BiomeGateService involvement and no status panel, just a
-- ProximityPrompt straight to PortalService.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local Trove = require(ReplicatedStorage.Shared.Modules.Trove)

local RETURN_PORTAL_TAG = "ReturnPortal"

local ReturnPortalController = {}

-- Shared across every return portal — same one-in-flight-at-a-time spam
-- guard GateController uses for outbound travel; the server enforces its
-- own cooldown/duplicate-request checks independently either way.
local travelRequestInFlight = false

local function setupReturnPortal(instance: Instance, trove: any)
	if not instance:IsA("BasePart") then
		return
	end

	local portalId = instance:GetAttribute("PortalId") :: string?
	if not portalId then
		warn(`ReturnPortalController: "{instance:GetFullName()}" is tagged {RETURN_PORTAL_TAG} but has no PortalId attribute`)
		return
	end

	local prompt = instance:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		warn(`ReturnPortalController: "{instance:GetFullName()}" is tagged {RETURN_PORTAL_TAG} but has no ProximityPrompt`)
		return
	end

	trove:Add(prompt.Triggered:Connect(function()
		if travelRequestInFlight then
			return
		end
		travelRequestInFlight = true

		task.spawn(function()
			local ok, reason = Net.GetFunction("RequestPortalReturn"):InvokeServer(portalId)
			if not ok then
				warn(`ReturnPortalController: return travel from "{portalId}" failed: {tostring(reason)}`)
			end
			travelRequestInFlight = false
		end)
	end))
end

function ReturnPortalController:Init()
	self._trove = Trove.new()
end

function ReturnPortalController:Start()
	for _, instance in CollectionService:GetTagged(RETURN_PORTAL_TAG) do
		setupReturnPortal(instance, self._trove)
	end

	CollectionService:GetInstanceAddedSignal(RETURN_PORTAL_TAG):Connect(function(instance)
		setupReturnPortal(instance, self._trove)
	end)
end

return ReturnPortalController
