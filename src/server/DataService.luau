-- Player data: coins, XP (levels), owned and equipped suits, settings, gamepasses.
-- Saved with DataStores. If data can't be loaded (e.g. Studio without API access), the player
-- still plays with fresh data, but nothing is saved, so real data is never overwritten.

local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Suits = require(ReplicatedStorage.Shared.Suits)

local PR = Config.Progression
local STORE_NAME = "WebCreatureData_v1"

type Profile = {
	data: any,
	canSave: boolean,
	loaded: boolean,
	passes: { [string]: boolean },
	trickWindowStart: number,
	trickXp: number,
}

local DataService = {}
DataService.LevelChanged = Signal.new() -- (player, level)

local profiles: { [Player]: Profile } = {}
local store: DataStore? = nil

local function defaults()
	return {
		Coins = 0,
		Xp = 0,
		Owned = { [Suits.Default] = true },
		Equipped = Suits.Default,
		Settings = {},
	}
end

-- Fills in anything missing from older saves.
local function reconcile(data: any)
	local fresh = defaults()
	if type(data) ~= "table" then
		return fresh
	end
	for key, value in fresh do
		if data[key] == nil then
			data[key] = value
		end
	end
	if type(data.Owned) ~= "table" then
		data.Owned = fresh.Owned
	end
	data.Owned[Suits.Default] = true
	if type(data.Settings) ~= "table" then
		data.Settings = {}
	end
	if not Suits.ById[data.Equipped] then
		data.Equipped = Suits.Default
	end
	return data
end

local function storeKey(player: Player): string
	return "player_" .. player.UserId
end

local function load(player: Player): (any, boolean)
	local activeStore = store
	if not activeStore then
		return defaults(), false
	end
	for attempt = 1, 3 do
		local ok, result = pcall(function()
			return activeStore:GetAsync(storeKey(player))
		end)
		if ok then
			return reconcile(result), true
		end
		warn(`[Web Creature] Loading data for {player.Name} failed (try {attempt}): {result}`)
		task.wait(attempt)
	end
	-- Couldn't read their data: play with fresh data but don't save over the real data.
	return defaults(), false
end

local function save(player: Player)
	local profile = profiles[player]
	local activeStore = store
	if not (profile and profile.loaded and profile.canSave and activeStore) then
		return
	end
	local data = profile.data
	local ok, err = pcall(function()
		activeStore:SetAsync(storeKey(player), data)
	end)
	if not ok then
		warn(`[Web Creature] Saving data for {player.Name} failed: {err}`)
	end
end

------------------------------------------------------------------------------------------------
-- Reading

function DataService.GetData(player: Player): any?
	local profile = profiles[player]
	return profile and profile.data
end

function DataService.HasPass(player: Player, passName: string): boolean
	local profile = profiles[player]
	return profile ~= nil and profile.passes[passName] == true
end

function DataService.Level(player: Player): number
	local data = DataService.GetData(player)
	if not data then
		return 1
	end
	return (Progression.FromXp(data.Xp))
end

function DataService.Owns(player: Player, suitId: string): boolean
	local suit = Suits.ById[suitId]
	local data = DataService.GetData(player)
	if not suit or not data then
		return suitId == Suits.Default
	end
	if suit.Gamepass then
		return DataService.HasPass(player, suit.Gamepass)
	end
	return data.Owned[suitId] == true
end

-- What the client is allowed to see.
function DataService.Public(player: Player)
	local profile = profiles[player]
	if not profile then
		return nil
	end
	local data = profile.data
	local level, into, needed = Progression.FromXp(data.Xp)
	local owned = {}
	for _, suit in Suits.List do
		owned[suit.Id] = DataService.Owns(player, suit.Id)
	end
	return {
		Coins = data.Coins,
		Xp = data.Xp,
		Level = level,
		XpIntoLevel = into,
		XpNeeded = needed,
		Owned = owned,
		Equipped = data.Equipped,
		Settings = data.Settings,
		Passes = table.clone(profile.passes),
		PassIds = Config.Gamepasses,
		DataSaving = profile.canSave,
	}
