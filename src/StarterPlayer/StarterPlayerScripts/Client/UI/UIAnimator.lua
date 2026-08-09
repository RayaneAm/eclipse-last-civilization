--!strict
-- The one place facility-modal motion is implemented. Every facility screen
-- calls into this instead of hand-rolling its own tween chain, so "open",
-- "close", "press" and "reveal" feel identical everywhere.
--
-- Built on Motion.luau (the cancel-safe TweenService wrapper) rather than
-- calling TweenService directly: modal open/close and button presses can be
-- re-triggered mid-flight (double-click, rapid E-press, opening one facility
-- while another is still closing), and uncancelled stacked tweens on the same
-- property visibly fight each other.
--
-- PERFORMANCE CONTRACT (facility UI brief §53):
--   * TweenService only. There is no RenderStepped/Heartbeat loop in this
--     module and facility screens must not add one.
--   * Repeating timers are driven by a SINGLE shared 1 Hz clock (see
--     BindTicker) that only runs while at least one visible screen is
--     subscribed, and stops itself when the last subscriber unbinds — not
--     one loop per card, per bar or per countdown.
--   * The carousel is a fixed set of chained tweens, not a per-frame
--     simulation.

local RunService = game:GetService("RunService")

local Theme = require(script.Parent.Theme)
local Motion = require(script.Parent.Motion)

local UIAnimator = {}

-- ---------------------------------------------------------------------
-- Timing vocabulary (facility UI brief §6-§9)
-- ---------------------------------------------------------------------

