--!strict
-- Authored Haven coordinates: +Z south/arrival, -Z north/expeditions,
-- +X east/right and -X west/left.

export type DistrictId = "Onboarding" | "Progression" | "Commerce" | "EventSeason"
export type PortalPlacement = {
	localPosition: Vector3,
	approachLocalPosition: Vector3,
	arcAngleDegrees: number,
	pocketWidth: number,
	displayName: string,
	status: string,
}

local HavenLayoutConfig = {}

HavenLayoutConfig.HAVEN_MIN_X = -62
HavenLayoutConfig.HAVEN_MAX_X = 62
HavenLayoutConfig.HAVEN_MIN_Z = -16
HavenLayoutConfig.HAVEN_MAX_Z = 118
HavenLayoutConfig.FORTIFICATION_HALF_WIDTH = 62
HavenLayoutConfig.GATEWAY_HALF_WIDTH = 17
HavenLayoutConfig.GATEWAY_CLEAR_HEIGHT = 28
HavenLayoutConfig.PERIMETER_WALL_THICKNESS = 8
HavenLayoutConfig.PERIMETER_WALL_HEIGHT = 24
HavenLayoutConfig.FORTIFICATION_WALL_HEIGHT = 30

HavenLayoutConfig.SPAWN_LOCAL_POSITION = Vector3.new(0, 0, 104)
HavenLayoutConfig.SPAWN_OFFSETS_X = { -12, -6, 0, 6, 12 }
HavenLayoutConfig.SPAWN_POINT_COUNT = 5
HavenLayoutConfig.SPAWN_PAD_SIZE = 5
HavenLayoutConfig.SPAWN_SURFACE_HEIGHT = 1
HavenLayoutConfig.SPAWN_ROOT_OFFSET = 3.5
-- Arrival composition: the survivor camp lives on the west/left diagonal and
-- the communal fire circle frames the opposite side. The central X=-8..8
-- arrival lane stays entirely unobstructed between them.
--
-- The east diagonal used to hold the Haven Guide (NPC + booth + sign). That
-- installation is gone; the spot is now the settlement's gathering fire, which
-- is what an arrival plaza in a survivor camp should actually offer — somewhere
-- to stand, not someone to be lectured by.
HavenLayoutConfig.CAMP_CIRCLE_LOCAL_POSITION = Vector3.new(24, 0, 84)
HavenLayoutConfig.BASE_GATE_LOCAL_POSITION = Vector3.new(-39, 0, 80)
HavenLayoutConfig.BASE_GATE_APPROACH_LOCAL_POSITION = Vector3.new(-22, 0, 90)
-- The records hall spans the north-east corner and faces the real arrival
-- terrace. Its diagonal silhouette is visible down the main street while its
-- wide facade screens the plain retaining walls behind it.
HavenLayoutConfig.LEADERBOARD_LOCAL_POSITION = Vector3.new(38, 0, -8)
-- Haven's own northern gateway. Part of the Haven perimeter, NOT of the
-- Expedition composition — it never moves with the district.
HavenLayoutConfig.EXPEDITION_GATEWAY_LOCAL_POSITION = Vector3.new(0, 0, -16)

-- ---------------------------------------------------------------------
-- Expedition composition
--
-- The whole fan is derived from the four numbers below instead of being
-- authored as loose per-portal coordinates. That is deliberate: it makes
-- "move the Expedition District" a translation of the ARC CENTER, and leaves
-- the radius, the 45-degree spacing, the approach-lane length, the pocket
-- widths and the Forest -> Frozen -> Nuclear -> Volcanic order structurally
-- untouched by such a move. Compressing the fan and moving the fan are now
-- different edits, not the same one.
--
-- Final compaction moves the complete fan from Z=-95 to Z=-30. RADIUS,
-- ANGLES AND APPROACH RADIUS ARE UNCHANGED — the composition is translated,
-- never squeezed. Do not "save space" by shrinking
-- EXPEDITION_ARC_RADIUS; that is the thing the broad fan is made of.
-- ---------------------------------------------------------------------
HavenLayoutConfig.EXPEDITION_ARC_CENTER_LOCAL_POSITION = Vector3.new(0, 0, -30)
HavenLayoutConfig.EXPEDITION_ARC_RADIUS = 95
HavenLayoutConfig.EXPEDITION_APPROACH_RADIUS = 58 -- where a themed approach lane meets its connector path
HavenLayoutConfig.EXPEDITION_GATHERING_OFFSET = 6 -- compact platform meets Haven's north floor without overlapping it
HavenLayoutConfig.EXPEDITION_GATHERING_LOCAL_POSITION = HavenLayoutConfig.EXPEDITION_ARC_CENTER_LOCAL_POSITION
	+ Vector3.new(0, 0, HavenLayoutConfig.EXPEDITION_GATHERING_OFFSET)

