--!strict
--[[
	Bootstrap — point d'entree serveur, et le seul.

	Aucune logique ici : il annonce l'etat des reglages, puis demarre les
	services dans l'ordre. Toute nouvelle mecanique se branche sur cette liste,
	et nulle part ailleurs.

	La banniere n'annonce QUE ce qu'un service execute. Une ligne de banniere
	qui decrit une regle que personne n'applique est exactement la panne
	qu'Arena a vue quatre fois.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Survivor = ReplicatedStorage:WaitForChild("Survivor")
local Config = require(Survivor:WaitForChild("Config"))

-- Charge ici pour que tout service qui ouvre un remote le trouve pret.
require(script.Parent:WaitForChild("RemoteGuard"))

print("================================================")
print(string.format("[Survivor] Serveur démarré — réglages version %d", Config.version))
print("[Survivor] Squelette du projet : aucune mécanique branchée pour l'instant.")
print("[Survivor] Si tu lis ces lignes, Rojo est branché.")
print("================================================")
