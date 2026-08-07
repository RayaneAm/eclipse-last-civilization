--!strict
-- Shared arrival-platform + return-portal builder for every portal
-- destination (Prompt 2: the 4 hidden biome regions AND the Tutorial Zone —
-- "the Tutorial Zone should use the same destination pattern"). Builds only
-- what every destination needs in common: a raised arrival platform (named
-- per PortalDestinationConfig.arrivalAnchorName, which PortalService
-- resolves by name at travel time) and a small always-open return portal
-- back to Haven. Biome-specific terrain (TerrainGenerator/LandmarkGenerator,
-- called separately by tools/BuildWorldMap.luau) and Tutorial-Zone-specific
-- content (resource nodes, Upgrade Station, seal walls, built by
-- tools/BuildTutorialZone.luau) are NOT this file's job — this is only the
-- common "you can land here, and you can leave" piece every destination
-- shares.

local CollectionService = game:GetService("CollectionService")
local GeneratorKit = require(script.Parent.GeneratorKit)

local PortalDestinationGenerator = {}

local PLATFORM_RADIUS = 22
local PLATFORM_THICKNESS = 2
local RETURN_PORTAL_OFFSET = 30 -- studs from the arrival platform, so arriving/leaving are never the same spot

export type DestinationInput = {
	id: string,
	displayName: string,
	realOrigin: CFrame,
	arrivalAnchorName: string,
	returnAnchorName: string,
	accentColor: Color3,
}

export type BuildResult = {
	Model: Model,
	ArrivalAnchor: BasePart,
}

-- Builds the raised arrival platform + a small always-open return portal at
-- a destination's own realOrigin. Returns the arrival anchor Part so callers
-- (BuildWorldMap/BuildTutorialZone) can build additional content relative to
-- it without recomputing the same position.
function PortalDestinationGenerator.Build(parent: Instance, destination: DestinationInput): BuildResult
	GeneratorKit.CleanupPrevious(parent, destination.id)

	local model = Instance.new("Model")
	model.Name = destination.id

	local origin = destination.realOrigin

	GeneratorKit.NewPart({
		Name = "ArrivalPlatform",
		Size = Vector3.new(PLATFORM_RADIUS * 2, PLATFORM_THICKNESS, PLATFORM_RADIUS * 2),
		CFrame = origin * CFrame.new(0, -PLATFORM_THICKNESS / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(70, 68, 74),
		Shape = Enum.PartType.Cylinder,
		Parent = model,
	})

	local rim = GeneratorKit.NewPart({
		Name = "ArrivalPlatformRim",
		Size = Vector3.new(0.6, PLATFORM_RADIUS * 2 + 1, PLATFORM_RADIUS * 2 + 1),
		CFrame = origin * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Neon,
		Color = destination.accentColor,
		Shape = Enum.PartType.Cylinder,
		CanCollide = false,
		Parent = model,
	})

	local rimLight = Instance.new("PointLight")
	rimLight.Color = destination.accentColor
	rimLight.Brightness = 2
	rimLight.Range = 30
	rimLight.Parent = rim
	CollectionService:AddTag(rimLight, "AmbientFlicker")

	local arrivalAnchor = GeneratorKit.NewPart({
		Name = destination.arrivalAnchorName,
		Size = Vector3.new(2, 0.2, 2),
		CFrame = origin * CFrame.new(0, PLATFORM_THICKNESS / 2 + 0.1, 0),
		Transparency = 1,
		CanCollide = false,
		Parent = model,
	})

	-- Small always-open return portal, offset from the arrival spot so
	-- arriving and leaving are never the exact same point. Reuses the same
	-- "energy membrane plane" visual language as a biome gate's barrier, but
	-- always non-collidable — this is the sanctioned way out, not a
	-- progression-gated passage, so it's never tagged GateBarrier/BiomeId and
	-- BiomeGateService's PhysicsService toggling never touches it.
	local returnCFrame = origin * CFrame.new(RETURN_PORTAL_OFFSET, 0, 0)

	GeneratorKit.NewPart({
		Name = "ReturnPortalFrame",
		Size = Vector3.new(6, 10, 1),
		CFrame = returnCFrame * CFrame.new(0, 5, 0),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(60, 58, 64),
		Transparency = 1, -- greybox: frame is implied by the membrane + prompt for now, kept simple pending the visual-polish pass
		CanCollide = false,
		Parent = model,
	})

	local membrane = GeneratorKit.NewPart({
		Name = "ReturnPortalMembrane",
		Size = Vector3.new(5, 9, 0.4),
		CFrame = returnCFrame * CFrame.new(0, 4.5, 0),
		Material = Enum.Material.ForceField,
		Color = destination.accentColor,
		Transparency = 0.55,
		CanCollide = false,
		Parent = model,
	})
	CollectionService:AddTag(membrane, "ReturnPortal")
	membrane:SetAttribute("PortalId", destination.id)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ReturnPrompt"
	prompt.ObjectText = "Return"
	prompt.ActionText = "Travel to Survivor Haven"
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = membrane

	model.Parent = parent

	return {
		Model = model,
		ArrivalAnchor = arrivalAnchor,
	}
end

return PortalDestinationGenerator
