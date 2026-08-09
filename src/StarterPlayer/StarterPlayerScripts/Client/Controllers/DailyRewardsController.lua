--!strict
-- DAILY SUPPLY DROP — the Daily Rewards screen, opened from the Haven's
-- Daily Rewards facility.
--
-- SERVER DECIDES, CLIENT REVEALS. This is the single most important property
-- of this file. DailyRewardsService.Claim picks the reward inside one atomic
-- UpdateAsync, durably records it, and grants it — all before this controller
-- learns anything. The carousel below is played only AFTER that result comes
-- back, and its landing position is computed from the returned index. The
-- client never picks, never previews and never predicts an outcome, and the
-- screen never shows success before the server has confirmed it (brief §29).
--
-- Opening the screen does NOT spin. It calls the read-only status remote to
-- learn whether a spin is available, then waits for the player to press SPIN
-- (brief §27). Before this pass, the only way to find out was to claim.
--
-- MONETIZATION BOUNDARY (brief §35-§40), enforced structurally here:
--   * There is no "buy another spin", no paid reroll, no paid rarity boost
--     and no Robux entry point anywhere in this file. The daily spin is free
--     and earned by returning.
--   * The Season Bonus block is DETERMINISTIC and fully itemized before
--     claiming — never a purchasable roll. It is also not implemented yet
--     (SeasonBonusConfig.Implemented = false), so its action stays disabled
--     and VIEW PASS merely opens the existing shop screen on an explicit
--     press; nothing here ever auto-prompts a purchase.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local Trove = require(ReplicatedStorage.Shared.Modules.Trove)
local DailyRewardConfig = require(ReplicatedStorage.Shared.Config.DailyRewardConfig)
local RarityConfig = require(ReplicatedStorage.Shared.Config.RarityConfig)
local SeasonBonusConfig = require(ReplicatedStorage.Shared.Config.SeasonBonusConfig)

local Theme = require(script.Parent.Parent.UI.Theme)
local FacilityStyle = require(script.Parent.Parent.UI.FacilityStyle)
local FacilityRouter = require(script.Parent.Parent.UI.FacilityRouter)
local UIAnimator = require(script.Parent.Parent.UI.UIAnimator)
local FacilityModal = require(script.Parent.Parent.UI.Components.FacilityModal)
local FacilityCard = require(script.Parent.Parent.UI.Components.FacilityCard)
local SectionHeader = require(script.Parent.Parent.UI.Components.SectionHeader)
local RarityCard = require(script.Parent.Parent.UI.Components.RarityCard)
local StatusChip = require(script.Parent.Parent.UI.Components.StatusChip)
local ActionBar = require(script.Parent.Parent.UI.Components.ActionBar)
local Button = require(script.Parent.Parent.UI.Components.Button)
local ItemIcon = require(script.Parent.Parent.UI.Components.ItemIcon)

local NotificationController = require(script.Parent.NotificationController)

local DailyRewardsController = {}

local IDENTITY = FacilityStyle.Facilities.DailyRewards
local ACCENT = IDENTITY.Accent

local CARD_GAP = 12
local CARD_STRIDE = RarityCard.WIDTH + CARD_GAP
local STRIP_CARD_COUNT = 34
-- The winner sits a few cards from the end so there is still something
-- visible sliding in behind it when the strip settles.
local WINNER_INDEX = STRIP_CARD_COUNT - 3
local IDLE_CARD_SCALE = 0.88
local CAROUSEL_HEIGHT = RarityCard.HEIGHT + 20

type Phase = "Idle" | "Spinning" | "Result" | "Claimed" | "Unknown"

local modal: FacilityModal.FacilityModal? = nil
local phase: Phase = "Unknown"
local spinAvailable = false
local currentStreak = 0
local secondsUntilReset = 0
local resultIndex: number? = nil
local requestInFlight = false
local unbindCountdown: (() -> ())? = nil

local function stopCountdown()
	if unbindCountdown then
		unbindCountdown()
		unbindCountdown = nil
	end
end

local render: () -> ()

-- ---------------------------------------------------------------------
-- Server calls
-- ---------------------------------------------------------------------

