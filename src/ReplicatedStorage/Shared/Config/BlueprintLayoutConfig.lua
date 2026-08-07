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
-- Positions deliberately reuse/extend the zones PersonalBaseGenerator.luau
-- already lays out (perimeter ring, shelter neighborhood, defense-control
-- spot, future survivor/production zones) rather than inventing a new
-- layout — see that file's own geometry for the matching decorative pieces.

export type BlueprintPad = {
	PadId: string,
	BuildingId: string,
	LocalCFrame: CFrame,
}

local BlueprintLayoutConfig = {}

local pads: { BlueprintPad } = {}

-- 8 perimeter wall pads, evenly spaced around the same radius-85 ring
-- PersonalBaseGenerator.buildPerimeterMarkers already uses, each facing
-- tangentially so a built wall reads as a continuous ring.
for i = 0, 7 do
	local angleDegrees = 45 * i
	local angle = math.rad(angleDegrees)
	local radius = 85
	table.insert(pads, {
		PadId = `Wall_{i}`,
		BuildingId = "Wall",
		LocalCFrame = CFrame.new(math.cos(angle) * radius, 0, math.sin(angle) * radius) * CFrame.Angles(0, angle + math.rad(90), 0),
	})
end

table.insert(pads, { PadId = "EntranceGate_1", BuildingId = "EntranceGate", LocalCFrame = CFrame.new(0, 0, -80) })
table.insert(pads, { PadId = "Storage_1", BuildingId = "Storage", LocalCFrame = CFrame.new(-25, 0, 18) })
table.insert(pads, { PadId = "Workbench_1", BuildingId = "Workbench", LocalCFrame = CFrame.new(-16, 0, 30) })
table.insert(pads, { PadId = "Generator_1", BuildingId = "Generator", LocalCFrame = CFrame.new(15, 0, -40) })
table.insert(pads, { PadId = "ResourceProcessor_1", BuildingId = "ResourceProcessor", LocalCFrame = CFrame.new(-40, 0, -35) })
table.insert(pads, { PadId = "DefenseControl_1", BuildingId = "DefenseControl", LocalCFrame = CFrame.new(-25, 0, -10) })
table.insert(pads, { PadId = "SurvivorQuarters_1", BuildingId = "SurvivorQuarters", LocalCFrame = CFrame.new(35, 0, -35) })

BlueprintLayoutConfig.All = pads

local byId: { [string]: BlueprintPad } = {}
for _, pad in pads do
	byId[pad.PadId] = pad
end

function BlueprintLayoutConfig.Get(padId: string): BlueprintPad?
	return byId[padId]
end

return BlueprintLayoutConfig
