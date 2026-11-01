-- On-screen UI while playing:
--   * Level, XP bar and coins (top left), with SUITS and SETTINGS buttons under them
--   * Speed meter (bottom middle)
--   * Crosshair in the middle that lights up red when a web zip target is in reach
--   * Control hints (bottom left) that match your device; press H (or Settings) to hide/show
-- Hidden while the main menu is open.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Cleaner = require(ReplicatedStorage.Shared.Cleaner)
local Config = require(ReplicatedStorage.Shared.Config)
local MathUtil = require(ReplicatedStorage.Shared.MathUtil)
local Menu = require(script.Parent.Menu)
local Profile = require(script.Parent.Profile)
local Settings = require(script.Parent.Settings)
local UIKit = require(script.Parent.UIKit)

local H = Config.HUD

local HINTS = {
	Keyboard = {
		"Hold LMB  Swing",
		"E  Web zip",
		"F  Punch (hit fast to knock out)",
		"Space at zip end  Launch",
		"Space in air  Double jump",
		"Q in air  Dive",
		"Fly along walls  Wall run",
		"H  Hide help",
	},
	Gamepad = {
		"Hold R2  Swing",
		"L1  Web zip",
		"X  Punch (hit fast to knock out)",
		"A at zip end  Launch",
		"A in air  Double jump",
		"L2 in air  Dive",
		"Fly along walls  Wall run",
	},
	Touch = {
		"Hold Web  Swing",
		"Zip  Web zip (aim with camera)",
		"Punch  Punch (hit fast to knock out)",
		"Jump at zip end  Launch",
		"Jump in air  Double jump",
		"Dive in air  Dive",
		"Fly along walls  Wall run",
	},
}

local function label(parent: Instance, props: { [string]: any }): TextLabel
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Font = H.Font
	text.TextColor3 = H.TextColor
	local anyText: any = text
	for key, value in props do
		anyText[key] = value
	end
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Transparency = 0.3
	stroke.Parent = text
	text.Parent = parent
	return text
end

local function roundBar(parent: Instance, props: { [string]: any }): (Frame, Frame)
	local back = Instance.new("Frame")
	back.BackgroundColor3 = Color3.new(0, 0, 0)
	back.BackgroundTransparency = 0.5
	back.BorderSizePixel = 0
	local anyBack: any = back
	for key, value in props do
		anyBack[key] = value
	end
	back.Parent = parent
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = H.AccentColor
	fill.BorderSizePixel = 0
	fill.Parent = back
	for _, frame in { back, fill } do
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = frame
	end
	return back, fill
end

local HUD = {}
HUD.__index = HUD

