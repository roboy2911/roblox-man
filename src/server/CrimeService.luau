-- Crimes: every so often a gang of thugs shows up on a sidewalk near a player, marked with a
-- red "!" visible across the city. Thugs chase and punch nearby players. Knock them all out
-- to stop the crime: everyone who helped gets coins and XP.
--
-- Combat is handled here too: when a player punches, the server checks which thugs are in
-- front of them and in reach. Punching while moving fast (swinging in) knocks a thug out in one hit.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CityBuilder = require(script.Parent.CityBuilder)
local DataService = require(script.Parent.DataService)

local CR = Config.Crime
local CB = Config.Combat
local PR = Config.Progression

local HOODIES = {
	Color3.fromRGB(70, 70, 75),
	Color3.fromRGB(110, 30, 35),
	Color3.fromRGB(70, 80, 50),
	Color3.fromRGB(40, 50, 80),
	Color3.fromRGB(90, 60, 40),
}
local PANTS = { Color3.fromRGB(40, 55, 90), Color3.fromRGB(30, 30, 35), Color3.fromRGB(80, 75, 65) }
local SKINS = {
	Color3.fromRGB(234, 184, 146),
	Color3.fromRGB(204, 142, 105),
	Color3.fromRGB(160, 105, 75),
	Color3.fromRGB(105, 70, 50),
	Color3.fromRGB(245, 205, 170),
}

type Thug = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	home: Vector3,
	lastAttack: number,
	dead: boolean,
}

type Crime = {
	model: Model,
	position: Vector3,
	thugs: { Thug },
	participants: { [Player]: boolean },
	started: number,
	finished: boolean,
}

local CrimeService = {}

local crimes: { Crime } = {}
local folder: Folder
local rng = Random.new()

