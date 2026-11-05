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

local Survivor = ReplicatedStorage:WaitForChild("Survivor")
local Config = require(Survivor:WaitForChild("Config"))
local Loot = require(Survivor:WaitForChild("Loot"))
local Remotes = Survivor:WaitForChild("Remotes")

local ReprisService = require(script.Parent:WaitForChild("ReprisService"))
local WorldService = require(script.Parent:WaitForChild("WorldService"))

local LootService = {}

local hud = Remotes:WaitForChild("Hud") :: RemoteEvent
local random = Random.new()

local bags: { [Player]: { string } } = {}
local stock: { [string]: number } = {}
-- Contenant -> deja fouille aujourd'hui.
local emptied: { [Instance]: boolean } = {}

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

function LootService.sendHud(player: Player, message: string?)
	local bag = bags[player] or {}
	local names: { string } = {}
	for _, itemId in bag do
		table.insert(names, Config.items[itemId].name)
	end
	hud:FireClient(player, {
		bag = names,
		slots = Config.bag.slots,
		stock = stock,
		message = message,
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
	local found = Loot.roll(Config.loot.tables[tableId], nextInt)
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
	for _, itemId in bag do
		stock[itemId] = (stock[itemId] or 0) + 1
	end
	bags[player] = {}
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
function LootService.broadcast(message: string?)
	for _, player in Players:GetPlayers() do
		LootService.sendHud(player, message)
	end
end

-- Un joueur aspire perd ce qu'il portait (decide).
function LootService.clearBag(player: Player)
	if bags[player] then
		bags[player] = {}
		refreshSpeed(player)
		LootService.sendHud(player)
	end
end

-- Le matin, une partie des contenants se remplit de nouveau.
function LootService.newDay()
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
	table.clear(stock)
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