-- Read-only. Never claims. A failure leaves the screen in "Unknown", which
-- renders as an honest "couldn't reach the supply drop" rather than an
-- optimistic SPIN button.
local function refreshStatus()
	local ok, status = pcall(function()
		return Net.GetFunction("RequestDailyRewardStatus"):InvokeServer()
	end)

	if ok and typeof(status) == "table" then
		spinAvailable = status.Available == true
		currentStreak = status.Streak or 0
		secondsUntilReset = status.SecondsUntilReset or 0
		phase = if spinAvailable then "Idle" else "Claimed"
	else
		phase = "Unknown"
	end
end

-- ---------------------------------------------------------------------
-- Streak strip
-- ---------------------------------------------------------------------

-- D1..D7 with the days already earned marked, today highlighted, and the
-- final day flagged as the best one. `currentStreak` is the count of
-- consecutive days ALREADY claimed, so the day being played for is the next
-- one along.
local function buildStreakStrip(parent: Instance, layoutOrder: number)
	local cycle = DailyRewardConfig.StreakCycleDays
	local completedInCycle = currentStreak % cycle
	-- A completed full cycle should read as "all seven done", not "zero".
	if currentStreak > 0 and completedInCycle == 0 then
		completedInCycle = cycle
	end
	local todayIndex = if spinAvailable then math.min(completedInCycle + 1, cycle) else completedInCycle

	local strip = Instance.new("Frame")
	strip.Name = "StreakStrip"
	strip.Size = UDim2.new(1, 0, 0, 54)
	strip.LayoutOrder = layoutOrder
	strip.BackgroundTransparency = 1
	strip.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalFlex = Enum.UIFlexAlignment.SpaceBetween
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = strip

	for day = 1, cycle do
		local isDone = day <= completedInCycle
		local isToday = day == todayIndex and spinAvailable
		local isBestDay = day == cycle

		local cell = Instance.new("Frame")
		cell.Name = `Day{day}`
		cell.Size = UDim2.fromOffset(38, 54)
		cell.LayoutOrder = day
		cell.BackgroundTransparency = 1
		cell.Parent = strip

		local marker = Instance.new("Frame")
		marker.Name = "Marker"
		marker.Size = UDim2.fromOffset(30, 30)
		marker.Position = UDim2.new(0.5, 0, 0, 0)
		marker.AnchorPoint = Vector2.new(0.5, 0)
		marker.BackgroundColor3 = if isDone then Theme.Colors.Success elseif isToday then ACCENT else Theme.Colors.CardBackground
		marker.BackgroundTransparency = if isDone or isToday then 0.15 else 0.1
		marker.BorderSizePixel = 0
		marker.Parent = cell

		local corner = Instance.new("UICorner")
		corner.CornerRadius = Theme.Corner.Pill
		corner.Parent = marker

		if isToday then
			local stroke = Instance.new("UIStroke")
			stroke.Color = ACCENT
			stroke.Thickness = 2
			stroke.Transparency = 0
			stroke.Parent = marker
		end

		local glyph = Instance.new("TextLabel")
		glyph.Size = UDim2.fromScale(1, 1)
		glyph.BackgroundTransparency = 1
		glyph.Font = Enum.Font.GothamBold
		glyph.TextSize = 14
		glyph.TextColor3 = if isDone or isToday then Color3.fromRGB(18, 16, 24) else Theme.Colors.TextMuted
		-- A drawn star would need its own geometry; the day number is the
		-- clearer label anyway, and the best-day cue is carried by the
		-- rarity floor caption below it.
		glyph.Text = tostring(day)
		glyph.Parent = marker

		local caption = Instance.new("TextLabel")
		caption.Name = "Floor"
		caption.Position = UDim2.new(0, 0, 0, 34)
		caption.Size = UDim2.new(1, 0, 0, 16)
		caption.BackgroundTransparency = 1
		caption.Font = Theme.Font.Caption.Font
		caption.TextSize = 9
		caption.TextColor3 = if isBestDay then ACCENT else Theme.Colors.TextMuted
		local target = DailyRewardConfig.StreakRarityTargets[day]
		caption.Text = if target then string.sub(RarityConfig.Get(target).Label, 1, 4) else ""
		caption.Parent = cell
	end
