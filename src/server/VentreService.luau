--!strict
--[[
	VentreService — le Ventre de l'Oeil, ou attendent ceux qu'il a aspires
	(decide avec Josh : un endroit a part, avec un role, pour ne pas
	s'ennuyer).

	- Les souvenirs : on les lit (X maintenu), ils s'ajoutent au journal et
	  s'affichent a l'ecran de celui qui lit.
	- L'Oculus : on y regarde la ville par l'Oeil (VentreView, cote client),
	  pour prevenir ses amis a la voix de la prochaine zone balayee.

	L'aspire y arrive par CrewService, et en repart la nuit.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Survivor = ReplicatedStorage:WaitForChild("Survivor")
local Config = require(Survivor:WaitForChild("Config"))
local Memories = require(Survivor:WaitForChild("Memories"))

local LootService = require(script.Parent:WaitForChild("LootService"))
local QuestService = require(script.Parent:WaitForChild("QuestService"))
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
	local oculus = promptFor(world.oculus, "Regarder par l'Œil", 0, e.oculusPromptDistance)
	oculus.ObjectText = "Oculus"
	oculus.Triggered:Connect(VentreService.tryWatch)
end

return VentreService
