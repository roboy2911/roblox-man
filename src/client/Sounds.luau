-- Plays non-positional sounds (menus, rewards). Sounds with an empty Id in
-- Config.Effects.Sounds are silently skipped.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)

local Sounds = {}

local cache: { [string]: Sound } = {}

function Sounds.Play(name: string)
	local def = Config.Effects.Sounds[name]
	if not def or def.Id == "" then
		return
	end
	local sound = cache[name]
	if not sound then
		sound = Instance.new("Sound")
		sound.Name = name
		sound.SoundId = def.Id
		sound.Volume = def.Volume
		sound.PlaybackSpeed = def.Speed
		sound.Parent = SoundService
		cache[name] = sound
	end
	SoundService:PlayLocalSound(sound)
end

return Sounds
