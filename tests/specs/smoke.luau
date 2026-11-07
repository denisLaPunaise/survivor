--!strict
--[[
	Le fumigene (etape 4) : le nuage coupe la ligne de vue, le lancer tombe a
	une distance raisonnable, l'Oeil guette au bord du nuage, et ses
	ingredients ne se trouvent qu'au fond de la superette.
]]

local Config = require("../../src/shared/Config")
local Smoke = require("../../src/shared/Smoke")

local harness = require("../harness")

return function(t: harness.Harness)
	local s = Config.smoke

	t.section("Le nuage dans le temps")

	t.equal("rien avant d'eclater", Smoke.radiusAt(s, -1), 0)
	t.check("il s'ouvre (plus petit au debut)", Smoke.radiusAt(s, s.growSeconds / 2) < s.radius)
	t.equal("plein au milieu", Smoke.radiusAt(s, s.seconds / 2), s.radius)
	t.check(
		"il retrecit en se dissipant",
		Smoke.radiusAt(s, s.seconds - s.fadeSeconds / 2) < s.radius
	)
	t.equal("rien apres", Smoke.radiusAt(s, s.seconds), 0)
	t.check(
		"il tient plein plus longtemps qu'il ne s'ouvre et se dissipe",
		s.seconds > (s.growSeconds + s.fadeSeconds) * 2
	)

	t.section("Il coupe la ligne de vue")

	local cloud: Smoke.Cloud = { x = 0, y = 5, z = 0, radius = 10 }
	local eyeY = 400
	t.check(
		"l'Oeil ne voit pas quelqu'un dedans",
		Smoke.blocking({ cloud }, 30, eyeY, 30, 2, 5, 1) ~= nil
	)
	t.check("ni quelqu'un juste derriere", Smoke.blocking({ cloud }, 0, eyeY, 0, 0, -30, 0) ~= nil)
	t.check(
		"il voit quelqu'un a cote, a decouvert",
		Smoke.blocking({ cloud }, 0, eyeY, 0, 40, 5, 0) == nil
	)
	t.check(
		"un nuage dissipe ne cache plus rien",
		Smoke.blocking({ { x = 0, y = 5, z = 0, radius = 0 } }, 30, eyeY, 30, 2, 5, 1) == nil
	)

	t.section("Le lancer")

	-- Ou la cloche repasse a la hauteur du depart.
	local function reach(up: number): number
		local flat = math.sqrt(1 - up * up)
		local points = Smoke.flight(
			0,
			0,
			0,
			flat * s.throwSpeed,
			up * s.throwSpeed + s.throwLift,
			0,
			s.gravity,
			s.flightStep,
			s.maxFlightSeconds
		)
		for i = 2, #points do
			if points[i].y < 0 then
				return points[i].x
			end
		end
		return math.huge
	end
	local level = reach(0)
	local high = reach(math.sin(math.rad(30)))
	t.check(
		string.format("a plat, il tombe a portee de voix (%.0f studs)", level),
		level > 25 and level < 60
	)
	t.check(
		string.format("vise haut, il couvre un ami plus loin (%.0f studs)", high),
		high > level and high < 120
	)
	t.check(
		"il a le temps de tomber avant d'etre abandonne en l'air",
		s.maxFlightSeconds > 2 * (math.sin(math.rad(30)) * s.throwSpeed + s.throwLift) / s.gravity
	)

	t.section("L'Oeil guette autour")

	local ring = s.radius + Config.eye.beamRadius - s.watchMargin
	local wx, wz = Smoke.watchPoint(10, 20, ring, 0, 0.5, 3)
	local fromCenter = math.sqrt((wx - 10) ^ 2 + (wz - 20) ^ 2)
	t.check("il tourne a distance du centre", math.abs(fromCenter - ring) < 0.001)
	t.check(
		"le bord de son regard mord sur le bord du nuage (il voit qui en sort)",
		ring - Config.eye.beamRadius < s.radius and ring > s.radius
	)
	t.check(
		"il perd la piste au bout de 5 a 10 secondes (Josh)",
		s.lingerSeconds >= 5 and s.lingerSeconds <= 10
	)
	t.check("et le nuage dure plus longtemps que sa ronde", s.seconds > s.lingerSeconds)
	t.check("sa ronde ne va pas plus vite que son regard", s.watchPace > 0 and s.watchPace < 1)

	t.section("Ce qu'il faut pour le fabriquer")

	for itemId in s.recipe do
		t.check(itemId .. " existe", Config.items[itemId] ~= nil)
	end
	local sources: { string } = {}
	for tableId, lootTable in Config.loot.tables do
		for _, entry in lootTable.entries do
			if entry.item == "chimie" then
				table.insert(sources, tableId)
			end
		end
	end
	t.equal(
		"les produits chimiques ne se trouvent qu'au fond de la superette",
		table.concat(sources, ","),
		"arriere"
	)
	t.check("le fumigene reste dans le sac au coffre", Config.items.fumigene.keep == true)
	t.check("Elie en fait au moins un par nuit", s.perNight >= 1)
end
