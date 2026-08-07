--!strict
-- Modern paged dialogue window: bottom-anchored glass panel, placeholder
-- portrait glyph, per-page typewriter text reveal, page counter, and
-- Skip/Continue buttons. No backdrop-catcher (deliberate — accidentally
-- dismissing mid-conversation would itself be a confusing dead end); the
-- only ways to close are Skip or Continue-past-the-last-page, both of which
-- always fire onComplete — there is no silent "cancel without completing"
-- path, so a player can never close this window and leave the underlying
-- server interaction (e.g. InteractQuestGiver) un-invoked.

local GuiService = game:GetService("GuiService")

local Theme = require(script.Parent.Parent.Theme)
local Motion = require(script.Parent.Parent.Motion)
local GamepadNav = require(script.Parent.Parent.GamepadNav)
local GlassPanel = require(script.Parent.GlassPanel)
local Button = require(script.Parent.Button)

local DialogueWindow = {}

export type DialogueLine = { Speaker: string, Text: string }
export type DialogueWindowOptions = { Parent: Instance, AccentColor: Color3? }
export type DialogueWindowApi = {
	Show: (pages: { DialogueLine }, onComplete: (() -> ())?) -> (),
	-- Immediately dismisses and fires onComplete, exactly like pressing the
	-- Skip button — the one exposed close path, so callers (e.g. an
	-- Escape/ButtonB keybind) can never leave onComplete un-invoked.
	Skip: () -> (),
	IsOpen: () -> boolean,
}

local CHARACTERS_PER_SECOND = 28
local PORTRAIT_SIZE = 72
local CONTENT_OFFSET = PORTRAIT_SIZE + Theme.Spacing.L -- 88

