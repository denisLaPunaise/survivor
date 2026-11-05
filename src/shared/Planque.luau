--!strict
--[[
	Planque — la faim, le repas du soir, et ce que coute une construction.

	Logique pure : la reserve, les couts et les reglages arrivent en argument.

	POURQUOI UN REPAS DU SOIR plutot que manger n'importe quand : manger dans un
	menu a la manette, au milieu des Balayages, serait une corvee. Le soir, ceux
	qui sont rentres a la Planque mangent ensemble sur la reserve commune. C'est
	ce qui oblige a fouiller (il faut de quoi manger) et a rentrer (la nuit, au
	chaud, on mange). Decision du 5 novembre 2026, a valider en jouant.
]]

local Planque = {}

export type Stock = { [string]: number }

export type Needs = {
	hungerMax: number,
	hungerPerMinute: number,
	hungryBelow: number,
	hungrySpeedFactor: number,
	starvingDamagePerSecond: number,
}

function Planque.canAfford(stock: Stock, cost: Stock): boolean
	for itemId, amount in cost do
		if (stock[itemId] or 0) < amount then
			return false
		end
	end
	return true
end

-- Prend le cout dans la reserve. Rend faux, sans rien toucher, si elle ne
-- suffit pas : on ne construit jamais a moitie.
function Planque.pay(stock: Stock, cost: Stock): boolean
	if not Planque.canAfford(stock, cost) then
		return false
	end
	for itemId, amount in cost do
		stock[itemId] -= amount
		if stock[itemId] <= 0 then
			stock[itemId] = nil
		end
	end
	return true
end

-- La faim apres `dt` secondes. Elle descend lentement : environ deux jours
-- sans manger avant d'etre vide (Config.needs).
function Planque.hungerAfter(needs: Needs, hunger: number, dt: number): number
	return math.max(hunger - needs.hungerPerMinute * dt / 60, 0)
end

-- Ce que la faim fait au joueur : sa vitesse, et ce qu'il perd en sante.
function Planque.hungerEffects(needs: Needs, hunger: number, dt: number): (number, number)
	local speed = if hunger < needs.hungryBelow then needs.hungrySpeedFactor else 1
	local damage = if hunger <= 0 then needs.starvingDamagePerSecond * dt else 0
	return speed, damage
end

-- Le repas du soir : pour chaque convive, un plat de `menu` (la premiere
-- combinaison que la reserve permet). Rend le nombre de convives nourris ;
-- les suivants n'ont rien eu.
function Planque.serveMeal(stock: Stock, menu: { Stock }, guests: number): number
	local fed = 0
	for _ = 1, guests do
		local served = false
		for _, dish in menu do
			if Planque.pay(stock, dish) then
				served = true
				break
			end
		end
		if not served then
			break
		end
		fed += 1
	end
	return fed
end

return Planque
