--!strict
-- Pure, deterministic Personal Base migration. Keeping this outside
-- BaseService makes the data transformation independently testable and keeps
-- DataStore I/O completely separate from schema reconciliation.

local BlueprintLayoutConfig = require(script.Parent.BlueprintLayoutConfig)
local BaseSessionTypes = require(script.Parent.BaseSessionTypes)

local BaseSessionMigration = {}

function BaseSessionMigration.Migrate(session: BaseSessionTypes.BaseSessionData): BaseSessionTypes.BaseSessionData
	if session.SchemaVersion >= BaseSessionTypes.CURRENT_SCHEMA_VERSION then
		return session
	end

	local unlinkedIds: { string } = {}
	local claimedPadIds: { [string]: boolean } = {}
	for structureId, structure in session.Structures do
		if structure.PadId then
			claimedPadIds[structure.PadId] = true
		else
			table.insert(unlinkedIds, structureId)
		end
	end
	table.sort(unlinkedIds)
	local padCountByBuildingId: { [string]: number } = {}
	for _, pad in BlueprintLayoutConfig.All do
		padCountByBuildingId[pad.BuildingId] = (padCountByBuildingId[pad.BuildingId] or 0) + 1
	end

	-- Only unique authored structure types can be reconciled from BuildingId
	-- alone. Repeated types such as Wall remain freeform unless an older save
	-- already carries a stable PadId; choosing one of eight sockets by table
	-- order would silently move legitimate player construction.
	for _, pad in BlueprintLayoutConfig.All do
		if not claimedPadIds[pad.PadId] and padCountByBuildingId[pad.BuildingId] == 1 then
			for _, structureId in unlinkedIds do
				local structure = session.Structures[structureId]
				if structure and not structure.PadId and structure.BuildingId == pad.BuildingId then
					structure.PadId = pad.PadId
					claimedPadIds[pad.PadId] = true
					break
				end
			end
		end
	end

	-- Only socket-owned structures move with the authored layout. A mismatched
	-- or removed PadId is never treated as permission to move a freeform build.
	for _, structure in session.Structures do
		if structure.PadId then
			local pad = BlueprintLayoutConfig.Get(structure.PadId)
			if pad and BlueprintLayoutConfig.AcceptsBuilding(pad, structure.BuildingId) then
				structure.CFrame = pad.LocalCFrame
			end
		end
	end

	session.SchemaVersion = BaseSessionTypes.CURRENT_SCHEMA_VERSION
	return session
end

return BaseSessionMigration
