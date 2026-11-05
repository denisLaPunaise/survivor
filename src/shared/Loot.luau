--!strict
--[[
	Loot — ce qu'on trouve en fouillant, et ce que pese le sac.

	Logique pure : le catalogue et les tables arrivent en argument depuis
	Config, le hasard aussi.
]]

local Loot = {}

export type Entry = {
	item: string,
	weight: number,
}

export type Table = {
	rolls: { min: number, max: number },
	entries: { Entry },
}

export type Item = {
	name: string,
	weight: number,
}

export type BagSettings = {
	slots: number,
	freeWeight: number,
	maxWeight: number,
	slowestFactor: number,
}

-- Les objets trouves dans un contenant. Chaque tirage est independant : deux
-- conserves dans le meme placard, ca arrive.
function Loot.roll(lootTable: Table, nextInt: (number, number) -> number): { string }
	local total = 0
	for _, entry in lootTable.entries do
		total += entry.weight
	end
	local out: { string } = {}
	if total <= 0 then
		return out
	end
	local count = nextInt(lootTable.rolls.min, lootTable.rolls.max)
	for _ = 1, count do
		local pick = nextInt(1, total)
		for _, entry in lootTable.entries do
			pick -= entry.weight
			if pick <= 0 then
				table.insert(out, entry.item)
				break
			end
		end
	end
	return out
end

function Loot.bagWeight(bag: { string }, items: { [string]: Item }): number
	local total = 0
	for _, itemId in bag do
		total += items[itemId].weight
	end
	return total
end

-- Multiplicateur de vitesse : rien jusqu'a `freeWeight`, puis on ralentit
-- lineairement jusqu'a `slowestFactor` a `maxWeight`. Un joueur lent se cache
-- mal : c'est le prix de rentrer charge.
function Loot.speedFactor(weight: number, settings: BagSettings): number
	if weight <= settings.freeWeight then
		return 1
	end
	local span = settings.maxWeight - settings.freeWeight
	local alpha = math.clamp((weight - settings.freeWeight) / span, 0, 1)
	return 1 - (1 - settings.slowestFactor) * alpha
end

return Loot
