-- The web line from your hand to the anchor, with a quick "shoot out" and a flash where it sticks.
-- Local only for now; showing other players' webs comes in the multiplayer step.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Cleaner = require(ReplicatedStorage.Shared.Cleaner)
local Config = require(ReplicatedStorage.Shared.Config)

local W = Config.Web

local WebVisuals = {}
WebVisuals.__index = WebVisuals

function WebVisuals.new(ctx)
	local cleaner = Cleaner.new()

	local anchorAttachment = Instance.new("Attachment")
	anchorAttachment.Name = "WebAnchor"
	anchorAttachment.Parent = workspace.Terrain
	cleaner:Add(anchorAttachment)

	local beam = Instance.new("Beam")
	beam.Name = "Web"
	beam.Attachment0 = ctx.HandAttachment
	beam.Attachment1 = anchorAttachment
	beam.Width0 = W.Width0
	beam.Width1 = W.Width1
	beam.Color = ColorSequence.new(W.Color)
	beam.LightEmission = 0.4
	beam.Transparency = NumberSequence.new(0)
	beam.FaceCamera = true
	beam.Segments = 1
	beam.Enabled = false
	beam.Parent = workspace.Terrain
	cleaner:Add(beam)

	local self = setmetatable({
		ctx = ctx,
		beam = beam,
		anchorAttachment = anchorAttachment,
		target = nil :: Vector3?,
		travel = 1,
		cleaner = cleaner,
	}, WebVisuals)

	cleaner:Add(RunService.RenderStepped:Connect(function(dt)
		self:_update(dt)
	end))

	return self
end

function WebVisuals:Attach(anchor: Vector3)
	self.target = anchor
	self.travel = 0
	self.anchorAttachment.WorldPosition = self.ctx.HandAttachment.WorldPosition
	self.beam.Enabled = true
end

function WebVisuals:Detach()
	self.target = nil
	self.beam.Enabled = false
end

function WebVisuals:_impact(position: Vector3)
	local flash = Instance.new("Part")
	flash.Name = "WebImpact"
	flash.Shape = Enum.PartType.Ball
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanQuery = false
	flash.CanTouch = false
	flash.CastShadow = false
	flash.Material = Enum.Material.Neon
	flash.Color = W.ImpactColor
	flash.Size = Vector3.one * 0.5
	flash.Position = position
	flash.Parent = workspace

	TweenService:Create(flash, TweenInfo.new(W.ImpactTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.one * W.ImpactSize,
		Transparency = 1,
	}):Play()
	Debris:AddItem(flash, W.ImpactTime + 0.05)
end

function WebVisuals:_update(dt: number)
	local target = self.target
	if not target then
		return
	end
	if self.travel < 1 then
		self.travel = math.min(1, self.travel + dt / W.ShootTime)
		local t = 1 - (1 - self.travel) ^ 3 -- ease out
		local start = self.ctx.HandAttachment.WorldPosition
		self.anchorAttachment.WorldPosition = start:Lerp(target, t)
		if self.travel >= 1 then
			self:_impact(target)
		end
	else
		self.anchorAttachment.WorldPosition = target
	end
end

function WebVisuals:Destroy()
	self.cleaner:Clean()
end

return WebVisuals
