-- The Web Creature look: a normal blocky Roblox avatar in a black suit with red hands and feet,
-- big angular white eyes, a spider emblem on the chest, and four mechanical spider legs on the back.
-- Everything is built from parts, so no uploaded assets are needed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local C = Config.Character

local WebCreatureLook = {}

function WebCreatureLook.CreateDescription(): HumanoidDescription
	local desc = Instance.new("HumanoidDescription")
	desc.HeadColor = C.Suit
	desc.TorsoColor = C.SuitLight
	desc.LeftArmColor = C.Suit
	desc.RightArmColor = C.Suit
	desc.LeftLegColor = C.Suit
	desc.RightLegColor = C.Suit
	-- No clothing, face or accessories: the suit is the look.
	desc.Shirt = 0
	desc.Pants = 0
	desc.GraphicTShirt = 0
	desc.Face = 0
	return desc
end

type PartProps = {
	Size: Vector3,
	CFrame: CFrame,
	Color: Color3,
	Material: Enum.Material?,
	Shape: Enum.PartType?,
}

local function weldPart(model: Model, base: BasePart, props: PartProps): Part
	local part = Instance.new("Part")
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.Color = props.Color
	part.Material = props.Material or Enum.Material.SmoothPlastic
	if props.Shape then
		part.Shape = props.Shape
	end
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = base
	weld.Part1 = part
	weld.Parent = part

	part.Parent = model
	return part
end

-- A stick between two world points.
local function segment(model: Model, base: BasePart, a: Vector3, b: Vector3, thickness: number, color: Color3, material: Enum.Material?): Part
	return weldPart(model, base, {
		Size = Vector3.new(thickness, thickness, (b - a).Magnitude),
		CFrame = CFrame.lookAt((a + b) / 2, b),
		Color = color,
		Material = material,
	})
end

local function removeFace(head: BasePart)
	local function check(child: Instance)
		if child:IsA("Decal") and child.Name == "face" then
			child:Destroy()
		end
	end
	for _, child in head:GetChildren() do
		check(child)
	end
	head.ChildAdded:Connect(check)
end

local function buildEyes(model: Model, head: BasePart)
	local hs = head.Size
	-- Two big angular lenses, outer corners raised.
	for side = -1, 1, 2 do
		weldPart(model, head, {
			Size = Vector3.new(0.34 * hs.X, 0.17 * hs.Y, 0.05),
			CFrame = head.CFrame
				* CFrame.new(side * 0.2 * hs.X, 0.06 * hs.Y, -0.5 * hs.Z)
				* CFrame.Angles(0, 0, math.rad(side * 15)),
			Color = C.Eye,
			Material = Enum.Material.Neon,
		})
	end
	-- Four tiny red spider eyes above them.
	local small = {
		Vector3.new(-0.07, 0.3, -0.46),
		Vector3.new(0.07, 0.3, -0.46),
		Vector3.new(-0.2, 0.26, -0.43),
		Vector3.new(0.2, 0.26, -0.43),
	}
	for _, offset in small do
		local size = 0.09 * hs.X
		weldPart(model, head, {
			Size = Vector3.new(size, size, size),
			CFrame = head.CFrame * CFrame.new(offset * hs),
			Color = C.Accent,
			Material = Enum.Material.Neon,
			Shape = Enum.PartType.Ball,
		})
	end
end

local function buildChestEmblem(model: Model, torso: BasePart)
	local ts = torso.Size
	local k = ts.X / 2
	local z = -ts.Z / 2 - 0.02
	local cy = 0.15 * k
	local function at(x: number, y: number): Vector3
		return torso.CFrame:PointToWorldSpace(Vector3.new(x * k, cy + y * k, z))
	end

	-- Body and head of the spider
	weldPart(model, torso, {
		Size = Vector3.new(0.16 * k, 0.34 * k, 0.04),
		CFrame = torso.CFrame * CFrame.new(0, cy, z),
		Color = C.Accent,
	})
	weldPart(model, torso, {
		Size = Vector3.new(0.11 * k, 0.11 * k, 0.04),
		CFrame = torso.CFrame * CFrame.new(0, cy + 0.24 * k, z),
		Color = C.Accent,
	})

	-- Eight legs, two segments each
	local startY = { 0.08, 0.03, -0.02, -0.07 }
	local kneeY = { 0.2, 0.1, -0.04, -0.14 }
	local footY = { 0.34, 0.12, -0.2, -0.36 }
	for side = -1, 1, 2 do
		for i = 1, 4 do
			local a = at(side * 0.06, startY[i])
			local knee = at(side * 0.24, kneeY[i])
			local foot = at(side * 0.36, footY[i])
			segment(model, torso, a, knee, 0.035 * k, C.Accent)
			segment(model, torso, knee, foot, 0.035 * k, C.Accent)
		end
	end
