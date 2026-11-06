--!strict
--[[
	VentreService — le Ventre de l'Oeil, ou attendent ceux qu'il a aspires
	(decide avec Josh : un endroit a part, avec un role, pour ne pas
	s'ennuyer).

	- Les souvenirs : on les lit (X maintenu), ils s'ajoutent au journal et
	  s'affichent a l'ecran de celui qui lit.
	- L'Oculus : on y regarde la ville par l'Oeil (VentreView, cote client),
	  pour prevenir ses amis a la voix de la prochaine zone balayee.
	- Le faire cligner : pendant un Balayage, frapper les piliers de chair
	  (R2). Assez de coups, et l'Oeil cligne de douleur (EyeService.flinch) :
	  une fois par Balayage, pour toute l'equipe (Config.eye.flinch).

	L'aspire y arrive par CrewService, et en repart la nuit.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Survivor = ReplicatedStorage:WaitForChild("Survivor")
local Config = require(Survivor:WaitForChild("Config"))
local Memories = require(Survivor:WaitForChild("Memories"))

local CrewService = require(script.Parent:WaitForChild("CrewService"))
local EyeService = require(script.Parent:WaitForChild("EyeService"))
local LootService = require(script.Parent:WaitForChild("LootService"))
local QuestService = require(script.Parent:WaitForChild("QuestService"))
local RemoteGuard = require(script.Parent:WaitForChild("RemoteGuard"))
local WorldService = require(script.Parent:WaitForChild("WorldService"))

local VentreService = {}

local remotes = Survivor:WaitForChild("Remotes")
local ventreRemote = remotes:WaitForChild("Ventre") :: RemoteEvent
local radio = remotes:WaitForChild("Radio") :: RemoteEvent

local function promptFor(parent: Instance, action: string, hold: number, distance: number)
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

local function read(player: Player, memory: Memories.Memory)
	local added = QuestService.addMemory(memory.id, memory.title, memory.lines)
	radio:FireClient(player, {
		lines = memory.lines,
		lineSeconds = Config.story.lineSeconds,
		tag = "· " .. memory.title .. " ·",
	})
	if added then
		LootService.sendHud(player, "Souvenir ajouté au journal", "quest")
	end
end

-- Par le meme chemin que les invites, pour les sondes.
function VentreService.tryRead(player: Player, id: number)
	for _, memory in Memories do
		if memory.id == id then
			read(player, memory)
		end
	end
end

-- LES COUPS : comptes pour le Balayage en cours seulement.
local hits = 0
local hitsSweep: number? = nil
local lastHit: { [Player]: number } = {}
local veins: { BasePart } = {}

-- La veine la plus proche du pilier frappe s'embrase un instant.
local function flash(near: Vector3)
	local best: BasePart? = nil
	local bestDistance = math.huge
	for _, vein in veins do
		local d = (vein.Position - near).Magnitude
		if d < bestDistance then
			best, bestDistance = vein, d
		end
	end
	if best then
		local color = best.Color
		best.Color = Color3.fromRGB(255, 236, 200)
		TweenService:Create(best, TweenInfo.new(0.4), { Color = color }):Play()
	end
end

local function tellTaken(message: string, kind: string)
	for _, other in Players:GetPlayers() do
		if CrewService.isTaken(other) then
			LootService.sendHud(other, message, kind)
		end
	end
end

-- Un coup de R2 dans le Ventre (par le meme chemin pour les sondes).
function VentreService.tryHit(player: Player): boolean
	local f = Config.eye.flinch
	if not CrewService.isTaken(player) then
		return false
	end
	local now = os.clock()
	if now - (lastHit[player] or 0) < Config.combat.meleeSeconds then
		return false
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return false
	end
	-- Un pilier de chair a portee ?
	local pillar: BasePart? = nil
	for _, part in workspace:GetPartBoundsInRadius(root.Position, f.hitRange) do
		if part.Name == "Paroi" and part:IsDescendantOf(WorldService.get().ventre) then
			pillar = part
			break
		end
	end
	if pillar == nil then
		return false
	end
	lastHit[player] = now
	flash(pillar.Position)
	local sweep = EyeService.sweepId()
	if sweep == nil then
		LootService.sendHud(player, "Il ne regarde pas : rien à blesser pour l'instant.")
		return true
	end
	if sweep ~= hitsSweep then
		hitsSweep, hits = sweep, 0
	end
	if hits >= f.hitsNeeded then
		LootService.sendHud(player, "Il a déjà cligné : attends le prochain Balayage.")
		return true
	end
	hits += 1
	if hits >= f.hitsNeeded then
		if EyeService.flinch() then
			LootService.broadcast("L'Œil cligne de douleur !", "quest")
		end
	else
		tellTaken(string.format("L'Œil frémit…  %d / %d", hits, f.hitsNeeded), "danger")
	end
	return true
end

function VentreService.tryWatch(player: Player)
	ventreRemote:FireClient(player, { watch = true })
end

function VentreService.start()
	local world = WorldService.get()
	local w = Config.world
	local e = Config.eye
	local byId: { [number]: Memories.Memory } = {}
	for _, memory in Memories do
		byId[memory.id] = memory
	end
	for _, part in world.ventre:GetDescendants() do
		local id = part:GetAttribute(w.memoryAttribute)
		local memory = if typeof(id) == "number" then byId[id] else nil
		if memory and part:IsA("BasePart") then
			local prompt = promptFor(part, "Lire", e.memoryHoldSeconds, Config.loot.promptDistance)
			prompt.ObjectText = memory.title
			prompt.Triggered:Connect(function(player: Player)
				read(player, memory)
			end)
		elseif typeof(id) == "number" then
			warn(string.format("[Survivor] Souvenir %d sans texte dans Memories", id))
		end
	end
	for _, part in world.ventre:GetDescendants() do
		if part:IsA("BasePart") and part.Name == "Veine" then
			table.insert(veins, part)
		end
	end
	-- R2 envoie deja le remote des coups : il sert aussi dans le Ventre.
	local attack = remotes:WaitForChild("Attack") :: RemoteEvent
	attack.OnServerEvent:Connect(RemoteGuard.wrap("AttackVentre", function(player: Player)
		VentreService.tryHit(player)
	end))
	local oculus = promptFor(world.oculus, "Regarder par l'Œil", 0, e.oculusPromptDistance)
	oculus.ObjectText = "Oculus"
	oculus.Triggered:Connect(VentreService.tryWatch)
end

return VentreService
