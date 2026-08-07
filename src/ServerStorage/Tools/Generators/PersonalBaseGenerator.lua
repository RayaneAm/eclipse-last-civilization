--!strict
-- Phase 4A: builds one player's personal base — the starter layout (ground,
-- perimeter markers, entrance, Civilization Core, starter shelter, basic
-- storage/workbench/generator markers, trader terminal, defense-control
-- marker, future survivor/production zone pads, Eclipse Assault foundation
-- anchors) plus every already-placed StructureInstance from that player's
-- BaseSessionData. Runs LIVE, at runtime, on the server (via BaseService,
-- required from ServerStorage.Tools — tools/ ships into the live game per
-- default.project.json) — not a Studio-only one-shot Build*.luau script,
-- since a base must be creatable for any of potentially thousands of
-- players, not hand-authored.
--
-- Follows GeneratorKit's conventions exactly (NewPart/CleanupPrevious/
-- Seeded/Finalize) for consistency with every other generator in this
-- project. Root organization: one player-keyed sub-Model under the shared
-- PersonalBases_Generated root (created by BaseService), individually
-- rebuilt via GeneratorKit.CleanupPrevious(root, tostring(userId)) — never a
-- whole-root wipe, so one player's rebuild can't touch another's.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GeneratorKit = require(script.Parent.GeneratorKit)
local PortalDestinationGenerator = require(script.Parent.PortalDestinationGenerator)
local BuildingConfig = require(ReplicatedStorage.Shared.Config.BuildingConfig)
local BlueprintLayoutConfig = require(ReplicatedStorage.Shared.Config.BlueprintLayoutConfig)
local PersonalBaseConfig = require(ReplicatedStorage.Shared.Config.PersonalBaseConfig)

local ROOT_NAME = "PersonalBases_Generated"

-- Must match PersonalBaseConfig.CoreLocalPosition exactly — see that file's
-- header comment for why this is a small duplicated constant, not a shared
-- module (same convention already established elsewhere in this project).
local CORE_OFFSET = Vector3.new(0, 0, 45)

local PersonalBaseGenerator = {}

-- ---------------------------------------------------------------------
-- Shared lookups (also used by BuildStructure/RemoveStructure, called
-- later and independently by BuildingService, not just during the initial
-- full Build).
-- ---------------------------------------------------------------------

local function findRoot(): Model?
	local root = Workspace:FindFirstChild(ROOT_NAME)
	return if root and root:IsA("Model") then root else nil
end

local function findBaseModel(userId: number): Model?
	local root = findRoot()
	if not root then
		return nil
	end
	local baseModel = root:FindFirstChild(tostring(userId))
	return if baseModel and baseModel:IsA("Model") then baseModel else nil
end

local function structuresContainer(userId: number): Model?
	local baseModel = findBaseModel(userId)
	if not baseModel then
		return nil
	end
	local container = baseModel:FindFirstChild("Structures")
	if not container then
		container = Instance.new("Model")
		container.Name = "Structures"
		container.Parent = baseModel
	end
	return container :: Model
end

-- ---------------------------------------------------------------------
-- Civilization Core — a real Eclipse-survivor identity, not a generic
-- glowing cube: reinforced base, visible support struts, cable runs, a ring
-- of status lights, one upgradeable outer-ring detail.
-- ---------------------------------------------------------------------

local CORE_HEIGHT = 22
local CORE_RADIUS = 8