end

local function buildBackLegs(model: Model, torso: BasePart)
	local ts = torso.Size
	local k = ts.X / 2
	local back = ts.Z / 2
	local function at(x: number, y: number, z: number): Vector3
		return torso.CFrame:PointToWorldSpace(Vector3.new(x * k, y * k, back + z * k))
	end

	-- Backpack hub with a glowing red core
	weldPart(model, torso, {
		Size = Vector3.new(0.25 * k, 0.9 * k, 0.9 * k),
		CFrame = torso.CFrame * CFrame.new(0, 0.15 * k, back + 0.12 * k) * CFrame.Angles(0, math.rad(90), 0),
		Color = C.Metal,
		Material = Enum.Material.Metal,
		Shape = Enum.PartType.Cylinder,
	})
	weldPart(model, torso, {
		Size = Vector3.new(0.06 * k, 0.4 * k, 0.4 * k),
		CFrame = torso.CFrame * CFrame.new(0, 0.15 * k, back + 0.26 * k) * CFrame.Angles(0, math.rad(90), 0),
		Color = C.Accent,
		Material = Enum.Material.Neon,
		Shape = Enum.PartType.Cylinder,
	})

	-- Two legs per side: { base, knee, tip } in torso space (scaled by k)
	local legs = {
		{ Vector3.new(0.35, 0.3, 0.15), Vector3.new(1.3, 1.25, 0.75), Vector3.new(1.9, 0.2, 0.9) },
		{ Vector3.new(0.35, 0.0, 0.15), Vector3.new(1.4, 0.5, 0.9), Vector3.new(1.75, -0.8, 0.7) },
	}
	for side = -1, 1, 2 do
		for _, leg in legs do
			local base = at(side * leg[1].X, leg[1].Y, leg[1].Z)
			local knee = at(side * leg[2].X, leg[2].Y, leg[2].Z)
			local tip = at(side * leg[3].X, leg[3].Y, leg[3].Z)
			local tipStart = knee:Lerp(tip, 0.72)

			segment(model, torso, base, knee, 0.16 * k, C.Metal, Enum.Material.Metal)
			weldPart(model, torso, {
				Size = Vector3.one * 0.24 * k,
				CFrame = CFrame.new(knee),
				Color = C.Suit,
				Material = Enum.Material.Metal,
				Shape = Enum.PartType.Ball,
			})
			segment(model, torso, knee, tipStart, 0.11 * k, C.Metal, Enum.Material.Metal)
			segment(model, torso, tipStart, tip, 0.09 * k, C.Accent, Enum.Material.Neon)
		end
	end
end

-- Waits (up to timeout) for Roblox to finish applying the avatar, so our colors aren't overwritten.
local function waitForAppearance(player: Player, timeout: number)
	if player:HasAppearanceLoaded() then
		return
	end
	local done = false
	local connection = player.CharacterAppearanceLoaded:Connect(function()
		done = true
	end)
	local started = os.clock()
	while not done and os.clock() - started < timeout do
		task.wait(0.1)
	end
	connection:Disconnect()
end

function WebCreatureLook.Decorate(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local head = character:WaitForChild("Head", 10) :: BasePart?
	if not humanoid or not head then
		return
	end

	local isR15 = humanoid.RigType == Enum.HumanoidRigType.R15
	local torso = (if isR15 then character:WaitForChild("UpperTorso", 10) else character:WaitForChild("Torso", 10)) :: BasePart?
	if not torso then
		return
	end

	waitForAppearance(player, 3)
	if character.Parent == nil then
		return
	end

	removeFace(head)

	-- Red gloves and boots (R15 only; R6 has no separate hands/feet)
	if isR15 then
		for _, name in { "LeftHand", "RightHand", "LeftFoot", "RightFoot" } do
			local part = character:FindFirstChild(name)
			if part and part:IsA("BasePart") then
				part.Color = C.Accent
			end
		end
	end

	local old = character:FindFirstChild("WebCreatureGear")
	if old then
		old:Destroy()
	end
	local gear = Instance.new("Model")
	gear.Name = "WebCreatureGear"

	buildEyes(gear, head)
	buildChestEmblem(gear, torso)
	buildBackLegs(gear, torso)

	gear.Parent = character
end

return WebCreatureLook
