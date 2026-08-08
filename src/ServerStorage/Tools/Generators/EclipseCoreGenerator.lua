--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HavenLayoutConfig = require(ReplicatedStorage.Shared.Config.HavenLayoutConfig)
local GeneratorKit = require(script.Parent.GeneratorKit)
local WorldFacilityLabelGenerator = require(script.Parent.WorldFacilityLabelGenerator)

local EclipseCoreGenerator = {}
function EclipseCoreGenerator.Build(parent: Instance, origin: CFrame): { Model: Model, CoreCFrame: CFrame }
	GeneratorKit.CleanupPrevious(parent, "EclipseCore")
	GeneratorKit.CleanupPrevious(parent, "EclipseRelay")
	local model = Instance.new("Model")
	model.Name = "EclipseRelay"
	local center = origin * CFrame.new(HavenLayoutConfig.ECLIPSE_RELAY_LOCAL_POSITION)
	GeneratorKit.NewPart({
		Name = "RelayDeck",
		Size = Vector3.new(14, 1, 14),
		CFrame = center * CFrame.new(0, 0.5, 0),
		Material = Enum.Material.DiamondPlate,
		Color = Color3.fromRGB(42, 45, 52),
		Parent = model,
	})
	for _, x in { -5.5, 5.5 } do
		for _, z in { -5.5, 5.5 } do
			GeneratorKit.NewPart({
				Name = "ContainmentStrut",
				Size = Vector3.new(0.7, 8, 0.7),
				CFrame = center * CFrame.new(x, 4.5, z),
				Material = Enum.Material.Metal,
				Color = Color3.fromRGB(56, 58, 65),
				Parent = model,
			})
		end
	end
	GeneratorKit.NewPart({
		Name = "RelayCorePedestal",
		Size = Vector3.new(7, 3, 7),
		CFrame = center * CFrame.new(0, 2, 0),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(48, 43, 58),
		Parent = model,
	})
	local energy = GeneratorKit.NewPart({
		Name = "RelayCoreColumn",
		Size = Vector3.new(4, 7, 4),
		CFrame = center * CFrame.new(0, 6.5, 0),
		Material = Enum.Material.Glass,
		Color = Color3.fromRGB(88, 52, 143),
		Transparency = 0.28,
		CanCollide = false,
		Parent = model,
	})
	energy.CastShadow = false
	for _, x in { -5.5, 5.5 } do
		GeneratorKit.NewPart({
			Name = "RelayCabinet",
			Size = Vector3.new(2, 4, 4),
			CFrame = center * CFrame.new(x, 2.5, 0),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(37, 41, 47),
			Parent = model,
		})
	end
	WorldFacilityLabelGenerator.Build(model, center * CFrame.new(0, 7.7, 6.1) * CFrame.Angles(0, math.pi, 0), {
		Title = "Eclipse Relay",
		Subtitle = "Settlement Power",
		AccentColor = Color3.fromRGB(112, 75, 170),
		Width = 11,
		MaxDistance = 60,
	})
	GeneratorKit.Finalize(model, "RelayDeck")
	model.Parent = parent
	return { Model = model, CoreCFrame = center }
end
return EclipseCoreGenerator
