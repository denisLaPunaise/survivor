--!strict
--[[
	Crew — qui est encore debout.

	Logique pure. LA DEFAITE (decidee avec Josh) : la partie est perdue quand
	plus aucun joueur n'est debout, tombe ou aspire. Un serveur sans joueur
	n'est pas une defaite : personne n'a perdu, il n'y a personne.
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

return Crew
