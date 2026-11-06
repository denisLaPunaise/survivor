--!strict
--[[
	EyeService — le Veilleur : les signes, le Balayage, le regard, l'aspiration.

	LE REGARD EST UNE LIGNE DE VUE (principe n°1). Un joueur est vu s'il est
	dans le cone du regard ET qu'un rayon partant de l'Oeil atteint sa tete ou
	son torse. Le rayon traverse ce qu'on voit au travers (vitres, parts
	presque invisibles) et ce qui ne couvre qu'a moitie (attribut `Couvert`),
	et s'arrete sur le reste : un toit, un mur, une voiture.

	Un joueur cache dans une cachette intacte n'est jamais vu : il n'y a rien a
	mesurer, la cachette le couvre par construction.

	Au client : `EyeState` annonce les phases ; l'attribut `Exposure` du joueur
	porte sa jauge ; la part `Regard` (le faisceau) vit dans Workspace et se
	voit de tous.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Survivor = ReplicatedStorage:WaitForChild("Survivor")
local Config = require(Survivor:WaitForChild("Config"))
local Exposure = require(Survivor:WaitForChild("Exposure"))
local Growth = require(Survivor:WaitForChild("Growth"))
local Sweep = require(Survivor:WaitForChild("Sweep"))
local Remotes = Survivor:WaitForChild("Remotes")

local CrewService = require(script.Parent:WaitForChild("CrewService"))
local HidingService = require(script.Parent:WaitForChild("HidingService"))
local LootService = require(script.Parent:WaitForChild("LootService"))
local PlanqueService = require(script.Parent:WaitForChild("PlanqueService"))
local WorldService = require(script.Parent:WaitForChild("WorldService"))

local EyeService = {}

local eyeState = Remotes:WaitForChild("EyeState") :: RemoteEvent
local random = Random.new()

-- Le regard en cours : nil entre deux Balayages.
local looking: { x: number, z: number }? = nil
local eyePosition = Vector3.zero
local groundY = 0
local beam: BasePart? = nil
local accumulated = 0
local exposures: { [Player]: number } = {}
-- Le dernier joueur que l'Oeil a vu pendant ce Balayage, et quand.
local sighting: { player: Player, at: number }? = nil

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.RespectCanCollide = false

-- Le globe de l'Oeil dans le ciel et la distance de son centre au bout de
-- la pupille : le regard (et la ligne de vue) partent de la pupille, tournee
-- vers ce qu'il vise (Josh : « que le laser sorte de la pupille »). Mesure
-- sur le modele, qui n'est tourne que chez les clients : cote serveur, il est
-- tel que la recette l'a pose.
local function eyeGeometry(): (Vector3, number)
	local w = Config.world
	local root = workspace:FindFirstChild(w.folder)
	local sky = root and root:FindFirstChild(w.sky)
	local model = sky and sky:FindFirstChild(w.eye)
	local globe = model and (model :: Model).PrimaryPart
	if globe == nil then
		error("[Survivor] Pas de globe pour l'Oeil : la recette de la ville n'a pas tourne ?")
	end
	local center = globe.Position
	local reach = globe.Size.X / 2
	for _, part in (model :: Model):GetDescendants() do
		if part:IsA("BasePart") and part.Name == "Pupille" then
			reach = math.max(reach, (part.Position - center).Magnitude + part.Size.Z / 2)
		end
	end
	return center, reach
end

local function boundsOf(part: BasePart): Sweep.Bounds
	local half = part.Size / 2
	local c = part.Position
	return { minX = c.X - half.X, maxX = c.X + half.X, minZ = c.Z - half.Z, maxZ = c.Z + half.Z }
end

-- La part du regard qui atteint `target` : 1 a decouvert, 0 cache, entre les
-- deux derriere un buisson.
local function visibility(target: Vector3, ignore: { Instance }): number
	local eye = Config.eye
	local seen = 1
	local origin = eyePosition
	local filter = table.clone(ignore)
	for _ = 1, eye.maxRayHops do
		rayParams.FilterDescendantsInstances = filter
		local direction = target - origin
		local hit = workspace:Raycast(origin, direction, rayParams)
		if hit == nil then
			return seen
		end
		local part = hit.Instance
		local cover = part:GetAttribute(Config.world.coverAttribute)
		if typeof(cover) == "number" then
			seen *= math.clamp(1 - cover, 0, 1)
		elseif part.Transparency < eye.seeThroughTransparency then
			return 0
		end
		-- Vitre ou buisson : on continue derriere.
		table.insert(filter, part)
		origin = hit.Position
		if seen <= 0 then
			return 0
		end
	end
	-- Trop de couches : on donne le doute au joueur.
	return 0
end

local function inCone(position: Vector3): boolean
	if looking == nil then
		return false
	end
	local target = Vector3.new(looking.x, groundY, looking.z)
	local axis = target - eyePosition
	local toPlayer = position - eyePosition
	if toPlayer.Magnitude <= 0 or axis.Magnitude <= 0 then
		return false
	end
	local cosAngle = axis.Unit:Dot(toPlayer.Unit)
	local maxAngle = math.atan(Config.eye.beamRadius / axis.Magnitude)
	return cosAngle >= math.cos(maxAngle)
end

local function seenFactor(player: Player): number
	if
		looking == nil
		or HidingService.isHidden(player)
		or CrewService.isTaken(player)
		or CrewService.isBound(player)
	then
		return 0
	end
	local character = player.Character
	if character == nil then
		return 0
	end
	local head = character:FindFirstChild("Head")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not (head and head:IsA("BasePart") and root and root:IsA("BasePart")) then
		return 0
	end
	if not inCone(root.Position) and not inCone(head.Position) then
		return 0
	end
	local ignore: { Instance } = {}
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(ignore, other.Character)
		end
	end
	if beam then
		table.insert(ignore, beam)
	end
	-- Viser un peu en deca du centre des parts, pour ne pas toucher le
	-- personnage lui-meme par arrondi (il est deja exclu, mais ses
	-- accessoires peuvent deborder).
	return math.max(visibility(head.Position, ignore), visibility(root.Position, ignore))
end

local function check(dt: number)
	for _, player in Players:GetPlayers() do
		-- Pendant un Balayage, s'abriter dans un batiment le marque.
		if
			looking
			and not HidingService.isHidden(player)
			and not CrewService.isTaken(player)
			and not CrewService.isBound(player)
		then
			local character = player.Character
			if character then
				HidingService.noteShelter(character:GetPivot().Position)
			end
		end
		local level = exposures[player] or 0
		local seen = seenFactor(player)
		if seen > 0 then
			-- Il l'a vu : c'est lui qu'il va traquer (le plus recent l'emporte).
			sighting = { player = player, at = os.clock() }
		end
		-- Ejecte de sa cachette arrachee : l'Oeil le tient et le poursuit,
		-- mais sa jauge ne monte pas avant la fin du repit.
		local grace = player:GetAttribute(Config.world.graceAttribute)
		if typeof(grace) == "number" and workspace:GetServerTimeNow() < grace then
			if looking then
				sighting = { player = player, at = os.clock() }
			end
			seen = 0
		end
		level = Exposure.step(level, seen, dt, Config.eye.exposure)
		exposures[player] = level
		player:SetAttribute("Exposure", level)
		if Exposure.isTaken(level) then
			exposures[player] = 0
			CrewService.take(player)
		end
	end
