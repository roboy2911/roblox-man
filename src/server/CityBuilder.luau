-- Builds the city at runtime: a grid of streets, towers in several styles with rooftop props,
-- streetlights, lane lines, parks and nice lighting.
-- Buildings (and their rooftop props) go in workspace.City.Buildings, which is the only thing
-- webs can stick to.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local C = Config.City

local CityBuilder = {}

local function block(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material
): Part
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

-- Small decorative parts that nothing needs to collide with.
local function detail(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local part = block(parent, name, size, cframe, color, material)
	part.CanCollide = false
	part.CastShadow = false
	return part
end

local function cylinder(parent: Instance, name: string, height: number, diameter: number, cframe: CFrame, color: Color3, material: Enum.Material): Part
	-- Cylinders run along X, so turn them upright.
	local part = block(parent, name, Vector3.new(height, diameter, diameter), cframe * CFrame.Angles(0, 0, math.rad(90)), color, material)
	part.Shape = Enum.PartType.Cylinder
	return part
end

------------------------------------------------------------------------------------------------
-- Towers

local function pickStyle(rng: Random, height: number)
	local options = {}
	for _, style in C.Styles do
		if height >= style.MinHeight then
			table.insert(options, style)
		end
	end
	-- Taller buildings are more likely to be glass/marble (listed first).
	local index = if height > 150 and rng:NextNumber() < 0.65 then 1 else rng:NextInteger(1, #options)
	return options[math.min(index, #options)]
end

-- Random props on a roof. top = height of the roof surface.
local function buildRoofProps(parent: Instance, rng: Random, x: number, z: number, width: number, depth: number, top: number)
	local function spot(margin: number): (number, number)
		local hx = math.max(width / 2 - margin, 0)
		local hz = math.max(depth / 2 - margin, 0)
		return x + rng:NextNumber(-hx, hx), z + rng:NextNumber(-hz, hz)
	end

	if width > 20 and depth > 20 and rng:NextNumber() < C.WaterTowerChance then
		local px, pz = spot(8)
		local legHeight = 5
		for _, offset in { Vector3.new(2.5, 0, 2.5), Vector3.new(-2.5, 0, 2.5), Vector3.new(2.5, 0, -2.5), Vector3.new(-2.5, 0, -2.5) } do
			block(parent, "WaterTowerLeg", Vector3.new(0.6, legHeight, 0.6), CFrame.new(px + offset.X, top + legHeight / 2, pz + offset.Z), Color3.fromRGB(60, 55, 50), Enum.Material.Metal)
		end
		cylinder(parent, "WaterTower", 8, 7.5, CFrame.new(px, top + legHeight + 4, pz), Color3.fromRGB(120, 85, 60), Enum.Material.WoodPlanks)
		cylinder(parent, "WaterTowerCap", 1, 8, CFrame.new(px, top + legHeight + 8.5, pz), Color3.fromRGB(70, 60, 55), Enum.Material.Metal)
	end

	if rng:NextNumber() < C.AcUnitChance then
		for _ = 1, rng:NextInteger(1, 3) do
			local px, pz = spot(4)
			block(parent, "AcUnit", Vector3.new(4, 3, 3), CFrame.new(px, top + 1.5, pz), Color3.fromRGB(170, 172, 175), Enum.Material.Metal)
			local fan = cylinder(parent, "AcFan", 0.2, 2.2, CFrame.new(px, top + 3.05, pz), Color3.fromRGB(40, 40, 45), Enum.Material.Metal)
			fan.CanCollide = false
		end
	end

	if width > 14 and rng:NextNumber() < C.RoofHutChance then
		local px, pz = spot(6)
		block(parent, "RoofHut", Vector3.new(8, 7, 8), CFrame.new(px, top + 3.5, pz), Color3.fromRGB(130, 130, 135), Enum.Material.Concrete)
		detail(parent, "RoofDoor", Vector3.new(2.5, 5, 0.2), CFrame.new(px, top + 2.5, pz - 4.05), Color3.fromRGB(50, 50, 55), Enum.Material.Metal)
	end

	if top > C.AntennaMinHeight and rng:NextNumber() < C.AntennaChance then
		local px, pz = spot(3)
		local height = rng:NextNumber(15, 35)
		block(parent, "Antenna", Vector3.new(0.6, height, 0.6), CFrame.new(px, top + height / 2, pz), Color3.fromRGB(150, 150, 155), Enum.Material.Metal)
		local light = detail(parent, "AntennaLight", Vector3.one * 1.2, CFrame.new(px, top + height + 0.4, pz), Color3.fromRGB(255, 40, 40), Enum.Material.Neon)
		light.Shape = Enum.PartType.Ball
	end
end

local function buildTower(parent: Instance, rng: Random, x: number, z: number, width: number, depth: number, heightScale: number)
	local base = C.CurbHeight
	local height = (C.MinHeight + (C.MaxHeight - C.MinHeight) * rng:NextNumber() ^ 1.5) * heightScale
	height = math.max(height, C.MinHeight * 0.8)

	local style = pickStyle(rng, height)
	local color = style.Colors[rng:NextInteger(1, #style.Colors)]

	local tower = Instance.new("Model")
	tower.Name = style.Name .. "Tower"

	local body = block(tower, "Body", Vector3.new(width, height, depth), CFrame.new(x, base + height / 2, z), color, style.Material)
	body.Reflectance = style.Reflectance

	-- Concrete corner pillars frame the glass and marble towers.
	if style.Pillars then
		for sx = -1, 1, 2 do
			for sz = -1, 1, 2 do
				block(tower, "Pillar", Vector3.new(2.5, height, 2.5), CFrame.new(x + sx * width / 2, base + height / 2, z + sz * depth / 2), C.LedgeColor, Enum.Material.Concrete)
			end
		end
	end

	-- Ledges wrapping each "floor" give a sense of speed as you fly past, and extra spots to web onto.
	local ledgeY = C.FloorSpacing
	while ledgeY < height - 10 do
		block(tower, "Ledge", Vector3.new(width + 1.5, 1.2, depth + 1.5), CFrame.new(x, base + ledgeY, z), C.LedgeColor, Enum.Material.Concrete)
		ledgeY += C.FloorSpacing
	end

	-- Roof rim
	block(tower, "Roof", Vector3.new(width + 3, 2, depth + 3), CFrame.new(x, base + height + 1, z), C.LedgeColor, Enum.Material.Concrete)
	local roofTop = base + height + 2

	-- Tall towers sometimes get a narrower top tier.
	if height > 120 and rng:NextNumber() < 0.6 then
		local tierW = width * rng:NextNumber(0.55, 0.8)
		local tierD = depth * rng:NextNumber(0.55, 0.8)
		local tierH = height * rng:NextNumber(0.2, 0.45)
		local tier = block(tower, "Tier", Vector3.new(tierW, tierH, tierD), CFrame.new(x, roofTop + tierH / 2, z), color, style.Material)
		tier.Reflectance = style.Reflectance
		block(tower, "TierRoof", Vector3.new(tierW + 2, 1.5, tierD + 2), CFrame.new(x, roofTop + tierH + 0.75, z), C.LedgeColor, Enum.Material.Concrete)
		buildRoofProps(tower, rng, x, z, tierW, tierD, roofTop + tierH + 1.5)
	else
		buildRoofProps(tower, rng, x, z, width, depth, roofTop)
	end

	tower.Parent = parent
end

local function buildBlock(parent: Instance, rng: Random, cx: number, cz: number, heightScale: number)
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

------------------------------------------------------------------------------------------------
-- Streets

local function buildTree(parent: Instance, rng: Random, x: number, z: number, groundY: number)
	local trunkHeight = rng:NextNumber(5, 8)
	block(parent, "Trunk", Vector3.new(1.2, trunkHeight, 1.2), CFrame.new(x, groundY + trunkHeight / 2, z), C.TrunkColor, Enum.Material.Wood)
	local leafSize = rng:NextNumber(7, 11)
	local leaves = block(parent, "Leaves", Vector3.one * leafSize, CFrame.new(x, groundY + trunkHeight + leafSize * 0.35, z), C.LeafColors[rng:NextInteger(1, #C.LeafColors)], Enum.Material.Grass)
	leaves.Shape = Enum.PartType.Ball
end

local function buildPark(parent: Instance, rng: Random, cx: number, cz: number)
	local top = C.CurbHeight
	detail(parent, "Grass", Vector3.new(C.BlockSize - 6, 0.2, C.BlockSize - 6), CFrame.new(cx, top + 0.1, cz), C.GrassColor, Enum.Material.Grass)
	-- A cross-shaped path
	detail(parent, "Path", Vector3.new(C.BlockSize - 6, 0.25, 6), CFrame.new(cx, top + 0.12, cz), C.SidewalkColor, Enum.Material.Concrete)
	detail(parent, "Path", Vector3.new(6, 0.25, C.BlockSize - 6), CFrame.new(cx, top + 0.12, cz), C.SidewalkColor, Enum.Material.Concrete)
	local half = C.BlockSize / 2 - 10
	for _ = 1, rng:NextInteger(5, 8) do
		local x = rng:NextNumber(-half, half)
		local z = rng:NextNumber(-half, half)
		if math.abs(x) > 6 and math.abs(z) > 6 then -- keep trees off the paths
			buildTree(parent, rng, cx + x, cz + z, top)
		end
	end
end

local function buildStreetlight(parent: Instance, x: number, z: number, facing: Vector3)
	local height = 16
	local top = C.CurbHeight
	block(parent, "LampPost", Vector3.new(0.7, height, 0.7), CFrame.new(x, top + height / 2, z), C.StreetlightColor, Enum.Material.Metal)
	local head = x * Vector3.xAxis + z * Vector3.zAxis + facing * 2.5
	detail(parent, "Lamp", Vector3.new(2.5, 0.5, 1.2), CFrame.lookAt(Vector3.new(head.X, top + height, head.Z), Vector3.new(head.X, top + height, head.Z) + facing), C.LampColor, Enum.Material.Neon)
end

local function setupLighting()
	Lighting.ClockTime = 16.5
	Lighting.Brightness = 2.5
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 140, 150)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1 -- lets glass towers reflect the sky

	local function effect(className: string): Instance
		local existing = Lighting:FindFirstChildOfClass(className)
		if existing then
			return existing
		end
		local created = Instance.new(className)
		created.Parent = Lighting
		return created
	end

	local atmosphere = effect("Atmosphere") :: Atmosphere
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(199, 210, 225)
	atmosphere.Decay = Color3.fromRGB(106, 112, 125)
	atmosphere.Glare = 0.3
	atmosphere.Haze = 1.8

	local bloom = effect("BloomEffect") :: BloomEffect
	bloom.Intensity = 0.6
	bloom.Size = 24
	bloom.Threshold = 0.95

	local color = effect("ColorCorrectionEffect") :: ColorCorrectionEffect
	color.Saturation = 0.1
	color.Contrast = 0.08

	local sunRays = effect("SunRaysEffect") :: SunRaysEffect
	sunRays.Intensity = 0.06
	sunRays.Spread = 0.8
end

function CityBuilder.Build(): Folder
	local existing = workspace:FindFirstChild("City")
	if existing then
		return existing :: Folder
	end

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

	block(streets, "Ground", Vector3.new(span + C.Margin * 2, 4, span + C.Margin * 2), CFrame.new(0, -2, 0), C.RoadColor, Enum.Material.Asphalt)

	-- Yellow center line down every road
	for i = 0, C.GridSize do
		local roadCenter = -half + i * pitch + C.RoadWidth / 2
		detail(streets, "LaneLine", Vector3.new(span, 0.1, 0.6), CFrame.new(0, 0.05, roadCenter), C.LaneColor, Enum.Material.SmoothPlastic)
		detail(streets, "LaneLine", Vector3.new(0.6, 0.1, span), CFrame.new(roadCenter, 0.05, 0), C.LaneColor, Enum.Material.SmoothPlastic)
	end

	local plaza = math.floor(C.GridSize / 2)
	local gridSpan = math.max(C.GridSize - 1, 1)

	-- Tallest near a downtown cluster, shorter in between.
	local function heightScaleAt(gx: number, gz: number): number
		local best = C.MinHeightScale
		for _, hub in C.Hubs do
			local dx = gx / gridSpan - hub.X
			local dz = gz / gridSpan - hub.Z
			local falloff = math.clamp(math.sqrt(dx * dx + dz * dz) / C.HubRadius, 0, 1)
			best = math.max(best, hub.Strength * (1 - falloff * 0.65))
		end
		return best
	end

	for gx = 0, C.GridSize - 1 do
		for gz = 0, C.GridSize - 1 do
			local cx = -half + C.RoadWidth + gx * pitch + C.BlockSize / 2
			local cz = -half + C.RoadWidth + gz * pitch + C.BlockSize / 2

			block(streets, "Sidewalk", Vector3.new(C.BlockSize, C.CurbHeight, C.BlockSize), CFrame.new(cx, C.CurbHeight / 2, cz), C.SidewalkColor, Enum.Material.Concrete)

			-- One streetlight on a corner of each block, leaning over the road
			local corner = C.BlockSize / 2 - 2
			buildStreetlight(streets, cx + corner, cz + corner, Vector3.xAxis)

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
				for _, offset in { Vector2.new(25, 25), Vector2.new(-25, 25), Vector2.new(25, -25), Vector2.new(-25, -25) } do
					buildTree(streets, rng, cx + offset.X, cz + offset.Y, C.CurbHeight)
				end
			elseif rng:NextNumber() < C.ParkChance then
				buildPark(streets, rng, cx, cz)
			else
				buildBlock(buildings, rng, cx, cz, heightScaleAt(gx, gz))
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
