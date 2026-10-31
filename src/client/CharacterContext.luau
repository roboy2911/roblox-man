-- References to the local character that every movement system needs.

local CharacterContext = {}
CharacterContext.__index = CharacterContext

export type CharacterContext = {
	Character: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	RootAttachment: Attachment,
	HandAttachment: Attachment,
	WorldParams: RaycastParams,
	SwingParams: RaycastParams,
	IsGrounded: (self: CharacterContext) -> boolean,
	IsAlive: (self: CharacterContext) -> boolean,
	Destroy: (self: CharacterContext) -> (),
}

function CharacterContext.new(character: Model): CharacterContext?
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not humanoid or not root then
		return nil
	end

	local handName = if humanoid.RigType == Enum.HumanoidRigType.R15 then "RightHand" else "Right Arm"
	local hand = (character:WaitForChild(handName, 5) or root) :: BasePart

	-- Our own attachments, so we never fight with Roblox's built-in ones.
	local rootAttachment = Instance.new("Attachment")
	rootAttachment.Name = "MovementAttachment"
	rootAttachment.Parent = root

	local handAttachment = Instance.new("Attachment")
	handAttachment.Name = "WebShooter"
	handAttachment.Position = if hand == root then Vector3.new(1, 0.5, -0.5) else Vector3.new(0, -hand.Size.Y / 2, 0)
	handAttachment.Parent = hand

	local worldParams = RaycastParams.new()
	worldParams.FilterType = Enum.RaycastFilterType.Exclude
	worldParams.FilterDescendantsInstances = { character }
	worldParams.IgnoreWater = true

	-- Webs only stick to buildings.
	local buildings = workspace:WaitForChild("City"):WaitForChild("Buildings")
	local swingParams = RaycastParams.new()
	swingParams.FilterType = Enum.RaycastFilterType.Include
	swingParams.FilterDescendantsInstances = { buildings }
	swingParams.IgnoreWater = true

	local self = setmetatable({
		Character = character,
		Humanoid = humanoid,
		Root = root,
		RootAttachment = rootAttachment,
		HandAttachment = handAttachment,
		WorldParams = worldParams,
		SwingParams = swingParams,
	}, CharacterContext)
	return (self :: any) :: CharacterContext
end

function CharacterContext:IsGrounded(): boolean
	return self.Humanoid.FloorMaterial ~= Enum.Material.Air
end

function CharacterContext:IsAlive(): boolean
	return self.Humanoid.Health > 0 and self.Humanoid:GetState() ~= Enum.HumanoidStateType.Dead
end

function CharacterContext:Destroy()
	self.RootAttachment:Destroy()
	self.HandAttachment:Destroy()
end

return CharacterContext
