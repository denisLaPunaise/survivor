--!strict
--[[
	PlanqueService — la faim, le repas du soir, et ce qu'on construit a la
	Planque avec la reserve commune.

	La faim : attribut `Hunger` du joueur (0 a Config.needs.hungerMax). Elle
	baisse en continu ; le soir, ceux qui sont rentres mangent sur la reserve.
	Affame, on ralentit (attribut `HungerFactor`, lu par le client) ; vide, on
	perd de la sante jusqu'a tomber.

	La construction : l'etabli de la Planque ouvre un panneau (remote
	`Planque`). Chaque construction coute des objets de la reserve et apparait
	a son emplacement `Slot<id>`. La barricade a des points de vie : les Repris
	doivent la casser pour descendre.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Survivor = ReplicatedStorage:WaitForChild("Survivor")
local Config = require(Survivor:WaitForChild("Config"))
local Planque = require(Survivor:WaitForChild("Planque"))
local Remotes = Survivor:WaitForChild("Remotes")

local CombatService = require(script.Parent:WaitForChild("CombatService"))
local LootService = require(script.Parent:WaitForChild("LootService"))
local RemoteGuard = require(script.Parent:WaitForChild("RemoteGuard"))
local WorldService = require(script.Parent:WaitForChild("WorldService"))

local PlanqueService = {}

type Build = {
	id: string,
	name: string,
	description: string,
	cost: { [string]: number },
	health: number?,
	heal: number?,
	earlySeconds: number?,
}

local remote = Remotes:WaitForChild("Planque") :: RemoteEvent
local built: { [string]: Instance } = {}
local barricadeHealth = 0
local buildsById: { [string]: Build } = {}
for _, b in Config.planque.builds do
	buildsById[b.id] = b :: any
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

-- Est-il a la Planque ?
function PlanqueService.isHome(player: Player): boolean
	local root = rootOf(player)
	if root == nil then
		return false
	end
	return (root.Position - WorldService.get().spawn.Position).Magnitude <= Config.planque.radius
end

-- Ceux qui veulent savoir qu'une chose vient d'etre construite (la quete :
-- la radio reparee).
local builtListeners: { (id: string, model: Instance) -> () } = {}
function PlanqueService.whenBuilt(listener: (id: string, model: Instance) -> ())
	table.insert(builtListeners, listener)
end

function PlanqueService.has(id: string): boolean
	return built[id] ~= nil
end

function PlanqueService.build(id: string): Build?
	return buildsById[id]
end

local function slotFor(id: string): BasePart?
	local slot = WorldService.get().planque:FindFirstChild(Config.world.slotPrefix .. id, true)
	if slot and slot:IsA("BasePart") then
		return slot
	end
	return nil
end

-- Ce qu'on voit d'une construction : un objet simple a son emplacement. La
-- barricade est la seule qui compte physiquement : elle bouche l'escalier.
local function place(id: string): Instance?
	local slot = slotFor(id)
	if slot == nil then
		warn("[Survivor] Pas d'emplacement Slot" .. id .. " dans la Planque")
		return nil
	end
	local m = Instance.new("Model")
	m.Name = "Construction_" .. id
	local function part(
		name: string,
		size: Vector3,
		cf: CFrame,
		material: Enum.Material,
		color: Color3
	): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.CFrame = cf
		p.Material = material
		p.Color = color
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = m
		return p
	end
	local wood = Color3.fromRGB(112, 86, 62)
	local metal = Color3.fromRGB(88, 92, 94)
	if id == "barricade" then
		for i = -1, 1 do
			part(
				"Planche",
				Vector3.new(slot.Size.X, 1.6, 0.5),
				slot.CFrame * CFrame.new(0, i * 2.4, 0) * CFrame.Angles(0, 0, math.rad(i * 4)),
				Enum.Material.WoodPlanks,
				wood
			)
		end
		local block = part("Barricade", slot.Size, slot.CFrame, Enum.Material.WoodPlanks, wood)
		block.Transparency = 1
		barricadeHealth = buildsById.barricade.health :: number
	elseif id == "lit" then
		for i = 0, 1 do
			part(
				"Lit",
				Vector3.new(3, 1.2, 7),
				slot.CFrame * CFrame.new(i * 4, 0, 0),
				Enum.Material.Fabric,
				Color3.fromRGB(96, 100, 84)
			)
		end
	elseif id == "rechaud" then
		part("Rechaud", Vector3.new(2, 1.6, 2), slot.CFrame, Enum.Material.Metal, metal)
		local flame = part(
			"Flamme",
			Vector3.new(0.8, 0.6, 0.8),
			slot.CFrame * CFrame.new(0, 1.1, 0),
			Enum.Material.Neon,
			Color3.fromRGB(255, 150, 70)
		)
		flame.CanCollide = false
		local light = Instance.new("PointLight")
		light.Color = flame.Color
		light.Range = 14
		light.Brightness = 1.2
		light.Parent = flame
	elseif id == "periscope" then
		part(
			"Periscope",
			Vector3.new(0.8, 9, 0.8),
			slot.CFrame * CFrame.new(0, 4.5, 0),
			Enum.Material.Metal,
			metal
		)
		part(
			"Oculaire",
			Vector3.new(1.4, 1, 1.4),
			slot.CFrame * CFrame.new(0, 0.5, 0),
			Enum.Material.Metal,
			metal
		)
	elseif id == "radio" then
		part(
			"Radio",
			Vector3.new(2, 1.4, 1),
			slot.CFrame,
			Enum.Material.SmoothPlastic,
			Color3.fromRGB(70, 66, 58)
		)
		local glow = part(
			"Voyant",
			Vector3.new(0.3, 0.3, 0.1),
			slot.CFrame * CFrame.new(0.6, 0.3, -0.55),
			Enum.Material.Neon,
			Color3.fromRGB(120, 220, 120)
		)
		glow.CanCollide = false
	end
	m.Parent = WorldService.get().planque
	return m
end

local function panelState(): any
	local stock = LootService.stock()
	local list = {}
	for _, b in Config.planque.builds do
		table.insert(list, {
			id = b.id,
			name = b.name,
			description = b.description,
			cost = b.cost,
			built = built[b.id] ~= nil,
			affordable = Planque.canAfford(stock, b.cost),
		})
	end
	local repair = nil
	if built.barricade and barricadeHealth < (buildsById.barricade.health :: number) then
		repair = {
			cost = Config.planque.repairCost,
			health = barricadeHealth,
			max = buildsById.barricade.health,
			affordable = Planque.canAfford(stock, Config.planque.repairCost),
		}
	end
	return { builds = list, repair = repair }
end

local function nearBench(player: Player): boolean
	local root = rootOf(player)
	local bench = WorldService.get().planque:FindFirstChild(Config.world.workbench, true)
	if root == nil or bench == nil or not bench:IsA("BasePart") then
		return false
	end
	return (root.Position - bench.Position).Magnitude <= Config.planque.useDistance
end

local function onRequest(player: Player, request: any)
	if typeof(request) ~= "table" or not nearBench(player) then
		return
	end
	local stock = LootService.stock()
	if typeof(request.build) == "string" then
		local b = buildsById[request.build]
		if b and built[b.id] == nil and Planque.pay(stock, b.cost) then
			local m = place(b.id)
			if m then
				built[b.id] = m
				LootService.broadcast(b.name .. " : construit")
				for _, listener in builtListeners do
					task.spawn(listener, b.id, m)
				end
			end
		end
	elseif request.repair == true and built.barricade then
		if Planque.pay(stock, Config.planque.repairCost) then
			barricadeHealth = math.min(
				barricadeHealth + Config.planque.repairAmount,
				buildsById.barricade.health :: number
			)
			LootService.broadcast("Barricade réparée")
		end
	end
	remote:FireClient(player, { panel = panelState() })
end

-- Pour les Repris : la barricade intacte la plus proche de ce point, a cette
-- portee. Rend de quoi la frapper. Branche par le Bootstrap (les Repris ne
-- connaissent pas la Planque).
function PlanqueService.obstacleNear(position: Vector3, range: number): ((number) -> ())?
	local m = built.barricade
	local block = m and m:FindFirstChild("Barricade")
	if block == nil or not block:IsA("BasePart") or barricadeHealth <= 0 then
		return nil
	end
	if (block.Position - position).Magnitude > range + block.Size.X / 2 then
		return nil
	end
	return function(damage: number)
		barricadeHealth -= damage
		if barricadeHealth <= 0 then
			local broken = built.barricade
			built.barricade = nil
			if broken then
				broken:Destroy()
			end
			LootService.broadcast("La barricade a cédé !")
		end
	end
end

-- A la table de la Planque : manger sur la reserve commune (un plat du menu).
-- Remplace le repas automatique du soir, que Josh ne trouvait pas clair : on
-- mange ce qu'on porte (Y, le sac), ou ce qui est a la Planque, quand on veut.
local function eatAtTable(player: Player)
	if player:GetAttribute("Taken") or CombatService.isDowned(player) then
		return
	end
	local fed = Planque.serveMeal(LootService.stock(), Config.planque.menu, 1)
	if fed == 0 then
		LootService.sendHud(player, "Rien à manger dans la réserve")
		return
	end
	player:SetAttribute("Hunger", Config.needs.hungerMax)
	local heal = if built.rechaud then buildsById.rechaud.heal :: number else 0
	if heal > 0 then
		CombatService.heal(player, heal)
	end
	LootService.broadcast(
		if heal > 0 then "Un repas chaud. Ça fait du bien." else "Repas pris sur la réserve"
	)
end

-- L'aube : avec les lits, ceux qui ont dormi a la Planque repartent soignes.
function PlanqueService.dawn()
	if not built.lit then
		return
	end
	for _, player in Players:GetPlayers() do
		if PlanqueService.isHome(player) and not CombatService.isDowned(player) then
			CombatService.heal(player, Config.combat.playerHealth)
		end
	end
end

-- Une defaite : tout recommence, les constructions aussi.
function PlanqueService.reset()
	for id, m in built do
		m:Destroy()
		built[id] = nil
	end
	barricadeHealth = 0
	for _, player in Players:GetPlayers() do
		player:SetAttribute("Hunger", Config.needs.hungerMax)
	end
end

function PlanqueService.start()
	local planque = WorldService.get().planque
	local bench = planque:FindFirstChild(Config.world.workbench, true)
	if bench and bench:IsA("BasePart") then
		local onFoot = Config.controls.contexts.onFoot
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Construire"
		prompt.ObjectText = "Établi"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = Config.planque.useDistance
		prompt.RequiresLineOfSight = false
		prompt.GamepadKeyCode = (Enum.KeyCode :: any)[onFoot.interact.gamepad]
		prompt.KeyboardKeyCode = (Enum.KeyCode :: any)[onFoot.interact.keyboard]
		prompt.Parent = bench
		prompt.Triggered:Connect(function(player: Player)
			remote:FireClient(player, { open = true, panel = panelState() })
		end)
	else
		warn("[Survivor] Pas d'établi dans la Planque : la construction est fermée")
	end
	remote.OnServerEvent:Connect(RemoteGuard.wrap("Planque", onRequest))

	local tablePart = planque:FindFirstChild(Config.world.table, true)
	if tablePart and tablePart:IsA("BasePart") then
		local onFoot = Config.controls.contexts.onFoot
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Manger (réserve)"
		prompt.ObjectText = "Table"
		prompt.HoldDuration = 1
		prompt.MaxActivationDistance = Config.planque.useDistance
		prompt.RequiresLineOfSight = false
		prompt.GamepadKeyCode = (Enum.KeyCode :: any)[onFoot.interact.gamepad]
		prompt.KeyboardKeyCode = (Enum.KeyCode :: any)[onFoot.interact.keyboard]
		prompt.Parent = tablePart
		prompt.Triggered:Connect(eatAtTable)
	else
		warn("[Survivor] Pas de table dans la Planque : on ne peut manger que son sac")
	end

	local function join(player: Player)
		player:SetAttribute("Hunger", Config.needs.hungerMax)
		player:SetAttribute("HungerFactor", 1)
	end
	Players.PlayerAdded:Connect(join)
	for _, player in Players:GetPlayers() do
		join(player)
	end

	-- La faim, une fois par seconde.
	task.spawn(function()
		local needs = Config.needs
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				if not player:GetAttribute("Taken") then
					local hunger = player:GetAttribute("Hunger")
					local current = if typeof(hunger) == "number" then hunger else needs.hungerMax
					local after = Planque.hungerAfter(needs, current, 1)
					player:SetAttribute("Hunger", after)
					local speed, damage = Planque.hungerEffects(needs, after, 1)
					player:SetAttribute("HungerFactor", speed)
					if damage > 0 then
						CombatService.damagePlayer(player, damage)
					end
				end
			end
		end
	end)
end

return PlanqueService
