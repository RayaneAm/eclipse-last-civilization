--!strict
-- A tiny name -> open-function registry for facility screens.
--
-- Base Management's "SUGGESTED" rows want to open the Generator, the
-- Processor or the Upgrade Station; the Defense screen wants to jump to a
-- wall's upgrade dialog. Having each controller `require` the others would
-- create real cycles (Base Management -> Production -> Base Management), and
-- Luau resolves a cycle by handing back a half-initialized module — a class
-- of bug that only shows up at runtime, in whichever order the Loader
-- happened to require things.
--
-- Instead every facility controller registers its own opener during Init,
-- and callers route by string id. A row whose destination is not registered
-- simply renders as non-interactive (see RecommendationRow), so a missing
-- or failed controller degrades to "no link" rather than erroring.

local FacilityRouter = {}

export type Opener = (...any) -> ()

local openers: { [string]: Opener } = {}

function FacilityRouter.Register(id: string, opener: Opener)
	if openers[id] then
		warn(`FacilityRouter: "{id}" was registered twice; keeping the first registration`)
		return
	end
	openers[id] = opener
end

function FacilityRouter.Has(id: string): boolean
	return openers[id] ~= nil
end

-- Returns true when something was actually opened, so a caller can fall back
-- to a message instead of silently doing nothing.
function FacilityRouter.Open(id: string, ...: any): boolean
	local opener = openers[id]
	if not opener then
		return false
	end
	opener(...)
	return true
end

return FacilityRouter
