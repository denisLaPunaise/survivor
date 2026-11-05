--!strict
--[[
	Hud — ce que le joueur voit a l'ecran : la jauge du regard, les messages,
	le sac, la reserve, l'ecran noir de la cachette et celui de l'aspiration.

	Le ciel qui rougit vit ici aussi : c'est le signe principal (decide), il
	doit se voir meme caché, par la lueur qui filtre.

	Rien ne se decide ici : tout vient des attributs du joueur (`Exposure`,
	`Hidden`, `Taken`) et des remotes `Hud` et `EyeState`.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Survivor = ReplicatedStorage:WaitForChild("Survivor")
local Config = require(Survivor:WaitForChild("Config"))
local Remotes = Survivor:WaitForChild("Remotes")

local Hud = {}

local player = Players.LocalPlayer

-- Couleurs et tailles d'interface : ce ne sont pas des reglages de jeu, elles
-- restent ici, nommees.
local INK = Color3.fromRGB(236, 230, 218)
local DANGER = Color3.fromRGB(214, 74, 58)
local PANEL = Color3.fromRGB(16, 15, 14)
local FONT = Enum.Font.GothamMedium
local MESSAGE_SECONDS = 4
-- La lueur sous la porte commence a ce multiple du rayon du regard.
local GLOW_RANGE_RADII = 4

local function label(
	parent: Instance,
	name: string,
	size: UDim2,
	position: UDim2,
	textSize: number
): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Size = size
	l.Position = position
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.BackgroundTransparency = 1
	l.TextColor3 = INK
	l.Font = FONT
	l.TextSize = textSize
	l.TextWrapped = true
	l.Text = ""
	l.Parent = parent
	return l
end

local function buttonName(binding: { gamepad: string, keyboard: string }): string
	local last = UserInputService:GetLastInputType()
	if string.find(last.Name, "Gamepad") then
		return (string.gsub(binding.gamepad, "^Button", ""))
	end
	return binding.keyboard
end

function Hud.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "SurvivorHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 5
	gui.Parent = player:WaitForChild("PlayerGui")

	-- L'ecran de cachette passe SOUS le texte, au-dessus du monde.
	local dark = Instance.new("Frame")
	dark.Name = "Cachette"
	dark.Size = UDim2.fromScale(1, 1)
	dark.BackgroundColor3 = Color3.new(0, 0, 0)
	dark.BackgroundTransparency = 0.04
	dark.Visible = false
	dark.ZIndex = 1
	dark.Parent = gui

	local glow = Instance.new("Frame")
	glow.Name = "Lueur"
	glow.Size = UDim2.fromScale(1, 0.18)
	glow.Position = UDim2.fromScale(0, 0.82)
	glow.BackgroundColor3 = Color3.fromRGB(255, 196, 170)
	glow.BackgroundTransparency = 1
	glow.BorderSizePixel = 0
	glow.ZIndex = 2
	glow.Parent = dark
	local fade = Instance.new("UIGradient")
	fade.Rotation = -90
	fade.Transparency = NumberSequence.new(0, 1)
	fade.Parent = glow

	local hiddenText =
		label(dark, "Texte", UDim2.fromScale(0.6, 0.1), UDim2.fromScale(0.5, 0.5), 22)
	hiddenText.ZIndex = 3

	local taken = Instance.new("Frame")
	taken.Name = "Aspire"
	taken.Size = UDim2.fromScale(1, 1)
	taken.BackgroundColor3 = Color3.fromRGB(240, 236, 228)
	taken.BackgroundTransparency = 0.05
	taken.Visible = false
	taken.Parent = gui
	local takenText =
		label(taken, "Texte", UDim2.fromScale(0.7, 0.2), UDim2.fromScale(0.5, 0.5), 26)
	takenText.TextColor3 = PANEL
	takenText.Text = "Le Veilleur t'a vu.\nTu reviendras au matin, quelque part dans la ville."

	-- La jauge du regard, en haut au centre.
	local gauge = Instance.new("Frame")
	gauge.Name = "Regard"
	gauge.AnchorPoint = Vector2.new(0.5, 0)
	gauge.Position = UDim2.new(0.5, 0, 0, 72)
	gauge.Size = UDim2.fromOffset(260, 10)
	gauge.BackgroundColor3 = PANEL
	gauge.BackgroundTransparency = 0.3
	gauge.BorderSizePixel = 0
	gauge.Visible = false
	gauge.Parent = gui
	local fill = Instance.new("Frame")
	fill.Name = "Plein"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = DANGER
	fill.BorderSizePixel = 0
	fill.Parent = gauge
	local gaugeText =
		label(gauge, "Texte", UDim2.fromOffset(260, 24), UDim2.new(0.5, 0, 0, -16), 16)
	gaugeText.Text = "IL TE VOIT"
	gaugeText.TextColor3 = DANGER

	local message = label(gui, "Message", UDim2.fromScale(0.6, 0.08), UDim2.fromScale(0.5, 0.3), 26)
	message.ZIndex = 4

	local bagText = Instance.new("TextLabel")
	bagText.Name = "Sac"
	bagText.AnchorPoint = Vector2.new(0, 1)
	bagText.Position = UDim2.new(0, 24, 1, -24)
	bagText.Size = UDim2.fromOffset(420, 90)
	bagText.BackgroundTransparency = 1
	bagText.TextColor3 = INK
	bagText.Font = FONT
	bagText.TextSize = 18
	bagText.TextXAlignment = Enum.TextXAlignment.Left
	bagText.TextYAlignment = Enum.TextYAlignment.Bottom
	bagText.TextWrapped = true
	bagText.Parent = gui

	local stockText = bagText:Clone()
	stockText.Name = "Reserve"
	stockText.AnchorPoint = Vector2.new(1, 0)
	stockText.Position = UDim2.new(1, -24, 0, 72)
	stockText.TextXAlignment = Enum.TextXAlignment.Right
	stockText.TextYAlignment = Enum.TextYAlignment.Top
	stockText.TextSize = 16
	stockText.Parent = gui

	local messageToken = 0
	local function show(text: string)
		messageToken += 1
		local mine = messageToken
		message.Text = text
		message.TextTransparency = 0
		task.delay(MESSAGE_SECONDS, function()
			if mine == messageToken then
				TweenService:Create(message, TweenInfo.new(1), { TextTransparency = 1 }):Play()
			end
		end)
	end

	local hud = Remotes:WaitForChild("Hud") :: RemoteEvent
	hud.OnClientEvent:Connect(function(data: any)
		bagText.Text =
			string.format("Sac %d/%d\n%s", #data.bag, data.slots, table.concat(data.bag, " · "))
		local lines: { string } = { "Réserve" }
		local ids: { string } = {}
		for itemId in data.stock do
			table.insert(ids, itemId)
		end
		table.sort(ids)
		for _, itemId in ids do
			local item = Config.items[itemId]
			table.insert(
				lines,
				string.format("%s × %d", if item then item.name else itemId, data.stock[itemId])
			)
		end
		stockText.Text = table.concat(lines, "\n")
		if data.message then
			show(data.message)
		end
	end)

	-- Le ciel qui rougit.
	local tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "SurvivorSignes"
	tint.Parent = Lighting
	local function tintTo(color: Color3, saturation: number, seconds: number)
		TweenService
			:Create(tint, TweenInfo.new(seconds), { TintColor = color, Saturation = saturation })
			:Play()
	end
	local eyeState = Remotes:WaitForChild("EyeState") :: RemoteEvent
	eyeState.OnClientEvent:Connect(function(data: any)
		if data.phase == "warning" then
			show("Le ciel rougit…")
			tintTo(Color3.fromRGB(255, 196, 186), -0.15, data.seconds)
		elseif data.phase == "sweep" then
			tintTo(Color3.fromRGB(255, 170, 160), -0.3, 1)
		else
			tintTo(Color3.new(1, 1, 1), 0, 3)
		end
	end)

	local function refreshStates()
		local hidden = player:GetAttribute("Hidden") == true
		dark.Visible = hidden
		hiddenText.Text = "Caché. Tu ne vois rien dehors.\nSortir : "
			.. buttonName(Config.controls.contexts.hidden.leave)
		taken.Visible = player:GetAttribute("Taken") == true
	end
	player:GetAttributeChangedSignal("Hidden"):Connect(refreshStates)
	player:GetAttributeChangedSignal("Taken"):Connect(refreshStates)
	UserInputService.LastInputTypeChanged:Connect(refreshStates)
	refreshStates()

	RunService.RenderStepped:Connect(function()
		local level = player:GetAttribute("Exposure")
		local value = if typeof(level) == "number" then level else 0
		gauge.Visible = value > 0.01 and not dark.Visible
		fill.Size = UDim2.fromScale(value, 1)

		-- Cache, on ne voit pas l'Oeil : seule une lueur filtre quand le
		-- regard passe pres (decide avec Josh).
		if dark.Visible then
			local beam = workspace:FindFirstChild("Regard")
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local strength = 0
			if beam and beam:IsA("BasePart") and root and root:IsA("BasePart") then
				local look = beam.CFrame.RightVector
				local tip = beam.Position + look * (beam.Size.X / 2)
				local flat =
					Vector3.new(tip.X - root.Position.X, 0, tip.Z - root.Position.Z).Magnitude
				local range = Config.eye.beamRadius * GLOW_RANGE_RADII
				strength = math.clamp(1 - flat / range, 0, 1)
			end
			glow.BackgroundTransparency = 1 - strength * 0.85
		end
	end)
end

return Hud