end

-- ---------------------------------------------------------------------
-- Season bonus
-- ---------------------------------------------------------------------

local function buildSeasonBonus(parent: Instance, layoutOrder: number)
	SectionHeader.new({ Text = "Season Bonus", Accent = ACCENT, LayoutOrder = layoutOrder, Parent = parent })

	local _card, cardContent = FacilityCard.new({
		Name = "SeasonBonus",
		Accent = ACCENT,
		LayoutOrder = layoutOrder + 1,
		Parent = parent,
	})

	FacilityCard.Header({
		Icon = "Gift",
		Title = SeasonBonusConfig.Name,
		Subtitle = "One fixed bonus drop per day",
		Accent = ACCENT,
		LayoutOrder = 1,
		Parent = cardContent,
	})

	local bonusRow = Instance.new("Frame")
	bonusRow.Name = "BonusContents"
	bonusRow.Size = UDim2.new(1, 0, 0, 58)
	bonusRow.LayoutOrder = 2
	bonusRow.BackgroundTransparency = 1
	bonusRow.Parent = cardContent

	-- The contents are shown in full BEFORE any claim, because a Season Pass
	-- benefit is deterministic value the player can see, never a hidden roll.
	for index, line in SeasonBonusConfig.Contents do
		local cell = Instance.new("Frame")
		cell.Name = `Bonus{index}`
		cell.Position = UDim2.new((index - 1) / #SeasonBonusConfig.Contents, 0, 0, 0)
		cell.Size = UDim2.new(1 / #SeasonBonusConfig.Contents, 0, 1, 0)
		cell.BackgroundColor3 = Theme.Colors.CardBackground
		cell.BackgroundTransparency = 0.35
		cell.BorderSizePixel = 0
		cell.Parent = bonusRow
		local cellCorner = Instance.new("UICorner")
		cellCorner.CornerRadius = Theme.Corner.Small
		cellCorner.Parent = cell

		local itemId = if line.Kind == "Currency" then "Scrap" else (line.ItemId or "EclipseShard")
		ItemIcon.new({
			ItemId = itemId,
			Size = UDim2.fromOffset(34, 34),
			Position = UDim2.new(0.5, 0, 0, 2),
			AnchorPoint = Vector2.new(0.5, 0),
			Flat = true,
			Parent = cell,
		})

		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.Position = UDim2.fromOffset(2, 38)
		label.Size = UDim2.new(1, -4, 0, 18)
		label.BackgroundTransparency = 1
		label.Font = Theme.Font.Caption.Font
		label.TextSize = Theme.Font.Caption.Size
		label.TextTruncate = Enum.TextTruncate.AtEnd
		label.TextColor3 = if line.Kind == "Shard" then RarityConfig.EclipseShard.AccentColor else Theme.Colors.TextSecondary
		label.Text = line.Label
		label.Parent = cell
	end

	StatusChip.new({
		Status = "Locked",
		Text = "SEASON PASS NOT AVAILABLE YET",
		LayoutOrder = 3,
		Parent = cardContent,
	})
end

-- ---------------------------------------------------------------------
-- Carousel
-- ---------------------------------------------------------------------

local function cardOptionsFor(reward: DailyRewardConfig.RewardEntry, name: string)
	return {
		Name = name,
		Rarity = reward.Rarity,
		ItemId = reward.ItemId or "Scrap",
		Title = reward.CardTitle or reward.Label,
		Amount = reward.CardAmount,
	}
end

local function playCarousel(content: GuiObject, winningIndex: number, layoutOrder: number)
	local viewport = Instance.new("Frame")
	viewport.Name = "CarouselViewport"
	viewport.Size = UDim2.new(1, 0, 0, CAROUSEL_HEIGHT)
	viewport.LayoutOrder = layoutOrder
	viewport.BackgroundColor3 = Theme.Colors.PanelBackground
	viewport.BackgroundTransparency = 0.4
	viewport.BorderSizePixel = 0
	viewport.ClipsDescendants = true
	viewport.Parent = content

	local viewportCorner = Instance.new("UICorner")
	viewportCorner.CornerRadius = Theme.Corner.Medium
	viewportCorner.Parent = viewport

	local strip = Instance.new("Frame")
	strip.Name = "Strip"
	strip.Size = UDim2.fromOffset(STRIP_CARD_COUNT * CARD_STRIDE, RarityCard.HEIGHT)
	strip.Position = UDim2.fromOffset(0, 10)
	strip.BackgroundTransparency = 1
	strip.Parent = viewport

	-- Decoy cards are drawn from the same pool the server rolls over, so the
	-- strip looks like the real distribution. They are decoration only — the
	-- landing card is fixed at WINNER_INDEX before any of this animates.
	local rng = Random.new()
	local winnerScale: UIScale? = nil

	for index = 1, STRIP_CARD_COUNT do
		local rewardIndex = if index == WINNER_INDEX then winningIndex else rng:NextInteger(1, #DailyRewardConfig.Rewards)
		local reward = DailyRewardConfig.Rewards[rewardIndex]
		local options = cardOptionsFor(reward, `Card{index}`)
		local _card, scale = RarityCard.new({
			Name = options.Name,
			Rarity = options.Rarity,
			ItemId = options.ItemId,
			Title = options.Title,
			Amount = options.Amount,
			Position = UDim2.fromOffset((index - 1) * CARD_STRIDE, 0),
			Parent = strip,
		})
		-- Every card is the same base size; emphasis is applied with UIScale
		-- only, so nothing reflows as the strip moves.
		scale.Scale = IDLE_CARD_SCALE
		if index == WINNER_INDEX then
			winnerScale = scale
		end
	end

	-- Center marker.
	local pointer = Instance.new("Frame")
	pointer.Name = "CenterMarker"
	pointer.AnchorPoint = Vector2.new(0.5, 0)
	pointer.Position = UDim2.new(0.5, 0, 0, 0)
	pointer.Size = UDim2.new(0, 2, 1, 0)
	pointer.BackgroundColor3 = ACCENT
	pointer.BackgroundTransparency = 0.55
	pointer.BorderSizePixel = 0
	pointer.ZIndex = 5
	pointer.Parent = viewport

	-- Landing maths: to center card k, the strip's left edge must sit at
	-- (viewportWidth/2) - (k*stride + cardWidth/2).
	--
	-- The viewport was created microseconds ago, so its AbsoluteSize is still
	-- zero until Roblox runs a layout pass — reading it directly would center
	-- the winner on x=0 and land the strip visibly off-screen. The panel HAS
	-- been laid out (the modal is already open), so derive the width from it:
	-- the viewport spans the content area, which is the panel inset by its
	-- own horizontal padding plus the content frame's right padding.
	local viewportWidth = viewport.AbsoluteSize.X
	if viewportWidth <= 0 then
		local activeModal = modal
		local panelWidth = if activeModal then activeModal.Panel.AbsoluteSize.X else 0
		viewportWidth = panelWidth - Theme.Spacing.L * 2 - Theme.Spacing.S
	end
	if viewportWidth <= 0 then
		viewportWidth = RarityCard.WIDTH * 3
	end

	local function offsetForCard(index: number): number
		return math.floor(viewportWidth / 2 - ((index - 1) * CARD_STRIDE + RarityCard.WIDTH / 2) + 0.5)
	end

	local startPosition = UDim2.fromOffset(offsetForCard(1), 10)
	local targetPosition = UDim2.fromOffset(offsetForCard(WINNER_INDEX), 10)

	UIAnimator.PlayRewardCarousel({
		Strip = strip,
		StartPosition = startPosition,
		TargetPosition = targetPosition,
		OnPhase = function()
			UIAnimator.PlaySound("RewardSpinTick")
		end,
		OnSettled = function()
			if winnerScale then
				-- The winning card grows into the emphasized center size only
				-- once it has actually landed — during the spin every card is
				-- the same size, so nothing telegraphs the result early.
				UIAnimator.PopWinner(winnerScale, 1)
			end
			task.delay(0.35, function()
				if phase == "Spinning" then
					phase = "Result"
					render()
				end
			end)
		end,
	})
end

-- ---------------------------------------------------------------------
-- Phases
-- ---------------------------------------------------------------------

local function renderResetCountdown(content: GuiObject, layoutOrder: number)
	local label = Instance.new("TextLabel")
	label.Name = "ResetCountdown"
	label.Size = UDim2.new(1, 0, 0, 20)
	label.LayoutOrder = layoutOrder
	label.BackgroundTransparency = 1
	label.Font = Theme.Font.Caption.Font
	label.TextSize = Theme.Font.Caption.Size
	label.TextColor3 = Theme.Colors.TextMuted
	label.Text = `Next reset in {FacilityStyle.FormatClock(secondsUntilReset)}`
	label.Parent = content

	stopCountdown()
	unbindCountdown = UIAnimator.BindTicker(function()
		if not label.Parent then
			stopCountdown()
			return
		end
		secondsUntilReset = math.max(0, secondsUntilReset - 1)
		label.Text = `Next reset in {FacilityStyle.FormatClock(secondsUntilReset)}`
	end)
end

local function renderIdle(content: GuiObject, nextOrder: () -> number)
	local hero = Instance.new("Frame")
	hero.Name = "Hero"
	hero.Size = UDim2.new(1, 0, 0, 112)
	hero.LayoutOrder = nextOrder()
	hero.BackgroundTransparency = 1
	hero.Parent = content

	ItemIcon.new({
		Name = "DailyDropIcon",
		ItemId = "Gift",
		Glyph = "Gift",
		Size = UDim2.fromOffset(50, 50),
		Position = UDim2.new(0.5, 0, 0, 0),
		AnchorPoint = Vector2.new(0.5, 0),
		AccentOverride = ACCENT,
		Parent = hero,
	})

	local headline = Instance.new("TextLabel")
	headline.Size = UDim2.new(1, 0, 0, 30)
	headline.Position = UDim2.fromOffset(0, 54)
	headline.BackgroundTransparency = 1
	headline.Font = Theme.Font.Title.Font
	headline.TextSize = Theme.Font.Title.Size
	headline.TextColor3 = Theme.Colors.TextPrimary
	headline.Text = "DAILY REWARD READY"
	headline.Parent = hero

	local subline = Instance.new("TextLabel")
	subline.Size = UDim2.new(1, 0, 0, 20)
	subline.Position = UDim2.fromOffset(0, 84)
	subline.BackgroundTransparency = 1
	subline.Font = Theme.Font.Body.Font
	subline.TextSize = Theme.Font.Body.Size
	subline.TextColor3 = ACCENT
	subline.Text = "1 free spin available"
	subline.Parent = hero

	ActionBar.new({
		PrimaryText = "Spin",
		PrimaryAccent = ACCENT,
		LayoutOrder = nextOrder(),
		OnPrimary = function()
			if requestInFlight or phase ~= "Idle" then
				return
			end
			requestInFlight = true

			-- The server picks, records and grants inside this single call.
			-- Only once it returns does the reveal begin.
			local ok, result = pcall(function()
				return Net.GetFunction("RequestDailyRewardRoll"):InvokeServer()
			end)
			requestInFlight = false

			if ok and typeof(result) == "table" and not result.Rejected and result.RewardIndex then
				resultIndex = result.RewardIndex
				currentStreak = result.Streak or currentStreak
				spinAvailable = false
				phase = "Spinning"
				render()
			else
				-- Rejected means the day was already claimed (possibly on
				-- another server). Re-read the real status rather than
				-- guessing at what happened.
				refreshStatus()
				render()
				NotificationController.Toast("BuildRejected", "Today's supply drop has already been claimed")
			end
		end,
		Parent = content,
	})

	SectionHeader.new({ Text = "Streak", Accent = ACCENT, LayoutOrder = nextOrder(), Parent = content })
	buildStreakStrip(content, nextOrder())
	renderResetCountdown(content, nextOrder())
	buildSeasonBonus(content, nextOrder())
	nextOrder()
end

local function renderSpinning(content: GuiObject, nextOrder: () -> number)
	local index = resultIndex
	if not index then
		return
	end

	local headline = Instance.new("TextLabel")
	headline.Name = "Headline"
	headline.Size = UDim2.new(1, 0, 0, 28)
	headline.LayoutOrder = nextOrder()
	headline.BackgroundTransparency = 1
	headline.Font = Theme.Font.Title.Font
	headline.TextSize = Theme.Font.Title.Size
	headline.TextColor3 = Theme.Colors.TextPrimary
	headline.Text = "OPENING SUPPLY DROP"
	headline.Parent = content

	playCarousel(content, index, nextOrder())
end

local function renderResult(content: GuiObject, nextOrder: () -> number)
	local index = resultIndex
	local reward = if index then DailyRewardConfig.Rewards[index] else nil
	if not reward then
		phase = "Claimed"
		return
	end

	local rarity = RarityConfig.Get(reward.Rarity)

	local headline = Instance.new("TextLabel")
	headline.Name = "YouGot"
	headline.Size = UDim2.new(1, 0, 0, 26)
	headline.LayoutOrder = nextOrder()
	headline.BackgroundTransparency = 1
	headline.Font = Theme.Font.Label.Font
	headline.TextSize = Theme.Font.Label.Size
	headline.TextColor3 = Theme.Colors.TextMuted
	headline.Text = "YOU GOT"
	headline.Parent = content

	local holder = Instance.new("Frame")
	holder.Name = "ResultCardHolder"
	holder.Size = UDim2.new(1, 0, 0, RarityCard.HEIGHT + 16)
	holder.LayoutOrder = nextOrder()
	holder.BackgroundTransparency = 1
	holder.Parent = content

	local _resultCard, resultScale = RarityCard.new({
		Name = "ResultCard",
		Rarity = reward.Rarity,
		ItemId = reward.ItemId or "Scrap",
		Title = reward.CardTitle or reward.Label,
		Amount = reward.CardAmount,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Parent = holder,
	})
	UIAnimator.PopWinner(resultScale)

	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Name = "Rarity"
	rarityLabel.Size = UDim2.new(1, 0, 0, 22)
	rarityLabel.LayoutOrder = nextOrder()
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Font = Theme.Font.Stat.Font
	rarityLabel.TextSize = Theme.Font.Heading.Size
	rarityLabel.TextColor3 = rarity.Color
	rarityLabel.Text = rarity.Label
	rarityLabel.Parent = content

	-- The server already granted this inside Claim(), so the honest wording
	-- is a completed statement, not a pending action. There is no second
	-- "claim" step to fake.
	local claimed = Instance.new("TextLabel")
	claimed.Name = "Claimed"
	claimed.Size = UDim2.new(1, 0, 0, 20)
	claimed.LayoutOrder = nextOrder()
	claimed.BackgroundTransparency = 1
	claimed.Font = Theme.Font.Body.Font
	claimed.TextSize = Theme.Font.Body.Size
	claimed.TextColor3 = Theme.Colors.Success
	claimed.Text = "REWARD CLAIMED ✓"
	claimed.Parent = content

	ActionBar.new({
		PrimaryText = "Continue",
		PrimaryAccent = ACCENT,
		LayoutOrder = nextOrder(),
		OnPrimary = function()
			phase = "Claimed"
			render()
		end,
		Parent = content,
	})
end

local function renderClaimed(content: GuiObject, nextOrder: () -> number)
	local hero = Instance.new("Frame")
	hero.Name = "Hero"
	hero.Size = UDim2.new(1, 0, 0, 94)
	hero.LayoutOrder = nextOrder()
	hero.BackgroundTransparency = 1
	hero.Parent = content

	ItemIcon.new({
		Name = "CollectedIcon",
		ItemId = "Gift",
		Glyph = "Gift",
		Size = UDim2.fromOffset(44, 44),
		Position = UDim2.new(0.5, 0, 0, 0),
		AnchorPoint = Vector2.new(0.5, 0),
		AccentOverride = ACCENT,
		Parent = hero,
	})

	local headline = Instance.new("TextLabel")
	headline.Size = UDim2.new(1, 0, 0, 28)
	headline.Position = UDim2.fromOffset(0, 46)
	headline.BackgroundTransparency = 1
	headline.Font = Theme.Font.Title.Font
	headline.TextSize = Theme.Font.Title.Size
	headline.TextColor3 = Theme.Colors.TextPrimary
	headline.Text = "COLLECTED TODAY"
	headline.Parent = hero

	local subline = Instance.new("TextLabel")
	subline.Size = UDim2.new(1, 0, 0, 20)
	subline.Position = UDim2.fromOffset(0, 72)
	subline.BackgroundTransparency = 1
	subline.Font = Theme.Font.Body.Font
	subline.TextSize = Theme.Font.Body.Size
	subline.TextColor3 = Theme.Colors.TextSecondary
	subline.Text = if currentStreak > 0 then `{currentStreak} day streak — come back tomorrow to keep it` else "Come back tomorrow for the next drop"
	subline.Parent = hero

	SectionHeader.new({ Text = "Streak", Accent = ACCENT, LayoutOrder = nextOrder(), Parent = content })
	buildStreakStrip(content, nextOrder())
	renderResetCountdown(content, nextOrder())
	buildSeasonBonus(content, nextOrder())
	nextOrder()
end

local function renderUnknown(content: GuiObject, nextOrder: () -> number)
	local _card, cardContent = FacilityCard.new({
		Name = "Unavailable",
		LayoutOrder = nextOrder(),
		Parent = content,
	})
	StatusChip.new({ Status = "Offline", Text = "UNAVAILABLE", LayoutOrder = 1, Parent = cardContent })
	FacilityCard.Text({
		Text = "Could not reach the supply drop right now. Try again in a moment.",
		Color = Theme.Colors.TextMuted,
		LayoutOrder = 2,
		Parent = cardContent,
	})

	Button.new({
		Text = "Retry",
		Variant = "Primary",
		AccentColor = ACCENT,
		Size = UDim2.new(1, 0, 0, 42),
		LayoutOrder = nextOrder(),
		OnActivated = function()
			refreshStatus()
			render()
		end,
		Parent = content,
	})
end

render = function()
	local activeModal = modal
	if not activeModal then
		return
	end
	stopCountdown()
	activeModal:ClearContent()

	local content = activeModal.Content
	local layoutOrder = 0
	local function nextOrder(): number
		layoutOrder += 1
		return layoutOrder
	end

	if phase == "Idle" then
		renderIdle(content, nextOrder)
	elseif phase == "Spinning" then
		renderSpinning(content, nextOrder)
	elseif phase == "Result" then
		renderResult(content, nextOrder)
	elseif phase == "Claimed" then
		renderClaimed(content, nextOrder)
	else
		renderUnknown(content, nextOrder)
	end

	-- The spin phase owns its own motion; staggering it too would fight the
	-- carousel's opening position.
	if phase ~= "Spinning" then
		activeModal:RevealContent()
	end
end

-- ---------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------

function DailyRewardsController.Open()
	local activeModal = modal
	if not activeModal then
		return
	end
	-- Never auto-roll on open. This is a read-only status query.
	refreshStatus()
	resultIndex = nil
	activeModal:Open()
	render()
end

function DailyRewardsController.Close()
	if modal then
		modal:Close()
	end
end

function DailyRewardsController:Init()
	self._trove = Trove.new()

	modal = FacilityModal.new({
		Id = "DailyRewards",
		Icon = IDENTITY.Icon,
		Title = IDENTITY.Title,
		Subtitle = IDENTITY.Subtitle,
		Accent = ACCENT,
		WidthClass = "Regular",
		OnClose = function()
			stopCountdown()
			-- Closing mid-spin must not strand the screen in "Spinning": the
			-- reward is already granted server-side, so the next open should
			-- show the settled, claimed state.
			if phase == "Spinning" or phase == "Result" then
				phase = "Claimed"
			end
		end,
	})

	FacilityRouter.Register("DailyRewards", function()
		DailyRewardsController.Open()
	end)
end

function DailyRewardsController:Start() end

return DailyRewardsController
