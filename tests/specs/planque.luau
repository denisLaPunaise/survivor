--!strict
--[[
	La faim, le repas du soir, et ce que coute une construction.
]]

local Config = require("../../src/shared/Config")
local Planque = require("../../src/shared/Planque")

local harness = require("../harness")

return function(t: harness.Harness)
	local needs = Config.needs

	t.section("Payer une construction")

	local stock = { planche = 3, ferraille = 1 }
	t.equal(
		"il manque de la ferraille : rien n'est pris",
		Planque.pay(stock, { planche = 3, ferraille = 2 }),
		false
	)
	t.equal("la reserve est intacte", stock.planche, 3)
	t.equal("assez : c'est paye", Planque.pay(stock, { planche = 2, ferraille = 1 }), true)
	t.check("et retire", stock.planche == 1 and stock.ferraille == nil)

	t.section("Chaque construction coute des objets qui existent")

	for _, b in Config.planque.builds do
		for itemId in b.cost do
			t.check(
				string.format("%s : %s est au catalogue", b.id, itemId),
				Config.items[itemId] ~= nil
			)
		end
	end
	for itemId in Config.planque.repairCost do
		t.check("la reparation : " .. itemId .. " est au catalogue", Config.items[itemId] ~= nil)
	end
	for _, dish in Config.planque.menu do
		for itemId in dish do
			t.check("le repas : " .. itemId .. " est au catalogue", Config.items[itemId] ~= nil)
		end
	end
	-- Chaque construction a besoin d'au moins un objet qu'on ne trouve pas
	-- dans une cuisine : il faut aller fouiller ailleurs.
	local kitchen: { [string]: boolean } = {}
	for _, entry in Config.loot.tables.cuisine.entries do
		kitchen[entry.item] = true
	end
	for _, b in Config.planque.builds do
		local elsewhere = false
		for itemId in b.cost do
			if not kitchen[itemId] then
				elsewhere = true
			end
		end
		t.check(b.id .. " demande de fouiller ailleurs qu'en cuisine", elsewhere)
	end

	t.section("La faim")

	local hunger = needs.hungerMax
	local minutes = 0
	while hunger > 0 and minutes < 200 do
		hunger = Planque.hungerAfter(needs, hunger, 60)
		minutes += 1
	end
	-- Un jour fait ~13 min (Config.day + la nuit) : plus d'un jour, moins de trois.
	t.check(
		string.format("sans manger, la faim est vide en %d min", minutes),
		minutes > 15 and minutes < 40
	)
	local speed = Planque.hungerEffects(needs, needs.hungryBelow - 1, 1)
	t.equal("affame : on ralentit", speed, needs.hungrySpeedFactor)
	local _, damage = Planque.hungerEffects(needs, 0, 10)
	t.check("vide : on perd de la sante", damage > 0)
	local _, none = Planque.hungerEffects(needs, 50, 10)
	t.equal("rassasie : rien", none, 0)

	t.section("Le repas du soir")

	local pantry = { conserve = 3, eau = 1 }
	local fed = Planque.serveMeal(pantry, Config.planque.menu, 3)
	t.equal("trois conserves et une eau nourrissent deux personnes", fed, 2)
	t.check("et la reserve est vide", pantry.conserve == nil and pantry.eau == nil)
	t.equal(
		"une reserve vide ne nourrit personne",
		Planque.serveMeal({}, Config.planque.menu, 3),
		0
	)
end
