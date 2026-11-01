-- The latest copy of this player's profile from the server (coins, level, suits, passes).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Settings = require(script.Parent.Settings)

local Profile = {
	Data = nil :: any,
	Changed = Signal.new(), -- (data)
}

local settingsLoaded = false

local function apply(data: any)
	if type(data) ~= "table" then
		return
	end
	Profile.Data = data
	if not settingsLoaded then
		settingsLoaded = true
		Settings.Load(data.Settings)
	end
	Profile.Changed:Fire(data)
end

function Profile.Start()
	Remotes.Event("ProfileUpdated").OnClientEvent:Connect(apply)
	task.spawn(function()
		local ok, data = pcall(function()
			return Remotes.Function("GetProfile"):InvokeServer()
		end)
		if ok then
			apply(data)
		end
	end)
end

return Profile
