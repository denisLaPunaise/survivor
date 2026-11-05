--!strict
--[[
	Growth — une quantite qui change jour apres jour, jusqu'a une limite.

	Logique pure. Sert a tout ce qui durcit avec les jours : le nombre de
	Repris, la vitesse a laquelle l'Oeil traque, la precision de sa visee.
	`perDay` peut etre negatif (une erreur qui diminue) : `limit` est alors un
	plancher, et non un plafond. `fromDay` : le jour ou la courbe commence a
	bouger ; avant, elle vaut `start` (l'Oeil qui s'impatiente quand on
	s'attarde dans un quartier).
]]

local Growth = {}

export type Curve = {
	start: number,
	perDay: number,
	limit: number,
	fromDay: number,
}

-- La valeur le jour `dayNumber` (jusqu'au jour `fromDay`, elle vaut `start`).
function Growth.onDay(curve: Curve, dayNumber: number): number
	local value = curve.start + curve.perDay * math.max(dayNumber - curve.fromDay, 0)
	if curve.perDay >= 0 then
		return math.min(value, curve.limit)
	end
	return math.max(value, curve.limit)
end

return Growth
