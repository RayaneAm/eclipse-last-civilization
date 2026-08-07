--!strict
-- Minimal, genuinely-new gamepad navigation helpers — zero controller-nav
-- code existed anywhere in the project before this UI system. Scoped
-- deliberately small: NextSelection* chain-wiring plus GuiService.SelectedObject
-- management for one modal panel at a time. NOT a full radial/stick-cursor
-- navigation framework (Roblox's default "virtual cursor" gamepad mode) —
-- that's unnecessary risk for a single panel and explicitly out of scope.

local GuiService = game:GetService("GuiService")

local GamepadNav = {}

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
	for _, descendant in container:GetDescendants() do
		if descendant:IsA("GuiButton") and descendant.Selectable and descendant.Visible then
			GuiService.SelectedObject = descendant
			return descendant
		end
	end
	return nil
end

function GamepadNav.Restore(previous: GuiObject?)
	GuiService.SelectedObject = previous
end

return GamepadNav
