--!strict
-- Phase 4B: minimal FIFO async mutex, the same "small hand-rolled utility"
-- convention as Signal.luau/Trove.luau elsewhere in this project. Roblox
-- server scripts are cooperatively scheduled — a coroutine that yields (e.g.
-- on a DataStore call) lets OTHER coroutines run in the gap, so "single-
-- threaded" alone does NOT prevent two logical operations on the same
-- player/base from interleaving their reads/writes. Every economy mutation
-- (PlayerProfileService, BaseService) acquires one of these — per-player or
-- per-host — before touching its cache, closing that gap.
--
-- Uncontended Acquire() returns immediately (no yield) — the common case for
-- ordinary, non-yielding mutations stays exactly as fast as it is today.
-- Contended Acquire() (only when a DataStore-touching commit is already in
-- flight for that same key) yields until Release() resumes it, in strict
-- FIFO order.

local Mutex = {}
Mutex.__index = Mutex

export type Mutex = typeof(setmetatable(
	{} :: { _locked: boolean, _waiters: { thread } },
	Mutex
))

function Mutex.new(): Mutex
	return setmetatable({ _locked = false, _waiters = {} }, Mutex)
end

function Mutex.Acquire(self: Mutex)
	if not self._locked then
		self._locked = true
		return
	end
	local thread = coroutine.running()
	table.insert(self._waiters, thread)
	coroutine.yield()
end

function Mutex.Release(self: Mutex)
	local nextThread = table.remove(self._waiters, 1)
	if nextThread then
		task.spawn(nextThread)
	else
		self._locked = false
	end
end

return Mutex
