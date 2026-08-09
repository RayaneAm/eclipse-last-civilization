--!strict
-- Phase 4A: building placement — client PREVIEWS only (a ghost part
-- following the cursor, grid-snapped, rotatable, tinted green/valid or red/
-- invalid from a client-side pre-check), the server (BuildingService) is
-- the sole authority and independently re-validates everything. CFrames are
-- sent to the server in WORLD space; the server converts to base-local
-- space itself using its own resolved origin (BaseService.GetResolvedOrigin)
-- before validating bounds/overlap — the client never needs to know or
-- trust its own base's origin for anything security-relevant, it only uses
-- the origin (fetched via RequestBaseState) to display the ghost sensibly.
--
-- On-screen Rotate/Place/Cancel buttons work identically across mouse,
-- touch, and gamepad (via Interaction.Bind/GamepadNav) — the ghost itself
-- follows the mouse on desktop; touch/gamepad players use the buttons to
-- commit whatever position the ghost last had (a reasonable foundation-
-- phase baseline, not full touch-drag/gamepad-cursor placement).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local Trove = require(ReplicatedStorage.Shared.Modules.Trove)
local BuildingConfig = require(ReplicatedStorage.Shared.Config.BuildingConfig)
local PersonalBaseConfig = require(ReplicatedStorage.Shared.Config.PersonalBaseConfig)

local Theme = require(script.Parent.Parent.UI.Theme)
local Interaction = require(script.Parent.Parent.UI.Interaction)
local GlassPanel = require(script.Parent.Parent.UI.Components.GlassPanel)
local Button = require(script.Parent.Parent.UI.Components.Button)
local IconTile = require(script.Parent.Parent.UI.Components.IconTile)
local NotificationController = require(script.Parent.NotificationController)

local BasePlacementController = {}

local active = false
local ghost: Part? = nil
local zoneMarker: Model? = nil
local selectedBuildingId: string? = nil
local rotationDegrees = 0
local baseOrigin: CFrame? = nil
local isValid = false
local isSubmitting = false

-- Maps every EXPECTED server rejection reason to a player-facing message —
-- anything not in this table is unexpected and still warn()s once with the
-- raw reason, for diagnosability (Phase 4A.1: replaces the previous bare
-- warn() for every rejection, which is what produced repeated console spam
-- alongside repeated in-flight requests — see the isSubmitting guard below).
local REJECTION_MESSAGES: { [string]: string } = {
	OutOfBounds = "Outside the Freeform Zone",
	ProtectedZone = "This location is protected",
	Overlap = "Structure overlaps another building",
	CannotAfford = "Not enough materials",
	BuildingLimitReached = "Base building limit reached",
	BaseNotReady = "Base is not ready yet",
}

local function snap(value: number): number
	local gridSize = PersonalBaseConfig.GridSize
	return math.floor(value / gridSize + 0.5) * gridSize
end

local function selectedFootprintExtents(): (number, number)
	if not selectedBuildingId then
		return 0, 0
	end
	local size = BuildingConfig.GetFootprintSize(selectedBuildingId)
	local angle = math.rad(rotationDegrees)
	local cosine = math.abs(math.cos(angle))
	local sine = math.abs(math.sin(angle))
	return cosine * size.X / 2 + sine * size.Z / 2, sine * size.X / 2 + cosine * size.Z / 2
end

local function withinBoundsLocal(localPos: Vector3): boolean
	local bounds = PersonalBaseConfig.PlotBounds
	local halfX, halfZ = selectedFootprintExtents()
	return math.abs(localPos.X) + halfX <= bounds.HalfWidth and math.abs(localPos.Z) + halfZ <= bounds.HalfDepth
end

