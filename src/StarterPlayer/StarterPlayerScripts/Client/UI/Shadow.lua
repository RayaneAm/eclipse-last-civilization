--!strict
-- Shared drop-shadow utility. Every "Panel" in this UI system parents
-- directly under either a plain Frame (persistent HUD) or a CanvasGroup
-- wrapper (Toast/Banner/InventoryController/DialogueWindow) — never nested
-- deeper — so a plain sibling Frame, offset and lower-ZIndex, composites
-- correctly in both cases: under a plain Frame it's just an ordinary
-- always-visible sibling; under a CanvasGroup it gets folded into that
-- group's own GroupTransparency-driven fade automatically, with zero extra
-- wiring, since a CanvasGroup composites ALL its descendants as one buffer.
--
-- Known accepted tradeoff: Interaction.Bind's hover/press UIScale (on the
-- button itself) doesn't propagate to this external shadow sibling. At the
-- existing 1.03x/0.97x deltas this is imperceptible — not worth wiring
-- shadow-awareness into Interaction.luau, which stays shadow-agnostic.

local Theme = require(script.Parent.Theme)

local Shadow = {}

export type ShadowOptions = {
	CornerRadius: UDim?,
	Offset: Vector2?,
	Transparency: number?,
	Color: Color3?,
}

-- Returns nil (no-op) if `instance.Parent` isn't set yet — callers should
-- attach after parenting the instance, not before.
function Shadow.Attach(instance: GuiObject, options: ShadowOptions?): Frame?
	local parent = instance.Parent
	if not parent then
		return nil
	end

	local opts = options or {}
	local offset = opts.Offset or Theme.Shadow.Offset
	local cornerRadius = opts.CornerRadius
	if not cornerRadius then
		local existingCorner = instance:FindFirstChildOfClass("UICorner")
		cornerRadius = if existingCorner then existingCorner.CornerRadius else Theme.Corner.Medium
	end

	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.BackgroundColor3 = opts.Color or Theme.Shadow.Color
	shadow.BackgroundTransparency = opts.Transparency or Theme.Shadow.Transparency
	shadow.BorderSizePixel = 0
	shadow.ZIndex = instance.ZIndex - 1
	shadow.AnchorPoint = instance.AnchorPoint
	shadow.Size = instance.Size
	shadow.Position = instance.Position + UDim2.fromOffset(offset.X, offset.Y)
	shadow.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = cornerRadius
	corner.Parent = shadow

	instance:GetPropertyChangedSignal("Size"):Connect(function()
		shadow.Size = instance.Size
	end)
	instance:GetPropertyChangedSignal("Position"):Connect(function()
		shadow.Position = instance.Position + UDim2.fromOffset(offset.X, offset.Y)
	end)

	instance.Destroying:Once(function()
		shadow:Destroy()
	end)

	return shadow
end

return Shadow
