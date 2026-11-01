-- Spawns every player as the Web Creature in their equipped suit, respawns them after they die,
-- and shows a nameplate with their level.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Suits = require(ReplicatedStorage.Shared.Suits)
local DataService = require(script.Parent.DataService)
local WebCreatureLook = require(script.Parent.WebCreatureLook)

local CharacterSpawner = {}

local function suitColors(player: Player)
	local data = DataService.GetData(player)
	local suitId = if data then data.Equipped else Suits.Default
	if not DataService.Owns(player, suitId) then
		suitId = Suits.Default
	end
	return Suits.ById[suitId].Colors
end

local function spawnPlayer(player: Player, at: CFrame?)
	if player.Parent == nil then
		return
	end
	DataService.WaitForProfile(player, 15)
	if player.Parent == nil then
		return
	end
	local ok, err = pcall(function()
		player:LoadCharacterWithHumanoidDescription(WebCreatureLook.CreateDescription(suitColors(player)))
	end)
	if not ok then
		warn("[CharacterSpawner] Falling back to default character:", err)
		player:LoadCharacter()
	end
	local character = player.Character
	if at and character then
		character:PivotTo(at)
	end
end

local function updateNameplate(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local plate = head and head:FindFirstChild("Nameplate")
	local levelLabel = plate and plate:FindFirstChild("Level")
	if levelLabel and levelLabel:IsA("TextLabel") then
		levelLabel.Text = `LV {DataService.Level(player)}`
	end
end

local function addNameplate(player: Player, character: Model)
	local head = character:WaitForChild("Head", 10)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not head then
		return
	end
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end

	local plate = Instance.new("BillboardGui")
	plate.Name = "Nameplate"
	plate.Size = UDim2.fromOffset(200, 46)
	plate.StudsOffset = Vector3.new(0, 2.6, 0)
	plate.MaxDistance = 150
	plate.LightInfluence = 0
	plate.PlayerToHideFrom = player -- you don't need to see your own

	local name = Instance.new("TextLabel")
	name.Name = "PlayerName"
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, 0, 0, 24)
	name.Font = Config.HUD.Font
	name.TextSize = 18
	name.TextColor3 = Color3.new(1, 1, 1)
	name.TextStrokeTransparency = 0.4
	name.Text = player.DisplayName
	name.Parent = plate

	local level = Instance.new("TextLabel")
	level.Name = "Level"
	level.BackgroundTransparency = 1
	level.Position = UDim2.fromOffset(0, 22)
	level.Size = UDim2.new(1, 0, 0, 18)
	level.Font = Config.HUD.Font
	level.TextSize = 14
	level.TextColor3 = Config.HUD.AccentColor
	level.TextStrokeTransparency = 0.4
	level.Text = `LV {DataService.Level(player)}`
	level.Parent = plate

	plate.Parent = head
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		task.spawn(WebCreatureLook.Decorate, player, character, suitColors(player))
		task.spawn(addNameplate, player, character)

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

-- Re-spawns the player in place so a newly equipped suit shows up.
function CharacterSpawner.ApplySuit(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then
		return -- they'll get the new suit on their next spawn
	end
	spawnPlayer(player, character:GetPivot())
end

function CharacterSpawner.Start()
	Players.CharacterAutoLoads = false
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	DataService.LevelChanged:Connect(function(player: Player)
		updateNameplate(player)
	end)
end

return CharacterSpawner
