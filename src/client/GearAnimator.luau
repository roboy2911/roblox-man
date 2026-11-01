-- Animates the four mechanical spider legs on the Web Creature's back.
-- The server builds them with real joints (SpiderHip_R1, SpiderKnee_R1, ...); here we rotate
-- those joints every frame depending on what you're doing:
--   * standing: slow, gentle breathing sway
--   * walking/running: a scuttling cycle
--   * swinging/zipping: legs flare wide and twitch with speed
--   * in the air: spread out like a falling spider; folded back when diving
--   * wall running: legs reach toward the wall
-- Local to this player for now.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Cleaner = require(ReplicatedStorage.Shared.Cleaner)
local MathUtil = require(ReplicatedStorage.Shared.MathUtil)

local rad = math.rad

type LegJoint = { motor: Motor6D, base: CFrame, side: number, index: number, isKnee: boolean }

local GearAnimator = {}
GearAnimator.__index = GearAnimator

function GearAnimator.new(ctx, fsm, motion)
	local self = setmetatable({
		ctx = ctx,
		fsm = fsm,
		motion = motion,
		joints = {} :: { LegJoint },
		current = {} :: { [Motor6D]: CFrame },
		time = 0,
		nextSearch = 0,
		cleaner = Cleaner.new(),
	}, GearAnimator)

	self.cleaner:Add(RunService.PreSimulation:Connect(function(dt)
		self:_update(dt)
	end))

	return self
end

-- The gear is added by the server a moment after spawning, so keep looking until it's there.
function GearAnimator:_find()
	local gear = self.ctx.Character:FindFirstChild("WebCreatureGear")
	if not gear then
		return
	end
	local joints = {}
	for _, descendant in gear:GetDescendants() do
		if descendant:IsA("Motor6D") then
			local kind, sideName, index = string.match(descendant.Name, "^Spider(%a+)_(%a)(%d)$")
			if kind and sideName and index then
				table.insert(joints, {
					motor = descendant,
					base = descendant.C0,
					side = if sideName == "R" then 1 else -1,
					index = tonumber(index) :: number,
					isKnee = kind == "Knee",
				})
				self.current[descendant] = CFrame.identity
			end
		end
	end
	self.joints = joints
end

-- Target rotation for one joint: pitch lifts/lowers the leg, yaw swings it forward/back.
function GearAnimator:_target(joint: LegJoint, speed: number): CFrame
	local state = self.fsm.Current
	local t = self.time
	local phase = joint.index * 1.7 + (if joint.side > 0 then 0 else math.pi)
	local s = joint.side

	if state == "Swing" or state == "Zip" then
		local twitch = math.sin(t * 22 + phase) * MathUtil.remapClamped(speed, 30, 120, 0, 6)
		if joint.isKnee then
			return CFrame.Angles(rad(-15 + twitch), 0, 0)
		end
		return CFrame.Angles(rad(15 + twitch), s * rad(-20), 0)
	elseif state == "WallRun" then
		local wallSide = self.motion.wallSide or 1
		local towardWall = if s == wallSide then 1 else 0
		local step = math.sin(t * 16 + phase) * 15
		if joint.isKnee then
			return CFrame.Angles(rad(-20 * towardWall + step * 0.5), 0, 0)
		end
		return CFrame.Angles(rad(-25 * towardWall + step), 0, 0)
	elseif state == "Air" then
		if self.motion.diving then
			if joint.isKnee then
				return CFrame.Angles(rad(35), 0, 0)
			end
			return CFrame.Angles(rad(-20), s * rad(25), 0)
		end
		local flutter = math.sin(t * 9 + phase) * 6
		if joint.isKnee then
			return CFrame.Angles(rad(-10 + flutter), 0, 0)
		end
		return CFrame.Angles(rad(10 + flutter), s * rad(-12), 0)
	end

	-- Ground: scuttle while moving, breathe while standing.
	local walkAmount = MathUtil.remapClamped(speed, 2, 16, 0, 1)
	local scuttle = math.sin(t * 14 + phase) * 22 * walkAmount
	local breathe = math.sin(t * 1.8 + phase) * 4 * (1 - walkAmount)
	if joint.isKnee then
		return CFrame.Angles(rad(math.abs(scuttle) * 0.6 + breathe), 0, 0)
	end
	return CFrame.Angles(rad(breathe), s * rad(scuttle), 0)
end

function GearAnimator:_update(dt: number)
	self.time += dt

	local now = os.clock()
	local needsSearch = #self.joints == 0 or not self.joints[1].motor:IsDescendantOf(self.ctx.Character)
	if needsSearch then
		if now < self.nextSearch then
			return
		end
		self.nextSearch = now + 0.5
		self:_find()
		if #self.joints == 0 then
			return
		end
	end

	local speed = self.ctx.Root.AssemblyLinearVelocity.Magnitude
	local alpha = MathUtil.expAlpha(10, dt)
	for _, joint in self.joints do
		local current = self.current[joint.motor]:Lerp(self:_target(joint, speed), alpha)
		self.current[joint.motor] = current
		joint.motor.C0 = joint.base * current
	end
end

function GearAnimator:Destroy()
	self.cleaner:Clean()
end

return GearAnimator
