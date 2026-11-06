--!strict
--[[
	LootService — fouiller, porter, deposer.

	Chaque contenant de `Fouilles` recoit une invite « Fouiller » (maintenir X).
	Le butin va dans le sac du joueur ; le coffre de la Planque le vide dans la
	reserve commune. Le poids du sac ralentit : le serveur pose l'attribut
	`SpeedFactor` sur le joueur, le client l'applique a sa vitesse.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Survivor = ReplicatedStorage:WaitForChild("Survivor")
local Config = require(Survivor:WaitForChild("Config"))
local Crew = require(Survivor:WaitForChild("Crew"))
local Loot = require(Survivor:WaitForChild("Loot"))
local Remotes = Survivor:WaitForChild("Remotes")

local CombatService = require(script.Parent:WaitForChild("CombatService"))
local RemoteGuard = require(script.Parent:WaitForChild("RemoteGuard"))
local ReprisService = require(script.Parent:WaitForChild("ReprisService"))
local WorldService = require(script.Parent:WaitForChild("WorldService"))

local LootService = {}

local hud = Remotes:WaitForChild("Hud") :: RemoteEvent
local random = Random.new()

local bags: { [Player]: { string } } = {}
local stock: { [string]: number } = {}
-- Contenant -> deja fouille aujourd'hui.
local emptied: { [Instance]: boolean } = {}
-- Les objets de quete deja trouves dans cette partie : un seul exemplaire.
local questFound: { [string]: boolean } = {}

local function nextInt(lo: number, hi: number): number
	return random:NextInteger(lo, hi)
end

local function promptFor(
	parent: Instance,
	action: string,
	hold: number,
	distance: number
): ProximityPrompt
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

-- La part qui porte l'invite : la part elle-meme, ou la part principale d'un
-- modele (une invite doit vivre sous une part ou une attache pour s'afficher).
local function anchorPart(instance: Instance): BasePart?
	if instance:IsA("BasePart") then
		return instance
	end
	if instance:IsA("Model") then
		return instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

-- `kind` : la sorte de message, qui choisit son allure a l'ecran ("danger",
-- "quest", "day" ; rien pour une simple information).
function LootService.sendHud(player: Player, message: string?, kind: string?)
	local bag = bags[player] or {}
	local names: { string } = {}
	for _, itemId in bag do
		table.insert(names, Config.items[itemId].name)
	end
	hud:FireClient(player, {
		bag = names,
		items = bag,
		slots = Config.bag.slots,
		stock = stock,
		message = message,
		kind = kind,
	})
end

local function refreshSpeed(player: Player)
	local weight = Loot.bagWeight(bags[player] or {}, Config.items)
	player:SetAttribute("SpeedFactor", Loot.speedFactor(weight, Config.bag))
end

local function search(player: Player, container: Instance, prompt: ProximityPrompt)
	if emptied[container] then
		return
	end
	local bag = bags[player]
	if bag == nil then
		return
	end
	if #bag >= Config.bag.slots then
		LootService.sendHud(player, "Sac plein — dépose au coffre de la Planque")
		return
	end
	local tableId = container:GetAttribute("Table") :: string
	-- Un contenant de quete donne d'abord son objet, une fois par partie ;
	-- ensuite c'est un contenant comme les autres.
	local questItem = container:GetAttribute(Config.world.questAttribute)
	local found = if typeof(questItem) == "string" and not questFound[questItem]
		then { questItem }
		else Loot.roll(Config.loot.tables[tableId], nextInt)
	if typeof(questItem) == "string" then
		questFound[questItem] = true
	end
	local taken: { string } = {}
	for _, itemId in found do
		if #bag >= Config.bag.slots then
			break
		end
		table.insert(bag, itemId)
		table.insert(taken, Config.items[itemId].name)
	end
	emptied[container] = true
	prompt.Enabled = false
	-- Fouiller fait du bruit : ceux qui dorment dans la maison l'entendent.
	local part = anchorPart(container)
	if part then
		ReprisService.noise(part.Position, "search")
	end
	refreshSpeed(player)
	LootService.sendHud(player, "Trouvé : " .. table.concat(taken, ", "))
end

local function deposit(player: Player)
	local bag = bags[player]
	if bag == nil or #bag == 0 then
		LootService.sendHud(player, "Rien à déposer")
		return
	end
	-- Ce qu'il faut porter soi-meme (l'antenne) reste dans le sac : la
	-- reserve ne rend rien.
	local kept: { string } = {}
	for _, itemId in bag do
		if (Config.items[itemId] :: any).keep then
			table.insert(kept, itemId)
		else
			stock[itemId] = (stock[itemId] or 0) + 1
		end
	end
	bags[player] = kept
	refreshSpeed(player)
	for _, other in Players:GetPlayers() do
		LootService.sendHud(other, if other == player then "Déposé dans la réserve" else nil)
	end
end

-- Fouiller un contenant par son nom. Meme raison que HidingService.tryEnter :
-- les sondes de test ne peuvent pas declencher une invite.
function LootService.trySearch(player: Player, containerName: string): number
	local world = WorldService.get()
	local container = world.containers:FindFirstChild(containerName)
	local part = container and anchorPart(container)
	local prompt = part and part:FindFirstChildWhichIsA("ProximityPrompt")
	if container == nil or prompt == nil then
		return -1
	end
	search(player, container, prompt)
	return #(bags[player] or {})
end

function LootService.tryDeposit(player: Player)
	deposit(player)
end

-- La reserve commune : la Planque y prend ce qu'elle construit et ce qu'on
-- mange. Rendue telle quelle (pas une copie) : la Planque la modifie.
function LootService.stock(): { [string]: number }
	return stock
end

-- Apres un changement de la reserve, tout le monde voit les nouveaux chiffres.
function LootService.broadcast(message: string?, kind: string?)
	for _, player in Players:GetPlayers() do
		LootService.sendHud(player, message, kind)
	end
end

-- Manger ou se soigner avec un objet du sac (Y). Rend le message a afficher.
local function useItem(player: Player, index: number)
	local bag = bags[player]
	if
		bag == nil
		or bag[index] == nil
		or player:GetAttribute("Taken")
		or player:GetAttribute("Bound")
		or CombatService.isDowned(player)
	then
		return
	end
	local item = Config.items[bag[index]]
	local food = (item :: any).food
	local heal = (item :: any).heal
	if food == nil and heal == nil then
		LootService.sendHud(player, item.name .. " : à déposer au coffre")
		return
	end
	table.remove(bag, index)
	if food then
		local hunger = player:GetAttribute("Hunger")
		local current = if typeof(hunger) == "number" then hunger else Config.needs.hungerMax
		player:SetAttribute("Hunger", math.min(current + food, Config.needs.hungerMax))
	end
	if heal then
		CombatService.heal(player, heal)
	end
	refreshSpeed(player)
	LootService.sendHud(
		player,
		if food then item.name .. " : mangé" else item.name .. " : utilisé"
	)
end

-- Un joueur aspire perd ce qu'il portait (decide).
-- Pour la quete : ce joueur porte-t-il cet objet ? Et le lui prendre.
function LootService.hasItem(player: Player, itemId: string): boolean
	return table.find(bags[player] or {}, itemId) ~= nil
end

function LootService.takeItem(player: Player, itemId: string): boolean
	local bag = bags[player]
	local index = bag and table.find(bag, itemId)
	if bag == nil or index == nil then
		return false
	end
	table.remove(bag, index)
	refreshSpeed(player)
	LootService.sendHud(player)
	return true
end

function LootService.clearBag(player: Player)
	if bags[player] then
		bags[player] = {}
		refreshSpeed(player)
		LootService.sendHud(player)
	end
end

-- LES EPAVES : la nuit, l'Oeil recrache ce qu'il a avale. Des caisses
-- lumineuses tombent du ciel, loin de la Planque ; on les fouille comme le
-- reste (table `epave`), et elles disparaissent a l'aube.
local wrecks: { Model } = {}

function LootService.clearWrecks()
	for _, wreck in wrecks do
		emptied[wreck] = nil
		wreck:Destroy()
	end
	table.clear(wrecks)
end

local function dropWreck(at: Vector3)
	local w = Config.loot.wrecks
	local m = Instance.new("Model")
	m.Name = "Epave"
	m:SetAttribute("Table", "epave")
	local box = Instance.new("Part")
	box.Name = "Caisse"
	box.Size = Vector3.new(4.5, 3, 3.5)
	box.Material = Enum.Material.CorrodedMetal
	box.Color = Color3.fromRGB(70, 64, 58)
	box.Anchored = true
	box.Parent = m
	-- Des fentes qui brulent encore : on la voit de loin, la nuit.
	for _, side in { -1, 1 } do
		local seam = Instance.new("Part")
		seam.Name = "Fente"
		seam.Size = Vector3.new(4.6, 0.25, 0.2)
		seam.Material = Enum.Material.Neon
		seam.Color = Color3.fromRGB(255, 120, 50)
		seam.Anchored = true
		seam.CanCollide = false
		seam.CFrame = CFrame.new(0, 0.4 * side, 1.76 * side)
		seam.Parent = m
	end
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 120, 60)
	light.Range = 18
	light.Brightness = 1.6
	light.Parent = box
	m.PrimaryPart = box
	local spin =
		CFrame.Angles(0, random:NextNumber(0, math.pi * 2), math.rad(random:NextNumber(-8, 8)))
	m:PivotTo(CFrame.new(at + Vector3.new(0, w.fallHeight, 0)) * spin)
	m.Parent = workspace
	table.insert(wrecks, m)
	-- La chute : de plus en plus vite, en tournant, puis un nuage de poussiere.
	local start = os.clock()
	local fall: RBXScriptConnection? = nil
	fall = RunService.Heartbeat:Connect(function()
		local t = math.clamp((os.clock() - start) / w.fallSeconds, 0, 1)
		if m.Parent then
			local height = w.fallHeight * (1 - t * t) + 1.5
			m:PivotTo(
				CFrame.new(at + Vector3.new(0, height, 0)) * CFrame.Angles(0, t * 6, 0) * spin
			)
		end
		if t >= 1 and fall then
			fall:Disconnect()
			local dust = Instance.new("Smoke")
			dust.Color = Color3.fromRGB(120, 110, 100)
			dust.Size = 8
			dust.Opacity = 0.4
			dust.RiseVelocity = 4
			dust.Parent = box
			task.delay(1.5, function()
				dust.Enabled = false
			end)
			local prompt =
				promptFor(box, "Fouiller", Config.loot.searchSeconds, Config.loot.promptDistance)
			prompt.ObjectText = "Épave"
			prompt.Triggered:Connect(function(player: Player)
				search(player, m, prompt)
			end)
		end
	end)
