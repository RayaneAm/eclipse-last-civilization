--!strict
-- Server-authoritative portal travel (Prompt 2). Scoped strictly to TRAVEL —
-- BiomeGateService keeps 100% of lock/unlock state and collision-group
-- responsibility; this only reads ProgressionService.GetTier the same way
-- BiomeGateService/RegionService already do, never duplicating that check
-- into a second progression system. GateController (and, for the Tutorial
-- Portal, its own client-side controller) call RequestPortalTravel; this
-- service decides whether it's allowed and, if so, performs it.
--
-- The client only ever sends a PortalId string — never a CFrame or
-- position — so a malicious client cannot supply an arbitrary destination.
-- Every real destination position comes from PortalDestinationConfig and
-- the physical anchor Parts the world generators build, resolved here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local Signal = require(ReplicatedStorage.Shared.Modules.Signal)
local PortalDestinationConfig = require(ReplicatedStorage.Shared.Config.PortalDestinationConfig)
local ProgressionService = require(script.Parent.ProgressionService)
local BaseService = require(script.Parent.BaseService)
local BasePermissionService = require(script.Parent.BasePermissionService)

local PortalService = {}

-- Fired only on a teleport that actually landed (authorized, not cooled down,
-- not aborted mid-transition). Kept as two directional Signals rather than one
-- "travelled" event because a consumer counting expeditions has to be able to
-- tell an outbound trip from the trip home — see DailyQuestService, which pairs
-- them into a round trip so RequestPortalReturn alone can never be farmed.
PortalService.DestinationEntered = Signal.new() -- (player, portalId, kind)
PortalService.ReturnedToHaven = Signal.new() -- (player, portalId, kind)

local COOLDOWN_SECONDS = 2
local TRANSITION_HOLD_SECONDS = 0.35 -- lets the fade-to-black actually read, and gives an in-flight death/leave a moment to be caught

local lastTravelAt: { [Player]: number } = {}
local pendingTravel: { [Player]: boolean } = {}

-- One-shot lookup, not a hot path — anchors are found once per travel
-- request, never polled. Recursive FindFirstChild is fine at this frequency.
local function findAnchor(name: string): BasePart?
	local instance = Workspace:FindFirstChild(name, true)
	if instance and instance:IsA("BasePart") then
		return instance
	end
	return nil
end

local function isAuthorized(player: Player, destination: PortalDestinationConfig.PortalDestinationDefinition): (boolean, string?)
	if destination.kind == "Tutorial" then
		return true, nil -- always enterable, never blocking, re-enterable after completion
	end

	if destination.kind == "PersonalBase" then
		local hostUserId = tonumber(string.match(destination.id, "^PersonalBase_(%d+)$"))
		if not hostUserId then
			return false, "UnknownPortal"
		end
		if hostUserId == player.UserId then
			return true, nil -- always authorized to enter your own base
		end
		if BasePermissionService.CanVisit(player, hostUserId) then
			return true, nil
		end
		return false, "NotInvited"
	end

	local requiredTier = destination.unlockTier
	if requiredTier and ProgressionService.GetTier(player) < requiredTier then
		return false, "TierTooLow"
	end

	return true, nil
end