local function buildCivilizationCore(parent: Instance, baseCFrame: CFrame)
	local model = Instance.new("Model")
	model.Name = "CivilizationCore"

	local plinth = GeneratorKit.NewPart({
		Name = "Plinth",
		Size = Vector3.new(CORE_RADIUS * 2.4, 2, CORE_RADIUS * 2.4),
		CFrame = baseCFrame * CFrame.new(0, 1, 0),
		Material = Enum.Material.DiamondPlate,
		Color = Color3.fromRGB(60, 58, 62),
		Parent = model,
	})

	-- Opens the Base Management UI (BaseUIController) — the Core's status
	-- display doubles as the main access point, per the brief's "provides
	-- access to base overview information."
	local corePrompt = Instance.new("ProximityPrompt")
	corePrompt.Name = "BaseCorePrompt"
	corePrompt.ObjectText = "Civilization Core"
	corePrompt.ActionText = "Manage Base"
	corePrompt.MaxActivationDistance = 16
	corePrompt.RequiresLineOfSight = false
	corePrompt.Parent = plinth
	CollectionService:AddTag(plinth, "BaseCoreTerminal")

	GeneratorKit.NewPart({
		Name = "CoreShell",
		Size = Vector3.new(CORE_RADIUS * 1.6, CORE_HEIGHT, CORE_RADIUS * 1.6),
		CFrame = baseCFrame * CFrame.new(0, 2 + CORE_HEIGHT / 2, 0),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(46, 44, 50),
		Parent = model,
	})

	-- Support struts, 4 angled braces.
	for i = 0, 3 do
		local angle = math.rad(90 * i + 45)
		GeneratorKit.NewPart({
			Name = `Strut{i}`,
			Size = Vector3.new(1, CORE_HEIGHT * 0.7, 1.2),
			CFrame = baseCFrame * CFrame.new(math.cos(angle) * CORE_RADIUS * 1.3, 2 + CORE_HEIGHT * 0.35, math.sin(angle) * CORE_RADIUS * 1.3) * CFrame.Angles(0, angle, math.rad(8)),
			Material = Enum.Material.CorrodedMetal,
			Color = Color3.fromRGB(70, 66, 60),
			Parent = model,
		})
	end

	-- Cable runs from the plinth up to the shell.
	for i = 1, 3 do
		local angle = math.rad(120 * i)
		GeneratorKit.NewPart({
			Name = `Cable{i}`,
			Size = Vector3.new(0.3, CORE_HEIGHT * 0.6, 0.3),
			CFrame = baseCFrame * CFrame.new(math.cos(angle) * CORE_RADIUS * 0.9, 2 + CORE_HEIGHT * 0.3, math.sin(angle) * CORE_RADIUS * 0.9),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(30, 28, 30),
			CanCollide = false,
			Parent = model,
		})
	end

	-- Ring of status lights.
	for i = 0, 7 do
		local angle = math.rad(45 * i)
		local light = GeneratorKit.NewPart({
			Name = `StatusLight{i}`,
			Size = Vector3.new(0.6, 0.6, 0.6),
			CFrame = baseCFrame * CFrame.new(math.cos(angle) * CORE_RADIUS * 0.85, 2 + CORE_HEIGHT * 0.55, math.sin(angle) * CORE_RADIUS * 0.85),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(140, 110, 255),
			Shape = Enum.PartType.Ball,
			CanCollide = false,
			Parent = model,
		})
		local pointLight = Instance.new("PointLight")
		pointLight.Color = Color3.fromRGB(150, 120, 255)
		pointLight.Brightness = 1.5
		pointLight.Range = 10
		pointLight.Parent = light
		CollectionService:AddTag(pointLight, "AmbientFlicker")
	end

	-- Upgradeable outer ring detail (static — matches this project's
	-- established rule that only small secondary energy details rotate,
	-- never the main architectural silhouette).
	GeneratorKit.NewPart({
		Name = "OuterRing",
		Size = Vector3.new(CORE_RADIUS * 2.4, 1, CORE_RADIUS * 2.4),
		CFrame = baseCFrame * CFrame.new(0, 2 + CORE_HEIGHT * 0.85, 0),
		Material = Enum.Material.ForceField,
		Color = Color3.fromRGB(140, 110, 255),
		Transparency = 0.5,
		Shape = Enum.PartType.Cylinder,
		CanCollide = false,
		Parent = model,
	})

	-- Eclipse Assault foundation: the Core doubles as the future assault
	-- objective reference — inert until a real assault system exists.
	CollectionService:AddTag(plinth, "EclipseAssaultObjective")

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CoreLabel"
	billboard.Size = UDim2.fromOffset(200, 36)
	billboard.StudsOffset = Vector3.new(0, CORE_HEIGHT + 4, 0)
	billboard.MaxDistance = 120
	billboard.LightInfluence = 0
	billboard.Parent = plinth

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = "CIVILIZATION CORE"
	label.Parent = billboard

	model.Parent = parent
end

-- ---------------------------------------------------------------------
-- Starter layout — deliberately incomplete-but-hopeful: a small surviving
-- outpost, not a finished fortress.
-- ---------------------------------------------------------------------

local function buildGround(parent: Instance, baseCFrame: CFrame)
	GeneratorKit.NewPart({
		Name = "Ground",
		Size = Vector3.new(200, 1, 200),
		CFrame = baseCFrame * CFrame.new(0, -0.5, 0),
		Material = Enum.Material.Ground,
		Color = Color3.fromRGB(74, 68, 58),
		Parent = parent,
	})
