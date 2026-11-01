-- Small helpers so every menu looks the same: text, panels and buttons.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Sounds = require(script.Parent.Sounds)

local H = Config.HUD

local UIKit = {}

UIKit.Colors = {
	Panel = Color3.fromRGB(18, 18, 24),
	PanelLight = Color3.fromRGB(32, 32, 42),
	Text = H.TextColor,
	Muted = Color3.fromRGB(170, 170, 185),
	Accent = H.AccentColor,
	Good = Color3.fromRGB(70, 200, 100),
	Disabled = Color3.fromRGB(70, 70, 80),
}

local function setProps(instance: Instance, props: { [string]: any }?)
	if not props then
		return
	end
	local target: any = instance
	for key, value in props do
		target[key] = value
	end
end

function UIKit.corner(parent: Instance, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 10)
	corner.Parent = parent
	return corner
end

function UIKit.frame(parent: Instance, props: { [string]: any }?): Frame
	local frame = Instance.new("Frame")
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = UIKit.Colors.Panel
	setProps(frame, props)
	frame.Parent = parent
	return frame
end

function UIKit.text(parent: Instance, props: { [string]: any }?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = H.Font
	label.TextColor3 = UIKit.Colors.Text
	label.TextSize = 18
	setProps(label, props)
	label.Parent = parent
	return label
end

-- A rounded button that grows a little on hover and plays the click sound.
function UIKit.button(parent: Instance, text: string, onClick: () -> (), props: { [string]: any }?): TextButton
	local button = Instance.new("TextButton")
	button.AutoButtonColor = false
	button.BorderSizePixel = 0
	button.BackgroundColor3 = UIKit.Colors.Accent
	button.Font = H.Font
	button.Text = text
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextSize = 20
	button.Size = UDim2.fromOffset(220, 48)
	setProps(button, props)
	UIKit.corner(button, 10)
	local scale = Instance.new("UIScale")
	scale.Parent = button
	button.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1.05 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)
	button.Activated:Connect(function()
		if button.Active then
			Sounds.Play("Click")
			onClick()
		end
	end)
	button.Parent = parent
	return button
end

-- A centered modal panel with a title and a close button. It's at most `maxSize` pixels, and
-- shrinks to fit small (phone) screens. Returns (panel, content area).
function UIKit.modal(parent: Instance, title: string, maxSize: Vector2, onClose: () -> ()): (Frame, Frame)
	local panel = UIKit.frame(parent, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.94, 0.88),
		BackgroundTransparency = 0.05,
		Visible = false,
		ZIndex = 5,
	})
	UIKit.corner(panel, 14)
	local stroke = Instance.new("UIStroke")
	stroke.Color = UIKit.Colors.Accent
	stroke.Thickness = 2
	stroke.Transparency = 0.4
	stroke.Parent = panel
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = maxSize
	limit.Parent = panel

	UIKit.text(panel, {
		Position = UDim2.fromOffset(20, 12),
		Size = UDim2.new(1, -80, 0, 36),
		Text = title,
		TextSize = 28,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 6,
	})
	UIKit.button(panel, "X", onClose, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(40, 40),
		BackgroundColor3 = UIKit.Colors.PanelLight,
		ZIndex = 6,
	})

	local content = UIKit.frame(panel, {
		Position = UDim2.fromOffset(16, 60),
		Size = UDim2.new(1, -32, 1, -76),
		BackgroundTransparency = 1,
		ZIndex = 6,
	})
	return panel, content
end

return UIKit
