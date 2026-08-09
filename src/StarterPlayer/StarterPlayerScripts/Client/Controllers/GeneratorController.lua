--!strict
-- BASIC GENERATOR / POWER — opened at the generator (BaseGeneratorTerminal
-- tag).
--
-- What is real here: total capacity, current consumption, per-consumer
-- enable/disable, and the resulting grid status. All of that comes from
-- PowerService and is fully server-authoritative — toggling a consumer calls
-- RequestSetPowerEnabled and the server refuses anything that would exceed
-- capacity.
--
-- What is NOT real: FUEL. `Power.GeneratorFuel` exists in the saved session
-- shape, but nothing in the game consumes it, produces it, or refills it —
-- there is no fuel drain loop and no "add fuel" remote. So this screen does
-- NOT draw a fuel gauge and does NOT offer an ADD FUEL button. It states
-- plainly that the fuel system is not implemented yet (brief §56: never
-- pretend a facility works). When a real fuel system ships, the meter goes
-- where that notice is.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local Trove = require(ReplicatedStorage.Shared.Modules.Trove)
local BuildingConfig = require(ReplicatedStorage.Shared.Config.BuildingConfig)

local Theme = require(script.Parent.Parent.UI.Theme)
local FacilityStyle = require(script.Parent.Parent.UI.FacilityStyle)
local FacilityRouter = require(script.Parent.Parent.UI.FacilityRouter)
local FacilityPrompts = require(script.Parent.Parent.UI.FacilityPrompts)
local FacilityModal = require(script.Parent.Parent.UI.Components.FacilityModal)
local FacilityCard = require(script.Parent.Parent.UI.Components.FacilityCard)
local SectionHeader = require(script.Parent.Parent.UI.Components.SectionHeader)
local MeterRow = require(script.Parent.Parent.UI.Components.MeterRow)
local StatusChip = require(script.Parent.Parent.UI.Components.StatusChip)
local EmptyState = require(script.Parent.Parent.UI.Components.EmptyState)
local Button = require(script.Parent.Parent.UI.Components.Button)

local BaseSessionController = require(script.Parent.BaseSessionController)
local NotificationController = require(script.Parent.NotificationController)

local GeneratorController = {}

local IDENTITY = FacilityStyle.Facilities.Generator
local ACCENT = IDENTITY.Accent

local POWER_REJECTIONS: { [string]: string } = {
	InsufficientPower = "Not enough spare capacity to switch this on",
	NotAPowerConsumer = "This structure does not use power",
	UnknownStructure = "This structure no longer exists",
	BaseNotReady = "Your base is not ready yet",
}

local modal: FacilityModal.FacilityModal? = nil
local pendingAction = false

local function setPowerEnabled(structureId: string, enabled: boolean)
	if pendingAction then
		return
	end
	pendingAction = true
	local ok, reason = Net.GetFunction("RequestSetPowerEnabled"):InvokeServer({ StructureId = structureId, Enabled = enabled })
	pendingAction = false
	if not ok then
		NotificationController.Toast("BuildRejected", POWER_REJECTIONS[tostring(reason)] or `Power change failed: {tostring(reason)}`)
	end
end

