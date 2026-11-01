-- Level math. Each level needs a bit more XP than the last.

local Progression = {}

-- XP needed to go from `level` to `level + 1`.
function Progression.XpForLevel(level: number): number
	return 100 + (level - 1) * 50
end

-- Turns total XP into (level, xp into the current level, xp needed for the next level).
function Progression.FromXp(totalXp: number): (number, number, number)
	local level = 1
	local remaining = math.max(0, math.floor(totalXp))
	while remaining >= Progression.XpForLevel(level) and level < 999 do
		remaining -= Progression.XpForLevel(level)
		level += 1
	end
	return level, remaining, Progression.XpForLevel(level)
end

return Progression
