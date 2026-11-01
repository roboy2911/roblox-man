-- Procedural poses, made in code so no animations need uploading.
--
-- Poses are applied by rotating each joint's fixed offset (C0 on classic Motor6D joints, or the
-- parent-side attachment on newer AnimationConstraint joints). Roblox's animations never touch
-- those, so they can't be overwritten. While a pose is active, the default animations
-- (like the falling one) are stopped so they don't fight it. Poses:
--   * Swing: the web arm reaches for the web. The rest of the body uses one of three styles,
--     picked per swing: Tuck (knees up at the bottom), Superman (legs straight back, free arm
--     forward) or Kick (one leg tucked, one kicked forward).
--   * Zip: web arm forward, body trailing.
--   * Wall run: running legs and pumping arms, leaning into the wall.
--   * Air: flips (front, back or barrel roll), a head-first dive, or a spread-out skydiving
--     pose when falling fast.
--   * Landing roll after a fast landing.
--   * The head looks where you're going whenever a pose is active.
--   * Punches (layered on top of whatever else is happening).
-- Also used to show other players' poses (see RemoteViews).
-- R15 only; on R6 this does nothing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Cleaner = require(ReplicatedStorage.Shared.Cleaner)
local Config = require(ReplicatedStorage.Shared.Config)
local MathUtil = require(ReplicatedStorage.Shared.MathUtil)

local P = Config.Pose
local T = Config.Tricks
local L = Config.Landing
local rad = math.rad

-- Joints we pose (looked up by name anywhere in the character)
local JOINTS = {
	RightShoulder = true,
	LeftShoulder = true,
	RightElbow = true,
	LeftElbow = true,
	RightHip = true,
	LeftHip = true,
	RightKnee = true,
	LeftKnee = true,
	Waist = true,
	Root = true,
	Neck = true,
}

