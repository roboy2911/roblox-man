--!strict
-- Every tuning number for the game lives here, so the feel can be adjusted in one place.

local Config = {}

Config.Swing = {
	-- Finding where the web sticks
	MaxWebLength = 240, -- furthest a web can reach (studs)
	MinWebLength = 40, -- short webs yank you into walls, so they're ignored
	MinAnchorHeight = 25, -- anchor must be at least this far above you
	-- The swing pivots this far out from the wall the web sticks to, so the arc
	-- passes through the street instead of dragging you along the building.
	AnchorWallOffset = 14,
	IdealForward = 75, -- the "perfect" anchor is this far ahead...
	IdealUp = 85, -- ...and this far up
	IdealSide = 28, -- ...and this far to one side (alternates left/right, or toward your turn)
	IdealLength = 100, -- preferred web length; much shorter or longer webs score worse
	LengthPenalty = 0.35, -- how strongly web length matters when picking
	TurnSideThreshold = 0.2, -- how much you need to be turning before webs favor that side
	SearchYaw = { -60, -45, -25, -10, 0, 10, 25, 45, 60 }, -- degrees left/right of your heading to scan
	SearchPitch = { 25, 40, 55, 70 }, -- degrees above the horizon to scan

	-- Pendulum physics
	Gravity = 135, -- a little lighter than world gravity so swings feel big and floaty at the top
	TurnRate = 4, -- how quickly WASD turns your swing direction (higher = sharper turns)
	SteerAccel = 30, -- extra sideways push from movement keys
	Brake = 50, -- deceleration when holding the opposite direction mid-swing
	PumpAccel = 45, -- extra speed gained at the bottom of the arc (the "whoosh")
	AttachKick = 12, -- small push along the swing direction when the web connects
	GroundLaunchSpeed = 60, -- upward pop when you start a swing from the ground
	InitialSnap = 0.98, -- web starts slightly shorter than the distance, for a light tug on connect
	RopeStiffness = 8, -- how quickly a stretched web pulls you back to its length
	MaxCorrectionSpeed = 30, -- limit on that pull
	-- When the web goes taut, this fraction of the speed it would cancel is redirected along the
	-- arc instead. Chained swings keep their speed and feel smooth instead of jerky.
	RedirectEfficiency = 0.85,
	SteerLean = 0.35, -- how much the body banks when steering mid-swing
	DiveCatchMinFallSpeed = 50, -- catching a web while diving this fast gives a bonus
	DiveCatchBoost = 18,
	SwingStyles = { "Tuck", "Superman", "Kick" }, -- a random pose style is picked per swing
	MinRopeLength = 15,
	ReelSpeed = 70, -- how fast the web shortens to keep you off the ground
	GroundClearance = 10, -- lowest point of the swing stays this high above the floor
	MaxSpeed = 120,
	CollisionTolerance = 20, -- if real velocity differs this much from ours, we hit something
	TurnResponsiveness = 10, -- how quickly the body leans into the swing
	LandCheckDistance = 3.4, -- touching ground this close ends the swing
	StartGraceTime = 0.3, -- seconds after a web connects before collisions/landing can end the swing
	ReattachCooldown = 0.12,

	-- Wall avoidance: walls near you gently push you away and turn crashes into glancing slides
	WallLookAhead = 0.3, -- seconds of travel to check ahead for walls
	WallMinCheck = 8,
	WallMaxCheck = 35,
	WallSideCheck = 10, -- how far to check left and right
	WallPush = 60,

	-- Web wrapping around building corners
	MaxWraps = 6, -- most corners one web can bend around
	WrapOffset = 0.75, -- how far out from the corner the web bends, so it doesn't clip
	MinWrapSpacing = 2, -- ignore a new corner this close to the last one
	UnwrapDelay = 0.1, -- seconds before a fresh bend can unwrap (stops flickering)

	-- Letting go
	ReleaseForwardBoost = 14,
	ReleaseUpBoost = 22,
	PerfectMinUpSpeed = 15, -- releasing while rising past the bottom counts as "perfect"
	PerfectMultiplier = 1.3,
	MaxReleaseSpeed = 140,
}

Config.Landing = {
	RollMinSpeed = 55, -- land faster than this and you roll out of it
	RollTime = 0.45,
	SlideTime = 0.5, -- after a fast landing you keep sliding forward this long
	SlideKeep = 0.6, -- fraction of horizontal speed kept as the slide
	DustMinSpeed = 35,
}

Config.Air = {
	MomentumThreshold = 4, -- only keep momentum when faster than WalkSpeed + this
	Drag = 0.45, -- how quickly air speed bleeds off (per second, exponential)
	SteerRate = 5, -- how quickly you can curve your flight with movement keys
	Brake = 80, -- deceleration when holding the opposite direction
	ForceLimit = 1e6,
}

