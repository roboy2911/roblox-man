-- Ground and Air states.
-- Roblox's Humanoid normally kills your speed in the air almost instantly. After a swing we
-- don't want that, so in the Air state we hold on to horizontal momentum ourselves and let
-- it fade slowly, with gentle steering.
-- Landing fast rolls you out of it and keeps you sliding forward for a moment, instead of
-- stopping dead.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cleaner = require(ReplicatedStorage.Shared.Cleaner)
local Config = require(ReplicatedStorage.Shared.Config)
local MathUtil = require(ReplicatedStorage.Shared.MathUtil)

local A = Config.Air
local L = Config.Landing

local LocomotionController = {}
LocomotionController.__index = LocomotionController

function LocomotionController.new(ctx, fsm, motion)
	local self = setmetatable({
		ctx = ctx,
		fsm = fsm,
		motion = motion,
		cleaner = Cleaner.new(),
		lastAirVelocity = Vector3.zero,
		slideUntil = 0,
		slideStart = 0,
		slideSpeed = 0,
		slideDirection = Vector3.zero,
	}, LocomotionController)

	-- Only pushes horizontally (Y force is 0), so gravity still works normally.
	local momentum = Instance.new("LinearVelocity")
	momentum.Name = "AirMomentum"
	momentum.Attachment0 = ctx.RootAttachment
	momentum.RelativeTo = Enum.ActuatorRelativeTo.World
	momentum.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	momentum.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	momentum.MaxAxesForce = Vector3.new(A.ForceLimit, 0, A.ForceLimit)
	momentum.Enabled = false
	momentum.Parent = ctx.Root
	self.momentum = self.cleaner:Add(momentum)

	fsm:Register("Ground", {
		Enter = function(previous)
			self:_land(previous)
		end,
		Exit = function()
			momentum.Enabled = false
			self.slideUntil = 0
		end,
		Update = function(dt)
			if not ctx:IsGrounded() then
				fsm:Set("Air")
				return
			end
			self:_updateSlide(dt)
		end,
	})

	fsm:Register("Air", {
		Enter = function()
			self:_enterAir()
		end,
		Exit = function()
			momentum.Enabled = false
		end,
		Update = function(dt)
			if ctx:IsGrounded() then
				fsm:Set("Ground")
				return
			end
			self.lastAirVelocity = ctx.Root.AssemblyLinearVelocity
			self:_updateAir(dt)
		end,
	})

	return self
end

function LocomotionController:_land(previous: string?)
	self.momentum.Enabled = false
	if previous == nil then
		return -- just spawned
	end

	local landingVelocity = if previous == "Air" then self.lastAirVelocity else self.ctx.Root.AssemblyLinearVelocity
	self.lastAirVelocity = Vector3.zero
	local flatVelocity = MathUtil.flat(landingVelocity)
	local impact = landingVelocity.Magnitude
	self.motion.events:Fire("Land", impact)

	if flatVelocity.Magnitude > L.RollMinSpeed then
		-- Roll out of it and keep sliding.
		self.motion.rollStart = os.clock()
		self.slideStart = os.clock()
		self.slideUntil = os.clock() + L.SlideTime
		self.slideSpeed = flatVelocity.Magnitude * L.SlideKeep
		self.slideDirection = flatVelocity.Unit
		self.momentum.VectorVelocity = self.slideDirection * self.slideSpeed
		self.momentum.Enabled = true
	end
end

function LocomotionController:_updateSlide(_dt: number)
	local momentum = self.momentum
	if not momentum.Enabled then
		return
	end
	local now = os.clock()
	local walk = self.ctx.Humanoid.WalkSpeed
	if now >= self.slideUntil then
		momentum.Enabled = false
		return
	end
	-- Ease the slide speed down to walking speed.
	local t = (now - self.slideStart) / L.SlideTime
	local speed = walk + (self.slideSpeed - walk) * (1 - t) ^ 2
	-- Follow the stick/keys a little, so you can steer out of a slide.
	local move = MathUtil.flat(self.ctx.Humanoid.MoveDirection)
	if move.Magnitude > 0.1 then
		self.slideDirection = MathUtil.safeUnit(self.slideDirection:Lerp(move.Unit, 0.1), self.slideDirection)
	end
	momentum.VectorVelocity = self.slideDirection * math.max(speed, walk)
end

function LocomotionController:_enterAir()
	local flatVelocity = MathUtil.flat(self.ctx.Root.AssemblyLinearVelocity)
	self.lastAirVelocity = self.ctx.Root.AssemblyLinearVelocity
	if flatVelocity.Magnitude > self.ctx.Humanoid.WalkSpeed + A.MomentumThreshold then
		self.momentum.VectorVelocity = flatVelocity
		self.momentum.Enabled = true
	else
		self.momentum.Enabled = false
	end
end

function LocomotionController:_updateAir(dt: number)
	local momentum = self.momentum
	local humanoid = self.ctx.Humanoid
	local diving = self.motion.diving
	-- Read the real velocity, so hitting a wall correctly stops us.
	local flatVelocity = MathUtil.flat(self.ctx.Root.AssemblyLinearVelocity)
	local speed = flatVelocity.Magnitude

	-- Pick momentum back up if something (like a dive) made us fast again.
	if not momentum.Enabled then
		if diving or speed > humanoid.WalkSpeed + A.MomentumThreshold then
			momentum.Enabled = true
		else
			return
		end
	end

	if speed < 0.01 then
		momentum.Enabled = false
		return
	end
	local direction = flatVelocity.Unit

	local move = MathUtil.flat(humanoid.MoveDirection)
	if move.Magnitude > 0.1 then
		move = move.Unit
		if direction:Dot(move) < -0.3 and not diving then
			-- Holding backwards brakes.
			speed = math.max(0, speed - A.Brake * dt)
		else
			direction = MathUtil.safeUnit(direction:Lerp(move, MathUtil.expAlpha(A.SteerRate, dt)), direction)
		end
	end

	if not diving then
		speed *= math.exp(-A.Drag * dt)
	end

	if speed <= humanoid.WalkSpeed + 1 and not diving then
		-- Slow enough: hand control back to the normal Humanoid.
		momentum.Enabled = false
		return
	end

	momentum.VectorVelocity = direction * speed
end

function LocomotionController:Destroy()
	self.cleaner:Clean()
end

return LocomotionController
