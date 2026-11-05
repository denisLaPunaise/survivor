--!strict
--[[
	DayService — le deroulement des jours, et la defaite.

	Un jour : l'aube (les cachettes fragiles changent de place, les aspires
	reviennent, une partie des contenants se remplit), puis
	`Config.day.sweepsPerDay` Balayages separes par un temps de fouille, puis le
	crepuscule, puis la nuit — pas encore construite : elle passe, et tout le
	monde se retrouve a la Planque.

	LA DEFAITE (decidee) : plus personne debout, la partie recommence depuis le
	debut. Une « generation » numerote chaque partie ; une boucle d'une
	ancienne generation s'arrete d'elle-meme au premier test.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Survivor = ReplicatedStorage:WaitForChild("Survivor")
local Config = require(Survivor:WaitForChild("Config"))

local CrewService = require(script.Parent:WaitForChild("CrewService"))
local EyeService = require(script.Parent:WaitForChild("EyeService"))
local HidingService = require(script.Parent:WaitForChild("HidingService"))
local LootService = require(script.Parent:WaitForChild("LootService"))
local PlanqueService = require(script.Parent:WaitForChild("PlanqueService"))
local ReprisService = require(script.Parent:WaitForChild("ReprisService"))

local DayService = {}

local random = Random.new()
local eyeState = Survivor:WaitForChild("Remotes"):WaitForChild("EyeState") :: RemoteEvent
local generation = 0

local function announce(message: string)
	for _, player in Players:GetPlayers() do
		LootService.sendHud(player, message)
	end
end

local function runGame(myGeneration: number)
	local function current(): boolean
		return generation == myGeneration
	end
	local d = Config.day
	local dayNumber = 0

	while current() do
		dayNumber += 1
		eyeState:FireAllClients({ phase = "dawn" })
		PlanqueService.dawn()
		CrewService.dawn()
		HidingService.newDay(dayNumber)
		LootService.newDay()
		ReprisService.newDay(dayNumber)
		CrewService.returnTaken()
		-- S'attarder dans le quartier : on le dit, chaque matin.
		announce(
			if dayNumber >= Config.district.pressureDay
				then string.format(
					"Jour %d. L'Œil s'impatiente : la ville ne tiendra plus longtemps.",
					dayNumber
				)
				else string.format("Jour %d", dayNumber)
		)

		task.wait(d.firstSweepSeconds)
		for i = 1, d.sweepsPerDay do
			if not current() then
				return
			end
			-- Le periscope voit le ciel rougir avant les autres.
			local periscope = PlanqueService.build("periscope")
			if periscope and PlanqueService.has("periscope") then
				announce("Le périscope : le ciel va rougir.")
				task.wait(periscope.earlySeconds :: number)
				if not current() then
					return
				end
			end
			EyeService.runSweep(current, dayNumber)
			if i < d.sweepsPerDay and current() then
				task.wait(random:NextNumber(d.gapSeconds.min, d.gapSeconds.max))
			end
		end
		if not current() then
			return
		end

		announce("Le jour tombe — rentrez à la Planque")
		task.wait(d.duskSeconds)
		if not current() then
			return
		end
		-- La nuit : l'Oeil se ferme, les Repris tombent de la Fissure.
		announce("La nuit tombe. Ils descendent.")
		eyeState:FireAllClients({ phase = "night", seconds = d.nightSeconds })
		CrewService.setLamps(true)
		ReprisService.beginNight(dayNumber)
		task.wait(d.nightSeconds)
		CrewService.setLamps(false)
	end
end

function DayService.restart()
	generation += 1
	local mine = generation
	task.spawn(runGame, mine)
end

function DayService.start()
	CrewService.onWipe(function()
		-- Arreter la partie en cours tout de suite : plus de regard.
		generation += 1
		EyeService.reset()
		announce("Plus personne debout. La partie recommence depuis le début.")
		task.wait(Config.day.wipeMessageSeconds)
		HidingService.reset()
		LootService.reset()
		ReprisService.clear()
		PlanqueService.reset()
		CrewService.setLamps(false)
		CrewService.gatherAtPlanque()
		DayService.restart()
	end)
	DayService.restart()
end

return DayService
