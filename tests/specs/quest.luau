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
end