local OPEN_POP = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local OPEN_SETTLE = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local CLOSE = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
-- The modal also travels a few px vertically on open/close. Scale alone
-- reads as a zoom; adding a small rise makes it read as the window coming
-- toward the player, which is the game-UI feel the brief asks for (§14).
local OPEN_RISE = 14
local PRESS_DOWN = TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PRESS_OVERSHOOT = TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PRESS_SETTLE = TweenInfo.new(0.04, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local HOVER = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local STAGGER_STEP = 0.03
local STAGGER_TWEEN = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local MAX_STAGGERED = 10 -- past this the reveal stops feeling fast; the rest just appear

UIAnimator.OpenDuration = OPEN_POP.Time + OPEN_SETTLE.Time
UIAnimator.CloseDuration = CLOSE.Time

-- ---------------------------------------------------------------------
-- Sound hooks
-- ---------------------------------------------------------------------
-- Clean, no-op-by-default hooks so a future audio pass has exactly one place
-- to plug into. Nothing here ships or requires any audio asset — assigning
-- UIAnimator.SoundHandler is the ONLY thing needed later.

export type SoundCue =
	"UIOpen"
	| "UIClose"
	| "Hover"
	| "Click"
	| "Build"
	| "Upgrade"
	| "RewardSpinTick"
	| "RewardWin"
	| "ProductionReady"

UIAnimator.SoundHandler = nil :: ((cue: SoundCue) -> ())?

function UIAnimator.PlaySound(cue: SoundCue)
	local handler = UIAnimator.SoundHandler
	if handler then
		task.spawn(handler, cue)
	end
end

-- ---------------------------------------------------------------------
-- Modal open / close
-- ---------------------------------------------------------------------

-- ONE UIScale per GuiObject, shared by every effect in this module.
--
-- This is not a tidiness preference, it is a correctness requirement: Roblox
-- applies only a single UIScale to a GuiObject, so an element carrying both
-- (say) a "PressScale" and a "HoverLift" would have one of them silently do
-- nothing — and which one is not something to rely on. An interactive card
-- here is legitimately touched by three effects (the open stagger, hover, and
-- press), so they must all drive the same instance.
--
-- They also share ONE Motion channel ("Scale"), so a later effect cleanly
-- cancels an earlier one instead of two tweens fighting over the same
-- property. Press therefore interrupts hover, and hover interrupts the
-- stagger, which is the intended precedence.
local SCALE_NAME = "EclipseScale"
local SCALE_CHANNEL = "Scale"

-- What each element should rest at while hovered/focused, so a press can
-- settle back to the hovered size rather than snapping to 1.0 under the
-- cursor. Weak-keyed: an entry disappears with its button.
local hoverRest: { [GuiObject]: number } = setmetatable({}, { __mode = "k" }) :: any

-- Matches by CLASS, not by name, so it also adopts a UIScale some component
-- created for its own reasons (RarityCard's carousel emphasis scale,
-- Interaction.luau's hover scale, a card's selected-state scale). Those all
-- animate the same property through the same Motion channel, so sharing the
-- one instance is exactly right — and creating a second would break both.
local function getScale(instance: GuiObject): UIScale
	local existing = instance:FindFirstChildOfClass("UIScale")
	if existing then
		return existing
	end
	local scale = Instance.new("UIScale")
	scale.Name = SCALE_NAME
	scale.Parent = instance
	return scale
end

local function restScale(instance: GuiObject): number
	return hoverRest[instance] or 1
end

-- POP -> SETTLE. Starts at 0.94 and slightly transparent, overshoots to
-- 1.02, lands on 1.00 fully opaque. Deliberately one overshoot, never a
-- repeating bounce.
function UIAnimator.OpenModal(root: CanvasGroup, panel: GuiObject)
	local scale = getScale(panel)
	scale.Scale = 0.93
	root.GroupTransparency = 1
	root.Visible = true

	-- Remembered on first open so repeated opens always settle back to the
	-- panel's real anchored position rather than drifting by the rise offset.
	local restPosition = panel:GetAttribute("RestPosition") :: UDim2?
	if not restPosition then
		restPosition = panel.Position
		panel:SetAttribute("RestPosition", restPosition)
	end
	local resting = restPosition :: UDim2
	panel.Position = resting + UDim2.fromOffset(0, OPEN_RISE)
	Motion.Tween(panel, "ModalRise", OPEN_POP, { Position = resting })

	Motion.Tween(root, "ModalFade", OPEN_POP, { GroupTransparency = 0 })
	local pop = Motion.Tween(scale, SCALE_CHANNEL, OPEN_POP, { Scale = 1.02 })
	pop.Completed:Once(function(state: Enum.PlaybackState)
		-- Only settle if the pop actually finished — a Cancel means a close
		-- (or a re-open) took over and owns the scale channel now.
		if state == Enum.PlaybackState.Completed then
			Motion.Tween(scale, SCALE_CHANNEL, OPEN_SETTLE, { Scale = 1 })
		end
	end)

	UIAnimator.PlaySound("UIOpen")
end

-- 1.00 -> 0.95 with a small fade, then hides cleanly. `onHidden` runs after
-- the fade so the caller can flip Visible off without a flash.
function UIAnimator.CloseModal(root: CanvasGroup, panel: GuiObject, onHidden: (() -> ())?)
	local scale = getScale(panel)

	Motion.Tween(scale, SCALE_CHANNEL, CLOSE, { Scale = 0.95 })
	local fade = Motion.Tween(root, "ModalFade", CLOSE, { GroupTransparency = 1 })
	fade.Completed:Once(function(state: Enum.PlaybackState)
		if state == Enum.PlaybackState.Completed and onHidden then
			onHidden()
		end
	end)

	UIAnimator.PlaySound("UIClose")
end

-- ---------------------------------------------------------------------
-- Button feedback
-- ---------------------------------------------------------------------

-- 1.00 -> 0.94 -> 1.02 -> 1.00 in ~0.14s total. Returns a cleanup function
-- so callers holding a Trove can disconnect on teardown.
function UIAnimator.BindButton(button: GuiButton, onActivated: (() -> ())?): () -> ()
	local scale = getScale(button)
	local connections: { RBXScriptConnection } = {}

	local function press()
		local down = Motion.Tween(scale, SCALE_CHANNEL, PRESS_DOWN, { Scale = 0.94 })
		down.Completed:Once(function(downState: Enum.PlaybackState)
			if downState ~= Enum.PlaybackState.Completed then
				return
			end
			local up = Motion.Tween(scale, SCALE_CHANNEL, PRESS_OVERSHOOT, { Scale = 1.02 })
			up.Completed:Once(function(upState: Enum.PlaybackState)
				if upState == Enum.PlaybackState.Completed then
					-- Settle to the hovered size, not a flat 1.0, so a click
					-- under the cursor does not visibly drop the element.
					Motion.Tween(scale, SCALE_CHANNEL, PRESS_SETTLE, { Scale = restScale(button) })
				end
			end)
		end)
	end

	-- `Activated` is Roblox's one event that already unifies mouse click,
	-- touch tap and gamepad A — no separate per-input activation path.
	table.insert(
		connections,
		button.Activated:Connect(function()
			if not button.Active then
				return
			end
			UIAnimator.PlaySound("Click")
			press()
			if onActivated then
				onActivated()
			end
		end)
	)

	return function()
		for _, connection in connections do
			connection:Disconnect()
		end
	end
end

-- Subtle 1.015 lift + brightness. Kept separate from BindButton so a card
-- can be hover-reactive without being a button, and a button can get press
-- feedback without a hover state on touch.
function UIAnimator.BindHover(target: GuiObject, options: { Scale: number?, Stroke: UIStroke?, HoverStrokeTransparency: number?, IdleStrokeTransparency: number? }?): () -> ()
	local opts = options or {}
	local hoverScale = opts.Scale or 1.015
	local scale = getScale(target)
	local stroke = opts.Stroke
	local idleStroke = opts.IdleStrokeTransparency or (if stroke then stroke.Transparency else 0.4)
	local hoverStroke = opts.HoverStrokeTransparency or 0.05

	local connections: { RBXScriptConnection } = {}

	local function enter()
		-- Recorded so a press on this element settles back to the hovered
		-- size instead of dropping to 1.0 while the cursor is still on it.
		hoverRest[target] = hoverScale
		Motion.Tween(scale, SCALE_CHANNEL, HOVER, { Scale = hoverScale })
		if stroke then
			Motion.Tween(stroke, "HoverStroke", HOVER, { Transparency = hoverStroke })
		end
		UIAnimator.PlaySound("Hover")
	end
	local function leave()
		hoverRest[target] = nil
		Motion.Tween(scale, SCALE_CHANNEL, HOVER, { Scale = 1 })
		if stroke then
			Motion.Tween(stroke, "HoverStroke", HOVER, { Transparency = idleStroke })
		end
	end

	table.insert(connections, target.MouseEnter:Connect(enter))
	table.insert(connections, target.MouseLeave:Connect(leave))
	if target:IsA("GuiButton") then
		table.insert(connections, target.SelectionGained:Connect(enter))
		table.insert(connections, target.SelectionLost:Connect(leave))
	end

	return function()
		hoverRest[target] = nil
		for _, connection in connections do
			connection:Disconnect()
		end
	end
end

-- ---------------------------------------------------------------------
-- Content stagger
-- ---------------------------------------------------------------------

-- Cards settle in 0.03s apart, so a screen reveals top-to-bottom instead of
-- appearing all at once.
--
-- The reveal is driven by UIScale, NOT by Position. Facility content sits
-- inside a UIListLayout, and a UIListLayout owns its children's Position
-- outright — assigning Position there is silently discarded, so a
-- slide-up stagger simply would not animate. UIScale is not layout-managed,
-- so it is the one transform that actually moves under a list layout.
--
-- CanvasGroup children additionally get a real group fade. Ordinary Frames
-- do not: fading an arbitrary subtree would mean walking every descendant,
-- recording its transparency and restoring it afterwards, which is both
-- expensive and prone to fighting whatever else is tweening those children.
function UIAnimator.StaggerChildren(container: GuiObject, startIndex: number?)
	local index = startIndex or 0
	for _, child in container:GetChildren() do
		if not child:IsA("GuiObject") or not child.Visible then
			continue
		end
		index += 1
		if index > MAX_STAGGERED then
			break
		end

		local scale = getScale(child)
		scale.Scale = 0.96

		local canvasGroup = if child:IsA("CanvasGroup") then child :: CanvasGroup else nil
		if canvasGroup then
			canvasGroup.GroupTransparency = 1
		end

		task.delay((index - 1) * STAGGER_STEP, function()
			-- The row may have been destroyed by a re-render during the
			-- stagger window; tweening a destroyed instance would throw.
			if not child.Parent then
				return
			end
			Motion.Tween(scale, SCALE_CHANNEL, STAGGER_TWEEN, { Scale = 1 })
			if canvasGroup then
				Motion.Tween(canvasGroup, "StaggerFade", STAGGER_TWEEN, { GroupTransparency = 0 })
			end
		end)
	end
end

-- ---------------------------------------------------------------------
-- Shared 1 Hz ticker
-- ---------------------------------------------------------------------
-- Countdown labels (production remaining, daily reset) need a per-second
-- update. One shared Heartbeat-driven clock serves all of them and is only
-- connected while something is actually subscribed — the alternative (a
-- task.spawn loop per label) leaks work for every closed screen.

local tickerSubscribers: { [any]: () -> () } = {}
local tickerConnection: RBXScriptConnection? = nil
local tickerAccumulator = 0

local function ensureTicker()
	if tickerConnection then
		return
	end
	tickerAccumulator = 0
	tickerConnection = RunService.Heartbeat:Connect(function(deltaTime: number)
		tickerAccumulator += deltaTime
		if tickerAccumulator < 1 then
			return
		end
		tickerAccumulator -= 1
		for _, callback in tickerSubscribers do
			local ok, err = pcall(callback)
			if not ok then
				warn(`UIAnimator: ticker subscriber errored: {err}`)
			end
		end
	end)
end

local function maybeStopTicker()
	if next(tickerSubscribers) ~= nil then
		return
	end
	if tickerConnection then
		tickerConnection:Disconnect()
		tickerConnection = nil
	end
end

-- Returns an unbind function. Callers MUST unbind when their screen closes;
-- every facility modal does this from its own close path.
function UIAnimator.BindTicker(callback: () -> ()): () -> ()
	local key = {}
	tickerSubscribers[key] = callback
	ensureTicker()
	return function()
		tickerSubscribers[key] = nil
		maybeStopTicker()
	end
end

-- ---------------------------------------------------------------------
-- Reward carousel
-- ---------------------------------------------------------------------

export type CarouselOptions = {
	Strip: GuiObject, -- the sliding frame holding the cards
	TargetPosition: UDim2, -- where the strip must end so the winner is centered
	StartPosition: UDim2,
	-- Fired at each deceleration boundary (4 times across the spin), which is
	-- where a spin sound would naturally change pitch or cadence. Deliberately
	-- NOT a per-card or per-second callback: a timer fine-grained enough to
	-- click on every passing card would be a per-frame loop, which this
	-- module's performance contract rules out.
	OnPhase: ((phaseIndex: number) -> ())?,
	OnSettled: (() -> ())?,
}

-- Four chained phases (fast -> medium -> slow -> settle) totalling ~3.6s,
-- matching the brief's pacing. The winner is ALWAYS whatever card the caller
-- already placed at TargetPosition — this function never picks anything, it
-- only moves a strip to a position the caller computed from the server's
-- already-decided result.
function UIAnimator.PlayRewardCarousel(options: CarouselOptions)
	local strip = options.Strip
	strip.Position = options.StartPosition

	local startOffset = options.StartPosition.X.Offset
	local endOffset = options.TargetPosition.X.Offset
	local travel = endOffset - startOffset

	-- Phase boundaries as a fraction of total travel. Front-loaded so it
	-- reads as "fast, then braking", not a linear slide.
	local phases = {
		{ Fraction = 0.55, Info = TweenInfo.new(1.0, Enum.EasingStyle.Linear) },
		{ Fraction = 0.85, Info = TweenInfo.new(1.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) },
		{ Fraction = 0.97, Info = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) },
		{ Fraction = 1.0, Info = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) },
	}

	local function runPhase(phaseIndex: number)
		local phase = phases[phaseIndex]
		if not phase then
			if options.OnSettled then
				options.OnSettled()
			end
			return
		end

		if options.OnPhase then
			options.OnPhase(phaseIndex)
		end

		local offset = startOffset + travel * phase.Fraction
		local goal = UDim2.new(options.TargetPosition.X.Scale, math.floor(offset + 0.5), options.TargetPosition.Y.Scale, options.TargetPosition.Y.Offset)
		local tween = Motion.Tween(strip, "Carousel", phase.Info, { Position = goal })
		tween.Completed:Once(function(state: Enum.PlaybackState)
			-- A Cancel means the screen closed (or re-rendered) mid-spin, so
			-- the chain simply stops — OnSettled must not fire for a spin the
			-- player is no longer watching.
			if state == Enum.PlaybackState.Completed then
				runPhase(phaseIndex + 1)
			end
		end)
	end

	runPhase(1)
end

-- A small celebratory pop for the winning card once the strip settles, ending
-- at `restingScale` (the emphasized centered size, 1.0 by default).
--
-- Takes the card's OWN UIScale rather than creating one: RarityCard already
-- ships each card with a scale it uses for carousel emphasis, and a second
-- UIScale on the same frame would leave one of the two doing nothing.
function UIAnimator.PopWinner(scale: UIScale, restingScale: number?)
	local target = restingScale or 1
	local up = Motion.Tween(scale, SCALE_CHANNEL, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = target * 1.12 })
	up.Completed:Once(function(state: Enum.PlaybackState)
		if state == Enum.PlaybackState.Completed then
			Motion.Tween(scale, SCALE_CHANNEL, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = target })
		end
	end)
	UIAnimator.PlaySound("RewardWin")
end

-- Re-exported so facility code can use the shared timings without also
-- requiring Theme just for a tween info.
UIAnimator.Timing = {
	Hover = HOVER,
	Close = CLOSE,
	Stagger = STAGGER_TWEEN,
	Fade = Theme.Motion.Fade,
}

return UIAnimator
