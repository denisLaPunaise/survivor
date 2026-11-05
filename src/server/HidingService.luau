--!strict
--[[
	HidingService — les cachettes : y entrer, en sortir, les marquer, les
	arracher, et les replacer chaque matin.

	Caché, le joueur est ANCRE a l'interieur de la cachette : il ne voit pas
	dehors (le client noircit l'ecran) et l'Oeil ne peut pas le voir tant que
	la cachette tient. C'est la regle n°1 : bien caché, on est en sécurité.

	Etat expose au client par attributs du joueur : `Hidden` (booleen).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Survivor = ReplicatedStorage:WaitForChild("Survivor")
local Config = require(Survivor:WaitForChild("Config"))
local Growth = require(Survivor:WaitForChild("Growth"))
local Hiding = require(Survivor:WaitForChild("Hiding"))
local Remotes = Survivor:WaitForChild("Remotes")

local LootService = require(script.Parent:WaitForChild("LootService"))
local RemoteGuard = require(script.Parent:WaitForChild("RemoteGuard"))
local ReprisService = require(script.Parent:WaitForChild("ReprisService"))
local WorldService = require(script.Parent:WaitForChild("WorldService"))

local HidingService = {}

export type Target = {
	id: string,
	x: number,
	z: number,
}

type Spot = {
	id: string,
	model: Instance,
	fragile: boolean,
	inside: BasePart,
	-- La premiere sortie : la ou sort un Repris qui s'y cachait.
	exit: BasePart,
	-- Une invite par sortie : une voiture s'ouvre des deux cotes (Josh : on
	-- ne pouvait y entrer que d'un cote).
	prompts: { ProximityPrompt },
	-- La sortie par ou l'occupant est entre : il ressort du meme cote.
	exitUsed: BasePart?,
	occupant: Player?,
	-- Un Repris s'y cache deja : il en sort quand on ouvre.
	lurker: boolean,
}

local random = Random.new()

local spots: { [string]: Spot } = {}
local hiddenIn: { [Player]: Spot } = {}
local marks: { [string]: Hiding.Mark } = {}
-- Emplacements arraches aujourd'hui : demain, ils restent vides.
local rippedToday: { [string]: boolean } = {}
local fragileFolder: Folder? = nil

local day = 1
local sweepNumber = 0

-- Les batiments ou l'on peut s'abriter (maisons au toit entier, superette).
-- S'y abriter pendant un Balayage les marque comme une cachette fragile ; au
-- Balayage suivant, l'Oeil arrache leur toit. Decide avec Josh le 5 novembre
-- 2026 : sans ca, entrer dans n'importe quelle maison suffisait a ne jamais
-- risquer rien.
type RoofPart = {
	part: BasePart,
	transparency: number,
	collide: boolean,
	query: boolean,
}

type Building = {
	id: string,
	model: Model,
	box: CFrame,
	size: Vector3,
	roof: { RoofPart },
	-- Ce qui part avec le toit sans couvrir personne : les objets legers de
	-- l'interieur (chaises, papiers, tapis...), aspires par le trou.
	loose: { RoofPart },
	ripped: boolean,
}

local buildings: { [string]: Building } = {}
local buildingList: { Building } = {}

function HidingService.buildingCount(): number
	return #buildingList
end

local function nextInt(lo: number, hi: number): number
	return random:NextInteger(lo, hi)
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function release(player: Player, toExit: boolean)
	local spot = hiddenIn[player]
	if spot == nil then
		return
	end
	hiddenIn[player] = nil
	spot.occupant = nil
	for _, prompt in spot.prompts do
		if prompt.Parent then
			prompt.Enabled = true
		end
	end
	local exit = spot.exitUsed or spot.exit
	spot.exitUsed = nil
	local root = rootOf(player)
	if root then
		root.Anchored = false
		if toExit then
			root.CFrame = exit.CFrame
		end
	end
	player:SetAttribute("Hidden", false)
end

local function enter(player: Player, spot: Spot, through: BasePart?)
	if hiddenIn[player] or spot.occupant then
		return
	end
	if player:GetAttribute("Taken") then
		return
	end
	local root = rootOf(player)
	if root == nil then
		return
	end
	if spot.lurker then
		-- La place est prise : un Repris en sort, et on reste dehors.
		spot.lurker = false
		ReprisService.ambush((through or spot.exit).CFrame, player)
		return
	end
	spot.occupant = player
	spot.exitUsed = through
	for _, prompt in spot.prompts do
		prompt.Enabled = false
	end
	hiddenIn[player] = spot
	root.CFrame = spot.inside.CFrame
	root.Anchored = true
	player:SetAttribute("Hidden", true)
	if spot.fragile then
		Hiding.mark(marks, spot.id, day, sweepNumber)
		-- La marque se voit, de tous : une lueur pale (decide).
		local glow = Instance.new("Highlight")
		glow.Name = "Marque"
		glow.FillTransparency = 1
		glow.OutlineColor = Color3.fromRGB(235, 225, 200)
		glow.OutlineTransparency = 0.35
		glow.Parent = spot.model
	end
end

local function register(id: string, model: Instance, fragile: boolean)
	local w = Config.world
	local inside = model:FindFirstChild(w.spotInside, true) :: BasePart
	local exits: { BasePart } = {}
	for _, d in model:GetDescendants() do
		if d.Name == w.spotExit and d:IsA("BasePart") then
			table.insert(exits, d)
		end
	end
	local onFoot = Config.controls.contexts.onFoot
	local spot: Spot = {
		id = id,
		model = model,
		fragile = fragile,
		inside = inside,
		exit = model:FindFirstChild(w.spotExit, true) :: BasePart,
		prompts = {},
		exitUsed = nil,
		occupant = nil,
		lurker = false,
	}
	for _, exit in exits do
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Se cacher"
		prompt.ObjectText = if fragile then "Cachette fragile" else "Cachette solide"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = Config.loot.hidePromptDistance
		prompt.RequiresLineOfSight = false
		prompt.GamepadKeyCode = (Enum.KeyCode :: any)[onFoot.interact.gamepad]
		prompt.KeyboardKeyCode = (Enum.KeyCode :: any)[onFoot.interact.keyboard]
		prompt.Parent = exit
		table.insert(spot.prompts, prompt)
		prompt.Triggered:Connect(function(player: Player)
			enter(player, spot, exit)
		end)
	end
	spots[id] = spot
end

-- Entrer dans une cachette par son identifiant. C'est ce que fait l'invite ;
-- c'est aussi ce que les sondes de test appellent, parce que les touches
-- simulees par le pont MCP n'atteignent pas les invites de Roblox.
function HidingService.tryEnter(player: Player, spotId: string): boolean
	local spot = spots[spotId]
	if spot == nil then
		return false
	end
	enter(player, spot)
	return hiddenIn[player] == spot
end

function HidingService.isHidden(player: Player): boolean
	return hiddenIn[player] ~= nil
end

-- Sortir tout le monde, sans les deplacer : pour un joueur aspire, une
-- defaite, ou la nuit.
function HidingService.releaseAll()
	for player in hiddenIn do
		release(player, true)
	end
end

function HidingService.release(player: Player)
	release(player, false)
end

-- Appele au signal de chaque Balayage, avant de calculer son trajet.
function HidingService.beginSweep(): { Target }
	sweepNumber += 1
	local out: { Target } = {}
	for _, spotId in Hiding.marked(marks, day, sweepNumber, Config.eye.markDays) do
		local spot = spots[spotId]
		local building = buildings[spotId]
		if spot then
			local p = spot.inside.Position
			table.insert(out, { id = spotId, x = p.X, z = p.Z })
		elseif building and not building.ripped then
			local p = building.box.Position
			table.insert(out, { id = spotId, x = p.X, z = p.Z })
		end
	end
	return out
end

-- Les arrachages au hasard d'un Balayage : des cachettes fragiles du jour et
-- des toits encore entiers, pris dans sa zone, hors de celles deja marquees.
-- Une cachette occupee peut partir aussi (decide avec Josh) : son occupant
-- est ejecte avec un repit.
function HidingService.randomTargets(
	zone: { minX: number, maxX: number, minZ: number, maxZ: number },
	spotCount: number,
	roofCount: number
): { Target }
	local function inZone(p: Vector3): boolean
		return p.X >= zone.minX and p.X <= zone.maxX and p.Z >= zone.minZ and p.Z <= zone.maxZ
	end
	local function pick(pool: { Target }, count: number, out: { Target })
		for _ = 1, math.min(count, #pool) do
			table.insert(out, table.remove(pool, random:NextInteger(1, #pool)) :: Target)
		end
	end
	local spotPool: { Target } = {}
	for id, spot in spots do
		local p = spot.inside.Position
		if spot.fragile and marks[id] == nil and inZone(p) then
			table.insert(spotPool, { id = id, x = p.X, z = p.Z })
		end
	end
	local roofPool: { Target } = {}
	for _, building in buildingList do
		local p = building.box.Position
		if not building.ripped and marks[building.id] == nil and inZone(p) then
			table.insert(roofPool, { id = building.id, x = p.X, z = p.Z })
		end
	end
	local out: { Target } = {}
	pick(spotPool, spotCount, out)
	pick(roofPool, roofCount, out)
	return out
end

-- Le batiment intact qui contient ce point, s'il y en a un.
local function buildingAt(position: Vector3): Building?
	for _, building in buildingList do
		if not building.ripped then
			local p = building.box:PointToObjectSpace(position)
			local half = building.size / 2
			if math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z then
				return building
			end
		end
	end
	return nil
end

-- Appele par l'EyeService pendant un Balayage, pour chaque joueur qui n'est
-- pas dans une cachette : s'il s'abrite dans un batiment, ce batiment est
-- marque. Meme regle que les cachettes fragiles : l'Oeil vient le chercher
-- au Balayage SUIVANT, jamais a celui-ci.
function HidingService.noteShelter(position: Vector3)
	local building = buildingAt(position)
	if building then
		Hiding.mark(marks, building.id, day, sweepNumber)
	end
end

-- Arracher la toiture : la vraie disparait (invisible, traversee par les
-- rayons) et des copies s'envolent. Rien n'est detruit : une defaite remet les
-- toits en place.
--
-- L'animation : la toiture TREMBLE d'abord, sur place (la vraie, encore
-- solide : on est encore couvert, c'est le signal pour fuir), puis chaque
-- morceau part a son tour, tire vers le ciel en tournoyant, avec ce qui
-- trainait dans la maison, dans un nuage de poussiere.
local function ripRoof(building: Building)
	building.ripped = true
	marks[building.id] = nil
	local e = Config.eye

	local shakeEnd = os.clock() + e.roofShakeSeconds
	-- Ceux qui sont dessous l'apprennent aussi par un message : le
	-- tremblement seul peut passer inapercu, tete baissee sur une fouille.
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			local p = building.box:PointToObjectSpace(character:GetPivot().Position)
			local half = building.size / 2
			if math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z then
				LootService.sendHud(player, "Le toit tremble : sors vite !")
			end
		end
	end
	local origins: { [BasePart]: CFrame } = {}
	for _, entry in building.roof do
		origins[entry.part] = entry.part.CFrame
	end
	while os.clock() < shakeEnd do
		for part, origin in origins do
			local j = e.roofShakeStuds
			part.CFrame = origin
				* CFrame.new(
					random:NextNumber(-j, j),
					random:NextNumber(-j, j),
					random:NextNumber(-j, j)
				)
		end
		RunService.Heartbeat:Wait()
	end
	for part, origin in origins do
		part.CFrame = origin
	end

	-- La poussiere, la ou le toit s'arrache.
	local center = building.box.Position + Vector3.new(0, building.size.Y / 2, 0)
	local dustAnchor = Instance.new("Part")
	dustAnchor.Anchored = true
	dustAnchor.CanCollide = false
	dustAnchor.CanQuery = false
	dustAnchor.Transparency = 1
	dustAnchor.Size = Vector3.new(1, 1, 1)
	dustAnchor.CFrame = CFrame.new(center)
	dustAnchor.Parent = workspace
	local dust = Instance.new("Smoke")
	dust.Color = Color3.fromRGB(150, 140, 128)
	dust.Opacity = 0.45
	dust.Size = 14
	dust.RiseVelocity = 10
	dust.Parent = dustAnchor
	task.delay(1.2, function()
		dust.Enabled = false
	end)
	task.delay(5, function()
		dustAnchor:Destroy()
	end)

	type Flyer = { ghost: BasePart, origin: CFrame, delay: number, drift: Vector3, axis: Vector3 }
	local flyers: { Flyer } = {}
	local function launch(entry: RoofPart)
		local ghost = entry.part:Clone()
		ghost.CanCollide = false
		ghost.CanQuery = false
		ghost.Anchored = true
		ghost.Parent = workspace
		table.insert(flyers, {
			ghost = ghost,
			origin = entry.part.CFrame,
			delay = random:NextNumber(0, e.roofStaggerSeconds),
			drift = Vector3.new(random:NextNumber(-1, 1), 0, random:NextNumber(-1, 1))
				* e.roofDriftStuds,
			axis = Vector3.new(
				random:NextNumber(-1, 1),
				random:NextNumber(-1, 1),
				random:NextNumber(-1, 1)
			).Unit,
		})
		entry.part.Transparency = 1
		entry.part.CanCollide = false
		entry.part.CanQuery = false
	end
	for _, entry in building.roof do
		launch(entry)
	end
	for _, entry in building.loose do
		launch(entry)
	end

	local started = os.clock()
	local total = e.roofLiftSeconds + e.roofStaggerSeconds
	local connection: RBXScriptConnection? = nil
	connection = RunService.Heartbeat:Connect(function()
		local elapsed = os.clock() - started
		for _, f in flyers do
			local t = math.clamp((elapsed - f.delay) / e.roofLiftSeconds, 0, 1)
			-- Lent au depart, puis aspire : la montee accelere.
			local rise = t * t * e.roofLiftHeight
			local spin = CFrame.fromAxisAngle(f.axis, t * e.roofSpinTurns * math.pi * 2)
			f.ghost.CFrame = (f.origin + Vector3.new(0, rise, 0) + f.drift * t) * spin
			f.ghost.Transparency = math.max(t * 1.2 - 0.2, 0)
		end
		if elapsed >= total then
			if connection then
				connection:Disconnect()
			end
			for _, f in flyers do
				f.ghost:Destroy()
			end
		end
	end)
end

-- L'Oeil arrache une cachette marquee : elle monte vers le ciel et disparait.
-- Celui qui etait dedans se retrouve a decouvert, la ou il etait.
function HidingService.rip(spotId: string)
	local building = buildings[spotId]
	if building then
		if not building.ripped then
			ripRoof(building)
		end
		return
	end
	local spot = spots[spotId]
	if spot == nil or not spot.fragile then
		return
	end
	spots[spotId] = nil
	marks[spotId] = nil
	rippedToday[spotId] = true
	local occupant = spot.occupant
	if occupant then
		-- Ejecte devant la cachette : l'Oeil le tient, mais le repit lui
		-- laisse le temps de courir (EyeService lit l'attribut).
		release(occupant, true)
		occupant:SetAttribute(
			Config.world.graceAttribute,
			workspace:GetServerTimeNow() + Config.eye.ripGraceSeconds
		)
		LootService.sendHud(occupant, "L'Œil arrache ta cachette : cours !")
	end
	for _, prompt in spot.prompts do
		prompt:Destroy()
	end
	local lift = Config.eye.ripLiftHeight
	local info =
		TweenInfo.new(Config.eye.ripLiftSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	for _, part in spot.model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			TweenService:Create(part, info, {
				CFrame = part.CFrame + Vector3.new(0, lift, 0),
				Transparency = 1,
			}):Play()
		end
	end
	task.delay(Config.eye.ripLiftSeconds, function()
		spot.model:Destroy()
	end)
end

-- Chaque matin : les cachettes fragiles changent de place (decide avec Josh).
function HidingService.newDay(dayNumber: number)
	day = dayNumber
	local world = WorldService.get()
	HidingService.releaseAll()

	for id, spot in spots do
		if spot.fragile then
			spots[id] = nil
		end
	end
	if fragileFolder then
		fragileFolder:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "CachettesFragiles"
	fragileFolder = folder

	local anchorsById: { [string]: BasePart } = {}
	local ids: { string } = {}
	for _, anchor in world.anchors:GetChildren() do
		if anchor:IsA("BasePart") then
			anchor.Transparency = 1
			anchor.CanCollide = false
			anchor.CanQuery = false
			anchorsById[anchor.Name] = anchor
			table.insert(ids, anchor.Name)
		end
	end
	local count = math.floor(#ids * Growth.onDay(Config.day.fragileShare, dayNumber) + 0.5)
	local avoid = rippedToday
	rippedToday = {}

	for _, id in Hiding.pickAnchors(ids, count, nextInt, avoid) do
		local anchor = anchorsById[id]
		local prefab =
			world.prefabs:FindFirstChild(anchor:GetAttribute("Prefab") :: string) :: Model
		local model = prefab:Clone()
		model.Name = id
		model:PivotTo(anchor.CFrame)
		model.Parent = folder
		register(id, model, true)
		spots[id].lurker = random:NextNumber() < Growth.onDay(Config.repris.day.lurkerShare, day)
	end
	folder.Parent = world.root
end

-- Une defaite : la memoire du Veilleur repart de zero aussi, et les toits
-- arraches reviennent (la partie recommence depuis le debut).
function HidingService.reset()
	for _, building in buildingList do
		if building.ripped then
			building.ripped = false
			for _, list in { building.roof, building.loose } do
				for _, entry in list do
					entry.part.Transparency = entry.transparency
					entry.part.CanCollide = entry.collide
					entry.part.CanQuery = entry.query
				end
			end
		end
	end
	table.clear(marks)
	table.clear(rippedToday)
	sweepNumber = 0
end

function HidingService.start()
	local world = WorldService.get()
	for _, spot in world.solidSpots:GetChildren() do
		register(spot.Name, spot, false)
	end

	local w = Config.world
	for _, model in world.root:GetDescendants() do
		if model:IsA("Model") and model:GetAttribute(w.buildingAttribute) == true then
			local roof: { RoofPart } = {}
			local loose: { RoofPart } = {}
			for _, part in model:GetDescendants() do
				if part:IsA("BasePart") then
					local entry = {
						part = part,
						transparency = part.Transparency,
						collide = part.CanCollide,
						query = part.CanQuery,
					}
					if part:GetAttribute(w.roofAttribute) == true then
						table.insert(roof, entry)
					elseif part:GetAttribute(w.looseAttribute) == true then
						table.insert(loose, entry)
					end
				end
			end
			local box, size = model:GetBoundingBox()
			local building: Building = {
				-- Les noms de maisons sont uniques dans la recette ; le prefixe
				-- evite toute collision avec un nom de cachette.
				id = "Batiment:" .. model:GetFullName(),
				model = model,
				box = box,
				size = size,
				roof = roof,
				loose = loose,
				ripped = false,
			}
			buildings[building.id] = building
			table.insert(buildingList, building)
		end
	end

	local leave = Remotes:WaitForChild("LeaveHiding") :: RemoteEvent
	leave.OnServerEvent:Connect(RemoteGuard.wrap("LeaveHiding", function(player: Player)
		release(player, true)
	end))

	Players.PlayerRemoving:Connect(function(player: Player)
		local spot = hiddenIn[player]
		if spot then
			spot.occupant = nil
			spot.exitUsed = nil
			for _, prompt in spot.prompts do
				prompt.Enabled = true
			end
			hiddenIn[player] = nil
		end
	end)
end

return HidingService