local function pick<T>(list: { T }): T
	return list[rng:NextInteger(1, #list)]
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function aliveRoot(character: Model?): (BasePart?, Humanoid?)
	if not character then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid and root and humanoid.Health > 0 and root:IsA("BasePart") then
		return root, humanoid
	end
	return nil, nil
end

------------------------------------------------------------------------------------------------
-- Spawning

local function makeThug(position: Vector3): (Model?, Humanoid?, BasePart?)
	local desc = Instance.new("HumanoidDescription")
	local skin = pick(SKINS)
	local hoodie = pick(HOODIES)
	local pants = pick(PANTS)
	desc.HeadColor = skin
	desc.TorsoColor = hoodie
	desc.LeftArmColor = hoodie
	desc.RightArmColor = hoodie
	desc.LeftLegColor = pants
	desc.RightLegColor = pants

	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		warn("[Web Creature] Couldn't create a thug:", model)
		return nil, nil, nil
	end

	model.Name = "Thug"
	model:SetAttribute("Thug", true)
	-- Thugs are animated by the clients (NPCAnimator), so drop any built-in animation script.
	local animate = model:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		model:Destroy()
		return nil, nil, nil
	end
	humanoid.MaxHealth = CR.ThugHealth
	humanoid.Health = CR.ThugHealth
	humanoid.WalkSpeed = CR.ThugSpeed
	humanoid.DisplayName = "Thug"
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	humanoid.NameDisplayDistance = 60
	humanoid.HealthDisplayDistance = 60

	model:PivotTo(CFrame.new(position + Vector3.new(0, 3.5, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	return model, humanoid, root
end

local function makeMarker(parent: Instance, position: Vector3): BasePart
	local marker = Instance.new("Part")
	marker.Name = "CrimeMarker"
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.Transparency = 1
	marker.Size = Vector3.one
	marker.Position = position + Vector3.new(0, 12, 0)

	local gui = Instance.new("BillboardGui")
	gui.Name = "Marker"
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Size = UDim2.fromOffset(110, 80)
	gui.MaxDistance = math.huge

	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.new(1, 0, 0, 44)
	icon.Font = Config.HUD.Font
	icon.Text = "!"
	icon.TextSize = 44
	icon.TextColor3 = Config.HUD.AccentColor
	icon.TextStrokeTransparency = 0.2
	icon.Parent = gui

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(0, 42)
	title.Size = UDim2.new(1, 0, 0, 18)
	title.Font = Config.HUD.Font
	title.Text = "CRIME"
	title.TextSize = 16
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextStrokeTransparency = 0.3
	title.Parent = gui

	local distance = Instance.new("TextLabel")
	distance.Name = "Distance" -- filled in by each client (CrimeMarkers)
	distance.BackgroundTransparency = 1
	distance.Position = UDim2.fromOffset(0, 60)
	distance.Size = UDim2.new(1, 0, 0, 16)
	distance.Font = Config.HUD.Font
	distance.Text = ""
	distance.TextSize = 13
	distance.TextColor3 = Color3.new(1, 1, 1)
	distance.TextStrokeTransparency = 0.3
	distance.Parent = gui

	gui.Parent = marker
	marker.Parent = parent
	return marker
end

-- A sidewalk spot a reasonable distance from a random player.
local function pickSpot(): Vector3?
	local spots = CityBuilder.Spots
	if #spots == 0 then
		return nil
	end
	local candidates = {}
	local players = Players:GetPlayers()
	if #players > 0 then
		local root = aliveRoot(pick(players).Character)
		if root then
			for _, spot in spots do
				local distance = flat(spot - root.Position).Magnitude
				if distance > CR.MinDistance and distance < CR.MaxDistance then
					table.insert(candidates, spot)
				end
			end
		end
	end
	if #candidates == 0 then
		candidates = spots
	end
	-- Not right on top of another crime
	for _ = 1, 10 do
		local spot = pick(candidates)
		local clear = true
		for _, crime in crimes do
			if (crime.position - spot).Magnitude < 80 then
				clear = false
				break
			end
		end
		if clear then
			return spot
		end
	end
	return nil
end

local function finishCrime(crime: Crime)
	if crime.finished then
		return
	end
	crime.finished = true

	for player in crime.participants do
		if player.Parent then
			DataService.Reward(player, PR.CrimeCoins, PR.CrimeXp, "Crime stopped!")
		end
	end

	local marker = crime.model:FindFirstChild("CrimeMarker")
	local gui = marker and marker:FindFirstChild("Marker")
	if gui then
		local icon = gui:FindFirstChild("Icon") :: TextLabel?
		local title = gui:FindFirstChild("Title") :: TextLabel?
		if icon then
			icon.Text = "OK"
			icon.TextColor3 = Color3.fromRGB(80, 230, 110)
		end
		if title then
			title.Text = "STOPPED"
		end
	end
	Debris:AddItem(crime.model, CR.CleanupDelay)
	local index = table.find(crimes, crime)
	if index then
		table.remove(crimes, index)
	end
end

local function spawnCrime()
	local spot = pickSpot()
	if not spot then
		return
	end

	local model = Instance.new("Model")
	model.Name = "Crime"
	-- Always sent to every client, so the marker shows up from across the city.
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	model.Parent = folder

	local crime: Crime = {
		model = model,
		position = spot,
		thugs = {},
		participants = {},
		started = os.clock(),
		finished = false,
	}
	table.insert(crimes, crime)
	makeMarker(model, spot)

	for _ = 1, rng:NextInteger(CR.ThugsMin, CR.ThugsMax) do
		local home = spot + Vector3.new(rng:NextNumber(-6, 6), 0, rng:NextNumber(-6, 6))
		local thugModel, humanoid, root = makeThug(home)
		if thugModel and humanoid and root then
			thugModel.Parent = model
			pcall(function()
				root:SetNetworkOwner(nil)
			end)
			local thug: Thug = {
				model = thugModel,
				humanoid = humanoid,
				root = root,
				home = home,
				lastAttack = 0,
				dead = false,
			}
			table.insert(crime.thugs, thug)
			humanoid.Died:Connect(function()
				thug.dead = true
				thugModel:SetAttribute("Down", true)
				for _, other in crime.thugs do
					if not other.dead then
						return
					end
				end
				finishCrime(crime)
			end)
		end
	end

	if #crime.thugs == 0 then
		model:Destroy()
		table.remove(crimes, table.find(crimes, crime) :: number)
		return
	end

	-- Let nearby players know.
	for _, player in Players:GetPlayers() do
		local root = aliveRoot(player.Character)
		if root and (root.Position - spot).Magnitude < CR.MaxDistance * 1.5 then
			DataService.Notify(player, "Crime reported! Look for the red !")
		end
	end
end

------------------------------------------------------------------------------------------------
-- Thug AI

local function nearestPlayer(position: Vector3, range: number): (BasePart?, Humanoid?, number)
	local bestRoot, bestHumanoid, bestDistance = nil, nil, range
	for _, player in Players:GetPlayers() do
		local root, humanoid = aliveRoot(player.Character)
		if root then
			local distance = (root.Position - position).Magnitude
			if distance < bestDistance then
				bestRoot, bestHumanoid, bestDistance = root, humanoid, distance
			end
		end
	end
	return bestRoot, bestHumanoid, bestDistance
end

local function updateThugs()
	local now = os.clock()
	for _, crime in table.clone(crimes) do
		for _, thug in crime.thugs do
			if not thug.dead then
				if not thug.root.Parent or thug.root.Position.Y < -50 then
					thug.humanoid.Health = 0 -- fell out of the world
				else
					local target, targetHumanoid, distance = nearestPlayer(thug.root.Position, CR.ThugAggroRange)
					if target and targetHumanoid then
						if distance > CR.ThugAttackRange then
							thug.humanoid:MoveTo(target.Position)
						else
							thug.humanoid:MoveTo(thug.root.Position)
							if now - thug.lastAttack > CR.ThugAttackCooldown then
								thug.lastAttack = now
								thug.model:SetAttribute("AttackTime", workspace:GetServerTimeNow())
								targetHumanoid:TakeDamage(CR.ThugDamage)
								Remotes.Event("HitFx"):FireAllClients(target.Position)
							end
						end
					elseif (thug.root.Position - thug.home).Magnitude > 6 then
						thug.humanoid:MoveTo(thug.home)
					end
				end
			end
		end

		-- Ignored crimes eventually go away.
		if not crime.finished and next(crime.participants) == nil and now - crime.started > CR.Lifetime then
			crime.finished = true
			crime.model:Destroy()
			table.remove(crimes, table.find(crimes, crime) :: number)
		end
	end
end

------------------------------------------------------------------------------------------------
-- Combat

local lastPunch: { [Player]: number } = {}

local function onPunch(player: Player)
	local now = os.clock()
	if now - (lastPunch[player] or 0) < CB.PunchCooldown * 0.8 then
		return
	end
	lastPunch[player] = now

	local root = aliveRoot(player.Character)
	if not root then
		return
	end
	local look = flat(root.CFrame.LookVector)
	look = if look.Magnitude > 1e-3 then look.Unit else Vector3.zAxis
	local speed = root.AssemblyLinearVelocity.Magnitude
	local fast = speed >= CB.SpeedKoThreshold
	local damage = if fast then CB.SpeedDamage else CB.PunchDamage
	local reach = CB.PunchRange + (if fast then 3 else 0)

	for _, crime in crimes do
		for _, thug in crime.thugs do
			if not thug.dead and thug.root.Parent then
				local offset = thug.root.Position - root.Position
				local distance = offset.Magnitude
				local direction = flat(offset)
				direction = if direction.Magnitude > 1e-3 then direction.Unit else look
				if distance <= reach and (distance < 3.5 or look:Dot(direction) > 0) then
					crime.participants[player] = true
					thug.humanoid:TakeDamage(damage)
					thug.root.AssemblyLinearVelocity = direction * CB.Knockback + Vector3.new(0, 25, 0)
					Remotes.Event("HitFx"):FireAllClients(thug.root.Position)
					if thug.humanoid.Health <= 0 then
						DataService.AddXp(player, PR.ThugKoXp)
					end
				end
			end
		end
	end
end

------------------------------------------------------------------------------------------------

function CrimeService.Start()
	folder = Instance.new("Folder")
	folder.Name = "Crimes"
	folder.Parent = workspace

	Remotes.Event("Punch").OnServerEvent:Connect(onPunch)
	Players.PlayerRemoving:Connect(function(player)
		lastPunch[player] = nil
		for _, crime in crimes do
			crime.participants[player] = nil
		end
	end)

	-- Thug brains, a few times a second
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= 0.15 then
			accumulator = 0
			updateThugs()
		end
	end)

	-- New crimes
	task.spawn(function()
		while true do
			task.wait(CR.SpawnInterval)
			local playerCount = #Players:GetPlayers()
			if playerCount > 0 and #crimes < CR.MaxActive + math.max(0, playerCount - 1) then
				local ok, err = pcall(spawnCrime)
				if not ok then
					warn("[Web Creature] Spawning a crime failed:", err)
				end
			end
		end
	end)
end

return CrimeService
