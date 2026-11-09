--!strict
--[[
	QuestService — la quete principale, « La voix dans la radio ».

	L'avancement est la logique pure de Quest (Story pour le texte, les jours
	dans Config.story). Ce service :
	- l'ouvre a l'aube et fait parler Mara la nuit (appele par DayService) :
	  le recit de l'etape reussie, le briefing de la suivante, et ce qu'elle
	  doit redire (le survivant aspire, retrouve ailleurs) ;
	- remplit les trous du texte (`{indice}` : ou se cache le survivant) avec
	  ce que les services lui donnent (`setValue`) ;
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
-- Le journal : tout ce que Mara a dit, nuit par nuit, a relire dans le
-- panneau du sac (Y). Garde meme apres une defaite (CONCEPT 12).
type Entry = { title: string, lines: { string } }
local journal: { Entry } = {}
-- Les trous du texte (Quest.fill), et ce que Mara doit redire cette nuit.
local values: { [string]: string } = { nom = Config.survivor.name }
local againTonight: { string }? = nil

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
		return Quest.fill({ step.objective }, values)[1]
	end
	if state.status == "solved" then
		return "Attendre la nuit : Mara rappellera."
	end
	if state.status == "finished" then
		return "Chapitre 1 terminé. Survivre : la suite viendra avec le quartier suivant."
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
	local data = { objective = objective() or "", journal = journal }
	if player then
		radio:FireClient(player, data)
	else
		radio:FireAllClients(data)
	end
end

-- L'etape `id` est-elle ouverte, a faire maintenant ?
function QuestService.isOpen(id: string): boolean
	local step = Quest.current(Story, state)
	return step ~= nil and step.id == id
end

-- L'etape `id` est-elle ouverte, ou deja derriere nous ?
function QuestService.hasReached(id: string): boolean
	return Quest.reached(Story, state, id)
end

-- Ce qui remplit un trou du texte de Mara (`{key}`).
function QuestService.setValue(key: string, value: string)
	values[key] = value
end

-- Mara redira cette nuit le texte `again` de l'etape en cours (le
-- survivant aspire : ou il se cache maintenant).
function QuestService.sayAgainTonight()
	local step = Story[state.index]
	if step and step.again then
		againTonight = step.again
	end
end

-- Un evenement du jeu : s'il reussit l'etape ouverte, tout le monde le sait.
function QuestService.notify(event: string)
	if Quest.complete(Story, state, event) then
		LootService.broadcast("Objectif atteint. Mara rappellera cette nuit.", "quest")
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
			"L'antenne est en place. Vite : quelqu'un doit régler la radio à la Planque !",
			"quest"
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
			"La radio est réglée. Il faut poser l'antenne en haut du château d'eau, maintenant.",
			"quest"
		)
	end
end

-- Un souvenir trouve dans le Ventre : il s'ajoute au journal, une fois.
local memoriesFound: { [number]: boolean } = {}
function QuestService.addMemory(id: number, title: string, lines: { string }): boolean
	if memoriesFound[id] then
		return false
	end
	memoriesFound[id] = true
	table.insert(journal, { title = "Souvenir : " .. title, lines = lines })
	send(nil)
	return true
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
		LootService.broadcast("Nouvel objectif.", "quest")
	end
	send(nil)
end

-- Appele par DayService a la tombee de la nuit : Mara parle, si elle a de quoi.
function QuestService.night(dayNumber: number)
	local lines = table.clone(Quest.night(Story, state))
	if againTonight then
		for _, line in againTonight do
			table.insert(lines, line)
		end
		againTonight = nil
	end
	for _, line in Quest.briefing(Story, Config.story.opensOnDay, state, dayNumber) do
		table.insert(lines, line)
	end
	lines = Quest.fill(lines, values)
	if #lines > 0 then
		lastReport = lines
		table.insert(
			journal,
			{ title = string.format("Mara, nuit du jour %d", dayNumber), lines = lines }
		)
		LootService.broadcast("Journal mis à jour : Y, puis R1.", "quest")
		radio:FireAllClients({ lines = lines, lineSeconds = Config.story.lineSeconds })
	end
	send(nil)
end

-- Une defaite : l'histoire recommence avec la partie (decide avec Josh).
function QuestService.reset()
	state = Quest.new()
	relayAt, relayBy, tunedAt = nil, nil, nil
	againTonight = nil
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
