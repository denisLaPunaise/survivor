--!strict
--[[
	La quete principale : on ne peut pas aller plus vite que ses jours, et
	chaque etape attend un evenement que le jeu envoie vraiment.
]]

local fs = require("@lune/fs")

local Config = require("../../src/shared/Config")
local Quest = require("../../src/shared/Quest")
local Story = require("../../src/shared/Story")

local harness = require("../harness")

return function(t: harness.Harness)
	local days = Config.story.opensOnDay

	t.section("Chaque etape a son jour")

	local previous = 0
	local ordered = true
	for _, step in Story do
		local day = days[step.id]
		if typeof(day) ~= "number" or day <= previous then
			ordered = false
		end
		previous = day or previous
	end
	t.check("chaque etape a un jour, et ils montent dans l'ordre", ordered)

	t.section("La partie la plus rapide possible")

	-- Des joueurs parfaits : chaque etape reussie le jour meme ou elle s'ouvre.
	local state = Quest.new()
	local openedOn: { [string]: number } = {}
	local finishedOn = 0
	for day = 1, 30 do
		if Quest.dawn(Story, days, state, day) then
			local step = Quest.current(Story, state) :: Quest.Step
			openedOn[step.id] = day
			Quest.complete(Story, state, step.event)
		end
		Quest.night(Story, state)
		if state.status == "finished" then
			finishedOn = day
			break
		end
	end
	local early = false
	for id, day in openedOn do
		if day < days[id] then
			early = true
		end
	end
	t.check("aucune etape ne s'ouvre avant son jour", not early)
	t.equal("l'histoire ne finit pas avant le jour de sa derniere etape", finishedOn, previous)

	t.section("Une etape a la fois")

	local s = Quest.new()
	t.check(
		"fermee avant l'aube : on ne peut rien reussir",
		not Quest.complete(Story, s, Story[1].event)
	)
	Quest.dawn(Story, days, s, 1)
	t.check("le mauvais evenement ne reussit rien", not Quest.complete(Story, s, "autre"))
	t.check("le bon evenement reussit l'etape", Quest.complete(Story, s, Story[1].event))
	t.equal("la nuit, Mara raconte", #Quest.night(Story, s), #Story[1].report)
	t.check(
		"l'etape suivante attend l'aube",
		Quest.current(Story, s) == nil and s.status == "locked"
	)
	t.check("et pas avant son jour", not Quest.dawn(Story, days, s, days[Story[2].id] - 1))
	t.equal("une nuit sans reussite : Mara se tait", #Quest.night(Story, s), 0)

	t.section("Le jeu envoie bien chaque evenement")

	local server = ""
	for _, fileName in fs.readDir("src/server") do
		server ..= fs.readFile("src/server/" .. fileName)
	end
	for _, step in Story do
		local build = string.match(step.event, "^built:(.+)$")
		local sent = if build
			then string.find(server, '"built:"', 1, true) ~= nil
			else string.find(server, '"' .. step.event .. '"', 1, true) ~= nil
		if build then
			local known = false
			for _, b in Config.planque.builds do
				if b.id == build then
					known = true
				end
			end
			sent = sent and known
		end
		t.check(step.id .. " : l'evenement « " .. step.event .. " » existe dans le jeu", sent)
	end

	t.section("Mara annonce le survivant la nuit d'avant")

	-- Le signal reussi a l'heure : le briefing vient la nuit d'avant
	-- l'ouverture du survivant, une seule fois.
	local b = Quest.new()
	local briefedOn: number? = nil
	local briefings = 0
	for day = 1, days.survivant do
		if Quest.dawn(Story, days, b, day) then
			local step = Quest.current(Story, b) :: Quest.Step
			if step.id ~= "survivant" then
				Quest.complete(Story, b, step.event)
			end
		end
		Quest.night(Story, b)
		if #Quest.briefing(Story, days, b, day) > 0 then
			briefedOn = day
			briefings += 1
		end
	end
	t.equal("le briefing tombe la nuit d'avant", briefedOn, days.survivant - 1)
	t.equal("et une seule fois", briefings, 1)

	-- Le signal reussi en retard (jour 6) : recit et briefing la meme nuit.
	local late = Quest.new()
	Quest.dawn(Story, days, late, 1)
	Quest.complete(Story, late, Story[1].event)
	Quest.night(Story, late)
	Quest.dawn(Story, days, late, 6)
	Quest.complete(Story, late, Story[2].event)
	Quest.night(Story, late)
	t.check(
		"en retard, le briefing suit le recit la meme nuit",
		#Quest.briefing(Story, days, late, 6) > 0
	)

	t.section("Les trous du texte sont tous remplis par le jeu")

	local known = { nom = true, indice = true }
	local unknown: { string } = {}
	for _, step in Story do
		for _, lines in { step.report, step.briefing or {}, step.again or {}, { step.objective } } do
			for _, line in lines do
				for key in string.gmatch(line, "{(%w+)}") do
					if not known[key] then
						table.insert(unknown, step.id .. ":" .. key)
					end
				end
			end
		end
	end
	t.equal("aucun trou inconnu", table.concat(unknown, ", "), "")
	local filled = Quest.fill({ "Il se cache {indice}, {nom}." }, { indice = "ici", nom = "Élie" })
	t.equal("un trou se remplit", filled[1], "Il se cache ici, Élie.")
	t.check(
		"le serveur donne bien l'indice",
		string.find(server, 'setValue("indice"', 1, true) ~= nil
	)

	t.section("Ce qu'une etape apporte reste")

	local r = Quest.new()
	t.check("le fumigene n'est pas atteint au debut", not Quest.reached(Story, r, "fumigene"))
	for day = 1, days.fumigene do
		if Quest.dawn(Story, days, r, day) then
			local step = Quest.current(Story, r) :: Quest.Step
			if step.id ~= "fumigene" then
				Quest.complete(Story, r, step.event)
			end
		end
		if day < days.fumigene then
			Quest.night(Story, r)
		end
	end
	t.check("ouvert, il est atteint (Elie fabrique)", Quest.reached(Story, r, "fumigene"))
	Quest.complete(Story, r, "thrown:fumigene")
	Quest.night(Story, r)
	t.check("reussi, il reste atteint", Quest.reached(Story, r, "fumigene"))
	t.check("une etape inconnue n'est jamais atteinte", not Quest.reached(Story, r, "rien"))
	t.check(
		"le serveur ne fait fabriquer Elie qu'une fois l'etape atteinte",
		string.find(server, "hasReached(SMOKE_STEP)", 1, true) ~= nil
	)

	t.section("Le survivant")

	local sv = Config.survivor
	t.check("il boite : plus lent que la marche", sv.limpSpeed < Config.movement.walkSpeed)
	t.check(
		"son invite ne prend pas celle des cachettes quand il suit",
		sv.promptDistance < sv.followDistance
	)
	t.check(
		"il cherche une cachette plus loin qu'on ne la voit",
		sv.hideRadius > Config.loot.hidePromptDistance
	)
	t.check("il se perd plus loin qu'il ne suit", sv.lostDistance > sv.followDistance * 3)
end
