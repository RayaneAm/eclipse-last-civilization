--!strict
-- Centralized Remote wrapper. All RemoteEvents/RemoteFunctions the game will
-- ever use are declared once in `Remotes` below (no magic strings scattered
-- through services/controllers). The server provisions instances on boot;
-- the client waits for them. Add new entries here as future prompts need them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

export type RemoteKind = "Event" | "Function"

local Remotes: { [string]: RemoteKind } = {
	RequestGateStatus = "Function", -- client -> server: get lock state for all gates
	GateActivated = "Event", -- server -> client(s): a gate finished its unlock FX sequence
	RegionChanged = "Event", -- server -> client: the player entered a different biome wedge

	-- Prompt 2: portal-based travel
	RequestPortalTravel = "Function", -- client -> server: payload is a PortalId string only; server resolves/validates the destination itself (outbound, tier-checked)
	RequestPortalReturn = "Function", -- client -> server: payload is the PortalId of the destination being LEFT; server resolves that destination's own returnAnchorName in Haven (no tier check — already there)
	PortalTransitionBegin = "Event", -- server -> client: fade to black, controls stay disabled until PortalTransitionEnd
	PortalTransitionEnd = "Event", -- server -> client: player has been placed at the destination; safe to fade in and restore controls

	-- Prompt 4A: core survival loop
	RequestPlayerSession = "Function", -- client -> server: one consolidated pull (inventory, tool, currency, quest, tier)
	InventoryChanged = "Event", -- server -> client: push on inventory mutation
	CurrencyChanged = "Event", -- server -> client: push on currency mutation
	ProgressionChanged = "Event", -- server -> client: push on tier change
	XPChanged = "Event", -- server -> client: push on XP gain and/or tier rollover from ProgressionService.AddXP.
	-- Payload: { AmountGained: number, XP: number, XPToNextTier: number?, Tier: number, TierUp: boolean }
	QuestUpdated = "Event", -- server -> client: push on quest/objective change
	RequestCraft = "Function", -- client -> server: payload is a recipe id only
	HarvestResourceNode = "Function", -- client -> server: payload is a node Instance reference
	EquipTool = "Function", -- client -> server: payload is an item id only
	InteractQuestGiver = "Function", -- client -> server: no payload; server infers start/turn-in/reminder

	-- Phase 3B: monetization UI + Daily Rewards roulette
	RequestStarterPackEligible = "Function", -- client -> server: no payload; returns boolean (PlaytimeService, < 30 total hours)
	RequestDailyRewardRoll = "Function", -- client -> server: no payload; returns { Rejected: true } or { RewardIndex: number, Streak: number }

	-- Daily Quests. Read-only from the client's side by design — there is no
	-- "I completed a daily objective" remote, exactly as QuestService's header
	-- explains for the tutorial chain. Progress only ever moves on server Signals.
	RequestDailyQuests = "Function", -- client -> server: no payload; assigns today's shared set if needed and returns personal progress
	DailyQuestsUpdated = "Event", -- server -> client: push the full DailyQuestState on roll/progress/completion

	-- Phase 4A: personal base
	RequestBaseState = "Function", -- client -> server: payload is the base owner's userId; returns BaseSessionData or nil
	BaseStateChanged = "Event", -- server -> client(s currently at/watching that base): push the full BaseSessionData on any mutation
	RequestPlaceBuilding = "Function", -- client -> server: {BuildingId, CFrame, Rotation}
	RequestBuildBlueprint = "Function", -- Phase 4A.1: client -> server: {PadId} — builds at the pad's own predefined transform, no client CFrame involved
	RequestMoveBuilding = "Function", -- client -> server: {StructureId, CFrame}
	RequestUpgradeBuilding = "Function", -- client -> server: {StructureId}
	RequestRepairBuilding = "Function", -- client -> server: {StructureId}
	RequestDismantleBuilding = "Function", -- client -> server: {StructureId}
	RequestDepositStorage = "Function", -- client -> server: {ItemId, Amount}
	RequestWithdrawStorage = "Function", -- client -> server: {ItemId, Amount}
	RequestStartProduction = "Function", -- client -> server: {MachineStructureId, RecipeId}
	RequestCollectProduction = "Function", -- client -> server: {JobId}
	RequestCancelProduction = "Function", -- client -> server: {JobId}
	RequestSetPowerEnabled = "Function", -- client -> server: {StructureId, Enabled}
	RequestTraderSell = "Function", -- client -> server: {ItemId, Amount, ConfirmOverride}
	RequestTraderSellJunk = "Function", -- client -> server: no payload
	RequestTraderBuy = "Function", -- client -> server: {ItemId, Amount}
	RequestSetReserve = "Function", -- client -> server: {ItemId, Amount}
	RequestSetAllowedVisitor = "Function", -- client -> server: {VisitorUserId, Allowed}
	RequestAllocateDefenseReserve = "Function", -- client -> server: {ItemId, Amount}
	RequestConsumeDefenseReserve = "Function", -- client -> server: {ItemId, Amount}
	RequestSupplyShopCatalog = "Function", -- client -> server: no payload
	RequestSupplyShopPurchase = "Function", -- client -> server: {ItemId}
	RequestMarketListings = "Function", -- client -> server: {Category, Cursor} — reads the MemoryStoreSortedMap index
	RequestCreateMarketListing = "Function", -- client -> server: {ItemId, Quantity, Price, Category, ReservedForUserId}
	RequestCancelMarketListing = "Function", -- client -> server: {ListingId}
	RequestPurchaseMarketListing = "Function", -- client -> server: {ListingId}
	RequestMyMarketListings = "Function", -- client -> server: no payload
	EclipseStateChanged = "Event", -- server -> client(s): broadcast on Eclipse phase transition
}

local Net = {}

local folder: Folder

local function getFolder(): Folder
	if folder then
		return folder
	end

	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild("Remotes")
		if existing then
			folder = existing :: Folder
		else
			folder = Instance.new("Folder")
			folder.Name = "Remotes"
			folder.Parent = ReplicatedStorage

			for name, kind in Remotes do
				local instance: Instance
				if kind == "Event" then
					instance = Instance.new("RemoteEvent")
				else
					instance = Instance.new("RemoteFunction")
				end
				instance.Name = name
				instance.Parent = folder
			end
		end
	else
		folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
	end

	return folder
end

function Net.GetEvent(name: string): RemoteEvent
	assert(Remotes[name] == "Event", `Net: "{name}" is not declared as an Event`)
	return getFolder():WaitForChild(name) :: RemoteEvent
end

function Net.GetFunction(name: string): RemoteFunction
	assert(Remotes[name] == "Function", `Net: "{name}" is not declared as a Function`)
	return getFolder():WaitForChild(name) :: RemoteFunction
end

return Net
