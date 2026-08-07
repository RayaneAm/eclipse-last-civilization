--!strict
-- Shared helpers for the procedural landmark generators. Kept deliberately
-- small: part creation with sane defaults, idempotent cleanup, and a seeded
-- RNG constructor so reruns of a generator are deterministic (same params in
-- -> same layout out) rather than re-rolling random debris every rebuild.

local GeneratorKit = {}

export type PartProps = {
	Name: string?,
	Size: Vector3,
	CFrame: CFrame,
	Material: Enum.Material?,
	Color: Color3?,
	Shape: Enum.PartType?,
	Transparency: number?,
	CanCollide: boolean?,
	Parent: Instance?,
}

function GeneratorKit.NewPart(props: PartProps): Part
	local part = Instance.new("Part")
	part.Name = props.Name or "Part"
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.Material = props.Material or Enum.Material.Rock
	part.Color = props.Color or Color3.fromRGB(120, 120, 120)
	if props.Shape then
		part.Shape = props.Shape
	end
	part.Transparency = props.Transparency or 0
	part.CanCollide = if props.CanCollide == nil then true else props.CanCollide
	part.Anchored = true
	part.CastShadow = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if props.Parent then
		part.Parent = props.Parent
	end
	return part
end

-- Destroys any previous generated instance with this name under `parent` so
-- re-running a generator never leaves duplicate/orphaned geometry behind.
-- A builder can "graduate" a model out of harm's way by renaming it to
-- anything other than `name` before the next rebuild.
function GeneratorKit.CleanupPrevious(parent: Instance, name: string)
	local existing = parent:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
end

function GeneratorKit.Seeded(seed: number): Random
	return Random.new(seed)
end

function GeneratorKit.Finalize(model: Model, primaryPartName: string?)
	if primaryPartName then
		local primary = model:FindFirstChild(primaryPartName)
		if primary and primary:IsA("BasePart") then
			model.PrimaryPart = primary
		end
	end
end

-- Four WedgeParts arranged around `baseCFrame` approximate a pyramid roof.
-- No native cone/pyramid PartType exists in Roblox, and this kitbash
-- technique (vs. an unreliable legacy SpecialMesh enum) is guaranteed to
-- render consistently. Good enough as a generated starting point — a builder
-- can hand-sculpt a nicer roof later per the hybrid workflow.
function GeneratorKit.BuildPyramidRoof(
	parent: Instance,
	baseCFrame: CFrame,
	baseSize: number,
	height: number,
	material: Enum.Material,
	color: Color3
): Model
	local roofModel = Instance.new("Model")
	roofModel.Name = "PyramidRoof"

	for i = 0, 3 do
		local angle = math.rad(90 * i)
		local wedge = Instance.new("WedgePart")
		wedge.Name = `RoofFace{i}`
		wedge.Size = Vector3.new(baseSize, height, baseSize / 2)
		wedge.CFrame = baseCFrame * CFrame.Angles(0, angle, 0) * CFrame.new(0, height / 2, baseSize / 4)
		wedge.Material = material
		wedge.Color = color
		wedge.Anchored = true
		wedge.CastShadow = true
		wedge.Parent = roofModel
	end

	roofModel.Parent = parent
	return roofModel
end

-- Scatters small rubble/debris parts in a disc around `center`, seeded so
-- rebuilds are deterministic. Used to break up the "everything is a clean
-- primitive" look at the base of generated landmarks.
function GeneratorKit.ScatterRubble(
	parent: Instance,
	center: CFrame,
	radius: number,
	count: number,
	rng: Random,
	material: Enum.Material,
	color: Color3
): Model
	local scatterModel = Instance.new("Model")
	scatterModel.Name = "RubbleScatter"

	for i = 1, count do
		local distance = rng:NextNumber(0, radius)
		local angle = rng:NextNumber(0, math.pi * 2)
		local offset = Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
		local scale = rng:NextNumber(0.6, 2.2)

		GeneratorKit.NewPart({
			Name = `Rubble{i}`,
			Size = Vector3.new(scale, scale * rng:NextNumber(0.5, 1), scale),
			CFrame = center * CFrame.new(offset) * CFrame.Angles(rng:NextNumber(0, math.pi), rng:NextNumber(0, math.pi), rng:NextNumber(0, math.pi)),
			Material = material,
			Color = color,
			CanCollide = false,
			Parent = scatterModel,
		})
	end

	scatterModel.Parent = parent
	return scatterModel
end

return GeneratorKit
