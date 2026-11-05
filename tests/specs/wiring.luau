--!strict
--[[
	Une regle que seuls les tests appellent est une regle qui ne s'applique pas.

	C'est la panne la plus couteuse d'Arena, vue quatre fois : une table de
	Config ou une fonction pure testee, mais lue par aucun service.

	Ce test relit chaque module de `src/shared/` et exige que chaque fonction
	qu'il exporte soit nommee AILLEURS que sur sa ligne de definition, quelque
	part dans `src/`. Celles qui ne le sont pas doivent etre dans la liste
	ci-dessous AVEC LEUR RAISON : une fonction qu'on garde expres se declare,
	elle ne se tolere pas en silence.
]]

local fs = require("@lune/fs")

local Config = require("../../src/shared/Config")
local Throttle = require("../../src/shared/Throttle")

local harness = require("../harness")

-- Nom complet -> raison. Une raison qui dit « pas encore » doit disparaitre le
-- jour ou la fonctionnalite arrive.
local NOT_WIRED_ON_PURPOSE: { [string]: string } = {}

local function sources(): { [string]: string }
	local out: { [string]: string } = {}
	for _, folder in { "src/shared", "src/server", "src/client" } do
		for _, fileName in fs.readDir(folder) do
			if string.match(fileName, "%.luau$") ~= nil then
				local path = folder .. "/" .. fileName
				out[path] = fs.readFile(path)
			end
		end
	end
	return out
end

local function countPlain(haystack: string, needle: string): number
	local count = 0
	local start = 1
	while true do
		local i, j = string.find(haystack, needle, start, true)
		if i == nil or j == nil then
			return count
		end
		-- Un nom plus long qui commence pareil (`allow` dans `allowAll`) n'est
		-- pas un appel.
		local after = string.sub(haystack, j + 1, j + 1)
		if string.match(after, "[%w_]") == nil then
			count += 1
		end
		start = j + 1
	end
end

return function(t: harness.Harness)
	t.section("Toute fonction pure exportee est appelee par le jeu")

	local all = sources()
	local checked = 0
	local stale: { string } = {}

	for path, source in all do
		local moduleName = string.match(path, "^src/shared/([%w_]+)%.luau$")
		if moduleName == nil then
			continue
		end
		for fnName in string.gmatch(source, "\nfunction " .. moduleName .. "%.([%w_]+)%(") do
			local full = moduleName .. "." .. fnName
			checked += 1
			local uses = 0
			for _, other in all do
				uses += countPlain(other, full)
			end
			-- Une occurrence est la definition elle-meme.
			local wired = uses > 1
			local excused = NOT_WIRED_ON_PURPOSE[full]
			if wired and excused ~= nil then
				table.insert(stale, full)
			elseif not wired then
				t.equal(full .. " est appelee par le jeu, ou excusee", excused ~= nil, true)
			end
		end
	end

	-- Un balayage qui ne trouve rien passerait toujours : il doit au moins
	-- trouver le seau de jetons.
	t.check("le balayage a bien trouve des fonctions", checked >= 1)

	-- Une excuse qui n'excuse plus rien ment a son tour.
	table.sort(stale)
	t.equal("aucune excuse perimee (" .. table.concat(stale, ", ") .. ")", #stale, 0)

	t.section("Le garde-fou contre l'inondation")

	local settings = Config.network.remoteThrottle
	local buckets = {}
	local passed = 0
	for _ = 1, settings.burst do
		if Throttle.allow(buckets, "p", 0, settings) then
			passed += 1
		end
	end
	t.equal("une rafale de la taille du seau passe entiere", passed, settings.burst)
	t.equal(
		"le message suivant, au meme instant, est refuse",
		Throttle.allow(buckets, "p", 0, settings),
		false
	)
	t.equal("un autre joueur n'en paie rien", Throttle.allow(buckets, "q", 0, settings), true)
	t.equal("une seconde plus tard, ca repasse", Throttle.allow(buckets, "p", 1, settings), true)

	-- Un humain : un appui tous les 250 ms pendant une minute.
	local human = {}
	local refused = 0
	for i = 0, 240 do
		if not Throttle.allow(human, "h", i * 0.25, settings) then
			refused += 1
		end
	end
	t.equal("un humain qui appuie toutes les 250 ms n'est jamais coupe", refused, 0)

	-- Un script : cent messages par seconde pendant dix secondes.
	local bot = {}
	local accepted = 0
	for i = 0, 999 do
		if Throttle.allow(bot, "b", i * 0.01, settings) then
			accepted += 1
		end
	end
	t.check(
		string.format("un script a 100 messages/s est coupe (%d acceptes sur 1000)", accepted),
		accepted < 100
	)
end