local SIDES = { Right = 1, Left = -1 }
local DOWN = Vector3.new(0, -1, 0)

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Rotation that turns a limb hanging straight down to point along `dir` (in the torso's space).
local function aimFromDown(dir: Vector3): CFrame
	if dir.Magnitude < 1e-4 then
		return CFrame.identity
	end
	dir = dir.Unit
	local dot = math.clamp(DOWN:Dot(dir), -1, 1)
	local axis = DOWN:Cross(dir)
	if axis.Magnitude < 1e-4 then
		return if dot > 0 then CFrame.identity else CFrame.Angles(math.pi, 0, 0)
	end
	return CFrame.fromAxisAngle(axis.Unit, math.acos(dot))
end

type Joint = {
	instance: Instance,
	setOffset: (CFrame) -> (),
	base: CFrame,
}

-- Wraps a joint so poses work the same on both joint types.
local function makeJoint(instance: Instance): Joint?
	if instance:IsA("Motor6D") then
		local motor = instance
		return {
			instance = motor,
			base = motor.C0,
			setOffset = function(cf: CFrame)
				motor.C0 = cf
			end,
		}
	elseif instance:IsA("AnimationConstraint") then
		local attachment = instance.Attachment0
		if not attachment then
			return nil
		end
		return {
			instance = instance,
			base = attachment.CFrame,
			setOffset = function(cf: CFrame)
				attachment.CFrame = cf
			end,
		}
	end
	return nil
end

local PoseController = {}
PoseController.__index = PoseController

function PoseController.new(ctx, fsm, motion, quiet: boolean?)
	local self = setmetatable({
		ctx = ctx,
		fsm = fsm,
		motion = motion,
		joints = {} :: { [string]: Joint },
		current = {} :: { [string]: CFrame },
		weight = 0,
		posing = false, -- whether joints are currently changed from their defaults
		nextJointCheck = 0,
		time = 0,
		quiet = quiet == true,
		cleaner = Cleaner.new(),
	}, PoseController)

	if not ctx.IsR15 then
		if quiet then
			return self
		end
		warn(
			"[Web Creature] Your character is R6, so swing poses are turned off. "
				.. "In Studio go to Home > Game Settings > Avatar and set Avatar Type to R15."
		)
		return self
	end

	for jointName in JOINTS do
		self.current[jointName] = CFrame.identity
	end
	self:_findJoints(not self.quiet)
	self.animator = ctx.Humanoid:FindFirstChildOfClass("Animator")

	self.cleaner:Add(RunService.PreSimulation:Connect(function(dt)
		self:_update(dt)
	end))

	return self
end

------------------------------------------------------------------------------------------------
-- Joints

-- Finds every joint we pose, wherever it lives in the character.
function PoseController:_findJoints(report: boolean)
	local character = self.ctx.Character
	local found = {}
	for _, descendant in character:GetDescendants() do
		if JOINTS[descendant.Name] and not found[descendant.Name] then
			-- Skip the spider-leg gear; only the body's own joints.
			if not descendant:FindFirstAncestor("WebCreatureGear") then
				local joint = makeJoint(descendant)
				if joint then
					found[descendant.Name] = joint
				end
			end
		end
	end
	self.joints = found
	self.upperTorso = character:FindFirstChild("UpperTorso")

	if report then
		local count, kinds = 0, {}
		for _, joint in found do
			count += 1
			kinds[joint.instance.ClassName] = true
		end
		local kindList = {}
		for kind in kinds do
			table.insert(kindList, kind)
		end
		if count == 0 then
			warn("[Web Creature] Poses are off: couldn't find any body joints in the character.")
		else
			print(`[Web Creature] Poses ready: {count} joints ({table.concat(kindList, ", ")})`)
		end
	end
end

-- If Roblox rebuilt the body (e.g. while loading the avatar), find the new joints.
function PoseController:_checkJoints()
	local now = os.clock()
	if now < self.nextJointCheck then
		return
	end
	self.nextJointCheck = now + 0.5
	for _, joint in self.joints do
		if not joint.instance:IsDescendantOf(self.ctx.Character) then
			self:_findJoints(false)
			return
		end
	end
	if next(self.joints) == nil then
		self:_findJoints(false)
	end
end

------------------------------------------------------------------------------------------------
-- Timed moves

-- Progress (0..1) through a timed move that started at `start`, or nil if it isn't running.
local function progress(start: number?, duration: number): number?
	if not start then
		return nil
	end
	local p = (os.clock() - start) / duration
	if p < 0 or p >= 1 then
		return nil
	end
	return p
end

local function smoothstep(t: number): number
	return t * t * (3 - 2 * t)
end

-- The extra whole-body rotation for a flip or roll, if one is happening.
function PoseController:_spinRotation(): CFrame?
	local state = self.fsm.Current
	if state == "Air" then
		local p = progress(self.motion.flipStart, T.FlipTime)
		if p then
			local angle = math.pi * 2 * smoothstep(p)
			local kind = self.motion.flipKind
			if kind == "Back" then
				return CFrame.Angles(angle, 0, 0)
			elseif kind == "Barrel" then
				return CFrame.Angles(0, 0, angle)
			end
			return CFrame.Angles(-angle, 0, 0) -- front flip
		end
	elseif state == "Ground" then
		local p = progress(self.motion.rollStart, L.RollTime)
		if p then
			return CFrame.Angles(-math.pi * 2 * smoothstep(p), 0, 0)
		end
	end
	return nil
end

------------------------------------------------------------------------------------------------
-- Poses

local function tuckPose(t: { [string]: CFrame })
	for side, s in SIDES do
		t[side .. "Shoulder"] = CFrame.Angles(rad(70), 0, s * rad(10))
		t[side .. "Elbow"] = CFrame.Angles(rad(100), 0, 0)
		t[side .. "Hip"] = CFrame.Angles(rad(100), 0, s * rad(5))
		t[side .. "Knee"] = CFrame.Angles(rad(-130), 0, 0)
	end
end

-- Head turns to look where you're going (limited so it never looks backwards).
function PoseController:_headLook(t: { [string]: CFrame })
	local torso = self.upperTorso
	if not torso then
		return
	end
	local v = self.ctx.Root.AssemblyLinearVelocity
	if v.Magnitude < 10 then
		return
	end
	local dir = torso.CFrame:VectorToObjectSpace(v.Unit)
	local yaw = math.clamp(math.atan2(-dir.X, -dir.Z), rad(-50), rad(50))
	local pitch = math.clamp(math.asin(math.clamp(dir.Y, -1, 1)), rad(-40), rad(30))
	t.Neck = CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
end

function PoseController:_swingPose(t: { [string]: CFrame }, zipping: boolean)
	local m = self.motion
	local webSide = m.webHand or "Right"
	local otherSide = if webSide == "Right" then "Left" else "Right"
	local o = SIDES[otherSide]

	-- Web arm reaches straight for the web.
	if m.pivot and self.upperTorso then
		local torso = self.upperTorso
		t[webSide .. "Shoulder"] = aimFromDown(torso.CFrame:VectorToObjectSpace(m.pivot - torso.Position))
	end
	t[webSide .. "Elbow"] = CFrame.identity

	if zipping then
		t[otherSide .. "Shoulder"] = CFrame.Angles(rad(-35), 0, o * rad(20))
		t[otherSide .. "Elbow"] = CFrame.Angles(rad(30), 0, 0)
		for side, s in SIDES do
			t[side .. "Hip"] = CFrame.Angles(rad(-25), 0, s * rad(5))
			t[side .. "Knee"] = CFrame.Angles(rad(-50), 0, 0)
		end
		return
	end

	-- 0 at the top of the arc, 1 at the bottom
	local bottom = (m.lowness or 0) ^ 2
	local style = m.swingStyle or "Tuck"

	if style == "Superman" then
		-- Free arm stretched forward, legs straight back.
		t[otherSide .. "Shoulder"] = CFrame.Angles(rad(lerp(120, 160, bottom)), 0, o * rad(15))
		t[otherSide .. "Elbow"] = CFrame.Angles(rad(10), 0, 0)
		for side, s in SIDES do
			t[side .. "Hip"] = CFrame.Angles(rad(lerp(-10, -30, bottom)), 0, s * rad(6))
			t[side .. "Knee"] = CFrame.Angles(rad(lerp(-30, -10, bottom)), 0, 0)
		end
		t.Waist = CFrame.Angles(rad(lerp(0, -12, bottom)), 0, 0)
	elseif style == "Kick" then
		-- Leg on the web side tucked, the other kicking forward through the bottom.
		t[otherSide .. "Shoulder"] = CFrame.Angles(rad(lerp(10, 40, bottom)), 0, o * rad(lerp(70, 40, bottom)))
		t[otherSide .. "Elbow"] = CFrame.Angles(rad(40), 0, 0)
		t[webSide .. "Hip"] = CFrame.Angles(rad(lerp(40, 100, bottom)), 0, 0)
		t[webSide .. "Knee"] = CFrame.Angles(rad(lerp(-60, -120, bottom)), 0, 0)
		t[otherSide .. "Hip"] = CFrame.Angles(rad(lerp(-15, 70, bottom)), 0, o * rad(8))
		t[otherSide .. "Knee"] = CFrame.Angles(rad(lerp(-40, -5, bottom)), 0, 0)
		t.Waist = CFrame.Angles(rad(lerp(-5, 10, bottom)), 0, 0)
	else
		-- Tuck through the bottom of the arc, stretch out at the top.
		t[otherSide .. "Shoulder"] = CFrame.Angles(rad(lerp(20, 60, bottom)), 0, o * rad(lerp(55, 25, bottom)))
		t[otherSide .. "Elbow"] = CFrame.Angles(rad(lerp(20, 90, bottom)), 0, 0)
		for side, s in SIDES do
			t[side .. "Hip"] = CFrame.Angles(rad(lerp(-20, 75, bottom)), 0, s * rad(lerp(12, 4, bottom)))
			t[side .. "Knee"] = CFrame.Angles(rad(-lerp(25, 110, bottom)), 0, 0)
		end
		t.Waist = CFrame.Angles(rad(lerp(-8, 12, bottom)), 0, 0)
	end
end

function PoseController:_wallRunPose(t: { [string]: CFrame })
	local phase = self.time * 14
	local wallSide = self.motion.wallSide or 1
	for side, s in SIDES do
		local swing = math.sin(phase + (if s > 0 then 0 else math.pi))
		t[side .. "Hip"] = CFrame.Angles(rad(30 + swing * 45), 0, 0)
		t[side .. "Knee"] = CFrame.Angles(rad(-50 + swing * 35), 0, 0)
		t[side .. "Shoulder"] = CFrame.Angles(rad(-swing * 50), 0, s * rad(15))
		t[side .. "Elbow"] = CFrame.Angles(rad(70), 0, 0)
	end
	-- Hand nearest the wall reaches out toward it.
	local wallArm = if wallSide > 0 then "Right" else "Left"
	t[wallArm .. "Shoulder"] = CFrame.Angles(rad(20), 0, wallSide * rad(80))
	t[wallArm .. "Elbow"] = CFrame.Angles(rad(20), 0, 0)
	t.Waist = CFrame.Angles(rad(10), 0, 0)
end

-- Returns the target pose and how strongly to apply it (0..1).
function PoseController:_targets(): ({ [string]: CFrame }, number)
	local t = {}
	local state = self.fsm.Current

	if state == "Swing" or state == "Zip" then
		self:_swingPose(t, state == "Zip")
		self:_headLook(t)
		return t, 1
	end

	if state == "WallRun" then
		self:_wallRunPose(t)
		self:_headLook(t)
		return t, 1
	end

	if state == "Air" then
		if progress(self.motion.flipStart, T.FlipTime) then
			tuckPose(t)
			return t, 1
		end

		if self.motion.diving then
			-- Head first, arms swept back
			t.Root = CFrame.Angles(rad(-65), 0, 0)
			for side, s in SIDES do
				t[side .. "Shoulder"] = CFrame.Angles(rad(-25), 0, s * rad(15))
				t[side .. "Hip"] = CFrame.Angles(rad(-8), 0, s * rad(3))
				t[side .. "Knee"] = CFrame.Angles(rad(-10), 0, 0)
			end
			t.Neck = CFrame.Angles(rad(35), 0, 0) -- look ahead, not at the ground
			return t, 1
		end

		-- Skydiving spread, stronger the faster you're going
		local speed = self.ctx.Root.AssemblyLinearVelocity.Magnitude
		local strength = MathUtil.remapClamped(speed, P.FallPoseMinSpeed, P.FallPoseMaxSpeed, 0, 1)
		for side, s in SIDES do
			t[side .. "Shoulder"] = CFrame.Angles(rad(15), 0, s * rad(lerp(55, 80, strength)))
			t[side .. "Elbow"] = CFrame.Angles(rad(25), 0, 0)
			t[side .. "Hip"] = CFrame.Angles(rad(-10), 0, s * rad(14))
			t[side .. "Knee"] = CFrame.Angles(rad(-35), 0, 0)
		end
		self:_headLook(t)
		return t, strength
	end

	if state == "Ground" and progress(self.motion.rollStart, L.RollTime) then
		tuckPose(t)
		return t, 1
	end

	return t, 0
end

------------------------------------------------------------------------------------------------
-- Applying

-- Stops Roblox's default animations while we're posing, so they don't fight our pose.
-- The default Animate script starts the right ones again when you land.
function PoseController:_stopDefaultAnimations()
	local animator = self.animator
	if not animator or not animator.Parent then
		animator = self.ctx.Humanoid:FindFirstChildOfClass("Animator")
		self.animator = animator
	end
	if not animator then
		return
	end
	for _, track in animator:GetPlayingAnimationTracks() do
		track:Stop(0.15)
	end
end

function PoseController:_restore()
	for _, joint in self.joints do
		if joint.instance.Parent then
			joint.setOffset(joint.base)
		end
	end
	self.posing = false
end

-- Throws the punching arm out and back, with the other arm up in a guard.
function PoseController:_punchOverlay(t: { [string]: CFrame }): boolean
	local p = progress(self.motion.punchStart, P.PunchTime)
	if not p then
		return false
	end
	local hand = self.motion.punchHand or "Right"
	local other = if hand == "Right" then "Left" else "Right"
	local extend = math.sin(p * math.pi) -- 0 -> 1 -> 0
	t[hand .. "Shoulder"] = CFrame.Angles(rad(lerp(40, 95, extend)), 0, 0)
	t[hand .. "Elbow"] = CFrame.Angles(rad(lerp(100, 0, extend)), 0, 0)
	t[other .. "Shoulder"] = CFrame.Angles(rad(60), 0, 0)
	t[other .. "Elbow"] = CFrame.Angles(rad(110), 0, 0)
	t.Waist = CFrame.Angles(0, (if hand == "Right" then 1 else -1) * rad(25) * extend, 0)
	return true
end

function PoseController:_update(dt: number)
	self.time += dt
	self:_checkJoints()
	local targets, targetWeight = self:_targets()
	local punching = self:_punchOverlay(targets)
	local alpha = MathUtil.expAlpha(if punching then 30 else P.Blend, dt)
	if punching then
		-- Punches are quick, so show them at full strength right away.
		self.weight = 1
	else
		self.weight += (targetWeight - self.weight) * MathUtil.expAlpha(P.WeightBlend, dt)
	end

	local spin = self:_spinRotation()

	for name, current in self.current do
		self.current[name] = current:Lerp(targets[name] or CFrame.identity, alpha)
	end

	if self.weight < 0.01 and not spin then
		if self.posing then
			self:_restore()
		end
		return
	end

	local rolling = self.fsm:Is("Ground") and spin ~= nil
	if self.weight > 0.3 and (rolling or not self.fsm:Is("Ground")) then
		self:_stopDefaultAnimations()
	end

	self.posing = true
	for name, joint in self.joints do
		local pose = CFrame.identity:Lerp(self.current[name], self.weight)
		if name == "Root" and spin then
			pose *= spin
		end
		joint.setOffset(joint.base * pose)
	end
end

function PoseController:Destroy()
	self.cleaner:Clean()
	if self.posing then
		self:_restore()
	end
end

return PoseController
