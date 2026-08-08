--!strict
-- Retained as a compatibility module for older plugin builds. The zoned
-- Haven deliberately has no generic plaza clutter; facility-specific props
-- live with their owning generators.
local PlazaDetailGenerator = {}
function PlazaDetailGenerator.Build(_parent: Instance, _origin: CFrame): Model?
	return nil
end
return PlazaDetailGenerator
