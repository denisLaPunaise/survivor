--!strict
--[[
	CrewService — qui est debout, qui a ete aspire, et la defaite.

	Un joueur aspire monte vers le ciel, perd son sac, et disparait jusqu'au
	matin. Il revient alors quelque part dans la ville (la nuit et les Repris
	n'existent pas encore : c'est la version courte de « revient la nuit
	suivante, a aller chercher »).

	Etat expose au client par attribut du joueur : `Taken` (booleen).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Survivor = ReplicatedStorage:WaitForChild("Survivor")
local Config = require(Survivor:WaitForChild("Config"))
local Crew = require(Survivor:WaitForChild("Crew"))

local CombatService = require(script.Parent:WaitForChild("CombatService"))
local HidingService = require(script.Parent:WaitForChild("HidingService"))
local LootService = require(script.Parent:WaitForChild("LootService"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))
local WorldService = require(script.Parent:WaitForChild("WorldService"))

local CrewService = {}

local random = Random.new()
local wipeListeners: { () -> () } = {}

local function standingMap(): { [Player]: boolean }
	local out: { [Player]: boolean } = {}
	for _, player in Players:GetPlayers() do
		-- Tombe, aspire ou attache dans un cocon : plus debout (decide avec Josh).
		out[player] = not player:GetAttribute("Taken")
			and not player:GetAttribute("Bound")
			and not CombatService.isDowned(player)
	end
	return out
end

function CrewService.onWipe(listener: () -> ())
	table.insert(wipeListeners, listener)
end

function CrewService.isTaken(player: Player): boolean
	return player:GetAttribute("Taken") == true
end

-- Recrache, attache dans un cocon en attendant ses amis.
function CrewService.isBound(player: Player): boolean
	return player:GetAttribute("Bound") == true
end

-- Les cocons en cours, par joueur.
local cocoons: { [Player]: Model } = {}

local function placeAt(player: Player, cframe: CFrame)
	player:LoadCharacter()
	local character = player.Character
	if character then
		character:PivotTo(cframe + Vector3.new(0, 3, 0))
	end
end

function CrewService.take(player: Player)
	if CrewService.isTaken(player) then
		return
	end
	player:SetAttribute("Taken", true)
	player:SetAttribute("Exposure", 0)
	HidingService.release(player)
	LootService.clearBag(player)

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.Anchored = true
		local e = Config.eye
		-- La colonne de lumiere, du sol jusqu'au ciel, qui s'eteint en montant.
		local column = Instance.new("Part")
		column.Name = "Aspiration"
		column.Shape = Enum.PartType.Cylinder
		column.Material = Enum.Material.Neon
		column.Color = Color3.fromRGB(255, 222, 196)
		column.Transparency = 0.45
		column.Anchored = true
		column.CanCollide = false
		column.CanQuery = false
		column.CastShadow = false
		local base = root.Position
		column.Size = Vector3.new(e.takenLiftHeight + 40, e.takenColumnWidth, e.takenColumnWidth)
		-- Un cylindre a sa longueur sur X : on le dresse.
		column.CFrame = CFrame.new(base + Vector3.new(0, e.takenLiftHeight / 2, 0))
			* CFrame.Angles(0, 0, math.rad(90))
		column.Parent = workspace
		Sfx.at("aspiration", base)
		TweenService:Create(column, TweenInfo.new(e.takenLiftSeconds + 0.6), { Transparency = 1 })
			:Play()
		task.delay(e.takenLiftSeconds + 0.7, function()
			column:Destroy()
		end)
		-- La montee : lente puis aspiree, en tournoyant.
		local start = os.clock()
		local spin: RBXScriptConnection? = nil
		spin = RunService.Heartbeat:Connect(function()
			local t = math.clamp((os.clock() - start) / e.takenLiftSeconds, 0, 1)
			if root.Parent then
				root.CFrame = CFrame.new(base + Vector3.new(0, e.takenLiftHeight * t * t, 0))
					* CFrame.Angles(0, t * e.takenSpinTurns * math.pi * 2, 0)
			end
			if t >= 1 and spin then
				spin:Disconnect()
			end
		end)
		-- La-haut : le Ventre de l'Oeil, jusqu'a la nuit.
		task.delay(e.takenLiftSeconds, function()
			if player.Parent and CrewService.isTaken(player) and player.Character == character then
				placeAt(player, WorldService.get().ventreSpawn.CFrame)
				-- Le Ventre est a 6 000 studs : sans ca, la ville ne serait plus
				-- chargee pour lui, et il ne verrait rien par l'Oeil (vu en jeu).
				player.ReplicationFocus = WorldService.get().bounds
				LootService.sendHud(
					player,
					"Le Ventre de l'Œil. Il te recrachera à la tombée de la nuit.",
					"danger"
				)
			end
		end)
	end

	CrewService.checkWipe()
end

function CrewService.checkWipe()
	if Crew.isWiped(standingMap()) then
		for _, listener in wipeListeners do
			task.spawn(listener)
		end
	end
end

-- A l'aube, celui que personne n'a releve se releve seul, affaibli.
function CrewService.dawn()
	for _, player in Players:GetPlayers() do
		if CombatService.isDowned(player) then
			CombatService.standUp(player, Config.combat.dawnHealth)
		end
	end
end

-- La nuit, chacun porte une petite lumiere : on voit ses amis, et un peu
-- devant soi. Pose sur le personnage, donc vue de tous.
local lampsOn = false
local function applyLamp(character: Model)
	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil then
		return
	end
	local lamp = root:FindFirstChild("Lampe")
	if lampsOn and lamp == nil then
		local light = Instance.new("PointLight")
		light.Name = "Lampe"
		light.Range = 18
		light.Brightness = 0.9
		light.Color = Color3.fromRGB(255, 220, 180)
		light.Parent = root
	elseif not lampsOn and lamp then
		lamp:Destroy()
	end
end

function CrewService.setLamps(on: boolean)
	lampsOn = on
	for _, player in Players:GetPlayers() do
		if player.Character then
			applyLamp(player.Character)
		end
	end
end

-- Detacher : le cocon s'ouvre, il repart.
local function free(player: Player)
	local cocoon = cocoons[player]
	cocoons[player] = nil
	if cocoon then
		cocoon:Destroy()
	end
	player:SetAttribute("Bound", false)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.Anchored = false
	end
end

-- Detacher un ami, par le meme chemin que l'invite (pour les sondes).
function CrewService.tryFree(friend: Player, player: Player): boolean
	if friend == player or not CrewService.isBound(player) then
		return false
	end
	if
		CrewService.isTaken(friend)
		or CrewService.isBound(friend)
		or CombatService.isDowned(friend)
	then
		return false
	end
	free(player)
	LootService.sendHud(player, friend.DisplayName .. " t'a détaché.", "quest")
	LootService.sendHud(friend, player.DisplayName .. " est libre.", "quest")
	return true
end

-- Le cocon : une chrysalide sombre, enlacee de veines qui brulent et battent
-- doucement, posee sur des racines dans une tache de terre brulee, et un fil
-- de lumiere qui monte au ciel, qu'on voit de loin. Ses amis le detachent en
-- maintenant X. (La premiere version, un cylindre et des batons rouges,
-- etait laide : vue en jeu le 6 novembre 2026.)
local function wrap(player: Player, at: Vector3)
	local e = Config.eye
	local m = Instance.new("Model")
	m.Name = "Cocon"
	local flesh = Color3.fromRGB(58, 20, 22)
	local burn = Color3.fromRGB(235, 70, 34)
	local function piece(
		name: string,
		size: Vector3,
		cf: CFrame,
		material: Enum.Material,
		color: Color3
	): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Material = material
		p.Color = color
		p.Anchored = true
		p.CanCollide = false
		p.CastShadow = false
		p.Parent = m
		return p
	end
	local function link(
		name: string,
		a: Vector3,
		b: Vector3,
		width: number,
		material: Enum.Material,
		color: Color3
	): Part
		return piece(
			name,
			Vector3.new(width, width, (b - a).Magnitude + width),
			CFrame.lookAt((a + b) / 2, b),
			material,
			color
		)
	end
	-- Un cylindre a sa longueur sur X : on le dresse ou on le couche.
	local upright = CFrame.Angles(0, 0, math.rad(90))

	-- La terre brulee, et les racines qui s'y enfoncent.
	piece(
		"TerreBrulee",
		Vector3.new(0.2, 12, 12),
		CFrame.new(at + Vector3.new(0, 0.1, 0)) * upright,
		Enum.Material.Slate,
		Color3.fromRGB(22, 12, 12)
	).Shape =
		Enum.PartType.Cylinder
	local veins: { Part } = {}
	for k = 1, 7 do
		local a = k / 7 * math.pi * 2 + random:NextNumber(-0.2, 0.2)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local from = at + dir * 1.6 + Vector3.new(0, 1.2, 0)
		local to = at + dir * random:NextNumber(4.5, 6.5) + Vector3.new(0, 0.15, 0)
		link("Racine", from, to, 0.7, Enum.Material.Slate, flesh)
		table.insert(
			veins,
			link(
				"VeineRacine",
				from + Vector3.new(0, 0.38, 0),
				to + Vector3.new(0, 0.3, 0),
				0.18,
				Enum.Material.Neon,
				burn
			)
		)
	end

	-- La chrysalide : un oeuf de quatre boules qui se chevauchent.
	local profile = { { 1.9, 4.4 }, { 3.2, 5.4 }, { 4.6, 5 }, { 5.9, 3.6 } }
	local core: Part? = nil
	for i, layer in profile do
		local ball = piece(
			"Chrysalide",
			Vector3.new(layer[2], layer[2], layer[2]),
			CFrame.new(at + Vector3.new(0, layer[1], 0)),
			Enum.Material.Slate,
			flesh:Lerp(Color3.fromRGB(30, 10, 12), i / #profile)
		)
		ball.Shape = Enum.PartType.Ball
		if i == 2 then
			core = ball
		end
	end
	-- Les veines qui l'enlacent : quatre spirales, posees sur la peau de l'oeuf.
	local function radiusAt(h: number): number
		local u = (h - 3.7) / 3.3
		return 2.75 * math.sqrt(math.max(1 - u * u, 0.04)) + 0.06
	end
	for k = 1, 4 do
		local previous: Vector3? = nil
		for step = 0, 9 do
			local h = 0.9 + step * 0.62
			local angle = k * math.pi / 2 + h * 0.95
			local r = radiusAt(h)
			local point = at + Vector3.new(math.cos(angle) * r, h, math.sin(angle) * r)
			if previous then
				table.insert(veins, link("Veine", previous, point, 0.22, Enum.Material.Neon, burn))
			end
			previous = point
		end
	end
	-- Elles battent doucement, comme un coeur.
	for _, vein in veins do
		TweenService:Create(
			vein,
			TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Transparency = 0.55 }
		):Play()
	end

	-- Le fil de lumiere, du haut du cocon jusqu'au ciel.
	local tether = piece(
		"Signal",
		Vector3.new(e.cocoonBeamHeight, 0.5, 0.5),
		CFrame.new(at + Vector3.new(0, 7 + e.cocoonBeamHeight / 2, 0)) * upright,
		Enum.Material.Neon,
		Color3.fromRGB(255, 110, 70)
	)
	tether.Shape = Enum.PartType.Cylinder
	tether.Transparency = 0.45
	tether.CanQuery = false

	local holder = core :: Part
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 80, 50)
	-- Assez pour le reperer la nuit, pas au point de tout repeindre en rouge
	-- (vu en jeu a 2).
	light.Range = 16
	light.Brightness = 0.8
	light.Parent = holder
	local onFoot = Config.controls.contexts.onFoot
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Détacher"
	prompt.ObjectText = player.DisplayName
	prompt.HoldDuration = e.freeHoldSeconds
	prompt.MaxActivationDistance = Config.loot.promptDistance
	prompt.RequiresLineOfSight = false
	prompt.GamepadKeyCode = (Enum.KeyCode :: any)[onFoot.interact.gamepad]
	prompt.KeyboardKeyCode = (Enum.KeyCode :: any)[onFoot.interact.keyboard]
	prompt.Parent = holder
	prompt.Triggered:Connect(function(friend: Player)
		CrewService.tryFree(friend, player)
	end)
	m.Parent = workspace
	cocoons[player] = m
end

-- A la tombee de la nuit, avec les Repris : l'Oeil recrache ceux qu'il a
-- pris. Ils tombent du ciel dans une colonne de lumiere, loin de la Planque,
-- et restent attaches jusqu'a ce qu'un ami vienne (decide avec Josh).
function CrewService.releaseTaken()
	local world = WorldService.get()
	local e = Config.eye
	local planque = world.spawn.Position
	for _, player in Players:GetPlayers() do
		if not CrewService.isTaken(player) then
			continue
		end
		-- Loin de la Planque, sur une place libre (comme les epaves).
		local at = LootService.landingSpot(e.releaseMinPlanqueDistance)
			or Vector3.new(planque.X, 0, planque.Z)
		player:SetAttribute("Taken", false)
		player:SetAttribute("Bound", true)
		player.ReplicationFocus = nil
		placeAt(player, CFrame.new(at + Vector3.new(0, e.releaseFallHeight, 0)))
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			root.Anchored = true
			-- La chute : lente puis acceleree, en tournoyant.
			local start = os.clock()
			local fall: RBXScriptConnection? = nil
			fall = RunService.Heartbeat:Connect(function()
				local t = math.clamp((os.clock() - start) / e.releaseFallSeconds, 0, 1)
				local height = e.releaseFallHeight * (1 - t * t) + 3
				if root.Parent then
					root.CFrame = CFrame.new(at + Vector3.new(0, height, 0))
						* CFrame.Angles(0, (1 - t) * e.takenSpinTurns * math.pi * 2, 0)
				end
				if t >= 1 and fall then
					fall:Disconnect()
				end
			end)
		end
		task.delay(e.releaseFallSeconds, function()
			if CrewService.isBound(player) then
				wrap(player, at)
			end
		end)
		LootService.sendHud(
			player,
			"Il t'a recraché. Tu es attaché : tes amis doivent venir te chercher.",
			"danger"
		)
		for _, other in Players:GetPlayers() do
			if other ~= player then
				LootService.sendHud(
					other,
					player.DisplayName .. " est retombé, pris dans un cocon. Allez le détacher !",
					"quest"
				)
			end
		end
	end
	CrewService.checkWipe()
end

-- La nuit (pas encore construite) et une defaite ramenent tout le monde a la
-- Planque.
function CrewService.gatherAtPlanque()
	local world = WorldService.get()
	HidingService.releaseAll()
	for _, player in Players:GetPlayers() do
		player:SetAttribute("Taken", false)
		player:SetAttribute("Exposure", 0)
		if cocoons[player] or CrewService.isBound(player) then
			free(player)
		end
		player.ReplicationFocus = nil
		CombatService.reset(player)
		placeAt(player, world.spawn.CFrame)
	end
end

function CrewService.start()
	local world = WorldService.get()
	CombatService.onDowned(function()
		CrewService.checkWipe()
	end)
	Players.CharacterAutoLoads = false

	local function join(player: Player)
		player:SetAttribute("Taken", false)
		player:SetAttribute("Bound", false)
		player:SetAttribute("Hidden", false)
		player:SetAttribute("Exposure", 0)
		-- Mort pour une autre raison (une chute) : on repart de la Planque.
		-- Branche AVANT le premier personnage, sinon sa mort passe inapercue.
		player.CharacterAdded:Connect(function(character: Model)
			task.defer(applyLamp, character)
			local humanoid = character:WaitForChild("Humanoid") :: Humanoid
			humanoid.Died:Connect(function()
				task.wait(2)
				if
					player.Parent
					and player.Character == character
					and not CrewService.isTaken(player)
				then
					placeAt(player, world.spawn.CFrame)
				end
			end)
		end)
		placeAt(player, world.spawn.CFrame)
	end
	Players.PlayerAdded:Connect(join)
	for _, player in Players:GetPlayers() do
		task.spawn(join, player)
	end
end

return CrewService
