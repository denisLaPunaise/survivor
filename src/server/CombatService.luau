--!strict
--[[
	CombatService — frapper, etre frappe, tomber, relever.

	On ne meurt pas sous les coups : on TOMBE (concept). La sante du joueur est
	tenue ici, pas par l'Humanoid : un Humanoid mort ne se soigne pas, il se
	reconstruit (lecon d'Arena), et un joueur tombe doit pouvoir etre releve
	sur place. L'Humanoid garde toujours au moins 1 PV.

	Etat expose au client par attributs du joueur : `Health` (0 a
	Config.combat.playerHealth), `Downed` (booleen).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Survivor = ReplicatedStorage:WaitForChild("Survivor")
local Config = require(Survivor:WaitForChild("Config"))
local Repris = require(Survivor:WaitForChild("Repris"))
local Remotes = Survivor:WaitForChild("Remotes")

local RemoteGuard = require(script.Parent:WaitForChild("RemoteGuard"))

local CombatService = {}

export type Target = {
	root: BasePart,
	-- `from` : qui frappe (nil : un piege).
	hit: (damage: number, from: Player?) -> (),
}

-- Ce que les joueurs peuvent frapper : les Repris s'y inscrivent.
local targets: { [BasePart]: Target } = {}
local lastSwing: { [Player]: number } = {}
local downListeners: { (Player) -> () } = {}
local revivePrompts: { [Player]: ProximityPrompt } = {}

function CombatService.registerTarget(target: Target)
	targets[target.root] = target
end

function CombatService.unregisterTarget(root: BasePart)
	targets[root] = nil
end

-- Un piege : chaque cible a cette distance prend le coup. Rend combien.
function CombatService.hurtNear(position: Vector3, radius: number, damage: number): number
	local hurt = 0
	for root, target in targets do
		if root.Parent and (root.Position - position).Magnitude <= radius then
			hurt += 1
			task.spawn(target.hit, damage, nil)
		end
	end
	return hurt
end

function CombatService.onDowned(listener: (Player) -> ())
	table.insert(downListeners, listener)
end

function CombatService.isDowned(player: Player): boolean
	return player:GetAttribute("Downed") == true
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function setHealth(player: Player, health: number)
	player:SetAttribute("Health", health)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		-- L'Humanoid suit, sans jamais tomber a zero (il mourrait pour de bon).
		humanoid.MaxHealth = Config.combat.playerHealth
		humanoid.Health = math.max(health, 1)
	end
end

local function clearRevive(player: Player)
	local prompt = revivePrompts[player]
	if prompt then
		prompt:Destroy()
		revivePrompts[player] = nil
	end
end

function CombatService.standUp(player: Player, health: number)
	clearRevive(player)
	player:SetAttribute("Downed", false)
	setHealth(player, health)
end

local function fall(player: Player)
	player:SetAttribute("Downed", true)
	setHealth(player, 0)
	-- Un ami le releve en maintenant X pres de lui.
	local root = rootOf(player)
	if root then
		local onFoot = Config.controls.contexts.onFoot
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Relever"
		prompt.ObjectText = player.DisplayName
		prompt.HoldDuration = Config.combat.reviveSeconds
		prompt.MaxActivationDistance = Config.combat.reviveDistance
		prompt.RequiresLineOfSight = false
		prompt.GamepadKeyCode = (Enum.KeyCode :: any)[onFoot.interact.gamepad]
		prompt.KeyboardKeyCode = (Enum.KeyCode :: any)[onFoot.interact.keyboard]
		prompt.Parent = root
		revivePrompts[player] = prompt
		prompt.Triggered:Connect(function(helper: Player)
			-- On ne se releve pas soi-meme, et un ami a terre ne releve personne.
			if helper ~= player and not CombatService.isDowned(helper) then
				CombatService.standUp(player, Config.combat.reviveHealth)
			end
		end)
	end
	for _, listener in downListeners do
		task.spawn(listener, player)
	end
end

-- Un Repris frappe un joueur.
function CombatService.damagePlayer(player: Player, damage: number)
	if
		CombatService.isDowned(player)
		or player:GetAttribute("Taken")
		or player:GetAttribute("Bound")
	then
		return
	end
	local health = player:GetAttribute("Health")
	local current = if typeof(health) == "number" then health else Config.combat.playerHealth
	local after, down = Repris.hit(current, damage)
	if down then
		fall(player)
	else
		setHealth(player, after)
	end
end

-- Le joueur frappe devant lui. Le serveur verifie la cadence, la portee et
-- l'angle : le client ne dit que « je frappe ».
local function swing(player: Player)
	local c = Config.combat
	local now = os.clock()
	if now - (lastSwing[player] or 0) < c.meleeSeconds then
		return
	end
	if
		CombatService.isDowned(player)
		or player:GetAttribute("Hidden")
		or player:GetAttribute("Taken")
		or player:GetAttribute("Bound")
	then
		return
	end
	local root = rootOf(player)
	if root == nil then
		return
	end
	lastSwing[player] = now
	local camera = player.Character and player.Character:FindFirstChild("Head")
	local look = if camera and camera:IsA("BasePart")
		then camera.CFrame.LookVector
		else root.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flatLook.Magnitude < 0.01 then
		return
	end
	flatLook = flatLook.Unit
	local best: Target? = nil
	local bestDistance = math.huge
	for targetRoot, target in targets do
		local offset = targetRoot.Position - root.Position
		local flat = Vector3.new(offset.X, 0, offset.Z)
		local distance = flat.Magnitude
		if distance <= c.meleeRange and distance < bestDistance then
			if distance < 1 or flat.Unit:Dot(flatLook) >= c.meleeCone then
				best = target
				bestDistance = distance
			end
		end
	end
	if best then
		best.hit(c.meleeDamage, player)
	end
end

-- Soigner (repas chaud, lits) : jamais au-dela du maximum, jamais un joueur
-- a terre (il doit etre releve).
function CombatService.heal(player: Player, amount: number)
	if CombatService.isDowned(player) then
		return
	end
	local health = player:GetAttribute("Health")
	local current = if typeof(health) == "number" then health else Config.combat.playerHealth
	setHealth(player, math.min(current + amount, Config.combat.playerHealth))
end

function CombatService.reset(player: Player)
	clearRevive(player)
	player:SetAttribute("Downed", false)
	setHealth(player, Config.combat.playerHealth)
end

function CombatService.start()
	local attack = Remotes:WaitForChild("Attack") :: RemoteEvent
	attack.OnServerEvent:Connect(RemoteGuard.wrap("Attack", function(player: Player)
		swing(player)
	end))

	local function join(player: Player)
		player:SetAttribute("Downed", false)
		player:SetAttribute("Health", Config.combat.playerHealth)
		player.CharacterAdded:Connect(function()
			-- Un nouveau personnage repart debout ; la sante, elle, suit ce que
			-- le jeu a decide (CrewService la remet quand il faut).
			task.defer(function()
				local health = player:GetAttribute("Health")
				setHealth(
					player,
					if typeof(health) == "number" and health > 0
						then health
						else Config.combat.playerHealth
				)
			end)
		end)
	end
	Players.PlayerAdded:Connect(join)
	for _, player in Players:GetPlayers() do
		join(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		clearRevive(player)
		lastSwing[player] = nil
	end)
end

return CombatService