function HUD.new(ctx, motion)
	local cleaner = Cleaner.new()

	local gui = Instance.new("ScreenGui")
	gui.Name = "WebCreatureHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Enabled = not Menu.IsOpen
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	cleaner:Add(gui)

	-- Profile: level, XP, coins (below Roblox's top bar)
	local profileBox = Instance.new("Frame")
	profileBox.Name = "Profile"
	profileBox.Position = UDim2.fromOffset(20, 70)
	profileBox.Size = UDim2.fromOffset(240, 60)
	profileBox.BackgroundTransparency = 1
	profileBox.Parent = gui
	local levelText = label(profileBox, {
		Size = UDim2.fromOffset(80, 30),
		Text = "LV 1",
		TextSize = 26,
		TextColor3 = H.AccentColor,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local coinsText = label(profileBox, {
		Position = UDim2.fromOffset(84, 4),
		Size = UDim2.fromOffset(156, 24),
		Text = "",
		TextSize = 18,
		TextColor3 = Color3.fromRGB(255, 210, 80),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local _, xpFill = roundBar(profileBox, {
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.new(1, 0, 0, 7),
	})
	local xpText = label(profileBox, {
		Position = UDim2.fromOffset(0, 42),
		Size = UDim2.new(1, 0, 0, 14),
		Text = "",
		TextSize = 11,
		TextTransparency = 0.25,
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	-- Buttons
	local buttons = Instance.new("Frame")
	buttons.Position = UDim2.fromOffset(20, 136)
	buttons.Size = UDim2.fromOffset(240, 34)
	buttons.BackgroundTransparency = 1
	buttons.Parent = gui
	UIKit.button(buttons, "SUITS", Menu.OpenShop, {
		Size = UDim2.fromOffset(110, 34),
		TextSize = 15,
	})
	UIKit.button(buttons, "SETTINGS", Menu.OpenSettings, {
		Position = UDim2.fromOffset(120, 0),
		Size = UDim2.fromOffset(110, 34),
		TextSize = 15,
		BackgroundColor3 = UIKit.Colors.PanelLight,
	})

	-- Speed meter
	local meter = Instance.new("Frame")
	meter.Name = "SpeedMeter"
	meter.AnchorPoint = Vector2.new(0.5, 1)
	meter.Position = UDim2.new(0.5, 0, 1, -24)
	meter.Size = UDim2.fromOffset(220, 54)
	meter.BackgroundTransparency = 1
	meter.Parent = gui
	local speedText = label(meter, {
		Size = UDim2.new(1, 0, 0, 34),
		Text = "0",
		TextSize = 32,
	})
	label(meter, {
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, 0, 0, 12),
		Text = "SPEED",
		TextSize = 11,
		TextTransparency = 0.3,
	})
	local _, barFill = roundBar(meter, {
		Position = UDim2.new(0, 0, 1, -6),
		Size = UDim2.new(1, 0, 0, 5),
	})

	-- Crosshair
	local crosshair = Instance.new("Frame")
	crosshair.Name = "Crosshair"
	crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
	crosshair.Position = UDim2.fromScale(0.5, 0.5)
	crosshair.Size = UDim2.fromOffset(8, 8)
	crosshair.BackgroundColor3 = Color3.new(1, 1, 1)
	crosshair.BackgroundTransparency = 0.5
	crosshair.BorderSizePixel = 0
	crosshair.Parent = gui
	local crosshairCorner = Instance.new("UICorner")
	crosshairCorner.CornerRadius = UDim.new(1, 0)
	crosshairCorner.Parent = crosshair
	local crosshairRing = Instance.new("UIStroke")
	crosshairRing.Color = Color3.new(0, 0, 0)
	crosshairRing.Transparency = 0.5
	crosshairRing.Parent = crosshair

	-- Hints
	local hints = Instance.new("Frame")
	hints.Name = "Hints"
	hints.AnchorPoint = Vector2.new(0, 1)
	hints.Position = UDim2.new(0, 20, 1, -20)
	hints.Size = UDim2.fromOffset(300, 180)
	hints.BackgroundTransparency = 1
	hints.Visible = Settings.Get("ControlHints") == true
	hints.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)
	layout.Parent = hints

	local self = setmetatable({
		ctx = ctx,
		motion = motion,
		gui = gui,
		levelText = levelText,
		coinsText = coinsText,
		xpFill = xpFill,
		xpText = xpText,
		speedText = speedText,
		barFill = barFill,
		crosshair = crosshair,
		hints = hints,
		hintDevice = "",
		shownSpeed = 0,
		cleaner = cleaner,
	}, HUD)

	self:_refreshHints()
	if Profile.Data then
		self:_refreshProfile(Profile.Data)
	end

	cleaner:Add(Profile.Changed:Connect(function(data)
		self:_refreshProfile(data)
	end))
	cleaner:Add(Menu.Changed:Connect(function(isOpen: boolean)
		gui.Enabled = not isOpen
	end))
	cleaner:Add(Settings.Changed:Connect(function(key: string, value: any)
		if key == "ControlHints" then
			hints.Visible = value == true
		end
	end))
	cleaner:Add(UserInputService.LastInputTypeChanged:Connect(function()
		self:_refreshHints()
	end))
	cleaner:Add(UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == H.HelpKey then
			Settings.Set("ControlHints", not Settings.Get("ControlHints"))
		end
	end))

	cleaner:Add(RunService.RenderStepped:Connect(function(dt)
		self:_update(dt)
	end))

	return self
end

function HUD:_refreshProfile(data: any)
	self.levelText.Text = `LV {data.Level}`
	self.coinsText.Text = `{data.Coins} coins`
	local fraction = if data.XpNeeded > 0 then data.XpIntoLevel / data.XpNeeded else 0
	self.xpFill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
	self.xpText.Text = `{data.XpIntoLevel} / {data.XpNeeded} XP`
end

function HUD:_device(): string
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Touch then
		return "Touch"
	elseif string.find(last.Name, "Gamepad") then
		return "Gamepad"
	end
	return "Keyboard"
end

function HUD:_refreshHints()
	local device = self:_device()
	if device == self.hintDevice then
		return
	end
	self.hintDevice = device
	for _, child in self.hints:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	for i, line in HINTS[device] do
		label(self.hints, {
			LayoutOrder = i,
			Size = UDim2.new(1, 0, 0, 18),
			Text = line,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTransparency = 0.15,
		})
	end
end

function HUD:_update(dt: number)
	local speed = self.ctx.Root.AssemblyLinearVelocity.Magnitude
	self.shownSpeed += (speed - self.shownSpeed) * MathUtil.expAlpha(8, dt)
	self.speedText.Text = tostring(math.floor(self.shownSpeed + 0.5))
	self.barFill.Size = UDim2.fromScale(math.clamp(self.shownSpeed / H.SpeedMeterMax, 0, 1), 1)

	local ready = self.motion.zipReady
	self.crosshair.BackgroundColor3 = if ready then H.AccentColor else Color3.new(1, 1, 1)
	self.crosshair.BackgroundTransparency = if ready then 0 else 0.5
	self.crosshair.Size = if ready then UDim2.fromOffset(12, 12) else UDim2.fromOffset(8, 8)
end

function HUD:Destroy()
	self.cleaner:Clean()
end

return HUD
