--!strict
-- Phase 3B: shrunk from a 2-ended terrace (arch + track + countdown board on
-- one end, vertical rail + pedestal on the other) into one small Season
-- Terminal touchpoint. Season Pass and the Eclipse Event are now UI-first
-- (see ShopController) — this world structure is a visual-only landmark,
-- not an interactive building. No FacilityAnchor/prompt, same "look at it,
-- don't interact with it" spirit as the Leaderboard Hall.

local CollectionService = game:GetService("CollectionService")
local GeneratorKit = require(script.Parent.GeneratorKit)

local SeasonPavilionGenerator = {}

local PEDESTAL_HEIGHT = 3.4
local MAST_HEIGHT = 7

-- `position` is the caller's choice of where to place this touchpoint —
-- BuildHavenDistricts uses the midpoint of the old SeasonEvent/SeasonPass
-- facility positions so it stays in the same general area without needing
-- any HavenFacilityConfig changes.
function SeasonPavilionGenerator.Build(parent: Instance, origin: CFrame, position: Vector3, accentColor: Color3): Model
	GeneratorKit.CleanupPrevious(parent, "SeasonTerminal")

	local model = Instance.new("Model")
	model.Name = "SeasonTerminal"

	local terminalCFrame = CFrame.new(position, origin.Position)

	GeneratorKit.NewPart({
		Name = "TerminalBase",
		Size = Vector3.new(2.4, 0.6, 2.4),
		CFrame = terminalCFrame * CFrame.new(0, 0.3, 0),
		Material = Enum.Material.Concrete,
		Color = Color3.fromRGB(70, 66, 72),
		Parent = model,
	})

	GeneratorKit.NewPart({
		Name = "TerminalPedestal",
		Size = Vector3.new(1.6, PEDESTAL_HEIGHT, 1.6),
		CFrame = terminalCFrame * CFrame.new(0, 0.6 + PEDESTAL_HEIGHT / 2, 0),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(52, 50, 56),
		Parent = model,
	})

	local screen = GeneratorKit.NewPart({
		Name = "TerminalScreen",
		Size = Vector3.new(1.3, 1, 0.15),
		CFrame = terminalCFrame * CFrame.new(0, 0.6 + PEDESTAL_HEIGHT + 0.1, 0) * CFrame.Angles(math.rad(-20), 0, 0),
		Material = Enum.Material.Neon,
		Color = accentColor,
		Transparency = 0.2,
		CanCollide = false,
		Parent = model,
	})
	local screenLight = Instance.new("PointLight")
	screenLight.Color = accentColor
	screenLight.Brightness = 1.6
	screenLight.Range = 14
	screenLight.Parent = screen
	CollectionService:AddTag(screenLight, "AmbientFlicker")

	-- Banner mast -- the only "landmark" cue this small touchpoint needs;
	-- the real Season Pass/Event experience lives entirely in the Shop UI.
	local mastCFrame = terminalCFrame * CFrame.new(2.2, 0, 0)
	GeneratorKit.NewPart({
		Name = "BannerMast",
		Size = Vector3.new(0.4, MAST_HEIGHT, 0.4),
		CFrame = mastCFrame * CFrame.new(0, MAST_HEIGHT / 2, 0),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(48, 46, 52),
		CanCollide = false,
		Parent = model,
	})
	local banner = GeneratorKit.NewPart({
		Name = "MastBanner",
		Size = Vector3.new(1.6, 2.8, 0.1),
		CFrame = mastCFrame * CFrame.new(0.9, MAST_HEIGHT - 1.6, 0),
		Material = Enum.Material.Fabric,
		Color = accentColor,
		CanCollide = false,
		Parent = model,
	})
	CollectionService:AddTag(banner, "AmbientSway")

	GeneratorKit.Finalize(model, "TerminalBase")
	model.Parent = parent

	return model
end

return SeasonPavilionGenerator