end

-- Appele a la tombee de la nuit : autant d'epaves que ce qu'il a avale.
function LootService.spawnWrecks(swallowed: number)
	local world = WorldService.get()
	local w = Config.loot.wrecks
	local points: { Crew.Point } = {}
	local spots: { Vector3 } = {}
	for _, anchor in world.anchors:GetChildren() do
		if anchor:IsA("BasePart") then
			table.insert(points, { x = anchor.Position.X, z = anchor.Position.Z })
			table.insert(spots, Vector3.new(anchor.Position.X, 0, anchor.Position.Z))
		end
	end
	local planque = { x = world.spawn.Position.X, z = world.spawn.Position.Z }
	local count = Loot.wreckCount(w, swallowed)
	-- A cote d'un emplacement, jamais dedans (une epave tombait dans un
	-- buisson, vu en jeu) : un pas de cote, et un rayon qui doit trouver le sol
	-- ou une rue, pas un toit ni une cachette.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances =
		{ workspace.Terrain, world.root:FindFirstChild("Rues") :: Instance }
	local function landing(): Vector3?
		for _ = 1, 8 do
			local index = Crew.pickLanding(points, planque, w.minPlanqueDistance, nextInt)
			if index == nil then
				return nil
			end
			local a = random:NextNumber(0, math.pi * 2)
			local step = random:NextNumber(w.sideStep, w.sideStep * 1.6)
			local at = spots[index] + Vector3.new(math.cos(a) * step, 0, math.sin(a) * step)
			local down = workspace:Raycast(at + Vector3.new(0, 200, 0), Vector3.new(0, -260, 0))
			local onGround = down
				and workspace:Raycast(at + Vector3.new(0, 200, 0), Vector3.new(0, -260, 0), params)
			if down and onGround and down.Instance == onGround.Instance then
				return Vector3.new(at.X, down.Position.Y, at.Z)
			end
		end
		return nil
	end
	for _ = 1, count do
		local at = landing()
		if at then
			dropWreck(at)
		end
	end
	if count > 0 then
		LootService.broadcast(
			"Il recrache ce qu'il a avalé : des épaves brûlantes tombent sur la ville.",
			"quest"
		)
	end
