-- Air tricks:
--   * Web zip (E / L1): shoots a web where the camera is aiming and yanks you to it, with a pop
--     at the end to hop over ledges. Works from the ground, the air, or mid-swing.
--   * Double jump (jump in the air): a second jump with a front flip. Recharges when you land,
--     swing or zip.
--   * Dive (hold Q / L2 in the air): fall faster and turn it into forward speed for the next web.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Cleaner = require(ReplicatedStorage.Shared.Cleaner)
local Config = require(ReplicatedStorage.Shared.Config)
local MathUtil = require(ReplicatedStorage.Shared.MathUtil)

local T = Config.Tricks
local flat = MathUtil.flat
local safeUnit = MathUtil.safeUnit

local TrickController = {}
TrickController.__index = TrickController

function TrickController.new(ctx, fsm, input, camera, visuals, effects, motion)
	local self = setmetatable({
		ctx = ctx,
		fsm = fsm,
		input = input,
		camera = camera,
		visuals = visuals,
		effects = effects,
		motion = motion,
		cleaner = Cleaner.new(),

		zipRequested = false,
		zipCooldownUntil = 0,
		zipTarget = Vector3.zero,
		zipTime = 0,
		zipStartSpeed = 0,
		zipSpeed = 0,
		zipExitVelocity = nil :: Vector3?,
		lastCommanded = Vector3.zero,

		jumpRequestTime = -math.huge,
		lastJumpSignal = -math.huge,
		airStart = 0,
		airJumpsLeft = T.AirJumps,
	}, TrickController)

	-- Constraints for the zip (same approach as swinging)
	local driver = Instance.new("LinearVelocity")
	driver.Name = "ZipDriver"
	driver.Attachment0 = ctx.RootAttachment
	driver.RelativeTo = Enum.ActuatorRelativeTo.World
	driver.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	driver.MaxForce = math.huge
	driver.Enabled = false
	driver.Parent = ctx.Root
	self.driver = self.cleaner:Add(driver)

	local facing = Instance.new("AlignOrientation")
	facing.Name = "ZipFacing"
	facing.Mode = Enum.OrientationAlignmentMode.OneAttachment
	facing.Attachment0 = ctx.RootAttachment
	facing.MaxTorque = math.huge
	facing.Responsiveness = 25
	facing.Enabled = false
	facing.Parent = ctx.Root
	self.facing = self.cleaner:Add(facing)

	fsm:Register("Zip", {
		Enter = function(_previous, target: Vector3, hand: string)
			self:_enterZip(target, hand)
		end,
		Exit = function()
			self:_exitZip()
		end,
		Update = function(dt: number)
			self:_updateZip(dt)
		end,
	})

	-- Inputs are only recorded here; they're acted on in the movement update below.
	self.cleaner:Add(input.ActionBegan:Connect(function(action: string)
		if action == "Zip" then
			self.zipRequested = true
		end
	end))
	-- JumpRequest can repeat while the button is held, so only count it as a new press after a gap.
	self.cleaner:Add(UserInputService.JumpRequest:Connect(function()
		local now = os.clock()
		if now - self.lastJumpSignal > 0.2 then
			self.jumpRequestTime = now
		end
		self.lastJumpSignal = now
	end))

	-- Recharge the double jump, and note when we left the ground.
	self.cleaner:Add(fsm.Changed:Connect(function(newState: string)
		if newState == "Air" then
			self.airStart = os.clock()
		else
			self.airJumpsLeft = T.AirJumps
		end
	end))

	fsm:AddHook(function(dt: number)
		self:_hook(dt)
	end)

	return self
end

