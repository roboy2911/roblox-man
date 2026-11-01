-- Every Web Creature suit. Unlock with coins once you reach the level, or with a gamepass.
-- Colors: Suit (body), SuitLight (torso), Accent (hands, feet, details), Eye, Metal (gear).

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

export type Suit = {
	Id: string,
	Name: string,
	Level: number,
	Price: number,
	Gamepass: string?, -- key in Config.Gamepasses; owning the pass unlocks the suit
	Colors: { Suit: Color3, SuitLight: Color3, Accent: Color3, Eye: Color3, Metal: Color3 },
}

local List: { Suit } = {
	{
		Id = "Classic",
		Name = "Classic",
		Level = 1,
		Price = 0,
		Colors = { Suit = rgb(26, 26, 32), SuitLight = rgb(44, 44, 54), Accent = rgb(220, 30, 45), Eye = rgb(255, 255, 255), Metal = rgb(60, 62, 72) },
	},
	{
		Id = "Midnight",
		Name = "Midnight",
		Level = 3,
		Price = 200,
		Colors = { Suit = rgb(18, 22, 45), SuitLight = rgb(30, 36, 70), Accent = rgb(40, 200, 255), Eye = rgb(200, 240, 255), Metal = rgb(50, 58, 80) },
	},
	{
		Id = "Toxic",
		Name = "Toxic",
		Level = 5,
		Price = 400,
		Colors = { Suit = rgb(22, 26, 22), SuitLight = rgb(36, 44, 36), Accent = rgb(120, 255, 60), Eye = rgb(220, 255, 200), Metal = rgb(55, 65, 55) },
	},
	{
		Id = "Arctic",
		Name = "Arctic",
		Level = 7,
		Price = 600,
		Colors = { Suit = rgb(225, 230, 238), SuitLight = rgb(200, 208, 220), Accent = rgb(60, 140, 255), Eye = rgb(20, 30, 60), Metal = rgb(150, 160, 175) },
	},
	{
		Id = "Inferno",
		Name = "Inferno",
		Level = 10,
		Price = 900,
		Colors = { Suit = rgb(45, 12, 10), SuitLight = rgb(70, 20, 15), Accent = rgb(255, 120, 20), Eye = rgb(255, 220, 120), Metal = rgb(80, 40, 30) },
	},
	{
		Id = "Royal",
		Name = "Royal",
		Level = 14,
		Price = 1400,
		Colors = { Suit = rgb(40, 16, 60), SuitLight = rgb(60, 26, 85), Accent = rgb(255, 200, 60), Eye = rgb(255, 245, 200), Metal = rgb(90, 70, 40) },
	},
	{
		Id = "Shadow",
		Name = "Shadow",
		Level = 20,
		Price = 2500,
		Colors = { Suit = rgb(10, 10, 12), SuitLight = rgb(18, 18, 22), Accent = rgb(255, 20, 20), Eye = rgb(255, 40, 40), Metal = rgb(30, 30, 34) },
	},
	{
		Id = "Gold",
		Name = "Gold (VIP)",
		Level = 1,
		Price = 0,
		Gamepass = "VIP",
		Colors = { Suit = rgb(30, 26, 18), SuitLight = rgb(60, 50, 25), Accent = rgb(255, 200, 40), Eye = rgb(255, 250, 220), Metal = rgb(200, 160, 60) },
	},
}

local ById: { [string]: Suit } = {}
for _, suit in List do
	ById[suit.Id] = suit
end

return {
	List = List,
	ById = ById,
	Default = "Classic",
}
