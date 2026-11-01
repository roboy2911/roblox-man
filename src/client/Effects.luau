-- Sounds and screen effects that make speed feel fast:
--   * one-shot sounds (web shoot, stick, release, whoosh, zip, double jump)
--   * wind that gets louder and higher-pitched with speed
--   * speed lines around the edge of the screen
--   * a glowing trail behind you, and thin streaks from your hands, when you're really moving
--   * a dust puff when you land hard
--   * punch sounds, and a burst where any punch lands (yours, other players' or thugs')
-- The trail uses your suit's accent color. Speed lines can be turned off in Settings.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Cleaner = require(ReplicatedStorage.Shared.Cleaner)
local Config = require(ReplicatedStorage.Shared.Config)
local MathUtil = require(ReplicatedStorage.Shared.MathUtil)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Settings = require(script.Parent.Settings)

local E = Config.Effects

local Effects = {}
Effects.__index = Effects

local function makeSound(name: string, parent: Instance): Sound?
	local def = E.Sounds[name]
	if not def or def.Id == "" then
		return nil -- sound turned off
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = def.Id
	sound.Volume = def.Volume
	sound.PlaybackSpeed = def.Speed
	sound.Parent = parent
	return sound
end

-- Thin white streaks from each hand at high speed.
local function makeHandTrail(hand: Attachment, cleaner): Trail
	local top = Instance.new("Attachment")
	top.Name = "HandTrailTop"
	top.Position = hand.Position + Vector3.new(0, 0.15, 0)
	top.Parent = hand.Parent
	local bottom = Instance.new("Attachment")
	bottom.Name = "HandTrailBottom"
	bottom.Position = hand.Position - Vector3.new(0, 0.15, 0)
	bottom.Parent = hand.Parent
	local trail = Instance.new("Trail")
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Lifetime = 0.2
	trail.FaceCamera = true
	trail.LightEmission = 1
	trail.Color = ColorSequence.new(Color3.new(1, 1, 1))
	trail.Transparency = NumberSequence.new(0.5, 1)
	trail.Enabled = false
	trail.Parent = hand.Parent
	cleaner:Add(trail)
	cleaner:Add(top)
	cleaner:Add(bottom)
	return trail
end

function Effects.new(ctx, motion)
	local cleaner = Cleaner.new()
	local rng = Random.new()

	-- Wind loop
	local wind = makeSound("Wind", ctx.Root)
	if wind then
		wind.Looped = true
		wind.Volume = 0
		wind:Play()
		cleaner:Add(wind)
	end

	-- Trail
	local top = Instance.new("Attachment")
	top.Name = "TrailTop"
	top.Position = Vector3.new(0, 0.8, 0)
	top.Parent = ctx.Root
	local bottom = Instance.new("Attachment")
	bottom.Name = "TrailBottom"
	bottom.Position = Vector3.new(0, -0.8, 0)
	bottom.Parent = ctx.Root
	local trail = Instance.new("Trail")
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Lifetime = 0.3
	trail.MinLength = 0.1
	trail.FaceCamera = true
	trail.LightEmission = 0.8
	local accent = ctx.Character:GetAttribute("AccentColor")
	if typeof(accent) ~= "Color3" then
		accent = Config.Character.Accent
	end
	trail.Color = ColorSequence.new(accent, Color3.new(1, 1, 1))
	trail.Transparency = NumberSequence.new(0.35, 1)
	trail.WidthScale = NumberSequence.new(1, 0)
	trail.Enabled = false
	trail.Parent = ctx.Root
	cleaner:Add(trail)
	cleaner:Add(top)
	cleaner:Add(bottom)

	-- Speed lines
	local gui = Instance.new("ScreenGui")
	gui.Name = "SpeedLines"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	cleaner:Add(gui)

	local lines = {}
	for i = 1, E.SpeedLineCount do
		local line = Instance.new("Frame")
		line.Name = "Line" .. i
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.BackgroundColor3 = Color3.new(1, 1, 1)
		line.BorderSizePixel = 0
		line.Visible = false
		line.Parent = gui
		lines[i] = line
	end

	local handTrails = {}
	for _, hand in ctx.HandAttachments do
		table.insert(handTrails, makeHandTrail(hand, cleaner))
	end

	local self = setmetatable({
		ctx = ctx,
		rng = rng,
		wind = wind,
		trail = trail,
		handTrails = handTrails,
		lines = lines,
		lineTimer = 0,
		cleaner = cleaner,
	}, Effects)

	cleaner:Add(RunService.RenderStepped:Connect(function(dt)
		self:_update(dt)
	end))

	-- The suit's accent color arrives from the server a moment after spawning.
	cleaner:Add(ctx.Character:GetAttributeChangedSignal("AccentColor"):Connect(function()
		local color = ctx.Character:GetAttribute("AccentColor")
		if typeof(color) == "Color3" then
			trail.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
		end
	end))

	cleaner:Add(Remotes.Event("HitFx").OnClientEvent:Connect(function(position: any)
		if typeof(position) == "Vector3" then
			self:HitBurst(position)
		end
	end))

	cleaner:Add(motion.events:Connect(function(name: string, value: any)
		if name == "Land" and value > Config.Landing.DustMinSpeed then
			self:Dust(value)
		end
	end))

	return self
end