end

-- Le matin, une partie des contenants se remplit de nouveau.
function LootService.newDay()
	LootService.clearWrecks()
	for container in emptied do
		if random:NextNumber() < Config.loot.restockChance then
			emptied[container] = nil
			local part = anchorPart(container)
			local prompt = part and part:FindFirstChildWhichIsA("ProximityPrompt")
			if prompt then
				prompt.Enabled = true
			end
		end
	end
end

-- Une defaite remet tout a zero : la partie recommence depuis le debut.
function LootService.reset()
	LootService.clearWrecks()
	table.clear(stock)
	table.clear(questFound)
	for container in emptied do
		local part = anchorPart(container)
		local prompt = part and part:FindFirstChildWhichIsA("ProximityPrompt")
		if prompt then
			prompt.Enabled = true
		end
	end
	table.clear(emptied)
	for player in bags do
		bags[player] = {}
		refreshSpeed(player)
		LootService.sendHud(player)
	end
end

function LootService.start()
	local world = WorldService.get()

	for _, container in world.containers:GetChildren() do
		local part = anchorPart(container)
		if part == nil then
			warn("[Survivor] Fouille sans part : " .. container:GetFullName())
			continue
		end
		local prompt =
			promptFor(part, "Fouiller", Config.loot.searchSeconds, Config.loot.promptDistance)
		prompt.ObjectText = container.Name
		prompt.Triggered:Connect(function(player: Player)
			search(player, container, prompt)
		end)
	end

	local bagRemote = Remotes:WaitForChild("Bag") :: RemoteEvent
	bagRemote.OnServerEvent:Connect(RemoteGuard.wrap("Bag", function(player: Player, request: any)
		if typeof(request) == "table" and typeof(request.use) == "number" then
			useItem(player, math.floor(request.use))
		end
	end))

	local chestPrompt = promptFor(world.chest, "Déposer", 0, Config.loot.promptDistance)
	chestPrompt.ObjectText = "Coffre"
	chestPrompt.Triggered:Connect(deposit)

	local function join(player: Player)
		bags[player] = {}
		refreshSpeed(player)
		LootService.sendHud(player)
	end
	Players.PlayerAdded:Connect(join)
	for _, player in Players:GetPlayers() do
		join(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		bags[player] = nil
	end)
end

return LootService
