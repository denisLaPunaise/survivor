--!strict
--[[
	Exposure — la jauge d'exposition : etre vu n'est pas une mort immediate.

	Logique pure. La jauge va de 0 a 1 ; pleine, le joueur est aspire.
	`seen` vaut 0 (cache), 1 (a decouvert) ou entre les deux (un buisson qui
	couvre a moitie). Traverser une rue en courant passe ; rester plante au
	milieu, non.
]]

local Exposure = {}

export type Settings = {
	fillSeconds: number,
	drainSeconds: number,
}

function Exposure.step(level: number, seen: number, dt: number, settings: Settings): number
	local nextLevel = if seen > 0
		then level + (dt * seen / settings.fillSeconds)
		else level - (dt / settings.drainSeconds)
	return math.clamp(nextLevel, 0, 1)
end

function Exposure.isTaken(level: number): boolean
	return level >= 1
end

return Exposure
