-- Passes each player's movement snapshot (swing state, web points, pose info) on to everyone
-- else, so all players see each other's webs and poses. Snapshots are cleaned up and
-- rate-limited so a bad client can't flood others.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local MotionRelay = {}

local MAX_PER_SECOND = 15
local MAX_WEB_POINTS = 8

local budgets: { [Player]: { tokens: number, last: number } } = {}

local function str(value: any, maxLength: number): string?
	if type(value) == "string" and #value <= maxLength then
		return value
	end
	return nil
end

local function num(value: any, min: number, max: number): number?
	if type(value) == "number" and value == value then -- (value == value) rules out NaN
		return math.clamp(value, min, max)
	end
	return nil
end

local function vec(value: any): Vector3?
	if typeof(value) == "Vector3" and value.Magnitude < 1e6 then
		return value
	end
	return nil
end

-- Keeps only the fields we expect, with sane types and sizes.
local function sanitize(snapshot: any): { [string]: any }?
	if type(snapshot) ~= "table" then
		return nil
	end
	local clean = {
		s = str(snapshot.s, 12),
		h = if snapshot.h == "Left" then "Left" else "Right",
		p = vec(snapshot.p),
		l = num(snapshot.l, 0, 1),
		st = str(snapshot.st, 12),
		d = snapshot.d == true,
		fa = num(snapshot.fa, 0, 5),
		fk = str(snapshot.fk, 12),
		ra = num(snapshot.ra, 0, 5),
		ws = num(snapshot.ws, -1, 1),
		pa = num(snapshot.pa, 0, 5),
		ph = if snapshot.ph == "Left" then "Left" else "Right",
	}
	if type(snapshot.w) == "table" then
		local points = {}
		for i = 1, math.min(#snapshot.w, MAX_WEB_POINTS) do
			local point = vec(snapshot.w[i])
			if not point then
				break
			end
			points[i] = point
		end
		if #points > 0 then
			clean.w = points
		end
	end
	return clean
end

local function allow(player: Player): boolean
	local now = os.clock()
	local budget = budgets[player]
	if not budget then
		budget = { tokens = MAX_PER_SECOND, last = now }
		budgets[player] = budget
	end
	budget.tokens = math.min(MAX_PER_SECOND, budget.tokens + (now - budget.last) * MAX_PER_SECOND)
	budget.last = now
	if budget.tokens < 1 then
		return false
	end
	budget.tokens -= 1
	return true
end

function MotionRelay.Start()
	local broadcast = Remotes.Event("MotionBroadcast")
	Remotes.Event("MotionUpdate").OnServerEvent:Connect(function(player: Player, snapshot: any)
		if not allow(player) then
			return
		end
		local clean = sanitize(snapshot)
		if not clean then
			return
		end
		for _, other in Players:GetPlayers() do
			if other ~= player then
				broadcast:FireClient(other, player, clean)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		budgets[player] = nil
	end)
end

return MotionRelay
