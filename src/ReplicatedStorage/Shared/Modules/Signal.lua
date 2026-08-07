--!strict
-- Minimal, dependency-free signal implementation (GoodSignal-style: coroutine
-- reuse, no BindableEvent overhead). Kept in-house per architecture decision #3
-- so the project has zero install step; swap for a Wally package later if needed.

local Signal = {}
Signal.__index = Signal

type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

function Signal.new()
	return setmetatable({
		_handlers = {} :: { [number]: (...any) -> () },
		_nextId = 0,
	}, Signal)
end

function Signal:Connect(handler: (...any) -> ()): Connection
	local id = self._nextId
	self._nextId += 1
	self._handlers[id] = handler

	local connection = {
		Connected = true,
	}

	function connection:Disconnect()
		if self.Connected then
			self.Connected = false
		end
	end

	local handlers = self._handlers
	local originalDisconnect = connection.Disconnect
	connection.Disconnect = function(self)
		originalDisconnect(self)
		handlers[id] = nil
	end

	return connection :: any
end

function Signal:Once(handler: (...any) -> ()): Connection
	local connection: Connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		handler(...)
	end)
	return connection
end

function Signal:Fire(...: any)
	for _, handler in self._handlers do
		task.spawn(handler, ...)
	end
end

function Signal:Wait(): ...any
	local thread = coroutine.running()
	local connection: Connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function Signal:DisconnectAll()
	table.clear(self._handlers)
end

function Signal:Destroy()
	self:DisconnectAll()
end

return Signal