-- Shared by both outbound travel (Haven -> destination.arrivalAnchorName)
-- and the return trip (destination -> destination.returnAnchorName in
-- Haven) — everything except which anchor name to resolve and whether tier
-- authorization applies is identical between the two directions.
local function performTeleport(player: Player, destination: PortalDestinationConfig.PortalDestinationDefinition, anchorName: string, loadingText: string): (boolean, string?)
	if pendingTravel[player] then
		return false, "AlreadyTraveling"
	end

	local now = os.clock()
	local lastAt = lastTravelAt[player]
	if lastAt and now - lastAt < COOLDOWN_SECONDS then
		return false, "Cooldown"
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and (character :: Model):FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not humanoid or not rootPart or humanoid.Health <= 0 then
		return false, "NoCharacter"
	end

	local anchor = findAnchor(anchorName)
	if not anchor then
		warn(`PortalService: anchor "{anchorName}" not found for portal "{destination.id}" — has the destination generator been run?`)
		return false, "DestinationNotReady"
	end

	pendingTravel[player] = true
	lastTravelAt[player] = now

	-- Guard the in-flight teleport against the player dying or leaving
	-- mid-transition — no existing codebase precedent for this async guard
	-- (confirmed by investigation), so it's self-contained here and torn
	-- down the instant this specific request resolves or aborts.
	local aborted = false
	local diedConnection = humanoid.Died:Connect(function()
		aborted = true
	end)
	local leavingConnection = Players.PlayerRemoving:Connect(function(leavingPlayer)
		if leavingPlayer == player then
			aborted = true
		end
	end)

	Net.GetEvent("PortalTransitionBegin"):FireClient(player, loadingText)
	task.wait(TRANSITION_HOLD_SECONDS)

	diedConnection:Disconnect()
	leavingConnection:Disconnect()
	pendingTravel[player] = nil

	if aborted or not rootPart.Parent or not character.Parent then
		return false, "AbortedDuringTransition"
	end

	rootPart.CFrame = anchor.CFrame + Vector3.new(0, 3, 0)
	Net.GetEvent("PortalTransitionEnd"):FireClient(player)

	return true, nil
end

function PortalService.TeleportToHavenArrival(player: Player): (boolean, string?)
	local destination = PortalDestinationConfig.Get("Tutorial")
	if not destination then
		return false, "UnknownPortal"
	end
	return performTeleport(player, destination, destination.returnAnchorName, "Entering Survivor Haven...")
end

local function travel(player: Player, portalId: string): (boolean, string?)
	if typeof(portalId) ~= "string" then
		return false, "InvalidPortal"
	end

	-- Personal-base ids resolve asynchronously (durable slot + idempotent
	-- physical build) BEFORE PortalDestinationConfig.Get is ever called for
	-- them — that shared config module's Get must stay synchronous, so the
	-- yielding happens here, in the service, not hidden inside it. See
	-- PortalDestinationConfig.luau's SetPersonalBaseOriginResolver comment.
	local hostUserId = tonumber(string.match(portalId, "^PersonalBase_(%d+)$"))
	if hostUserId then
		local ready = BaseService.PrepareBaseForTravel(hostUserId)
		if not ready then
			return false, "DestinationNotReady"
		end
	end

	local destination = PortalDestinationConfig.Get(portalId)
	if not destination then
		return false, "UnknownPortal"
	end

	local authorized, reason = isAuthorized(player, destination)
	if not authorized then
		return false, reason
	end

	local ok, failure = performTeleport(player, destination, destination.arrivalAnchorName, destination.loadingText)
	if ok then
		PortalService.DestinationEntered:Fire(player, destination.id, destination.kind)
	end
	return ok, failure
end

-- No tier check — the player is already standing in the destination, so
-- returning to Haven is always allowed regardless of what's changed since
-- they arrived.
local function returnToHaven(player: Player, portalId: string): (boolean, string?)
	if typeof(portalId) ~= "string" then
		return false, "InvalidPortal"
	end

	local destination = PortalDestinationConfig.Get(portalId)
	if not destination then
		return false, "UnknownPortal"
	end

	local ok, failure = performTeleport(player, destination, destination.returnAnchorName, "Returning to Survivor Haven...")
	if ok then
		PortalService.ReturnedToHaven:Fire(player, destination.id, destination.kind)
	end
	return ok, failure
end

function PortalService:Init()
	Players.PlayerRemoving:Connect(function(player)
		lastTravelAt[player] = nil
		pendingTravel[player] = nil
	end)

	Net.GetFunction("RequestPortalTravel").OnServerInvoke = function(player: Player, portalId: string)
		return travel(player, portalId)
	end

	Net.GetFunction("RequestPortalReturn").OnServerInvoke = function(player: Player, portalId: string)
		return returnToHaven(player, portalId)
	end
end

return PortalService
