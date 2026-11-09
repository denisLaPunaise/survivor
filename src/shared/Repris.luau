--!strict
--[[
	Repris — ce qui decide du comportement des Repris, et la taille des nuits.

	Logique pure : aucune API Roblox. Les distances et les etats arrivent en
	argument, les reglages aussi (Config.repris).

	LA REGLE DU JOUR (concept) : les Repris dorment a l'interieur. Ils se
	reveillent si l'on fait du bruit pres d'eux (courir, fouiller) ou si on
	les touche presque. Dehors c'est l'Oeil, dedans ce sont les Repris : il
	faut choisir son danger.
]]

local Repris = {}

export type Wake = {
	sprintRadius: number,
	searchRadius: number,
	touchRadius: number,
}

export type Noise = "none" | "sprint" | "search"

-- Un Repris endormi se reveille-t-il pour ce joueur, a cette distance, avec ce
-- bruit ?
function Repris.wakes(wake: Wake, distance: number, noise: Noise): boolean
	if distance <= wake.touchRadius then
		return true
	end
	if noise == "sprint" then
		return distance <= wake.sprintRadius
	end
	if noise == "search" then
		return distance <= wake.searchRadius
	end
	return false
end

export type Candidate = {
	id: any,
	distance: number,
	visible: boolean,
}

-- La cible : le joueur visible le plus proche dans le rayon de poursuite. Un
-- joueur qu'il ne voit pas (derriere un mur, cache) ne compte pas.
function Repris.pickTarget(candidates: { Candidate }, chaseRadius: number): any?
	local best: any? = nil
	local bestDistance = math.huge
	for _, c in candidates do
		if c.visible and c.distance <= chaseRadius and c.distance < bestDistance then
			best = c.id
			bestDistance = c.distance
		end
	end
	return best
end

export type Night = {
	base: number,
	perNight: number,
	perPlayer: number,
	max: number,
	runnerShareStart: number,
	runnerSharePerNight: number,
	runnerShareMax: number,
}

-- Combien de Repris descendent la nuit `night` (1 pour la premiere), pour
-- `players` joueurs. Plus on est nombreux, plus ils sont nombreux : la
-- difficulte suit l'equipe (concept).
function Repris.waveSize(night: Night, nightNumber: number, players: number): number
	local count = night.base
		+ night.perNight * (nightNumber - 1)
		+ night.perPlayer * math.max(players - 1, 0)
	return math.min(math.floor(count), night.max)
end

-- La part de Coureurs dans la vague : aucun au debut, de plus en plus.
function Repris.runnerShare(night: Night, nightNumber: number): number
	return math.clamp(
		night.runnerShareStart + night.runnerSharePerNight * (nightNumber - 1),
		0,
		night.runnerShareMax
	)
end

export type Arrival = { fromDay: number, dayShare: number, nightShare: number }
export type Share = { id: string, share: number }

-- Les sortes deja arrivees le jour `day`, et leur part : parmi les endormis
-- du jour, ou parmi ceux qui tombent la nuit. Triees par nom : le meme tirage
-- donne toujours la meme sorte.
function Repris.shares(arrivals: { [string]: Arrival }, day: number, night: boolean): { Share }
	local out: { Share } = {}
	for id, arrival in arrivals do
		local share = if night then arrival.nightShare else arrival.dayShare
		if day >= arrival.fromDay and share > 0 then
			table.insert(out, { id = id, share = share })
		end
	end
	table.sort(out, function(a, b)
		return a.id < b.id
	end)
	return out
end

-- La sorte d'un Repris, pour un tirage `roll` entre 0 et 1 : chaque part a
-- sa tranche, le reste est `base` (l'Errant).
function Repris.pickKind(shares: { Share }, roll: number, base: string): string
	local cursor = 0
	for _, entry in shares do
		cursor += entry.share
		if roll < cursor then
			return entry.id
		end
	end
	return base
end

-- Un coup sur un joueur : sa sante apres le coup, et s'il tombe. On ne meurt
-- pas d'un coup : on tombe, et un ami peut nous relever (concept).
function Repris.hit(health: number, damage: number): (number, boolean)
	local after = health - damage
	if after <= 0 then
		return 0, true
	end
	return after, false
end

return Repris
