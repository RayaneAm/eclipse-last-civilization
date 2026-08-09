--!strict
-- CAPSULE LABORATORY — the Haven's research facility.
--
-- HONEST SCOPE: there is no research system. No config defines research
-- projects, unlocks or effects; no service tracks discovered technology; and
-- there is no timed-research state anywhere in the session data. Its prompt
-- previously read "View" and did nothing.
--
-- So AVAILABLE / ACTIVE / DISCOVERED exist as real, laid-out tabs with real
-- empty states, and each says plainly that research has not shipped. In
-- particular ACTIVE does NOT draw a progress bar counting down to nothing —
-- the brief is explicit that if timed research does not exist, do not fake
-- it (§46); only the presentation architecture is built.
--
-- What IS real on this screen is the one genuinely related system the game
-- has today: crafting (CraftingConfig + RequestCraft, fronted by the
-- existing crafting panel). Rather than leave the player with a dead end,
-- the AVAILABLE tab points at it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage.Shared.Modules.Trove)

local Theme = require(script.Parent.Parent.UI.Theme)
local FacilityStyle = require(script.Parent.Parent.UI.FacilityStyle)
local FacilityRouter = require(script.Parent.Parent.UI.FacilityRouter)
local FacilityModal = require(script.Parent.Parent.UI.Components.FacilityModal)
local FacilityCard = require(script.Parent.Parent.UI.Components.FacilityCard)
local SectionHeader = require(script.Parent.Parent.UI.Components.SectionHeader)
local StatusChip = require(script.Parent.Parent.UI.Components.StatusChip)
local EmptyState = require(script.Parent.Parent.UI.Components.EmptyState)
local Button = require(script.Parent.Parent.UI.Components.Button)

local LaboratoryController = {}

local IDENTITY = FacilityStyle.Facilities.Laboratory
local ACCENT = IDENTITY.Accent

local TABS = {
	{ Id = "Available", Label = "AVAILABLE" },
	{ Id = "Active", Label = "ACTIVE" },
	{ Id = "Discovered", Label = "DISCOVERED" },
}

local modal: FacilityModal.FacilityModal? = nil
local currentTab = "Available"

local function renderAvailable(content: GuiObject, nextOrder: () -> number)
	local _card, cardContent = FacilityCard.new({
		Name = "ResearchLocked",
		Accent = ACCENT,
		LayoutOrder = nextOrder(),
		Parent = content,
	})

	FacilityCard.Header({
		Icon = "Lab",
		Title = "CAPSULE RESEARCH",
		Subtitle = "Decode recovered survival capsules",
		Accent = ACCENT,
		LayoutOrder = 1,
		Parent = cardContent,
	})
	StatusChip.new({ Status = "Locked", Text = "NOT YET IMPLEMENTED", LayoutOrder = 2, Parent = cardContent })
	FacilityCard.Text({
		Text = "Research projects are not in the game yet. When they arrive, recovered capsules will be decoded here to unlock new technology for your settlement.",
		Color = Theme.Colors.TextMuted,
		LayoutOrder = 3,
		Parent = cardContent,
	})

	-- The real, adjacent system — crafting — so this facility is not a dead
	-- end while research is unbuilt.
	if FacilityRouter.Has("Crafting") then
		SectionHeader.new({
			Text = "Available now",
			Accent = ACCENT,
			LayoutOrder = nextOrder(),
			Parent = content,
		})

		local _craftCard, craftContent = FacilityCard.new({
			Name = "Crafting",
			Accent = Theme.Colors.Brand,
			LayoutOrder = nextOrder(),
			Parent = content,
		})

		FacilityCard.Header({
			Icon = "Build",
			Title = "EQUIPMENT CRAFTING",
			Subtitle = "Build tools and gear from salvaged materials",
			Accent = Theme.Colors.Brand,
			LayoutOrder = 1,
			Parent = craftContent,
		})
		Button.new({
			Text = "Open Crafting",
			Variant = "Primary",
			AccentColor = Theme.Colors.Brand,
			Size = UDim2.new(1, 0, 0, 40),
			LayoutOrder = 2,
			OnActivated = function()
				local activeModal = modal
				if activeModal then
					activeModal:Suspend()
				end
				FacilityRouter.Open("Crafting", { ReturnRoute = "Laboratory", ReturnTab = currentTab })
			end,
			Parent = craftContent,
		})
	end
end

local function renderActive(content: GuiObject, nextOrder: () -> number)
	-- No progress bar here, deliberately. There is no research job to be a
	-- fraction of, and a bar animating toward nothing would be a lie.
	EmptyState.new({
		Glyph = "Lab",
		Text = "No active research",
		Subtext = "Research projects have not been implemented yet.",
		Card = true,
		LayoutOrder = nextOrder(),
		Parent = content,
	})
end

local function renderDiscovered(content: GuiObject, nextOrder: () -> number)
	EmptyState.new({
		Glyph = "Lab",
		Text = "Nothing discovered yet",
		Subtext = "Explore further to recover capsules worth decoding.",
		Card = true,
		LayoutOrder = nextOrder(),
		Parent = content,
	})
end

local function render()
	local activeModal = modal
	if not activeModal then
		return
	end
	activeModal:ClearContent()

	local layoutOrder = 0
	local function nextOrder(): number
		layoutOrder += 1
		return layoutOrder
	end

	if currentTab == "Active" then
		renderActive(activeModal.Content, nextOrder)
	elseif currentTab == "Discovered" then
		renderDiscovered(activeModal.Content, nextOrder)
	else
		renderAvailable(activeModal.Content, nextOrder)
	end

	activeModal:RevealContent()
end

function LaboratoryController.Open(initialTab: string?)
	local activeModal = modal
	if not activeModal then
		return
	end
	currentTab = initialTab or "Available"
	activeModal:Open(currentTab)
	render()
end

function LaboratoryController:Init()
	self._trove = Trove.new()

	modal = FacilityModal.new({
		Id = "Laboratory",
		Icon = IDENTITY.Icon,
		Title = IDENTITY.Title,
		Subtitle = IDENTITY.Subtitle,
		Accent = ACCENT,
		WidthClass = "Regular",
		Tabs = TABS,
		OnTabSelected = function(tabId: string)
			currentTab = tabId
			render()
		end,
	})

	FacilityRouter.Register("Laboratory", function(tabId: string?)
		LaboratoryController.Open(tabId)
	end)
end

function LaboratoryController:Start() end

return LaboratoryController