end

local function buildPerimeterMarkers(parent: Instance, baseCFrame: CFrame)
	local model = Instance.new("Model")
	model.Name = "PerimeterMarkers"
	local radius = 85
	for i = 0, 15 do
		local angle = math.rad(22.5 * i)
		GeneratorKit.NewPart({
			Name = `PerimeterPost{i}`,
			Size = Vector3.new(1, 3, 1),
			CFrame = baseCFrame * CFrame.new(math.cos(angle) * radius, 1.5, math.sin(angle) * radius),
			Material = Enum.Material.WoodPlanks,
			Color = Color3.fromRGB(70, 58, 44),
			Parent = model,
		})
	end
	model.Parent = parent
end

local function buildEntrance(parent: Instance, baseCFrame: CFrame)
	local entranceCFrame = baseCFrame * CFrame.new(0, 0, -80)
	local model = Instance.new("Model")
	model.Name = "Entrance"

	for _, side in { -1, 1 } do
		GeneratorKit.NewPart({
			Name = if side < 0 then "PylonLeft" else "PylonRight",
			Size = Vector3.new(1.8, 10, 1.8),
			CFrame = entranceCFrame * CFrame.new(side * 6, 5, 0),
			Material = Enum.Material.Concrete,
			Color = Color3.fromRGB(78, 76, 80),
			Parent = model,
		})
	end
	GeneratorKit.NewPart({
		Name = "Lintel",
		Size = Vector3.new(14, 1.4, 1.8),
		CFrame = entranceCFrame * CFrame.new(0, 10, 0),
		Material = Enum.Material.Concrete,
		Color = Color3.fromRGB(78, 76, 80),
		Parent = model,
	})

	model.Parent = parent
end

local function buildStarterShelter(parent: Instance, baseCFrame: CFrame)
	local shelterCFrame = baseCFrame * CFrame.new(-25, 0, 30)
	local model = Instance.new("Model")
	model.Name = "StarterShelter"

	GeneratorKit.NewPart({
		Name = "Floor",
		Size = Vector3.new(14, 0.5, 14),
		CFrame = shelterCFrame * CFrame.new(0, 0.25, 0),
		Material = Enum.Material.WoodPlanks,
		Color = Color3.fromRGB(84, 66, 48),
		Parent = model,
	})
	for _, offset in { Vector3.new(-6.5, 0, -6.5), Vector3.new(6.5, 0, -6.5), Vector3.new(-6.5, 0, 6.5), Vector3.new(6.5, 0, 6.5) } do
		GeneratorKit.NewPart({
			Name = "Wall",
			Size = Vector3.new(0.6, 6, 14),
			CFrame = shelterCFrame * CFrame.new(offset) * CFrame.Angles(0, if math.abs(offset.X) > math.abs(offset.Z) then math.rad(90) else 0, 0),
			Material = Enum.Material.Fabric,
			Color = Color3.fromRGB(90, 84, 70),
			Transparency = 0.1,
			CanCollide = false,
			Parent = model,
		})
	end
	GeneratorKit.BuildPyramidRoof(model, shelterCFrame * CFrame.new(0, 6, 0), 15, 4, Enum.Material.Fabric, Color3.fromRGB(70, 62, 50))

	model.Parent = parent
end

local function buildMarkerBuilding(parent: Instance, cframe: CFrame, name: string, color: Color3, size: Vector3)
	local model = Instance.new("Model")
	model.Name = name

	GeneratorKit.NewPart({
		Name = "Body",
		Size = size,
		CFrame = cframe * CFrame.new(0, size.Y / 2, 0),
		Material = Enum.Material.Concrete,
		Color = color,
		Parent = model,
	})

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(160, 30)
	billboard.StudsOffset = Vector3.new(0, size.Y + 1.5, 0)
	billboard.MaxDistance = 70
	billboard.LightInfluence = 0
	billboard.Parent = model.Body

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = string.upper(name)
	label.Parent = billboard

	model.Parent = parent
	return model
end

local function buildTraderTerminal(parent: Instance, baseCFrame: CFrame)
	local terminalCFrame = baseCFrame * CFrame.new(25, 0, 30)
	local model = buildMarkerBuilding(parent, terminalCFrame, "TraderTerminal", Color3.fromRGB(90, 76, 58), Vector3.new(4, 5, 3))

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TraderPrompt"
	prompt.ObjectText = "Trader"
	prompt.ActionText = "Trade"
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = model.Body
	CollectionService:AddTag(model.Body, "BaseTraderTerminal")
