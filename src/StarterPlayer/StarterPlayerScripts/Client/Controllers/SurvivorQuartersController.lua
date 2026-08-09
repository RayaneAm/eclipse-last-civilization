--!strict
-- SURVIVOR QUARTERS — opened at the quarters (BaseQuartersTerminal tag).
--
-- HONEST SCOPE: there are no survivors in this game yet. Nothing in
-- BaseSessionTypes stores a survivor roster, no service assigns or houses
-- one, and no config defines survivor names, states or base bonuses. So this
-- screen shows NO survivor list, NO capacity like "2 / 4", and no invented
-- names — the brief is explicit that a facility without a backend gets a
-- polished shell, never fabricated content (§26/§56).
--
-- What it DOES show is entirely real: that the structure is built, its
-- level, its power draw and whether it is currently switched on (all
-- replicated session state), plus a clear statement of what the building
-- will do once survivors ship. That gives the player a truthful answer to
-- "what is this?" and "what does it do right now?", which is the actual job
-- of this screen today.
--
-- When a survivor system lands, the roster and capacity meter replace the
-- locked block below; the rest of this screen already fits.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage.Shared.Modules.Trove)
local BuildingConfig = require(ReplicatedStorage.Shared.Config.BuildingConfig)

local Theme = require(script.Parent.Parent.UI.Theme)
local FacilityStyle = require(script.Parent.Parent.UI.FacilityStyle)
local FacilityRouter = require(script.Parent.Parent.UI.FacilityRouter)
local FacilityPrompts = require(script.Parent.Parent.UI.FacilityPrompts)
local FacilityModal = require(script.Parent.Parent.UI.Components.FacilityModal)
local FacilityCard = require(script.Parent.Parent.UI.Components.FacilityCard)
local SectionHeader = require(script.Parent.Parent.UI.Components.SectionHeader)
local StatusChip = require(script.Parent.Parent.UI.Components.StatusChip)
local EmptyState = require(script.Parent.Parent.UI.Components.EmptyState)
local Button = require(script.Parent.Parent.UI.Components.Button)

local BaseSessionController = require(script.Parent.BaseSessionController)

local SurvivorQuartersController = {}

local IDENTITY = FacilityStyle.Facilities.Quarters
local ACCENT = IDENTITY.Accent

local modal: FacilityModal.FacilityModal? = nil

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

	local structureId, structure = BaseSessionController.FindStructureByBuildingId("SurvivorQuarters")
	local definition = BuildingConfig.Get("SurvivorQuarters")

	if not structureId or not structure or not definition then
		EmptyState.new({
			Glyph = "Quarters",
			Text = "Quarters not built",
			Subtext = "Build Survivor Quarters at its construction node.",
			Card = true,
			LayoutOrder = nextOrder(),
			Parent = content,
		})
		activeModal:RevealContent()
		return
	end

	local session = BaseSessionController.GetSession()
	local enabled = session and session.Power.Enabled[structureId] == true
	local maxHealth = BuildingConfig.GetMaxHealth("SurvivorQuarters")

	-- Real structure state.
	local _statusCard, statusContent = FacilityCard.new({
		Name = "Structure",
		Accent = ACCENT,
		LayoutOrder = nextOrder(),
		Parent = content,
	})

	FacilityCard.Header({
		Icon = "Quarters",
		Title = definition.Name,
		Subtitle = `Level {structure.Level} · {structure.Health} / {maxHealth} health`,
		Accent = ACCENT,
		LayoutOrder = 1,
		Parent = statusContent,
	})
	StatusChip.new({
		Status = if enabled then "Running" else "Offline",
		Text = if enabled then "POWERED" else "UNPOWERED",
		LayoutOrder = 2,
		Parent = statusContent,
	})
	FacilityCard.Text({
		Text = definition.Description or "Provides shelter for your settlement.",
		LayoutOrder = 3,
		Parent = statusContent,
	})

	if definition.PowerDraw > 0 and not enabled then
		FacilityCard.Text({
			Text = `Draws {definition.PowerDraw} power when switched on. Manage it at the generator.`,
			Color = Theme.Colors.TextMuted,
			LayoutOrder = 4,
			Parent = statusContent,
		})
	end

	-- The unimplemented part, stated plainly.
	SectionHeader.new({ Text = "Survivors", LayoutOrder = nextOrder(), Parent = content })

	local _lockedCard, lockedContent = FacilityCard.new({
		Name = "SurvivorsLocked",
		LayoutOrder = nextOrder(),
		Parent = content,
	})

	StatusChip.new({ Status = "Locked", Text = "NOT YET IMPLEMENTED", LayoutOrder = 1, Parent = lockedContent })
	FacilityCard.Text({
		Text = "Survivors are not in the game yet. Once they arrive, this is where you will house them and see the bonuses they give your settlement.",
		Color = Theme.Colors.TextMuted,
		LayoutOrder = 2,
		Parent = lockedContent,
	})

	if FacilityRouter.Has("Generator") then
		Button.new({
			Text = "Open Generator",
			Variant = "Secondary",
			AccentColor = FacilityStyle.Accents.Generator,
			Size = UDim2.new(1, 0, 0, 40),
			LayoutOrder = nextOrder(),
			OnActivated = function()
				FacilityRouter.Open("Generator")
			end,
			Parent = content,
		})
	end

	activeModal:RevealContent()
end

function SurvivorQuartersController.Open()
	local activeModal = modal
	if not activeModal then
		return
	end
	BaseSessionController.Refresh()
	activeModal:Open()
	render()
end

function SurvivorQuartersController:Init()
	self._trove = Trove.new()

	modal = FacilityModal.new({
		Id = "SurvivorQuarters",
		Icon = IDENTITY.Icon,
		Title = IDENTITY.Title,
		Subtitle = IDENTITY.Subtitle,
		Accent = ACCENT,
		WidthClass = "Compact",
	})

	FacilityRouter.Register("SurvivorQuarters", function()
		SurvivorQuartersController.Open()
	end)
end

function SurvivorQuartersController:Start()
	self._trove:Add(FacilityPrompts.Bind({
		Tag = "BaseQuartersTerminal",
		OnTriggered = function()
			SurvivorQuartersController.Open()
		end,
	}))

	self._trove:Add(BaseSessionController.Changed:Connect(function()
		local activeModal = modal
		if activeModal and activeModal:IsOpen() then
			render()
		end
	end))
end

return SurvivorQuartersController
