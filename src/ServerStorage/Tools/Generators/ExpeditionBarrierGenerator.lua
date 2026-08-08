--!strict
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HavenLayoutConfig = require(ReplicatedStorage.Shared.Config.HavenLayoutConfig)
local GeneratorKit = require(script.Parent.GeneratorKit)

local ExpeditionBarrierGenerator = {}
function ExpeditionBarrierGenerator.Build(parent: Instance, origin: CFrame): Model
	GeneratorKit.CleanupPrevious(parent, "ExpeditionBarrier")
	local model = Instance.new("Model")
	model.Name = "ExpeditionBarrier"
	local width = HavenLayoutConfig.GATEWAY_HALF_WIDTH * 2 + 3
	local height = HavenLayoutConfig.GATEWAY_CLEAR_HEIGHT
	local z = HavenLayoutConfig.EXPEDITION_GATEWAY_LOCAL_POSITION.Z
	for i = 1, 6 do
		local segmentWidth = width / 6
		local field = GeneratorKit.NewPart({
			Name = `Field{i}`,
			Size = Vector3.new(segmentWidth + 0.2, height, 0.8),
			CFrame = origin * CFrame.new(-width / 2 + segmentWidth * (i - 0.5), height / 2, z),
			Material = Enum.Material.ForceField,
			Color = Color3.fromRGB(150, 49, 52),
			Transparency = 0.72,
			Parent = model,
		})
		CollectionService:AddTag(field, "ExpeditionSecurityBarrier")
	end
	for _, x in { -width / 2, width / 2 } do
		GeneratorKit.NewPart({
			Name = "CheckpointFieldPylon",
			Size = Vector3.new(1.4, height + 2, 1.4),
			CFrame = origin * CFrame.new(x, (height + 2) / 2, z),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(34, 37, 43),
			Parent = model,
		})
	end
	local sign = GeneratorKit.NewPart({
		Name = "CheckpointStatus",
		Size = Vector3.new(12, 2.4, 0.3),
		CFrame = origin * CFrame.new(0, 18, z + 0.6) * CFrame.Angles(0, math.pi, 0),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(35, 37, 42),
		CanCollide = false,
		Parent = model,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(700, 140)
	gui.MaxDistance = 75
	gui.LightInfluence = 0.4
	gui.Parent = sign
	CollectionService:AddTag(gui, "ExpeditionCheckpointSign")
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(226, 181, 160)
	label.Text = "TUTORIAL CLEARANCE REQUIRED"
	label.Parent = gui
	model.Parent = parent
	return model
end
return ExpeditionBarrierGenerator