Config.Camera = {
	BaseFov = 70,
	MaxFov = 90,
	FovMinSpeed = 30, -- FOV starts widening above this speed
	FovMaxSpeed = 120, -- and is fully wide at this speed
	Smoothing = 6,
	AttachKick = 2,
	ReleaseKick = 4,
	PerfectKick = 8,
	KickDecay = 5,
	ShakeDecay = 6,
	ShakeStrength = 1.2, -- camera offset at full shake (studs, roughly)
	ShakeFrequency = 18,

	-- Auto-follow: when you aren't moving the camera, it turns to face where you're flying
	AutoFollowDelay = 1.0, -- seconds after you last moved the camera
	AutoFollowSpeed = 1.6,
	AutoFollowMinSpeed = 40,
	RollMax = 6, -- degrees the camera tilts in turns
	RollSmoothing = 4,
}

Config.Web = {
	ShootTime = 0.08, -- seconds for the web to fly from hand to anchor
	CoreWidth0 = 0.22, -- at the anchor
	CoreWidth1 = 0.12, -- at the hand
	GlowWidth = 0.7,
	GlowTransparency = 0.8,
	Color = Color3.fromRGB(245, 245, 255),
	GlowColor = Color3.fromRGB(200, 225, 255),
	ImpactColor = Color3.fromRGB(255, 255, 255),
	ImpactSize = 3,
	ImpactTime = 0.25,
	WobbleAmplitude = 3, -- web wobbles side to side right after it connects
	WobbleFrequency = 18,
	WobbleDecay = 6,
	SagFactor = 0.6, -- how much a slack web droops
	RemnantTime = 0.5, -- a let-go web strand falls away for this long
}

Config.Input = {
	Swing = {
		Inputs = { Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2 } :: { any },
		Title = "Web",
	},
	Zip = {
		Inputs = { Enum.KeyCode.E, Enum.KeyCode.ButtonL1 } :: { any },
		Title = "Zip",
	},
	Dive = {
		Inputs = { Enum.KeyCode.Q, Enum.KeyCode.ButtonL2 } :: { any },
		Title = "Dive",
	},
}

Config.Tricks = {
	-- Web zip: shoot a web where the camera aims and get yanked to it
	ZipRange = 220,
	ZipSpeed = 160,
	ZipAccelTime = 0.12, -- seconds to reach full zip speed
	ZipArriveDistance = 6,
	ZipMaxTime = 2,
	ZipEndPop = 45, -- upward pop at the end, so you hop over ledges
	ZipExitCarry = 0.45, -- fraction of zip speed you keep afterwards
	ZipCooldown = 0.5,
	ZipKick = 6, -- camera FOV kick

	-- Double jump (with a front flip)
	AirJumps = 1,
	AirJumpPower = 65,
	AirJumpMinAirTime = 0.12, -- must be airborne this long first
	FlipTime = 0.55,

	-- Zip aim assist: if the crosshair just misses a building, search a small cone around it
	ZipAssistAngle = 8, -- degrees
	-- Point launch: press jump right as a zip ends for a big launch
	PointLaunchWindow = 0.3, -- seconds around the end of the zip
	PointLaunchForward = 70,
	PointLaunchUp = 85,

	-- Dive: fall faster and turn that into forward speed for the next web
	DiveGravity = 120,
	DiveForwardAccel = 40,
	DiveMaxSpeed = 140,
}

Config.WallRun = {
	MinSpeed = 35, -- need this much speed to start a wall run
	CheckDistance = 3.5, -- how close a wall must be
	MaxAngle = 0.55, -- how head-on you can hit the wall and still run (0 = parallel only)
	Duration = 1.6, -- longest wall run
	Lift = 25, -- upward speed when starting
	Gravity = 30, -- light gravity while running
	Drag = 0.15,
	MinStaySpeed = 25,
	Stick = 8, -- pull toward the wall
	JumpOut = 50, -- wall jump: push away from the wall...
	JumpUp = 60, -- ...upward...
	JumpForwardKeep = 0.85, -- ...and keep this much forward speed
	Cooldown = 0.4,
}

Config.HUD = {
	Font = Enum.Font.GothamBlack,
	TextColor = Color3.fromRGB(255, 255, 255),
	AccentColor = Color3.fromRGB(220, 30, 45),
	SpeedMeterMax = 150,
	ChainMin = 2, -- show the chain counter from this many moves
	HelpKey = Enum.KeyCode.H,
}

Config.Pose = {
	Blend = 12, -- how quickly limbs move to a new pose
	WeightBlend = 10, -- how quickly poses fade in and out
	FallPoseMinSpeed = 35, -- spread-out falling pose starts above this speed
	FallPoseMaxSpeed = 100,
}

