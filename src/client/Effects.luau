-- Sounds and screen effects that make speed feel fast:
--   * one-shot sounds (web shoot, stick, release, whoosh, zip, double jump)
--   * wind that gets louder and higher-pitched with speed
--   * speed lines around the edge of the screen
--   * a glowing trail behind you when you're really moving
-- All local to this player for now.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Cleaner = require(ReplicatedStorage.Shared.Cleaner)
local Config = require(ReplicatedStorage.Shared.Config)
local MathUtil = require(ReplicatedStorage.Shared.MathUtil)

local E = Config.Effects

local Effects = {}
Effects.__index = Effects

local function makeSound(name: string, parent: Instance): Sound
	local def = E.Sounds[name]
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = def.Id
	sound.Volume = def.Volume
	sound.PlaybackSpeed = def.Speed
	sound.Parent = parent
	return sound
end

function Effects.new(ctx)
	local cleaner = Cleaner.new()
	local rng = Random.new()

	-- Wind loop
	local wind = makeSound("Wind", ctx.Root)
	wind.Looped = true
	wind.Volume = 0
	wind:Play()
	cleaner:Add(wind)

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
	trail.Color = ColorSequence.new(Config.Character.Accent, Color3.new(1, 1, 1))
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

	local self = setmetatable({
		ctx = ctx,
		rng = rng,
		wind = wind,
		trail = trail,
		lines = lines,
		lineTimer = 0,
		cleaner = cleaner,
	}, Effects)

	cleaner:Add(RunService.RenderStepped:Connect(function(dt)
		self:_update(dt)
	end))

	return self
end

function Effects:_play(name: string, pitch: number?)
	local sound = makeSound(name, self.ctx.Root)
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
	local windDef = E.Sounds.Wind
	self.wind.Volume = MathUtil.remapClamped(speed, E.WindMinSpeed, E.WindMaxSpeed, 0, windDef.Volume)
	self.wind.PlaybackSpeed = MathUtil.remapClamped(speed, E.WindMinSpeed, E.WindMaxSpeed, 0.8, 1.4)

	-- Trail
	self.trail.Enabled = speed > E.TrailMinSpeed

	-- Speed lines: re-scattered 20 times a second so they flicker like motion blur
	local intensity = MathUtil.remapClamped(speed, E.SpeedLinesMinSpeed, E.SpeedLinesMaxSpeed, 0, 1)
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
