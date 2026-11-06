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

local Typography = require(script.Parent:WaitForChild("Typography"))

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
-- Quand l'Oeil te voit : ce qu'il murmure selon la jauge (de 0 a 1), le
-- battement des bords rouges (par seconde, au debut puis a la fin) et le
-- tremblement de la vue (en degres, jauge pleine).
local WHISPERS = {
	{ from = 0.02, text = "Je te vois…" },
	{ from = 0.45, text = "Ne bouge pas…" },
	{ from = 0.8, text = "À moi." },
}
local PULSE_SLOW, PULSE_FAST = 1.2, 3.2
local SHAKE_DEGREES = 0.6

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

	-- Cache, on voit dehors normalement (Josh : l'ecran noir et son message
	-- genaient). Il ne reste qu'un rappel discret en bas, et la lueur qui
	-- monte quand le regard approche.
	local dark = Instance.new("Frame")
	dark.Name = "Cachette"
	dark.Size = UDim2.fromScale(1, 1)
	dark.BackgroundTransparency = 1
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
		label(dark, "Texte", UDim2.fromScale(0.6, 0.05), UDim2.fromScale(0.5, 0.93), 17)
	hiddenText.ZIndex = 3
	hiddenText.TextTransparency = 0.25

	-- L'aspiration : un flash, puis le noir et ce qu'il t'a dit.
	local flash = Instance.new("Frame")
	flash.Name = "Eclair"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.ZIndex = 8
	flash.Parent = gui
	local taken = Instance.new("Frame")
	taken.Name = "Aspire"
	taken.Size = UDim2.fromScale(1, 1)
	taken.BackgroundColor3 = Color3.new(0, 0, 0)
	taken.BackgroundTransparency = 1
	taken.BorderSizePixel = 0
	taken.ZIndex = 7
	taken.Parent = gui
	local takenText =
		label(taken, "Texte", UDim2.fromScale(0.7, 0.2), UDim2.fromScale(0.5, 0.5), 40)
	takenText.Font = Typography.STORY
	takenText.TextColor3 = DANGER
	takenText.TextTransparency = 1
	takenText.ZIndex = 8

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
	gauge.Size = UDim2.fromOffset(220, 4)

	-- Les bords de l'ecran qui rougissent et battent quand il te voit : quatre
	-- degrades qui partent des bords.
	local edges: { Frame } = {}
	-- Chaque bord : ou il s'accroche, sa taille, et le sens du degrade (opaque
	-- au bord de l'ecran, transparent vers le centre).
	local function addEdge(anchor: Vector2, size: Vector2, rotation: number)
		local frame = Instance.new("Frame")
		frame.Name = "Bord"
		frame.AnchorPoint = anchor
		frame.Position = UDim2.fromScale(anchor.X, anchor.Y)
		frame.Size = UDim2.fromScale(size.X, size.Y)
		frame.BackgroundColor3 = Color3.fromRGB(150, 10, 6)
		frame.BorderSizePixel = 0
		frame.BackgroundTransparency = 1
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = rotation
		gradient.Transparency = NumberSequence.new(0, 1)
		gradient.Parent = frame
		frame.Parent = gui
		table.insert(edges, frame)
	end
	addEdge(Vector2.new(0.5, 0), Vector2.new(1, 0.22), 90)
	addEdge(Vector2.new(0.5, 1), Vector2.new(1, 0.22), -90)
	addEdge(Vector2.new(0, 0.5), Vector2.new(0.14, 1), 0)
	addEdge(Vector2.new(1, 0.5), Vector2.new(0.14, 1), 180)

	-- Le murmure de l'Oeil, au centre, qui tremble.
	local whisper =
		label(gui, "Murmure", UDim2.fromScale(0.6, 0.08), UDim2.fromScale(0.5, 0.62), 30)
	whisper.Font = Typography.STORY
	whisper.TextColor3 = DANGER
	whisper.TextStrokeTransparency = 0.5
	whisper.TextTransparency = 1
	whisper.ZIndex = 6

	-- La sante, en bas au centre : visible seulement quand elle n'est pas pleine.
	local healthBar = Instance.new("Frame")
	healthBar.Name = "Sante"
	healthBar.AnchorPoint = Vector2.new(0.5, 1)
	healthBar.Position = UDim2.new(0.5, 0, 1, -28)
	healthBar.Size = UDim2.fromOffset(220, 8)
	healthBar.BackgroundColor3 = PANEL
	healthBar.BackgroundTransparency = 0.3
	healthBar.BorderSizePixel = 0
	healthBar.Parent = gui
	local healthFill = Instance.new("Frame")
	healthFill.Name = "Plein"
	healthFill.Size = UDim2.fromScale(1, 1)
	healthFill.BackgroundColor3 = INK
	healthFill.BorderSizePixel = 0
	healthFill.Parent = healthBar

	-- A terre : un voile rouge sombre, et ce qu'il faut attendre.
	local downed = Instance.new("Frame")
	downed.Name = "ATerre"
	downed.Size = UDim2.fromScale(1, 1)
	downed.BackgroundColor3 = Color3.fromRGB(60, 8, 6)
	downed.BackgroundTransparency = 0.45
	downed.Visible = false
	downed.Parent = gui
	local downedText =
		label(downed, "Texte", UDim2.fromScale(0.7, 0.2), UDim2.fromScale(0.5, 0.62), 24)
	downedText.Text = "À terre.\nUn ami peut te relever. Sinon, tu te relèveras à l'aube."

	local message = label(gui, "Message", UDim2.fromScale(0.6, 0.08), UDim2.fromScale(0.5, 0.3), 24)
	message.ZIndex = 5
	-- Un contour leger plutot qu'un bandeau : un bandeau faisait une boite aux
	-- bords durs (vu en jeu le 6 novembre 2026).
	message.TextStrokeTransparency = 0.55
	message.TextTransparency = 1

	-- Le titre du jour : au centre, en machine a ecrire, puis il s'efface.
	-- Plus bas que les messages (0,3) : a l'aube, les deux arrivent ensemble.
	local dayTitle = label(gui, "Jour", UDim2.fromScale(0.8, 0.1), UDim2.fromScale(0.5, 0.46), 58)
	dayTitle.Font = Typography.STORY
	dayTitle.TextColor3 = Typography.KINDS.day
	dayTitle.TextStrokeTransparency = 0.8
	dayTitle.TextTransparency = 1
	dayTitle.ZIndex = 5
	local daySub =
		label(gui, "JourSuite", UDim2.fromScale(0.7, 0.06), UDim2.fromScale(0.5, 0.54), 22)
	daySub.Font = Typography.STORY
	daySub.TextColor3 = Typography.KINDS.danger
	daySub.TextStrokeTransparency = 0.8
	daySub.TextTransparency = 1
	daySub.ZIndex = 5

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

	-- Un message glisse en place et s'ecrit vite, dans la couleur de sa sorte,
	-- puis s'efface ; un danger reste un peu plus.
	local messageToken = 0
	local function show(text: string, kind: string?)
		messageToken += 1
		local mine = messageToken
		local color = Typography.KINDS[kind or "info"] or Typography.INK
		message.TextColor3 = color
		message.Position = UDim2.fromScale(0.5, 0.315)
		message.TextTransparency = 1
		local enter = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(message, enter, {
			Position = UDim2.fromScale(0.5, 0.3),
			TextTransparency = 0,
		}):Play()
		Typography.typewrite(message, text, Typography.MESSAGE_SPEED)
		local hold = if kind == "danger" then MESSAGE_SECONDS + 1.5 else MESSAGE_SECONDS
		task.delay(hold, function()
			if mine == messageToken then
				local leave = TweenInfo.new(0.8)
				TweenService:Create(message, leave, { TextTransparency = 1 }):Play()
			end
		end)
	end

	-- « Jour 9. L'Oeil s'impatiente : ... » : le titre, puis la suite dessous.
	local dayToken = 0
	local function showDay(text: string)
		dayToken += 1
		local mine = dayToken
		local title, rest = string.match(text, "^(Jour %d+)%.?%s*(.*)$")
		dayTitle.TextTransparency = 0
		local writing = Typography.typewrite(dayTitle, title or text, Typography.STORY_SPEED / 3)
		daySub.Text = ""
		if rest and rest ~= "" then
			task.delay(writing + 0.4, function()
				if mine == dayToken then
					daySub.TextTransparency = 0
					Typography.typewrite(daySub, rest, Typography.STORY_SPEED)
				end
			end)
		end
		task.delay(writing + 4.5, function()
			if mine == dayToken then
				local leave = TweenInfo.new(1.6)
				TweenService:Create(dayTitle, leave, { TextTransparency = 1 }):Play()
				TweenService:Create(daySub, leave, { TextTransparency = 1 }):Play()
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
			if data.kind == "day" then
				showDay(data.message)
			else
				show(data.message, data.kind)
			end
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
	-- La nuit, cote client seulement : l'heure et la lumiere baissent. Le
	-- serveur garde la lumiere du jour (c'est la sienne qui sert aux rayons, et
	-- l'Oeil ne regarde pas la nuit).
	local dayClock = Lighting.ClockTime
	local dayBrightness = Lighting.Brightness
	local dayOutdoor = Lighting.OutdoorAmbient
	local function nightTo(on: boolean)
		local info = TweenInfo.new(6)
		if on then
			TweenService:Create(Lighting, info, {
				ClockTime = Config.sky.night.clockTime,
				Brightness = Config.sky.night.brightness,
				OutdoorAmbient = Color3.fromRGB(table.unpack(Config.sky.night.outdoorAmbient)),
			}):Play()
		else
			TweenService:Create(Lighting, info, {
				ClockTime = dayClock,
				Brightness = dayBrightness,
				OutdoorAmbient = dayOutdoor,
			}):Play()
		end
	end

	local eyeState = Remotes:WaitForChild("EyeState") :: RemoteEvent
	eyeState.OnClientEvent:Connect(function(data: any)
		if data.phase == "night" then
			tintTo(Color3.fromRGB(170, 180, 215), -0.45, 6)
			nightTo(true)
			return
		elseif data.phase == "dawn" then
			tintTo(Color3.new(1, 1, 1), 0, 6)
			nightTo(false)
			return
		end
		if data.phase == "warning" then
			show("Le ciel rougit…", "danger")
			tintTo(Color3.fromRGB(255, 196, 186), -0.15, data.seconds)
		elseif data.phase == "sweep" then
			tintTo(Color3.fromRGB(255, 170, 160), -0.3, 1)
		else
			tintTo(Color3.new(1, 1, 1), 0, 3)
		end
	end)

	local function refreshStates()
		local hidden = player:GetAttribute("Hidden") == true
		-- Attache dans un cocon : le meme rappel discret, en bas.
		local bound = player:GetAttribute("Bound") == true
		dark.Visible = hidden or bound
		hiddenText.Text = if bound
			then "Attaché   ·   Tes amis doivent venir te détacher"
			else "Caché   ·   Sortir : " .. buttonName(Config.controls.contexts.hidden.leave)
		downed.Visible = player:GetAttribute("Downed") == true
	end
	player:GetAttributeChangedSignal("Downed"):Connect(refreshStates)
	player:GetAttributeChangedSignal("Bound"):Connect(refreshStates)
	player:GetAttributeChangedSignal("Health"):Connect(function()
		local health = player:GetAttribute("Health")
		local ratio = if typeof(health) == "number" then health / Config.combat.playerHealth else 1
		healthFill.Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
		healthBar.Visible = ratio < 0.999
	end)
	healthBar.Visible = false

	-- La faim, sous la sante : elle se voit des qu'elle baisse d'un quart.
	local hungerBar = healthBar:Clone()
	hungerBar.Name = "Faim"
	hungerBar.Position = UDim2.new(0.5, 0, 1, -14)
	hungerBar.Size = UDim2.fromOffset(220, 5)
	hungerBar.Parent = gui
	local hungerFill = hungerBar:FindFirstChild("Plein") :: Frame
	hungerFill.BackgroundColor3 = Color3.fromRGB(196, 150, 82)
	local function refreshHunger()
		local hunger = player:GetAttribute("Hunger")
		local ratio = if typeof(hunger) == "number" then hunger / Config.needs.hungerMax else 1
		hungerFill.Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
		hungerBar.Visible = ratio < 0.75
	end
	player:GetAttributeChangedSignal("Hunger"):Connect(refreshHunger)
	refreshHunger()
	player:GetAttributeChangedSignal("Hidden"):Connect(refreshStates)
	player:GetAttributeChangedSignal("Taken"):Connect(refreshStates)

	-- L'ASPIRATION, vue par celui qu'on aspire : un flash blanc qui vire au
	-- rouge, la camera forcee vers l'Oeil pendant qu'il monte en tournoyant,
	-- puis le noir et « Il t'a pris. » Un nouveau personnage (le Ventre, ou le
	-- retour) rend la camera et dissipe le noir.
	local defaultFov = workspace.CurrentCamera.FieldOfView
	local capture = 0
	local function eyePosition(): Vector3
		local w = Config.world
		local root = workspace:FindFirstChild(w.folder)
		local sky = root and root:FindFirstChild(w.sky)
		local eye = sky and sky:FindFirstChild(w.eye)
		if eye and eye:IsA("Model") then
			return eye:GetPivot().Position
		end
		return workspace.CurrentCamera.CFrame.Position + Vector3.new(0, 600, 0)
	end
	local function onTaken()
		if player:GetAttribute("Taken") ~= true then
			return
		end
		capture += 1
		local mine = capture
		local camera = workspace.CurrentCamera
		local lift = Config.eye.takenLiftSeconds
		flash.BackgroundColor3 = Color3.new(1, 1, 1)
		flash.BackgroundTransparency = 0
		TweenService:Create(flash, TweenInfo.new(0.35), {
			BackgroundColor3 = Color3.fromRGB(190, 24, 12),
			BackgroundTransparency = 0.35,
		}):Play()
		task.delay(0.35, function()
			TweenService:Create(flash, TweenInfo.new(1.2), { BackgroundTransparency = 1 }):Play()
		end)
		local target = eyePosition()
		local started = os.clock()
		camera.CameraType = Enum.CameraType.Scriptable
		RunService:BindToRenderStep(
			"SurvivorAspiration",
			Enum.RenderPriority.Camera.Value + 2,
			function()
				local t = math.clamp((os.clock() - started) / lift, 0, 1)
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				local from = if root and root:IsA("BasePart")
					then root.Position + Vector3.new(0, 1.5, 0)
					else camera.CFrame.Position
				camera.CFrame = CFrame.lookAt(from, target) * CFrame.Angles(0, 0, t * math.pi * 1.5)
				camera.FieldOfView = defaultFov + 40 * t
			end
		)
		task.delay(lift * 0.7, function()
			if mine ~= capture then
				return
			end
			TweenService:Create(taken, TweenInfo.new(0.8), { BackgroundTransparency = 0 }):Play()
			takenText.TextTransparency = 0
			Typography.typewrite(takenText, "Il t'a pris.", Typography.STORY_SPEED / 2)
		end)
		task.delay(lift + 0.1, function()
			RunService:UnbindFromRenderStep("SurvivorAspiration")
			camera.FieldOfView = defaultFov
		end)
	end
	player:GetAttributeChangedSignal("Taken"):Connect(onTaken)
	player.CharacterAdded:Connect(function(character: Model)
		RunService:UnbindFromRenderStep("SurvivorAspiration")
		local camera = workspace.CurrentCamera
		camera.FieldOfView = defaultFov
		camera.CameraType = Enum.CameraType.Custom
		camera.CameraSubject = character:WaitForChild("Humanoid") :: Humanoid
		if taken.BackgroundTransparency < 1 then
			task.delay(1, function()
				local out = TweenInfo.new(1.5)
				TweenService:Create(taken, out, { BackgroundTransparency = 1 }):Play()
				TweenService:Create(takenText, out, { TextTransparency = 1 }):Play()
			end)
		end
	end)
	UserInputService.LastInputTypeChanged:Connect(refreshStates)
	refreshStates()

	-- La vue tremble quand il te voit : apres la camera de Roblox, a chaque
	-- image, une petite secousse qui grandit avec la jauge.
	local exposure = 0
	RunService:BindToRenderStep(
		"SurvivorRegardSecousse",
		Enum.RenderPriority.Camera.Value + 1,
		function()
			if exposure > 0.02 then
				local camera = workspace.CurrentCamera
				local a = math.rad(SHAKE_DEGREES * exposure)
				camera.CFrame *= CFrame.Angles(
					(math.random() - 0.5) * a,
					(math.random() - 0.5) * a,
					(math.random() - 0.5) * a
				)
			end
		end
	)

	RunService.RenderStepped:Connect(function()
		local level = player:GetAttribute("Exposure")
		local value = if typeof(level) == "number" then level else 0
		exposure = value
		gauge.Visible = value > 0.01 and not dark.Visible
		fill.Size = UDim2.fromScale(value, 1)

		-- Les bords battent comme un coeur, plus vite et plus fort quand la
		-- jauge monte.
		local rate = PULSE_SLOW + (PULSE_FAST - PULSE_SLOW) * value
		local beat = 0.5 + 0.5 * math.sin(os.clock() * math.pi * 2 * rate)
		local redness = if value > 0.01
			then math.clamp(value * 0.7 + beat * 0.3 * value + 0.1, 0, 0.9)
			else 0
		for _, edge in edges do
			edge.BackgroundTransparency = 1 - redness
		end
		-- Le murmure : la phrase de la jauge, de plus en plus grande et
		-- tremblante.
		local said: string? = nil
		for _, w in WHISPERS do
			if value >= w.from then
				said = w.text
			end
		end
		if said and value > 0.01 then
			if whisper.Text ~= said then
				Typography.typewrite(whisper, said, Typography.STORY_SPEED)
			end
			whisper.TextTransparency = 0.1
			whisper.TextSize = 26 + 18 * value
			local jitter = 4 * value
			whisper.Position =
				UDim2.new(0.5, (math.random() - 0.5) * jitter, 0.62, (math.random() - 0.5) * jitter)
		else
			whisper.TextTransparency = 1
			whisper.Text = ""
		end

		-- Cache, une lueur monte en bas de l'ecran quand le regard passe
		-- pres : on le voit aussi, mais pas forcement s'il est dans le dos.
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
