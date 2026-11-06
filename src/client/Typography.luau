--!strict
--[[
	Typography — l'allure des textes, a un seul endroit (Josh : « que les
	textes soient plus sympas »).

	Deux voix : une police de machine a ecrire pour ce qui raconte (la radio,
	le journal, les titres des jours, les murmures de l'Oeil), et une police
	nette pour ce qu'on lit d'un coup d'oeil en jouant. Chaque sorte de
	message a sa couleur. Ce sont des choix d'interface, pas des reglages de
	jeu : ils restent ici, nommes.
]]

local RunService = game:GetService("RunService")

local Typography = {}

Typography.STORY = Enum.Font.SpecialElite
Typography.UI = Enum.Font.GothamMedium

Typography.INK = Color3.fromRGB(236, 230, 218)
Typography.DIM = Color3.fromRGB(150, 143, 132)

-- La couleur de chaque sorte de message envoyee par le serveur.
Typography.KINDS = {
	info = Color3.fromRGB(236, 230, 218),
	danger = Color3.fromRGB(236, 96, 72),
	quest = Color3.fromRGB(234, 190, 112),
	radio = Color3.fromRGB(196, 222, 170),
	day = Color3.fromRGB(240, 232, 214),
}

-- Lettres par seconde : la radio se lit, un message se voit.
Typography.STORY_SPEED = 38
Typography.MESSAGE_SPEED = 90

-- Ecrit `text` dans `label` lettre par lettre. Un nouvel appel sur le meme
-- label interrompt le precedent. Rend la duree de l'ecriture.
local writing: { [TextLabel]: number } = {}
function Typography.typewrite(label: TextLabel, text: string, lettersPerSecond: number): number
	local token = (writing[label] or 0) + 1
	writing[label] = token
	label.Text = text
	label.MaxVisibleGraphemes = 0
	local total = utf8.len(text) or #text
	local duration = total / lettersPerSecond
	task.spawn(function()
		local started = os.clock()
		while writing[label] == token do
			local shown = math.floor((os.clock() - started) * lettersPerSecond)
			if shown >= total then
				label.MaxVisibleGraphemes = -1
				break
			end
			label.MaxVisibleGraphemes = shown
			RunService.RenderStepped:Wait()
		end
	end)
	return duration
end

return Typography
