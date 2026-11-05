--!strict
--[[
	Les Repris : ce qui les reveille, qui ils poursuivent, combien descendent.
]]

local Config = require("../../src/shared/Config")
local Growth = require("../../src/shared/Growth")
local Repris = require("../../src/shared/Repris")

local harness = require("../harness")

return function(t: harness.Harness)
	local r = Config.repris

	t.section("Ce qui les reveille")

	t.check("marcher a cote, a 10 studs : il dort", not Repris.wakes(r.wake, 10, "none"))
	t.check("le frôler : il se reveille", Repris.wakes(r.wake, r.wake.touchRadius - 0.5, "none"))
	t.check(
		"courir dans la piece d'a cote : il entend",
		Repris.wakes(r.wake, r.wake.sprintRadius - 1, "sprint")
	)
	t.check("courir loin : il dort", not Repris.wakes(r.wake, r.wake.sprintRadius + 5, "sprint"))
	t.check(
		"fouiller dans la meme maison : il entend",
		Repris.wakes(r.wake, r.wake.searchRadius - 1, "search")
	)
	-- Le choix de fond : marcher accroupi a cote d'un Repris doit etre
	-- possible, sinon dedans ne vaut pas mieux que dehors.
	t.check("on peut passer pres de lui en marchant", r.wake.touchRadius < 8)

	t.section("Qui ils poursuivent")

	local target = Repris.pickTarget({
		{ id = "loin", distance = 30, visible = true },
		{ id = "cache", distance = 5, visible = false },
		{ id = "proche", distance = 12, visible = true },
	}, 70)
	t.equal("le plus proche qu'il VOIT, pas celui derriere le mur", target, "proche")
	t.equal(
		"personne a portee : personne",
		Repris.pickTarget({ { id = "x", distance = 90, visible = true } }, 70),
		nil
	)

	t.section("Fuir un Repris")

	local walk = Config.movement.walkSpeed
	local sprint = Config.movement.sprintSpeed
	t.check("un Errant ne rattrape pas quelqu'un qui marche", r.kinds.errant.speed < walk)
	t.check("un Coureur rattrape quelqu'un qui court", r.kinds.coureur.speed > sprint)

	t.section("Le jour, ils sont de plus en plus nombreux")

	local d = r.day
	t.equal(
		"le premier jour, un quart des maisons",
		Growth.onDay(d.houseShare, 1),
		d.houseShare.start
	)
	t.check(
		"le cinquieme jour, plus",
		Growth.onDay(d.houseShare, 5) > Growth.onDay(d.houseShare, 1)
	)
	t.equal("jamais plus que le plafond", Growth.onDay(d.houseShare, 999), d.houseShare.limit)
	t.check("jamais plus de la moitie des maisons", d.houseShare.limit <= 0.5)
	t.check(
		"les cachettes restent utilisables : 1 sur 5 occupee au pire",
		d.lurkerShare.limit <= 0.2
	)
	t.check(
		"dehors, plus nombreux au jour 10 qu'au jour 1",
		Growth.onDay(d.outdoor, 10) > Growth.onDay(d.outdoor, 1)
	)

	t.section("La taille des nuits")

	t.equal("premiere nuit, seul", Repris.waveSize(r.night, 1, 1), r.night.base)
	t.check(
		"la nuit suivante est pire",
		Repris.waveSize(r.night, 2, 3) > Repris.waveSize(r.night, 1, 3)
	)
	t.check(
		"a cinq, plus qu'a trois",
		Repris.waveSize(r.night, 3, 5) > Repris.waveSize(r.night, 3, 3)
	)
	t.equal("jamais au-dela du maximum", Repris.waveSize(r.night, 99, 5), r.night.max)
	t.equal(
		"pas de Coureur la premiere nuit",
		Repris.runnerShare(r.night, 1),
		r.night.runnerShareStart
	)
	t.equal(
		"jamais plus que la moitie de Coureurs",
		Repris.runnerShare(r.night, 99),
		r.night.runnerShareMax
	)

	t.section("Les coups")

	local after, down = Repris.hit(100, 14)
	t.check("un coup d'Errant ne fait pas tomber", after == 86 and not down)
	local _, fallen = Repris.hit(10, 14)
	t.check("le coup de trop fait tomber, pas mourir", fallen)
	local hits = math.ceil(Config.combat.playerHealth / r.kinds.errant.damage)
	t.check(
		string.format("il faut %d coups d'Errant pour tomber : on a le temps de reagir", hits),
		hits >= 5
	)
	local swings = math.ceil(r.kinds.errant.health / Config.combat.meleeDamage)
	t.check(
		string.format("un Errant tombe en %d coups de pied-de-biche", swings),
		swings >= 2 and swings <= 4
	)
end
