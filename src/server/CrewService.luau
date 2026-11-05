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
local TweenService = game:GetService("TweenService")

local Survivor = ReplicatedStorage:WaitForChild("Survivor")
local Config = require(Survivor:WaitForChild("Config"))
local Crew = require(Survivor:WaitForChild("Crew"))

local HidingService = require(script.Parent:WaitForChild("HidingService"))
local LootService = require(script.Parent:WaitForChild("LootService"))
local WorldService = require(script.Parent:WaitForChild("WorldService"))

local CrewService = {}

local random = Random.new()
local wipeListeners: { () -> () } = {}

local function standingMap(): { [Player]: boolean }
	local out: { [Player]: boolean } = {}
	for _, player in Players:GetPlayers() do
		out[player] = not player:GetAttribute("Taken")
	end
	return out
end

function CrewService.onWipe(listener: () -> ())
	table.insert(wipeListeners, listener)
end

function CrewService.isTaken(player: Player): boolean
	return player:GetAttribute("Taken") == true
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
		local info = TweenInfo.new(
			Config.eye.takenLiftSeconds,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.In
		)
		TweenService:Create(root, info, {
			CFrame = root.CFrame + Vector3.new(0, Config.eye.takenLiftHeight, 0),
		}):Play()
		task.delay(Config.eye.takenLiftSeconds, function()
			if player.Character == character and character then
				character:Destroy()
			end
		end)
	end

	if Crew.isWiped(standingMap()) then
		for _, listener in wipeListeners do
			task.spawn(listener)
		end
	end
end

local function placeAt(player: Player, cframe: CFrame)
	player:LoadCharacter()
	local character = player.Character
	if character then
		character:PivotTo(cframe + Vector3.new(0, 3, 0))
	end
end

-- Le matin, les aspires reviennent quelque part dans la ville.
function CrewService.returnTaken()
	local world = WorldService.get()
	local anchors = world.anchors:GetChildren()
	for _, player in Players:GetPlayers() do
		if CrewService.isTaken(player) then
			player:SetAttribute("Taken", false)
			local anchor = anchors[random:NextInteger(1, math.max(#anchors, 1))]
			if anchor and anchor:IsA("BasePart") then
				placeAt(player, anchor.CFrame)
			else
				placeAt(player, world.spawn.CFrame)
			end
		end
	end
end

-- La nuit (pas encore construite) et une defaite ramenent tout le monde a la
-- Planque.
function CrewService.gatherAtPlanque()
	local world = WorldService.get()
	HidingService.releaseAll()
	for _, player in Players:GetPlayers() do
		player:SetAttribute("Taken", false)
		player:SetAttribute("Exposure", 0)
		placeAt(player, world.spawn.CFrame)
	end
end

function CrewService.start()
	local world = WorldService.get()
	Players.CharacterAutoLoads = false

	local function join(player: Player)
		player:SetAttribute("Taken", false)
		player:SetAttribute("Hidden", false)
		player:SetAttribute("Exposure", 0)
		-- Mort pour une autre raison (une chute) : on repart de la Planque.
		-- Branche AVANT le premier personnage, sinon sa mort passe inapercue.
		player.CharacterAdded:Connect(function(character: Model)
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
