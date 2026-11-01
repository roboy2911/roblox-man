-- The main menu (shown when you join, with a slow flyover of the city), the Suits shop and
-- the Settings panel. The shop and settings can also be opened from the HUD while playing.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Suits = require(ReplicatedStorage.Shared.Suits)
local Profile = require(script.Parent.Profile)
local Settings = require(script.Parent.Settings)
local UIKit = require(script.Parent.UIKit)

local player = Players.LocalPlayer
local Colors = UIKit.Colors

local Menu = {
	IsOpen = true, -- the main menu (not the shop/settings panels)
	Changed = Signal.new(), -- (isOpen)
}

local input
local controls
local menuGui: ScreenGui
local panelsGui: ScreenGui
local shopPanel: Frame
local settingsPanel: Frame
local shopMessage: TextLabel
local refreshShop: () -> ()
local refreshSettings: () -> ()

------------------------------------------------------------------------------------------------
-- Player controls

local function setControls(enabled: boolean)
	if input then
		input:SetEnabled(enabled)
	end
	if controls then
		if enabled then
			controls:Enable()
		else
			controls:Disable()
		end
	end
end

local function loadControls()
	local ok, result = pcall(function()
		local playerModule = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: any)
		return playerModule:GetControls()
	end)
	if ok then
		controls = result
	else
		warn("[Web Creature] Couldn't get player controls:", result)
	end
end

------------------------------------------------------------------------------------------------
-- Panels

local function closePanels()
	shopPanel.Visible = false
	settingsPanel.Visible = false
end

function Menu.OpenShop()
	settingsPanel.Visible = false
	shopMessage.Text = ""
	refreshShop()
	shopPanel.Visible = true
end

function Menu.OpenSettings()
	shopPanel.Visible = false
	refreshSettings()
	settingsPanel.Visible = true
end

local function promptPass(passName: string)
	local id = Config.Gamepasses[passName]
	if id and id ~= 0 then
		MarketplaceService:PromptGamePassPurchase(player, id)
	end
end