-- Phase 4A.1: freeform placement is now confined to the one marked
-- Freeform Zone — mirrors BuildingService's own server-authoritative
-- withinFreeformZone check exactly, so the client-side ghost preview never
-- shows green somewhere the server would reject.
local function withinFreeformZoneLocal(localPos: Vector3): boolean
	local zone = PersonalBaseConfig.FreeformZone
	local halfX, halfZ = selectedFootprintExtents()
	return localPos.X - halfX >= zone.MinX and localPos.X + halfX <= zone.MaxX and localPos.Z - halfZ >= zone.MinZ and localPos.Z + halfZ <= zone.MaxZ
end

local function insideProtectedZoneLocal(localPos: Vector3): boolean
	if (localPos - PersonalBaseConfig.CoreLocalPosition).Magnitude < PersonalBaseConfig.CoreProtectedRadius then
		return true
	end
	if (localPos - PersonalBaseConfig.EntranceLocalPosition).Magnitude < PersonalBaseConfig.EntranceProtectedRadius then
		return true
	end
	return false
end

local function destroyZoneMarker()
	if zoneMarker then
		zoneMarker:Destroy()
		zoneMarker = nil
	end
end

-- Ground-level visualization of the one region freeform placement accepts
-- — shown for the duration of an active ghost so the boundary is visible
-- BEFORE a player tries (and would otherwise only discover it) via a
-- red-ghost/rejected-request round trip.
local function createZoneMarker()
	destroyZoneMarker()
	if not baseOrigin then
		return
	end
	local zone = PersonalBaseConfig.FreeformZone
	local centerLocal = Vector3.new((zone.MinX + zone.MaxX) / 2, 0, (zone.MinZ + zone.MaxZ) / 2)
	local sizeX = zone.MaxX - zone.MinX
	local sizeZ = zone.MaxZ - zone.MinZ

	local model = Instance.new("Model")
	model.Name = "FreeformZoneBoundary"
	for _, edge in {
		{ 0, -sizeZ / 2, sizeX, 0.22 },
		{ 0, sizeZ / 2, sizeX, 0.22 },
		{ -sizeX / 2, 0, 0.22, sizeZ },
		{ sizeX / 2, 0, 0.22, sizeZ },
	} do
		local part = Instance.new("Part")
		part.Name = "BoundaryEdge"
		part.Size = Vector3.new(edge[3], 0.12, edge[4])
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Transparency = 0.58
		part.Material = Enum.Material.SmoothPlastic
		part.Color = Color3.fromRGB(108, 169, 166)
		part.CFrame = baseOrigin * CFrame.new(centerLocal + Vector3.new(edge[1], 0.46, edge[2]))
		part.Parent = model
	end
	model.Parent = Workspace
	zoneMarker = model
end

local function destroyGhost()
	if ghost then
		ghost:Destroy()
		ghost = nil
	end
	destroyZoneMarker()
end

local function updateGhostAt(worldPosition: Vector3)
	if not ghost or not baseOrigin then
		return
	end
	local localPos = baseOrigin:ToObjectSpace(CFrame.new(worldPosition)).Position
	local snappedLocal = Vector3.new(snap(localPos.X), 0, snap(localPos.Z))
	local worldCFrame = baseOrigin * CFrame.new(snappedLocal) * CFrame.Angles(0, math.rad(rotationDegrees), 0)

	isValid = withinBoundsLocal(snappedLocal) and withinFreeformZoneLocal(snappedLocal) and not insideProtectedZoneLocal(snappedLocal)
	ghost.CFrame = worldCFrame * CFrame.new(0, ghost.Size.Y / 2, 0)
	ghost.Color = if isValid then Color3.fromRGB(120, 220, 130) else Color3.fromRGB(220, 90, 90)
end

local function currentGhostWorldCFrame(): CFrame?
	if not ghost then
		return nil
	end
	return ghost.CFrame * CFrame.new(0, -ghost.Size.Y / 2, 0)
end

