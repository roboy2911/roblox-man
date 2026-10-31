--!strict
local MathUtil = {}

-- Frame-rate independent smoothing factor for lerps.
function MathUtil.expAlpha(speed: number, dt: number): number
	return 1 - math.exp(-speed * dt)
end

function MathUtil.flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

function MathUtil.safeUnit(v: Vector3, fallback: Vector3): Vector3
	if v.Magnitude < 1e-4 then
		return fallback
	end
	return v.Unit
end

-- Removes the part of v that points along normal (normal must be a unit vector).
function MathUtil.projectOnPlane(v: Vector3, normal: Vector3): Vector3
	return v - normal * v:Dot(normal)
end

function MathUtil.clampMagnitude(v: Vector3, max: number): Vector3
	if v.Magnitude > max then
		return v.Unit * max
	end
	return v
end

function MathUtil.remapClamped(x: number, inMin: number, inMax: number, outMin: number, outMax: number): number
	local t = math.clamp((x - inMin) / (inMax - inMin), 0, 1)
	return outMin + (outMax - outMin) * t
end

return MathUtil
