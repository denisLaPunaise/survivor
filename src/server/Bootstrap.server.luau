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

local CombatService = require(script.Parent:WaitForChild("CombatService"))
local CrewService = require(script.Parent:WaitForChild("CrewService"))
local DayService = require(script.Parent:WaitForChild("DayService"))
local EyeService = require(script.Parent:WaitForChild("EyeService"))
local HidingService = require(script.Parent:WaitForChild("HidingService"))
local LootService = require(script.Parent:WaitForChild("LootService"))
local PlanqueService = require(script.Parent:WaitForChild("PlanqueService"))
local QuestService = require(script.Parent:WaitForChild("QuestService"))
local VentreService = require(script.Parent:WaitForChild("VentreService"))
local ReprisService = require(script.Parent:WaitForChild("ReprisService"))
local WorldService = require(script.Parent:WaitForChild("WorldService"))

print("================================================")
print(string.format("[Survivor] Serveur démarré — réglages version %d", Config.version))

local world = WorldService.load()
if world == nil then
	print("[Survivor] Rien ne démarre tant que la ville est incomplète (voir ci-dessus).")
	print("================================================")
	return
end

local d = Config.day
print(
	string.format(
		"[Survivor] Un jour : %d Balayages, %d à %d s de fouille entre deux, signes %d s avant",
		d.sweepsPerDay,
		d.gapSeconds.min,
		d.gapSeconds.max,
		Config.eye.warningSeconds
	)
)
print(
	string.format(
		"[Survivor] Aspiré après %.1f s de plein regard ; %d emplacements, %d %% occupés chaque matin",
		Config.eye.exposure.fillSeconds,
		#world.anchors:GetChildren(),
		math.floor(d.fragileShare.start * 100 + 0.5)
	)
)
print("================================================")

LootService.start()
HidingService.start()
print(
	string.format(
		"[Survivor] %d bâtiments où s'abriter, et dont l'Œil peut arracher le toit",
		HidingService.buildingCount()
	)
)
CombatService.start()
CrewService.start()
EyeService.start()
ReprisService.start()
PlanqueService.start()
QuestService.start()
VentreService.start()
-- Les Repris frappent la barricade de la Planque sans la connaitre.
ReprisService.setObstacleProvider(PlanqueService.obstacleNear)
DayService.start()
