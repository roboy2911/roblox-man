-- Animates the thugs in code (no uploaded animations): a walk cycle based on how fast they
-- move, a boxing stance when standing, and a punch when the server says they attacked.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MathUtil = require(ReplicatedStorage.Shared.MathUtil)
local JointUtil = require(script.Parent.JointUtil)

local rad = math.rad

local NAMES = {
	RightShoulder = true,
	LeftShoulder = true,
	RightElbow = true,
	LeftElbow = true,
	RightHip = true,
	LeftHip = true,
	RightKnee = true,
	LeftKnee = true,
	Waist = true,
}

type Npc = {
	model: Model,
	root: BasePart,
	humanoid: Humanoid,
	joints: { [string]: JointUtil.Joint },
	phase: number,
	walk: number,
}

local NPCAnimator = {}

local npcs: { [Model]: Npc } = {}

local function track(model: Model)
	if npcs[model] then
		return
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid then
		return
	end
	local joints = JointUtil.find(model, NAMES)
	if next(joints) == nil then
		return
	end
	npcs[model] = { model = model, root = root, humanoid = humanoid, joints = joints, phase = 0, walk = 0 }
end

local function update(dt: number)
	local serverNow = workspace:GetServerTimeNow()
	for model, npc in npcs do
		if not model.Parent or npc.humanoid.Health <= 0 or model:GetAttribute("Down") then
			npcs[model] = nil
			continue
		end
		local speed = MathUtil.flat(npc.root.AssemblyLinearVelocity).Magnitude
		npc.walk += (MathUtil.remapClamped(speed, 1, 12, 0, 1) - npc.walk) * MathUtil.expAlpha(8, dt)
		npc.phase += dt * (4 + speed * 0.5)
		local swing = math.sin(npc.phase)
		local walk = npc.walk
		local stance = 1 - walk

		local pose: { [string]: CFrame } = {}
		for side, s in { Right = 1, Left = -1 } do
			local legSwing = swing * s
			pose[side .. "Hip"] = CFrame.Angles(rad(legSwing * 35 * walk), 0, 0)
			pose[side .. "Knee"] = CFrame.Angles(rad(-math.max(0, -legSwing) * 45 * walk - 10 * stance), 0, 0)
			-- Arms swing while walking, fists up while standing
			pose[side .. "Shoulder"] = CFrame.Angles(rad(-legSwing * 30 * walk + 45 * stance), 0, 0)
			pose[side .. "Elbow"] = CFrame.Angles(rad(20 * walk + 100 * stance), 0, 0)
		end
		pose.Waist = CFrame.Angles(0, rad(math.sin(npc.phase * 0.5) * 4 * stance), 0)

		-- Punch
		local attackAge = serverNow - (model:GetAttribute("AttackTime") or 0)
		if attackAge >= 0 and attackAge < 0.3 then
			local extend = math.sin(attackAge / 0.3 * math.pi)
			pose.RightShoulder = CFrame.Angles(rad(45 + 50 * extend), 0, 0)
			pose.RightElbow = CFrame.Angles(rad(100 * (1 - extend)), 0, 0)
			pose.Waist = CFrame.Angles(0, rad(25 * extend), 0)
		end

		for name, joint in npc.joints do
			if joint.instance.Parent then
				joint.set(pose[name] or CFrame.identity)
			end
		end
	end
end

function NPCAnimator.Start()
	local crimes = workspace:WaitForChild("Crimes")
	local function consider(instance: Instance)
		if instance:IsA("Model") and instance:GetAttribute("Thug") then
			-- Body parts may still be arriving, so give it a moment.
			task.delay(0.5, track, instance)
		end
	end
	for _, descendant in crimes:GetDescendants() do
		consider(descendant)
	end
	crimes.DescendantAdded:Connect(consider)
	RunService.PreSimulation:Connect(update)
end

return NPCAnimator
