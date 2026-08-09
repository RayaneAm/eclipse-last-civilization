--!strict
-- DEFENSE CONTROL — opened at the defense mast (BaseDefenseTerminal tag).
--
-- The perimeter at a glance: per-side integrity bars, tier pips, open
-- sockets called out, and the two actions that are actually backed today —
-- REPAIR (BuildingService.RequestRepairBuilding) and VIEW/upgrade (routed to
-- the shared upgrade screen).
--
-- Turrets, machine guns, lasers, barriers and power routing are explicitly
-- NOT implemented — no such gameplay system exists. Rather than showing
-- fake toggles, the bottom of this screen states what is planned and offers
-- nothing to press (brief §25/§56). When those systems ship they slot in
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
local TierPips = require(script.Parent.Parent.UI.Components.TierPips)
local StatusChip = require(script.Parent.Parent.UI.Components.StatusChip)
local EmptyState = require(script.Parent.Parent.UI.Components.EmptyState)
local Button = require(script.Parent.Parent.UI.Components.Button)

local BaseSessionController = require(script.Parent.BaseSessionController)
local NotificationController = require(script.Parent.NotificationController)

local DefenseControlController = {}

local IDENTITY = FacilityStyle.Facilities.Defense
local ACCENT = IDENTITY.Accent

local REPAIR_REJECTIONS: { [string]: string } = {
	AlreadyFullHealth = "That structure is already at full health",
	CannotAfford = "Not enough materials in Base Storage to repair",
	UnknownStructure = "This structure no longer exists",
	BaseNotReady = "Your base is not ready yet",
}

local modal: FacilityModal.FacilityModal? = nil
local pendingAction = false

