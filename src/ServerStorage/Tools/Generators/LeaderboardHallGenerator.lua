--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HavenLayoutConfig = require(ReplicatedStorage.Shared.Config.HavenLayoutConfig)
local LeaderboardConfig = require(ReplicatedStorage.Shared.Config.LeaderboardConfig)
local GeneratorKit = require(script.Parent.GeneratorKit)
local WorldFacilityLabelGenerator = require(script.Parent.WorldFacilityLabelGenerator)

local LeaderboardHallGenerator = {}

type LeaderboardCategory = {
	Id: string,
	Title: string,
	RowCount: number,
}

local HALL_WIDTH = 60
local PANEL_WIDTH = 17.5
local PANEL_HEIGHT = 18
local GOLD = Color3.fromRGB(231, 184, 61)
local SILVER = Color3.fromRGB(190, 201, 213)
local BRONZE = Color3.fromRGB(193, 119, 68)
local STANDARD = Color3.fromRGB(104, 158, 185)

local function newLabel(parent: Instance, name: string, position: UDim2, size: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Font = Enum.Font.GothamMedium
	label.TextColor3 = Color3.fromRGB(224, 229, 229)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = parent
	return label
end

local function rankColor(rank: number): Color3
	if rank == 1 then
		return GOLD
	elseif rank == 2 then
		return SILVER
	elseif rank == 3 then
		return BRONZE
	end
	return STANDARD
end

local function medalName(rank: number): string
	if rank == 1 then
		return "GOLD"
	elseif rank == 2 then
		return "SILVER"
	elseif rank == 3 then
		return "BRONZE"
	end
	return ""
end

local function buildRankRow(parent: Instance, rank: number)
	local color = rankColor(rank)
	local rowHeight = 0.066
	local rowGap = 0.0065
	local row = Instance.new("Frame")
	row.Name = `Rank{rank}`
	row.BackgroundColor3 = if rank <= 3 then color:Lerp(Color3.fromRGB(18, 22, 27), 0.78) else Color3.fromRGB(35, 41, 47)
	row.BackgroundTransparency = if rank <= 3 then 0.08 else 0.2
	row.BorderSizePixel = 0
	row.Position = UDim2.fromScale(0.04, 0.215 + (rank - 1) * (rowHeight + rowGap))
	row.Size = UDim2.fromScale(0.92, rowHeight)
	row:SetAttribute("Rank", rank)
	row:SetAttribute("AwardType", medalName(rank))
	row.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.18, 0)
	corner.Parent = row

	local rankBadge = newLabel(row, "Medal", UDim2.fromScale(0.015, 0.08), UDim2.fromScale(0.14, 0.84))
	rankBadge.BackgroundTransparency = 0
	rankBadge.BackgroundColor3 = color
	rankBadge.Font = Enum.Font.GothamBold
	rankBadge.Text = `#{rank}`
	rankBadge.TextColor3 = Color3.fromRGB(19, 23, 27)
	rankBadge.TextScaled = true
	rankBadge.TextXAlignment = Enum.TextXAlignment.Center
	local badgeCorner = Instance.new("UICorner")
	badgeCorner.CornerRadius = UDim.new(1, 0)
	badgeCorner.Parent = rankBadge

	local survivor = newLabel(row, "Survivor", UDim2.fromScale(0.18, 0), UDim2.fromScale(if rank <= 3 then 0.49 else 0.79, 1))
	survivor.Font = if rank <= 3 then Enum.Font.GothamBold else Enum.Font.GothamMedium
	survivor.Text = "AWAITING SURVIVOR"
	survivor.TextColor3 = if rank <= 3 then color else Color3.fromRGB(221, 226, 227)
	survivor.TextScaled = true
	survivor.TextTruncate = Enum.TextTruncate.AtEnd

	if rank <= 3 then
		local award = newLabel(row, "Award", UDim2.fromScale(0.69, 0), UDim2.fromScale(0.28, 1))
		award.Font = Enum.Font.GothamBold
		award.Text = medalName(rank)
		award.TextColor3 = color
		award.TextScaled = true
		award.TextXAlignment = Enum.TextXAlignment.Right
	end
end

