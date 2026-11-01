-- The web line from your hand to the anchor.
--   * A bright core plus a soft glow around it.
--   * Shoots out from the hand, then flashes and bursts into particles where it sticks.
--   * Wobbles side to side right after connecting, and droops when it goes slack.
--   * When the web wraps around building corners it's drawn as a chain of segments:
--       stick point -> corner 1 -> corner 2 -> ... -> hand
--   * When you let go, the last strand falls away and fades instead of vanishing.
--   * With the Rainbow Webs gamepass, webs cycle through colors (for everyone watching).
-- Local only for now; showing other players' webs comes in the multiplayer step.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Cleaner = require(ReplicatedStorage.Shared.Cleaner)
local Config = require(ReplicatedStorage.Shared.Config)

local W = Config.Web

local WebVisuals = {}
WebVisuals.__index = WebVisuals

local function makeAttachment(name: string): Attachment
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Parent = workspace.Terrain
	return attachment
end

local function makeBeam(a0: Attachment, a1: Attachment, glow: boolean): Beam
	local beam = Instance.new("Beam")
	beam.Name = if glow then "WebGlow" else "Web"
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.FaceCamera = true
	beam.Segments = 12
	if glow then
		beam.Width0 = W.GlowWidth
		beam.Width1 = W.GlowWidth * 0.6
		beam.Color = ColorSequence.new(W.GlowColor)
		beam.LightEmission = 1
		beam.Transparency = NumberSequence.new(W.GlowTransparency)
	else
		beam.Width0 = W.CoreWidth0
		beam.Width1 = W.CoreWidth1
		beam.Color = ColorSequence.new(W.Color)
		beam.LightEmission = 0.4
		beam.Transparency = NumberSequence.new(0)
	end
	beam.Enabled = false
	beam.Parent = workspace.Terrain
	return beam
end

-- Points an attachment's X axis along `axis`, which is the direction a Beam curves toward.
local function setCurveAxis(attachment: Attachment, axis: Vector3)
	local pos = attachment.WorldPosition
	local up = Vector3.yAxis - axis * axis.Y
	if up.Magnitude < 1e-3 then
		up = Vector3.zAxis - axis * axis.Z
	end
	attachment.WorldCFrame = CFrame.fromMatrix(pos, axis, up.Unit)
end

