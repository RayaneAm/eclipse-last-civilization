--!strict
-- Fixed personal-base blueprint-pad layout (Phase 4A.1) — every pad's
-- position/rotation is authored here, once, server-trusted, never derived
-- from client input. BuildingService.RequestBuildBlueprint places a
-- structure at exactly a pad's own LocalCFrame; PersonalBaseGenerator draws
-- an unbuilt pad as a ghost outline + prompt at the same CFrame. Reuses the
-- existing BuildingConfig roster (only 2 new entries, EntranceGate and
-- DefenseControl, added alongside this file) rather than inventing new
-- building types this pass.
--
-- Positions form a readable rectangular settlement: arrival essentials,
-- specialist side lanes and a defensive perimeter with room left between
-- them for later freeform/co-op expansion.

local BuildingConfig = require(script.Parent.BuildingConfig)
local PersonalBaseConfig = require(script.Parent.PersonalBaseConfig)

export type BlueprintPad = {
	PadId: string,
	BuildingId: string,
	LocalCFrame: CFrame,
	District: "Entrance" | "Logistics" | "Production" | "Support" | "Perimeter",
	RequiredBuildingId: string?,
	AllowedBuildingIds: { string }?,
	SpanLength: number?,
	DefenseGroup: "Front" | "Back" | "Left" | "Right" | "Gate"?,
}

local BlueprintLayoutConfig = {}

local HALF_WIDTH = PersonalBaseConfig.PlotBounds.HalfWidth
local HALF_DEPTH = PersonalBaseConfig.PlotBounds.HalfDepth
local WALL_FOOTPRINT = BuildingConfig.GetFootprintSize("Wall")
local GATE_FOOTPRINT = BuildingConfig.GetFootprintSize("EntranceGate")
local WALL_THICKNESS = WALL_FOOTPRINT.Z
local GATE_HALF_WIDTH = GATE_FOOTPRINT.X / 2

-- Every center is derived from the corresponding outer boundary and actual
-- tier-one footprint. The CFrame orientation points local +Z inward; higher
-- tier depth offsets therefore preserve this same exterior face.
local FRONT_CENTER_Z = -(HALF_DEPTH - WALL_THICKNESS / 2)
local BACK_CENTER_Z = HALF_DEPTH - WALL_THICKNESS / 2
local LEFT_CENTER_X = -(HALF_WIDTH - WALL_THICKNESS / 2)
local RIGHT_CENTER_X = HALF_WIDTH - WALL_THICKNESS / 2
local GATE_CENTER_Z = -(HALF_DEPTH - GATE_FOOTPRINT.Z / 2)

local SIDE_INNER_X = HALF_WIDTH - WALL_THICKNESS
local FRONT_SECTION_SPAN = SIDE_INNER_X - GATE_HALF_WIDTH
local FRONT_SECTION_CENTER_X = (SIDE_INNER_X + GATE_HALF_WIDTH) / 2
local BACK_SECTION_SPAN = SIDE_INNER_X
local BACK_SECTION_CENTER_X = BACK_SECTION_SPAN / 2
local SIDE_SECTION_SPAN = HALF_DEPTH - WALL_THICKNESS
local SIDE_SECTION_CENTER_Z = SIDE_SECTION_SPAN / 2

local pads: { BlueprintPad } = {
	-- All six central lots are available together. Their physical grouping,
	-- not a numbered stage chain, communicates logistics/production/support.
	-- Stable PadIds preserve existing ownership and migration contracts.
	{
		PadId = "EntranceGate_1",
		BuildingId = "EntranceGate",
		LocalCFrame = CFrame.new(0, 0, GATE_CENTER_Z),
		District = "Entrance",
		AllowedBuildingIds = { "EntranceGate", "ReinforcedGate", "MetalGate", "AdvancedGate" },
		DefenseGroup = "Gate",
	},
	{ PadId = "Storage_1", BuildingId = "Storage", LocalCFrame = CFrame.new(-32, 0, 12), District = "Logistics" },
	{ PadId = "Workbench_1", BuildingId = "Workbench", LocalCFrame = CFrame.new(32, 0, 12), District = "Logistics" },
	{ PadId = "Generator_1", BuildingId = "Generator", LocalCFrame = CFrame.new(-46, 0, 42), District = "Production" },
	{ PadId = "ResourceProcessor_1", BuildingId = "ResourceProcessor", LocalCFrame = CFrame.new(-46, 0, 68), District = "Production" },
	{ PadId = "DefenseControl_1", BuildingId = "DefenseControl", LocalCFrame = CFrame.new(46, 0, 42), District = "Support" },
	{ PadId = "SurvivorQuarters_1", BuildingId = "SurvivorQuarters", LocalCFrame = CFrame.new(46, 0, 68), District = "Support" },
}

