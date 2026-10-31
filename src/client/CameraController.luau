-- Widens the field of view as you go faster, adds short FOV "kicks" when a web connects or
-- you let go, and camera shake (through Humanoid.CameraOffset, so it never fights the camera).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local MathUtil = require(ReplicatedStorage.Shared.MathUtil)

local C = Config.Camera

local CameraController = {}
CameraController.__index = CameraController

function CameraController.new()
	local self = setmetatable({
		root = nil :: BasePart?,
		humanoid = nil :: Humanoid?,
		fov = C.BaseFov,
		kick = 0,
		shake = 0,
		time = 0,
	}, CameraController)

	RunService.RenderStepped:Connect(function(dt)
		self:_update(dt)
	end)

	return self
end

function CameraController:SetCharacter(root: BasePart?, humanoid: Humanoid?)
	if self.humanoid and self.humanoid ~= humanoid then
		self.humanoid.CameraOffset = Vector3.zero
	end
	self.root = root
	self.humanoid = humanoid
end

function CameraController:Kick(amount: number)
	self.kick += amount
end

-- amount is roughly 0..1
function CameraController:Shake(amount: number)
	self.shake = math.min(1, self.shake + amount)
end

function CameraController:_update(dt: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	self.time += dt

	local speed = if self.root then self.root.AssemblyLinearVelocity.Magnitude else 0
	local target = MathUtil.remapClamped(speed, C.FovMinSpeed, C.FovMaxSpeed, C.BaseFov, C.MaxFov)

	self.fov += (target - self.fov) * MathUtil.expAlpha(C.Smoothing, dt)
	self.kick *= math.exp(-C.KickDecay * dt)
	camera.FieldOfView = math.clamp(self.fov + self.kick, 1, 120)

	self.shake *= math.exp(-C.ShakeDecay * dt)
	local humanoid = self.humanoid
	if humanoid then
		if self.shake > 0.01 then
			local t = self.time * C.ShakeFrequency
			local strength = self.shake * self.shake * C.ShakeStrength
			humanoid.CameraOffset = Vector3.new(math.noise(t, 0.3), math.noise(t, 7.1), math.noise(t, 13.7)) * strength
		elseif humanoid.CameraOffset ~= Vector3.zero then
			humanoid.CameraOffset = Vector3.zero
		end
	end
end

return CameraController
