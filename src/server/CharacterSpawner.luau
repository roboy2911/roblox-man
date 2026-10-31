-- Spawns every player as the Web Creature and respawns them after they die.

local Players = game:GetService("Players")

local WebCreatureLook = require(script.Parent.WebCreatureLook)

local CharacterSpawner = {}

local function spawnPlayer(player: Player)
	if player.Parent == nil then
		return
	end
	local ok, err = pcall(function()
		player:LoadCharacterWithHumanoidDescription(WebCreatureLook.CreateDescription())
	end)
	if not ok then
		warn("[CharacterSpawner] Falling back to default character:", err)
		player:LoadCharacter()
	end
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		task.spawn(WebCreatureLook.Decorate, player, character)

		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		humanoid.Died:Connect(function()
			task.wait(Players.RespawnTime)
			if player.Character == character then
				spawnPlayer(player)
			end
		end)
	end)
	spawnPlayer(player)
end

function CharacterSpawner.Start()
	Players.CharacterAutoLoads = false
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return CharacterSpawner
