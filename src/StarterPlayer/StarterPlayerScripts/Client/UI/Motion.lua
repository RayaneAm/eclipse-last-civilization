--!strict
-- Cancel-safe TweenService wrapper for 2D GuiObjects. AmbientController's
-- shared Heartbeat loop is explicitly PivotTo/3D-only (Part/Model, see its
-- own doc comment) and stays that way — GuiObjects have no PivotTo/CFrame, so
-- 2D UI motion needs its own small helper rather than being bolted onto that
-- loop.
--
-- Why not just bare TweenService:Create everywhere (the norm elsewhere in the
-- project)? Button hover/press fires rapidly and repeatedly (a mouse crossing
-- several tiles, a mobile thumb drag, gamepad d-pad spam) — stacking
-- uncancelled tweens on the same property makes them fight each other, a bug
-- class the project's existing one-shot fades (panel open, region toast) never
-- had to handle. This module fixes it once, keyed per (instance, channel).

local TweenService = game:GetService("TweenService")

local Motion = {}

local activeTweens: { [Instance]: { [string]: Tween } } = setmetatable({}, { __mode = "k" }) :: any

-- `channel` is a caller-chosen label (e.g. "Scale", "Stroke"), not necessarily
-- a literal property name, so an instance can have several independent tween
-- channels that don't cancel each other (e.g. a button scaling AND its stroke
-- glowing at the same time).
function Motion.Tween(instance: Instance, channel: string, tweenInfo: TweenInfo, props: { [string]: any }): Tween
	local existing = activeTweens[instance]
	if existing and existing[channel] then
		existing[channel]:Cancel()
	end

	local tween = TweenService:Create(instance, tweenInfo, props)
	activeTweens[instance] = activeTweens[instance] or {}
	(activeTweens[instance] :: { [string]: Tween })[channel] = tween
	tween:Play()
	return tween
end

function Motion.FadeIn(instance: GuiObject, duration: number?)
	instance.Visible = true
	local tweenInfo = TweenInfo.new(duration or 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	if instance:IsA("CanvasGroup") then
		Motion.Tween(instance, "Fade", tweenInfo, { GroupTransparency = 0 })
	else
		Motion.Tween(instance, "Fade", tweenInfo, { BackgroundTransparency = 0 })
	end
end

function Motion.FadeOut(instance: GuiObject, duration: number?, onComplete: (() -> ())?)
	local tweenInfo = TweenInfo.new(duration or 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween: Tween
	if instance:IsA("CanvasGroup") then
		tween = Motion.Tween(instance, "Fade", tweenInfo, { GroupTransparency = 1 })
	else
		tween = Motion.Tween(instance, "Fade", tweenInfo, { BackgroundTransparency = 1 })
	end
	if onComplete then
		tween.Completed:Once(onComplete)
	end
end

return Motion
