--!strict
--[[
	Visibility — la jauge de Visibilite de la Planque (decide avec Josh le 9
	novembre 2026).

	Logique pure : les sources et les reglages arrivent en argument.

	Ce qui se voit et s'entend de la Planque (ses constructions, ses lampes,
	la fumee du rechaud, le survivant, le bruit des coups la nuit) fait un
	NIVEAU. Chaque nuit, la jauge monte d'une part de ce niveau, et l'Oeil en
	oublie un peu. Elle attire des Repris en plus la nuit ; pleine, l'Oeil
	trouve la Planque.
]]

local Visibility = {}

export type Settings = {
	rate: number,
	decay: number,
	found: number,
	afterFound: number,
	extraEvery: number,
}

-- Le niveau : la somme des sources, jamais negatif (le camouflage cache, il
-- ne rend pas invisible ce qui ne se voyait pas).
function Visibility.level(sources: { number }): number
	local total = 0
	for _, value in sources do
		total += value
	end
	return math.max(total, 0)
end

-- La jauge apres une nuit a ce niveau.
function Visibility.night(gauge: number, level: number, settings: Settings): number
	return math.clamp(gauge + level * settings.rate - settings.decay, 0, settings.found)
end

-- Les Repris en plus, cette nuit, attires par la Planque.
function Visibility.extraRepris(gauge: number, settings: Settings): number
	return math.floor(gauge / settings.extraEvery)
end

-- Pleine : l'Oeil a trouve la Planque.
function Visibility.found(gauge: number, settings: Settings): boolean
	return gauge >= settings.found
end

return Visibility
