--!strict
-- Consistent, restrained world-mounted labels. These stay fixed to physical
-- architecture and never behave like HUD-scale billboards.
local GeneratorKit = require(script.Parent.GeneratorKit)

local WorldFacilityLabelGenerator = {}
export type Options = { Title: string, Subtitle: string?, AccentColor: Color3?, Width: number?, MaxDistance: number? }

function WorldFacilityLabelGenerator.Build(parent: Instance, labelCFrame: CFrame, options: Options): Part
	local width = options.Width or 12
	local plate = GeneratorKit.NewPart({
		Name = "WorldLabel",
		Size = Vector3.new(width, 3.2, 0.35),
		CFrame = labelCFrame,
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(28, 31, 38),
		CanCollide = false,
		Parent = parent,
	})
	-- Give validators and tooling an explicit contract to select. A recursive
	-- name search can accidentally resolve another decorative label below the
	-- same facility model as those interiors evolve.
	plate:SetAttribute("IsCanonicalWorldFacilityLabel", true)
	plate:SetAttribute("ConfiguredWidth", width)
	plate:SetAttribute("ConfiguredHeight", 3.2)
	local strip = GeneratorKit.NewPart({
		Name = "LabelAccent",
		Size = Vector3.new(width, 0.16, 0.12),
		CFrame = labelCFrame * CFrame.new(0, -1.42, -0.22),
		Material = Enum.Material.Neon,
		Color = options.AccentColor or Color3.fromRGB(185, 151, 92),
		CanCollide = false,
		Parent = parent,
	})
	strip.CastShadow = false
	local gui = Instance.new("SurfaceGui")
	gui.Name = "LabelSurface"
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(math.floor(width * 70), 220)
	gui.MaxDistance = options.MaxDistance or 82
	gui.LightInfluence = 0.35
	gui.Parent = plate
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromScale(0.04, 0.08)
	title.Size = UDim2.fromScale(0.92, 0.54)
	title.Font = Enum.Font.GothamBold
	title.Text = string.upper(options.Title)
	title.TextColor3 = Color3.fromRGB(236, 232, 220)
	title.TextScaled = true
	title.Parent = gui
	if options.Subtitle then
		local subtitle = Instance.new("TextLabel")
		subtitle.Name = "Subtitle"
		subtitle.BackgroundTransparency = 1
		subtitle.Position = UDim2.fromScale(0.06, 0.65)
		subtitle.Size = UDim2.fromScale(0.88, 0.2)
		subtitle.Font = Enum.Font.GothamMedium
		subtitle.Text = string.upper(options.Subtitle)
		subtitle.TextColor3 = options.AccentColor or Color3.fromRGB(205, 175, 118)
		subtitle.TextScaled = true
		subtitle.Parent = gui
	end
	return plate
end

return WorldFacilityLabelGenerator
