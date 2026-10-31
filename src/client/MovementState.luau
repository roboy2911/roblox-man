-- A small state machine: exactly one movement state (Ground, Air, Swing, ...) runs at a time.
-- Each state can have Enter(previousState, ...), Exit(nextState) and Update(dt).
-- Hooks run every frame before the current state's Update, whatever the state is
-- (used for things like "start a swing if the button is held").

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Signal)

export type StateHandlers = {
	Enter: ((previous: string?, ...any) -> ())?,
	Exit: ((nextState: string) -> ())?,
	Update: ((dt: number) -> ())?,
}

local MovementState = {}
MovementState.__index = MovementState

function MovementState.new()
	return setmetatable({
		Current = nil :: string?,
		Changed = Signal.new(),
		_states = {} :: { [string]: StateHandlers },
		_hooks = {} :: { (dt: number) -> () },
	}, MovementState)
end

function MovementState:Register(name: string, handlers: StateHandlers)
	self._states[name] = handlers
end

function MovementState:AddHook(fn: (dt: number) -> ())
	table.insert(self._hooks, fn)
end

function MovementState:Is(name: string): boolean
	return self.Current == name
end

function MovementState:Set(name: string, ...: any)
	if self.Current == name then
		return
	end
	local nextState = self._states[name]
	assert(nextState, `Unknown movement state "{name}"`)

	local previous = self.Current
	local previousState = previous and self._states[previous]
	if previousState and previousState.Exit then
		previousState.Exit(name)
	end

	self.Current = name
	if nextState.Enter then
		nextState.Enter(previous, ...)
	end
	self.Changed:Fire(name, previous)
end

function MovementState:Update(dt: number)
	for _, hook in self._hooks do
		hook(dt)
	end
	local state = self.Current and self._states[self.Current]
	if state and state.Update then
		state.Update(dt)
	end
end

function MovementState:Destroy()
	self.Changed:Destroy()
	table.clear(self._hooks)
end

return MovementState
