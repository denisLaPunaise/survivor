--!strict
--[[
	VisibilityService — ce que l'Oeil sait de la Planque (decide avec Josh le
	9 novembre 2026).

	Chaque nuit : le niveau (constructions, postes de l'etabli, fumee du
	rechaud, le survivant, le bruit des coups) fait monter la jauge ; elle
	fait descendre des Repris en plus. Au matin, si elle est pleine, l'Oeil a
	trouve la Planque : le premier Balayage la vise et arrache ce qui n'est
	pas sous un filet de camouflage. Puis elle redescend.

	La jauge se lit en attribut de Workspace (Config.visibility.attribute).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Survivor = ReplicatedStorage:WaitForChild("Survivor")
local Config = require(Survivor:WaitForChild("Config"))
local Visibility = require(Survivor:WaitForChild("Visibility"))

local EyeService = require(script.Parent:WaitForChild("EyeService"))
local FreeBuildService = require(script.Parent:WaitForChild("FreeBuildService"))
local LootService = require(script.Parent:WaitForChild("LootService"))
local PlanqueService = require(script.Parent:WaitForChild("PlanqueService"))
local SurvivorService = require(script.Parent:WaitForChild("SurvivorService"))

local VisibilityService = {}

local gauge = 0

local function publish()
	workspace:SetAttribute(Config.visibility.attribute, gauge)
end

-- Ce qui se voit et s'entend de la Planque, maintenant.
function VisibilityService.level(): number
	local v = Config.visibility
	local sources = {
		FreeBuildService.visibility(),
		PlanqueService.builtCount() * v.perBuild,
		if PlanqueService.has("rechaud") then v.stoveSmoke else 0,
		if SurvivorService.state() == "home" then v.survivor else 0,
		(FreeBuildService.takeHits() + PlanqueService.takeHits()) * v.perHit,
	}
	return Visibility.level(sources)
end

-- A la tombee de la nuit : la jauge monte. Rend les Repris en plus.
function VisibilityService.night(): number
	local v = Config.visibility
	gauge = Visibility.night(gauge, VisibilityService.level(), v)
	publish()
	return Visibility.extraRepris(gauge, v)
end

-- A l'aube : pleine, l'Oeil a trouve la Planque.
function VisibilityService.dawn()
	local v = Config.visibility
	if not Visibility.found(gauge, v) then
		return
	end
	gauge = v.afterFound
	publish()
	EyeService.targetPlanque()
	LootService.broadcast(
		"L'Œil a trouvé la Planque ! Le premier Balayage viendra la chercher.",
		"danger"
	)
end

function VisibilityService.reset()
	gauge = 0
	publish()
end

function VisibilityService.start()
	publish()
end

return VisibilityService
