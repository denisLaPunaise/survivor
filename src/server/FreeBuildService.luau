--!strict
--[[
	FreeBuildService — la construction libre autour de la Planque (decide avec
	Josh le 9 novembre 2026).

	Le client montre un fantome et envoie ce qu'il veut poser et ou ; le
	serveur verifie (dans la cour, a portee, la case libre, la reserve
	suffit), paie et construit. Les pieces qui barrent la route (palissades,
	murs, chevaux de frise) ont une sante : les Repris les frappent
	(`obstacleNear`), on les repare (X). Les pieges blessent les Repris qui
	passent dessus ; les lampes s'allument la nuit. Chaque piece compte dans
	la Visibilite de la Planque (`visibility`).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Survivor = ReplicatedStorage:WaitForChild("Survivor")
local Config = require(Survivor:WaitForChild("Config"))
local FreeBuild = require(Survivor:WaitForChild("FreeBuild"))
local Planque = require(Survivor:WaitForChild("Planque"))
local Remotes = Survivor:WaitForChild("Remotes")

local CombatService = require(script.Parent:WaitForChild("CombatService"))
local LootService = require(script.Parent:WaitForChild("LootService"))
local RemoteGuard = require(script.Parent:WaitForChild("RemoteGuard"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))
local WorldService = require(script.Parent:WaitForChild("WorldService"))

local FreeBuildService = {}

type PieceSpec = {
	id: string,
	name: string,
	cost: { [string]: number },
	cells: number,
	depthCells: number,
	layer: string,
	size: { number },
	health: number?,
	blocks: boolean,
	visibility: number,
	material: string,
	color: { number },
	height: number?,
	trapDamage: number?,
	trapSeconds: number?,
	lightRange: number?,
}

type Placed = {
	spec: PieceSpec,
	model: Model,
	main: BasePart,
	keys: { string },
	health: number,
	lastTrap: number,
	light: PointLight?,
	bulb: BasePart?,
	prompt: ProximityPrompt?,
}

local placed: { Placed } = {}
-- Les coups encaisses depuis la derniere fois (le bruit, pour la Visibilite).
local hits = 0
local occupied: { [string]: boolean } = {}
local folder: Folder? = nil
local night = false

local specs: { [string]: PieceSpec } = {}
for _, spec in Config.freeBuild.pieces :: { PieceSpec } do
	specs[spec.id] = spec
end

local ground = RaycastParams.new()
ground.FilterType = Enum.RaycastFilterType.Exclude

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function getFolder(): Folder
	local f = folder
	if f == nil or f.Parent == nil then
		f = Instance.new("Folder")
		f.Name = "Constructions"
		f.Parent = WorldService.get().root
		folder = f
	end
	return f :: Folder
end

local function part(
	model: Model,
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
	p.Parent = model
	return p
end

-- Ce qu'on voit d'une piece : la piece principale (celle qu'on frappe et
-- qu'on mesure) et ses details.
local function shape(spec: PieceSpec, at: CFrame): (Model, BasePart, PointLight?, BasePart?)
	local model = Instance.new("Model")
	model.Name = "Construction_" .. spec.id
	local size = Vector3.new(spec.size[1], spec.size[2], spec.size[3])
	local material = (Enum.Material :: any)[spec.material] :: Enum.Material
	local color = rgb(spec.color)
	local main = part(model, "Piece", size, at, material, color)
	local light: PointLight? = nil
	local bulb: BasePart? = nil
	if spec.id == "palissade" then
		-- Des planches debout, inegales, et deux traverses.
		for _, y in { -size.Y * 0.25, size.Y * 0.3 } do
			part(
				model,
				"Traverse",
				Vector3.new(size.X, 0.5, 0.4),
				at * CFrame.new(0, y, -size.Z / 2 - 0.2),
				Enum.Material.WoodPlanks,
				color:Lerp(Color3.new(0, 0, 0), 0.25)
			)
		end
	elseif spec.id == "tole" then
		-- Des montants de bois derriere la tole, et des taches de rouille.
		for _, x in { -size.X / 2 + 0.3, size.X / 2 - 0.3 } do
			part(
				model,
				"Montant",
				Vector3.new(0.5, size.Y, 0.5),
				at * CFrame.new(x, 0, size.Z / 2 + 0.25),
				Enum.Material.WoodPlanks,
				Color3.fromRGB(96, 80, 64)
			)
		end
	elseif spec.id == "frise" then
		-- Des poutres croisees, pointes vers l'exterieur.
		main.Transparency = 1
		main.CanCollide = true
		for _, angle in { 35, -35 } do
			part(
				model,
				"Poutre",
				Vector3.new(size.X, 0.5, 0.5),
				at * CFrame.Angles(math.rad(angle), 0, 0),
				Enum.Material.WoodPlanks,
				color
			)
		end
	elseif spec.id == "piege" then
		main.CanCollide = false
		for _ = 1, 9 do
			local spike = part(
				model,
				"Clou",
				Vector3.new(0.15, 0.6, 0.15),
				at * CFrame.new(math.random() * 3 - 1.5, 0.4, math.random() * 3 - 1.5),
				Enum.Material.Metal,
				Color3.fromRGB(150, 150, 146)
			)
			spike.CanCollide = false
		end
	elseif spec.id == "lampe" then
		bulb = part(
			model,
			"Ampoule",
			Vector3.new(1.2, 0.8, 1.2),
			at * CFrame.new(0, size.Y / 2 + 0.3, 0),
			Enum.Material.Glass,
			Color3.fromRGB(230, 214, 170)
		)
		local glow = Instance.new("PointLight")
		glow.Range = spec.lightRange :: number
		glow.Brightness = 1.6
		glow.Color = Color3.fromRGB(255, 214, 160)
		glow.Shadows = true
		glow.Enabled = night
		glow.Parent = bulb
		light = glow
	elseif spec.id == "filet" then
		-- Un filet tendu sur quatre perches : il couvre a moitie (l'Oeil voit
		-- au travers, moins bien).
		main.CanCollide = false
		main.Transparency = 0.15
		main:SetAttribute(Config.world.coverAttribute, 0.6)
		local height = spec.height :: number
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				part(
					model,
					"Perche",
					Vector3.new(0.3, height, 0.3),
					at * CFrame.new(sx * (size.X / 2 - 0.2), -height / 2, sz * (size.Z / 2 - 0.2)),
					Enum.Material.WoodPlanks,
					Color3.fromRGB(96, 80, 64)
				)
			end
		end
	end
	model.PrimaryPart = main
	return model, main, light, bulb
end

local function remove(entry: Placed)
	local index = table.find(placed, entry)
	if index then
		table.remove(placed, index)
	end
	for _, key in entry.keys do
		occupied[key] = nil
	end
	entry.model:Destroy()
end

-- Une piece abimee se voit : elle noircit avec ses coups.
local function showDamage(entry: Placed)
	local max = entry.spec.health
	if max == nil then
		return
	end
	local t = 1 - entry.health / max
	entry.main.Color = rgb(entry.spec.color):Lerp(Color3.fromRGB(30, 26, 24), t * 0.7)
	local prompt = entry.prompt
	if prompt then
		prompt.Enabled = entry.health < max
	end
end

local function repair(player: Player, entry: Placed)
	local max = entry.spec.health
	if max == nil or entry.health >= max or table.find(placed, entry) == nil then
		return
	end
	if not Planque.pay(LootService.stock(), Config.freeBuild.repairCost) then
		LootService.sendHud(player, "Il faut une planche dans la réserve pour réparer.")
		return
	end
	entry.health = max
	showDamage(entry)
	LootService.broadcast(entry.spec.name .. " : réparée")
end

-- Ou poser `spec` vise en (x, z), tourne de `turns` : les cases, le CFrame,
-- ou la raison du refus.
local function plan(
	spec: PieceSpec,
	x: number,
	z: number,
	turns: number
): ({ string }?, CFrame?, string?)
	local b = Config.freeBuild
	local spawn = WorldService.get().spawn.Position
	local i, j = FreeBuild.cellAt(x, z, b.grid)
	local keys, cx, cz = FreeBuild.footprint(spec, turns, i, j, b.grid)
	if not FreeBuild.inYard(cx, cz, spawn.X, spawn.Z, b.radius) then
		return nil, nil, "Trop loin de la Planque."
	end
	if not FreeBuild.fits(occupied, keys) then
		return nil, nil, "La place est prise."
	end
	if #placed >= b.maxPieces then
		return nil, nil, "Trop de constructions."
	end
	local filter: { Instance } = { getFolder() }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(filter, player.Character)
		end
	end
	ground.FilterDescendantsInstances = filter
	local hit =
		workspace:Raycast(Vector3.new(cx, spawn.Y + 60, cz), Vector3.new(0, -120, 0), ground)
	if hit == nil then
		return nil, nil, "Pas de sol ici."
	end
	local lift = spec.size[2] / 2 + (spec.height or 0)
	-- Un quart de tour : la longueur passe de X a Z.
	local at = CFrame.new(cx, hit.Position.Y + lift, cz) * CFrame.Angles(0, math.rad(90 * turns), 0)
	return keys, at, nil
end

local function construct(player: Player, request: any)
	if typeof(request) ~= "table" then
		return
	end
	local spec = specs[request.piece]
	local x, z, turns = request.x, request.z, request.turns
	if
		spec == nil
		or typeof(x) ~= "number"
		or typeof(z) ~= "number"
		or typeof(turns) ~= "number"
		or turns ~= math.floor(turns)
		or turns < 0
		or turns > 3
	then
		return
	end
	local character = player.Character
	if
		character == nil
		or player:GetAttribute("Hidden")
		or player:GetAttribute("Taken")
		or CombatService.isDowned(player)
	then
		return
	end
	-- A portee de bras tendu : on ne construit pas a l'autre bout de la cour.
	local from = character:GetPivot().Position
	if Vector3.new(x - from.X, 0, z - from.Z).Magnitude > Config.freeBuild.reach + 8 then
		return
	end
	local keys, at, refusal = plan(spec, x, z, turns)
	if keys == nil or at == nil then
		LootService.sendHud(player, refusal)
		return
	end
	if not Planque.pay(LootService.stock(), spec.cost) then
		LootService.sendHud(player, "Pas assez dans la réserve pour : " .. spec.name)
		return
	end
	local model, main, light, bulb = shape(spec, at)
	model:SetAttribute("Cles", table.concat(keys, ","))
	model.Parent = getFolder()
	local entry: Placed = {
		spec = spec,
		model = model,
		main = main,
		keys = keys,
		health = spec.health or 0,
		lastTrap = 0,
		light = light,
		bulb = bulb,
		prompt = nil,
	}
	for _, key in keys do
		occupied[key] = true
	end
	if spec.health then
		local onFoot = Config.controls.contexts.onFoot
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Réparer"
		prompt.ObjectText = spec.name
		prompt.HoldDuration = Config.freeBuild.repairHoldSeconds
		prompt.MaxActivationDistance = Config.loot.promptDistance
		prompt.RequiresLineOfSight = false
		prompt.GamepadKeyCode = (Enum.KeyCode :: any)[onFoot.interact.gamepad]
		prompt.KeyboardKeyCode = (Enum.KeyCode :: any)[onFoot.interact.keyboard]
		prompt.Enabled = false
		prompt.Triggered:Connect(function(by: Player)
			repair(by, entry)
		end)
		prompt.Parent = main
		entry.prompt = prompt
	end
	table.insert(placed, entry)
	Sfx.at("toit", main)
	LootService.broadcast(spec.name .. " : construit")
end

-- Pour les sondes : le meme chemin que le client.
function FreeBuildService.tryConstruct(
	player: Player,
	pieceId: string,
	x: number,
	z: number,
	turns: number
)
	construct(player, { piece = pieceId, x = x, z = z, turns = turns })
end

-- Pour les Repris : la piece qui barre la route la plus proche, a cette
-- portee. Rend de quoi la frapper.
function FreeBuildService.obstacleNear(position: Vector3, range: number): ((number) -> ())?
	local best: Placed? = nil
	local bestDistance = math.huge
	for _, entry in placed do
		if entry.spec.blocks and entry.spec.health then
			-- Au bord de la piece, pas a son centre : une palissade fait 8 de long.
			local p = entry.main.CFrame:PointToObjectSpace(position)
			local half = entry.main.Size / 2
			local outside = Vector3.new(
				math.max(math.abs(p.X) - half.X, 0),
				0,
				math.max(math.abs(p.Z) - half.Z, 0)
			)
			local distance = outside.Magnitude
			if distance <= range and distance < bestDistance then
				best, bestDistance = entry, distance
			end
		end
	end
	local target = best
	if target == nil then
		return nil
	end
	return function(damage: number)
		if table.find(placed, target) == nil then
			return
		end
		hits += 1
		target.health -= damage
		if target.health <= 0 then
			Sfx.at("toit", target.main)
			LootService.broadcast(target.spec.name .. " a cédé !", "danger")
			remove(target)
		else
			showDamage(target)
		end
	end
end

function FreeBuildService.takeHits(): number
	local taken = hits
	hits = 0
	return taken
end

-- L'Oeil a trouve la Planque : il arrache `count` constructions qui ne sont
-- pas sous un filet de camouflage. Elles montent vers lui. Rend combien.
function FreeBuildService.rip(count: number): number
	local covered: { [string]: boolean } = {}
	for _, entry in placed do
		if entry.spec.layer == "air" then
			for _, key in entry.keys do
				local below = string.gsub(key, "^air:", "sol:")
				covered[below] = true
			end
		end
	end
	local exposed: { Placed } = {}
	for _, entry in placed do
		local hidden = false
		for _, key in entry.keys do
			if covered[key] then
				hidden = true
			end
		end
		if entry.spec.layer == "sol" and not hidden then
			table.insert(exposed, entry)
		end
	end
	local taken = 0
	while taken < count and #exposed > 0 do
		local entry = table.remove(exposed, math.random(1, #exposed)) :: Placed
		taken += 1
		for _, key in entry.keys do
			occupied[key] = nil
		end
		local index = table.find(placed, entry)
		if index then
			table.remove(placed, index)
		end
		Sfx.at("toit", entry.main)
		local model = entry.model
		local origin = model:GetPivot()
		task.spawn(function()
			local started = os.clock()
			while os.clock() - started < 2.5 do
				local t = (os.clock() - started) / 2.5
				model:PivotTo(
					origin * CFrame.new(0, 250 * t * t, 0) * CFrame.Angles(t * 4, t * 6, 0)
				)
				task.wait()
			end
			model:Destroy()
		end)
	end
	return taken
end

-- Ce que les constructions ajoutent a la Visibilite de la Planque.
function FreeBuildService.visibility(): number
	local total = 0
	for _, entry in placed do
		total += entry.spec.visibility
	end
	return total
end

function FreeBuildService.count(): number
	return #placed
end

-- La nuit, les lampes s'allument.
function FreeBuildService.setNight(on: boolean)
	night = on
	for _, entry in placed do
		local light, bulb = entry.light, entry.bulb
		if light and bulb then
			light.Enabled = on
			bulb.Material = if on then Enum.Material.Neon else Enum.Material.Glass
		end
	end
end

function FreeBuildService.reset()
	for i = #placed, 1, -1 do
		remove(placed[i])
	end
end

function FreeBuildService.start()
	local remote = Remotes:WaitForChild("Construct") :: RemoteEvent
	remote.OnServerEvent:Connect(RemoteGuard.wrap("Construct", construct))
	-- Les pieges : ceux qui passent dessus s'y blessent, a leur cadence.
	task.spawn(function()
		while true do
			task.wait(0.25)
			local now = os.clock()
			for _, entry in placed do
				local damage, every = entry.spec.trapDamage, entry.spec.trapSeconds
				if damage and every and now - entry.lastTrap >= every then
					if
						CombatService.hurtNear(
							entry.main.Position,
							entry.main.Size.X / 2 + 1,
							damage
						) > 0
					then
						entry.lastTrap = now
					end
				end
			end
		end
	end)
end

return FreeBuildService
