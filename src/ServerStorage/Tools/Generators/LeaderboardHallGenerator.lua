--!strict
-- Phase 3A: promoted from a wide wall to Survivor Haven's landmark — a real
-- status monument, not a kiosk. Local -Z is "front" throughout this file
-- (CFrame.new(position, lookAt) orients -Z toward lookAt, and SurfaceGui's
-- default Face = Front renders on a part's -Z face) — every panel/prop below
-- is offset toward -Z so it sits proud of the wall, facing the plaza the
-- player approaches from.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LeaderboardConfig = require(ReplicatedStorage.Shared.Config.LeaderboardConfig)
local GeneratorKit = require(script.Parent.GeneratorKit)

local LeaderboardHallGenerator = {}

-- Phase 3A: enlarged again — 28x14 (Phase 1 correction's "large and
-- prominent" fix) still read as too small to notice from spawn. 40x22 with
-- taller towers and a viewing apron is sized to be an obvious landmark while
-- staying inside the facility's own verified clearance budget (bounding
-- radius ~26, checked against Base Gate on the same bearing and the nudged
-- Market Rest Nook — see the Phase 3A plan).
local WALL_WIDTH = 40
local WALL_HEIGHT = 22
local WALL_THICKNESS = 1.2
local TOWER_WIDTH = 5
local TOWER_HEIGHT = 28
-- Phase 3B: panels enlarged (9x12 -> 10x16 studs) so 3 real categories at
-- up to 10 rows each read cleanly instead of cramped — the wall is already
-- 22 tall, so there's real headroom below the crown for a taller panel.
local PANEL_WIDTH = 10
local PANEL_HEIGHT = 16
local PANEL_SPACING = 14
local APRON_DEPTH = 10
local APRON_WIDTH = WALL_WIDTH + 2 * TOWER_WIDTH + 4
local ROW_HEIGHT = 34
local ROW_GAP = 4

local function buildPanel(parent: Instance, wallCenterCFrame: CFrame, index: number, category: LeaderboardConfig.LeaderboardCategory, accentColor: Color3)
	local offsetX = (index - 2) * PANEL_SPACING
	local panelCFrame = wallCenterCFrame * CFrame.new(offsetX, 0, -(WALL_THICKNESS / 2 + 0.05))

	local panel = GeneratorKit.NewPart({
		Name = `Panel{index}`,
		Size = Vector3.new(PANEL_WIDTH, PANEL_HEIGHT, 0.1),
		CFrame = panelCFrame,
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(30, 30, 36),
		CanCollide = false,
		Parent = parent,
	})

	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = "PanelDisplay"
	surfaceGui.Face = Enum.NormalId.Front
	surfaceGui.LightInfluence = 0
	surfaceGui.PixelsPerStud = 36
	surfaceGui.Parent = panel

	local root = Instance.new("Frame")
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.Parent = surfaceGui

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 16)
	padding.PaddingRight = UDim.new(0, 16)
	padding.PaddingTop = UDim.new(0, 16)
	padding.PaddingBottom = UDim.new(0, 16)
	padding.Parent = root

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, ROW_GAP)
	layout.Parent = root

	local header = Instance.new("TextLabel")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, 40)
	header.Font = Enum.Font.GothamBlack
	header.TextScaled = true
	header.TextColor3 = accentColor
	header.Text = category.Title
	header.LayoutOrder = 0
	header.Parent = root

	local divider = Instance.new("Frame")
	divider.Name = "Divider"
	divider.Size = UDim2.new(1, 0, 0, 3)
	divider.BackgroundColor3 = accentColor
	divider.BorderSizePixel = 0
	divider.LayoutOrder = 1
	divider.Parent = root

	-- Still placeholder rows throughout — no backend leaderboard/stats
	-- system exists yet (see LeaderboardConfig's header comment); the row
	-- count/title are real, the ranked names/values are not.
	for i = 1, category.RowCount do
		local row = Instance.new("TextLabel")
		row.Name = `Row{i}`
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
		row.Font = Enum.Font.Code
		row.TextSize = 20
		row.TextColor3 = Color3.new(1, 1, 1)
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.Text = `{i}.  ———`
		row.LayoutOrder = i + 1
		row.Parent = root
	end
end

-- `position`/`origin` follow the same convention CivicBuildingGenerator.Build
-- already uses: the hall faces `origin.Position` (the plaza center)
-- regardless of which angle it's placed at.
function LeaderboardHallGenerator.Build(parent: Instance, origin: CFrame, position: Vector3, accentColor: Color3): Model
	GeneratorKit.CleanupPrevious(parent, "Leaderboards")

	local model = Instance.new("Model")
	model.Name = "Leaderboards"

	local wallCFrame = CFrame.new(position, origin.Position)
	local wallCenterCFrame = wallCFrame * CFrame.new(0, WALL_HEIGHT / 2 - 0.3, 0)

	GeneratorKit.NewPart({
		Name = "HallWall",
		Size = Vector3.new(WALL_WIDTH, WALL_HEIGHT, WALL_THICKNESS),
		CFrame = wallCFrame * CFrame.new(0, WALL_HEIGHT / 2, 0),
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(46, 44, 50),
		Parent = model,
	})

	-- A wide, +0.4-stud raised viewing apron in front of the wall — "add a
	-- viewing area in front" and "status monument, not a kiosk." Extends
	-- toward the plaza (-Z, away from Base Gate, which sits further out
	-- along the same bearing) so it never threatens that footprint.
	local apronCFrame = wallCFrame * CFrame.new(0, 0.2, -APRON_DEPTH / 2 - WALL_THICKNESS / 2)
	GeneratorKit.NewPart({
		Name = "ViewingApron",
		Size = Vector3.new(APRON_WIDTH, 0.4, APRON_DEPTH),
		CFrame = apronCFrame,
		Material = Enum.Material.Concrete,
		Color = Color3.fromRGB(64, 62, 66),
		Parent = model,
	})
	for _, side in { -1, 1 } do
		GeneratorKit.NewPart({
			Name = if side < 0 then "ApronRailLeft" else "ApronRailRight",
			Size = Vector3.new(0.6, 1.4, APRON_DEPTH),
			CFrame = apronCFrame * CFrame.new(side * (APRON_WIDTH / 2 - 0.3), 0.9, 0),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(58, 56, 60),
			CanCollide = false,
			Parent = model,
		})
	end

	-- 2 flanking tower pillars, taller than the wall — the "large, prominent"
	-- landmark silhouette, framing the panel wall between them.
	for _, sign in { -1, 1 } do
		GeneratorKit.NewPart({
			Name = if sign < 0 then "TowerLeft" else "TowerRight",
			Size = Vector3.new(TOWER_WIDTH, TOWER_HEIGHT, TOWER_WIDTH),
			CFrame = wallCFrame * CFrame.new(sign * (WALL_WIDTH / 2 + TOWER_WIDTH / 2), TOWER_HEIGHT / 2, 0),
			Material = Enum.Material.Slate,
			Color = Color3.fromRGB(40, 38, 44),
			Parent = model,
		})

		-- A stepped cap on each tower — reads as deliberate monument
		-- architecture rather than a plain pillar stub.
		GeneratorKit.NewPart({
			Name = if sign < 0 then "TowerCapLeft" else "TowerCapRight",
			Size = Vector3.new(TOWER_WIDTH + 1, 1.2, TOWER_WIDTH + 1),
			CFrame = wallCFrame * CFrame.new(sign * (WALL_WIDTH / 2 + TOWER_WIDTH / 2), TOWER_HEIGHT + 0.6, 0),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(54, 52, 58),
			CanCollide = false,
			Parent = model,
		})

		local towerLight = Instance.new("PointLight")
		towerLight.Color = accentColor
		towerLight.Brightness = 1.6
		towerLight.Range = 22
		towerLight.Parent = GeneratorKit.NewPart({
			Name = if sign < 0 then "TowerLightLeft" else "TowerLightRight",
			Size = Vector3.new(0.2, 0.2, 0.2),
			CFrame = wallCFrame * CFrame.new(sign * (WALL_WIDTH / 2 + TOWER_WIDTH / 2), TOWER_HEIGHT - 1, -TOWER_WIDTH / 2 - 0.2),
			Transparency = 1,
			CanCollide = false,
			Parent = model,
		})
		CollectionService:AddTag(towerLight, "AmbientFlicker")
	end

	for index, category in LeaderboardConfig.Categories do
		buildPanel(model, wallCenterCFrame, index, category, accentColor)
	end

	-- Integrated sign frame spanning the top of the wall — a real crown
	-- structure, not a thin floating neon bar.
	local crownCFrame = wallCFrame * CFrame.new(0, WALL_HEIGHT + 1.6, 0)
	GeneratorKit.NewPart({
		Name = "CrownFrame",
		Size = Vector3.new(WALL_WIDTH * 0.7, 2.6, 0.6),
		CFrame = crownCFrame,
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(40, 38, 44),
		CanCollide = false,
		Parent = model,
	})

	local crown = GeneratorKit.NewPart({
		Name = "CrownSign",
		Size = Vector3.new(WALL_WIDTH * 0.66, 1.8, 0.25),
		CFrame = crownCFrame * CFrame.new(0, 0, -0.5),
		Material = Enum.Material.Neon,
		Color = accentColor,
		Transparency = 0.15,
		CanCollide = false,
		Parent = model,
	})

	local crownBillboard = Instance.new("BillboardGui")
	crownBillboard.Name = "CrownLabel"
	crownBillboard.Size = UDim2.fromOffset(340, 60)
	crownBillboard.MaxDistance = 200
	crownBillboard.LightInfluence = 0
	crownBillboard.Parent = crown

	local crownLabel = Instance.new("TextLabel")
	crownLabel.BackgroundTransparency = 1
	crownLabel.Size = UDim2.fromScale(1, 1)
	crownLabel.Font = Enum.Font.GothamBlack
	crownLabel.TextScaled = true
	crownLabel.TextColor3 = Color3.new(1, 1, 1)
	crownLabel.Text = "LEADERBOARDS"
	crownLabel.Parent = crownBillboard

	-- (The 2 tower lights above are the only dynamic lights on this
	-- structure — stays inside the "avoid too many dynamic lights"
	-- performance rule; no separate edge-light pass needed now that the
	-- towers themselves carry the flanking light.)

	-- Phase 3B: deliberately no FacilityAnchor/HavenFacility tag here — the
	-- brief is explicit that the Leaderboard Hall should be read passively,
	-- with no "E / View" prompt and no floating hologram info card. With no
	-- tagged anchor, FacilityController's tag-scan loop simply never
	-- attaches anything to this structure; this is a pure omission, not a
	-- special case handled elsewhere.

	GeneratorKit.Finalize(model, "HallWall")
	model.Parent = parent

	return model
end

return LeaderboardHallGenerator
