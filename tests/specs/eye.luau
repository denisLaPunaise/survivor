--!strict
--[[
	Le regard de l'Oeil : trajets, duree deduite, jauge d'exposition.
	On teste ce que le jeu FAIT (ou regarde l'Oeil, quand on est aspire), pas
	qu'un chiffre de Config est coherent avec un autre.
]]

local Config = require("../../src/shared/Config")
local Exposure = require("../../src/shared/Exposure")
local Growth = require("../../src/shared/Growth")
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

	t.section("Les arrachages au hasard, en passant")

	local stops = Sweep.withStops(line, { { id = "toit-7", x = 190, z = 50 } }, 1.6)
	t.equal("un detour et un retour de plus", #stops, #line + 2)
	local detour = 0
	for i, p in stops do
		if p.spotId == "toit-7" then
			detour = i
		end
	end
	t.check("le detour n'est pas au debut : il arrache en passant", detour > 1)
	t.check(
		"il revient sur son trajet apres",
		stops[detour + 1].x == stops[detour - 1].x and stops[detour + 1].z == stops[detour - 1].z
	)
	local rips = Config.eye.randomRips
	-- Jusqu'au jour prevu pour finir le quartier, la ville s'abime sans se
	-- vider ; si l'on s'attarde, l'Oeil s'impatiente et elle devient
	-- invivable.
	local function roofsBy(lastDay: number): number
		local total = 0
		for d = 1, lastDay do
			total += Growth.onDay(rips.roofs, d) * Config.day.sweepsPerDay
		end
		return total
	end
	local pressure = Config.district.pressureDay
	t.check(
		string.format(
			"au jour %d, %.0f toits arraches au hasard sur 91 : la ville tient",
			pressure - 1,
			roofsBy(pressure - 1)
		),
		roofsBy(pressure - 1) < 91 / 2
	)
	t.check(
		string.format("au jour %d, %.0f toits : environ la moitie", pressure, roofsBy(pressure)),
		math.abs(roofsBy(pressure) - 91 / 2) < 91 * 0.1
	)
	t.check(
		string.format(
			"au jour %d, %.0f toits : s'attarder rend la ville invivable",
			pressure + 3,
			roofsBy(pressure + 3)
		),
		roofsBy(pressure + 3) > 91 * 0.9
	)
	t.check(
		"en s'attardant, de moins en moins de cachettes chaque matin",
		Growth.onDay(Config.day.fragileShare, pressure + 3)
			< Growth.onDay(Config.day.fragileShare, pressure - 1)
	)
	t.check(
		"chaque Balayage arrache quand meme au moins une cachette au hasard",
		Growth.onDay(rips.spots, 1) >= 1
	)
	-- Ejecte au centre du regard, le premier jour : pendant le repit il le
	-- poursuit sans remplir la jauge ; en courant, on est hors du cercle a la
	-- fin du repit.
	local gap = (Config.movement.sprintSpeed - Growth.onDay(Config.eye.hunt.chaseSpeed, 1))
		* Config.eye.ripGraceSeconds
	t.check(
		string.format("ejecte le jour 1 : %.0f studs d'avance a la fin du repit", gap),
		gap > Config.eye.beamRadius
	)

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

	t.section("La traque")

	local nx, nz = Sweep.chaseStep(0, 0, 100, 0, 15, 1)
	t.check("en une seconde, le regard avance de sa vitesse vers la cible", nx == 15 and nz == 0)
	local ax, az = Sweep.chaseStep(0, 0, 3, 4, 15, 1)
	t.check("il ne depasse jamais sa cible", ax == 3 and az == 4)

	local hunt = Config.eye.hunt
	local sprint = Config.movement.sprintSpeed
	t.check("le premier jour, on lui echappe en courant", Growth.onDay(hunt.chaseSpeed, 1) < sprint)
	-- Pris au centre du cercle le premier jour, on court droit devant : le
	-- temps de sortir du cercle qui nous suit ne doit pas suffire a la jauge.
	local escape = Config.eye.beamRadius / (sprint - Growth.onDay(hunt.chaseSpeed, 1))
	t.check(
		string.format(
			"jour 1, du centre du cercle, en courant : dehors en %.1f s, pas aspire",
			escape
		),
		not Exposure.isTaken(Exposure.step(0, 1, escape, Config.eye.exposure))
	)
	t.check(
		"jour 1, il ne rattrape pas quelqu'un qui marche",
		Growth.onDay(hunt.chaseSpeed, 1) < Config.movement.walkSpeed
	)
	t.check(
		"au bout de dix jours, il court plus vite que nous",
		Growth.onDay(hunt.chaseSpeed, 10) > sprint
	)
	t.check(
		"il vise de plus en plus juste",
		Growth.onDay(hunt.aimError, 8) < Growth.onDay(hunt.aimError, 1)
	)
	t.equal(
		"jamais plus juste que le plancher",
		Growth.onDay(hunt.aimError, 99),
		hunt.aimError.limit
	)
	local late = { start = 1, perDay = 1, limit = 9, fromDay = 5 }
	t.check(
		"une courbe ne bouge pas avant son jour, puis monte",
		Growth.onDay(late, 4) == 1 and Growth.onDay(late, 5) == 1 and Growth.onDay(late, 7) == 3
	)
	t.check(
		"il garde la piste de plus en plus longtemps",
		Growth.onDay(hunt.memorySeconds, 6) > Growth.onDay(hunt.memorySeconds, 1)
	)

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