function TrickController:_hook(dt: number)
	local fsm = self.fsm
	local ctx = self.ctx
	if not ctx:IsAlive() then
		return
	end

	-- Web zip
	if self.zipRequested then
		self.zipRequested = false
		local canZip = fsm:Is("Ground") or fsm:Is("Air") or fsm:Is("Swing")
		if canZip and os.clock() >= self.zipCooldownUntil then
			local target, hand = self:_findZipTarget()
			if target then
				fsm:Set("Zip", target, hand)
				return
			end
		end
	end

	if not fsm:Is("Air") then
		self.motion.diving = false
		return
	end

	-- Double jump (only for presses made after we'd been airborne a moment)
	if
		self.airJumpsLeft > 0
		and self.jumpRequestTime > self.airStart + T.AirJumpMinAirTime
		and os.clock() - self.jumpRequestTime < 0.15
	then
		self.airJumpsLeft -= 1
		self.jumpRequestTime = -math.huge
		local v = ctx.Root.AssemblyLinearVelocity
		ctx.Root.AssemblyLinearVelocity = Vector3.new(v.X, T.AirJumpPower, v.Z)
		self.motion.flipStart = os.clock()
		self.effects:AirJump()
		self.camera:Kick(3)
	end

	-- Dive
	local diving = self.input:IsDown("Dive")
	self.motion.diving = diving
	if diving then
		local root = ctx.Root
		local v = root.AssemblyLinearVelocity
		local flatV = flat(v)
		local cameraForward = safeUnit(flat(workspace.CurrentCamera.CFrame.LookVector), Vector3.zAxis)
		local forward = safeUnit(flatV, cameraForward)
		local add = forward * T.DiveForwardAccel * dt
		if (flatV + add).Magnitude > T.DiveMaxSpeed then
			add = Vector3.zero
		end
		root.AssemblyLinearVelocity = v + add + Vector3.new(0, -T.DiveGravity * dt, 0)
	end
end

-- Where the camera is aiming, if it's a building within range.
function TrickController:_findZipTarget(): (Vector3?, string?)
	local camera = workspace.CurrentCamera
	local root = self.ctx.Root
	local origin = camera.CFrame.Position
	local range = T.ZipRange + (origin - root.Position).Magnitude
	local result = workspace:Raycast(origin, camera.CFrame.LookVector * range, self.ctx.SwingParams)
	if not result then
		return nil, nil
	end
	local target = result.Position + result.Normal * 1.5
	if (target - root.Position).Magnitude < T.ZipArriveDistance + 2 then
		return nil, nil
	end
	local hand = if (target - root.Position):Dot(camera.CFrame.RightVector) >= 0 then "Right" else "Left"
	return target, hand
end

function TrickController:_enterZip(target: Vector3, hand: string)
	local ctx = self.ctx
	local root = ctx.Root
	local humanoid = ctx.Humanoid

	local toTarget = target - root.Position
	self.zipTarget = target
	self.zipTime = 0
	self.zipStartSpeed = math.max(0, root.AssemblyLinearVelocity:Dot(toTarget.Unit))
	self.zipSpeed = self.zipStartSpeed
	self.zipExitVelocity = nil
	self.lastCommanded = root.AssemblyLinearVelocity

	humanoid.AutoRotate = false
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)

	self.driver.VectorVelocity = root.AssemblyLinearVelocity
	self.driver.Enabled = true
	local faceDir = safeUnit(flat(toTarget), safeUnit(flat(root.CFrame.LookVector), Vector3.zAxis))
	self.facing.CFrame = CFrame.lookAt(Vector3.zero, faceDir)
	self.facing.Enabled = true

	self.motion.webHand = hand
	self.motion.pivot = target
	self.visuals:Attach(target, ctx.HandAttachments[hand])
	self.effects:Zip()
	self.camera:Kick(T.ZipKick)
end

function TrickController:_finishZip(direction: Vector3)
	self.zipExitVelocity = direction * self.zipSpeed * T.ZipExitCarry + Vector3.new(0, T.ZipEndPop, 0)
	self.fsm:Set("Air")
end

function TrickController:_updateZip(dt: number)
	local root = self.ctx.Root
	self.zipTime += dt

	local toTarget = self.zipTarget - root.Position
	local distance = toTarget.Magnitude
	local direction = safeUnit(toTarget, Vector3.yAxis)

	if distance < T.ZipArriveDistance or self.zipTime > T.ZipMaxTime then
		self:_finishZip(direction)
		return
	end
	-- Hit something on the way: stop early.
	if self.zipTime > 0.1 and (root.AssemblyLinearVelocity - self.lastCommanded).Magnitude > 40 then
		self:_finishZip(direction)
		return
	end

	local t = math.clamp(self.zipTime / T.ZipAccelTime, 0, 1)
	self.zipSpeed = self.zipStartSpeed + (T.ZipSpeed - self.zipStartSpeed) * t
	local v = direction * self.zipSpeed
	self.lastCommanded = v
	self.driver.VectorVelocity = v
end

function TrickController:_exitZip()
	local ctx = self.ctx
	self.driver.Enabled = false
	self.facing.Enabled = false
	self.visuals:Detach()
	self.motion.pivot = nil

	if self.zipExitVelocity then
		ctx.Root.AssemblyLinearVelocity = self.zipExitVelocity
	end
	ctx.Humanoid.AutoRotate = true
	if ctx:IsAlive() then
		ctx.Humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	end
	self.zipCooldownUntil = os.clock() + T.ZipCooldown
end

function TrickController:Destroy()
	if self.fsm:Is("Zip") then
		self.ctx.Humanoid.AutoRotate = true
		self.visuals:Detach()
	end
	self.motion.diving = false
	self.cleaner:Clean()
end

return TrickController