end

-- Yields until the player's data has loaded (or the timeout passes).
function DataService.WaitForProfile(player: Player, timeout: number?): boolean
	local deadline = os.clock() + (timeout or 15)
	while os.clock() < deadline and player.Parent do
		local profile = profiles[player]
		if profile and profile.loaded then
			return true
		end
		task.wait(0.1)
	end
	return false
end

------------------------------------------------------------------------------------------------
-- Changing

local function updateLeaderstats(player: Player)
	local data = DataService.GetData(player)
	local stats = player:FindFirstChild("leaderstats")
	if not data or not stats then
		return
	end
	local levelValue = stats:FindFirstChild("Level") :: IntValue?
	local coinsValue = stats:FindFirstChild("Coins") :: IntValue?
	if levelValue then
		levelValue.Value = (Progression.FromXp(data.Xp))
	end
	if coinsValue then
		coinsValue.Value = data.Coins
	end
end

function DataService.Push(player: Player)
	updateLeaderstats(player)
	local public = DataService.Public(player)
	if public then
		Remotes.Event("ProfileUpdated"):FireClient(player, public)
	end
end

function DataService.Notify(player: Player, text: string)
	Remotes.Event("Notify"):FireClient(player, text)
end

-- Adds coins (doubled for VIP). Returns how many were actually given.
function DataService.AddCoins(player: Player, amount: number, push: boolean?): number
	local data = DataService.GetData(player)
	if not data then
		return 0
	end
	local multiplier = if DataService.HasPass(player, "VIP") then PR.VipCoinMultiplier else 1
	local given = math.floor(amount * multiplier)
	data.Coins += given
	if push ~= false then
		DataService.Push(player)
	end
	return given
end

function DataService.AddXp(player: Player, amount: number, push: boolean?)
	local data = DataService.GetData(player)
	if not data or amount <= 0 then
		return
	end
	local before = Progression.FromXp(data.Xp)
	data.Xp += math.floor(amount)
	local after = Progression.FromXp(data.Xp)
	if after > before then
		local bonus = DataService.AddCoins(player, PR.LevelUpCoins * (after - before), false)
		DataService.Notify(player, `LEVEL UP! You're level {after}  (+{bonus} coins)`)
		DataService.LevelChanged:Fire(player, after)
	end
	if push ~= false then
		DataService.Push(player)
	end
end

-- Coins + XP together, with one notification.
function DataService.Reward(player: Player, coins: number, xp: number, reason: string)
	local given = DataService.AddCoins(player, coins, false)
	DataService.Notify(player, `{reason}  +{given} coins  +{xp} XP`)
	DataService.AddXp(player, xp, false)
	DataService.Push(player)
end

-- Small XP for tricks, capped per minute.
function DataService.TrickXp(player: Player)
	local profile = profiles[player]
	if not profile or not profile.loaded then
		return
	end
	local now = os.clock()
	if now - profile.trickWindowStart > 60 then
		profile.trickWindowStart = now
		profile.trickXp = 0
	end
	if profile.trickXp + PR.TrickXp > PR.TrickXpPerMinute then
		return
	end
	profile.trickXp += PR.TrickXp
	DataService.AddXp(player, PR.TrickXp)
end

function DataService.SetSettings(player: Player, settings: any)
	local data = DataService.GetData(player)
	if not data or type(settings) ~= "table" then
		return
	end
	for key, default in Config.Settings do
		local value = settings[key]
		if type(value) == type(default) then
			data.Settings[key] = value
		end
	end
end

