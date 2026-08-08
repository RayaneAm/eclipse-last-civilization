--!strict
-- Historical module name retained for callers; geometry is now a straight,
-- segmented northern fortification with one controlled Grand Gateway.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HavenLayoutConfig = require(ReplicatedStorage.Shared.Config.HavenLayoutConfig)
local GeneratorKit = require(script.Parent.GeneratorKit)
local WorldFacilityLabelGenerator = require(script.Parent.WorldFacilityLabelGenerator)

local ColosseumWallGenerator = {}
local function block(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3)
	GeneratorKit.NewPart({
		Name = name,
		Size = size,
		CFrame = cf,
		Material = Enum.Material.Concrete,
		Color = color,
		Parent = parent,
	})
end

function ColosseumWallGenerator.Build(parent: Instance, origin: CFrame): Model
	GeneratorKit.CleanupPrevious(parent, "ColosseumWall")
	GeneratorKit.CleanupPrevious(parent, "NorthernFortification")
	local model = Instance.new("Model")
	model.Name = "NorthernFortification"
	local z = HavenLayoutConfig.EXPEDITION_GATEWAY_LOCAL_POSITION.Z
	local half = HavenLayoutConfig.FORTIFICATION_HALF_WIDTH
	local gap = HavenLayoutConfig.GATEWAY_HALF_WIDTH
	local wallHeight = HavenLayoutConfig.FORTIFICATION_WALL_HEIGHT
	local wallColor = Color3.fromRGB(57, 61, 67)
	for _, side in { -1, 1 } do
		local width = half - gap
		local x = side * (gap + width / 2)
		block(
			model,
			"FortifiedWallSegment",
			Vector3.new(width, wallHeight, HavenLayoutConfig.PERIMETER_WALL_THICKNESS),
			origin * CFrame.new(x, wallHeight / 2, z),
			wallColor
		)
		block(
			model,
			"RetainingFoot",
			Vector3.new(width, 5, 14),
			origin * CFrame.new(x, 2.5, z + 2),
			Color3.fromRGB(44, 48, 53)
		)
		block(
			model,
			"GatewayPylon",
			Vector3.new(6, wallHeight + 8, 10),
			origin * CFrame.new(side * (gap + 3), (wallHeight + 8) / 2, z),
			Color3.fromRGB(46, 50, 57)
		)
		block(
			model,
			"SecurityTower",
			Vector3.new(10, wallHeight + 6, 12),
			origin * CFrame.new(side * 57, (wallHeight + 6) / 2, z),
			Color3.fromRGB(48, 52, 58)
		)
		for xFence = gap + 10, half - 5, 10 do
			block(
				model,
				"WallFencePost",
				Vector3.new(0.5, 6, 0.5),
				origin * CFrame.new(side * xFence, wallHeight + 3, z),
				Color3.fromRGB(31, 34, 39)
			)
		end
	end
	block(
		model,
		"GatewayLintel",
		Vector3.new(gap * 2 + 12, 6, 10),
		origin * CFrame.new(0, HavenLayoutConfig.GATEWAY_CLEAR_HEIGHT + 3, z),
		Color3.fromRGB(45, 49, 56)
	)
	WorldFacilityLabelGenerator.Build(
		model,
		origin * CFrame.new(0, HavenLayoutConfig.GATEWAY_CLEAR_HEIGHT + 3, z + 5.2) * CFrame.Angles(0, math.pi, 0),
		{
			Title = "Expeditions",
			Subtitle = "Security Gateway",
			AccentColor = Color3.fromRGB(202, 145, 78),
			Width = 18,
			MaxDistance = 100,
		}
	)
	GeneratorKit.Finalize(model, "GatewayLintel")
	model.Parent = parent
	return model
end
return ColosseumWallGenerator
