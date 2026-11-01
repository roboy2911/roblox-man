-- All client <-> server messages. The server creates them at startup; clients wait for them.
--
-- Events:
--   MotionUpdate     client -> server   this player's movement snapshot (for others to see)
--   MotionBroadcast  server -> clients  (player, snapshot) for every other player
--   Punch            client -> server   the player threw a punch
--   HitFx            server -> clients  (position) a punch or thug attack landed
--   Trick            client -> server   (name) a trick was done, for a little XP
--   ProfileUpdated   server -> client   the player's coins / XP / suits / settings
--   Notify           server -> client   (text) a small notification
--   SaveSettings     client -> server   (settings table)
-- Functions:
--   GetProfile       client -> server   returns the profile
--   ShopRequest      client -> server   (action, suitId) -> (ok, message)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	"MotionUpdate",
	"MotionBroadcast",
	"Punch",
	"HitFx",
	"Trick",
	"ProfileUpdated",
	"Notify",
	"SaveSettings",
}
local FUNCTIONS = { "GetProfile", "ShopRequest" }

local Remotes = {}

-- Server only: create everything.
function Remotes.Setup()
	assert(RunService:IsServer(), "Remotes.Setup runs on the server")
	local folder = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in EVENTS do
		if not folder:FindFirstChild(name) then
			local event = Instance.new("RemoteEvent")
			event.Name = name
			event.Parent = folder
		end
	end
	for _, name in FUNCTIONS do
		if not folder:FindFirstChild(name) then
			local fn = Instance.new("RemoteFunction")
			fn.Name = name
			fn.Parent = folder
		end
	end
	folder.Parent = ReplicatedStorage
end

local function folder(): Instance
	return ReplicatedStorage:WaitForChild("Remotes")
end

function Remotes.Event(name: string): RemoteEvent
	return folder():WaitForChild(name) :: RemoteEvent
end

function Remotes.Function(name: string): RemoteFunction
	return folder():WaitForChild(name) :: RemoteFunction
end

return Remotes