local function repair(structureId: string, name: string)
	if pendingAction then
		return
	end
	pendingAction = true
	local ok, reason = Net.GetFunction("RequestRepairBuilding"):InvokeServer({ StructureId = structureId })
	pendingAction = false
	if ok then
		NotificationController.Toast("BuildConfirmed", `{name} repaired ✓`)
	else
		NotificationController.Toast("BuildRejected", REPAIR_REJECTIONS[tostring(reason)] or `Repair failed: {tostring(reason)}`)
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

	local defense = BaseSessionController.GetDefenseSummary()

	if #defense == 0 then
		EmptyState.new({
			Glyph = "Defense",
			Text = "No perimeter sockets yet",
			Subtext = "Build Defense Control to unlock the wall sockets around your settlement.",
			Card = true,
			LayoutOrder = nextOrder(),
			Parent = content,
		})
		activeModal:RevealContent()
		return
	end

	-- Overall integrity, so the headline answer ("are my walls OK?") is the
	-- first thing on screen.
	local totalHealth, totalMax, openSockets = 0, 0, 0
	for _, group in defense do
		totalHealth += group.Health
		totalMax += group.MaxHealth
		openSockets += group.Sockets - group.Built
	end
	local integrity = if totalMax > 0 then totalHealth / totalMax else 0

	local _summaryCard, summaryContent = FacilityCard.new({
		Name = "Summary",
		Accent = ACCENT,
		LayoutOrder = nextOrder(),
		Parent = content,
	})

	FacilityCard.Header({ Icon = "Defense", Title = "PERIMETER", Accent = ACCENT, LayoutOrder = 1, Parent = summaryContent })
	StatusChip.new({
		Status = if openSockets > 0 then "Critical" elseif integrity < 0.6 then "Low" else "Stable",
		Text = if openSockets > 0 then `{openSockets} OPEN` elseif integrity < 0.6 then "DAMAGED" else "SECURE",
		LayoutOrder = 2,
		Parent = summaryContent,
	})
	if totalMax > 0 then
		MeterRow.new({
			Label = "Integrity",
			Value = `{math.floor(integrity * 100 + 0.5)}%`,
			Progress = integrity,
			Accent = if integrity < 0.6 then Theme.Colors.Warning else ACCENT,
			LayoutOrder = 3,
			Parent = summaryContent,
		})
	end

	-- Per-side breakdown.
	SectionHeader.new({
		Text = "Sides",
		Accent = ACCENT,
		Info = "A side is only as strong as its weakest socket, so the tier shown is the lowest along that side.",
		LayoutOrder = nextOrder(),
		Parent = content,
	})

	for _, group in defense do
		local fraction = if group.MaxHealth > 0 then group.Health / group.MaxHealth else 0
		local _card, cardContent = FacilityCard.new({
			Name = `Side_{group.Group}`,
			Accent = FacilityStyle.TierAccent(group.Tier),
			LayoutOrder = nextOrder(),
			Parent = content,
		})

		TierPips.Row({
			Name = `{group.Group} Wall`,
			Tier = group.Tier,
			LayoutOrder = 1,
			Parent = cardContent,
		})

		if group.Built < group.Sockets then
			FacilityCard.Text({
				Text = `{group.Sockets - group.Built} of {group.Sockets} sockets still open — anything can walk through.`,
				Color = Theme.Colors.Danger,
				LayoutOrder = 2,
				Parent = cardContent,
			})
		end

		if group.MaxHealth > 0 then
			MeterRow.new({
				Label = "Health",
				Value = `{group.Health} / {group.MaxHealth}`,
				Progress = fraction,
				Accent = if fraction < 0.5 then Theme.Colors.Danger elseif fraction < 1 then Theme.Colors.Warning else ACCENT,
				Compact = true,
				LayoutOrder = 3,
				Parent = cardContent,
			})
		end
	end

	-- Damaged structures with a real repair action.
	local damaged = BaseSessionController.GetDamagedStructures()
	if #damaged > 0 then
		SectionHeader.new({
			Text = "Needs repair",
			Accent = Theme.Colors.Warning,
			Info = "Repair cost is a fraction of the original build cost, scaled to how much health is missing.",
			LayoutOrder = nextOrder(),
			Parent = content,
		})

		for index, entry in damaged do
			if index > 5 then
				break
			end
			local maxHealth = BuildingConfig.GetMaxHealth(entry.Structure.BuildingId)
			local _card, cardContent = FacilityCard.new({
				Name = `Damaged_{entry.StructureId}`,
				Accent = Theme.Colors.Warning,
				Padding = Theme.Spacing.S,
				LayoutOrder = nextOrder(),
				Parent = content,
			})

			FacilityCard.Header({
				Title = entry.Definition.Name,
				Subtitle = `{entry.Structure.Health} / {maxHealth} health`,
				LayoutOrder = 1,
				Parent = cardContent,
			})

			local row = Instance.new("Frame")
			row.Name = "RepairRow"
			row.Size = UDim2.new(1, 0, 0, 34)
			row.LayoutOrder = 2
			row.BackgroundTransparency = 1
			row.Parent = cardContent

			local structureId = entry.StructureId
			local name = entry.Definition.Name
			Button.new({
				Text = "Repair",
				Variant = "Primary",
				AccentColor = Theme.Colors.Warning,
				Size = UDim2.fromOffset(120, 32),
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, 0, 0.5, 0),
				OnActivated = function()
					repair(structureId, name)
				end,
				Parent = row,
			})
		end
	end

	-- Strongest available upgrade, routed to the shared upgrade screen.
	local candidates = BaseSessionController.GetUpgradeCandidates()
	local wallUpgrade: BaseSessionController.UpgradeCandidate? = nil
	for _, candidate in candidates do
		if candidate.Current.DefenseTier then
			wallUpgrade = candidate
			break
		end
	end

	if wallUpgrade and FacilityRouter.Has("UpgradeStructure") then
		local target = wallUpgrade :: BaseSessionController.UpgradeCandidate
		SectionHeader.new({ Text = "Next upgrade", Accent = FacilityStyle.Accents.UpgradeStation, LayoutOrder = nextOrder(), Parent = content })
		Button.new({
			Text = `View {target.Current.Name} Upgrade`,
			Variant = "Secondary",
			AccentColor = FacilityStyle.Accents.UpgradeStation,
			Size = UDim2.new(1, 0, 0, 40),
			LayoutOrder = nextOrder(),
			OnActivated = function()
				FacilityRouter.Open("UpgradeStructure", target.StructureId)
			end,
			Parent = content,
		})
	end

	-- Planned systems. Nothing pressable, because nothing is implemented.
	SectionHeader.new({ Text = "Automated defenses", LayoutOrder = nextOrder(), Parent = content })
	local _plannedCard, plannedContent = FacilityCard.new({
		Name = "Planned",
		LayoutOrder = nextOrder(),
		Parent = content,
	})
	StatusChip.new({ Status = "Locked", Text = "NOT YET IMPLEMENTED", LayoutOrder = 1, Parent = plannedContent })
	FacilityCard.Text({
		Text = "Turrets, barriers and power routing are planned for a later update. Walls and gates are the only defenses in the game today.",
		Color = Theme.Colors.TextMuted,
		LayoutOrder = 2,
		Parent = plannedContent,
	})

	activeModal:RevealContent()
end

function DefenseControlController.Open()
	local activeModal = modal
	if not activeModal then
		return
	end
	BaseSessionController.Refresh()
	activeModal:Open()
	render()
end

function DefenseControlController:Init()
	self._trove = Trove.new()

	modal = FacilityModal.new({
		Id = "DefenseControl",
		Icon = IDENTITY.Icon,
		Title = IDENTITY.Title,
		Subtitle = IDENTITY.Subtitle,
		Accent = ACCENT,
		WidthClass = "Regular",
	})

	FacilityRouter.Register("Defense", function()
		DefenseControlController.Open()
	end)
end

function DefenseControlController:Start()
	self._trove:Add(FacilityPrompts.Bind({
		Tag = "BaseDefenseTerminal",
		OnTriggered = function()
			DefenseControlController.Open()
		end,
	}))

	self._trove:Add(BaseSessionController.Changed:Connect(function()
		local activeModal = modal
		if activeModal and activeModal:IsOpen() then
			render()
		end
	end))
end

return DefenseControlController
