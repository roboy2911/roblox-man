-- Ground and Air states.
-- Roblox's Humanoid normally kills your speed in the air almost instantly. After a swing we
-- don't want that, so in the Air state we hold on to horizontal momentum ourselves and let
-- it fade slowly, with gentle steering.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cleaner = require(ReplicatedStorage.Shared.Cleaner)
local Config = require(ReplicatedStorage.Shared.Config)
local MathUtil = require(ReplicatedStorage.Shared.MathUtil)

local A = Config.Air

local LocomotionController = {}
LocomotionController.__index = LocomotionController

function LocomotionController.new(ctx, fsm)
	local self = setmetatable({
		ctx = ctx,
		fsm = fsm,
		cleaner = Cleaner.new(),
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
		Enter = function()
			momentum.Enabled = false
		end,
		Update = function()
			if not ctx:IsGrounded() then
				fsm:Set("Air")
			end
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
			self:_updateAir(dt)
		end,
	})

	return self
end

function LocomotionController:_enterAir()
	local flatVelocity = MathUtil.flat(self.ctx.Root.AssemblyLinearVelocity)
	if flatVelocity.Magnitude > self.ctx.Humanoid.WalkSpeed + A.MomentumThreshold then
		self.momentum.VectorVelocity = flatVelocity
		self.momentum.Enabled = true
	else
		self.momentum.Enabled = false
	end
end

function LocomotionController:_updateAir(dt: number)
	local momentum = self.momentum
	if not momentum.Enabled then
		return
	end

	local humanoid = self.ctx.Humanoid
	-- Read the real velocity, so hitting a wall correctly stops us.
	local flatVelocity = MathUtil.flat(self.ctx.Root.AssemblyLinearVelocity)
	local speed = flatVelocity.Magnitude
	if speed < 0.01 then
		momentum.Enabled = false
		return
	end
	local direction = flatVelocity.Unit

	local move = MathUtil.flat(humanoid.MoveDirection)
	if move.Magnitude > 0.1 then
		move = move.Unit
		if direction:Dot(move) < -0.3 then
			-- Holding backwards brakes.
			speed = math.max(0, speed - A.Brake * dt)
		else
			direction = MathUtil.safeUnit(direction:Lerp(move, MathUtil.expAlpha(A.SteerRate, dt)), direction)
		end
	end

	speed *= math.exp(-A.Drag * dt)

	if speed <= humanoid.WalkSpeed + 1 then
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