local function buildShop()
	local panel, content = UIKit.modal(panelsGui, "SUITS", Vector2.new(820, 560), closePanels)
	shopPanel = panel

	-- Top row: coins and gamepasses
	local coins = UIKit.text(content, {
		Size = UDim2.new(0.34, 0, 0, 40),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(255, 210, 80),
		TextSize = 22,
		ZIndex = 6,
	})
	local vipButton = UIKit.button(content, "GET VIP", function()
		promptPass("VIP")
	end, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -196, 0, 0),
		Size = UDim2.fromOffset(180, 40),
		TextSize = 15,
		BackgroundColor3 = Color3.fromRGB(200, 150, 30),
		ZIndex = 6,
	})
	local rainbowButton = UIKit.button(content, "RAINBOW WEBS", function()
		promptPass("RainbowWebs")
	end, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(186, 40),
		TextSize = 15,
		BackgroundColor3 = Color3.fromRGB(120, 60, 200),
		ZIndex = 6,
	})

	shopMessage = UIKit.text(content, {
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(1, 0, 0, 22),
		TextSize = 15,
		TextColor3 = Colors.Muted,
		Text = "",
		ZIndex = 6,
	})

	local grid = Instance.new("ScrollingFrame")
	grid.Position = UDim2.fromOffset(0, 70)
	grid.Size = UDim2.new(1, 0, 1, -70)
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 6
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.new()
	grid.ZIndex = 6
	grid.Parent = content
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(180, 200)
	layout.CellPadding = UDim2.fromOffset(12, 12)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	local function request(action: string, suitId: string)
		shopMessage.Text = "..."
		local ok, success, message = pcall(function()
			return Remotes.Function("ShopRequest"):InvokeServer(action, suitId)
		end)
		if not ok then
			shopMessage.Text = "Couldn't reach the server, try again"
			return
		end
		shopMessage.Text = message or ""
		shopMessage.TextColor3 = if success then Colors.Good else Colors.Accent
	end

	local cards = {}
	for index, suit in Suits.List do
		local card = UIKit.frame(grid, { BackgroundColor3 = Colors.PanelLight, LayoutOrder = index, ZIndex = 6 })
		UIKit.corner(card, 10)

		-- Color preview: suit, accent and eye colors side by side
		local swatch = UIKit.frame(card, {
			Position = UDim2.fromOffset(10, 10),
			Size = UDim2.new(1, -20, 0, 70),
			BackgroundColor3 = suit.Colors.Suit,
			ZIndex = 7,
		})
		UIKit.corner(swatch, 8)
		UIKit.frame(swatch, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.35, 0.5),
			Size = UDim2.fromOffset(34, 34),
			BackgroundColor3 = suit.Colors.Accent,
			ZIndex = 8,
		})
		UIKit.frame(swatch, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.65, 0.5),
			Size = UDim2.fromOffset(26, 12),
			BackgroundColor3 = suit.Colors.Eye,
			ZIndex = 8,
		})

		UIKit.text(card, {
			Position = UDim2.fromOffset(10, 86),
			Size = UDim2.new(1, -20, 0, 24),
			Text = suit.Name,
			TextSize = 18,
			ZIndex = 7,
		})
		local requirement = UIKit.text(card, {
			Position = UDim2.fromOffset(10, 110),
			Size = UDim2.new(1, -20, 0, 20),
			TextSize = 13,
			TextColor3 = Colors.Muted,
			ZIndex = 7,
		})
		local button = UIKit.button(card, "", function()
			local data = Profile.Data
			if not data then
				return
			end
			if data.Owned[suit.Id] then
				request("Equip", suit.Id)
			elseif suit.Gamepass then
				promptPass(suit.Gamepass)
			else
				request("Buy", suit.Id)
			end
		end, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -12),
			Size = UDim2.new(1, -20, 0, 40),
			TextSize = 16,
			ZIndex = 7,
		})
		cards[suit.Id] = { button = button, requirement = requirement }
	end

	refreshShop = function()
		local data = Profile.Data
		if not data then
			coins.Text = "Loading..."
			return
		end
		coins.Text = `{data.Coins} coins`

		local function passButton(button: TextButton, passName: string, label: string)
			local owned = data.Passes and data.Passes[passName]
			local forSale = (data.PassIds and data.PassIds[passName] or 0) ~= 0
			button.Text = if owned then label .. ": OWNED" elseif forSale then "GET " .. label else label .. ": SOON"
			button.Active = forSale and not owned
			button.AutoButtonColor = false
		end
		passButton(vipButton, "VIP", "VIP")
		passButton(rainbowButton, "RainbowWebs", "RAINBOW WEBS")

		for _, suit in Suits.List do
			local card = cards[suit.Id]
			local owned = data.Owned[suit.Id] == true
			local equipped = data.Equipped == suit.Id
			local button, requirement = card.button, card.requirement
			button.Active = true
			if equipped then
				button.Text = "EQUIPPED"
				button.BackgroundColor3 = Colors.Disabled
				button.Active = false
			elseif owned then
				button.Text = "EQUIP"
				button.BackgroundColor3 = Colors.Good
			elseif suit.Gamepass then
				local forSale = (data.PassIds and data.PassIds[suit.Gamepass] or 0) ~= 0
				button.Text = if forSale then "GET " .. suit.Gamepass else "COMING SOON"
				button.BackgroundColor3 = if forSale then Color3.fromRGB(200, 150, 30) else Colors.Disabled
				button.Active = forSale
			elseif data.Level < suit.Level then
				button.Text = `LEVEL {suit.Level}`
				button.BackgroundColor3 = Colors.Disabled
				button.Active = false
			else
				button.Text = `BUY {suit.Price}`
				button.BackgroundColor3 = if data.Coins >= suit.Price then Colors.Accent else Colors.Disabled
			end

			if owned then
				requirement.Text = "Owned"
			elseif suit.Gamepass then
				requirement.Text = "Comes with " .. suit.Gamepass
			else
				requirement.Text = `Level {suit.Level}  |  {suit.Price} coins`
			end
		end
	end
end

local function buildSettings()
	local panel, content = UIKit.modal(panelsGui, "SETTINGS", Vector2.new(560, 470), closePanels)
	settingsPanel = panel

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = content

	local toggles = {}
	for index, entry in Config.SettingsOrder do
		local row = UIKit.frame(content, {
			Size = UDim2.new(1, 0, 0, 44),
			BackgroundColor3 = Colors.PanelLight,
			LayoutOrder = index,
			ZIndex = 6,
		})
		UIKit.corner(row, 8)
		UIKit.text(row, {
			Position = UDim2.fromOffset(14, 0),
			Size = UDim2.new(1, -130, 1, 0),
			Text = entry.Label,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 7,
		})
		toggles[entry.Key] = UIKit.button(row, "", function()
			Settings.Set(entry.Key, not Settings.Get(entry.Key))
			refreshSettings()
		end, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(90, 32),
			TextSize = 15,
			ZIndex = 7,
		})
	end

	local saving = UIKit.text(content, {
		Size = UDim2.new(1, 0, 0, 24),
		TextSize = 13,
		TextColor3 = Colors.Muted,
		LayoutOrder = 100,
		ZIndex = 6,
	})

	refreshSettings = function()
		for key, toggle in toggles do
			local on = Settings.Get(key) == true
			toggle.Text = if on then "ON" else "OFF"
			toggle.BackgroundColor3 = if on then Colors.Good else Colors.Disabled
		end
		local data = Profile.Data
		saving.Text = if data and data.DataSaving == false
			then "Progress isn't being saved right now."
			else "Your progress and settings are saved automatically."
	end
	Settings.Changed:Connect(function()
		refreshSettings()
	end)