function WebVisuals.new(ctx)
	local self = setmetatable({
		ctx = ctx,
		points = {} :: { Vector3 }, -- [1] = where the web sticks, then corners toward the hand
		attachments = {} :: { Attachment },
		cores = {} :: { Beam },
		glows = {} :: { Beam },
		handEnd = makeAttachment("WebHandEnd"), -- follows the hand; beams end here
		hand = ctx.HandAttachment :: Attachment, -- which hand the web comes from
		onImpact = nil :: ((Vector3) -> ())?, -- called when the web hits
		travel = 1,
		attachTime = 0,
		slack = 0,
		active = false,
		remnants = {} :: { any },
		owner = Players:GetPlayerFromCharacter(ctx.Character),
		rainbow = false,
		cleaner = Cleaner.new(),
	}, WebVisuals)

	self.cleaner:Add(self.handEnd)
	self.cleaner:Add(function()
		for _, list in { self.cores, self.glows, self.attachments } do
			for _, instance in list do
				instance:Destroy()
			end
		end
		for _, remnant in table.clone(self.remnants) do
			remnant.cleanup()
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
		local attachment = makeAttachment("WebPoint")
		table.insert(self.attachments, attachment)
		table.insert(self.cores, makeBeam(attachment, self.handEnd, false))
		table.insert(self.glows, makeBeam(attachment, self.handEnd, true))
	end
end

-- Connects segment i from point i to the next point toward the hand (or the hand itself).
function WebVisuals:_refresh()
	local count = if self.active then #self.points else 0
	self:_ensure(count)
	for i in self.attachments do
		local enabled = i <= count
		local nextAttachment = if i < count then self.attachments[i + 1] else self.handEnd
		for _, beam in { self.cores[i], self.glows[i] } do
			beam.Attachment1 = nextAttachment
			beam.CurveSize0 = 0
			beam.CurveSize1 = 0
			beam.Enabled = enabled
		end
	end
end

function WebVisuals:Attach(stickPoint: Vector3, hand: Attachment?)
	self.hand = hand or self.ctx.HandAttachment
	self.points = { stickPoint }
	self.travel = 0
	self.attachTime = os.clock()
	self.slack = 0
	self.active = true
	self:_ensure(1)
	self.handEnd.WorldPosition = self.hand.WorldPosition
	self.attachments[1].WorldPosition = self.hand.WorldPosition
	self:_refresh()
end

-- Updates the chain when the web wraps or unwraps around corners.
function WebVisuals:SetPoints(points: { Vector3 })
	self.points = points
	self:_refresh()
	self:_place()
end

-- How much longer the web is than the straight distance (it droops by this much).
function WebVisuals:SetSlack(slack: number)
	self.slack = slack
end

-- Hides the web. With leaveStrand, the last strand stays behind and falls away.
function WebVisuals:Detach(leaveStrand: boolean?)
	if leaveStrand and self.active and #self.points > 0 and self.travel >= 1 then
		self:_spawnRemnant(self.points[#self.points], self.hand.WorldPosition)
	end
	self.active = false
	self.points = {}
	self:_refresh()
end

function WebVisuals:_spawnRemnant(from: Vector3, to: Vector3)
	local a0 = makeAttachment("RemnantTop")
	a0.WorldPosition = from
	local a1 = makeAttachment("RemnantEnd")
	a1.WorldPosition = to
	local beam = makeBeam(a0, a1, false)
	beam.Enabled = true

	local remnant
	remnant = {
		start = os.clock(),
		velocity = self.ctx.Root.AssemblyLinearVelocity * 0.3,
		a1 = a1,
		beam = beam,
		cleanup = function()
			beam:Destroy()
			a0:Destroy()
			a1:Destroy()
			local index = table.find(self.remnants, remnant)
			if index then
				table.remove(self.remnants, index)
			end
		end,
	}
	table.insert(self.remnants, remnant)
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

	-- Little burst of web bits
	local burstPoint = makeAttachment("WebBurst")
	burstPoint.WorldPosition = position
	local burst = Instance.new("ParticleEmitter")
	burst.Color = ColorSequence.new(W.Color)
	burst.LightEmission = 0.5
	burst.Size = NumberSequence.new(0.5, 0)
	burst.Transparency = NumberSequence.new(0, 1)
	burst.Lifetime = NumberRange.new(0.2, 0.4)
	burst.Speed = NumberRange.new(12, 24)
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.Drag = 5
	burst.Enabled = false
	burst.Parent = burstPoint
	burst:Emit(14)
	Debris:AddItem(burstPoint, 1)
end

-- Puts every attachment at its point (the stick point flies out from the hand at first).
function WebVisuals:_place()
	self.handEnd.WorldPosition = self.hand.WorldPosition
	for i, point in self.points do
		if i == 1 and self.travel < 1 then
			local t = 1 - (1 - self.travel) ^ 3 -- ease out
			self.attachments[1].WorldPosition = self.hand.WorldPosition:Lerp(point, t)
		else
			self.attachments[i].WorldPosition = point
		end
	end
end

-- Bends the segment that reaches the hand: droops when slack, wobbles after connecting.
function WebVisuals:_bendLastSegment()
	local count = #self.points
	if count == 0 then
		return
	end
	local start = self.attachments[count]
	local segment = self.handEnd.WorldPosition - start.WorldPosition
	if segment.Magnitude < 1 then
		return
	end
	local along = segment.Unit
	local side = along:Cross(Vector3.yAxis)
	side = if side.Magnitude < 1e-3 then Vector3.xAxis else side.Unit
	-- "Down", but at right angles to the web (zero for a vertical web)
	local down = Vector3.new(0, -1, 0) + along * along.Y

	local age = os.clock() - self.attachTime
	local wobble = math.sin(age * W.WobbleFrequency) * W.WobbleAmplitude * math.exp(-age * W.WobbleDecay)
	local sag = if self.travel < 1 then 0 else math.min(self.slack * W.SagFactor, segment.Magnitude * 0.3)
	local bend = down * sag + side * wobble -- down is shorter for steep webs, so they droop less
	local size = bend.Magnitude

	local core, glow = self.cores[count], self.glows[count]
	if size < 0.05 then
		core.CurveSize0 = 0
		glow.CurveSize0 = 0
		return
	end
	setCurveAxis(start, bend / size)
	core.CurveSize0 = size
	glow.CurveSize0 = size
end

function WebVisuals:_updateRemnants(dt: number)
	local now = os.clock()
	for i = #self.remnants, 1, -1 do
		local remnant = self.remnants[i]
		local age = now - remnant.start
		if age >= W.RemnantTime then
			remnant.cleanup()
		else
			remnant.velocity += Vector3.new(0, -workspace.Gravity * 0.5 * dt, 0)
			remnant.a1.WorldPosition += remnant.velocity * dt
			remnant.beam.Transparency = NumberSequence.new(age / W.RemnantTime)
		end
	end
end

function WebVisuals:_update(dt: number)
	self:_updateRemnants(dt)
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
	self:_bendLastSegment()
	self:_updateColor()
end

-- Rainbow Webs gamepass: cycle the web's color.
function WebVisuals:_updateColor()
	local rainbow = self.owner ~= nil and self.owner:GetAttribute("RainbowWebs") == true
	if not rainbow and not self.rainbow then
		return
	end
	self.rainbow = rainbow
	local core = if rainbow then Color3.fromHSV((os.clock() * 0.4) % 1, 0.65, 1) else W.Color
	local glow = if rainbow then Color3.fromHSV((os.clock() * 0.4) % 1, 0.8, 1) else W.GlowColor
	local coreSequence = ColorSequence.new(core)
	local glowSequence = ColorSequence.new(glow)
	for i = 1, #self.points do
		self.cores[i].Color = coreSequence
		self.glows[i].Color = glowSequence
	end
end

function WebVisuals:Destroy()
	self.cleaner:Clean()
end

return WebVisuals
