-- Minimal signal: Connect / Fire / Destroy.
local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal:Connect(fn)
	local handlers = self._handlers
	local entry = { fn = fn, connected = true }
	table.insert(handlers, entry)
	return {
		Disconnect = function()
			entry.connected = false
			local index = table.find(handlers, entry)
			if index then
				table.remove(handlers, index)
			end
		end,
	}
end

function Signal:Fire(...)
	for _, entry in table.clone(self._handlers) do
		if entry.connected then
			task.spawn(entry.fn, ...)
		end
	end
end

function Signal:Destroy()
	table.clear(self._handlers)
end

return Signal