local function buildPanel(parent: Instance, cf: CFrame, index: number, category: LeaderboardCategory, accent: Color3)
	local panelPart = GeneratorKit.NewPart({
		Name = `LeaderboardPanel{index}`,
		Size = Vector3.new(PANEL_WIDTH, PANEL_HEIGHT, 0.35),
		CFrame = cf * CFrame.new((index - 2) * 19.2, 13.4, -1.2),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(24, 29, 35),
		CanCollide = false,
		Parent = parent,
	})
	panelPart:SetAttribute("LeaderboardCategoryId", category.Id)
	panelPart:SetAttribute("LeaderboardRowCount", category.RowCount)
	panelPart:SetAttribute("PanelBottomWorldHeight", 4.4)
	panelPart:SetAttribute("RankTenBottomPaddingScale", 0.0665)

	local gui = Instance.new("SurfaceGui")
	gui.Name = "TopTenDisplay"
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(700, 820)
	gui.LightInfluence = 0.15
	gui.MaxDistance = 190
	gui.Parent = panelPart

	local header = Instance.new("Frame")
	header.Name = "CategoryHeader"
	header.BackgroundColor3 = Color3.fromRGB(31, 42, 51)
	header.BorderSizePixel = 0
	header.Position = UDim2.fromScale(0.04, 0.035)
	header.Size = UDim2.fromScale(0.92, 0.155)
	header.Parent = gui
	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = UDim.new(0.12, 0)
	headerCorner.Parent = header
	local stripe = Instance.new("Frame")
	stripe.Name = "AccentStripe"
	stripe.BackgroundColor3 = accent
	stripe.BorderSizePixel = 0
	stripe.Size = UDim2.fromScale(0.025, 1)
	stripe.Parent = header

	local title = newLabel(header, "Title", UDim2.fromScale(0.07, 0.06), UDim2.fromScale(0.89, 0.58))
	title.Font = Enum.Font.GothamBold
	title.Text = category.Title
	title.TextColor3 = Color3.fromRGB(235, 239, 239)
	title.TextScaled = true
	local subtitle = newLabel(header, "Subtitle", UDim2.fromScale(0.07, 0.62), UDim2.fromScale(0.89, 0.25))
	subtitle.Font = Enum.Font.GothamBold
	subtitle.Text = "TOP 10 SURVIVORS"
	subtitle.TextColor3 = accent
	subtitle.TextScaled = true

	local rowCount = math.min(category.RowCount, 10)
	for rank = 1, rowCount do
		buildRankRow(gui, rank)
	end
end

function LeaderboardHallGenerator.Build(
	parent: Instance,
	origin: CFrame,
	position: Vector3,
	accentColor: Color3
): Model
	GeneratorKit.CleanupPrevious(parent, "Leaderboards")
	local model = Instance.new("Model")
	model.Name = "Leaderboards"
	local spawn = origin:PointToWorldSpace(HavenLayoutConfig.SPAWN_LOCAL_POSITION)
	local cf = CFrame.lookAt(position, Vector3.new(spawn.X, position.Y, spawn.Z))

	GeneratorKit.NewPart({
		Name = "RecordsHallFoundation",
		Size = Vector3.new(HALL_WIDTH + 5, 1, 17),
		CFrame = cf * CFrame.new(0, 0.5, -5.5),
		Material = Enum.Material.Pavement,
		Color = Color3.fromRGB(72, 76, 79),
		Parent = model,
	})
	GeneratorKit.NewPart({
		Name = "RankingWall",
		Size = Vector3.new(HALL_WIDTH, 27, 2.2),
		CFrame = cf * CFrame.new(0, 13.5, 0),
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(37, 42, 49),
		Parent = model,
	})
	GeneratorKit.NewPart({
		Name = "RecordsCanopy",
		Size = Vector3.new(HALL_WIDTH + 5, 1.3, 6),
		CFrame = cf * CFrame.new(0, 27.6, -1.7),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(47, 54, 62),
		Parent = model,
	})
	GeneratorKit.NewPart({
		Name = "RecordsHeaderBacking",
		Size = Vector3.new(HALL_WIDTH - 4, 4.2, 0.5),
		CFrame = cf * CFrame.new(0, 24.7, -1.35),
		Material = Enum.Material.DiamondPlate,
		Color = Color3.fromRGB(49, 61, 70),
		CanCollide = false,
		Parent = model,
	})

	for _, x in { -(HALL_WIDTH / 2 + 1.8), HALL_WIDTH / 2 + 1.8 } do
		GeneratorKit.NewPart({
			Name = "RecordsHallTower",
			Size = Vector3.new(3.6, 30, 5),
			CFrame = cf * CFrame.new(x, 15, 0),
			Material = Enum.Material.Concrete,
			Color = Color3.fromRGB(42, 47, 54),
			Parent = model,
		})
		GeneratorKit.NewPart({
			Name = "ViewingRail",
			Size = Vector3.new(0.8, 2.3, 13),
			CFrame = cf * CFrame.new(x, 1.15, -7),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(56, 62, 67),
			Parent = model,
		})
	end

	for index, category in LeaderboardConfig.Categories do
		buildPanel(model, cf, index, category, accentColor)
	end

	for _, x in { -25, -8.5, 8.5, 25 } do
		local practical = GeneratorKit.NewPart({
			Name = "RecordsHallPractical",
			Size = Vector3.new(4, 0.45, 0.7),
			CFrame = cf * CFrame.new(x, 26.8, -3.2),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(107, 190, 224),
			CanCollide = false,
			Parent = model,
		})
		local light = Instance.new("SurfaceLight")
		light.Face = Enum.NormalId.Bottom
		light.Color = Color3.fromRGB(130, 203, 232)
		light.Brightness = 0.75
		light.Range = 15
		light.Angle = 95
		light.Parent = practical
	end

	WorldFacilityLabelGenerator.Build(model, cf * CFrame.new(0, 25, -1.7), {
		Title = "SURVIVOR RECORDS HALL",
		Subtitle = "TOP 10  |  HONOR THE BEST",
		AccentColor = accentColor,
		Width = 31,
		MaxDistance = 190,
	})
	GeneratorKit.Finalize(model, "RankingWall")
	model.Parent = parent
	return model
end

return LeaderboardHallGenerator
