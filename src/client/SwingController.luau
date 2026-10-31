-- Web swinging.
--
-- How it works:
--   1. While the Swing button is held, we scan a cone of rays above and ahead of you and pick the
--      building point closest to an "ideal" anchor spot. You never have to aim precisely.
--   2. While swinging we run our own pendulum: gravity + steering + a "pump" at the bottom of the
--      arc, then the web stops you moving further away than its length. The result is fed to a
--      LinearVelocity on the root part, so we control the feel exactly.
--   3. Letting go keeps all your speed and adds a boost. Letting go while rising past the bottom
--      of the arc is a "perfect release" with a bigger boost, a flip and camera kick.
--
-- Webs alternate between a building on your left and one on your right (or favor the side you're
-- turning toward), and come from the matching hand.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cleaner = require(ReplicatedStorage.Shared.Cleaner)
local Config = require(ReplicatedStorage.Shared.Config)
local MathUtil = require(ReplicatedStorage.Shared.MathUtil)

local S = Config.Swing
local flat = MathUtil.flat
local safeUnit = MathUtil.safeUnit
local projectOnPlane = MathUtil.projectOnPlane

local SwingController = {}
SwingController.__index = SwingController

function SwingController.new(ctx, fsm, input, camera, visuals, effects, motion)
	local self = setmetatable({
		ctx = ctx,
		fsm = fsm,
		input = input,
		camera = camera,
		visuals = visuals,
		effects = effects,
		motion = motion, -- shared info for poses (which hand, where the web is, ...)
		cleaner = Cleaner.new(),

		-- The web as a chain of points: [1] is where the swing started, later entries are
		-- corners it has wrapped around. The last point is what you currently swing from.
		points = {} :: { Vector3 },
		webPoint = Vector3.zero, -- where the web visibly sticks
		floorY = 0,
		lastPos = Vector3.zero,
		lastWrapTime = 0,
		ropeLength = 0,
		maxLength = math.huge,
		velocity = Vector3.zero,
		lastCommanded = Vector3.zero,
		releaseVelocity = nil :: Vector3?,
		perfectRelease = false,
		cooldownUntil = 0,
		nextSide = 1, -- 1 = prefer a building on the right next, -1 = left
		wasAtBottom = false,
		swingTime = 0,
	}, SwingController)

	local driver = Instance.new("LinearVelocity")
	driver.Name = "SwingDriver"
	driver.Attachment0 = ctx.RootAttachment
	driver.RelativeTo = Enum.ActuatorRelativeTo.World
	driver.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	driver.MaxForce = math.huge
	driver.Enabled = false
	driver.Parent = ctx.Root
	self.driver = self.cleaner:Add(driver)

	local lean = Instance.new("AlignOrientation")
	lean.Name = "SwingLean"
	lean.Mode = Enum.OrientationAlignmentMode.OneAttachment
	lean.Attachment0 = ctx.RootAttachment
	lean.MaxTorque = math.huge
	lean.Responsiveness = S.TurnResponsiveness
	lean.Enabled = false
	lean.Parent = ctx.Root
	self.lean = self.cleaner:Add(lean)

	fsm:Register("Swing", {
		Enter = function(_previous, pivot: Vector3, webPoint: Vector3, hand: string)
			self:_enter(pivot, webPoint, hand)
		end,
		Exit = function(nextState: string)
			self:_exit(nextState)
		end,
		Update = function(dt: number)
			self:_update(dt)
		end,
	})

	-- Holding the button while not swinging keeps looking for an anchor, so you can hold it
	-- while falling and the web fires the moment a building comes in range.
	fsm:AddHook(function()
		if not (fsm:Is("Ground") or fsm:Is("Air")) or not input:IsDown("Swing") then
			return
		end
		if os.clock() < self.cooldownUntil or not ctx:IsAlive() then
			return
		end
		local pivot, webPoint, hand = self:_findAnchor()
		if pivot then
			fsm:Set("Swing", pivot, webPoint, hand)
		end
	end)

	return self
end

