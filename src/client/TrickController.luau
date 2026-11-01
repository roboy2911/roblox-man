-- Air tricks:
--   * Web zip (E / L1): shoots a web where the camera is aiming (with a little aim assist) and
--     yanks you to it, with a pop at the end to hop over ledges. Works from anywhere.
--   * Point launch: press jump right as a zip ends for a big launch.
--   * Double jump (jump in the air): a second jump with a flip. Recharges when you land,
--     swing, zip or wall run.
--   * Dive (hold Q / L2 in the air): fall faster and turn it into forward speed for the next web.
--   * Wall run: fly along a wall fast and you'll run on it. Jump to kick off.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Cleaner = require(ReplicatedStorage.Shared.Cleaner)
local Config = require(ReplicatedStorage.Shared.Config)
local MathUtil = require(ReplicatedStorage.Shared.MathUtil)

local T = Config.Tricks
local W = Config.WallRun
local flat = MathUtil.flat
local safeUnit = MathUtil.safeUnit
local projectOnPlane = MathUtil.projectOnPlane

local AIR_FLIPS = { "Front", "Barrel" }

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
		zipDirection = Vector3.zero,
		zipExitVelocity = nil :: Vector3?,
		zipEndTime = -math.huge,
		lastCommanded = Vector3.zero,

		jumpRequestTime = -math.huge,
		lastJumpSignal = -math.huge,
		airStart = 0,
		airJumpsLeft = T.AirJumps,

		wallNormal = Vector3.zero,
		wallStart = 0,
		wallVerticalSpeed = 0,
		wallExitVelocity = nil :: Vector3?,
		wallCooldownUntil = 0,
	}, TrickController)

	-- Constraints shared by the zip and wall run (same approach as swinging)
	local driver = Instance.new("LinearVelocity")
	driver.Name = "TrickDriver"
	driver.Attachment0 = ctx.RootAttachment
	driver.RelativeTo = Enum.ActuatorRelativeTo.World
	driver.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	driver.MaxForce = math.huge
	driver.Enabled = false
	driver.Parent = ctx.Root
	self.driver = self.cleaner:Add(driver)

	local facing = Instance.new("AlignOrientation")
	facing.Name = "TrickFacing"
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

	fsm:Register("WallRun", {
		Enter = function(_previous, normal: Vector3)
			self:_enterWallRun(normal)
		end,
		Exit = function()
			self:_exitWallRun()
		end,
		Update = function(dt: number)
			self:_updateWallRun(dt)
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

function TrickController:_flip(kind: string)
	self.motion.flipStart = os.clock()
	self.motion.flipKind = kind
end

-- Was jump pressed within `window` seconds of `time`?
function TrickController:_jumpNear(time: number, window: number): boolean
	return math.abs(self.jumpRequestTime - time) < window
end

function TrickController:_hook(dt: number)
	local fsm = self.fsm
	local ctx = self.ctx
	if not ctx:IsAlive() then
		return
	end

	-- Crosshair info for the HUD
	local zipTarget = self:_findZipTarget()
	self.motion.zipReady = zipTarget ~= nil and os.clock() >= self.zipCooldownUntil

	-- Web zip
	if self.zipRequested then
		self.zipRequested = false
		local canZip = fsm:Is("Ground") or fsm:Is("Air") or fsm:Is("Swing") or fsm:Is("WallRun")
		if canZip and os.clock() >= self.zipCooldownUntil and zipTarget then
			local hand = if (zipTarget - ctx.Root.Position):Dot(workspace.CurrentCamera.CFrame.RightVector) >= 0
				then "Right"
				else "Left"
			fsm:Set("Zip", zipTarget, hand)
			return
		end
	end

	if not fsm:Is("Air") then
		self.motion.diving = false
		return
	end

	-- Point launch: jump pressed right around the end of a zip
	local now = os.clock()
	if now - self.zipEndTime < T.PointLaunchWindow and self:_jumpNear(self.zipEndTime, T.PointLaunchWindow) then
		self.jumpRequestTime = -math.huge
		self.zipEndTime = -math.huge
		local forward = safeUnit(flat(self.zipDirection), safeUnit(flat(workspace.CurrentCamera.CFrame.LookVector), Vector3.zAxis))
		ctx.Root.AssemblyLinearVelocity = forward * T.PointLaunchForward + Vector3.new(0, T.PointLaunchUp, 0)
		self:_flip("Front")
		self.effects:AirJump()
		self.camera:Kick(8)
		self.camera:Shake(0.4)
		self.motion.events:Fire("PointLaunch")
		return
	end

	-- Double jump (only for presses made after we'd been airborne a moment)
	if
		self.airJumpsLeft > 0
		and self.jumpRequestTime > self.airStart + T.AirJumpMinAirTime
		and now - self.jumpRequestTime < 0.15
	then
		self.airJumpsLeft -= 1
		self.jumpRequestTime = -math.huge
		local v = ctx.Root.AssemblyLinearVelocity
		ctx.Root.AssemblyLinearVelocity = Vector3.new(v.X, T.AirJumpPower, v.Z)
		self:_flip(AIR_FLIPS[math.random(1, #AIR_FLIPS)])
		self.effects:AirJump()
		self.camera:Kick(3)
		self.motion.events:Fire("AirJump")
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
		return
	end

	-- Wall run: flying fast alongside a wall
	local normal = self:_findRunnableWall()
	if normal then
		fsm:Set("WallRun", normal)
	end
end

------------------------------------------------------------------------------------------------
-- Web zip

-- Where the camera is aiming, if it's a building within range. If the exact crosshair misses,
-- look in a small cone around it.
function TrickController:_findZipTarget(): Vector3?
	local camera = workspace.CurrentCamera
	local root = self.ctx.Root
	local cf = camera.CFrame
	local range = T.ZipRange + (cf.Position - root.Position).Magnitude

	local function try(direction: Vector3): Vector3?
		local result = workspace:Raycast(cf.Position, direction * range, self.ctx.SwingParams)
		if not result then
			return nil
		end
		local target = result.Position + result.Normal * 1.5
		if (target - root.Position).Magnitude < T.ZipArriveDistance + 2 then
			return nil
		end
		return target
	end

	local direct = try(cf.LookVector)
	if direct then
		return direct
	end
	local angle = math.rad(T.ZipAssistAngle)
	for i = 0, 7 do
		local around = i / 8 * math.pi * 2
		local dir = (cf * CFrame.Angles(math.sin(around) * angle, math.cos(around) * angle, 0)).LookVector
		local target = try(dir)
		if target then
			return target
		end
	end
	return nil
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
	self.zipDirection = toTarget.Unit
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
	self.motion.events:Fire("Zip")
end

function TrickController:_finishZip(direction: Vector3)
	self.zipDirection = direction
	self.zipExitVelocity = direction * self.zipSpeed * T.ZipExitCarry + Vector3.new(0, T.ZipEndPop, 0)
	self.zipEndTime = os.clock()
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
	self.visuals:Detach(true)
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

------------------------------------------------------------------------------------------------
-- Wall run

-- Returns the wall's normal if there's a wall right beside you that you're flying along.
function TrickController:_findRunnableWall(): Vector3?
	if os.clock() < self.wallCooldownUntil then
		return nil
	end
	local root = self.ctx.Root
	local v = root.AssemblyLinearVelocity
	local flatV = flat(v)
	local speed = flatV.Magnitude
	if speed < W.MinSpeed then
		return nil
	end
	local dir = flatV / speed
	local right = dir:Cross(Vector3.yAxis)
	for _, side in { right, -right } do
		local hit = workspace:Raycast(root.Position, side * W.CheckDistance, self.ctx.WorldParams)
		if hit and math.abs(hit.Normal.Y) < 0.3 then
			local normal = safeUnit(flat(hit.Normal), Vector3.zero)
			if math.abs(dir:Dot(normal)) < W.MaxAngle then
				return normal
			end
		end
	end
	return nil
end

function TrickController:_enterWallRun(normal: Vector3)
	local ctx = self.ctx
	self.wallNormal = normal
	self.wallStart = os.clock()
	self.wallVerticalSpeed = math.max(W.Lift, ctx.Root.AssemblyLinearVelocity.Y * 0.5)
	self.wallExitVelocity = nil
	self.jumpRequestTime = -math.huge

	ctx.Humanoid.AutoRotate = false
	ctx.Humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	self.driver.VectorVelocity = ctx.Root.AssemblyLinearVelocity
	self.driver.Enabled = true
	self.facing.Enabled = true
	self.motion.events:Fire("WallRun")
end

function TrickController:_updateWallRun(dt: number)
	local ctx = self.ctx
	local root = ctx.Root
	local pos = root.Position
	local now = os.clock()

	-- Wall jump
	if self.jumpRequestTime > self.wallStart + 0.1 then
		self.jumpRequestTime = -math.huge
		local along = flat(projectOnPlane(root.AssemblyLinearVelocity, self.wallNormal))
		self.wallExitVelocity = along * W.JumpForwardKeep
			+ self.wallNormal * W.JumpOut
			+ Vector3.new(0, W.JumpUp, 0)
		self:_flip("Barrel")
		self.effects:AirJump()
		self.camera:Kick(4)
		self.motion.events:Fire("WallJump")
		self.fsm:Set("Air")
		return
	end

	if ctx:IsGrounded() then
		self.fsm:Set("Ground")
		return
	end

	-- Still a wall beside us?
	local hit = workspace:Raycast(pos, -self.wallNormal * (W.CheckDistance + 1.5), ctx.WorldParams)
	if not hit or math.abs(hit.Normal.Y) > 0.3 or now - self.wallStart > W.Duration then
		self.fsm:Set("Air")
		return
	end
	local normal = safeUnit(flat(hit.Normal), self.wallNormal)
	self.wallNormal = normal

	local along = flat(projectOnPlane(root.AssemblyLinearVelocity, normal))
	local speed = along.Magnitude * math.exp(-W.Drag * dt)
	if speed < W.MinStaySpeed then
		self.fsm:Set("Air")
		return
	end
	local direction = along.Unit

	self.wallVerticalSpeed -= W.Gravity * dt
	local v = direction * speed + Vector3.new(0, self.wallVerticalSpeed, 0) - normal * W.Stick
	self.driver.VectorVelocity = v

	-- Face along the wall, leaning into it a little.
	local up = safeUnit(Vector3.yAxis - normal * 0.4, Vector3.yAxis)
	self.facing.CFrame = CFrame.lookAt(Vector3.zero, direction, up)

	-- Which side the wall is on, for the pose: 1 = right, -1 = left
	self.motion.wallSide = if normal:Dot(direction:Cross(Vector3.yAxis)) < 0 then 1 else -1
end

function TrickController:_exitWallRun()
	local ctx = self.ctx
	self.driver.Enabled = false
	self.facing.Enabled = false
	if self.wallExitVelocity then
		ctx.Root.AssemblyLinearVelocity = self.wallExitVelocity
	else
		-- Drop off the wall: keep the speed along it, minus the pull toward the wall.
		local v = ctx.Root.AssemblyLinearVelocity
		ctx.Root.AssemblyLinearVelocity = v + self.wallNormal * W.Stick
	end
	ctx.Humanoid.AutoRotate = true
	if ctx:IsAlive() then
		ctx.Humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	end
	self.wallCooldownUntil = os.clock() + W.Cooldown
end

function TrickController:Destroy()
	if self.fsm:Is("Zip") or self.fsm:Is("WallRun") then
		self.ctx.Humanoid.AutoRotate = true
		self.visuals:Detach()
	end
	self.motion.diving = false
	self.cleaner:Clean()
end

return TrickController