local function render()
	local activeModal = modal
	if not activeModal then
		return
	end
	activeModal:ClearContent()

	local content = activeModal.Content
	local layoutOrder = 0
	local function nextOrder(): number
		layoutOrder += 1
		return layoutOrder
	end

	local power = BaseSessionController.GetPowerSummary()
	local session = BaseSessionController.GetSession()

	if not power.HasGenerator then
		EmptyState.new({
			Glyph = "Power",
			Text = "No generator built",
			Subtext = "Build a Basic Generator at its construction node to power machines.",
			Card = true,
			LayoutOrder = nextOrder(),
			Parent = content,
		})
		activeModal:RevealContent()
		return
	end

	local headroom = power.Capacity - power.Used
	local status: FacilityStyle.StatusKind = if headroom < 0 then "Critical" elseif headroom <= 1 then "Low" else "Stable"

	activeModal:SetHeader(IDENTITY.Title, `Level {power.GeneratorLevel} · {power.Capacity} power capacity`)

	-- OUTPUT
	local _outputCard, outputContent = FacilityCard.new({
		Name = "Output",
		Accent = ACCENT,
		LayoutOrder = nextOrder(),
		Parent = content,
	})

	FacilityCard.Header({ Icon = "Power", Title = "POWER OUTPUT", Accent = ACCENT, LayoutOrder = 1, Parent = outputContent })
	StatusChip.new({ Status = status, LayoutOrder = 2, Parent = outputContent })
	MeterRow.new({
		Label = "Draw",
		Value = `{power.Used} / {power.Capacity}`,
		Progress = if power.Capacity > 0 then power.Used / power.Capacity else 0,
		Accent = if status == "Critical" then Theme.Colors.Danger elseif status == "Low" then FacilityStyle.StatusColor.Low else ACCENT,
		Info = "Maximum power the base can currently supply, against what your enabled machines and running jobs draw.",
		LayoutOrder = 3,
		Parent = outputContent,
	})
	FacilityCard.Text({
		Text = if headroom < 0
			then "Draw exceeds capacity. Disable a consumer or upgrade the generator."
			elseif headroom == 0 then "No spare capacity. Nothing else can be switched on."
			else `{headroom} power spare.`,
		Color = if headroom < 0 then Theme.Colors.Danger elseif headroom <= 1 then Theme.Colors.Warning else Theme.Colors.TextSecondary,
		LayoutOrder = 4,
		Parent = outputContent,
	})

	-- FUEL — deliberately presented as an unimplemented system rather than a
	-- decorative gauge. See this file's header.
	SectionHeader.new({ Text = "Fuel", LayoutOrder = nextOrder(), Parent = content })

	local _fuelCard, fuelContent = FacilityCard.new({
		Name = "Fuel",
		LayoutOrder = nextOrder(),
		Parent = content,
	})
	StatusChip.new({ Status = "Locked", Text = "NOT YET IMPLEMENTED", LayoutOrder = 1, Parent = fuelContent })
	FacilityCard.Text({
		Text = "This generator does not consume fuel yet. Power capacity comes from its level, and refuelling will arrive with a later update.",
		Color = Theme.Colors.TextMuted,
		LayoutOrder = 2,
		Parent = fuelContent,
	})

	-- CONSUMERS — the real, actionable part of this screen.
	SectionHeader.new({
		Text = "Consumers",
		Accent = ACCENT,
		Info = "Switching a machine off frees its power for something else.",
		LayoutOrder = nextOrder(),
		Parent = content,
	})

	local consumerCount = 0
	if session then
		local structureIds: { string } = {}
		for structureId, structure in session.Structures do
			local definition = BuildingConfig.Get(structure.BuildingId)
			if definition and definition.PowerDraw > 0 then
				table.insert(structureIds, structureId)
			end
		end
		table.sort(structureIds)

		for _, structureId in structureIds do
			consumerCount += 1
			local structure = session.Structures[structureId]
			local definition = BuildingConfig.Get(structure.BuildingId) :: BuildingConfig.BuildingDefinition
			local enabled = session.Power.Enabled[structureId] == true

			local _card, cardContent = FacilityCard.new({
				Name = `Consumer_{structureId}`,
				Accent = if enabled then ACCENT else nil,
				Padding = Theme.Spacing.S,
				LayoutOrder = nextOrder(),
				Parent = content,
			})

			FacilityCard.Header({
				Title = definition.Name,
				TrailingText = `{definition.PowerDraw} PWR`,
				TrailingColor = ACCENT,
				LayoutOrder = 1,
				Parent = cardContent,
			})

			local row = Instance.new("Frame")
			row.Name = "ToggleRow"
			row.Size = UDim2.new(1, 0, 0, 34)
			row.LayoutOrder = 2
			row.BackgroundTransparency = 1
			row.Parent = cardContent

			StatusChip.new({
				Status = if enabled then "Running" else "Offline",
				Text = if enabled then "ENABLED" else "DISABLED",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 0, 0.5, 0),
				Parent = row,
			})

			-- Switching ON is blocked client-side when it clearly cannot fit,
			-- so the button never fires a request PowerService will refuse.
			local wouldExceed = not enabled and power.Used + definition.PowerDraw > power.Capacity
			Button.new({
				Text = if enabled then "Turn Off" else "Turn On",
				Variant = if enabled then "Secondary" else "Primary",
				AccentColor = if enabled then Theme.Colors.Danger else ACCENT,
				Size = UDim2.fromOffset(112, 32),
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, 0, 0.5, 0),
				Disabled = wouldExceed,
				OnActivated = function()
					setPowerEnabled(structureId, not enabled)
				end,
				Parent = row,
			})

			if wouldExceed then
				FacilityCard.Text({
					Text = `Needs {definition.PowerDraw} power — only {math.max(0, headroom)} spare.`,
					Color = Theme.Colors.Danger,
					LayoutOrder = 3,
					Parent = cardContent,
				})
			end
		end
	end

	if consumerCount == 0 then
		EmptyState.new({
			Glyph = "Power",
			Text = "Nothing draws power yet",
			Subtext = "Machines and powered structures appear here once built.",
			Card = true,
			LayoutOrder = nextOrder(),
			Parent = content,
		})
	end

	activeModal:RevealContent()
end

function GeneratorController.Open()
	local activeModal = modal
	if not activeModal then
		return
	end
	BaseSessionController.Refresh()
	activeModal:Open()
	render()
end

function GeneratorController:Init()
	self._trove = Trove.new()

	modal = FacilityModal.new({
		Id = "Generator",
		Icon = IDENTITY.Icon,
		Title = IDENTITY.Title,
		Subtitle = IDENTITY.Subtitle,
		Accent = ACCENT,
		WidthClass = "Regular",
	})

	FacilityRouter.Register("Generator", function()
		GeneratorController.Open()
	end)
end

function GeneratorController:Start()
	self._trove:Add(FacilityPrompts.Bind({
		Tag = "BaseGeneratorTerminal",
		OnTriggered = function()
			GeneratorController.Open()
		end,
	}))

	self._trove:Add(BaseSessionController.Changed:Connect(function()
		local activeModal = modal
		if activeModal and activeModal:IsOpen() then
			render()
		end
	end))
end

return GeneratorController
