--!strict
--[[
	Le regard de l'Oeil : trajets, duree deduite, jauge d'exposition.
	On teste ce que le jeu FAIT (ou regarde l'Oeil, quand on est aspire), pas
	qu'un chiffre de Config est coherent avec un autre.
]]

local Config = require("../../src/shared/Config")
local Exposure = require("../../src/shared/Exposure")
local Sweep = require("../../src/shared/Sweep")

local harness = require("../harness")

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-6
end

return function(t: harness.Harness)
	local bounds = { minX = 0, maxX = 200, minZ = 0, maxZ = 110 }

	t.section("Le rateau")

	local line = Sweep.linePath(bounds, 55, true, false)
	t.equal("trois passages pour 110 studs espaces de 55 (6 points)", #line, 6)
	t.check("le premier passage part de minX", line[1].x == 0 and line[1].z == 0)
	t.check("le deuxieme revient en sens inverse", line[3].x == 200 and line[4].x == 0)
	local reversed = Sweep.linePath(bounds, 55, true, true)
	t.equal("a l'envers, il commence par le bord oppose", reversed[1].z, 110)

	t.section("La spirale")

	local spiral = Sweep.spiralPath(bounds, 55)
	t.check("la spirale a au moins un tour", #spiral >= 4)
	local inside = true
	for _, p in spiral do
		if p.x < 0 or p.x > 200 or p.z < 0 or p.z > 110 then
			inside = false
		end
	end
	t.check("elle reste dans les limites", inside)

	t.section("Le temps se deduit de la longueur")

	local points = {
		{ x = 0, z = 0, pause = 0 },
		{ x = 90, z = 0, pause = 2 },
		{ x = 90, z = 45, pause = 0 },
	}
	local tl = Sweep.timeline(points, 45)
	t.check("90 studs a 45/s + 2 s de pause + 45 studs = 5 s", near(tl.total, 5))
	local x, z, reached = Sweep.sample(tl, 1)
	t.check("a 1 s, a mi-chemin du premier segment", near(x, 45) and near(z, 0) and reached == 1)
	x, z, reached = Sweep.sample(tl, 3)
	t.check(
		"a 3 s, il s'attarde sur le deuxieme point",
		near(x, 90) and near(z, 0) and reached == 2
	)
	x, z, reached = Sweep.sample(tl, 4.5)
	t.check("a 4,5 s, au milieu du dernier segment", near(x, 90) and near(z, 22.5) and reached == 2)
	x, z, reached = Sweep.sample(tl, 99)
	t.check("apres la fin, il reste au dernier point", near(x, 90) and near(z, 45) and reached == 3)

	t.section("Les cachettes marquees passent d'abord")

	local inspected = Sweep.withInspections(line, { { id = "abri-3", x = 50, z = 50 } }, 1.6)
	t.equal("le premier point est la cachette", inspected[1].spotId, "abri-3")
	t.equal("l'Oeil s'y attarde", inspected[1].pause, 1.6)
	t.equal("puis le rateau suit", #inspected, #line + 1)

	t.section("La zone d'un Balayage")

	local district = { minX = -400, maxX = 400, minZ = -320, maxZ = 320 }
	local zone = Sweep.zoneAround(0, 0, 280, district)
	t.check("centree sur le joueur", zone.minX == -140 and zone.maxX == 140 and zone.minZ == -140)
	local edge = Sweep.zoneAround(395, -318, 280, district)
	t.check(
		"au bord, ramenee dans le quartier",
		edge.maxX == 400 and edge.minX == 120 and edge.minZ == -320
	)
	local tiny = Sweep.zoneAround(0, 0, 280, { minX = 0, maxX = 100, minZ = 0, maxZ = 100 })
	t.check(
		"un quartier plus petit que la zone : tout le quartier",
		tiny.minX == 0 and tiny.maxX == 100
	)
	local near = Sweep.targetsIn({
		{ id = "dedans", x = 10, z = 10 },
		{ id = "marge", x = 180, z = 0 },
		{ id = "loin", x = 390, z = 300 },
	}, zone, 60)
	t.equal("il arrache celles de sa zone et de la marge, pas les autres", #near, 2)

	t.section("La jauge d'exposition")

	local settings = Config.eye.exposure
	local level = 0
	local seconds = 0
	while not Exposure.isTaken(level) and seconds < 10 do
		level = Exposure.step(level, 1, 0.1, settings)
		seconds += 0.1
	end
	t.check(
		string.format(
			"plein regard : aspire en %.1f s (reglage %.1f)",
			seconds,
			settings.fillSeconds
		),
		math.abs(seconds - settings.fillSeconds) < 0.11
	)

	-- Traverser le cercle en sprint, au centre : on sort avant d'etre aspire.
	local crossing = (Config.eye.beamRadius * 2) / Config.movement.sprintSpeed
	t.check(
		string.format(
			"traverser le cercle en sprint (%.2f s) ne suffit pas a etre aspire",
			crossing
		),
		not Exposure.isTaken(Exposure.step(0, 1, crossing, settings))
	)
	-- Mais rester a moitie couvert finit mal.
	t.check(
		"a moitie couvert, on tient deux fois plus longtemps",
		not Exposure.isTaken(Exposure.step(0, 0.5, settings.fillSeconds * 1.9, settings))
	)
	t.equal(
		"a l'abri, la jauge redescend",
		Exposure.step(0.5, 0, settings.drainSeconds, settings),
		0
	)
end