-- The task board sits in the protected south-east arrival corner: close to
-- Spawn, visible after arrival, and outside the central circulation lane.
HavenLayoutConfig.NOTICE_BOARD_LOCAL_POSITION = Vector3.new(52, 0, 97)

-- Local +Z is south (toward Haven), so the fan opens toward -Z: a portal at
-- `angleDegrees` sits at (sin θ, -cos θ) * radius from the arc center.
local function arcPoint(angleDegrees: number, radius: number): Vector3
	local angle = math.rad(angleDegrees)
	return HavenLayoutConfig.EXPEDITION_ARC_CENTER_LOCAL_POSITION
		+ Vector3.new(math.sin(angle) * radius, 0, -math.cos(angle) * radius)
end

-- Per-portal authoring: only what is genuinely unique to each biome. Position
-- is never hand-written — it is always its angle on the shared arc.
local portalAuthoring = {
	{ id = "ForestWildlands", arcAngleDegrees = -67.5, pocketWidth = 33.4, displayName = "FOREST WILDLANDS", status = "BETA" },
	{ id = "FrozenWasteland", arcAngleDegrees = -22.5, pocketWidth = 35.6, displayName = "FROZEN WASTELAND", status = "COMING SOON" },
	{ id = "NuclearCity", arcAngleDegrees = 22.5, pocketWidth = 38.9, displayName = "NUCLEAR RUINS", status = "COMING SOON" },
	{ id = "VolcanicCore", arcAngleDegrees = 67.5, pocketWidth = 44.4, displayName = "VOLCANIC FRONTIER", status = "COMING SOON" },
}

HavenLayoutConfig.PortalPlacements = {} :: { [string]: PortalPlacement }
for _, authored in portalAuthoring do
	HavenLayoutConfig.PortalPlacements[authored.id] = {
		localPosition = arcPoint(authored.arcAngleDegrees, HavenLayoutConfig.EXPEDITION_ARC_RADIUS),
		approachLocalPosition = arcPoint(authored.arcAngleDegrees, HavenLayoutConfig.EXPEDITION_APPROACH_RADIUS),
		arcAngleDegrees = authored.arcAngleDegrees,
		pocketWidth = authored.pocketWidth,
		displayName = authored.displayName,
		status = authored.status,
	}
end

function HavenLayoutConfig.PortalPlacement(biomeId: string): PortalPlacement
	local placement = HavenLayoutConfig.PortalPlacements[biomeId]
	if not placement then
		error(`HavenLayoutConfig: no portal placement for biome "{biomeId}"`)
	end
	return placement
end

function HavenLayoutConfig.PositionFromLocal(origin: CFrame, localPosition: Vector3): Vector3
	return origin:PointToWorldSpace(localPosition)
end

function HavenLayoutConfig.CFrameFacing(origin: CFrame, localPosition: Vector3, targetLocalPosition: Vector3): CFrame
	local position = HavenLayoutConfig.PositionFromLocal(origin, localPosition)
	local target = HavenLayoutConfig.PositionFromLocal(origin, targetLocalPosition)
	return CFrame.lookAt(position, Vector3.new(target.X, position.Y, target.Z))
end

export type DistrictDefinition = { id: DistrictId, name: string, accentColor: Color3 }
HavenLayoutConfig.Districts = {
	{ id = "Onboarding", name = "Onboarding District", accentColor = Color3.fromRGB(120, 220, 140) },
	{ id = "Progression", name = "Progression District", accentColor = Color3.fromRGB(100, 200, 255) },
	{ id = "Commerce", name = "Commerce District", accentColor = Color3.fromRGB(255, 200, 100) },
	{ id = "EventSeason", name = "Event & Season District", accentColor = Color3.fromRGB(210, 130, 255) },
} :: { DistrictDefinition }

function HavenLayoutConfig.GetDistrict(id: DistrictId): DistrictDefinition
	for _, district in HavenLayoutConfig.Districts do
		if district.id == id then
			return district
		end
	end
	error(`HavenLayoutConfig: unknown district "{id}"`)
end

return HavenLayoutConfig
