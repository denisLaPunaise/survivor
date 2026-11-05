--!strict
--[[
	RemoteGuard — le garde-fou contre l'inondation, a UN SEUL endroit.

	Chaque service enveloppe le gestionnaire de son remote :
	`RemoteGuard.wrap("Search", f)`. Un message en trop est jete sans reponse :
	un client honnete n'en envoie jamais autant, et repondre a une inondation
	serait la nourrir.

	Lecon d'Arena : quatre remotes sur huit n'avaient aucune limite, parce que
	chaque service la recodait a sa facon ou l'oubliait. Ici, aucun remote ne se
	branche sans passer par ce module.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Survivor = ReplicatedStorage:WaitForChild("Survivor")
local Config = require(Survivor:WaitForChild("Config"))
local Throttle = require(Survivor:WaitForChild("Throttle"))

local RemoteGuard = {}

local bucketsByRemote: { [string]: { [Player]: Throttle.Bucket } } = {}
local warned: { [Player]: boolean } = {}

function RemoteGuard.wrap(
	remoteName: string,
	handler: (Player, ...any) -> ()
): (Player, ...any) -> ()
	local buckets: { [Player]: Throttle.Bucket } = {}
	bucketsByRemote[remoteName] = buckets
	local settings = Config.network.remoteThrottle

	return function(player: Player, ...: any)
		if not Throttle.allow(buckets, player, os.clock(), settings) then
			-- Une seule ligne par joueur et par session : une inondation qui
			-- remplit aussi la console cacherait tout le reste.
			if not warned[player] then
				warned[player] = true
				warn(
					string.format(
						"[Survivor] %s envoie trop de messages sur %s : ignorés",
						player.Name,
						remoteName
					)
				)
			end
			return
		end
		handler(player, ...)
	end
end

Players.PlayerRemoving:Connect(function(player: Player)
	for _, buckets in bucketsByRemote do
		buckets[player] = nil
	end
	warned[player] = nil
end)

return RemoteGuard
