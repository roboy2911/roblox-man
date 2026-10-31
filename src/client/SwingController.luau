-- Web swinging.
--
-- How it works:
--   1. While the Swing button is held, we scan a cone of rays above and ahead of you and pick the
--      building point closest to an "ideal" anchor spot. You never have to aim precisely.
--   2. While swinging we run our own pendulum: gravity + steering + a "pump" at the bottom of the
--      arc, then the web stops you moving further away than its length. The result is fed to a
--      LinearVelocity on the root part, so we control the feel exactly.
--   3. Letting go keeps all your speed and adds a boost. Letting go while rising past the bottom
--      of the arc is a "perfect release" with a bigger boost and camera kick.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cleaner = require(ReplicatedStorage.Shared.Cleaner)
local Config = require(ReplicatedStorage.Shared.Config)
local MathUtil = require(ReplicatedStorage.Shared.MathUtil)

local S = Config.Swing
local flat = MathUtil.flat
local safeUnit = MathUtil.safeUnit
local projectOnPlane = MathUtil.projectOnPlane

local SwingController = {}
SwingController.__index = SwingController

function SwingController.new(ctx, fsm, input, camera, visuals)
	local self = setmetatable({
		ctx = ctx,
		fsm = fsm,
		input = input,
		camera = camera,
		visuals = visuals,
		cleaner = Cleaner.new(),

		anchor = Vector3.zero,
		ropeLength = 0,
		maxLength = math.huge,
		velocity = Vector3.zero,
		lastCommanded = Vector3.zero,
		releaseVelocity = nil :: Vector3?,
		perfectRelease = false,
		cooldownUntil = 0,
	}, SwingController)

	local driver = Instance.new("LinearVelocity")
	driver.Name = "SwingDriver"
	driver.Attachment0 = ctx.RootAttachment
	driver.RelativeTo = Enum.ActuatorRelativeTo.World
	driver.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	driver.MaxForce = math.huge
	driver.Enabled = false
	driver.Parent = ctx.Root
	self.driver = self.cleaner:Add(driver)

	local lean = Instance.new("AlignOrientation")
	lean.Name = "SwingLean"
	lean.Mode = Enum.OrientationAlignmentMode.OneAttachment
	lean.Attachment0 = ctx.RootAttachment
	lean.MaxTorque = math.huge
	lean.Responsiveness = S.TurnResponsiveness
	lean.Enabled = false
	lean.Parent = ctx.Root
	self.lean = self.cleaner:Add(lean)

	fsm:Register("Swing", {
		Enter = function(_previous, anchor: Vector3)
			self:_enter(anchor)
		end,
		Exit = function(nextState: string)
			self:_exit(nextState)
		end,
		Update = function(dt: number)
			self:_update(dt)
		end,
	})

	-- Holding the button while not swinging keeps looking for an anchor, so you can hold it
	-- while falling and the web fires the moment a building comes in range.
	fsm:AddHook(function()
		if fsm:Is("Swing") or not input:IsDown("Swing") then
			return
		end
		if os.clock() < self.cooldownUntil or not ctx:IsAlive() then
			return
		end
		local anchor = self:_findAnchor()
		if anchor then
			fsm:Set("Swing", anchor)
		end
	end)

	return self
end

-- Which way the player wants to go: mostly where the camera looks, nudged toward current motion.
function SwingController:_heading(): Vector3
	local root = self.ctx.Root
	local cam = workspace.CurrentCamera
	local look = flat(cam.CFrame.LookVector)
	local heading = safeUnit(look, safeUnit(flat(root.CFrame.LookVector), Vector3.zAxis))
	local velocity = flat(root.AssemblyLinearVelocity)
	if velocity.Magnitude > 25 then
		heading = safeUnit(heading * 0.6 + velocity.Unit * 0.4, heading)
	end
	return heading
end

