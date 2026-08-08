--!strict
-- Single source of truth for portal travel destinations (Prompt 2): the 4
-- biome gates plus the Tutorial Portal. Owns only destination/travel data —
-- "where does this portal lead, what does it take to use it, where do you
-- land" — not layout geometry (WorldMapConfig/HavenLayoutConfig own that)
-- and not facility placement (HavenFacilityConfig owns that). Consumed by
-- PortalService (server-authoritative travel), GateController/
-- PortalTransitionController (client interaction/transition), and the
-- PortalDestinationGenerator tool that builds the physical arrival/return
-- geometry each entry describes.

local BiomeConfig = require(script.Parent.BiomeConfig)
local WorldMapConfig = require(script.Parent.WorldMapConfig)

export type PortalKind = "Biome" | "Tutorial" | "PersonalBase"

export type PortalDestinationDefinition = {
	id: string,
	displayName: string,
	kind: PortalKind,
	unlockTier: number?, -- nil for Tutorial: always enterable, never blocking
	teaserOrigin: CFrame, -- near Haven — the existing gate anchor position
	realOrigin: CFrame, -- independent far-away origin (see WorldMapConfig.RealOrigin)
	arrivalAnchorName: string, -- Part name PortalDestinationGenerator creates as the landing spot
	returnAnchorName: string, -- Part name in Haven the player lands on when they come back
	loadingText: string,
}

local destinations: { [string]: PortalDestinationDefinition } = {}

for _, biome in BiomeConfig do
	destinations[biome.id] = {
		id = biome.id,
		displayName = biome.name,
		kind = "Biome",
		unlockTier = biome.unlockTier,
		teaserOrigin = WorldMapConfig.WORLD_ORIGIN, -- resolved to the real gate anchor CFrame by GateGenerator/PortalService at build/runtime
		realOrigin = WorldMapConfig.RealOrigin[biome.id],
		arrivalAnchorName = `Arrival_{biome.id}`,
		returnAnchorName = `ReturnLanding_{biome.id}`,
		loadingText = `Entering {biome.name}...`,
	}
end

destinations.Tutorial = {
	id = "Tutorial",
	displayName = "Tutorial Zone",
	kind = "Tutorial",
	unlockTier = nil,
	teaserOrigin = WorldMapConfig.WORLD_ORIGIN,
	realOrigin = WorldMapConfig.RealOrigin.Tutorial,
	arrivalAnchorName = "Arrival_Tutorial",
	returnAnchorName = "HavenArrivalAnchor",
	loadingText = "Entering the Tutorial Zone...",
}

local PortalDestinationConfig = {}

-- Phase 4A: personal-base travel. Ids of the form "PersonalBase_<userId>"
-- are synthesized on demand rather than looked up in the static
-- `destinations` table above (which is populated once from BiomeConfig at
-- require-time and can't hold a per-player entry). BaseService injects the
-- resolver at server Init via SetPersonalBaseOriginResolver rather than this
-- module requiring BaseService directly — this file lives in ReplicatedStorage
-- and must stay safely requirable from the client, while BaseService lives in
-- ServerScriptService. The resolver itself must never yield (no DataStore
-- calls) — see BaseService.GetResolvedOrigin, a plain synchronous table read
-- of a server-owned runtime registry, and PersonalBaseConfig.OriginForSlot,
-- pure grid arithmetic. If the resolver isn't set (client) or the slot isn't
-- resolved yet, Get returns nil for that id, same as any other unknown
-- portal — PortalService.travel resolves the slot via
-- BaseService.PrepareBaseForTravel BEFORE calling Get, so in the real travel
-- path this is already populated by the time Get is called.
local personalBaseOriginResolver: ((userId: number) -> CFrame?)? = nil

function PortalDestinationConfig.SetPersonalBaseOriginResolver(resolver: (userId: number) -> CFrame?)
	personalBaseOriginResolver = resolver
end

local function personalBaseDestination(id: string, userId: number): PortalDestinationDefinition?
	if not personalBaseOriginResolver then
		return nil
	end
	local origin = personalBaseOriginResolver(userId)
	if not origin then
		return nil
	end
	return {
		id = id,
		displayName = "Personal Base",
		kind = "PersonalBase",
		unlockTier = nil,
		teaserOrigin = WorldMapConfig.WORLD_ORIGIN,
		realOrigin = origin,
		arrivalAnchorName = "Arrival_PersonalBase",
		returnAnchorName = "ReturnLanding_PersonalBase",
		loadingText = "Entering your base...",
	}
end

function PortalDestinationConfig.Get(id: string): PortalDestinationDefinition?
	local userIdString = string.match(id, "^PersonalBase_(%d+)$")
	if userIdString then
		return personalBaseDestination(id, tonumber(userIdString) :: number)
	end
	return destinations[id]
end

function PortalDestinationConfig.All(): { [string]: PortalDestinationDefinition }
	return destinations
end

return PortalDestinationConfig
