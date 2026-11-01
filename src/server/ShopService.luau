-- Buying and equipping suits. All checks happen here on the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Suits = require(ReplicatedStorage.Shared.Suits)
local CharacterSpawner = require(script.Parent.CharacterSpawner)
local DataService = require(script.Parent.DataService)

local ShopService = {}

local lastRequest: { [Player]: number } = {}

function ShopService.Start()
	Remotes.Function("ShopRequest").OnServerInvoke = function(player: Player, action: any, suitId: any)
		-- A little spam protection
		local now = os.clock()
		if now - (lastRequest[player] or 0) < 0.3 then
			return false, "Slow down"
		end
		lastRequest[player] = now

		if type(action) ~= "string" or type(suitId) ~= "string" or not Suits.ById[suitId] then
			return false, "Something went wrong"
		end
		if not DataService.WaitForProfile(player, 5) then
			return false, "Your data is still loading"
		end

		if action == "Buy" then
			return DataService.BuySuit(player, suitId)
		elseif action == "Equip" then
			local data = DataService.GetData(player)
			if data and data.Equipped == suitId then
				return true, "Already wearing it"
			end
			local ok, message = DataService.EquipSuit(player, suitId)
			if ok then
				task.spawn(CharacterSpawner.ApplySuit, player)
			end
			return ok, message
		end
		return false, "Something went wrong"
	end

	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

return ShopService
