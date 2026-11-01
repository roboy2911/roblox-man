-- Draws other players' webs, poses and spider legs from the snapshots their game sends
-- (relayed by the server). Their movement itself already replicates through Roblox physics;
-- this adds everything that's drawn locally.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cleaner = require(ReplicatedStorage.Shared.Cleaner)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Signal = require(ReplicatedStorage.Shared.Signal)
local CharacterContext = require(script.Parent.CharacterContext)
local GearAnimator = require(script.Parent.GearAnimator)
local PoseController = require(script.Parent.PoseController)
local WebVisuals = require(script.Parent.WebVisuals)

local RemoteViews = {}

type View = {
	character: Model,
	ctx: any,
	fsm: any,
	motion: any,
	visuals: any,
	cleaner: any,
}

local views: { [Player]: View } = {}
local creating: { [Player]: boolean } = {}
local pending: { [Player]: any } = {}
local retryAfter: { [Player]: number } = {}

local function destroyView(player: Player)
	local view = views[player]
	if view then
		views[player] = nil
		view.cleaner:Clean()
	end
end

local function apply(view: View, snapshot: any)
	local m = view.motion
	local now = os.clock()
	view.fsm.Current = snapshot.s or "Ground"
	m.webHand = snapshot.h or "Right"
	m.pivot = snapshot.p
	m.lowness = snapshot.l or 0
	m.swingStyle = snapshot.st or "Tuck"
	m.diving = snapshot.d == true
	m.flipKind = snapshot.fk or "Front"
	m.flipStart = if snapshot.fa then now - snapshot.fa else nil
	m.rollStart = if snapshot.ra then now - snapshot.ra else nil
	m.wallSide = snapshot.ws or 1
	m.punchStart = if snapshot.pa then now - snapshot.pa else nil
	m.punchHand = snapshot.ph or "Right"

	local visuals = view.visuals
	local points = snapshot.w
	if points and #points > 0 then
		if not visuals.active then
			visuals:Attach(points[1], view.ctx.HandAttachments[m.webHand])
		end
		visuals:SetPoints(points)
	elseif visuals.active then
		visuals:Detach(true)
	end
end

local function createView(player: Player)
	if creating[player] or os.clock() < (retryAfter[player] or 0) then
		return
	end
	local character = player.Character
	if not character then
		return
	end
	creating[player] = true
	task.spawn(function()
		local ctx = CharacterContext.new(character)
		creating[player] = nil
		if not ctx or player.Character ~= character or not player.Parent then
			if ctx then
				ctx:Destroy()
			end
			-- Not loaded yet (e.g. too far away to be streamed in); try again later.
			retryAfter[player] = os.clock() + 3
			return
		end

		local cleaner = Cleaner.new()
		cleaner:Add(ctx)
		local fsm = {
			Current = "Ground",
			Is = function(self, name: string): boolean
				return self.Current == name
			end,
		}
		local motion = {
			webHand = "Right",
			lowness = 0,
			swingStyle = "Tuck",
			diving = false,
			flipKind = "Front",
			wallSide = 1,
			punchHand = "Right",
			events = Signal.new(),
		}
		cleaner:Add(motion.events)
		local visuals = cleaner:Add(WebVisuals.new(ctx))
		cleaner:Add(PoseController.new(ctx, fsm, motion, true))
		cleaner:Add(GearAnimator.new(ctx, fsm, motion))

		local view: View = {
			character = character,
			ctx = ctx,
			fsm = fsm,
			motion = motion,
			visuals = visuals,
			cleaner = cleaner,
		}
		views[player] = view
		cleaner:Add(character.AncestryChanged:Connect(function()
			if not character:IsDescendantOf(workspace) and views[player] == view then
				destroyView(player)
			end
		end))

		local snapshot = pending[player]
		pending[player] = nil
		if snapshot then
			pcall(apply, view, snapshot)
		end
	end)
end

function RemoteViews.Start()
	Remotes.Event("MotionBroadcast").OnClientEvent:Connect(function(player: Player, snapshot: any)
		if typeof(player) ~= "Instance" or player == Players.LocalPlayer or type(snapshot) ~= "table" then
			return
		end
		local view = views[player]
		if view and view.character ~= player.Character then
			destroyView(player)
			view = nil
		end
		if not view then
			pending[player] = snapshot
			createView(player)
			return
		end
		local ok, err = pcall(apply, view, snapshot)
		if not ok then
			warn("[Web Creature] Couldn't show another player's movement:", err)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		destroyView(player)
		pending[player] = nil
		retryAfter[player] = nil
	end)
end

return RemoteViews
