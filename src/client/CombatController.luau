-- Punching (F / X / "Punch" button). Plays the punch pose and sound right away, lunges you a
-- little toward a thug in front of you, and tells the server, which decides what got hit.
-- Punch while moving fast (swinging in) to knock a thug out in one hit.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cleaner = require(ReplicatedStorage.Shared.Cleaner)
local Config = require(ReplicatedStorage.Shared.Config)
local MathUtil = require(ReplicatedStorage.Shared.MathUtil)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local CB = Config.Combat
local flat = MathUtil.flat

local CombatController = {}
CombatController.__index = CombatController

function CombatController.new(ctx, input, camera, effects, motion)
	local self = setmetatable({
		ctx = ctx,
		camera = camera,
		effects = effects,
		motion = motion,
		lastPunch = 0,
		nextHand = "Right",
		cleaner = Cleaner.new(),
	}, CombatController)

	self.cleaner:Add(input.ActionBegan:Connect(function(action: string)
		if action == "Punch" then
			self:_punch()
		end
	end))

	return self
end

-- The nearest standing thug in front of you, within `range`.
function CombatController:_thugInFront(range: number): BasePart?
	local crimes = workspace:FindFirstChild("Crimes")
	if not crimes then
		return nil
	end
	local root = self.ctx.Root
	local look = MathUtil.safeUnit(flat(root.CFrame.LookVector), Vector3.zAxis)
	local best, bestDistance = nil, range
	for _, model in crimes:GetDescendants() do
		if model:IsA("Model") and model:GetAttribute("Thug") and not model:GetAttribute("Down") then
			local thugRoot = model:FindFirstChild("HumanoidRootPart")
			if thugRoot and thugRoot:IsA("BasePart") then
				local offset = thugRoot.Position - root.Position
				local distance = offset.Magnitude
				if distance < bestDistance and look:Dot(MathUtil.safeUnit(flat(offset), look)) > 0.3 then
					best, bestDistance = thugRoot, distance
				end
			end
		end
	end
	return best
end

function CombatController:_punch()
	local now = os.clock()
	if now - self.lastPunch < CB.PunchCooldown or not self.ctx:IsAlive() then
		return
	end
	self.lastPunch = now

	self.motion.punchStart = now
	self.motion.punchHand = self.nextHand
	self.nextHand = if self.nextHand == "Right" then "Left" else "Right"
	self.effects:Punch()

	-- Step into the punch.
	local target = self:_thugInFront(CB.LungeRange)
	if target then
		local root = self.ctx.Root
		local direction = MathUtil.safeUnit(flat(target.Position - root.Position), Vector3.zero)
		root.AssemblyLinearVelocity += direction * CB.LungeSpeed
	end

	Remotes.Event("Punch"):FireServer()
end

function CombatController:Destroy()
	self.cleaner:Clean()
end

return CombatController