end

-- UI/HUD Visual Direction Pass: reserves the future Mailbox delivery
-- system's world location (PersonalBaseConfig.MailboxReservedLocalPosition)
-- with a purely decorative, non-interactive prop — no ProximityPrompt, no
-- CollectionService tag, no remote. Real delivery/claim logic is explicitly
-- out of scope this pass; this only marks the spot so it reads as reserved
-- in-game rather than only existing as a config constant.
local function buildMailboxProp(parent: Instance, baseCFrame: CFrame)
	local mailboxCFrame = baseCFrame * CFrame.new(PersonalBaseConfig.MailboxReservedLocalPosition)
	buildMarkerBuilding(parent, mailboxCFrame, "Mailbox (Coming Soon)", Color3.fromRGB(70, 90, 110), Vector3.new(2, 3, 2))
end

-- Phase 4A.1: DefenseControl was a purely-decorative marker here — it's now
-- a real blueprint-pad structure (see buildBlueprintPads/BlueprintLayoutConfig's
-- DefenseControl_1 pad), so this function and its call are removed rather
-- than left to draw a second, overlapping object at the same spot.

local function buildFutureZonePads(parent: Instance, baseCFrame: CFrame)
	local model = Instance.new("Model")
	model.Name = "FutureZones"

	-- Phase 4A.1: SurvivorArea and ProductionArea used to be flat unlabeled
	-- placeholder quads here — they're now real, labeled blueprint pads
	-- (SurvivorQuarters_1, ResourceProcessor_1 in BlueprintLayoutConfig, at
	-- these exact same offsets) rendered by buildBlueprintPads instead.
	-- MarketplaceAccessTerminal has no pad yet (marketplace access isn't a
	-- buildable structure), so it stays here unchanged.
	for _, entry in {
		{ Name = "MarketplaceAccessTerminal", Offset = Vector3.new(0, 0, 45), Color = Color3.fromRGB(60, 70, 90) },
	} do
		GeneratorKit.NewPart({
			Name = entry.Name,
			Size = Vector3.new(12, 0.3, 12),
			CFrame = baseCFrame * CFrame.new(entry.Offset) * CFrame.new(0, 0.15, 0),
			Material = Enum.Material.Neon,
			Color = entry.Color,
			Transparency = 0.7,
			CanCollide = false,
			Parent = model,
		})
	end

	model.Parent = parent
end

-- ---------------------------------------------------------------------
-- Blueprint pads (Phase 4A.1) — guided-progression build slots. Each
-- unbuilt pad renders as a translucent footprint outline + name label +
-- a "BaseBlueprintPad"-tagged ProximityPrompt carrying a PadId attribute
-- (BaseUIController listens for this tag). A pad that already has a
-- linked StructureInstance (structure.PadId == pad.PadId, set either by a
-- real RequestBuildBlueprint build or by BaseService's migration of a
-- pre-4A.1 freeform structure) is skipped entirely here — the real
-- structure itself is drawn by the ordinary BuildStructure per-structure
-- loop in Build below, exactly like any other structure.
-- ---------------------------------------------------------------------

local function buildPadGhost(container: Instance, baseCFrame: CFrame, pad: BlueprintLayoutConfig.BlueprintPad)
	local definition = BuildingConfig.Get(pad.BuildingId)
	local footprint = BuildingConfig.GetFootprintSize(pad.BuildingId)
	local padCFrame = baseCFrame * pad.LocalCFrame

	local outline = GeneratorKit.NewPart({
		Name = pad.PadId,
		Size = Vector3.new(footprint.X, 0.3, footprint.Z),
		CFrame = padCFrame * CFrame.new(0, 0.15, 0),
		Material = Enum.Material.ForceField,
		Color = Color3.fromRGB(140, 200, 255),
		Transparency = 0.55,
		CanCollide = false,
		Parent = container,
	})

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BlueprintPrompt"
	prompt.ObjectText = if definition then definition.Name else pad.BuildingId
	prompt.ActionText = "Build"
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = outline
	outline:SetAttribute("PadId", pad.PadId)
	CollectionService:AddTag(outline, "BaseBlueprintPad")

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(160, 30)
	billboard.StudsOffset = Vector3.new(0, 2, 0)
	billboard.MaxDistance = 70
	billboard.LightInfluence = 0
	billboard.Parent = outline

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(140, 200, 255)
	label.Text = if definition then `Build: {definition.Name}` else pad.BuildingId
	label.Parent = billboard

	return outline