local function submitPlacement()
	if not selectedBuildingId or not isValid or isSubmitting then
		return
	end
	local worldCFrame = currentGhostWorldCFrame()
	if not worldCFrame then
		return
	end

	isSubmitting = true
	if BasePlacementController._placeButton then
		Interaction.SetDisabled(BasePlacementController._placeButton, true)
	end

	local ok, reason = Net.GetFunction("RequestPlaceBuilding"):InvokeServer({
		BuildingId = selectedBuildingId,
		CFrame = worldCFrame,
		Rotation = rotationDegrees,
	})

	isSubmitting = false
	if BasePlacementController._placeButton then
		Interaction.SetDisabled(BasePlacementController._placeButton, false)
	end

	if not ok then
		local message = REJECTION_MESSAGES[tostring(reason)]
		if message then
			NotificationController.Toast("BuildRejected", message)
		else
			warn(`BasePlacementController: placement failed: {tostring(reason)}`)
		end
	else
		NotificationController.Toast("BuildConfirmed", "Structure built")
	end
end

function BasePlacementController.CancelPlacement()
	if not active then
		return
	end
	active = false
	destroyGhost()
	selectedBuildingId = nil
	if BasePlacementController._hudFrame then
		BasePlacementController._hudFrame.Visible = false
	end
end

local function beginGhostFor(buildingId: string)
	destroyGhost()
	selectedBuildingId = buildingId
	rotationDegrees = 0

	local part = Instance.new("Part")
	part.Name = "PlacementGhost"
	part.Size = BuildingConfig.GetFootprintSize(buildingId)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Transparency = 0.4
	part.Material = Enum.Material.ForceField
	part.Color = Color3.fromRGB(120, 220, 130)
	part.Parent = Workspace
	ghost = part
	createZoneMarker()

	if BasePlacementController._hudFrame then
		BasePlacementController._hudFrame.Visible = true
	end
end

-- ---------------------------------------------------------------------
-- Building picker + HUD (Rotate/Place/Cancel)
-- ---------------------------------------------------------------------