end

local function placeBeam()
	local part = beam
	if part == nil or looking == nil then
		return
	end
	local target = Vector3.new(looking.x, groundY, looking.z)
	local length = (target - eyePosition).Magnitude
	part.Size = Vector3.new(length, Config.eye.beamRadius * 2, Config.eye.beamRadius * 2)
	-- Un cylindre prend sa longueur sur X.
	part.CFrame = CFrame.lookAt((eyePosition + target) / 2, target)
		* CFrame.Angles(0, math.rad(90), 0)
end

local function makeBeam(): BasePart
	local part = Instance.new("Part")
	part.Name = "Regard"
	part.Shape = Enum.PartType.Cylinder
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(255, 214, 196)
	part.Transparency = 0.82
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	local light = Instance.new("SpotLight")
	light.Name = "Lumiere"
	light.Face = Enum.NormalId.Right
	light.Range = 60
	light.Angle = 30
	light.Brightness = 6
	light.Color = part.Color
	light.Parent = part
	part.Parent = workspace
	return part
end

-- Le centre du Balayage : un joueur encore debout, tire au hasard. Sans
-- personne, un point au hasard du quartier.
local function zoneCenter(bounds: Sweep.Bounds, dayNumber: number): (number, number, Player?)
	local candidates: { Player } = {}
	for _, player in Players:GetPlayers() do
		if player.Character and not CrewService.isTaken(player) then
			table.insert(candidates, player)
		end
	end
	if #candidates == 0 then
		return random:NextNumber(bounds.minX, bounds.maxX),
			random:NextNumber(bounds.minZ, bounds.maxZ),
			nil
	end
	local pick = candidates[random:NextInteger(1, #candidates)]
	local at = (pick.Character :: Model):GetPivot().Position
	-- Il vise « dans le coin » au debut, de plus en plus juste ensuite.
	local error = Growth.onDay(Config.eye.hunt.aimError, dayNumber)
	local angle = random:NextNumber(0, math.pi * 2)
	local miss = random:NextNumber(0, error)
	return at.X + math.cos(angle) * miss, at.Z + math.sin(angle) * miss, pick
end

local function buildPath(
	district: Sweep.Bounds,
	targets: { HidingService.Target },
	cx: number,
	cz: number,
	dayNumber: number
): Sweep.Timeline
	local eye = Config.eye
	local bounds = Sweep.zoneAround(cx, cz, eye.zoneSize, district)
	targets = Sweep.targetsIn(targets, bounds, eye.inspectMargin)
	-- Les arrachages au hasard : un peu plus chaque jour (une partie decimale
	-- est une chance).
	local function count(curve: Growth.Curve): number
		local value = Growth.onDay(curve, dayNumber)
		local whole = math.floor(value)
		return whole + (if random:NextNumber() < value - whole then 1 else 0)
	end
	local extra = HidingService.randomTargets(
		bounds,
		count(eye.randomRips.spots),
		count(eye.randomRips.roofs)
	)
	local pattern = eye.patterns[random:NextInteger(1, #eye.patterns)]
	local path = if pattern == "spiral"
		then Sweep.spiralPath(bounds, eye.laneSpacing)
		else Sweep.linePath(
			bounds,
			eye.laneSpacing,
			random:NextNumber() < 0.5,
			random:NextNumber() < 0.5
		)
	local inspected = Sweep.withInspections(
		Sweep.withStops(path, extra, eye.inspectSeconds),
		targets,
		eye.inspectSeconds
	)
	return Sweep.timeline(inspected, eye.beamSpeed)
end

-- Un Balayage complet : les signes, puis le regard. Rend la main a la fin.
-- `stillCurrent` dit si la partie n'a pas ete remise a zero entre-temps.
function EyeService.runSweep(stillCurrent: () -> boolean, dayNumber: number)
	local eye = Config.eye
	local hunt = eye.hunt
	local world = WorldService.get()
	local bounds = boundsOf(world.bounds)
	-- La zone se choisit AU SIGNAL : c'est la que l'Oeil cherchera, et la
	-- radio de la Planque peut le dire a temps.
	local cx, cz, aimed = zoneCenter(bounds, dayNumber)
	-- La zone part avec le signal : ceux qui regardent par l'Oeil, depuis
	-- son Ventre, la voient et peuvent prevenir les autres.
	eyeState:FireAllClients({
		phase = "warning",
		seconds = eye.warningSeconds,
		zone = { x = cx, z = cz, size = eye.zoneSize },
	})
	if aimed and PlanqueService.has("radio") then
		LootService.broadcast(
			"La radio grésille : il va chercher du côté de " .. aimed.DisplayName,
			"danger"
		)
	end
	task.wait(eye.warningSeconds)
	if not stillCurrent() then
		return
	end

	groundY = world.bounds.Position.Y
	local globeCenter, pupilReach = eyeGeometry()
	-- Le bout de la pupille, tournee vers le point vise.
	local function aimFrom(x: number, z: number): Vector3
		local target = Vector3.new(x, groundY, z)
		return globeCenter + (target - globeCenter).Unit * pupilReach
	end
	local timeline = buildPath(bounds, HidingService.beginSweep(), cx, cz, dayNumber)

	eyeState:FireAllClients({ phase = "sweep", seconds = timeline.total })
	beam = makeBeam()
	sighting = nil
	local chaseSpeed = Growth.onDay(hunt.chaseSpeed, dayNumber)
	local memory = Growth.onDay(hunt.memorySeconds, dayNumber)
	local started = os.clock()
	local last = started
	-- Le temps du rateau n'avance que quand l'Oeil suit le rateau : une
	-- poursuite le met en pause, et il reprend la ou il s'etait arrete.
	local patternTime = 0
	local ripped = 0
	local bx, bz = Sweep.sample(timeline, 0)
	local mode = "pattern" -- "pattern" | "chase" | "return"
	while stillCurrent() do
		local now = os.clock()
		local dt = now - last
		last = now
		local target = sighting
		local targetRoot = target
			and target.player.Character
			and target.player.Character:FindFirstChild("HumanoidRootPart")
		local tracking = target ~= nil
			and now - target.at <= memory
			and targetRoot ~= nil
			and not HidingService.isHidden(target.player)
			and not CrewService.isTaken(target.player)
		if tracking and targetRoot and targetRoot:IsA("BasePart") then
			-- La traque : il fonce sur celui qu'il a vu.
			mode = "chase"
			bx, bz = Sweep.chaseStep(
				bx,
				bz,
				targetRoot.Position.X,
				targetRoot.Position.Z,
				chaseSpeed,
				dt
			)
		else
			local px, pz, reached = Sweep.sample(timeline, patternTime)
			if mode ~= "pattern" then
				-- Il a perdu sa proie : il revient a son rateau.
				mode = "return"
				bx, bz = Sweep.chaseStep(bx, bz, px, pz, eye.beamSpeed, dt)
				if math.abs(bx - px) < 1 and math.abs(bz - pz) < 1 then
					mode = "pattern"
				end
			else
				patternTime += dt
				px, pz, reached = Sweep.sample(timeline, patternTime)
				bx, bz = px, pz
				-- Arracher chaque cachette marquee au moment ou le regard
				-- l'atteint. A part : un toit tremble une seconde, et le regard
				-- ne doit pas s'arreter pendant ce temps.
				while ripped < reached do
					ripped += 1
					local spotId = timeline.points[ripped].spotId
					if spotId then
						task.spawn(HidingService.rip, spotId)
					end
				end
			end
		end
		looking = { x = bx, z = bz }
		eyePosition = aimFrom(bx, bz)
		placeBeam()
		if patternTime >= timeline.total or now - started >= hunt.maxSweepSeconds then
			break
		end
		RunService.Heartbeat:Wait()
	end
	sighting = nil

	looking = nil
	if beam then
		beam:Destroy()
		beam = nil
	end
	eyeState:FireAllClients({ phase = "idle" })
end

-- Une defaite coupe tout : plus de regard, plus de jauge.
function EyeService.reset()
	looking = nil
	if beam then
		beam:Destroy()
		beam = nil
	end
	table.clear(exposures)
	eyeState:FireAllClients({ phase = "idle" })
end

function EyeService.start()
	RunService.Heartbeat:Connect(function(dt: number)
		accumulated += dt
		if accumulated < Config.eye.checkSeconds then
			return
		end
		local step = accumulated
		accumulated = 0
		check(step)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		exposures[player] = nil
	end)
end

return EyeService
