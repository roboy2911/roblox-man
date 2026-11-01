-- Camera feel:
--   * Field of view widens as you go faster, with short "kicks" when a web connects or you let go.
--   * Shake (through Humanoid.CameraOffset, so it never fights the camera).
--   * Auto-follow: if you haven't moved the camera for a moment while flying fast, it gently
--     turns to face where you're going.
--   * Tilts slightly into turns.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local MathUtil = require(ReplicatedStorage.Shared.MathUtil)

local C = Config.Camera
local flat = MathUtil.flat

local CameraController = {}
CameraController.__index = CameraController

function CameraController.new()
	local self = setmetatable({
		root = nil :: BasePart?,
		humanoid = nil :: Humanoid?,
		fov = C.BaseFov,
		kick = 0,
		shake = 0,
		roll = 0,
		time = 0,
		lastManualInput = -math.huge,
	}, CameraController)

	RunService.RenderStepped:Connect(function(dt)
		self:_update(dt)
	end)

	-- After the default camera has moved this frame, apply auto-follow and tilt.
	RunService:BindToRenderStep("WebCreatureCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
		self:_afterCamera(dt)
	end)

	-- Note whenever the player turns the camera themselves.
	UserInputService.InputChanged:Connect(function(input)
		local inputType = input.UserInputType
		if inputType == Enum.UserInputType.MouseMovement then
			if
				UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
				or UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
			then
				self.lastManualInput = os.clock()
			end
		elseif inputType == Enum.UserInputType.Gamepad1 then
			if input.KeyCode == Enum.KeyCode.Thumbstick2 and input.Position.Magnitude > 0.15 then
				self.lastManualInput = os.clock()
			end
		elseif inputType == Enum.UserInputType.Touch then
			-- Touch drags on the right side of the screen turn the camera.
			local camera = workspace.CurrentCamera
			if camera and input.Position.X > camera.ViewportSize.X * 0.4 then
				self.lastManualInput = os.clock()
			end
		end
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

function CameraController:_afterCamera(dt: number)
	local camera = workspace.CurrentCamera
	local root = self.root
	local humanoid = self.humanoid
	if not camera or not root or not humanoid or camera.CameraType ~= Enum.CameraType.Custom then
		return
	end

	local velocity = root.AssemblyLinearVelocity
	local flatVelocity = flat(velocity)
	local speed = flatVelocity.Magnitude
	local airborne = humanoid.FloorMaterial == Enum.Material.Air
	local shiftLock = UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter

	-- Auto-follow: turn toward the direction of travel. The default camera continues from
	-- whatever direction we leave it facing, so this sticks.
	local idle = os.clock() - self.lastManualInput > C.AutoFollowDelay
	if idle and airborne and not shiftLock and speed > C.AutoFollowMinSpeed then
		local look = flat(camera.CFrame.LookVector)
		if look.Magnitude > 1e-3 then
			look = look.Unit
			local travel = flatVelocity / speed
			local angle = math.atan2(look:Cross(travel).Y, look:Dot(travel))
			local strength = MathUtil.remapClamped(speed, C.AutoFollowMinSpeed, C.AutoFollowMinSpeed * 2.5, 0.3, 1)
			local step = angle * MathUtil.expAlpha(C.AutoFollowSpeed * strength, dt)
			local focus = camera.Focus.Position
			camera.CFrame = CFrame.new(focus) * CFrame.Angles(0, step, 0) * CFrame.new(-focus) * camera.CFrame
		end
	end

	-- Tilt into turns: sideways speed relative to the camera.
	local sideways = if airborne then velocity:Dot(camera.CFrame.RightVector) else 0
	local targetRoll = -math.clamp(sideways / Config.Swing.MaxSpeed, -1, 1) * math.rad(C.RollMax)
	self.roll += (targetRoll - self.roll) * MathUtil.expAlpha(C.RollSmoothing, dt)
	if math.abs(self.roll) > 1e-4 then
		camera.CFrame *= CFrame.Angles(0, 0, self.roll)
	end
end

return CameraController
