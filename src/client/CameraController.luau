-- Widens the field of view as you go faster, plus short "kicks" when a web connects or you let go.

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
		fov = C.BaseFov,
		kick = 0,
	}, CameraController)

	RunService.RenderStepped:Connect(function(dt)
		self:_update(dt)
	end)

	return self
end

function CameraController:SetRoot(root: BasePart?)
	self.root = root
end

function CameraController:Kick(amount: number)
	self.kick += amount
end

function CameraController:_update(dt: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	local speed = if self.root then self.root.AssemblyLinearVelocity.Magnitude else 0
	local target = MathUtil.remapClamped(speed, C.FovMinSpeed, C.FovMaxSpeed, C.BaseFov, C.MaxFov)

	self.fov += (target - self.fov) * MathUtil.expAlpha(C.Smoothing, dt)
	self.kick *= math.exp(-C.KickDecay * dt)

	camera.FieldOfView = math.clamp(self.fov + self.kick, 1, 120)
end

return CameraController
