-- Client entry point: sets up input and camera once, and all movement systems per character.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cleaner = require(Shared:WaitForChild("Cleaner"))

local CameraController = require(script.CameraController)
local CharacterContext = require(script.CharacterContext)
local InputController = require(script.InputController)
local LocomotionController = require(script.LocomotionController)
local MovementState = require(script.MovementState)
local SwingController = require(script.SwingController)
local WebVisuals = require(script.WebVisuals)

local player = Players.LocalPlayer
local input = InputController.new()
local camera = CameraController.new()

local session = nil
local spawnCount = 0

local function startCharacter(character: Model)
	spawnCount += 1
	local thisSpawn = spawnCount

	if session then
		session:Clean()
		session = nil
	end

	local ctx = CharacterContext.new(character)
	if not ctx then
		return
	end
	if thisSpawn ~= spawnCount then
		-- A newer character arrived while we were waiting.
		ctx:Destroy()
		return
	end

	local s = Cleaner.new()
	session = s
	s:Add(ctx)

	local fsm = s:Add(MovementState.new())
	local visuals = s:Add(WebVisuals.new(ctx))
	s:Add(LocomotionController.new(ctx, fsm))
	s:Add(SwingController.new(ctx, fsm, input, camera, visuals))

	camera:SetRoot(ctx.Root)
	s:Add(function()
		camera:SetRoot(nil)
	end)

	fsm:Set(if ctx:IsGrounded() then "Ground" else "Air")

	s:Add(RunService.PreSimulation:Connect(function(dt)
		fsm:Update(dt)
	end))

	s:Add(ctx.Humanoid.Died:Connect(function()
		if session == s then
			s:Clean()
			session = nil
		end
	end))
end

player.CharacterAdded:Connect(startCharacter)
if player.Character then
	task.spawn(startCharacter, player.Character)
end