function SwingController:_findAnchor(): Vector3?
	local pos = self.ctx.Root.Position
	local heading = self:_heading()
	local basis = CFrame.lookAt(Vector3.zero, heading)
	local ideal = pos + heading * S.IdealForward + Vector3.yAxis * S.IdealUp

	local best: Vector3? = nil
	local bestScore = -math.huge

	for _, yaw in S.SearchYaw do
		for _, pitch in S.SearchPitch do
			local dir = (basis * CFrame.Angles(0, math.rad(yaw), 0) * CFrame.Angles(math.rad(pitch), 0, 0)).LookVector
			local result = workspace:Raycast(pos, dir * S.MaxWebLength, self.ctx.SwingParams)
			if result then
				-- Stick slightly out from the surface so the web doesn't clip into the wall.
				local point = result.Position + result.Normal * 0.2
				local rel = point - pos
				if
					rel.Magnitude >= S.MinWebLength
					and rel.Y >= S.MinAnchorHeight
					and flat(rel):Dot(heading) > 0
				then
					local score = -(point - ideal).Magnitude
					if score > bestScore then
						best, bestScore = point, score
					end
				end
			end
		end
	end

	return best
end

-- Height of whatever is under the player (or very low if nothing is).
function SwingController:_floorHeight(pos: Vector3): number
	local result = workspace:Raycast(pos, Vector3.new(0, -1000, 0), self.ctx.WorldParams)
	return if result then result.Position.Y else pos.Y - 1000
end

function SwingController:_enter(anchor: Vector3)
	local ctx = self.ctx
	local root = ctx.Root
	local humanoid = ctx.Humanoid
	local pos = root.Position
	local velocity = root.AssemblyLinearVelocity

	self.anchor = anchor
	self.releaseVelocity = nil
	self.perfectRelease = false

	-- Start the web a bit shorter than the real distance, so it yanks you on connect.
	local distance = (anchor - pos).Magnitude
	self.ropeLength = math.max(distance * S.InitialSnap, S.MinRopeLength)
	-- The web will reel in if needed so the bottom of the arc stays above the floor.
	self.maxLength = math.max(anchor.Y - (self:_floorHeight(pos) + S.GroundClearance), S.MinRopeLength)

	if ctx:IsGrounded() then
		velocity += Vector3.new(0, S.GroundLaunchSpeed, 0)
	end

	-- Small push in the direction you're heading, so even a standing start swings.
	local ropeDir = (anchor - pos).Unit
	local kick = projectOnPlane(self:_heading(), ropeDir)
	velocity += safeUnit(kick, Vector3.zero) * S.AttachKick

	self.velocity = velocity
	self.lastCommanded = velocity

	humanoid.AutoRotate = false
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)

	self.driver.VectorVelocity = velocity
	self.driver.Enabled = true
	self.lean.CFrame = root.CFrame.Rotation
	self.lean.Enabled = true

	self.visuals:Attach(anchor)
	self.camera:Kick(Config.Camera.AttachKick)
end

