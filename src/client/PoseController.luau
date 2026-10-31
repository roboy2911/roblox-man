-- Procedural poses, made in code so no animations need uploading.
--
-- Roblox's Animator sets each joint's Motor6D.Transform every frame. We run just after it
-- (PreSimulation) and blend our own pose on top:
--   * Swing: the web arm reaches for the web, the other arm and legs tuck at the bottom of the
--     arc and stretch out at the top.
--   * Zip: web arm forward, body trailing.
--   * Air: a front flip after a double jump or perfect release, a head-first dive, or a
--     spread-out skydiving pose when falling fast.
-- R15 only; on R6 this does nothing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Cleaner = require(ReplicatedStorage.Shared.Cleaner)
local Config = require(ReplicatedStorage.Shared.Config)
local MathUtil = require(ReplicatedStorage.Shared.MathUtil)

local P = Config.Pose
local T = Config.Tricks
local rad = math.rad

-- joint name -> the part that holds it
local JOINTS = {
	RightShoulder = "RightUpperArm",
	LeftShoulder = "LeftUpperArm",
	RightElbow = "RightLowerArm",
	LeftElbow = "LeftLowerArm",
	RightHip = "RightUpperLeg",
	LeftHip = "LeftUpperLeg",
	RightKnee = "RightLowerLeg",
	LeftKnee = "LeftLowerLeg",
	Waist = "UpperTorso",
	Root = "LowerTorso",
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

local PoseController = {}
PoseController.__index = PoseController

function PoseController.new(ctx, fsm, motion)
	local self = setmetatable({
		ctx = ctx,
		fsm = fsm,
		motion = motion,
		motors = {} :: { [string]: Motor6D },
		current = {} :: { [string]: CFrame },
		weight = 0,
		cleaner = Cleaner.new(),
	}, PoseController)

	if not ctx.IsR15 then
		return self
	end

	for jointName, partName in JOINTS do
		local part = ctx.Character:FindFirstChild(partName)
		local motor = part and part:FindFirstChild(jointName)
		if motor and motor:IsA("Motor6D") then
			self.motors[jointName] = motor
			self.current[jointName] = CFrame.identity
		end
	end
	self.upperTorso = ctx.Character:FindFirstChild("UpperTorso")

	self.cleaner:Add(RunService.PreSimulation:Connect(function(dt)
		self:_update(dt)
	end))

	return self
end

-- Progress through a flip (0..1), or nil if not flipping.
function PoseController:_flipProgress(): number?
	local start = self.motion.flipStart
	if not start then
		return nil
	end
	local p = (os.clock() - start) / T.FlipTime
	if p < 0 or p >= 1 then
		return nil
	end
	return p
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

	-- Tuck through the bottom of the arc, stretch out at the top.
	local tuck = (m.lowness or 0) ^ 2
	t[otherSide .. "Shoulder"] = CFrame.Angles(rad(lerp(20, 60, tuck)), 0, o * rad(lerp(55, 25, tuck)))
	t[otherSide .. "Elbow"] = CFrame.Angles(rad(lerp(20, 90, tuck)), 0, 0)
	for side, s in SIDES do
		t[side .. "Hip"] = CFrame.Angles(rad(lerp(-20, 75, tuck)), 0, s * rad(lerp(12, 4, tuck)))
		t[side .. "Knee"] = CFrame.Angles(rad(-lerp(25, 110, tuck)), 0, 0)
	end
	t.Waist = CFrame.Angles(rad(lerp(-8, 12, tuck)), 0, 0)
end

-- Returns the target pose and how strongly to apply it (0..1).
function PoseController:_targets(): ({ [string]: CFrame }, number)
	local t = {}
	local state = self.fsm.Current

	if state == "Swing" or state == "Zip" then
		self:_swingPose(t, state == "Zip")
		return t, 1
	end

	if state == "Air" then
		if self:_flipProgress() then
			-- Tight tuck while flipping
			for side, s in SIDES do
				t[side .. "Shoulder"] = CFrame.Angles(rad(70), 0, s * rad(10))
				t[side .. "Elbow"] = CFrame.Angles(rad(100), 0, 0)
				t[side .. "Hip"] = CFrame.Angles(rad(100), 0, s * rad(5))
				t[side .. "Knee"] = CFrame.Angles(rad(-130), 0, 0)
			end
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
			return t, 1
		end

		-- Skydiving spread, stronger the faster you're going
		local speed = self.ctx.Root.AssemblyLinearVelocity.Magnitude
		local strength = MathUtil.remapClamped(speed, P.FallPoseMinSpeed, P.FallPoseMaxSpeed, 0, 1)
		for side, s in SIDES do
			t[side .. "Shoulder"] = CFrame.Angles(rad(15), 0, s * rad(75))
			t[side .. "Elbow"] = CFrame.Angles(rad(25), 0, 0)
			t[side .. "Hip"] = CFrame.Angles(rad(-10), 0, s * rad(14))
			t[side .. "Knee"] = CFrame.Angles(rad(-35), 0, 0)
		end
		return t, strength
	end

	return t, 0
end

function PoseController:_update(dt: number)
	local targets, targetWeight = self:_targets()
	local alpha = MathUtil.expAlpha(P.Blend, dt)
	self.weight += (targetWeight - self.weight) * MathUtil.expAlpha(P.WeightBlend, dt)

	local flip = self:_flipProgress()
	local flipRotation = nil
	if flip and self.fsm:Is("Air") then
		local eased = flip * flip * (3 - 2 * flip) -- smoothstep
		flipRotation = CFrame.Angles(-math.pi * 2 * eased, 0, 0) -- negative X = forward flip
	end

	for name, motor in self.motors do
		local pose = self.current[name]:Lerp(targets[name] or CFrame.identity, alpha)
		self.current[name] = pose
		if self.weight > 0.01 then
			motor.Transform = motor.Transform:Lerp(pose, self.weight)
		end
		if name == "Root" and flipRotation then
			motor.Transform *= flipRotation
		end
	end
end

function PoseController:Destroy()
	self.cleaner:Clean()
end

return PoseController