Config.Effects = {
	-- Sounds are off (empty Id) until real ones are picked. To add one, find a sound in the
	-- Creator Store (Toolbox -> Audio), copy its ID and put it in as "rbxassetid://123456".
	Sounds = {
		Shoot = { Id = "", Volume = 0.35, Speed = 1 }, -- web fires
		Stick = { Id = "", Volume = 0.3, Speed = 1 }, -- web hits a building
		Release = { Id = "", Volume = 0.3, Speed = 1 }, -- letting go of a swing
		Whoosh = { Id = "", Volume = 0.22, Speed = 1 }, -- passing the bottom of a fast swing
		Zip = { Id = "", Volume = 0.45, Speed = 1 }, -- web zip
		AirJump = { Id = "", Volume = 0.5, Speed = 1 }, -- double jump
		Wind = { Id = "", Volume = 0.6, Speed = 1 }, -- looping wind, louder with speed
	},
	WindMinSpeed = 40,
	WindMaxSpeed = 140,
	SpeedLinesMinSpeed = 70,
	SpeedLinesMaxSpeed = 150,
	SpeedLineCount = 28,
	TrailMinSpeed = 80,
	BottomWhooshMinSpeed = 60, -- whoosh + shake when passing the bottom of a swing this fast
	BottomShake = 0.35,
	PerfectShake = 0.5,
}

Config.City = {
	Seed = 1337,
	GridSize = 24, -- blocks per side
	-- Downtown clusters with the tallest towers, so every part of the city is swingable.
	-- X/Z are positions across the city (0 = one edge, 1 = the other), Strength scales height.
	Hubs = {
		{ X = 0.5, Z = 0.5, Strength = 1.0 },
		{ X = 0.18, Z = 0.22, Strength = 0.85 },
		{ X = 0.82, Z = 0.2, Strength = 0.8 },
		{ X = 0.2, Z = 0.8, Strength = 0.8 },
		{ X = 0.8, Z = 0.78, Strength = 0.9 },
	},
	HubRadius = 0.3, -- how far each cluster's tall buildings spread (fraction of the city)
	MinHeightScale = 0.4, -- buildings between clusters are at least this tall (relative)
	BlockSize = 90,
	RoadWidth = 45,
	Margin = 300, -- extra ground around the city
	CurbHeight = 1,
	LotInset = 6,
	MinHeight = 50,
	MaxHeight = 340,
	FloorSpacing = 40, -- distance between the ledges that wrap each building
	RoadColor = Color3.fromRGB(45, 46, 52),
	SidewalkColor = Color3.fromRGB(150, 150, 155),
	LedgeColor = Color3.fromRGB(85, 88, 98),
	-- Building styles. Tall towers lean toward Glass/Marble, short ones toward Brick/Concrete.
	Styles = {
		{
			Name = "Glass",
			Material = Enum.Material.Glass,
			Colors = { Color3.fromRGB(70, 95, 120), Color3.fromRGB(85, 110, 125), Color3.fromRGB(60, 80, 100) },
			Reflectance = 0.15,
			Pillars = true,
			MinHeight = 120,
		},
		{
			Name = "Marble",
			Material = Enum.Material.Marble,
			Colors = { Color3.fromRGB(210, 205, 195), Color3.fromRGB(190, 190, 185) },
			Reflectance = 0,
			Pillars = true,
			MinHeight = 90,
		},
		{
			Name = "Concrete",
			Material = Enum.Material.Concrete,
			Colors = { Color3.fromRGB(150, 150, 155), Color3.fromRGB(120, 125, 135), Color3.fromRGB(170, 165, 155) },
			Reflectance = 0,
			Pillars = false,
			MinHeight = 0,
		},
		{
			Name = "Brick",
			Material = Enum.Material.Brick,
			Colors = { Color3.fromRGB(140, 75, 60), Color3.fromRGB(120, 85, 70), Color3.fromRGB(160, 100, 80) },
			Reflectance = 0,
			Pillars = false,
			MinHeight = 0,
		},
	},

	-- Rooftop props (chance per roof)
	WaterTowerChance = 0.3,
	AcUnitChance = 0.5,
	AntennaChance = 0.6, -- only on roofs taller than AntennaMinHeight
	AntennaMinHeight = 200,
	RoofHutChance = 0.35,

	-- Streets
	ParkChance = 0.06, -- chance a block is a park instead of buildings
	LaneColor = Color3.fromRGB(230, 200, 60),
	StreetlightColor = Color3.fromRGB(55, 58, 65),
	LampColor = Color3.fromRGB(255, 235, 190),
	GrassColor = Color3.fromRGB(85, 140, 70),
	TrunkColor = Color3.fromRGB(95, 70, 50),
	LeafColors = { Color3.fromRGB(70, 130, 60), Color3.fromRGB(90, 150, 70), Color3.fromRGB(60, 115, 55) },
}

Config.Character = {
	Suit = Color3.fromRGB(26, 26, 32),
	SuitLight = Color3.fromRGB(44, 44, 54),
	Accent = Color3.fromRGB(220, 30, 45),
	Eye = Color3.fromRGB(255, 255, 255),
	Metal = Color3.fromRGB(60, 62, 72),
}

return Config