-- Which way the player wants to go: the direction they're pressing (WASD / stick), or where the
-- camera looks if they aren't pressing anything. Nudged slightly toward current motion.
function SwingController:_heading(): Vector3
	local root = self.ctx.Root
	local move = flat(self.ctx.Humanoid.MoveDirection)
	local heading
	if move.Magnitude > 0.1 then
		heading = move.Unit
	else
		local look = flat(workspace.CurrentCamera.CFrame.LookVector)
		heading = safeUnit(look, safeUnit(flat(root.CFrame.LookVector), Vector3.zAxis))
	end
	local velocity = flat(root.AssemblyLinearVelocity)
	if velocity.Magnitude > 25 then
		heading = safeUnit(heading * 0.75 + velocity.Unit * 0.25, heading)
	end
	return heading
end

-- Which side the next web should favor: toward your turn if you're turning, otherwise the
-- opposite side from the last web (left, right, left, ...).
function SwingController:_preferredSide(heading: Vector3): number
	local velocity = flat(self.ctx.Root.AssemblyLinearVelocity)
	if velocity.Magnitude > 10 then
		local velocityRight = velocity.Unit:Cross(Vector3.yAxis)
		local turn = heading:Dot(velocityRight) -- > 0 means you want to go right of where you're moving
		if math.abs(turn) > S.TurnSideThreshold then
			return if turn > 0 then 1 else -1
		end
	end
	return self.nextSide
end

-- Returns the swing pivot (used for physics), the point where the web visibly sticks, and which
-- hand shoots it. For webs on walls the pivot sits out over the street, so you swing past the
-- building, not into it.
function SwingController:_findAnchor(): (Vector3?, Vector3?, string?)
	local pos = self.ctx.Root.Position
	local heading = self:_heading()
	local right = heading:Cross(Vector3.yAxis)
	local side = self:_preferredSide(heading)
	local basis = CFrame.lookAt(Vector3.zero, heading)
	local ideal = pos + heading * S.IdealForward + Vector3.yAxis * S.IdealUp + right * side * S.IdealSide

	local best: Vector3? = nil
	local bestWebPoint: Vector3? = nil
	local bestScore = -math.huge

	for _, yaw in S.SearchYaw do
		for _, pitch in S.SearchPitch do
			local dir = (basis * CFrame.Angles(0, math.rad(yaw), 0) * CFrame.Angles(math.rad(pitch), 0, 0)).LookVector
			local result = workspace:Raycast(pos, dir * S.MaxWebLength, self.ctx.SwingParams)
			if result then
				-- Stick slightly out from the surface so the web doesn't clip into the wall.
				local webPoint = result.Position + result.Normal * 0.2
				local pivot = webPoint
				if math.abs(result.Normal.Y) < 0.5 then
					pivot += safeUnit(flat(result.Normal), Vector3.zero) * S.AnchorWallOffset
				end
				local rel = pivot - pos
				if
					rel.Magnitude >= S.MinWebLength
					and rel.Y >= S.MinAnchorHeight
					and flat(rel):Dot(heading) > 0
				then
					local score = -(pivot - ideal).Magnitude
						- math.abs(rel.Magnitude - S.IdealLength) * S.LengthPenalty
					if score > bestScore then
						best, bestWebPoint, bestScore = pivot, webPoint, score
					end
				end
			end
		end
	end

	if not best or not bestWebPoint then
		return nil, nil, nil
	end
	local hand = if flat(bestWebPoint - pos):Dot(right) >= 0 then "Right" else "Left"
	return best, bestWebPoint, hand
end

-- Pushes you away from nearby walls and removes the part of your velocity heading into them,
-- so a near-crash becomes a slide along the wall.
function SwingController:_avoidWalls(pos: Vector3, v: Vector3, dt: number): Vector3
	local horizontal = flat(v)
	local speed = horizontal.Magnitude
	if speed < 1 then
		return v
	end
	local forward = horizontal / speed
	local right = forward:Cross(Vector3.yAxis)

	local checks = {
		{ forward, math.clamp(speed * S.WallLookAhead, S.WallMinCheck, S.WallMaxCheck) },
		{ right, S.WallSideCheck },
		{ -right, S.WallSideCheck },
	}
	for _, check in checks do
		local dir, range = check[1], check[2]
		local hit = workspace:Raycast(pos, dir * range, self.ctx.WorldParams)
		if hit and math.abs(hit.Normal.Y) < 0.5 then
			local normal = safeUnit(flat(hit.Normal), Vector3.zero)
			local closeness = 1 - hit.Distance / range -- 0 far, 1 touching
			local into = v:Dot(normal)
			if into < 0 then
				v -= normal * into * closeness
			end
			v += normal * S.WallPush * closeness * dt
		end
	end
	return v