end

------------------------------------------------------------------------------------------------
-- Main menu

local orbitConnection: RBXScriptConnection?

local function startOrbit()
	local angle = 0
	orbitConnection = RunService.RenderStepped:Connect(function(dt)
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		angle += dt * 0.04
		camera.CameraType = Enum.CameraType.Scriptable
		local position = Vector3.new(math.cos(angle) * 380, 260, math.sin(angle) * 380)
		camera.CFrame = CFrame.lookAt(position, Vector3.new(0, 90, 0))
	end)
end

local function stopOrbit()
	if orbitConnection then
		orbitConnection:Disconnect()
		orbitConnection = nil
	end
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
end

function Menu.Play()
	if not Menu.IsOpen then
		return
	end
	Menu.IsOpen = false
	closePanels()
	stopOrbit()
	setControls(true)
	local root = menuGui:FindFirstChild("Root") :: Frame
	local fade = TweenService:Create(root, TweenInfo.new(0.35), { Position = UDim2.fromScale(-0.6, 0) })
	fade:Play()
	fade.Completed:Connect(function()
		if not Menu.IsOpen then
			menuGui.Enabled = false
		end
	end)
	Menu.Changed:Fire(false)
end

local function buildMainMenu()
	menuGui = Instance.new("ScreenGui")
	menuGui.Name = "MainMenu"
	menuGui.IgnoreGuiInset = true
	menuGui.ResetOnSpawn = false
	menuGui.DisplayOrder = 10
	menuGui.Parent = player:WaitForChild("PlayerGui")

	local root = UIKit.frame(menuGui, {
		Name = "Root",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.15,
	})
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, 0.6),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Parent = root

	local column = UIKit.frame(root, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 60, 0.5, 0),
		Size = UDim2.new(0.6, 0, 0, 420),
		BackgroundTransparency = 1,
	})
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 12)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = column

	local title = UIKit.text(column, {
		Size = UDim2.new(1, 0, 0, 80),
		Text = "WEB CREATURE",
		TextScaled = true,
		TextColor3 = Colors.Accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 1,
	})
	local titleLimit = Instance.new("UITextSizeConstraint")
	titleLimit.MaxTextSize = 76
	titleLimit.Parent = title

	UIKit.text(column, {
		Size = UDim2.new(1, 0, 0, 28),
		Text = "Swing the city. Stop crime. Unlock suits.",
		TextSize = 20,
		TextColor3 = Colors.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 2,
	})
	UIKit.frame(column, { Size = UDim2.fromOffset(10, 16), BackgroundTransparency = 1, LayoutOrder = 3 })

	UIKit.button(column, "PLAY", Menu.Play, { LayoutOrder = 4, Size = UDim2.fromOffset(260, 56), TextSize = 26 })
	UIKit.button(column, "SUITS", Menu.OpenShop, {
		LayoutOrder = 5,
		Size = UDim2.fromOffset(260, 48),
		BackgroundColor3 = Colors.PanelLight,
	})
	UIKit.button(column, "SETTINGS", Menu.OpenSettings, {
		LayoutOrder = 6,
		Size = UDim2.fromOffset(260, 48),
		BackgroundColor3 = Colors.PanelLight,
	})

	local footer = UIKit.text(column, {
		Size = UDim2.new(1, 0, 0, 24),
		TextSize = 16,
		TextColor3 = Colors.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 7,
		Text = "Loading your profile...",
	})
	Profile.Changed:Connect(function(data)
		footer.Text = `Level {data.Level}  |  {data.Coins} coins`
	end)
end

------------------------------------------------------------------------------------------------

function Menu.Init(inputController)
	input = inputController
	panelsGui = Instance.new("ScreenGui")
	panelsGui.Name = "Panels"
	panelsGui.IgnoreGuiInset = true
	panelsGui.ResetOnSpawn = false
	panelsGui.DisplayOrder = 15
	panelsGui.Parent = player:WaitForChild("PlayerGui")

	buildShop()
	buildSettings()
	buildMainMenu()

	Profile.Changed:Connect(function()
		if shopPanel.Visible then
			refreshShop()
		end
		if settingsPanel.Visible then
			refreshSettings()
		end
	end)

	task.spawn(function()
		loadControls()
		if Menu.IsOpen then
			setControls(false)
		end
	end)
	setControls(false)
	startOrbit()
end

return Menu