-- Eight wall sockets mark the rectangular settlement boundary without
-- drawing a compulsory circular roadmap. The open south-center bay belongs
-- to EntranceGate_1.
local wallPads = {
	{ X = -FRONT_SECTION_CENTER_X, Z = FRONT_CENTER_Z, Rotation = 0, Span = FRONT_SECTION_SPAN, Group = "Front" },
	{ X = FRONT_SECTION_CENTER_X, Z = FRONT_CENTER_Z, Rotation = 0, Span = FRONT_SECTION_SPAN, Group = "Front" },
	{ X = -BACK_SECTION_CENTER_X, Z = BACK_CENTER_Z, Rotation = 180, Span = BACK_SECTION_SPAN, Group = "Back" },
	{ X = BACK_SECTION_CENTER_X, Z = BACK_CENTER_Z, Rotation = 180, Span = BACK_SECTION_SPAN, Group = "Back" },
	{ X = LEFT_CENTER_X, Z = -SIDE_SECTION_CENTER_Z, Rotation = 90, Span = SIDE_SECTION_SPAN, Group = "Left" },
	{ X = LEFT_CENTER_X, Z = SIDE_SECTION_CENTER_Z, Rotation = 90, Span = SIDE_SECTION_SPAN, Group = "Left" },
	{ X = RIGHT_CENTER_X, Z = -SIDE_SECTION_CENTER_Z, Rotation = -90, Span = SIDE_SECTION_SPAN, Group = "Right" },
	{ X = RIGHT_CENTER_X, Z = SIDE_SECTION_CENTER_Z, Rotation = -90, Span = SIDE_SECTION_SPAN, Group = "Right" },
}
for i, wall in wallPads do
	table.insert(pads, {
		PadId = `Wall_{i - 1}`,
		BuildingId = "Wall",
		LocalCFrame = CFrame.new(wall.X, 0, wall.Z) * CFrame.Angles(0, math.rad(wall.Rotation), 0),
		District = "Perimeter",
		RequiredBuildingId = "DefenseControl",
		AllowedBuildingIds = { "Wall", "ReinforcedWall", "MetalWall", "AdvancedWall" },
		SpanLength = wall.Span,
		DefenseGroup = wall.Group,
	})
end

BlueprintLayoutConfig.All = pads

local byId: { [string]: BlueprintPad } = {}
for _, pad in pads do
	byId[pad.PadId] = pad
end

function BlueprintLayoutConfig.Get(padId: string): BlueprintPad?
	return byId[padId]
end

function BlueprintLayoutConfig.IsUnlocked(pad: BlueprintPad, structures: { [string]: any }): boolean
	if not pad.RequiredBuildingId then
		return true
	end
	for _, structure in structures do
		if structure.BuildingId == pad.RequiredBuildingId then
			return true
		end
	end
	return false
end

function BlueprintLayoutConfig.AcceptsBuilding(pad: BlueprintPad, buildingId: string): boolean
	if not pad.AllowedBuildingIds then
		return pad.BuildingId == buildingId
	end
	return table.find(pad.AllowedBuildingIds, buildingId) ~= nil
end

function BlueprintLayoutConfig.GetFootprintSize(pad: BlueprintPad, buildingId: string?): Vector3
	local footprint = BuildingConfig.GetFootprintSize(buildingId or pad.BuildingId)
	return if pad.SpanLength then Vector3.new(pad.SpanLength, footprint.Y, footprint.Z) else footprint
end

-- A socket stores the tier-one center. Deeper higher tiers grow only toward
-- the settlement interior, keeping the exterior defensive face locked to
-- the true max-range line instead of creeping into the patrol zone.
function BlueprintLayoutConfig.GetStructureLocalCFrame(pad: BlueprintPad, buildingId: string?): CFrame
	local baseDepth = BuildingConfig.GetFootprintSize(pad.BuildingId).Z
	local depth = BuildingConfig.GetFootprintSize(buildingId or pad.BuildingId).Z
	return pad.LocalCFrame * CFrame.new(0, 0, math.max(0, depth - baseDepth) / 2)
end

return BlueprintLayoutConfig
