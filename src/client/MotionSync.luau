-- Sends a small snapshot of what you're doing (state, web points, pose info) to the server
-- about 10 times a second, so other players can draw your webs and poses.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Cleaner = require(ReplicatedStorage.Shared.Cleaner)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local ACTIVE_RATE = 0.1 -- seconds between snapshots while doing something
local IDLE_RATE = 0.5 -- while just standing or walking

local MotionSync = {}
MotionSync.__index = MotionSync

local function ageOf(start: number?, duration: number, now: number): number?
	if start and now - start >= 0 and now - start < duration then
		return now - start
	end
	return nil
end

function MotionSync.new(fsm, motion, visuals)
	local self = setmetatable({
		fsm = fsm,
		motion = motion,
		visuals = visuals,
		timer = 0,
		cleaner = Cleaner.new(),
	}, MotionSync)

	local remote = Remotes.Event("MotionUpdate")
	self.cleaner:Add(RunService.Heartbeat:Connect(function(dt)
		self.timer += dt
		local snapshot, active = self:_snapshot()
		if self.timer >= (if active then ACTIVE_RATE else IDLE_RATE) then
			self.timer = 0
			remote:FireServer(snapshot)
		end
	end))

	return self
end

function MotionSync:_snapshot(): ({ [string]: any }, boolean)
	local m = self.motion
	local now = os.clock()
	local web = if self.visuals.active and #self.visuals.points > 0 then self.visuals.points else nil
	local snapshot = {
		s = self.fsm.Current,
		h = m.webHand,
		p = m.pivot,
		l = math.floor((m.lowness or 0) * 100) / 100,
		st = m.swingStyle,
		d = m.diving,
		fa = ageOf(m.flipStart, Config.Tricks.FlipTime, now),
		fk = m.flipKind,
		ra = ageOf(m.rollStart, Config.Landing.RollTime, now),
		ws = m.wallSide,
		pa = ageOf(m.punchStart, Config.Pose.PunchTime, now),
		ph = m.punchHand,
		w = web,
	}
	local active = snapshot.s ~= "Ground" or web ~= nil or snapshot.pa ~= nil or snapshot.ra ~= nil
	return snapshot, active
end

function MotionSync:Destroy()
	self.cleaner:Clean()
end

return MotionSync
