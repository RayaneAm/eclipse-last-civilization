--!strict
-- Phase 3B: a shared, solid, opaque part-built survivor figure — the base
-- body reused by the Quest Giver ("Survivor Guide") and the Survivor
-- Market's Merchant, so both get a consistent look without duplicating the
-- same ~15-part body twice. Deliberately NOT the translucent ForceField
-- hologram look used elsewhere in this project (the old Quest Giver figure,
-- CapsuleLab's scientist stub) — this phase explicitly asks for a real-
-- looking person, not an abstract hologram silhouette, for these two NPCs.

local GeneratorKit = require(script.Parent.GeneratorKit)

local SurvivorFigureGenerator = {}

export type FigureOptions = {
	Backpack: boolean?,
	Binoculars: boolean?,
	Apron: boolean?,
	AccentColor: Color3?, -- small trim only (belt, straps) — the outfit itself stays a fixed survival palette
}

local OUTFIT_JACKET = Color3.fromRGB(94, 92, 70) -- olive
local OUTFIT_PANTS = Color3.fromRGB(70, 62, 50) -- brown
local SKIN = Color3.fromRGB(196, 158, 128)

function SurvivorFigureGenerator.Build(parent: Instance, figureCFrame: CFrame, options: FigureOptions?): Model
	local opts = options or {}
	local accent = opts.AccentColor or Color3.fromRGB(150, 120, 70)

	local figure = Instance.new("Model")
	figure.Name = "SurvivorFigure"

	for _, side in { -1, 1 } do
		GeneratorKit.NewPart({
			Name = if side < 0 then "LegLeft" else "LegRight",
			Size = Vector3.new(0.7, 2, 0.7),
			CFrame = figureCFrame * CFrame.new(side * 0.4, 1, 0),
			Material = Enum.Material.Fabric,
			Color = OUTFIT_PANTS,
			CanCollide = false,
			Parent = figure,
		})
	end

	GeneratorKit.NewPart({
		Name = "Torso",
		Size = Vector3.new(2, 2.2, 1.1),
		CFrame = figureCFrame * CFrame.new(0, 3.1, 0),
		Material = Enum.Material.Fabric,
		Color = OUTFIT_JACKET,
		CanCollide = false,
		Parent = figure,
	})

	for _, side in { -1, 1 } do
		GeneratorKit.NewPart({
			Name = if side < 0 then "ArmLeft" else "ArmRight",
			Size = Vector3.new(0.6, 2, 0.6),
			CFrame = figureCFrame * CFrame.new(side * 1.3, 3, 0),
			Material = Enum.Material.Fabric,
			Color = OUTFIT_JACKET,
			CanCollide = false,
			Parent = figure,
		})
	end

	GeneratorKit.NewPart({
		Name = "Head",
		Size = Vector3.new(1, 1, 1),
		CFrame = figureCFrame * CFrame.new(0, 4.7, 0),
		Material = Enum.Material.SmoothPlastic,
		Color = SKIN,
		CanCollide = false,
		Parent = figure,
	})

	GeneratorKit.NewPart({
		Name = "Belt",
		Size = Vector3.new(2.05, 0.3, 1.15),
		CFrame = figureCFrame * CFrame.new(0, 2.1, 0),
		Material = Enum.Material.Metal,
		Color = accent,
		CanCollide = false,
		Parent = figure,
	})

	if opts.Backpack then
		GeneratorKit.NewPart({
			Name = "Backpack",
			Size = Vector3.new(1.5, 1.8, 0.7),
			CFrame = figureCFrame * CFrame.new(0, 3.2, 0.85),
			Material = Enum.Material.Fabric,
			Color = Color3.fromRGB(60, 56, 44),
			CanCollide = false,
			Parent = figure,
		})
		GeneratorKit.NewPart({
			Name = "BackpackStrap",
			Size = Vector3.new(1.7, 0.2, 0.15),
			CFrame = figureCFrame * CFrame.new(0, 3.9, 0.5),
			Material = Enum.Material.Fabric,
			Color = accent,
			CanCollide = false,
			Parent = figure,
		})
	end

	if opts.Binoculars then
		GeneratorKit.NewPart({
			Name = "Binoculars",
			Size = Vector3.new(0.7, 0.35, 0.3),
			CFrame = figureCFrame * CFrame.new(0, 3.6, -0.6) * CFrame.Angles(math.rad(10), 0, 0),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(40, 40, 42),
			CanCollide = false,
			Parent = figure,
		})
		GeneratorKit.NewPart({
			Name = "BinocularsStrap",
			Size = Vector3.new(0.12, 1.4, 0.12),
			CFrame = figureCFrame * CFrame.new(0, 3.95, -0.3) * CFrame.Angles(math.rad(20), 0, 0),
			Material = Enum.Material.Fabric,
			Color = Color3.fromRGB(40, 36, 30),
			CanCollide = false,
			Parent = figure,
		})
	end

	if opts.Apron then
		GeneratorKit.NewPart({
			Name = "Apron",
			Size = Vector3.new(1.7, 1.9, 0.15),
			CFrame = figureCFrame * CFrame.new(0, 2.6, -0.58) * CFrame.Angles(math.rad(-4), 0, 0),
			Material = Enum.Material.Fabric,
			Color = Color3.fromRGB(120, 92, 60),
			CanCollide = false,
			Parent = figure,
		})
	end

	GeneratorKit.Finalize(figure, "Torso")
	figure.Parent = parent
	return figure
end

return SurvivorFigureGenerator