function BasePlacementController:_buildUI()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "BasePlacementUI"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = playerGui
	self._trove:Add(screenGui)

	-- Picker: shown when EnterBuildMode is called, before a ghost exists.
	local pickerPanel = GlassPanel.new({
		Name = "Picker",
		Size = UDim2.new(0, 320, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.fromScale(0.5, 0.46),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = screenGui,
	})
	pickerPanel.Visible = false
	self._pickerPanel = pickerPanel

	local pickerPadding = Instance.new("UIPadding")
	pickerPadding.PaddingLeft = UDim.new(0, Theme.Spacing.L)
	pickerPadding.PaddingRight = UDim.new(0, Theme.Spacing.L)
	pickerPadding.PaddingTop = UDim.new(0, Theme.Spacing.L)
	pickerPadding.PaddingBottom = UDim.new(0, Theme.Spacing.L)
	pickerPadding.Parent = pickerPanel

	local pickerLayout = Instance.new("UIListLayout")
	pickerLayout.Padding = UDim.new(0, Theme.Spacing.S)
	pickerLayout.Parent = pickerPanel

	local pickerTitle = Instance.new("TextLabel")
	pickerTitle.BackgroundTransparency = 1
	pickerTitle.Size = UDim2.new(1, 0, 0, 26)
	pickerTitle.Font = Theme.Font.Heading.Font
	pickerTitle.TextSize = Theme.Font.Heading.Size
	pickerTitle.TextColor3 = Theme.Colors.TextPrimary
	pickerTitle.Text = "SELECT A STRUCTURE"
	pickerTitle.Parent = pickerPanel

	local freeformBuildingIds = { Foundation = true, Wall = true, Door = true, DefenseWall = true, RepairStation = true }
	for _, definition in BuildingConfig.All do
		if freeformBuildingIds[definition.Id] then
			Button.new({
				Text = definition.Name,
				Variant = "Secondary",
				Size = UDim2.new(1, 0, 0, 36),
				OnActivated = function()
					pickerPanel.Visible = false
					beginGhostFor(definition.Id)
				end,
				Parent = pickerPanel,
			})
		end
	end

	Button.new({
		Text = "Cancel",
		Variant = "Ghost",
		Size = UDim2.new(1, 0, 0, 36),
		OnActivated = function()
			pickerPanel.Visible = false
			active = false
		end,
		Parent = pickerPanel,
	})

	-- Rotate/Place/Cancel HUD, shown while a ghost is active.
	local hudFrame = Instance.new("Frame")
	hudFrame.Name = "PlacementHUD"
	hudFrame.Size = UDim2.new(0, 260, 0, 64)
	hudFrame.Position = UDim2.new(0.5, 0, 1, -Theme.Spacing.L)
	hudFrame.AnchorPoint = Vector2.new(0.5, 1)
	hudFrame.BackgroundTransparency = 1
	hudFrame.Visible = false
	hudFrame.Parent = screenGui
	self._hudFrame = hudFrame

	local hudLayout = Instance.new("UIListLayout")
	hudLayout.FillDirection = Enum.FillDirection.Horizontal
	hudLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	hudLayout.Padding = UDim.new(0, Theme.Spacing.S)
	hudLayout.Parent = hudFrame

	-- Phase 4A.1: swapped from dingbat/symbol glyphs (↻/✓/✕) to emoji —
	-- Roblox's default UI font reliably covers emoji but not the dingbat
	-- block those characters sit in, which is what produced the
	-- "placeholder square" bug CloseButton also had (see that component's
	-- own rewrite for the full root-cause explanation).
	local _rotateContainer, rotateButton = IconTile.new({
		Icon = "🔄",
		TileSize = UDim2.fromOffset(56, 56),
		OnActivated = function()
			rotationDegrees = (rotationDegrees + 90) % 360
		end,
		Parent = hudFrame,
	})

	local _placeContainer, placeButton = IconTile.new({
		Icon = "✅",
		AccentColor = Theme.Colors.Success,
		TileSize = UDim2.fromOffset(56, 56),
		OnActivated = function()
			submitPlacement()
		end,
		Parent = hudFrame,
	})

	local _cancelContainer, cancelButton = IconTile.new({
		Icon = "❌",
		AccentColor = Theme.Colors.Danger,
		TileSize = UDim2.fromOffset(56, 56),
		OnActivated = function()
			BasePlacementController.CancelPlacement()
		end,
		Parent = hudFrame,
	})

	self._rotateButton = rotateButton
	self._placeButton = placeButton
	self._cancelButton = cancelButton
end

function BasePlacementController.EnterBuildMode()
	local self = BasePlacementController
	active = true

	local player = Players.LocalPlayer
	local ok, result = pcall(function()
		return Net.GetFunction("RequestBaseState"):InvokeServer(player.UserId)
	end)
	baseOrigin = if ok and result then result.Origin else nil
	if not baseOrigin then
		warn("BasePlacementController: could not resolve base origin — are you inside your base?")
		active = false
		return
	end

	self._pickerPanel.Visible = true
end

function BasePlacementController:Init()
	self._trove = Trove.new()
	self:_buildUI()
end

function BasePlacementController:Start()
	local player = Players.LocalPlayer

	self._trove:Add(RunService.Heartbeat:Connect(function()
		if player:GetAttribute("EclipseMenuOpen") == true or not active or not ghost then
			return
		end
		local mouse = player:GetMouse()
		if mouse and mouse.Hit then
			updateGhostAt(mouse.Hit.Position)
		end
	end))

	self._trove:Add(UserInputService.InputBegan:Connect(function(input, processed)
		if player:GetAttribute("EclipseMenuOpen") == true or processed or not active or not ghost then
			return
		end
		if input.KeyCode == Enum.KeyCode.R then
			rotationDegrees = (rotationDegrees + 90) % 360
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			submitPlacement()
		elseif input.KeyCode == Enum.KeyCode.Escape or input.UserInputType == Enum.UserInputType.MouseButton2 then
			BasePlacementController.CancelPlacement()
		end
	end))
end

return BasePlacementController
