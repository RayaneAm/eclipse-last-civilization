--!strict
-- RESOURCE PROCESSOR — opened by pressing E at a production machine's status
-- panel (BaseProductionMachine tag).
--
-- Three states, each with one obvious action (brief §18-§21):
--
--   IDLE     pick a recipe card, see its inputs / output / time, START
--   RUNNING  a live progress bar and a countdown, with CANCEL
--   READY    the finished output, big, with COLLECT
--
-- The countdown is driven by UIAnimator's single shared 1 Hz ticker, bound
-- only while this screen is open and running, and unbound on close — not a
-- per-screen loop, and never a RenderStepped.
--
-- Every action is a real ProductionService call. Cancel genuinely forfeits
-- the already-consumed inputs (that is the server's rule, chosen to make
-- cancel-to-duplicate structurally impossible), so this screen says so
-- before the player confirms rather than letting them find out afterwards.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local Trove = require(ReplicatedStorage.Shared.Modules.Trove)
local BuildingConfig = require(ReplicatedStorage.Shared.Config.BuildingConfig)
local ProductionRecipeConfig = require(ReplicatedStorage.Shared.Config.ProductionRecipeConfig)

local Theme = require(script.Parent.Parent.UI.Theme)
local FacilityStyle = require(script.Parent.Parent.UI.FacilityStyle)
local FacilityRouter = require(script.Parent.Parent.UI.FacilityRouter)
local FacilityPrompts = require(script.Parent.Parent.UI.FacilityPrompts)
local UIAnimator = require(script.Parent.Parent.UI.UIAnimator)
local FacilityModal = require(script.Parent.Parent.UI.Components.FacilityModal)
local FacilityCard = require(script.Parent.Parent.UI.Components.FacilityCard)
local SectionHeader = require(script.Parent.Parent.UI.Components.SectionHeader)
local StatusChip = require(script.Parent.Parent.UI.Components.StatusChip)
local MeterRow = require(script.Parent.Parent.UI.Components.MeterRow)
local ResourceRequirementRow = require(script.Parent.Parent.UI.Components.ResourceRequirementRow)
local ActionBar = require(script.Parent.Parent.UI.Components.ActionBar)
local EmptyState = require(script.Parent.Parent.UI.Components.EmptyState)
local ItemIcon = require(script.Parent.Parent.UI.Components.ItemIcon)
local ConfirmDialog = require(script.Parent.Parent.UI.Components.ConfirmDialog)

local BaseSessionController = require(script.Parent.BaseSessionController)
local NotificationController = require(script.Parent.NotificationController)

local ProductionController = {}

local IDENTITY = FacilityStyle.Facilities.Production
local ACCENT = IDENTITY.Accent

local START_REJECTIONS: { [string]: string } = {
	InsufficientMaterials = "Deposit more input materials into Base Storage",
	InsufficientScrap = "Not enough Scrap",
	InsufficientPower = "Not enough power — build or upgrade the generator",
	MachineBusy = "This machine is already running a job",
	NotAProductionMachine = "This structure cannot run production",
	UnknownRecipe = "That recipe is not valid for this machine",
	BaseNotReady = "Your base is not ready yet",
}

local COLLECT_REJECTIONS: { [string]: string } = {
	StorageFull = "Base Storage is full — withdraw or spend something first",
	NotFinished = "This job is not finished yet",
	AlreadyCollected = "Already collected",
}

local modal: FacilityModal.FacilityModal? = nil
local currentStructureId: string? = nil
local selectedRecipeId: string? = nil
local pendingAction = false
local unbindTicker: (() -> ())? = nil

local function stopTicker()
	if unbindTicker then
		unbindTicker()
		unbindTicker = nil
	end
end

-- ---------------------------------------------------------------------
-- Rendering
-- ---------------------------------------------------------------------

local render: () -> ()

