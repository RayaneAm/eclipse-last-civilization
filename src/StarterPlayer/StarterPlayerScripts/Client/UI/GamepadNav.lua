--!strict
-- Minimal, genuinely-new gamepad navigation helpers — zero controller-nav
-- code existed anywhere in the project before this UI system. Scoped
-- deliberately small: NextSelection* chain-wiring plus GuiService.SelectedObject
-- management for one modal panel at a time. NOT a full radial/stick-cursor
-- navigation framework (Roblox's default "virtual cursor" gamepad mode) —
-- that's unnecessary risk for a single panel and explicitly out of scope.

local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local GamepadNav = {}

local function isActuallyVisible(guiObject: GuiObject): boolean
	local current: Instance? = guiObject
	local screenGui: ScreenGui? = nil
	local screenRoot: GuiObject? = nil
	while current do
		if current:IsA("GuiObject") and not current.Visible then
			return false
		end
		if current:IsA("LayerCollector") and not current.Enabled then
			return false
		end
		if current:IsA("ScreenGui") then
			screenGui = current
			break
		end
		if current:IsA("GuiObject") then
			screenRoot = current
		end
		current = current.Parent
	end

	-- GuiService rejects targets that are technically Visible but currently
	-- outside the rendered viewport (common while a modal is settling in).
	local position = guiObject.AbsolutePosition
	local size = guiObject.AbsoluteSize
	local bounds = screenRoot and screenRoot.AbsoluteSize
	if screenGui and bounds then
		if position.X < 0 or position.Y < 0 or position.X + size.X > bounds.X or position.Y + size.Y > bounds.Y then
			return false
		end
	end
	return true
end

-- Wires a flat vertical Up/Down chain (e.g. a tab strip, a single-column
-- list). No wraparound at the ends.
function GamepadNav.LinkChain(buttons: { GuiButton })
	for i, button in buttons do
		local previous = buttons[i - 1]
		local next = buttons[i + 1]
		if previous then
			button.NextSelectionUp = previous
		end
		if next then
			button.NextSelectionDown = next
		end
	end
end

-- Wires a grid (e.g. the inventory tile grid): Left/Right within a row,
-- Up/Down by matching column index across rows. Clamped, no wraparound.
function GamepadNav.LinkGrid(buttons: { GuiButton }, columns: number)
	local rowCount = math.ceil(#buttons / columns)

	for index, button in buttons do
		local row = math.floor((index - 1) / columns)
		local column = (index - 1) % columns

		local leftIndex = if column > 0 then index - 1 else nil
		local rightIndex = if column < columns - 1 and index < #buttons then index + 1 else nil
		local upIndex = if row > 0 then index - columns else nil
		local downIndex = if row < rowCount - 1 and index + columns <= #buttons then index + columns else nil

		if leftIndex then
			button.NextSelectionLeft = buttons[leftIndex]
		end
		if rightIndex then
			button.NextSelectionRight = buttons[rightIndex]
		end
		if upIndex then
			button.NextSelectionUp = buttons[upIndex]
		end
		if downIndex then
			button.NextSelectionDown = buttons[downIndex]
		end
	end
end

-- Finds the first Selectable GuiButton under `container` (depth-first) and
-- makes it the active gamepad selection. Returns what it picked, if anything.
function GamepadNav.FocusFirst(container: GuiObject): GuiObject?
	if not UserInputService.GamepadEnabled then
		return nil
	end
	for _, descendant in container:GetDescendants() do
		if descendant:IsA("GuiButton") and descendant.Selectable and isActuallyVisible(descendant) then
			GuiService.SelectedObject = descendant
			return descendant
		end
	end
	return nil
end

function GamepadNav.Restore(previous: GuiObject?)
	if not UserInputService.GamepadEnabled then
		GuiService.SelectedObject = nil
		return
	end
	if previous and previous.Parent and previous.Selectable and isActuallyVisible(previous) then
		GuiService.SelectedObject = previous
	else
		GuiService.SelectedObject = nil
	end
end

return GamepadNav
