--!strict
--[[
	VentreView — ce que voit celui qui attend dans le Ventre de l'Oeil.

	- Regarder par l'Oeil (l'Oculus) : la camera monte a la place de l'Oeil et
	  regarde la ville. La zone du prochain Balayage s'y dessine en rouge des
	  le signal, le faisceau se suit, et les amis sont surlignes : on les
	  previent a la voix. B revient (Config.controls.contexts.watch).
]]

local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Survivor = ReplicatedStorage:WaitForChild("Survivor")
local Config = require(Survivor:WaitForChild("Config"))
local Remotes = Survivor:WaitForChild("Remotes")

local Typography = require(script.Parent:WaitForChild("Typography"))

local VentreView = {}

-- La distance du centre de l'Oeil au-dela de sa pupille (globe de 120, pupille
-- a ~132) : c'est d'ici qu'on regarde la ville.
local EYE_REACH = 145
-- La hauteur du volume rouge de la zone : plus que les collines de la ville.
local ZONE_HEIGHT = 60

-- Demarre a part : le Ventre peut mettre un moment a arriver chez le client,
-- et rien d'autre ne doit l'attendre.
function VentreView.start()
	task.spawn(VentreView.run)
end

function VentreView.run()
	local player = Players.LocalPlayer
	local w = Config.world
	local root = workspace:WaitForChild(w.folder)
	local sky = root:WaitForChild(w.sky)
	local eye = sky:WaitForChild(w.eye) :: Model
	-- La vue passe SOUS les paupieres : fermees, elles boucheraient tout.
	local below = eye:GetPivot().Position.Y - EYE_REACH
	local lids = sky:FindFirstChild(w.lids)
	if lids then
		for _, part in lids:GetChildren() do
			if part:IsA("BasePart") then
				below = math.min(below, part.Position.Y - 12)
			end
		end
	end

	-- La zone du prochain Balayage, recue avec le signal.
	local zone: { x: number, z: number, size: number }? = nil
	local eyeState = Remotes:WaitForChild("EyeState") :: RemoteEvent
	eyeState.OnClientEvent:Connect(function(data: any)
		if data.phase == "warning" and typeof(data.zone) == "table" then
			zone = data.zone
		elseif data.phase == "idle" or data.phase == "night" or data.phase == "dawn" then
			zone = nil
		end
	end)

	local gui = Instance.new("ScreenGui")
	gui.Name = "SurvivorOeil"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 9
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local caption = Instance.new("TextLabel")
	caption.AnchorPoint = Vector2.new(0.5, 1)
	caption.Position = UDim2.new(0.5, 0, 1, -120)
	-- La hauteur suit le texte : a hauteur fixe, la fin etait coupee.
	caption.Size = UDim2.fromScale(0.8, 0)
	caption.AutomaticSize = Enum.AutomaticSize.Y
	caption.BackgroundTransparency = 1
	caption.Font = Typography.STORY
	caption.TextSize = 20
	caption.TextColor3 = Typography.KINDS.danger
	caption.TextStrokeTransparency = 0.6
	caption.TextWrapped = true
	caption.Parent = gui

	local watching = false
	local marks: { Highlight } = {}
	local square: Part? = nil
	-- Ce qu'on coupe le temps de regarder, pour le remettre ensuite : le flou de
	-- profondeur, les nuages (l'Oeil est AU-DESSUS : on ne voyait que leur
	-- dessus, vu en jeu) et la brume.
	local blurs: { DepthOfFieldEffect } = {}
	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	local hazeBefore = { density = 0, haze = 0 }

	local function stopWatching()
		if not watching then
			return
		end
		watching = false
		gui.Enabled = false
		local hud = player.PlayerGui:FindFirstChild("SurvivorHud")
		if hud and hud:IsA("ScreenGui") then
			hud.Enabled = true
		end
		RunService:UnbindFromRenderStep("SurvivorOeilVue")
		ContextActionService:UnbindAction("SurvivorQuitterOeil")
		for _, mark in marks do
			mark:Destroy()
		end
		table.clear(marks)
		if square then
			square:Destroy()
			square = nil
		end
		for _, effect in blurs do
			effect.Enabled = true
		end
		table.clear(blurs)
		if clouds then
			clouds.Enabled = true
		end
		if atmosphere then
			atmosphere.Density = hazeBefore.density
			atmosphere.Haze = hazeBefore.haze
		end
		local camera = workspace.CurrentCamera
		camera.CameraType = Enum.CameraType.Custom
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end

	local function startWatching()
		if watching then
			return
		end
		watching = true
		gui.Enabled = true
		-- Le sac et la reserve encombraient la vue : on les cache le temps de
		-- regarder (la radio et la legende restent).
		local hud = player.PlayerGui:FindFirstChild("SurvivorHud")
		if hud and hud:IsA("ScreenGui") then
			hud.Enabled = false
		end
		-- Les amis, vus a travers tout.
		for _, other in Players:GetPlayers() do
			if other ~= player and other.Character then
				local mark = Instance.new("Highlight")
				mark.FillColor = Color3.fromRGB(160, 230, 140)
				mark.FillTransparency = 0.3
				mark.OutlineColor = Color3.new(1, 1, 1)
				mark.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				mark.Parent = other.Character
				table.insert(marks, mark)
			end
		end
		if clouds then
			clouds.Enabled = false
		end
		-- Sans brume : a 550 studs, meme legere, elle repeignait le sol couleur
		-- ciel (vu dans Studio).
		if atmosphere then
			hazeBefore = { density = atmosphere.Density, haze = atmosphere.Haze }
			atmosphere.Density = 0
			atmosphere.Haze = 0
		end
		-- Le flou de profondeur de la place noierait la ville, vue de si haut.
		for _, effect in Lighting:GetChildren() do
			if effect:IsA("DepthOfFieldEffect") and effect.Enabled then
				effect.Enabled = false
				table.insert(blurs, effect)
			end
		end
		local camera = workspace.CurrentCamera
		camera.CameraType = Enum.CameraType.Scriptable
		local looking = Vector3.zero
		RunService:BindToRenderStep(
			"SurvivorOeilVue",
			Enum.RenderPriority.Camera.Value + 1,
			function(dt: number)
				-- Ce qu'il regarde : le bout de son faisceau, sinon la zone du
				-- prochain Balayage, sinon le centre de la ville.
				local target = Vector3.zero
				local beam = workspace:FindFirstChild("Regard")
				if beam and beam:IsA("BasePart") then
					target = beam.Position + beam.CFrame.RightVector * (beam.Size.X / 2)
					caption.Text = "Il cherche. Dis-leur où il regarde."
				elseif zone then
					target = Vector3.new(zone.x, 0, zone.z)
					caption.Text = "Il va chercher là, en rouge. Préviens-les !"
				else
					caption.Text =
						"La ville, vue par l'Œil. Tes amis brillent en vert.   B : revenir"
				end
				-- La zone en rouge, au sol, pour celui qui regarde seulement.
				if zone and square == nil then
					local part = Instance.new("Part")
					part.Anchored = true
					part.CanCollide = false
					part.CanQuery = false
					part.CastShadow = false
					part.Material = Enum.Material.Neon
					part.Color = Color3.fromRGB(220, 40, 30)
					-- Un volume, pas un plan : a plat, les collines le percaient.
					part.Transparency = 0.82
					part.Size = Vector3.new(zone.size, ZONE_HEIGHT, zone.size)
					part.CFrame = CFrame.new(zone.x, ZONE_HEIGHT / 2 - 10, zone.z)
					part.Parent = workspace
					square = part
				elseif zone == nil and square then
					square:Destroy()
					square = nil
				end
				looking = looking:Lerp(target, math.clamp(dt * 3, 0, 1))
				-- Juste sous la pupille, pas au centre du globe (on y voyait l'iris
				-- de l'interieur, vu en jeu).
				local center = eye:GetPivot().Position
				local from = center + (looking - center).Unit * EYE_REACH
				from = Vector3.new(from.X, math.min(from.Y, below), from.Z)
				camera.CFrame = CFrame.lookAt(from, looking)
			end
		)
		local leave = Config.controls.contexts.watch.leave
		ContextActionService:BindActionAtPriority(
			"SurvivorQuitterOeil",
			function(_, state)
				if state == Enum.UserInputState.Begin then
					stopWatching()
				end
				return Enum.ContextActionResult.Sink
			end,
			false,
			Enum.ContextActionPriority.High.Value,
			(Enum.KeyCode :: any)[leave.gamepad],
			(Enum.KeyCode :: any)[leave.keyboard]
		)
	end

	local ventreRemote = Remotes:WaitForChild("Ventre") :: RemoteEvent
	ventreRemote.OnClientEvent:Connect(function(data: any)
		if typeof(data) == "table" and data.watch then
			startWatching()
		end
	end)
	-- Recrache (ou la partie recommence) : on ne regarde plus par l'Oeil.
	player.CharacterAdded:Connect(stopWatching)
	player:GetAttributeChangedSignal("Taken"):Connect(function()
		if player:GetAttribute("Taken") ~= true then
			stopWatching()
		end
	end)
end

return VentreView