local function renderIdle(content: GuiObject, structureId: string, definition: BuildingConfig.BuildingDefinition, nextOrder: () -> number)
	local recipes = ProductionRecipeConfig.ForMachine(definition.Id)
	if #recipes == 0 then
		EmptyState.new({
			Glyph = "Production",
			Text = "No recipes available",
			Subtext = "This machine has no production recipes yet.",
			Card = true,
			LayoutOrder = nextOrder(),
			Parent = content,
		})
		return
	end

	table.sort(recipes, function(a, b)
		return a.Id < b.Id
	end)

	-- Default to the first recipe so the screen always has a concrete
	-- selection to describe; the player is never looking at an empty shell.
	local selected: ProductionRecipeConfig.ProductionRecipe? = nil
	for _, recipe in recipes do
		if recipe.Id == selectedRecipeId then
			selected = recipe
		end
	end
	if not selected then
		selected = recipes[1]
		selectedRecipeId = selected.Id
	end

	StatusChip.new({ Status = "Idle", Text = "READY TO START", LayoutOrder = nextOrder(), Parent = content })

	if #recipes > 1 then
		SectionHeader.new({ Text = "Recipe", Accent = ACCENT, LayoutOrder = nextOrder(), Parent = content })

		local cards = Instance.new("Frame")
		cards.Name = "RecipeCards"
		cards.Size = UDim2.new(1, 0, 0, 86)
		cards.LayoutOrder = nextOrder()
		cards.BackgroundTransparency = 1
		cards.Parent = content

		local cardsLayout = Instance.new("UIListLayout")
		cardsLayout.FillDirection = Enum.FillDirection.Horizontal
		cardsLayout.Padding = UDim.new(0, Theme.Spacing.S)
		cardsLayout.Parent = cards

		for index, recipe in recipes do
			local isSelected = recipe.Id == selectedRecipeId
			local card = Instance.new("TextButton")
			card.Name = `Recipe_{recipe.Id}`
			card.Size = UDim2.new(1 / #recipes, -Theme.Spacing.S, 1, 0)
			card.LayoutOrder = index
			card.AutoButtonColor = false
			card.Text = ""
			card.BackgroundColor3 = Theme.Colors.CardBackground
			card.BackgroundTransparency = Theme.Transparency.CardBackground
			card.BorderSizePixel = 0
			card.Parent = cards

			local corner = Instance.new("UICorner")
			corner.CornerRadius = Theme.Corner.Medium
			corner.Parent = card

			if isSelected then
				local stroke = Instance.new("UIStroke")
				stroke.Color = ACCENT
				stroke.Thickness = 1.5
				stroke.Transparency = 0.1
				stroke.Parent = card
				local scale = Instance.new("UIScale")
				scale.Scale = 1.02
				scale.Parent = card
			end

			ItemIcon.new({
				ItemId = recipe.OutputItemId,
				Size = UDim2.fromOffset(24, 24),
				Position = UDim2.fromOffset(10, 10),
				Parent = card,
			})

			local name = Instance.new("TextLabel")
			name.Position = UDim2.fromOffset(10, 38)
			name.Size = UDim2.new(1, -20, 0, 30)
			name.BackgroundTransparency = 1
			name.Font = Theme.Font.Label.Font
			name.TextSize = Theme.Font.Label.Size
			name.TextXAlignment = Enum.TextXAlignment.Left
			name.TextYAlignment = Enum.TextYAlignment.Top
			name.TextWrapped = true
			name.TextColor3 = if isSelected then Theme.Colors.TextPrimary else Theme.Colors.TextSecondary
			name.Text = string.upper(recipe.Name)
			name.Parent = card

			local time = Instance.new("TextLabel")
			time.AnchorPoint = Vector2.new(1, 1)
			time.Position = UDim2.new(1, -10, 1, -8)
			time.Size = UDim2.fromOffset(60, 16)
			time.BackgroundTransparency = 1
			time.Font = Theme.Font.Caption.Font
			time.TextSize = Theme.Font.Caption.Size
			time.TextXAlignment = Enum.TextXAlignment.Right
			time.TextColor3 = Theme.Colors.TextMuted
			time.Text = FacilityStyle.FormatClock(recipe.DurationSeconds)
			time.Parent = card

			local cleanupPress = UIAnimator.BindButton(card, function()
				selectedRecipeId = recipe.Id
				render()
			end)
			local cleanupHover = UIAnimator.BindHover(card)
			card.Destroying:Once(function()
				cleanupPress()
				cleanupHover()
			end)
		end
	end

	local recipe = selected :: ProductionRecipeConfig.ProductionRecipe

	SectionHeader.new({ Text = recipe.Name, Accent = ACCENT, LayoutOrder = nextOrder(), Parent = content })

	-- INPUT
	SectionHeader.new({
		Text = "Input",
		Info = "Input materials are taken from Base Storage the moment the job starts.",
		LayoutOrder = nextOrder(),
		Parent = content,
	})

	local _inputCard, inputContent = FacilityCard.new({
		Name = "Input",
		Spacing = Theme.Spacing.XXS,
		LayoutOrder = nextOrder(),
		Parent = content,
	})

	local storage = BaseSessionController.GetStorage()
	local scrap = BaseSessionController.GetScrap()
	local result = ResourceRequirementRow.RenderCost(inputContent, recipe.Materials, storage)
	local affordable = result.Affordable
	local shortfall = result.Summary

	if recipe.Scrap > 0 then
		ResourceRequirementRow.new({
			ItemId = "Scrap",
			Owned = scrap,
			Required = recipe.Scrap,
			LayoutOrder = 100,
			Parent = inputContent,
		})
		if scrap < recipe.Scrap then
			affordable = false
			local missingScrap = recipe.Scrap - scrap
			shortfall = if shortfall then `{shortfall}, {missingScrap} Scrap` else `Missing {missingScrap} Scrap`
		end
	end

	-- OUTPUT + TIME + POWER
	SectionHeader.new({ Text = "Output", LayoutOrder = nextOrder(), Parent = content })

	local _outputCard, outputContent = FacilityCard.new({
		Name = "Output",
		Accent = ACCENT,
		LayoutOrder = nextOrder(),
		Parent = content,
	})

	local outputRow = Instance.new("Frame")
	outputRow.Name = "OutputRow"
	outputRow.Size = UDim2.new(1, 0, 0, 34)
	outputRow.LayoutOrder = 1
	outputRow.BackgroundTransparency = 1
	outputRow.Parent = outputContent

	ItemIcon.new({ ItemId = recipe.OutputItemId, Size = UDim2.fromOffset(28, 28), Parent = outputRow })

	local outputLabel = Instance.new("TextLabel")
	outputLabel.Position = UDim2.fromOffset(38, 0)
	outputLabel.Size = UDim2.new(1, -38, 1, 0)
	outputLabel.BackgroundTransparency = 1
	outputLabel.Font = Theme.Font.Heading.Font
	outputLabel.TextSize = Theme.Font.Heading.Size
	outputLabel.TextXAlignment = Enum.TextXAlignment.Left
	outputLabel.TextColor3 = Theme.Colors.TextPrimary
	outputLabel.Text = `{recipe.OutputQuantity} {FacilityStyle.PrettyName(recipe.OutputItemId)}`
	outputLabel.Parent = outputRow

	local profile = definition.ProductionProfile
	local effectiveDuration = if profile then math.max(1, math.ceil(recipe.DurationSeconds / profile.SpeedMultiplier)) else recipe.DurationSeconds

	local metaRow = Instance.new("Frame")
	metaRow.Name = "Meta"
	metaRow.Size = UDim2.new(1, 0, 0, 20)
	metaRow.LayoutOrder = 2
	metaRow.BackgroundTransparency = 1
	metaRow.Parent = outputContent

	local timeLabel = Instance.new("TextLabel")
	timeLabel.Size = UDim2.new(0.5, 0, 1, 0)
	timeLabel.BackgroundTransparency = 1
	timeLabel.Font = Theme.Font.Caption.Font
	timeLabel.TextSize = Theme.Font.Caption.Size
	timeLabel.TextXAlignment = Enum.TextXAlignment.Left
	timeLabel.TextColor3 = Theme.Colors.TextMuted
	timeLabel.Text = `TIME  {FacilityStyle.FormatClock(effectiveDuration)}`
	timeLabel.Parent = metaRow

	local powerLabel = timeLabel:Clone()
	powerLabel.AnchorPoint = Vector2.new(1, 0)
	powerLabel.Position = UDim2.fromScale(1, 0)
	powerLabel.TextXAlignment = Enum.TextXAlignment.Right
	powerLabel.Text = `POWER  {recipe.PowerDraw}`
	powerLabel.Parent = metaRow

	-- Power is checked server-side at start; surface a foreseeable failure
	-- here rather than letting START come back rejected.
	local power = BaseSessionController.GetPowerSummary()
	local session = BaseSessionController.GetSession()
	local machineDraw = if definition.PowerDraw > 0 and session and session.Power.Enabled[structureId] ~= true then definition.PowerDraw else 0
	if power.Used + machineDraw + recipe.PowerDraw > power.Capacity then
		affordable = false
		shortfall = if power.HasGenerator then "Not enough power capacity for this job" else "Build a generator to run production"
	end

	ActionBar.new({
		PrimaryText = "Start",
		PrimaryAccent = ACCENT,
		BlockedReason = shortfall,
		LayoutOrder = nextOrder(),
		OnPrimary = function()
			if pendingAction or not affordable then
				return
			end
			pendingAction = true
			local ok, reason = Net.GetFunction("RequestStartProduction"):InvokeServer({
				MachineStructureId = structureId,
				RecipeId = recipe.Id,
			})
			pendingAction = false

			if ok then
				NotificationController.Toast("BuildConfirmed", `{recipe.Name} started`)
			else
				NotificationController.Toast("BuildRejected", START_REJECTIONS[tostring(reason)] or `Could not start: {tostring(reason)}`)
			end
		end,
		Parent = content,
	})
end

local function renderRunning(content: GuiObject, job: any, nextOrder: () -> number)
	local recipe = ProductionRecipeConfig.Get(job.RecipeId)
	local remaining = math.max(0, job.CompletesAt - os.time())
	local total = math.max(1, job.CompletesAt - job.StartedAt)

	StatusChip.new({ Status = "Running", LayoutOrder = nextOrder(), Parent = content })

	SectionHeader.new({
		Text = if recipe then recipe.Name else job.RecipeId,
		Accent = ACCENT,
		LayoutOrder = nextOrder(),
		Parent = content,
	})

	local _card, cardContent = FacilityCard.new({
		Name = "Progress",
		Accent = ACCENT,
		LayoutOrder = nextOrder(),
		Parent = content,
	})

	local _meter, setProgress, setValue = MeterRow.new({
		Name = "JobProgress",
		Label = "Progress",
		Value = `{FacilityStyle.FormatClock(remaining)} remaining`,
		Progress = 1 - remaining / total,
		Accent = ACCENT,
		LayoutOrder = 1,
		Parent = cardContent,
	})

	if recipe then
		FacilityCard.Text({
			Text = `Producing {recipe.OutputQuantity} {FacilityStyle.PrettyName(recipe.OutputItemId)}.`,
			LayoutOrder = 2,
			Parent = cardContent,
		})
	end

	-- One shared-ticker subscription for the whole screen. It re-reads the
	-- job each second rather than closing over a stale copy, and re-renders
	-- once when the job actually completes so READY appears without the
	-- player having to reopen the panel.
	stopTicker()
	unbindTicker = UIAnimator.BindTicker(function()
		local activeModal = modal
		if not activeModal or not activeModal:IsOpen() then
			stopTicker()
			return
		end
		local secondsLeft = math.max(0, job.CompletesAt - os.time())
		setProgress(1 - secondsLeft / total)
		setValue(`{FacilityStyle.FormatClock(secondsLeft)} remaining`)
		if secondsLeft <= 0 then
			stopTicker()
			UIAnimator.PlaySound("ProductionReady")
			render()
		end
	end)

	ActionBar.new({
		PrimaryText = "Cancel Job",
		PrimaryAccent = Theme.Colors.Danger,
		LayoutOrder = nextOrder(),
		OnPrimary = function()
			if pendingAction then
				return
			end
			-- The forfeit is disclosed before the player commits, because the
			-- server genuinely does not refund (that rule is what makes a
			-- cancel-to-duplicate exploit impossible).
			ConfirmDialog.Show({
				Title = "Cancel Production",
				Message = "The materials and Scrap this job already consumed will NOT be refunded. Cancel anyway?",
				ConfirmText = "Cancel Job",
				Danger = true,
				OnConfirm = function()
					if pendingAction then
						return
					end
					pendingAction = true
					local ok, reason = Net.GetFunction("RequestCancelProduction"):InvokeServer({ JobId = job.Id })
					pendingAction = false
					if not ok then
						NotificationController.Toast("BuildRejected", `Could not cancel: {tostring(reason)}`)
					end
				end,
			})
		end,
		Parent = content,
	})
end

local function renderReady(content: GuiObject, job: any, nextOrder: () -> number)
	local recipe = ProductionRecipeConfig.Get(job.RecipeId)

	StatusChip.new({ Status = "Ready", LayoutOrder = nextOrder(), Parent = content })
	SectionHeader.new({ Text = "Output", Accent = Theme.Colors.Success, LayoutOrder = nextOrder(), Parent = content })

	local _card, cardContent = FacilityCard.new({
		Name = "ReadyOutput",
		Accent = Theme.Colors.Success,
		LayoutOrder = nextOrder(),
		Parent = content,
	})

	local row = Instance.new("Frame")
	row.Name = "OutputRow"
	row.Size = UDim2.new(1, 0, 0, 48)
	row.LayoutOrder = 1
	row.BackgroundTransparency = 1
	row.Parent = cardContent

	if recipe then
		ItemIcon.new({ ItemId = recipe.OutputItemId, Size = UDim2.fromOffset(40, 40), Parent = row })

		local label = Instance.new("TextLabel")
		label.Position = UDim2.fromOffset(52, 0)
		label.Size = UDim2.new(1, -52, 1, 0)
		label.BackgroundTransparency = 1
		label.Font = Theme.Font.Title.Font
		label.TextSize = Theme.Font.Title.Size
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextColor3 = Theme.Colors.TextPrimary
		label.Text = `{recipe.OutputQuantity} {string.upper(FacilityStyle.PrettyName(recipe.OutputItemId))}`
		label.Parent = row
	end

	-- Collect fails server-side if the output would overflow storage, so
	-- warn before the click rather than after the rejection.
	local storage = BaseSessionController.GetStorageSummary()
	local incoming = if recipe then recipe.OutputQuantity else 0
	local wouldOverflow = storage.Capacity > 0 and storage.Used + incoming > storage.Capacity

	ActionBar.new({
		PrimaryText = "Collect",
		PrimaryAccent = Theme.Colors.Success,
		BlockedReason = if wouldOverflow then `Base Storage is full ({storage.Used} / {storage.Capacity})` else nil,
		LayoutOrder = nextOrder(),
		OnPrimary = function()
			if pendingAction or wouldOverflow then
				return
			end
			pendingAction = true
			local ok, reason = Net.GetFunction("RequestCollectProduction"):InvokeServer({ JobId = job.Id })
			pendingAction = false
			if ok then
				NotificationController.Toast("BuildConfirmed", "Collected into Base Storage")
			else
				NotificationController.Toast("BuildRejected", COLLECT_REJECTIONS[tostring(reason)] or `Collect failed: {tostring(reason)}`)
			end
		end,
		Parent = content,
	})
end

render = function()
	local activeModal = modal
	local structureId = currentStructureId
	if not activeModal or not structureId then
		return
	end

	stopTicker()
	activeModal:ClearContent()

	local content = activeModal.Content
	local layoutOrder = 0
	local function nextOrder(): number
		layoutOrder += 1
		return layoutOrder
	end

	local session = BaseSessionController.GetSession()
	local structure = session and session.Structures[structureId]
	local definition = structure and BuildingConfig.Get(structure.BuildingId)

	if not structure or not definition then
		EmptyState.new({
			Glyph = "Production",
			Text = "Machine unavailable",
			Subtext = "This structure no longer exists.",
			Card = true,
			LayoutOrder = nextOrder(),
			Parent = content,
		})
		activeModal:RevealContent()
		return
	end

	activeModal:SetHeader(string.upper(definition.Name), definition.Description)

	local job = BaseSessionController.GetActiveJob(structureId)
	if not job then
		renderIdle(content, structureId, definition, nextOrder)
	elseif os.time() < job.CompletesAt then
		renderRunning(content, job, nextOrder)
	else
		renderReady(content, job, nextOrder)
	end

	activeModal:RevealContent()
end

-- ---------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------

function ProductionController.Open(structureId: string?)
	local activeModal = modal
	if not activeModal then
		return
	end
	BaseSessionController.Refresh()

	local target = structureId
	if not target then
		-- Opened from a summary screen rather than from a specific machine:
		-- prefer one that needs attention (ready first, then idle).
		local session = BaseSessionController.GetSession()
		if session then
			local fallback: string? = nil
			for candidateId, structure in session.Structures do
				local definition = BuildingConfig.Get(structure.BuildingId)
				if definition and definition.Category == "Production" then
					fallback = fallback or candidateId
					local job = BaseSessionController.GetActiveJob(candidateId)
					if job and os.time() >= job.CompletesAt then
						target = candidateId
						break
					end
				end
			end
			target = target or fallback
		end
	end

	if not target then
		NotificationController.Toast("BuildRejected", "Build a Resource Processor first")
		return
	end

	currentStructureId = target
	selectedRecipeId = nil
	activeModal:Open()
	render()
end

function ProductionController:Init()
	self._trove = Trove.new()

	modal = FacilityModal.new({
		Id = "Production",
		Icon = IDENTITY.Icon,
		Title = IDENTITY.Title,
		Subtitle = IDENTITY.Subtitle,
		Accent = ACCENT,
		WidthClass = "Regular",
		OnClose = function()
			-- The ticker must never outlive the screen it drives.
			stopTicker()
		end,
	})

	FacilityRouter.Register("Production", function(structureId: string?)
		ProductionController.Open(structureId)
	end)
end

function ProductionController:Start()
	self._trove:Add(FacilityPrompts.Bind({
		Tag = "BaseProductionMachine",
		OnTriggered = function(host: BasePart)
			local structureId = host:GetAttribute("StructureId")
			if typeof(structureId) ~= "string" then
				return
			end
			BaseSessionController.Refresh()

			-- Walking up to a machine that is DONE should just collect it —
			-- opening a panel to press one button is friction for the most
			-- common interaction. Anything else opens the full screen.
			local job = BaseSessionController.GetActiveJob(structureId)
			if job and os.time() >= job.CompletesAt then
				local ok, reason = Net.GetFunction("RequestCollectProduction"):InvokeServer({ JobId = job.Id })
				if ok then
					NotificationController.Toast("BuildConfirmed", "Production collected into Base Storage")
					return
				end
				-- A failed quick-collect (storage full) falls through to the
				-- panel, which explains the problem properly.
				NotificationController.Toast("BuildRejected", COLLECT_REJECTIONS[tostring(reason)] or `Collect failed: {tostring(reason)}`)
			end

			ProductionController.Open(structureId)
		end,
	}))

	self._trove:Add(BaseSessionController.Changed:Connect(function()
		local activeModal = modal
		if activeModal and activeModal:IsOpen() then
			render()
		end
	end))
end

return ProductionController