function DialogueWindow.new(options: DialogueWindowOptions): (CanvasGroup, DialogueWindowApi)
	local accentColor = options.AccentColor or Theme.Colors.Brand

	local wrapper = Instance.new("CanvasGroup")
	wrapper.Name = "DialogueWindow"
	-- 4px taller than the panel below so the panel's drop shadow has slack to
	-- render in — a CanvasGroup clips to its own bounds like
	-- ClipsDescendants=true (see Toast.luau's identical comment).
	wrapper.Size = UDim2.new(0.7, 0, 0, 164)
	wrapper.AnchorPoint = Vector2.new(0.5, 1)
	wrapper.Position = UDim2.new(0.5, 0, 1, -Theme.Spacing.XL)
	wrapper.BackgroundTransparency = 1
	wrapper.GroupTransparency = 1
	wrapper.Visible = false
	wrapper.Parent = options.Parent

	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = Vector2.new(420, 154)
	sizeConstraint.MaxSize = Vector2.new(720, 194)
	sizeConstraint.Parent = wrapper

	local scale = Instance.new("UIScale")
	scale.Name = "Scale"
	scale.Scale = 0.94
	scale.Parent = wrapper

	local panel = GlassPanel.new({
		Name = "Panel",
		Size = UDim2.new(1, 0, 1, -4),
		AccentColor = accentColor,
		Parent = wrapper,
	})

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, Theme.Spacing.L)
	padding.PaddingRight = UDim.new(0, Theme.Spacing.L)
	padding.PaddingTop = UDim.new(0, Theme.Spacing.L)
	padding.PaddingBottom = UDim.new(0, Theme.Spacing.M)
	padding.Parent = panel

	local portrait = Instance.new("Frame")
	portrait.Name = "Portrait"
	portrait.Size = UDim2.fromOffset(PORTRAIT_SIZE, PORTRAIT_SIZE)
	portrait.BackgroundColor3 = Theme.Colors.PanelBackground
	portrait.BackgroundTransparency = Theme.Transparency.PanelBackground
	portrait.BorderSizePixel = 0
	portrait.Parent = panel

	local portraitCorner = Instance.new("UICorner")
	portraitCorner.CornerRadius = Theme.Corner.Pill
	portraitCorner.Parent = portrait

	local portraitStroke = Instance.new("UIStroke")
	portraitStroke.Color = accentColor
	portraitStroke.Thickness = 1.5
	portraitStroke.Transparency = Theme.Transparency.StrokeDefault
	portraitStroke.Parent = portrait

	local portraitGlyph = Instance.new("TextLabel")
	portraitGlyph.Size = UDim2.fromScale(1, 1)
	portraitGlyph.BackgroundTransparency = 1
	portraitGlyph.Font = Enum.Font.GothamBold
	portraitGlyph.TextSize = 30
	portraitGlyph.TextColor3 = Theme.Colors.TextPrimary
	portraitGlyph.TextStrokeColor3 = Color3.new(0, 0, 0)
	portraitGlyph.TextStrokeTransparency = 0.6
	portraitGlyph.Text = "🧭" -- placeholder portrait — no character art asset pipeline exists in this project
	portraitGlyph.Parent = portrait

	local speakerLabel = Instance.new("TextLabel")
	speakerLabel.Name = "Speaker"
	speakerLabel.Size = UDim2.new(1, -CONTENT_OFFSET, 0, 20)
	speakerLabel.Position = UDim2.new(0, CONTENT_OFFSET, 0, 0)
	speakerLabel.BackgroundTransparency = 1
	speakerLabel.Font = Theme.Font.Heading.Font
	speakerLabel.TextSize = Theme.Font.Heading.Size
	speakerLabel.TextXAlignment = Enum.TextXAlignment.Left
	speakerLabel.TextColor3 = accentColor
	speakerLabel.Text = ""
	speakerLabel.Parent = panel

	local bodyLabel = Instance.new("TextLabel")
	bodyLabel.Name = "Body"
	bodyLabel.Size = UDim2.new(1, -CONTENT_OFFSET, 0, 64)
	bodyLabel.Position = UDim2.new(0, CONTENT_OFFSET, 0, 24)
	bodyLabel.BackgroundTransparency = 1
	bodyLabel.Font = Theme.Font.Body.Font
	bodyLabel.TextSize = Theme.Font.Body.Size
	bodyLabel.TextXAlignment = Enum.TextXAlignment.Left
	bodyLabel.TextYAlignment = Enum.TextYAlignment.Top
	bodyLabel.TextWrapped = true
	bodyLabel.TextColor3 = Theme.Colors.TextSecondary
	bodyLabel.Text = ""
	bodyLabel.Parent = panel

	local pageCounter = Instance.new("TextLabel")
	pageCounter.Name = "PageCounter"
	pageCounter.AnchorPoint = Vector2.new(0, 1)
	pageCounter.Position = UDim2.new(0, CONTENT_OFFSET, 1, 0)
	pageCounter.Size = UDim2.fromOffset(60, 18)
	pageCounter.BackgroundTransparency = 1
	pageCounter.Font = Theme.Font.Caption.Font
	pageCounter.TextSize = Theme.Font.Caption.Size
	pageCounter.TextXAlignment = Enum.TextXAlignment.Left
	pageCounter.TextColor3 = Theme.Colors.TextMuted
	pageCounter.Text = ""
	pageCounter.Parent = panel

	local continueButton = Button.new({
		Text = "Continue",
		Variant = "Primary",
		AccentColor = accentColor,
		Size = UDim2.fromOffset(120, 36),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 1, 0),
		Parent = panel,
	})

	local skipButton = Button.new({
		Text = "Skip",
		Variant = "Ghost",
		AccentColor = accentColor,
		Size = UDim2.fromOffset(70, 36),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -128, 1, 0),
		Parent = panel,
	})

	GamepadNav.LinkChain({ skipButton, continueButton })

	-- Per-instance state (not module-level — this constructor could in
	-- principle be called more than once, even though DialogueController
	-- only ever builds one).
	local isOpen = false
	local currentPages: { DialogueLine } = {}
	local currentPageIndex = 1
	local currentOnComplete: (() -> ())? = nil
	local revealComplete = false
	local revealToken: {}? = nil
	local previousSelection: GuiObject? = nil

	local function revealBody(fullText: string)
		local length = utf8.len(fullText) or 0
		revealComplete = false
		bodyLabel.Text = ""

		if length <= 0 then
			bodyLabel.Text = fullText
			revealComplete = true
			return
		end

		local token = {}
		revealToken = token
		task.spawn(function()
			local start = os.clock()
			while revealToken == token do
				local shownChars = math.floor((os.clock() - start) * CHARACTERS_PER_SECOND)
				if shownChars >= length then
					bodyLabel.Text = fullText
					revealComplete = true
					return
				end
				local byteEnd = utf8.offset(fullText, shownChars + 1)
				bodyLabel.Text = if byteEnd then string.sub(fullText, 1, byteEnd - 1) else fullText
				task.wait()
			end
		end)
	end

	local function showPage(index: number)
		currentPageIndex = index
		local page = currentPages[index]
		speakerLabel.Text = page.Speaker
		pageCounter.Text = `{index}/{#currentPages}`
		revealBody(page.Text)
	end

	local function close()
		isOpen = false
		revealToken = nil
		Motion.FadeOut(wrapper, Theme.Motion.PanelClose.Time, function()
			if not isOpen then
				wrapper.Visible = false
			end
		end)
		Motion.Tween(scale, "Open", Theme.Motion.PanelClose, { Scale = 0.94 })
		GamepadNav.Restore(previousSelection)
	end

	local function skip()
		local onComplete = currentOnComplete
		currentOnComplete = nil
		close()
		if onComplete then
			onComplete()
		end
	end

	local function continueOrAdvance()
		if not revealComplete then
			revealToken = nil
			bodyLabel.Text = currentPages[currentPageIndex].Text
			revealComplete = true
			return
		end

		if currentPageIndex >= #currentPages then
			skip() -- last page's Continue behaves exactly like Skip: close + fire onComplete
		else
			showPage(currentPageIndex + 1)
		end
	end

	continueButton.Activated:Connect(continueOrAdvance)
	skipButton.Activated:Connect(skip)

	local api: DialogueWindowApi = {
		Show = function(pages, onComplete)
			if #pages == 0 then
				if onComplete then
					onComplete()
				end
				return
			end
			currentPages = pages
			currentOnComplete = onComplete
			isOpen = true
			wrapper.Visible = true
			showPage(1)
			Motion.FadeIn(wrapper, Theme.Motion.PanelOpen.Time)
			Motion.Tween(scale, "Open", Theme.Motion.PanelOpen, { Scale = 1 })
			previousSelection = GuiService.SelectedObject
			GamepadNav.FocusFirst(wrapper)
		end,
		Skip = skip,
		IsOpen = function()
			return isOpen
		end,
	}

	return wrapper, api
end

return DialogueWindow
