-- The web line from your hand to the anchor, with a quick "shoot out" and a flash where it sticks.
-- When the web wraps around building corners it's drawn as a chain of segments:
--   stick point -> corner 1 -> corner 2 -> ... -> hand
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
	local self = setmetatable({
		ctx = ctx,
		points = {} :: { Vector3 }, -- [1] = where the web sticks, then corners toward the hand
		attachments = {} :: { Attachment },
		beams = {} :: { Beam },
		hand = ctx.HandAttachment :: Attachment, -- which hand the web comes from
		onImpact = nil :: ((Vector3) -> ())?, -- called when the web hits
		travel = 1,
		active = false,
		cleaner = Cleaner.new(),
	}, WebVisuals)

	self.cleaner:Add(function()
		for _, beam in self.beams do
			beam:Destroy()
		end
		for _, attachment in self.attachments do
			attachment:Destroy()
		end
	end)

	self.cleaner:Add(RunService.RenderStepped:Connect(function(dt)
		self:_update(dt)
	end))

	return self
end

-- Makes sure there are enough attachments and beams for `count` segments.
function WebVisuals:_ensure(count: number)
	while #self.attachments < count do
		local attachment = Instance.new("Attachment")
		attachment.Name = "WebPoint"
		attachment.Parent = workspace.Terrain
		table.insert(self.attachments, attachment)

		local beam = Instance.new("Beam")
		beam.Name = "Web"
		beam.Width0 = W.Width1
		beam.Width1 = W.Width0
		beam.Color = ColorSequence.new(W.Color)
		beam.LightEmission = 0.4
		beam.Transparency = NumberSequence.new(0)
		beam.FaceCamera = true
		beam.Segments = 1
		beam.Enabled = false
		beam.Parent = workspace.Terrain
		table.insert(self.beams, beam)
	end
end

-- Connects segment i from point i to the next point toward the hand (or the hand itself).
function WebVisuals:_refresh()
	local count = if self.active then #self.points else 0
	self:_ensure(count)
	for i, beam in self.beams do
		if i <= count then
			beam.Attachment0 = self.attachments[i]
			beam.Attachment1 = if i < count then self.attachments[i + 1] else self.hand
			beam.Enabled = true
		else
			beam.Enabled = false
		end
	end
end

function WebVisuals:Attach(stickPoint: Vector3, hand: Attachment?)
	self.hand = hand or self.ctx.HandAttachment
	self.points = { stickPoint }
	self.travel = 0
	self.active = true
	self:_ensure(1)
	self.attachments[1].WorldPosition = self.hand.WorldPosition
	self:_refresh()
end

-- Updates the chain when the web wraps or unwraps around corners.
function WebVisuals:SetPoints(points: { Vector3 })
	self.points = points
	self:_refresh()
	self:_place()
end

function WebVisuals:Detach()
	self.active = false
	self.points = {}
	self:_refresh()
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

-- Puts every attachment at its point (the stick point flies out from the hand at first).
function WebVisuals:_place()
	for i, point in self.points do
		if i == 1 and self.travel < 1 then
			local t = 1 - (1 - self.travel) ^ 3 -- ease out
			self.attachments[1].WorldPosition = self.hand.WorldPosition:Lerp(point, t)
		else
			self.attachments[i].WorldPosition = point
		end
	end
end

function WebVisuals:_update(dt: number)
	if not self.active or #self.points == 0 then
		return
	end
	if self.travel < 1 then
		self.travel = math.min(1, self.travel + dt / W.ShootTime)
		if self.travel >= 1 then
			self:_impact(self.points[1])
			if self.onImpact then
				self.onImpact(self.points[1])
			end
		end
	end
	self:_place()
end

function WebVisuals:Destroy()
	self.cleaner:Clean()
end

return WebVisuals
