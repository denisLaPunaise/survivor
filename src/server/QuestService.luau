--!strict
--[[
	QuestService — la quete principale, « La voix dans la radio ».

	L'avancement est la logique pure de Quest (Story pour le texte, les jours
	dans Config.story). Ce service :
	- l'ouvre a l'aube et fait parler Mara la nuit (appele par DayService) ;
	- ecoute le jeu : la radio reparee (PlanqueService), l'antenne posee en
	  haut du chateau d'eau pendant qu'un autre regle la radio a la Planque ;
	- envoie aux clients l'objectif du moment et les lignes de la radio
	  (remote Radio), a tous en meme temps.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Survivor = ReplicatedStorage:WaitForChild("Survivor")
local Config = require(Survivor:WaitForChild("Config"))
local Quest = require(Survivor:WaitForChild("Quest"))
local Story = require(Survivor:WaitForChild("Story"))

local LootService = require(script.Parent:WaitForChild("LootService"))
local PlanqueService = require(script.Parent:WaitForChild("PlanqueService"))
local RemoteGuard = require(script.Parent:WaitForChild("RemoteGuard"))
local WorldService = require(script.Parent:WaitForChild("WorldService"))

local QuestService = {}

local radio = Survivor:WaitForChild("Remotes"):WaitForChild("Radio") :: RemoteEvent
local state = Quest.new()
-- Les deux gestes du signal, et quand : poser l'antenne, regler la radio.
local relayAt: number? = nil
local relayBy: Player? = nil
local tunedAt: number? = nil
-- Le dernier message de Mara : on peut le reecouter a la radio, si on etait
-- distrait (Josh). Garde meme apres une defaite : c'est le debut du journal.
local lastReport: { string } = {}
-- L'invite de la radio de la Planque : regler pendant le signal, reecouter
-- sinon. Une seule invite, donc aucun bouton de plus.
local radioPrompt: ProximityPrompt? = nil

local function promptFor(parent: Instance, action: string, hold: number, distance: number)
	local onFoot = Config.controls.contexts.onFoot
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.HoldDuration = hold
	prompt.MaxActivationDistance = distance
	prompt.RequiresLineOfSight = false
	prompt.GamepadKeyCode = (Enum.KeyCode :: any)[onFoot.interact.gamepad]
	prompt.KeyboardKeyCode = (Enum.KeyCode :: any)[onFoot.interact.keyboard]
	prompt.Parent = parent
	return prompt
end

-- Ce que l'on doit faire, en une ligne.
local function objective(): string?
	local step = Quest.current(Story, state)
	if step then
		return step.objective
	end
	if state.status == "solved" then
		return "Attendre la nuit : Mara rappellera."
	end
	if state.status == "finished" then
		return "Mara cherche le survivant. (La suite de l'histoire n'est pas encore construite.)"
	end
	if state.index > 1 then
		return "Survivre : Mara rappellera quand elle aura du nouveau."
	end
	return nil
end

local function signalOpen(): boolean
	local step = Quest.current(Story, state)
	return step ~= nil and step.event == "relay"
end

local function send(player: Player?)
	if radioPrompt then
		radioPrompt.ActionText = if signalOpen() then "Régler la radio" else "Réécouter la radio"
	end
	local data = { objective = objective() or "" }
	if player then
		radio:FireClient(player, data)
	else
		radio:FireAllClients(data)
	end
end

-- Un evenement du jeu : s'il reussit l'etape ouverte, tout le monde le sait.
function QuestService.notify(event: string)
	if Quest.complete(Story, state, event) then
		LootService.broadcast("Objectif atteint. Mara rappellera cette nuit.")
		send(nil)
	end
end

-- Les deux gestes dans la meme fenetre (ou seul dans Studio) : le signal passe.
local function trySignal()
	local s = Config.story
	local solo = s.soloInStudio and RunService:IsStudio() and #Players:GetPlayers() == 1
	if relayAt == nil or relayBy == nil then
		return
	end
	local together = tunedAt ~= nil and math.abs(relayAt - tunedAt) <= s.tuneWindowSeconds
	if not (solo or together) then
		return
	end
	if not LootService.takeItem(relayBy, "antenne") then
		return
	end
	relayAt, relayBy, tunedAt = nil, nil, nil
	QuestService.notify("relay")
end

local function onRelay(player: Player)
	if not signalOpen() then
		LootService.sendHud(player, "D'ici, on voit toute la ville. Rien à faire pour l'instant.")
		return
	end
	if not LootService.hasItem(player, "antenne") then
		LootService.sendHud(player, "Il faut l'antenne de l'église.")
		return
	end
	relayAt, relayBy = os.clock(), player
	trySignal()
	if signalOpen() then
		LootService.broadcast(
			"L'antenne est en place. Vite : quelqu'un doit régler la radio à la Planque !"
		)
	end
end

local function onTune(player: Player)
	if not signalOpen() then
		-- Hors du signal, la radio rejoue le dernier message, a lui seul.
		if #lastReport == 0 then
			LootService.sendHud(player, "Rien que du grésillement.")
		else
			radio:FireClient(player, { lines = lastReport, lineSeconds = Config.story.lineSeconds })
		end
		return
	end
	tunedAt = os.clock()
	trySignal()
	if signalOpen() then
		LootService.broadcast(
			"La radio est réglée. Il faut poser l'antenne en haut du château d'eau, maintenant."
		)
	end
end

-- Poser l'antenne et regler la radio par le meme chemin que les invites :
-- les sondes de test ne peuvent pas declencher une invite (comme
-- HidingService.tryEnter).
function QuestService.tryRelay(player: Player)
	onRelay(player)
end

function QuestService.tryTune(player: Player)
	onTune(player)
end

-- Appele par DayService a chaque aube.
function QuestService.dawn(dayNumber: number)
	if Quest.dawn(Story, Config.story.opensOnDay, state, dayNumber) then
		LootService.broadcast("Nouvel objectif.")
	end
	send(nil)
end

-- Appele par DayService a la tombee de la nuit : Mara parle, si elle a de quoi.
function QuestService.night()
	local lines = Quest.night(Story, state)
	if #lines > 0 then
		lastReport = lines
		radio:FireAllClients({ lines = lines, lineSeconds = Config.story.lineSeconds })
	end
	send(nil)
end

-- Une defaite : l'histoire recommence avec la partie (decide avec Josh).
function QuestService.reset()
	state = Quest.new()
	relayAt, relayBy, tunedAt = nil, nil, nil
	send(nil)
end

function QuestService.start()
	local s = Config.story
	local relay = promptFor(
		WorldService.get().relay,
		"Poser l'antenne",
		s.relayHoldSeconds,
		s.relayPromptDistance
	)
	relay.ObjectText = "Château d'eau"
	relay.Triggered:Connect(onRelay)

	-- La radio reparee : la quete avance, et on peut la regler.
	PlanqueService.whenBuilt(function(id: string, model: Instance)
		QuestService.notify("built:" .. id)
		if id == "radio" then
			local part = model:FindFirstChild("Radio", true)
			if part and part:IsA("BasePart") then
				local tune = promptFor(
					part,
					"Régler la radio",
					s.tuneHoldSeconds,
					Config.planque.useDistance
				)
				tune.ObjectText = "Radio"
				tune.Triggered:Connect(onTune)
				radioPrompt = tune
				send(nil)
			end
		end
	end)

	-- Le client demande l'objectif quand il est pret : a son arrivee, le
	-- serveur parlerait avant qu'il n'ecoute.
	radio.OnServerEvent:Connect(RemoteGuard.wrap("Radio", function(player: Player)
		send(player)
	end))
end

return QuestService
