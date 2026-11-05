--!strict
--[[
	Hiding — la memoire du Veilleur et la ville qui change chaque matin.

	Logique pure. Le hasard arrive en argument (`nextInt(lo, hi)`), pour que
	les tests le rejouent.

	LA REGLE (decidee avec Josh) : une cachette fragile utilisee est marquee.
	Au Balayage SUIVANT, l'Oeil vient d'abord sur les cachettes marquees et les
	arrache. Jamais au Balayage pendant lequel on s'y est cache : se cacher au
	signal puis se faire arracher dans la foulee serait une punition sans
	parade.
]]

local Hiding = {}

export type Mark = {
	day: number,
	sweep: number,
}

-- `sweep` est le numero GLOBAL du Balayage (il ne repart pas a 1 chaque jour),
-- ce qui permet de comparer deux marques sans se soucier des jours.
function Hiding.mark(marks: { [string]: Mark }, spotId: string, day: number, sweep: number)
	if marks[spotId] == nil then
		marks[spotId] = { day = day, sweep = sweep }
	end
end

-- Les cachettes que l'Oeil verifie au Balayage `sweep` du jour `day`, triees.
-- Une marque plus vieille que `markDays` jours s'efface et disparait de la
-- table : la ville oublie, le Veilleur aussi.
function Hiding.marked(
	marks: { [string]: Mark },
	day: number,
	sweep: number,
	markDays: number
): { string }
	local out: { string } = {}
	for spotId, mark in marks do
		if day - mark.day >= markDays then
			marks[spotId] = nil
		elseif mark.sweep < sweep then
			table.insert(out, spotId)
		end
	end
	table.sort(out)
	return out
end

-- Les emplacements ou poser les cachettes fragiles ce matin. On evite ceux de
-- `avoid` (les cachettes arrachees hier ne reviennent pas au meme endroit),
-- sauf s'il n'en reste pas assez.
function Hiding.pickAnchors(
	anchorIds: { string },
	count: number,
	nextInt: (number, number) -> number,
	avoid: { [string]: boolean }
): { string }
	local fresh: { string } = {}
	local stale: { string } = {}
	local sorted = table.clone(anchorIds)
	-- Trier d'abord : l'ordre des enfants d'un dossier Roblox n'est pas garanti,
	-- et le meme hasard doit donner la meme ville.
	table.sort(sorted)
	for _, id in sorted do
		if avoid[id] then
			table.insert(stale, id)
		else
			table.insert(fresh, id)
		end
	end

	local function shuffle(list: { string })
		for i = #list, 2, -1 do
			local j = nextInt(1, i)
			list[i], list[j] = list[j], list[i]
		end
	end
	shuffle(fresh)
	shuffle(stale)

	local out: { string } = {}
	for _, id in fresh do
		if #out >= count then
			return out
		end
		table.insert(out, id)
	end
	for _, id in stale do
		if #out >= count then
			return out
		end
		table.insert(out, id)
	end
	return out
end

return Hiding
