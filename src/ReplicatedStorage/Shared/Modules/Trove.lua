--!strict
-- Minimal, dependency-free cleanup utility (subset of the common "Trove/Maid"
-- pattern). Hand-rolled per architecture decision #3. Tracks Instances,
-- RBXScriptConnections, callables, and tables with a :Destroy()/:Disconnect().

local Trove = {}
Trove.__index = Trove

type Trackable = Instance | RBXScriptConnection | (() -> ()) | { Destroy: (any) -> () } | { Disconnect: (any) -> () }

function Trove.new()
	return setmetatable({
		_objects = {} :: { Trackable },
	}, Trove)
end

function Trove:Add<T>(object: T): T
	table.insert(self._objects, object :: any)
	return object
end

function Trove:Clean()
	for i = #self._objects, 1, -1 do
		local object = self._objects[i]
		self._objects[i] = nil

		if typeof(object) == "Instance" then
			object:Destroy()
		elseif typeof(object) == "RBXScriptConnection" then
			object:Disconnect()
		elseif typeof(object) == "function" then
			object()
		elseif typeof(object) == "table" then
			local anyObject = object :: any
			if typeof(anyObject.Destroy) == "function" then
				anyObject:Destroy()
			elseif typeof(anyObject.Disconnect) == "function" then
				anyObject:Disconnect()
			end
		end
	end
end

function Trove:Destroy()
	self:Clean()
end

return Trove
