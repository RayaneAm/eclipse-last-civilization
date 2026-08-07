--!strict
-- Finds the actual Terrain surface height at a horizontal position via a
-- straight-down raycast, instead of duplicating whatever noise formula
-- generated the terrain there (which would drift out of sync). Used by both
-- a build-time tool (tools/Generators/LandmarkGenerator.luau, placing hero
-- landmarks) and a runtime service (src/server/Services/ResourceService.luau,
-- placing resource nodes) — one implementation, two callers, per Prompt 4A's
-- "avoid duplicated ... code" directive.

local Workspace = game:GetService("Workspace")

local TerrainSurface = {}

function TerrainSurface.FindSurfacePosition(horizontalPosition: Vector3): Vector3
	local terrain = Workspace:FindFirstChildOfClass("Terrain")
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Include
	raycastParams.FilterDescendantsInstances = if terrain then { terrain } else {}

	local origin = Vector3.new(horizontalPosition.X, 600, horizontalPosition.Z)
	local result = Workspace:Raycast(origin, Vector3.new(0, -1200, 0), raycastParams)

	if result then
		return result.Position
	end

	return horizontalPosition
end

return TerrainSurface
