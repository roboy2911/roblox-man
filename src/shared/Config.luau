--!strict
-- Every tuning number for the game lives here, so the feel can be adjusted in one place.

local Config = {}

Config.Swing = {
	-- Finding where the web sticks
	MaxWebLength = 240, -- furthest a web can reach (studs)
	MinWebLength = 25, -- webs shorter than this feel cramped, so they're ignored
	MinAnchorHeight = 18, -- anchor must be at least this far above you
	IdealForward = 75, -- the "perfect" anchor is this far ahead...
	IdealUp = 85, -- ...and this far up
	SearchYaw = { -45, -25, -10, 0, 10, 25, 45 }, -- degrees left/right of your heading to scan
	SearchPitch = { 25, 40, 55, 70 }, -- degrees above the horizon to scan

	-- Pendulum physics
	Gravity = 150, -- a little lighter than world gravity so swings feel big and floaty at the top
	SteerAccel = 45, -- how hard movement keys push you sideways while swinging
	PumpAccel = 75, -- extra speed gained at the bottom of the arc (the "whoosh")
	AttachKick = 18, -- small push along the swing direction when the web connects
	GroundLaunchSpeed = 60, -- upward pop when you start a swing from the ground
	InitialSnap = 0.93, -- web starts slightly shorter than the distance, so it yanks you on connect
	RopeStiffness = 9, -- how quickly a stretched web pulls you back to its length
	MaxCorrectionSpeed = 45, -- limit on that pull, so the yank is punchy but not violent
	MinRopeLength = 15,
	ReelSpeed = 70, -- how fast the web shortens to keep you off the ground
	GroundClearance = 10, -- lowest point of the swing stays this high above the floor
	MaxSpeed = 170,
	CollisionTolerance = 20, -- if real velocity differs this much from ours, we hit something
	TurnResponsiveness = 18, -- how quickly the body leans into the swing
	LandCheckDistance = 3.4, -- touching ground this close ends the swing
	ReattachCooldown = 0.12,

	-- Letting go
	ReleaseForwardBoost = 22,
	ReleaseUpBoost = 28,
	PerfectMinUpSpeed = 15, -- releasing while rising past the bottom counts as "perfect"
	PerfectMultiplier = 1.5,
	MaxReleaseSpeed = 190,
}

Config.Air = {
	MomentumThreshold = 4, -- only keep momentum when faster than WalkSpeed + this
	Drag = 0.25, -- how quickly air speed bleeds off (per second, exponential)
	SteerRate = 2.5, -- how quickly you can curve your flight with movement keys
	Brake = 60, -- deceleration when holding the opposite direction
	ForceLimit = 1e6,
}

Config.Camera = {
	BaseFov = 70,
	MaxFov = 100,
	FovMinSpeed = 30, -- FOV starts widening above this speed
	FovMaxSpeed = 170, -- and is fully wide at this speed
	Smoothing = 6,
	AttachKick = 3,
	ReleaseKick = 6,
	PerfectKick = 11,
	KickDecay = 5,
}

Config.Web = {
	ShootTime = 0.08, -- seconds for the web to fly from hand to anchor
	Width0 = 0.12,
	Width1 = 0.22,
	Color = Color3.fromRGB(245, 245, 255),
	ImpactColor = Color3.fromRGB(255, 255, 255),
	ImpactSize = 3,
	ImpactTime = 0.25,
}

Config.Input = {
	Swing = {
		Inputs = { Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2 } :: { any },
		Title = "Web",
	},
}

Config.City = {
	Seed = 1337,
	GridSize = 8, -- blocks per side
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
	BuildingColors = {
		Color3.fromRGB(120, 125, 135),
		Color3.fromRGB(165, 160, 150),
		Color3.fromRGB(95, 105, 120),
		Color3.fromRGB(140, 145, 155),
		Color3.fromRGB(110, 100, 95),
		Color3.fromRGB(180, 182, 188),
	},
	BuildingMaterials = {
		Enum.Material.Concrete,
		Enum.Material.SmoothPlastic,
		Enum.Material.Slate,
	},
}

Config.Character = {
	Suit = Color3.fromRGB(26, 26, 32),
	SuitLight = Color3.fromRGB(44, 44, 54),
	Accent = Color3.fromRGB(220, 30, 45),
	Eye = Color3.fromRGB(255, 255, 255),
	Metal = Color3.fromRGB(60, 62, 72),
}

return Config
