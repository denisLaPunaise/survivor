--!strict
--[[
	Crew — qui est encore debout.

	Logique pure. LA DEFAITE (decidee avec Josh) : la partie est perdue quand
	plus aucun joueur n'est debout, tombe, aspire ou attache dans un cocon. Un
	serveur sans joueur n'est pas une defaite : personne n'a perdu, il n'y a
	personne.

	Et ou l'Oeil recrache un aspire, la nuit : loin de la Planque, pour que
	ses amis aient a sortir le chercher.
]]

local Crew = {}

function Crew.isWiped(standing: { [any]: boolean }): boolean
	local anyone = false
	for _, isStanding in standing do
		anyone = true
		if isStanding then
			return false
		end
	end
	return anyone
end

export type Point = { x: number, z: number }

-- Un point au hasard parmi ceux a `minDistance` au moins de `avoid` (la
-- Planque). Rend son indice, ou nil s'il n'y en a aucun.
function Crew.pickLanding(
	points: { Point },
	avoid: Point,
	minDistance: number,
	nextInt: (number, number) -> number
): number?
	local far: { number } = {}
	for i, p in points do
		local dx, dz = p.x - avoid.x, p.z - avoid.z
		if dx * dx + dz * dz >= minDistance * minDistance then
			table.insert(far, i)
		end
	end
	if #far == 0 then
		return nil
	end
	return far[nextInt(1, #far)]
end

return Crew
