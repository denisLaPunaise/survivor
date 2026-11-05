--!strict
--[[
	La fouille et le poids du sac.
]]

local Config = require("../../src/shared/Config")
local Loot = require("../../src/shared/Loot")

local harness = require("../harness")

local function seeded(seed: number): (number, number) -> number
	local state = seed
	return function(lo: number, hi: number): number
		-- Park-Miller : le produit reste sous 2^53, donc exact en double.
		state = (state * 16807) % 2147483647
		return lo + (state % (hi - lo + 1))
	end
end

return function(t: harness.Harness)
	t.section("Chaque table ne donne que des objets qui existent")

	for tableId, lootTable in Config.loot.tables do
		for _, entry in lootTable.entries do
			t.check(
				string.format("%s : %s est au catalogue", tableId, entry.item),
				Config.items[entry.item] ~= nil
			)
		end
		t.check(tableId .. " : au moins un tirage", lootTable.rolls.min >= 1)
	end

	t.section("Les tirages suivent les poids")

	local rng = seeded(11)
	local counts: { [string]: number } = {}
	local rolls = 0
	for _ = 1, 4000 do
		for _, item in Loot.roll(Config.loot.tables.cuisine, rng) do
			counts[item] = (counts[item] or 0) + 1
			rolls += 1
		end
	end
	local share = (counts["conserve"] or 0) / rolls
	t.check(
		string.format("la conserve sort ~50 %% du temps en cuisine (%.0f %%)", share * 100),
		share > 0.45 and share < 0.55
	)
	t.check("un tirage rend entre 1 et 3 objets en cuisine", rolls >= 4000 and rolls <= 12000)

	t.section("Le sac ralentit")

	local bag = Config.bag
	t.equal("leger, on court normalement", Loot.speedFactor(bag.freeWeight, bag), 1)
	t.equal(
		"au maximum, on avance au plus lent",
		Loot.speedFactor(bag.maxWeight, bag),
		bag.slowestFactor
	)
	t.equal(
		"au-dela, on ne ralentit plus",
		Loot.speedFactor(bag.maxWeight * 3, bag),
		bag.slowestFactor
	)
	t.equal(
		"deux ferrailles et une conserve pesent 5",
		Loot.bagWeight({ "ferraille", "ferraille", "conserve" }, Config.items),
		5
	)

	-- Un sac plein des objets les plus lourds doit ralentir : sinon le poids ne
	-- coute rien et le reglage ne sert a rien.
	local heaviest = 0
	for _, item in Config.items do
		heaviest = math.max(heaviest, item.weight)
	end
	t.check(
		"un sac plein d'objets lourds ralentit vraiment",
		Loot.speedFactor(heaviest * bag.slots, bag) < 1
	)
end