function SwingController:_update(dt: number)
	local ctx = self.ctx
	local root = ctx.Root

	if not self.input:IsDown("Swing") then
		self:_release()
		return
	end

	local pos = root.Position

	-- If the real velocity is far from what we asked for, we hit something: trust reality.
	local actual = root.AssemblyLinearVelocity
	if (actual - self.lastCommanded).Magnitude > S.CollisionTolerance then
		self.velocity = actual
	end
	local v = self.velocity

	-- Reel in to keep the bottom of the arc off the ground.
	if self.ropeLength > self.maxLength then
		self.ropeLength = math.max(self.maxLength, self.ropeLength - S.ReelSpeed * dt)
	end

	-- Gravity
	v += Vector3.new(0, -S.Gravity * dt, 0)

	local toAnchor = self.anchor - pos
	local distance = toAnchor.Magnitude
	if distance < 0.01 then
		self:_release()
		return
	end
	local ropeDir = toAnchor / distance -- points from you to the anchor

	-- Steering: movement keys push you sideways across the arc.
	local move = ctx.Humanoid.MoveDirection
	if move.Magnitude > 0.05 then
		v += projectOnPlane(move, ropeDir) * S.SteerAccel * dt
	end

	-- Pump: speed up through the bottom of the arc, but only when swinging the way you're facing.
	local tangent = projectOnPlane(v, ropeDir)
	local lowness = math.clamp(ropeDir.Y, 0, 1) -- 1 when hanging straight down
	if tangent.Magnitude > 1 and flat(tangent):Dot(self:_heading()) > 0 then
		v += tangent.Unit * S.PumpAccel * lowness * lowness * dt
	end

	-- The web: you can't move further away than its length.
	local correction = Vector3.zero
	if distance > self.ropeLength then
		local radial = v:Dot(ropeDir) -- positive = moving toward anchor
		if radial < 0 then
			v -= ropeDir * radial
		end
		local stretch = distance - self.ropeLength
		correction = ropeDir * math.min(stretch * S.RopeStiffness, S.MaxCorrectionSpeed)
	end

	-- Soft speed cap
	local speed = v.Magnitude
	if speed > S.MaxSpeed then
		v = v.Unit * (speed + (S.MaxSpeed - speed) * MathUtil.expAlpha(4, dt))
	end

	self.velocity = v
	local commanded = v + correction
	self.lastCommanded = commanded
	self.driver.VectorVelocity = commanded

	-- Lean into the web: body "up" points at the anchor, facing the direction of travel.
	local forward = projectOnPlane(v, ropeDir)
	if forward.Magnitude < 2 then
		forward = projectOnPlane(self:_heading(), ropeDir)
	end
	if forward.Magnitude > 1e-3 then
		self.lean.CFrame = CFrame.lookAt(Vector3.zero, forward.Unit, ropeDir)
	end

	-- Touching down ends the swing.
	if v.Y < 0 then
		local hit = workspace:Raycast(pos, Vector3.new(0, -S.LandCheckDistance, 0), ctx.WorldParams)
		if hit then
			self.fsm:Set("Air")
		end
	end
end

function SwingController:_release()
	local v = self.velocity
	local pos = self.ctx.Root.Position

	-- "Perfect" = rising and already past the anchor, i.e. at the front of the arc.
	local pastAnchor = flat(pos - self.anchor):Dot(flat(v)) > 0
	local perfect = v.Y > S.PerfectMinUpSpeed and pastAnchor

	local forwardBoost = S.ReleaseForwardBoost
	local upBoost = S.ReleaseUpBoost
	if perfect then
		forwardBoost *= S.PerfectMultiplier
		upBoost *= S.PerfectMultiplier
	end

	local forward = safeUnit(flat(v), Vector3.zero)
	v += forward * forwardBoost + Vector3.new(0, upBoost, 0)

	self.releaseVelocity = MathUtil.clampMagnitude(v, S.MaxReleaseSpeed)
	self.perfectRelease = perfect
	self.fsm:Set("Air")
end

function SwingController:_exit(_nextState: string)
	local ctx = self.ctx
	local humanoid = ctx.Humanoid

	self.driver.Enabled = false
	self.lean.Enabled = false
	self.visuals:Detach()

	local finalVelocity = self.releaseVelocity or self.velocity
	ctx.Root.AssemblyLinearVelocity = finalVelocity

	humanoid.AutoRotate = true
	if ctx:IsAlive() then
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	end

	if self.releaseVelocity then
		local C = Config.Camera
		self.camera:Kick(if self.perfectRelease then C.PerfectKick else C.ReleaseKick)
	end

	self.cooldownUntil = os.clock() + S.ReattachCooldown
end

function SwingController:Destroy()
	if self.fsm:Is("Swing") then
		self.ctx.Humanoid.AutoRotate = true
		self.visuals:Detach()
	end
	self.cleaner:Clean()
end

return SwingController
