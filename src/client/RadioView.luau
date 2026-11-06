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

local INK = Color3.fromRGB(236, 230, 218)
local RADIO = Color3.fromRGB(196, 222, 170)
local FONT = Enum.Font.GothamMedium

function RadioView.start()
	local player = Players.LocalPlayer
	local radio = Remotes:WaitForChild("Radio") :: RemoteEvent

	local gui = Instance.new("ScreenGui")
	gui.Name = "SurvivorRadio"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	gui.Parent = player:WaitForChild("PlayerGui")

	local objective = Instance.new("TextLabel")
	objective.Name = "Objectif"
	objective.Position = UDim2.fromOffset(24, 72)
	objective.Size = UDim2.new(0.32, 0, 0, 60)
	objective.BackgroundTransparency = 1
	objective.Font = FONT
	objective.TextSize = 15
	objective.TextColor3 = INK
	objective.TextTransparency = 0.15
	objective.TextStrokeTransparency = 0.6
	objective.TextWrapped = true
	objective.TextXAlignment = Enum.TextXAlignment.Left
	objective.TextYAlignment = Enum.TextYAlignment.Top
	objective.Text = ""
	objective.Parent = gui

	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Radio"
	subtitle.AnchorPoint = Vector2.new(0.5, 1)
	subtitle.Position = UDim2.fromScale(0.5, 0.84)
	subtitle.Size = UDim2.new(0.62, 0, 0, 70)
	subtitle.BackgroundTransparency = 1
	subtitle.Font = FONT
	subtitle.TextSize = 20
	subtitle.TextColor3 = RADIO
	subtitle.TextStrokeTransparency = 0.4
	subtitle.TextWrapped = true
	subtitle.TextTransparency = 1
	subtitle.Text = ""
	subtitle.Parent = gui

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
		while #queue > 0 do
			local line = table.remove(queue, 1) :: string
			subtitle.Text = "RADIO · " .. line
			TweenService:Create(subtitle, TweenInfo.new(0.4), { TextTransparency = 0 }):Play()
			task.wait(lineSeconds)
			TweenService:Create(subtitle, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			task.wait(0.5)
		end
		playing = false
	end

	radio.OnClientEvent:Connect(function(data: any)
		if typeof(data) ~= "table" then
			return
		end
		if typeof(data.objective) == "string" then
			objective.Text = if data.objective == "" then "" else "Objectif · " .. data.objective
		end
		if typeof(data.lines) == "table" then
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
