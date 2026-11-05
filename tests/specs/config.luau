--!strict
--[[
	Config se charge seule, sans Roblox, et ses chiffres de base tiennent debout.
]]

local Config = require("../../src/shared/Config")

local harness = require("../harness")

return function(t: harness.Harness)
	t.section("Config se charge et porte une version")

	t.check("la version est un entier positif", Config.version >= 1 and Config.version % 1 == 0)

	t.section("Le garde-fou reseau")

	local throttle = Config.network.remoteThrottle
	t.check("une rafale laisse passer au moins un double clic", throttle.burst >= 2)
	t.check("le seau se remplit", throttle.perSecond > 0)
end
