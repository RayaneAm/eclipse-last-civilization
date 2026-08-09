--!strict
-- Large shared Daily Quests board. The three rows are initialized from the
-- deterministic UTC-day selection and DailyQuestsController refreshes their
-- timer and the local player's progress at runtime.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DailyQuestConfig = require(ReplicatedStorage.Shared.Config.DailyQuestConfig)
local GeneratorKit = require(script.Parent.GeneratorKit)

local DailyQuestBoardGenerator = {}

local BOARD_WIDTH = 24
local BOARD_HEIGHT = 14
local BOARD_CENTER_Y = 10
local POST_HEIGHT = 20
local TIMBER = Color3.fromRGB(91, 67, 45)
local TIMBER_DARK = Color3.fromRGB(57, 43, 32)
local ACCENT = Color3.fromRGB(229, 176, 54)
local PANEL = Color3.fromRGB(47, 34, 29)

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	material: Enum.Material,
	color: Color3,
	collide: boolean?
): Part
	return GeneratorKit.NewPart({
		Name = name,
		Size = size,
		CFrame = cf,
		Material = material,
		Color = color,
		CanCollide = collide,
		Parent = parent,
	})
end

local function textLabel(parent: Instance, name: string, position: UDim2, size: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.TextColor3 = Color3.fromRGB(238, 229, 211)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = parent
	return label
end

local function buildStructure(model: Instance, cf: CFrame): Part
	for _, x in { -BOARD_WIDTH / 2 - 1, BOARD_WIDTH / 2 + 1 } do
		part(model, "BoardPost", Vector3.new(1.5, POST_HEIGHT, 1.5), cf * CFrame.new(x, POST_HEIGHT / 2, 0.5), Enum.Material.Wood, TIMBER_DARK)
		part(model, "BoardPostFooting", Vector3.new(2.6, 1.1, 2.6), cf * CFrame.new(x, 1.55, 0.5), Enum.Material.Rock, Color3.fromRGB(94, 88, 79), false)
		part(
			model,
			"BoardBrace",
			Vector3.new(0.55, 6.2, 0.55),
			cf * CFrame.new(x + (if x < 0 then -1.6 else 1.6), 4.2, 2) * CFrame.Angles(math.rad(-20), 0, math.rad(if x < 0 then 22 else -22)),
			Enum.Material.Wood,
			TIMBER,
			false
		)
	end

	for index = 1, 8 do
		part(
			model,
			`BoardBackingPlank{index}`,
			Vector3.new(BOARD_WIDTH + 1.2, BOARD_HEIGHT / 8 - 0.06, 0.65),
			cf * CFrame.new(0, BOARD_CENTER_Y - BOARD_HEIGHT / 2 + (index - 0.5) * BOARD_HEIGHT / 8, 0.25),
			Enum.Material.WoodPlanks,
			if index % 2 == 0 then Color3.fromRGB(91, 66, 45) else Color3.fromRGB(105, 76, 50)
		)
	end
	part(model, "BoardFrameTop", Vector3.new(BOARD_WIDTH + 2.5, 0.8, 1), cf * CFrame.new(0, BOARD_CENTER_Y + BOARD_HEIGHT / 2 + 0.4, 0), Enum.Material.Wood, TIMBER_DARK)
	part(model, "BoardFrameBottom", Vector3.new(BOARD_WIDTH + 2.5, 0.8, 1), cf * CFrame.new(0, BOARD_CENTER_Y - BOARD_HEIGHT / 2 - 0.4, 0), Enum.Material.Wood, TIMBER_DARK)

	local awning = part(
		model,
		"BoardAwning",
		Vector3.new(BOARD_WIDTH + 4, 0.35, 4.8),
		cf * CFrame.new(0, BOARD_CENTER_Y + BOARD_HEIGHT / 2 + 1.8, -1.6) * CFrame.Angles(math.rad(-15), 0, 0),
		Enum.Material.CorrodedMetal,
		Color3.fromRGB(78, 72, 65),
		false
	)
	for _, x in { -7, 7 } do
		local bulb = part(model, "BoardLampBulb", Vector3.new(0.7, 0.35, 0.7), awning.CFrame * CFrame.new(x, -0.45, -1.35), Enum.Material.Neon, Color3.fromRGB(255, 218, 157), false)
		bulb.CastShadow = false
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Bottom
		light.Color = Color3.fromRGB(255, 211, 151)
		light.Brightness = 1.8
		light.Range = 28
		light.Angle = 100
		light.Parent = bulb
	end

	return part(
		model,
		"QuestDisplay",
		Vector3.new(BOARD_WIDTH - 1.2, BOARD_HEIGHT - 1.1, 0.2),
		cf * CFrame.new(0, BOARD_CENTER_Y, -0.43),
		Enum.Material.Metal,
		PANEL,
		false
	)
end

local function addRoundedBorder(frame: Frame, color: Color3)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 3
	stroke.Transparency = 0.18
	stroke.Parent = frame
end

local function buildDisplay(display: Part)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "QuestDisplaySurface"
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(1400, 780)
	gui.MaxDistance = 170
	gui.LightInfluence = 0.18
	gui.Parent = display

	local title = textLabel(gui, "Title", UDim2.fromScale(0.04, 0.025), UDim2.fromScale(0.92, 0.1))
	title.Font = Enum.Font.GothamBlack
	title.Text = "DAILY QUESTS"
	title.TextColor3 = Color3.fromRGB(255, 208, 70)
	title.TextXAlignment = Enum.TextXAlignment.Center

	local timer = textLabel(gui, "ResetTimer", UDim2.fromScale(0.1, 0.125), UDim2.fromScale(0.8, 0.055))
	timer.Text = `Refreshing in {DailyQuestConfig.DescribeTimeUntilReset()}`
	timer.TextColor3 = Color3.fromRGB(230, 219, 202)
	timer.TextXAlignment = Enum.TextXAlignment.Center

	local sharedIds = DailyQuestConfig.SharedDailyIds()
	for index = 1, DailyQuestConfig.QUESTS_PER_DAY do
		local definition = assert(DailyQuestConfig.Get(sharedIds[index]))
		local row = Instance.new("Frame")
		row.Name = `QuestRow{index}`
		row.Position = UDim2.fromScale(0.045, 0.2 + (index - 1) * 0.255)
		row.Size = UDim2.fromScale(0.91, 0.22)
		row.BackgroundColor3 = Color3.fromRGB(42, 29, 25)
		row.BackgroundTransparency = 0.04
		row:SetAttribute("QuestId", definition.id)
		row:SetAttribute("RewardScrap", definition.rewardScrap)
		row.Parent = gui
		addRoundedBorder(row, ACCENT)

		local name = textLabel(row, "QuestName", UDim2.fromScale(0.025, 0.08), UDim2.fromScale(0.62, 0.28))
		name.Font = Enum.Font.GothamBold
		name.Text = definition.name
		local objective = textLabel(row, "Objective", UDim2.fromScale(0.025, 0.36), UDim2.fromScale(0.69, 0.26))
		objective.Text = DailyQuestConfig.DescribeProgress(definition, 0)
		objective.TextColor3 = Color3.fromRGB(209, 200, 187)

		local reward = textLabel(row, "Reward", UDim2.fromScale(0.73, 0.12), UDim2.fromScale(0.24, 0.34))
		reward.Font = Enum.Font.GothamBold
		reward.Text = `+{definition.rewardScrap} SCRAP`
		reward.TextColor3 = Color3.fromRGB(255, 196, 55)
		reward.TextXAlignment = Enum.TextXAlignment.Right

		local track = Instance.new("Frame")
		track.Name = "ProgressTrack"
		track.Position = UDim2.fromScale(0.025, 0.69)
		track.Size = UDim2.fromScale(0.68, 0.12)
		track.BackgroundColor3 = Color3.fromRGB(20, 16, 14)
		track.Parent = row
		addRoundedBorder(track, Color3.fromRGB(87, 69, 55))
		local fill = Instance.new("Frame")
		fill.Name = "ProgressFill"
		fill.Size = UDim2.fromScale(0, 1)
		fill.BackgroundColor3 = ACCENT
		fill.BorderSizePixel = 0
		fill.Parent = track
		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = UDim.new(1, 0)
		fillCorner.Parent = fill

		local status = textLabel(row, "Status", UDim2.fromScale(0.73, 0.63), UDim2.fromScale(0.24, 0.2))
		status.Font = Enum.Font.GothamBold
		status.Text = "INCOMPLETE"
		status.TextColor3 = Color3.fromRGB(230, 219, 202)
		status.TextXAlignment = Enum.TextXAlignment.Right
	end
end

local function buildSurroundings(model: Instance, cf: CFrame)
	part(model, "BoardCrate", Vector3.new(2.8, 2.2, 2.5), cf * CFrame.new(-BOARD_WIDTH / 2 - 3, 2.1, -1.5) * CFrame.Angles(0, math.rad(14), 0), Enum.Material.WoodPlanks, Color3.fromRGB(97, 72, 48), false)
	part(model, "BoardBarrel", Vector3.new(2.1, 3, 2.1), cf * CFrame.new(BOARD_WIDTH / 2 + 3, 2.5, -1.8), Enum.Material.CorrodedMetal, Color3.fromRGB(91, 76, 58), false)
end

function DailyQuestBoardGenerator.Build(parent: Instance, boardCFrame: CFrame): Model
	GeneratorKit.CleanupPrevious(parent, "DailyQuestBoard")
	local model = Instance.new("Model")
	model.Name = "DailyQuestBoard"
	model:SetAttribute("QuestSlots", DailyQuestConfig.QUESTS_PER_DAY)
	model:SetAttribute("SharedDayIndex", DailyQuestConfig.CurrentDayIndex())

	local display = buildStructure(model, boardCFrame)
	buildDisplay(display)
	buildSurroundings(model, boardCFrame)

	local anchor = part(model, "FacilityAnchor", Vector3.new(BOARD_WIDTH, 8, 3), boardCFrame * CFrame.new(0, 6, -3), Enum.Material.ForceField, ACCENT, false)
	anchor.Transparency = 1
	anchor:SetAttribute("FacilityId", "DailyQuests")
	CollectionService:AddTag(anchor, "HavenFacility")

	GeneratorKit.Finalize(model, "QuestDisplay")
	model.Parent = parent
	return model
end

return DailyQuestBoardGenerator
