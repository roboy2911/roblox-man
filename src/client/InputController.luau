-- Turns raw input (mouse, gamepad, touch button) into named actions like "Swing".
-- ContextActionService creates the on-screen button for mobile automatically.

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Signal = require(ReplicatedStorage.Shared.Signal)

local InputController = {}
InputController.__index = InputController

function InputController.new()
	local self = setmetatable({
		_down = {} :: { [string]: boolean },
		Enabled = true, -- turned off while menus are open
		ActionBegan = Signal.new(),
		ActionEnded = Signal.new(),
	}, InputController)

	local function handle(action: string, state: Enum.UserInputState, _input: InputObject)
		if not self.Enabled then
			if self._down[action] then
				self._down[action] = false
				self.ActionEnded:Fire(action)
			end
			return Enum.ContextActionResult.Pass
		end
		if state == Enum.UserInputState.Begin then
			self._down[action] = true
			self.ActionBegan:Fire(action)
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			if self._down[action] then
				self._down[action] = false
				self.ActionEnded:Fire(action)
			end
		end
		return Enum.ContextActionResult.Sink
	end

	for action, binding in Config.Input do
		ContextActionService:BindAction(action, handle, true, table.unpack(binding.Inputs))
		ContextActionService:SetTitle(action, binding.Title)
	end

	return self
end

function InputController:IsDown(action: string): boolean
	return self.Enabled and self._down[action] == true
end

function InputController:SetEnabled(enabled: boolean)
	self.Enabled = enabled
	if not enabled then
		for action, down in self._down do
			if down then
				self._down[action] = false
				self.ActionEnded:Fire(action)
			end
		end
	end
end

return InputController
