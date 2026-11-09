--!strict
--[[
	ChapterView — l'ecran de fin d'un chapitre (Josh : « ecran de fin, puis
	on continue »). Quand l'Oeil aspire le Gardien, l'ecran se voile de noir,
	le titre s'ecrit a la machine, le nombre de jours dessous, puis tout
	s'efface et la partie continue. Aucun bouton : rien a faire a la manette.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Survivor = ReplicatedStorage:WaitForChild("Survivor")
local Remotes = Survivor:WaitForChild("Remotes")

local Typography = require(script.Parent:WaitForChild("Typography"))

local ChapterView = {}

-- Les titres des chapitres (CONCEPT 14) : un seul existe pour l'instant.
local TITLES = {
	[1] = "La Banlieue",
}

local FADE_SECONDS = 1.5

function ChapterView.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "SurvivorChapitre"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50
	gui.Enabled = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local veil = Instance.new("Frame")
	veil.Size = UDim2.fromScale(1, 1)
	veil.BackgroundColor3 = Color3.new(0, 0, 0)
	veil.BackgroundTransparency = 1
	veil.BorderSizePixel = 0
	veil.Parent = gui

	local function text(y: number, size: number, font: Enum.Font, color: Color3): TextLabel
		local label = Instance.new("TextLabel")
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.fromScale(0.5, y)
		label.Size = UDim2.fromScale(0.8, 0.1)
		label.BackgroundTransparency = 1
		label.Font = font
		label.TextSize = size
		label.TextColor3 = color
		label.TextTransparency = 1
		label.TextWrapped = true
		label.Text = ""
		label.Parent = veil
		return label
	end
	local kicker = text(0.34, 22, Typography.UI, Typography.DIM)
	local title = text(0.45, 52, Typography.STORY, Typography.KINDS.quest)
	local days = text(0.58, 24, Typography.STORY, Typography.INK)

	local chapter = Remotes:WaitForChild("Chapter") :: RemoteEvent
	chapter.OnClientEvent:Connect(function(data: any)
		-- Le serveur envoie tout (Config.gardien.endScreenSeconds) : pas de
		-- valeur de repli cachee ici.
		if
			typeof(data) ~= "table"
			or typeof(data.seconds) ~= "number"
			or typeof(data.days) ~= "number"
			or typeof(data.chapter) ~= "number"
		then
			return
		end
		local seconds = data.seconds
		gui.Enabled = true
		local fade = TweenInfo.new(FADE_SECONDS)
		TweenService:Create(veil, fade, { BackgroundTransparency = 0.1 }):Play()
		for _, label in { kicker, title, days } do
			label.Text = ""
			TweenService:Create(label, fade, { TextTransparency = 0 }):Play()
		end
		kicker.Text = string.format("FIN DU CHAPITRE %d", data.chapter)
		task.delay(FADE_SECONDS * 0.5, function()
			local written =
				Typography.typewrite(title, TITLES[data.chapter] or "", Typography.STORY_SPEED / 2)
			task.delay(written + 0.4, function()
				local n = data.days
				Typography.typewrite(
					days,
					string.format(
						"Vous avez tenu %d jour%s. L'Œil vous cherche toujours.",
						n,
						if n > 1 then "s" else ""
					),
					Typography.STORY_SPEED
				)
			end)
		end)
		task.delay(seconds, function()
			TweenService:Create(veil, fade, { BackgroundTransparency = 1 }):Play()
			for _, label in { kicker, title, days } do
				TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
			end
			task.delay(FADE_SECONDS, function()
				gui.Enabled = false
			end)
		end)
	end)
end

return ChapterView
