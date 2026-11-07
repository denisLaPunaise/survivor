--!strict
--[[
	Les sons : chacun est vraiment joue quelque part (un son liste mais jamais
	appele, c'est une regle qui ne s'applique pas), et ses reglages tiennent.
]]

local fs = require("@lune/fs")

local Config = require("../../src/shared/Config")

local harness = require("../harness")

return function(t: harness.Harness)
	local code = ""
	for _, folder in { "src/server", "src/client" } do
		for _, fileName in fs.readDir(folder) do
			code ..= fs.readFile(folder .. "/" .. fileName)
		end
	end

	t.section("Chaque son sert")

	for name, entry in Config.sounds.library do
		local used = string.find(code, '"' .. name .. '"', 1, true) ~= nil
		t.check(name .. " est joue par le jeu", used)
		t.check(
			name .. " : un identifiant et un volume entre 0 et 1",
			entry.id > 0 and entry.volume > 0 and entry.volume <= 1
		)
	end

	t.section("Les distances")

	t.check(
		"un son du monde s'entend plus loin qu'il ne sonne plein",
		Config.sounds.rollOffMax > Config.sounds.rollOffMin
	)
	t.check(
		"on entend son regard approcher avant qu'il soit sur soi",
		Config.sounds.gazeHeardStuds > Config.eye.beamRadius * 4
	)
end
