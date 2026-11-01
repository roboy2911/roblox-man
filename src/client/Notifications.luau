-- Small messages in the bottom-right corner (rewards, level ups, crimes reported).
-- They fade out after a few seconds.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sounds = require(script.Parent.Sounds)
local UIKit = require(script.Parent.UIKit)

local MAX_SHOWN = 4
local SHOW_TIME = 4

local Notifications = {}

local list: Frame
local counter = 0

function Notifications.Show(text: string)
	if not list then
		return
	end
	local shown = {}
	for _, child in list:GetChildren() do
		if child:IsA("TextLabel") then
			table.insert(shown, child)
		end
	end
	counter += 1
	if #shown >= MAX_SHOWN then
		shown[1]:Destroy()
	end

	local label = UIKit.text(list, {
		Size = UDim2.new(1, 0, 0, 26),
		Text = text,
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTransparency = 1,
		LayoutOrder = counter,
	})
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Transparency = 1
	stroke.Parent = label

	TweenService:Create(label, TweenInfo.new(0.2), { TextTransparency = 0 }):Play()
	TweenService:Create(stroke, TweenInfo.new(0.2), { Transparency = 0.4 }):Play()
	task.delay(SHOW_TIME, function()
		if label.Parent then
			TweenService:Create(label, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
			TweenService:Create(stroke, TweenInfo.new(0.5), { Transparency = 1 }):Play()
			task.wait(0.5)
			label:Destroy()
		end
	end)

	if string.find(text, "LEVEL UP") then
		Sounds.Play("LevelUp")
	elseif string.find(text, "coins") then
		Sounds.Play("Coins")
	elseif string.find(text, "Crime reported") then
		Sounds.Play("CrimeAlert")
	end
end

function Notifications.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Notifications"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	list = UIKit.frame(gui, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 1, -90),
		Size = UDim2.fromOffset(420, 130),
		BackgroundTransparency = 1,
	})
	local layout = Instance.new("UIListLayout")
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)
	layout.Parent = list

	Remotes.Event("Notify").OnClientEvent:Connect(function(text: any)
		if type(text) == "string" then
			Notifications.Show(text)
		end
	end)
end

return Notifications