-- A puff of dust at your feet; bigger the harder you land.
function Effects:Dust(impact: number)
	local root = self.ctx.Root
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -8, 0), self.ctx.WorldParams)
	if not hit then
		return
	end
	local point = Instance.new("Attachment")
	point.Name = "LandingDust"
	point.WorldPosition = hit.Position + Vector3.new(0, 0.3, 0)
	point.Parent = workspace.Terrain

	local dust = Instance.new("ParticleEmitter")
	dust.Color = ColorSequence.new(Color3.fromRGB(170, 165, 160))
	dust.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.2),
		NumberSequenceKeypoint.new(1, 3.5),
	})
	dust.Transparency = NumberSequence.new(0.35, 1)
	dust.Lifetime = NumberRange.new(0.5, 0.9)
	dust.Speed = NumberRange.new(10, 18)
	dust.SpreadAngle = Vector2.new(85, 85)
	dust.Drag = 4
	dust.Acceleration = Vector3.new(0, 2, 0)
	dust.Enabled = false
	dust.Parent = point
	dust:Emit(math.floor(MathUtil.remapClamped(impact, 35, 140, 10, 30)))
	Debris:AddItem(point, 1.5)
end

function Effects:_play(name: string, pitch: number?)
	local sound = makeSound(name, self.ctx.Root)
	if not sound then
		return
	end
	sound.PlaybackSpeed *= (pitch or 1) * self.rng:NextNumber(0.94, 1.06)
	sound:Play()
	Debris:AddItem(sound, 4)
end

function Effects:Shoot()
	self:_play("Shoot")
end

function Effects:Stick()
	self:_play("Stick")
end

function Effects:Release(perfect: boolean)
	self:_play("Release", if perfect then 1.25 else 1)
end

function Effects:Whoosh(speed: number)
	self:_play("Whoosh", MathUtil.remapClamped(speed, 60, 140, 0.9, 1.2))
end

function Effects:Zip()
	self:_play("Zip")
end

function Effects:AirJump()
	self:_play("AirJump")
end

function Effects:Punch()
	self:_play("Punch")
end

-- A punch landed somewhere: a quick white burst and a hit sound.
function Effects:HitBurst(position: Vector3)
	if (position - self.ctx.Root.Position).Magnitude > 250 then
		return
	end
	local point = Instance.new("Attachment")
	point.Name = "HitBurst"
	point.WorldPosition = position
	point.Parent = workspace.Terrain

	local burst = Instance.new("ParticleEmitter")
	burst.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(255, 220, 150))
	burst.LightEmission = 0.8
	burst.Size = NumberSequence.new(0.8, 0)
	burst.Transparency = NumberSequence.new(0, 1)
	burst.Lifetime = NumberRange.new(0.15, 0.3)
	burst.Speed = NumberRange.new(15, 30)
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.Drag = 6
	burst.Enabled = false
	burst.Parent = point
	burst:Emit(16)

	local def = E.Sounds.Hit
	if def.Id ~= "" then
		local sound = Instance.new("Sound")
		sound.SoundId = def.Id
		sound.Volume = def.Volume
		sound.PlaybackSpeed = def.Speed * self.rng:NextNumber(0.9, 1.1)
		sound.Parent = point
		sound:Play()
	end
	Debris:AddItem(point, 2)
end

function Effects:_rerollLine(line: Frame, intensity: number)
	local rng = self.rng
	local angle = rng:NextNumber(0, math.pi * 2)
	local radius = rng:NextNumber(0.42, 0.75)
	line.Position = UDim2.fromScale(0.5 + math.cos(angle) * radius, 0.5 + math.sin(angle) * radius)
	line.Rotation = math.deg(angle)
	line.Size = UDim2.fromOffset(40 + rng:NextNumber(60, 180) * intensity, 2)
	line.BackgroundTransparency = 1 - intensity * rng:NextNumber(0.25, 0.6)
end

function Effects:_update(dt: number)
	local speed = self.ctx.Root.AssemblyLinearVelocity.Magnitude

	-- Wind
	local wind = self.wind
	if wind then
		local windDef = E.Sounds.Wind
		wind.Volume = MathUtil.remapClamped(speed, E.WindMinSpeed, E.WindMaxSpeed, 0, windDef.Volume)
		wind.PlaybackSpeed = MathUtil.remapClamped(speed, E.WindMinSpeed, E.WindMaxSpeed, 0.8, 1.4)
	end

	-- Trails
	local fast = speed > E.TrailMinSpeed
	self.trail.Enabled = fast
	for _, handTrail in self.handTrails do
		handTrail.Enabled = fast
	end

	-- Speed lines: re-scattered 20 times a second so they flicker like motion blur
	local intensity = if Settings.Get("SpeedLines")
		then MathUtil.remapClamped(speed, E.SpeedLinesMinSpeed, E.SpeedLinesMaxSpeed, 0, 1)
		else 0
	self.lineTimer += dt
	local reroll = self.lineTimer > 0.05
	if reroll then
		self.lineTimer = 0
	end
	for _, line in self.lines do
		if intensity <= 0 then
			line.Visible = false
		else
			line.Visible = true
			if reroll then
				self:_rerollLine(line, intensity)
			end
		end
	end
end

function Effects:Destroy()
	self.cleaner:Clean()
end

return Effects
