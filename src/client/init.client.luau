-- Client entry point: sets up input and camera once, and all movement systems per character.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cleaner = require(Shared:WaitForChild("Cleaner"))
local Signal = require(Shared:WaitForChild("Signal"))

local CameraController = require(script.CameraController)
local CharacterContext = require(script.CharacterContext)
local Effects = require(script.Effects)
local GearAnimator = require(script.GearAnimator)
local HUD = require(script.HUD)
local InputController = require(script.InputController)
local LocomotionController = require(script.LocomotionController)
local MovementState = require(script.MovementState)
local PoseController = require(script.PoseController)
local SwingController = require(script.SwingController)
local TrickController = require(script.TrickController)
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

	-- Shared info the movement systems write and the pose system reads.
	local motion = {
		webHand = "Right",
		pivot = nil :: Vector3?,
		lowness = 0,
		swingStyle = "Tuck",
		diving = false,
		flipStart = nil :: number?,
		flipKind = "Front",
		rollStart = nil :: number?,
		wallSide = 1,
		zipReady = false,
		-- Fired for things the UI and effects react to:
		-- SwingStart, Release(perfect), Land(speed), Zip, PointLaunch, AirJump, WallRun,
		-- WallJump, DiveCatch
		events = Signal.new(),
	}
	s:Add(motion.events)

	local fsm = s:Add(MovementState.new())
	local visuals = s:Add(WebVisuals.new(ctx))
	local effects = s:Add(Effects.new(ctx, motion))
	visuals.onImpact = function()
		effects:Stick()
	end
	s:Add(LocomotionController.new(ctx, fsm, motion))
	s:Add(SwingController.new(ctx, fsm, input, camera, visuals, effects, motion))
	s:Add(TrickController.new(ctx, fsm, input, camera, visuals, effects, motion))
	s:Add(PoseController.new(ctx, fsm, motion))
	s:Add(GearAnimator.new(ctx, fsm, motion))
	s:Add(HUD.new(ctx, motion))

	camera:SetCharacter(ctx.Root, ctx.Humanoid)
	s:Add(function()
		camera:SetCharacter(nil, nil)
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