end

local function blueprintPadsContainer(userId: number): Model?
	local baseModel = findBaseModel(userId)
	if not baseModel then
		return nil
	end
	local container = baseModel:FindFirstChild("BlueprintPads")
	if not container then
		container = Instance.new("Model")
		container.Name = "BlueprintPads"
		container.Parent = baseModel
	end
	return container :: Model
end

-- Idempotent by construction: derives ghost-vs-built state purely from the
-- already-migrated session.Structures/PadId linkage passed in, never from
-- any local/generator-side memory of what it last drew — a linked/built
-- pad never gets a ghost, an unbuilt pad is never duplicated, and calling
-- this twice (e.g. via a full rebuild) produces the same result every time
-- since the whole per-player model is destroyed via GeneratorKit.CleanupPrevious
-- before Build recreates it.
local function buildBlueprintPads(parent: Instance, baseCFrame: CFrame, session: any?)
	local model = Instance.new("Model")
	model.Name = "BlueprintPads"

	local builtPadIds: { [string]: boolean } = {}
	if session then
		for _, structure in session.Structures do
			if structure.PadId then
				builtPadIds[structure.PadId] = true
			end
		end
	end

	for _, pad in BlueprintLayoutConfig.All do
		if not builtPadIds[pad.PadId] then
			buildPadGhost(model, baseCFrame, pad)
		end
	end

	model.Parent = parent
end

-- Called by BuildingService.requestDismantleBuilding when a pad-linked
-- structure is torn down mid-session (no full rebuild) — restores that
-- one pad's ghost so the guided-progression slot is buildable again,
-- without touching any other pad's state. No-ops if a ghost for this pad
-- is already present (idempotent, same guarantee as buildBlueprintPads).
function PersonalBaseGenerator.RestoreBlueprintPad(userId: number, origin: CFrame, padId: string)
	local pad = BlueprintLayoutConfig.Get(padId)
	if not pad then
		return
	end
	local container = blueprintPadsContainer(userId)
	if not container then
		return
	end
	if container:FindFirstChild(padId) then
		return
	end
	buildPadGhost(container, origin, pad)
end

local function buildAttackRouteAnchors(parent: Instance, baseCFrame: CFrame)
	-- Eclipse Assault foundation: tagged-but-inert reference anchors a
	-- future assault-combat phase will use — do nothing on their own.
	local model = Instance.new("Model")
	model.Name = "EclipseAssaultAnchors"

	for i = 0, 3 do
		local angle = math.rad(90 * i)
		local anchor = GeneratorKit.NewPart({
			Name = `EclipseAssaultSpawn{i}`,
			Size = Vector3.new(2, 0.2, 2),
			CFrame = baseCFrame * CFrame.new(math.cos(angle) * 82, 0.1, math.sin(angle) * 82),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(200, 60, 60),
			Transparency = 0.8,
			CanCollide = false,
			Parent = model,
		})
		CollectionService:AddTag(anchor, "EclipseAssaultSpawn")

		local route = GeneratorKit.NewPart({
			Name = `EclipseAttackRoute{i}`,
			Size = Vector3.new(4, 0.1, 60),
			CFrame = baseCFrame * CFrame.new(math.cos(angle) * 50, 0.05, math.sin(angle) * 50) * CFrame.Angles(0, angle, 0),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(200, 60, 60),
			Transparency = 0.92,
			CanCollide = false,
			Parent = model,
		})
		CollectionService:AddTag(route, "EclipseAttackRoute")
	end

	model.Parent = parent
end

