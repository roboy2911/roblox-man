-- The player's settings (camera follow, shake, speed lines, ...). Loaded from their saved
-- profile, and saved back to the server shortly after any change.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Signal = require(ReplicatedStorage.Shared.Signal)

local Settings = {
	Values = table.clone(Config.Settings),
	Changed = Signal.new(), -- (key, value)
}

local saveQueued = false

function Settings.Get(key: string): any
	return Settings.Values[key]
end

function Settings.Set(key: string, value: any)
	if Settings.Values[key] == nil or type(value) ~= type(Settings.Values[key]) then
		return
	end
	Settings.Values[key] = value
	Settings.Changed:Fire(key, value)
	if not saveQueued then
		saveQueued = true
		task.delay(1, function()
			saveQueued = false
			Remotes.Event("SaveSettings"):FireServer(Settings.Values)
		end)
	end
end

-- Applies saved settings without saving them again.
function Settings.Load(saved: any)
	if type(saved) ~= "table" then
		return
	end
	for key, value in saved do
		if Settings.Values[key] ~= nil and type(value) == type(Settings.Values[key]) then
			Settings.Values[key] = value
			Settings.Changed:Fire(key, value)
		end
	end
end

return Settings