function DataService.BuySuit(player: Player, suitId: string): (boolean, string)
	local suit = Suits.ById[suitId]
	local data = DataService.GetData(player)
	if not suit or not data then
		return false, "Something went wrong"
	end
	if DataService.Owns(player, suitId) then
		return false, "You already own this suit"
	end
	if suit.Gamepass then
		return false, "This suit comes with the " .. suit.Gamepass .. " pass"
	end
	if DataService.Level(player) < suit.Level then
		return false, `Reach level {suit.Level} first`
	end
	if data.Coins < suit.Price then
		return false, "Not enough coins"
	end
	data.Coins -= suit.Price
	data.Owned[suitId] = true
	DataService.Push(player)
	return true, `Unlocked {suit.Name}!`
end

function DataService.EquipSuit(player: Player, suitId: string): (boolean, string)
	local data = DataService.GetData(player)
	local suit = Suits.ById[suitId]
	if not data or not suit then
		return false, "Something went wrong"
	end
	if not DataService.Owns(player, suitId) then
		return false, "You don't own this suit yet"
	end
	data.Equipped = suitId
	DataService.Push(player)
	return true, `Equipped {suit.Name}`
end

------------------------------------------------------------------------------------------------
-- Gamepasses

local function checkPasses(player: Player, profile: Profile)
	for name, id in Config.Gamepasses do
		local owns = false
		if id ~= 0 then
			local ok, result = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
			end)
			owns = ok and result == true
		end
		profile.passes[name] = owns
	end
	player:SetAttribute("RainbowWebs", profile.passes.RainbowWebs == true)
end

local function onPassPurchased(player: Player, passId: number, purchased: boolean)
	if not purchased then
		return
	end
	local profile = profiles[player]
	if not profile then
		return
	end
	for name, id in Config.Gamepasses do
		if id ~= 0 and id == passId then
			profile.passes[name] = true
			DataService.Notify(player, `Thanks for buying {name}!`)
		end
	end
	player:SetAttribute("RainbowWebs", profile.passes.RainbowWebs == true)
	DataService.Push(player)
end

------------------------------------------------------------------------------------------------
-- Lifecycle

local function onPlayerAdded(player: Player)
	local profile: Profile = {
		data = defaults(),
		canSave = false,
		loaded = false,
		passes = {},
		trickWindowStart = 0,
		trickXp = 0,
	}
	profiles[player] = profile

	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local levelValue = Instance.new("IntValue")
	levelValue.Name = "Level"
	levelValue.Value = 1
	levelValue.Parent = stats
	local coinsValue = Instance.new("IntValue")
	coinsValue.Name = "Coins"
	coinsValue.Parent = stats
	stats.Parent = player

	local data, canSave = load(player)
	if player.Parent == nil then
		return
	end
	profile.data = data
	profile.canSave = canSave
	checkPasses(player, profile)
	profile.loaded = true
	DataService.Push(player)

	if not canSave then
		warn(
			"[Web Creature] Progress won't be saved this session. In Studio, turn on "
				.. "Game Settings > Security > Enable Studio Access to API Services."
		)
	end
end

local function onPlayerRemoving(player: Player)
	save(player)
	profiles[player] = nil
end

function DataService.Start()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[Web Creature] DataStores unavailable, progress won't be saved:", result)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(onPassPurchased)

	-- Save everyone when the server shuts down.
	game:BindToClose(function()
		local pending = 0
		for _, player in Players:GetPlayers() do
			pending += 1
			task.spawn(function()
				save(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)

	-- Autosave
	task.spawn(function()
		while true do
			task.wait(PR.AutosaveInterval)
			for _, player in Players:GetPlayers() do
				task.spawn(save, player)
			end
		end
	end)

	Remotes.Function("GetProfile").OnServerInvoke = function(player: Player)
		DataService.WaitForProfile(player, 10)
		return DataService.Public(player)
	end
	Remotes.Event("SaveSettings").OnServerEvent:Connect(function(player: Player, settings: any)
		DataService.SetSettings(player, settings)
	end)
	Remotes.Event("Trick").OnServerEvent:Connect(function(player: Player, _name: any)
		DataService.TrickXp(player)
	end)
end

return DataService