end

-- The point you're currently swinging from.
function SwingController:_pivot(): Vector3
	return self.points[#self.points]
end

-- The web reels in if needed so the bottom of the arc stays above the floor.
function SwingController:_updateMaxLength()
	self.maxLength = math.max(self:_pivot().Y - (self.floorY + S.GroundClearance), S.MinRopeLength)
end

-- Returns the building hit if the straight line from `from` to `to` passes through one.
function SwingController:_blocked(from: Vector3, to: Vector3): RaycastResult?
	local offset = to - from
	local length = offset.Magnitude
	if length < 1 then
		return nil
	end
	-- Stop just short of the target so a corner point doesn't count as blocking itself.
	return workspace:Raycast(from, offset.Unit * (length - 0.5), self.ctx.SwingParams)
end

-- Finds the corner the web just caught on. Last frame's line was clear and this frame's isn't,
-- so we search between the two positions for the line that just grazes the building. Where
-- that grazing line touches is the corner.
function SwingController:_findCorner(clearPos: Vector3, blockedPos: Vector3, pivot: Vector3): Vector3?
	local lo, hi = 0, 1
	if self:_blocked(clearPos, pivot) then
		lo = nil -- no clear line to start from; just use the current hit
	end
	if lo then
		for _ = 1, 8 do
			local mid = (lo + hi) / 2
			if self:_blocked(clearPos:Lerp(blockedPos, mid), pivot) then
				hi = mid
			else
				lo = mid
			end
		end
	end
	local hit = self:_blocked(clearPos:Lerp(blockedPos, hi), pivot)
	if not hit then
		hit = self:_blocked(blockedPos, pivot)
	end
	if not hit then
		return nil
	end
	return hit.Position + hit.Normal * S.WrapOffset
end

-- Wraps the web around corners it would otherwise pass through, and unwraps it when you
-- swing back. Returns the point you're now swinging from.
function SwingController:_updateWraps(pos: Vector3): Vector3
	local points = self.points
	local changed = false

	-- Unwrap: if you can see the previous point again, the web no longer touches this corner.
	if #points > 1 and os.clock() - self.lastWrapTime > S.UnwrapDelay then
		local previous = points[#points - 1]
		if not self:_blocked(pos, previous) then
			local removed = table.remove(points) :: Vector3
			self.ropeLength += (previous - removed).Magnitude
			changed = true
		end
	end

	-- Wrap: the line to the pivot goes through a building, so bend the web at the corner.
	local pivot = points[#points]
	if #points <= S.MaxWraps and self:_blocked(pos, pivot) then
		local corner = self:_findCorner(self.lastPos, pos, pivot)
		if corner and (corner - pivot).Magnitude > S.MinWrapSpacing then
			table.insert(points, corner)
			self.ropeLength = math.max(S.MinRopeLength, self.ropeLength - (pivot - corner).Magnitude)
			self.lastWrapTime = os.clock()
			changed = true
		end
	end

	if changed then
		self:_updateMaxLength()
		local visualPoints = { self.webPoint }
		for i = 2, #points do
			table.insert(visualPoints, points[i])
		end
		self.visuals:SetPoints(visualPoints)
		self.motion.pivot = visualPoints[#visualPoints] -- the arm aims at the nearest bend
	end

	self.lastPos = pos
	return points[#points]
end

-- Height of whatever is under the player (or very low if nothing is).
function SwingController:_floorHeight(pos: Vector3): number
	local result = workspace:Raycast(pos, Vector3.new(0, -1000, 0), self.ctx.WorldParams)
	return if result then result.Position.Y else pos.Y - 1000
end

function SwingController:_enter(anchor: Vector3, webPoint: Vector3?, hand: string?)
	local ctx = self.ctx
	local root = ctx.Root
	local humanoid = ctx.Humanoid
	local pos = root.Position
	local velocity = root.AssemblyLinearVelocity

	self.points = { anchor }
	self.webPoint = webPoint or anchor
	self.lastPos = pos
	self.lastWrapTime = 0
	self.releaseVelocity = nil
	self.perfectRelease = false

	-- Start the web a bit shorter than the real distance, so it yanks you on connect.
	local distance = (anchor - pos).Magnitude
	self.ropeLength = math.max(distance * S.InitialSnap, S.MinRopeLength)
	self.floorY = self:_floorHeight(pos)
	self:_updateMaxLength()

	if ctx:IsGrounded() then
		velocity += Vector3.new(0, S.GroundLaunchSpeed, 0)
	end

	-- Small push in the direction you're heading, so even a standing start swings.
	local ropeDir = (anchor - pos).Unit
	local kick = projectOnPlane(self:_heading(), ropeDir)
	velocity += safeUnit(kick, Vector3.zero) * S.AttachKick

	self.velocity = velocity
	self.lastCommanded = velocity
	self.swingTime = 0

	humanoid.AutoRotate = false
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	-- Apply the launch immediately, so the very first frame already moves.
	root.AssemblyLinearVelocity = velocity

	self.driver.VectorVelocity = velocity
	self.driver.Enabled = true
	self.lean.CFrame = root.CFrame.Rotation
	self.lean.Enabled = true

	local webHand = hand or "Right"
	self.nextSide = if webHand == "Right" then -1 else 1
	self.wasAtBottom = false
	self.motion.webHand = webHand
	self.motion.pivot = self.webPoint
	self.motion.lowness = 0

	self.visuals:Attach(self.webPoint, ctx.HandAttachments[webHand])
	self.effects:Shoot()
	self.camera:Kick(Config.Camera.AttachKick)
end

function SwingController:_update(dt: number)
	local ctx = self.ctx
	local root = ctx.Root

	if not self.input:IsDown("Swing") then
		self:_release()
		return
	end

	local pos = root.Position

	self.swingTime += dt

	-- If the real velocity is far from what we asked for, we hit something: trust reality.
	-- (Skipped for the first moment, while the character is still getting up to speed.)
	local actual = root.AssemblyLinearVelocity
	if self.swingTime > S.StartGraceTime and (actual - self.lastCommanded).Magnitude > S.CollisionTolerance then
		self.velocity = actual
	end
	local v = self.velocity

	-- Reel in to keep the bottom of the arc off the ground.
	if self.ropeLength > self.maxLength then
		self.ropeLength = math.max(self.maxLength, self.ropeLength - S.ReelSpeed * dt)
	end

	-- Gravity
	v += Vector3.new(0, -S.Gravity * dt, 0)

	local pivot = self:_updateWraps(pos)
	local toAnchor = pivot - pos
	local distance = toAnchor.Magnitude
	if distance < 0.01 then
		self:_release()
		return
	end
	local ropeDir = toAnchor / distance -- points from you to the anchor

	-- Steering: movement keys turn your direction of travel (keeping your speed),
	-- and holding the opposite direction brakes.
	local move = flat(ctx.Humanoid.MoveDirection)
	if move.Magnitude > 0.1 then
		move = move.Unit
		local horizontal = flat(v)
		local hSpeed = horizontal.Magnitude
		if hSpeed > 1 then
			local dir = horizontal / hSpeed
			if dir:Dot(move) < -0.3 then
				hSpeed = math.max(0, hSpeed - S.Brake * dt)
			else
				dir = safeUnit(dir:Lerp(move, MathUtil.expAlpha(S.TurnRate, dt)), dir)
			end
			v = dir * hSpeed + Vector3.new(0, v.Y, 0)
		end
		v += projectOnPlane(move, ropeDir) * S.SteerAccel * dt
	end

	-- Pump: speed up through the bottom of the arc, but only when swinging the way you're facing.
	local tangent = projectOnPlane(v, ropeDir)
	local lowness = math.clamp(ropeDir.Y, 0, 1) -- 1 when hanging straight down
	if tangent.Magnitude > 1 and flat(tangent):Dot(self:_heading()) > 0 then
		v += tangent.Unit * S.PumpAccel * lowness * lowness * dt
	end
	self.motion.lowness = lowness

	-- Whoosh + a little shake each time you sweep through the bottom of the arc fast.
	if lowness > 0.92 then
		local speedNow = v.Magnitude
		if not self.wasAtBottom and speedNow > Config.Effects.BottomWhooshMinSpeed then
			self.effects:Whoosh(speedNow)
			self.camera:Shake(Config.Effects.BottomShake)
		end
		self.wasAtBottom = true
	elseif lowness < 0.8 then
		self.wasAtBottom = false
	end

	-- The web: you can't move further away than its length.
	local correction = Vector3.zero
	if distance > self.ropeLength then
		local radial = v:Dot(ropeDir) -- positive = moving toward anchor
		if radial < 0 then
			v -= ropeDir * radial
		end
		local stretch = distance - self.ropeLength
		correction = ropeDir * math.min(stretch * S.RopeStiffness, S.MaxCorrectionSpeed)
	end

	v = self:_avoidWalls(pos, v, dt)

	-- Soft speed cap
	local speed = v.Magnitude
	if speed > S.MaxSpeed then
		v = v.Unit * (speed + (S.MaxSpeed - speed) * MathUtil.expAlpha(4, dt))
	end

	self.velocity = v
	local commanded = v + correction
	self.lastCommanded = commanded
	self.driver.VectorVelocity = commanded

	-- Lean into the web: body "up" points at the anchor, facing the direction of travel.
	local forward = projectOnPlane(v, ropeDir)
	if forward.Magnitude < 2 then
		forward = projectOnPlane(self:_heading(), ropeDir)
	end
	if forward.Magnitude > 1e-3 then
		self.lean.CFrame = CFrame.lookAt(Vector3.zero, forward.Unit, ropeDir)
	end

	-- Touching down ends the swing (not right after starting one from the ground).
	if v.Y < 0 and self.swingTime > S.StartGraceTime then
		local hit = workspace:Raycast(pos, Vector3.new(0, -S.LandCheckDistance, 0), ctx.WorldParams)
		if hit then
			self.fsm:Set("Air")
		end
	end
end

function SwingController:_release()
	local v = self.velocity
	local pos = self.ctx.Root.Position

	-- "Perfect" = rising and already past the anchor, i.e. at the front of the arc.
	local pastAnchor = flat(pos - self:_pivot()):Dot(flat(v)) > 0
	local perfect = v.Y > S.PerfectMinUpSpeed and pastAnchor

	local forwardBoost = S.ReleaseForwardBoost
	local upBoost = S.ReleaseUpBoost
	if perfect then
		forwardBoost *= S.PerfectMultiplier
		upBoost *= S.PerfectMultiplier
	end

	local forward = safeUnit(flat(v), Vector3.zero)
	v += forward * forwardBoost + Vector3.new(0, upBoost, 0)

	self.releaseVelocity = MathUtil.clampMagnitude(v, S.MaxReleaseSpeed)
	self.perfectRelease = perfect
	self.effects:Release(perfect)
	if perfect then
		self.motion.flipStart = os.clock()
		self.camera:Shake(Config.Effects.PerfectShake)
	end
	self.fsm:Set("Air")
end

function SwingController:_exit(_nextState: string)
	local ctx = self.ctx
	local humanoid = ctx.Humanoid

	self.driver.Enabled = false
	self.lean.Enabled = false
	self.visuals:Detach()
	self.motion.pivot = nil
	self.motion.lowness = 0

	local finalVelocity = self.releaseVelocity or self.velocity
	ctx.Root.AssemblyLinearVelocity = finalVelocity

	humanoid.AutoRotate = true
	if ctx:IsAlive() then
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	end

	if self.releaseVelocity then
		local C = Config.Camera
		self.camera:Kick(if self.perfectRelease then C.PerfectKick else C.ReleaseKick)
	end

	self.cooldownUntil = os.clock() + S.ReattachCooldown
end

function SwingController:Destroy()
	if self.fsm:Is("Swing") then
		self.ctx.Humanoid.AutoRotate = true
		self.visuals:Detach()
	end
	self.cleaner:Clean()
end

return SwingController
