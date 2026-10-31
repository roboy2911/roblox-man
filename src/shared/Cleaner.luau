-- Collects things to clean up (instances, connections, functions, objects with Destroy)
-- and cleans them all in reverse order.
local Cleaner = {}
Cleaner.__index = Cleaner

function Cleaner.new()
	return setmetatable({ _items = {} }, Cleaner)
end

function Cleaner:Add(item)
	table.insert(self._items, item)
	return item
end

function Cleaner:Clean()
	local items = self._items
	self._items = {}
	for i = #items, 1, -1 do
		local item = items[i]
		local kind = typeof(item)
		if kind == "function" then
			item()
		elseif kind == "RBXScriptConnection" then
			item:Disconnect()
		elseif kind == "Instance" then
			item:Destroy()
		elseif kind == "table" then
			if item.Destroy then
				item:Destroy()
			elseif item.Disconnect then
				item:Disconnect()
			end
		end
	end
end

Cleaner.Destroy = Cleaner.Clean

return Cleaner
