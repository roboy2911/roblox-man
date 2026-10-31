-- Builds a gray-box test city at runtime: a grid of streets and towers of different heights.
-- Buildings go in workspace.City.Buildings, which is the only thing webs can stick to.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local CityBuilder = {}

local function block(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function buildTower(parent: Instance, rng: Random, x: number, z: number, width: number, depth: number, heightScale: number)
	local C = Config.City
	local base = C.CurbHeight
	local height = (C.MinHeight + (C.MaxHeight - C.MinHeight) * rng:NextNumber() ^ 1.5) * heightScale
	height = math.max(height, C.MinHeight * 0.8)

	local color = C.BuildingColors[rng:NextInteger(1, #C.BuildingColors)]
	local material = C.BuildingMaterials[rng:NextInteger(1, #C.BuildingMaterials)]

	local tower = Instance.new("Model")
	tower.Name = "Tower"

	block(tower, "Body", Vector3.new(width, height, depth), CFrame.new(x, base + height / 2, z), color, material)

	-- Ledges wrapping each "floor" give a sense of speed as you fly past, and extra spots to web onto.
	local ledgeY = C.FloorSpacing
	while ledgeY < height - 10 do
		block(
			tower,
			"Ledge",
			Vector3.new(width + 1.5, 1.2, depth + 1.5),
			CFrame.new(x, base + ledgeY, z),
			C.LedgeColor,
			Enum.Material.Concrete
		)
		ledgeY += C.FloorSpacing
	end

	-- Roof rim
	block(
		tower,
		"Roof",
		Vector3.new(width + 3, 2, depth + 3),
		CFrame.new(x, base + height + 1, z),
		C.LedgeColor,
		Enum.Material.Concrete
	)

	-- Tall towers sometimes get a narrower top tier.
	if height > 120 and rng:NextNumber() < 0.6 then
		local tierW = width * rng:NextNumber(0.55, 0.8)
		local tierD = depth * rng:NextNumber(0.55, 0.8)
		local tierH = height * rng:NextNumber(0.2, 0.45)
		block(
			tower,
			"Tier",
			Vector3.new(tierW, tierH, tierD),
			CFrame.new(x, base + height + 2 + tierH / 2, z),
			color,
			material
		)
	end

	tower.Parent = parent
end

local function buildBlock(parent: Instance, rng: Random, cx: number, cz: number, heightScale: number)
	local C = Config.City
	local size = C.BlockSize
	local inset = C.LotInset
	local split = rng:NextInteger(1, 3)

	if split == 1 then
		buildTower(parent, rng, cx, cz, size - inset * 2, size - inset * 2, heightScale)
	elseif split == 2 then
		-- Two towers side by side, split along a random axis.
		local half = size / 2
		local alongX = rng:NextNumber() < 0.5
		for side = -1, 1, 2 do
			local ox = if alongX then side * half / 2 else 0
			local oz = if alongX then 0 else side * half / 2
			local w = if alongX then half - inset * 1.5 else size - inset * 2
			local d = if alongX then size - inset * 2 else half - inset * 1.5
			buildTower(parent, rng, cx + ox, cz + oz, w, d, heightScale)
		end
	else
		-- Four towers, one per corner.
		local quarter = size / 4
		local lot = size / 2 - inset * 1.5
		for sx = -1, 1, 2 do
			for sz = -1, 1, 2 do
				buildTower(parent, rng, cx + sx * quarter, cz + sz * quarter, lot, lot, heightScale)
			end
		end
	end
end

local function setupLighting()
	Lighting.ClockTime = 16.5
	Lighting.Brightness = 2.5
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 140, 150)

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(199, 210, 225)
	atmosphere.Decay = Color3.fromRGB(106, 112, 125)
	atmosphere.Glare = 0.3
	atmosphere.Haze = 1.8
	atmosphere.Parent = Lighting
end

function CityBuilder.Build(): Folder
	local existing = workspace:FindFirstChild("City")
	if existing then
		return existing :: Folder
	end

	local C = Config.City
	local rng = Random.new(C.Seed)

	local city = Instance.new("Folder")
	city.Name = "City"
	local streets = Instance.new("Folder")
	streets.Name = "Streets"
	streets.Parent = city
	local buildings = Instance.new("Folder")
	buildings.Name = "Buildings"
	buildings.Parent = city

	local pitch = C.BlockSize + C.RoadWidth
	local span = C.GridSize * pitch + C.RoadWidth
	local half = span / 2

	block(
		streets,
		"Ground",
		Vector3.new(span + C.Margin * 2, 4, span + C.Margin * 2),
		CFrame.new(0, -2, 0),
		C.RoadColor,
		Enum.Material.Asphalt
	)

	local center = (C.GridSize - 1) / 2
	local maxDist = math.sqrt(2) * center
	local plaza = math.floor(C.GridSize / 2)

	for gx = 0, C.GridSize - 1 do
		for gz = 0, C.GridSize - 1 do
			local cx = -half + C.RoadWidth + gx * pitch + C.BlockSize / 2
			local cz = -half + C.RoadWidth + gz * pitch + C.BlockSize / 2

			block(
				streets,
				"Sidewalk",
				Vector3.new(C.BlockSize, C.CurbHeight, C.BlockSize),
				CFrame.new(cx, C.CurbHeight / 2, cz),
				C.SidewalkColor,
				Enum.Material.Concrete
			)

			if gx == plaza and gz == plaza then
				-- Open plaza surrounded by the tallest towers: a good place to start swinging.
				local spawn = Instance.new("SpawnLocation")
				spawn.Name = "Spawn"
				spawn.Anchored = true
				spawn.Neutral = true
				spawn.Duration = 0
				spawn.Size = Vector3.new(14, 1, 14)
				spawn.CFrame = CFrame.new(cx, C.CurbHeight + 0.5, cz)
				spawn.Color = Config.Character.Accent
				spawn.Material = Enum.Material.SmoothPlastic
				spawn.TopSurface = Enum.SurfaceType.Smooth
				spawn.Parent = streets
			else
				-- Taller in the middle of the city, shorter at the edges.
				local d = math.sqrt((gx - center) ^ 2 + (gz - center) ^ 2) / maxDist
				local heightScale = 1 - d * 0.6
				buildBlock(buildings, rng, cx, cz, heightScale)
			end
		end
	end

	-- Studio's template spawn would compete with the plaza spawn.
	local templateSpawn = workspace:FindFirstChild("SpawnLocation")
	if templateSpawn and templateSpawn:IsA("SpawnLocation") then
		templateSpawn:Destroy()
	end

	setupLighting()
	city.Parent = workspace
	return city
end

return CityBuilder
