--!strict
--[[
	Le Gardien (etape 5) : on peut l'attirer en courant, il rattrape qui
	marche, l'Oeil doit le TENIR (pas seulement le croiser), et ce qui ouvre
	sa grille se fabrique.
]]

local Config = require("../../src/shared/Config")

local harness = require("../harness")

return function(t: harness.Harness)
	local g = Config.gardien
	local m = Config.movement

	t.section("L'attirer dehors")

	t.check("il rattrape qui marche", g.speed > m.walkSpeed)
	t.check("on le distance en courant", g.speed < m.sprintSpeed)
	t.check("il rentre plus lentement qu'il ne poursuit", g.homeSpeed < g.speed)
	t.check(
		"deux coups mettent a terre, pas un",
		g.damage < Config.combat.playerHealth and g.damage * 2 >= Config.combat.playerHealth
	)
	t.check(
		"il cherche celui qu'il a perdu plus longtemps qu'un Repris",
		g.forgetSeconds > Config.repris.forgetSeconds
	)

	t.section("Le livrer a l'Oeil")

	t.check(
		"l'Oeil doit le tenir plus longtemps qu'un joueur",
		g.exposure.fillSeconds > Config.eye.exposure.fillSeconds * 2
	)
	-- Le traverser en courant devant lui : il est dans le cercle du regard
	-- (32 studs de large) ~2 s ; ca ne doit pas suffire.
	t.check(
		"le faire passer dans le regard ne suffit pas",
		g.exposure.fillSeconds > Config.eye.beamRadius * 2 / g.speed
	)
	t.check(
		"sa jauge redescend lentement : on peut s'y reprendre",
		g.exposure.drainSeconds >= g.exposure.fillSeconds
	)

	t.section("La grille")

	local tool: any = nil
	for _, b in Config.planque.builds do
		if b.id == "coupeboulon" then
			tool = b
		end
	end
	t.check("le coupe-boulon se fabrique a l'etabli", tool ~= nil and tool.item == "coupeboulon")
	t.check(
		"il reste dans le sac au coffre",
		Config.items.coupeboulon ~= nil and Config.items.coupeboulon.keep == true
	)
	t.check(
		"couper la chaine prend du temps (et du bruit)",
		g.chainHoldSeconds > Config.loot.searchSeconds * 2
	)
end