-- ---------------------------------------------------------------------
-- Player-placed structures — generic per-category placeholder geometry
-- plus a name label (no bespoke art per building this phase, per the
-- Phase 4A plan's foundation-only scoping).
-- ---------------------------------------------------------------------

local CATEGORY_COLOR = {
	Structural = Color3.fromRGB(120, 108, 90),
	Utility = Color3.fromRGB(90, 110, 120),
	Production = Color3.fromRGB(140, 120, 60),
	Defense = Color3.fromRGB(130, 60, 60),
	Civilization = Color3.fromRGB(120, 100, 180),
}

function PersonalBaseGenerator.BuildStructure(userId: number, origin: CFrame, structure: any)
	local container = structuresContainer(userId)
	if not container then
		return
	end
	local existing = container:FindFirstChild(structure.Id)
	if existing then
		existing:Destroy()
	end

	local definition = BuildingConfig.Get(structure.BuildingId)
	local color = if definition then CATEGORY_COLOR[definition.Category] else Color3.fromRGB(100, 100, 100)
	local worldCFrame = origin * structure.CFrame

	local model = Instance.new("Model")
	model.Name = structure.Id

	local sizeY = 3 + structure.Level * 0.5
	GeneratorKit.NewPart({
		Name = "Body",
		Size = Vector3.new(5, sizeY, 5),
		CFrame = worldCFrame * CFrame.new(0, sizeY / 2, 0),
		Material = Enum.Material.Concrete,
		Color = color,
		Parent = model,
	})

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(150, 26)
	billboard.StudsOffset = Vector3.new(0, sizeY + 1.2, 0)
	billboard.MaxDistance = 50
	billboard.LightInfluence = 0
	billboard.Parent = model.Body

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = if definition then `{definition.Name} (Lv{structure.Level})` else structure.BuildingId
	label.Parent = billboard

	model.Parent = container

	-- A pad-linked structure is now real geometry — its ghost (if any is
	-- still present; migrated structures never had one) must not linger
	-- alongside it. Safe no-op if already removed.
	if structure.PadId then
		local baseModel = findBaseModel(userId)
		local padsContainer = baseModel and baseModel:FindFirstChild("BlueprintPads")
		local ghost = padsContainer and padsContainer:FindFirstChild(structure.PadId)
		if ghost then
			ghost:Destroy()
		end
	end
end

function PersonalBaseGenerator.RemoveStructure(userId: number, structureId: string)
	local container = structuresContainer(userId)
	if not container then
		return
	end
	local existing = container:FindFirstChild(structureId)
	if existing then
		existing:Destroy()
	end
end

-- ---------------------------------------------------------------------
-- Top-level Build
-- ---------------------------------------------------------------------

function PersonalBaseGenerator.Build(root: Model, userId: number, origin: CFrame, session: any?): Model
	GeneratorKit.CleanupPrevious(root, tostring(userId))

	local model = Instance.new("Model")
	model.Name = tostring(userId)

	-- The Civilization Core sits forward of the raw origin — PortalDestinationGenerator
	-- builds the arrival platform + return portal AT the raw origin (see
	-- below), so the Core (and PersonalBaseConfig.CoreLocalPosition, which
	-- BuildingService's protected-zone check uses) is deliberately offset to
	-- avoid overlapping that arrival geometry.
	buildGround(model, origin)
	buildPerimeterMarkers(model, origin)
	buildEntrance(model, origin)
	buildCivilizationCore(model, origin * CFrame.new(CORE_OFFSET))
	buildStarterShelter(model, origin)
	buildTraderTerminal(model, origin)
	buildMailboxProp(model, origin)
	buildFutureZonePads(model, origin)
	buildBlueprintPads(model, origin, session)
	buildAttackRouteAnchors(model, origin)

	model.Parent = root

	-- Arrival platform + the interactable ReturnPortal back to Haven — reuses
	-- the exact same generator every biome/Tutorial destination already
	-- uses, so travel back to Haven works via the identical, already-proven
	-- ReturnPortalController/PortalService contract (PortalId = the same
	-- "PersonalBase_<userId>" id PortalDestinationConfig.Get parses).
	PortalDestinationGenerator.Build(model, {
		id = `PersonalBase_{userId}`,
		displayName = "Personal Base",
		realOrigin = origin,
		arrivalAnchorName = "Arrival_PersonalBase",
		returnAnchorName = "ReturnLanding_PersonalBase",
		accentColor = Color3.fromRGB(140, 110, 255),
	})

	local container = Instance.new("Model")
	container.Name = "Structures"
	container.Parent = model

	if session then
		for _, structure in session.Structures do
			-- The Core's bespoke visual is already built above via
			-- buildCivilizationCore — skip it here so the generic
			-- placeholder-box builder doesn't draw a second, overlapping
			-- object for it.
			if structure.BuildingId ~= "CivilizationCore" then
				PersonalBaseGenerator.BuildStructure(userId, origin, structure)
			end
		end
	end

	return model
end

return PersonalBaseGenerator
