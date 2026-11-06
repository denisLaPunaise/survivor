--!strict
--[[
	RadioView — l'objectif du moment, et la voix de la radio en sous-titres.

	Rien a appuyer : l'objectif reste en haut a gauche, discret ; la nuit, les
	lignes de Mara passent en bas de l'ecran, une a une, chez tout le monde en
	meme temps (decide avec Josh : pas de voix enregistrees).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Survivor = ReplicatedStorage:WaitForChild("Survivor")
local Remotes = Survivor:WaitForChild("Remotes")

local RadioView = {}

local Typography = require(script.Parent:WaitForChild("Typography"))

function RadioView.start()
	local player = Players.LocalPlayer
	local radio = Remotes:WaitForChild("Radio") :: RemoteEvent

	local gui = Instance.new("ScreenGui")
	gui.Name = "SurvivorRadio"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	gui.Parent = player:WaitForChild("PlayerGui")

	-- L'objectif : un petit titre dore, puis la phrase, discrete.
	local objectiveHead = Instance.new("TextLabel")
	objectiveHead.Name = "ObjectifTitre"
	objectiveHead.Position = UDim2.fromOffset(24, 70)
	objectiveHead.Size = UDim2.new(0.32, 0, 0, 16)
	objectiveHead.BackgroundTransparency = 1
	objectiveHead.Font = Typography.STORY
	objectiveHead.TextSize = 14
	objectiveHead.TextColor3 = Typography.KINDS.quest
	objectiveHead.TextXAlignment = Enum.TextXAlignment.Left
	objectiveHead.Text = ""
	objectiveHead.Parent = gui

	local objective = Instance.new("TextLabel")
	objective.Name = "Objectif"
	objective.Position = UDim2.fromOffset(24, 88)
	-- La hauteur suit le texte : a 60 px fixes, un long objectif etait coupe.
	objective.Size = UDim2.fromScale(0.32, 0)
	objective.AutomaticSize = Enum.AutomaticSize.Y
	objective.BackgroundTransparency = 1
	objective.Font = Typography.UI
	objective.TextSize = 15
	objective.TextColor3 = Typography.INK
	objective.TextTransparency = 0.1
	objective.TextStrokeTransparency = 0.6
	objective.TextWrapped = true
	objective.TextXAlignment = Enum.TextXAlignment.Left
	objective.TextYAlignment = Enum.TextYAlignment.Top
	objective.Text = ""
	objective.Parent = gui

	-- La radio : un petit « RADIO » qui gresille, et la voix de Mara en
	-- machine a ecrire.
	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Radio"
	subtitle.AnchorPoint = Vector2.new(0.5, 1)
	subtitle.Position = UDim2.fromScale(0.5, 0.84)
	subtitle.Size = UDim2.fromScale(0.62, 0.1)
	subtitle.BackgroundTransparency = 1
	subtitle.Font = Typography.STORY
	subtitle.TextSize = 22
	subtitle.TextColor3 = Typography.KINDS.radio
	subtitle.TextStrokeTransparency = 0.45
	subtitle.TextWrapped = true
	subtitle.TextTransparency = 1
	subtitle.ZIndex = 2
	subtitle.Text = ""
	subtitle.Parent = gui
	local tag = Instance.new("TextLabel")
	tag.Name = "RadioTitre"
	tag.AnchorPoint = Vector2.new(0.5, 1)
	tag.Position = UDim2.new(0.5, 0, 0.74, -4)
	tag.Size = UDim2.fromOffset(200, 18)
	tag.BackgroundTransparency = 1
	tag.Font = Typography.STORY
	tag.TextSize = 14
	tag.TextColor3 = Typography.KINDS.radio
	tag.TextTransparency = 1
	tag.Text = "· RADIO ·"
	tag.Parent = gui

	-- Les lignes arrivent par paquets ; un nouveau paquet attend la fin du
	-- precedent.
	local queue: { string } = {}
	-- Remplace par ce que le serveur envoie (Config.story.lineSeconds).
	local lineSeconds = 0
	local playing = false
	local function play()
		if playing then
			return
		end
		playing = true
		local fade = TweenInfo.new(0.4)
		while #queue > 0 do
			local line = table.remove(queue, 1) :: string
			subtitle.TextTransparency = 0
			local writing = Typography.typewrite(subtitle, line, Typography.STORY_SPEED)
			-- Le temps d'ecrire, puis le temps de lire.
			local started = os.clock()
			while os.clock() - started < math.max(lineSeconds, writing + 2) do
				-- Le gresillement : le titre clignote, la voix tremble a peine.
				tag.TextTransparency = 0.2 + math.random() * 0.5
				subtitle.TextTransparency = if math.random() < 0.06 then 0.35 else 0
				task.wait(0.08)
			end
			TweenService:Create(subtitle, fade, { TextTransparency = 1 }):Play()
			task.wait(0.5)
		end
		TweenService:Create(tag, fade, { TextTransparency = 1 }):Play()
		playing = false
	end

	local lastObjective = ""
	radio.OnClientEvent:Connect(function(data: any)
		if typeof(data) ~= "table" then
			return
		end
		if typeof(data.objective) == "string" and data.objective ~= lastObjective then
			lastObjective = data.objective
			objectiveHead.Text = if data.objective == "" then "" else "OBJECTIF"
			-- Un nouvel objectif s'ecrit, et son titre s'allume un instant.
			Typography.typewrite(objective, data.objective, Typography.MESSAGE_SPEED)
			objectiveHead.TextTransparency = 0
			objectiveHead.TextColor3 = Color3.new(1, 1, 1)
			TweenService
				:Create(objectiveHead, TweenInfo.new(1.5), { TextColor3 = Typography.KINDS.quest })
				:Play()
		end
		if typeof(data.lines) == "table" then
			-- Un souvenir lu dans le Ventre porte son propre titre.
			tag.Text = if typeof(data.tag) == "string" then data.tag else "· RADIO ·"
			if typeof(data.lineSeconds) == "number" then
				lineSeconds = data.lineSeconds
			end
			for _, line in data.lines do
				table.insert(queue, line)
			end
			task.spawn(play)
		end
	end)
	-- Pret a ecouter : on demande ou l'on en est.
	radio:FireServer()
end

return RadioView
