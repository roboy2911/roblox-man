-- Finds a rig's joints by name and lets you rotate them, on both classic Motor6D joints and
-- newer AnimationConstraint joints. Rotating the joint's fixed offset (C0 / parent attachment)
-- means animations can't overwrite it.

local JointUtil = {}

export type Joint = {
	instance: Instance,
	base: CFrame,
	set: (CFrame) -> (), -- sets the offset to base * rotation
}

function JointUtil.make(instance: Instance): Joint?
	if instance:IsA("Motor6D") then
		local motor = instance
		local base = motor.C0
		return {
			instance = motor,
			base = base,
			set = function(rotation: CFrame)
				motor.C0 = base * rotation
			end,
		}
	elseif instance:IsA("AnimationConstraint") then
		local attachment = instance.Attachment0
		if not attachment then
			return nil
		end
		local base = attachment.CFrame
		return {
			instance = instance,
			base = base,
			set = function(rotation: CFrame)
				attachment.CFrame = base * rotation
			end,
		}
	end
	return nil
end

-- Finds the named joints anywhere in `model` (skipping the Web Creature's gear).
function JointUtil.find(model: Instance, names: { [string]: boolean }): { [string]: Joint }
	local found = {}
	for _, descendant in model:GetDescendants() do
		if names[descendant.Name] and not found[descendant.Name] and not descendant:FindFirstAncestor("WebCreatureGear") then
			local joint = JointUtil.make(descendant)
			if joint then
				found[descendant.Name] = joint
			end
		end
	end
	return found
end

return JointUtil
