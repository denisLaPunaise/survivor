--!strict
--[[
	La memoire du Veilleur et la ville qui change chaque matin.
]]

local Config = require("../../src/shared/Config")
local Crew = require("../../src/shared/Crew")
local Hiding = require("../../src/shared/Hiding")

local harness = require("../harness")

-- Un hasard rejouable : un generateur lineaire, pour que les tests ne
-- dependent pas de l'horloge.
local function seeded(seed: number): (number, number) -> number
	local state = seed
	return function(lo: number, hi: number): number
		-- Park-Miller : le produit reste sous 2^53, donc exact en double.
		state = (state * 16807) % 2147483647
		return lo + (state % (hi - lo + 1))
	end
end

return function(t: harness.Harness)
	t.section("Marquer une cachette")

	local marks = {}
	Hiding.mark(marks, "abri", 1, 3)
	t.equal(
		"au Balayage pendant lequel on s'y cache, l'Oeil ne vient pas",
		#Hiding.marked(marks, 1, 3, 2),
		0
	)
	t.equal("au Balayage suivant, il vient la verifier", Hiding.marked(marks, 1, 4, 2)[1], "abri")
	Hiding.mark(marks, "abri", 1, 4)
	t.equal("se recacher au meme endroit ne rajeunit pas la marque", marks["abri"].sweep, 3)
	t.equal("le lendemain, elle est encore la", #Hiding.marked(marks, 2, 9, 2), 1)
	t.equal("deux jours plus tard, elle s'est effacee", #Hiding.marked(marks, 3, 13, 2), 0)
	t.equal("et elle a quitte la table", marks["abri"], nil)

	t.section("Les cachettes fragiles bougent chaque matin")

	local anchors = { "e1", "e2", "e3", "e4", "e5", "e6", "e7", "e8", "e9", "e10" }
	local picked = Hiding.pickAnchors(anchors, 6, seeded(7), {})
	t.equal("on en prend le nombre demande", #picked, 6)
	local seen = {}
	local unique = true
	for _, id in picked do
		if seen[id] then
			unique = false
		end
		seen[id] = true
	end
	t.check("jamais deux fois le meme emplacement", unique)

	local again = Hiding.pickAnchors(anchors, 6, seeded(7), {})
	t.equal(
		"le meme hasard donne la meme ville",
		table.concat(again, ","),
		table.concat(picked, ",")
	)

	local avoid = { e1 = true, e2 = true, e3 = true }
	local withAvoid = Hiding.pickAnchors(anchors, 6, seeded(3), avoid)
	local reused = 0
	for _, id in withAvoid do
		if avoid[id] then
			reused += 1
		end
	end
	t.equal("une cachette arrachee hier ne revient pas au meme endroit", reused, 0)

	local tight = Hiding.pickAnchors(anchors, 9, seeded(3), avoid)
	t.equal("s'il n'en reste pas assez, on reprend les anciens", #tight, 9)

	t.section("La defaite")

	t.equal("un serveur vide n'a pas perdu", Crew.isWiped({}), false)
	t.equal("un joueur debout suffit", Crew.isWiped({ a = false, b = true }), false)
	t.equal(
		"plus personne debout : la partie est perdue",
		Crew.isWiped({ a = false, b = false }),
		true
	)

	t.section("Recrache, loin de la Planque")

	local points = { { x = 10, z = 0 }, { x = 400, z = 0 }, { x = 0, z = -500 } }
	local planque = { x = 0, z = 0 }
	local min = Config.eye.releaseMinPlanqueDistance
	local always = true
	for seed = 1, 20 do
		local i = Crew.pickLanding(points, planque, min, seeded(seed))
		if i == nil or i == 1 then
			always = false
		end
	end
	t.check("jamais a cote de la Planque : les amis doivent sortir", always)
	t.equal(
		"aucun point assez loin : on le dit",
		Crew.pickLanding({ { x = 1, z = 1 } }, planque, min, seeded(1)),
		nil
	)
end
