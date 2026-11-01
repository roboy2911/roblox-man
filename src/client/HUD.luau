-- On-screen UI:
--   * Speed meter (bottom middle)
--   * Crosshair in the middle that lights up red when a web zip target is in reach
--   * Control hints (bottom left) that match your device; press H to hide/show

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Cleaner = require(ReplicatedStorage.Shared.Cleaner)
local Config = require(ReplicatedStorage.Shared.Config)
local MathUtil = require(ReplicatedStorage.Shared.MathUtil)

local H = Config.HUD

local HINTS = {
	Keyboard = {
		"Hold LMB  Swing",
		"E  Web zip",
		"Space at zip end  Launch",
		"Space in air  Double jump",
		"Q in air  Dive",
		"Fly along walls  Wall run",
		"H  Hide help",
	},
	Gamepad = {
		"Hold R2  Swing",
		"L1  Web zip",
		"A at zip end  Launch",
		"A in air  Double jump",
		"L2 in air  Dive",
		"Fly along walls  Wall run",
	},
	Touch = {
		"Hold Web  Swing",
		"Zip  Web zip (aim with camera)",
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

local HUD = {}
HUD.__index = HUD

function HUD.new(ctx, motion)
	local cleaner = Cleaner.new()

	local gui = Instance.new("ScreenGui")
	gui.Name = "WebCreatureHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	cleaner:Add(gui)

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
	local barBack = Instance.new("Frame")
	barBack.Position = UDim2.new(0, 0, 1, -6)
	barBack.Size = UDim2.new(1, 0, 0, 5)
	barBack.BackgroundColor3 = Color3.new(0, 0, 0)
	barBack.BackgroundTransparency = 0.5
	barBack.BorderSizePixel = 0
	barBack.Parent = meter
	local barFill = Instance.new("Frame")
	barFill.Size = UDim2.fromScale(0, 1)
	barFill.BackgroundColor3 = H.AccentColor
	barFill.BorderSizePixel = 0
	barFill.Parent = barBack
	for _, frame in { barBack, barFill } do
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = frame
	end

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
	hints.Size = UDim2.fromOffset(260, 160)
	hints.BackgroundTransparency = 1
	hints.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Padding = UDim.new(0, 2)
	layout.Parent = hints

	local self = setmetatable({
		ctx = ctx,
		motion = motion,
		gui = gui,
		speedText = speedText,
		barFill = barFill,
		crosshair = crosshair,
		hints = hints,
		hintDevice = "",
		hintsVisible = true,
		shownSpeed = 0,
		cleaner = cleaner,
	}, HUD)

	self:_refreshHints()

	cleaner:Add(UserInputService.LastInputTypeChanged:Connect(function()
		self:_refreshHints()
	end))
	cleaner:Add(UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == H.HelpKey then
			self.hintsVisible = not self.hintsVisible
			self.hints.Visible = self.hintsVisible
		end
	end))

	cleaner:Add(RunService.RenderStepped:Connect(function(dt)
		self:_update(dt)
	end))

	return self
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
