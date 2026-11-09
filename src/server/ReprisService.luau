--!strict
--[[
	ReprisService — ceux que l'Oeil a pris, et qui redescendent.

	LE JOUR, ils dorment dans une partie des maisons (Config.repris), et se
	reveillent au bruit : courir pres d'eux, fouiller dans la meme maison, ou
	les frôler. Reveilles, ils poursuivent le joueur visible le plus proche ;
	s'ils le perdent, ils se rendorment ou ils sont.

	LA NUIT, ils tombent de la Fissure, loin des joueurs, et convergent vers la
	Planque : c'est elle qu'il faudra defendre (point 3, la construction).

	Ils ne voient pas un joueur cache dans une cachette, ni un joueur a terre
	(ils passent au suivant), ni a travers un mur.

	SIX SORTES (Config.repris.kinds), dont quatre arrivent au fil des jours
	(Config.repris.arrivals, decide avec Josh) : le Hurleur crie et fait
	accourir les autres, le Rampant sent ceux qui sont caches tout pres et
	les en arrache, la Brute casse les barricades, le Guetteur perche sur les
	toits le jour et previent l'Oeil. Chacun a son corps (une tete generee,
	une silhouette), marche avec les animations Zombie de Roblox, et s'entend.
]]

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local Survivor = ReplicatedStorage:WaitForChild("Survivor")
local Config = require(Survivor:WaitForChild("Config"))
local Growth = require(Survivor:WaitForChild("Growth"))
local Repris = require(Survivor:WaitForChild("Repris"))

local CombatService = require(script.Parent:WaitForChild("CombatService"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))
local WorldService = require(script.Parent:WaitForChild("WorldService"))

local ReprisService = {}

type Look = {
	height: number,
	width: number,
	depth: number,
	scale: number,
	head: string,
	hump: string?,
	eyes: { number }?,
	bigEye: { number }?,
}

type Kind = {
	name: string,
	speed: number,
	health: number,
	damage: number,
	attackRange: number,
	attackSeconds: number,
	chaseRadius: number,
	obstacleFactor: number,
	run: boolean,
	scream: { radius: number, cooldown: number, freezeSeconds: number }?,
	sniffRadius: number?,
	alertCooldown: number?,
	look: Look,
}

type Agent = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	head: BasePart,
	kindId: string,
	kind: Kind,
	moveTrack: AnimationTrack?,
	idleTrack: AnimationTrack?,
	steps: Sound?,
	-- Le Hurleur : son dernier cri, et jusqu'a quand il se fige pour crier.
	lastScream: number,
	frozenUntil: number,
	-- Le Guetteur : la derniere fois qu'il a prevenu l'Oeil.
	lastAlert: number,
	health: number,
	mode: string, -- "dormant" | "hunting" | "roaming"
	night: boolean,
	target: Player?,
	lastSeen: number,
	lastAttack: number,
	lastPath: number,
	waypoints: { PathWaypoint },
	waypointIndex: number,
	pathGoal: Vector3?,
	-- Un chemin se calcule en tache de fond : la boucle ne l'attend pas.
	pathing: boolean,
	-- Pour le debloquer : ou il etait, depuis quand il n'avance plus, et
	-- jusqu'a quand il fait un pas de cote (et vers ou).
	stuckFrom: Vector3,
	stuckSince: number,
	sidestepUntil: number,
	sidestepTo: Vector3?,
	-- Ce qu'il est alle voir : l'endroit d'un bruit, ou ou il a vu sa cible
	-- pour la derniere fois.
	lead: Vector3?,
}

local random = Random.new()
local agents: { Agent } = {}
local folder: Folder? = nil
local templates: { [string]: Model } = {}
-- Ce qui sort un joueur de sa cachette (le Rampant) : fourni par le
-- Bootstrap (HidingService depend deja des Repris).
local unhide: ((Player) -> ())? = nil
-- Ceux qui veulent savoir qu'un Guetteur a vu quelqu'un (l'Oeil).
local watchListeners: { (Player) -> () } = {}
local noises: { { position: Vector3, kind: Repris.Noise, at: number } } = {}
-- Ce qui leur barre la route (la barricade de la Planque) : fourni par le
-- Bootstrap, pour que les Repris ne dependent pas de la Planque.
local obstacleNear: ((Vector3, number) -> ((number) -> ())?)? = nil

function ReprisService.setObstacleProvider(provider: (Vector3, number) -> ((number) -> ())?)
	obstacleNear = provider
end

function ReprisService.setUnhider(release: (Player) -> ())
	unhide = release
end

function ReprisService.onWatch(listener: (Player) -> ())
	table.insert(watchListeners, listener)
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function getFolder(): Folder
	local f = folder
	if f == nil or f.Parent == nil then
		f = Instance.new("Folder")
		f.Name = "Repris"
		f.Parent = workspace
		folder = f
	end
	return f :: Folder
end

-- Un morceau genere (ServerStorage.SurvivorModeles), soude a `to` a cette
-- place. Absent : on le dit une fois, le corps reste sans.
local missingWarned: { [string]: boolean } = {}
local function attach(
	model: Model,
	name: string,
	to: BasePart,
	at: CFrame,
	width: number
): BasePart?
	local store = ServerStorage:FindFirstChild("SurvivorModeles")
	local source = store and store:FindFirstChild(name)
	if source == nil or not source:IsA("BasePart") then
		if not missingWarned[name] then
			missingWarned[name] = true
			warn("[Survivor] Morceau de Repris absent : ServerStorage.SurvivorModeles." .. name)
		end
		return nil
	end
	local piece = source:Clone()
	-- A la largeur voulue, en gardant ses proportions.
	piece.Size = piece.Size * (width / piece.Size.X)
	piece.Anchored = false
	piece.CanCollide = false
	piece.CanQuery = false
	piece.CanTouch = false
	piece.Massless = true
	piece.CFrame = to.CFrame * at
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = to
	weld.Part1 = piece
	weld.Parent = piece
	piece.Parent = model
	return piece
end

local function glowingEye(model: Model, to: BasePart, at: CFrame, size: number, color: { number })
	local eye = Instance.new("Part")
	eye.Name = "Oeil"
	eye.Shape = Enum.PartType.Ball
	eye.Size = Vector3.one * size
	eye.Material = Enum.Material.Neon
	eye.Color = Color3.fromRGB(color[1], color[2], color[3])
	eye.CanCollide = false
	eye.CanQuery = false
	eye.CanTouch = false
	eye.Massless = true
	eye.CFrame = to.CFrame * at
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = to
	weld.Part1 = eye
	weld.Parent = eye
	eye.Parent = model
end

-- Un corps de Repris : un humain de cendre, decharne, une tete de crane
-- generee aux orbites qui luisent. Chaque sorte a ses proportions.
local function buildTemplate(look: Look): Model
	local description = Instance.new("HumanoidDescription")
	description.HeightScale = look.height
	description.WidthScale = look.width
	description.DepthScale = look.depth
	description.HeadScale = 0.85
	description.BodyTypeScale = 0
	description.ProportionScale = 0
	local ash = Color3.fromRGB(54, 52, 50)
	description.HeadColor = ash
	description.TorsoColor = ash:Lerp(Color3.new(0, 0, 0), 0.15)
	description.LeftArmColor = ash
	description.RightArmColor = ash
	description.LeftLegColor = ash:Lerp(Color3.new(0, 0, 0), 0.2)
	description.RightLegColor = ash:Lerp(Color3.new(0, 0, 0), 0.2)
	local model = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	model.Name = "Repris"
	-- Le script Animate des joueurs ne tourne pas sur un PNJ : le serveur
	-- joue lui-meme leurs animations.
	local animate = model:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end
	-- Une peau de cendre durcie.
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.Material = Enum.Material.Basalt
		end
	end
	local head = model:FindFirstChild("Head") :: BasePart
	-- La tete de Roblox disparait sous le crane genere ; elle reste pour la
	-- ligne de vue (ses yeux voient d'ici).
	for _, child in head:GetDescendants() do
		if child:IsA("Decal") or child:IsA("FaceControls") then
			child:Destroy()
		end
	end
	if head:IsA("MeshPart") then
		head.TextureID = ""
	end
	local skull =
		attach(model, look.head, head, CFrame.new(0, head.Size.Y * 0.1, 0), head.Size.X * 1.05)
	if skull then
		head.Transparency = 1
		-- Le crane genere a sa texture retiree : il prend la cendre du corps
		-- (la texture d'origine etait un crane de dessin anime, vu le 9
		-- novembre 2026).
		skull.TextureID = ""
		skull.Material = Enum.Material.Basalt
		skull.Color = ash
	end
	local face = skull or head
	if look.bigEye then
		glowingEye(
			model,
			face,
			CFrame.new(0, face.Size.Y * 0.08, -face.Size.Z * 0.4),
			face.Size.X * 0.38,
			look.bigEye
		)
	elseif look.eyes then
		for _, side in { -1, 1 } do
			glowingEye(
				model,
				face,
				CFrame.new(side * face.Size.X * 0.2, face.Size.Y * 0.08, -face.Size.Z * 0.36),
				face.Size.X * 0.13,
				look.eyes
			)
		end
	end
	local torso = model:FindFirstChild("UpperTorso") :: BasePart?
	if look.hump and torso then
		-- La bosse de gravats, sur le haut du dos, de la largeur des epaules.
		-- Sa texture d'origine (ferraille blanche et rouille) jurait avec la
		-- cendre du corps (vu le 9 novembre 2026) : elle prend sa couleur.
		local hump = attach(
			model,
			look.hump,
			torso,
			CFrame.new(0, torso.Size.Y * 0.2, torso.Size.Z * 0.5),
			torso.Size.X * 1.05
		)
		if hump then
			hump.TextureID = ""
			hump.Material = Enum.Material.Slate
			hump.Color = ash:Lerp(Color3.fromRGB(90, 60, 44), 0.35)
		end
	end
	-- Une fumee sombre qui s'echappe d'eux : ils sont faits de ce qui brule.
	if torso then
		local smoke = Instance.new("Smoke")
		smoke.Color = Color3.fromRGB(30, 28, 28)
		smoke.Opacity = 0.12
		smoke.Size = 1.2
		smoke.RiseVelocity = 1.5
		smoke.Parent = torso
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	if look.scale ~= 1 then
		model:ScaleTo(look.scale)
	end
	return model
end

local function templateFor(kindId: string): Model
	local cached = templates[kindId]
	if cached then
		return cached
	end
	local kind = (Config.repris.kinds :: any)[kindId] :: Kind
	local built = buildTemplate(kind.look)
	templates[kindId] = built
	return built
end

local function remove(agent: Agent, fade: boolean)
	local index = table.find(agents, agent)
	if index then
		table.remove(agents, index)
	end
	CombatService.unregisterTarget(agent.root)
	if fade then
		for _, part in agent.model:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = true
				part.CanCollide = false
				TweenService:Create(part, TweenInfo.new(1.2), { Transparency = 1 }):Play()
			end
		end
		task.delay(1.3, function()
			agent.model:Destroy()
		end)
	else
		agent.model:Destroy()
	end
end

local function wakeUp(agent: Agent, target: Player?, lead: Vector3?)
	if agent.kind.speed <= 0 then
		-- Le Guetteur ne descend pas de son toit.
		return
	end
	if agent.mode == "dormant" then
		agent.mode = "hunting"
		agent.humanoid.WalkSpeed = agent.kind.speed
		Sfx.at("grognement", agent.head)
	end
	-- Reveille par un bruit sans voir personne : il va voir d'ou il vient.
	agent.lastSeen = os.clock()
	if target then
		agent.target = target
	end
	if lead then
		agent.lead = lead
	end
end

local function spawnAgent(kindId: string, at: CFrame, night: boolean): Agent?
	local kind = (Config.repris.kinds :: any)[kindId] :: Kind
	local model = templateFor(kindId):Clone()
	model.Name = kind.name
	model:PivotTo(at)
	model.Parent = getFolder()
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local head = model:FindFirstChild("Head") :: BasePart
	humanoid.WalkSpeed = if night then kind.speed else 0
	if kind.speed <= 0 then
		-- Le Guetteur : fige sur son toit.
		root.Anchored = true
	else
		root:SetNetworkOwner(nil)
	end
	-- Leurs animations, jouees par le serveur ; leurs pas, qu'on entend de
	-- pres, plus graves pour les gros.
	local anims = Config.repris.animations
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator == nil then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	local function load(id: number): AnimationTrack
		local animation = Instance.new("Animation")
		animation.AnimationId = "rbxassetid://" .. id
		return (animator :: Animator):LoadAnimation(animation)
	end
	local moveTrack = load(if kind.run then anims.run else anims.walk)
	local idleTrack = load(anims.idle)
	idleTrack:Play()
	local steps: Sound? = nil
	if kind.speed > 0 then
		local entry = (Config.sounds.library :: any)["pas"]
		local sound = Instance.new("Sound")
		sound.Name = "Pas"
		sound.SoundId = "rbxassetid://" .. entry.id
		sound.Volume = entry.volume
		sound.Looped = true
		sound.PlaybackSpeed = 1.25 / kind.look.scale
		sound.RollOffMinDistance = Config.repris.stepsHeard.min
		sound.RollOffMaxDistance = Config.repris.stepsHeard.max
		sound.Parent = root
		steps = sound
	end
	local agent: Agent = {
		model = model,
		humanoid = humanoid,
		root = root,
		head = head,
		kindId = kindId,
		kind = kind,
		moveTrack = moveTrack,
		idleTrack = idleTrack,
		steps = steps,
		lastScream = -math.huge,
		frozenUntil = 0,
		lastAlert = -math.huge,
		health = kind.health,
		mode = if night then "roaming" else "dormant",
		night = night,
		target = nil,
		lastSeen = 0,
		lastAttack = 0,
		lastPath = 0,
		waypoints = {},
		waypointIndex = 0,
		pathGoal = nil,
		pathing = false,
		stuckFrom = at.Position,
		stuckSince = os.clock(),
		sidestepUntil = 0,
		sidestepTo = nil,
		lead = nil,
	}
	table.insert(agents, agent)
	CombatService.registerTarget({
		root = root,
		hit = function(damage: number, from: Player?)
			agent.health -= damage
			-- Un coup se voit : un eclair pâle.
			local flash = Instance.new("Highlight")
			flash.FillColor = Color3.fromRGB(240, 230, 220)
			flash.FillTransparency = 0.4
			flash.OutlineTransparency = 1
			flash.Parent = model
			task.delay(0.12, function()
				flash:Destroy()
			end)
			if agent.health <= 0 then
				remove(agent, true)
			else
				wakeUp(agent, from)
			end
		end,
	})
	return agent
end

-- Le bruit d'une fouille, d'une porte, d'un coup : reveille ceux qui dorment
-- a portee.
function ReprisService.noise(position: Vector3, kind: Repris.Noise)
	table.insert(noises, { position = position, kind = kind, at = os.clock() })
end

local function canSee(agent: Agent, target: BasePart): boolean
	local filter: { Instance } = { getFolder() }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(filter, player.Character)
		end
	end
	rayParams.FilterDescendantsInstances = filter
	local origin = agent.head.Position
	local hit = workspace:Raycast(origin, target.Position - origin, rayParams)
	if hit == nil then
		return true
	end
	-- Une vitre ou une part presque invisible ne cache personne.
	return hit.Instance.Transparency >= Config.eye.seeThroughTransparency
end

local function huntable(player: Player): BasePart?
	if
		player:GetAttribute("Hidden")
		or player:GetAttribute("Taken")
		or player:GetAttribute("Bound")
		or CombatService.isDowned(player)
	then
		return nil
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local pathWarned = false

local function moveTowards(agent: Agent, goal: Vector3)
	local now = os.clock()
	local r = Config.repris
	-- Coince contre un mur : il saute et fait un pas de cote, puis reprend.
	local sidestep = agent.sidestepTo
	if sidestep and now < agent.sidestepUntil then
		agent.humanoid:MoveTo(sidestep)
		return
	end
	if (agent.root.Position - agent.stuckFrom).Magnitude > 1 then
		agent.stuckFrom = agent.root.Position
		agent.stuckSince = now
	elseif now - agent.stuckSince > r.stuckSeconds then
		local angle = random:NextNumber(0, math.pi * 2)
		agent.sidestepTo = agent.root.Position
			+ Vector3.new(math.cos(angle), 0, math.sin(angle)) * 10
		agent.sidestepUntil = now + r.sidestepSeconds
		agent.stuckSince = now
		agent.humanoid.Jump = true
		-- Et son chemin se recalcule depuis la ou il sera.
		agent.pathGoal = nil
		return
	end
	-- De pres et en vue, tout droit ; sinon par un chemin, recalcule de temps
	-- en temps (les maisons ont des murs et des portes).
	local direct = (goal - agent.root.Position).Magnitude < 14
	if direct then
		agent.waypoints = {}
		agent.humanoid:MoveTo(goal)
		return
	end
	if
		not agent.pathing
		and (
			now - agent.lastPath >= r.repathSeconds
			or agent.pathGoal == nil
			or (agent.pathGoal - goal).Magnitude > 8
		)
	then
		agent.lastPath = now
		agent.pathGoal = goal
		agent.pathing = true
		local from = agent.root.Position
		-- Le calcul attend le moteur : fait dans la boucle, cent Repris la
		-- nuit la faisaient tourner une fois toutes les quelques secondes, et
		-- la plupart restaient plantes (vu le 9 novembre 2026).
		task.spawn(function()
			local shape = Config.repris.path
			local path = PathfindingService:CreatePath({
				AgentRadius = shape.radius,
				AgentHeight = shape.height,
				AgentCanJump = shape.canJump,
			})
			local ok, problem = pcall(function()
				path:ComputeAsync(from, goal)
			end)
			agent.pathing = false
			if ok and path.Status == Enum.PathStatus.Success then
				agent.waypoints = path:GetWaypoints()
				agent.waypointIndex = math.min(2, #agent.waypoints)
			else
				-- Pas de chemin : il fonce tout droit, comme une bete. Si c'est le
				-- moteur qui a echoue, on le dit (une fois).
				if not ok and not pathWarned then
					pathWarned = true
					warn("[Survivor] Calcul de chemin des Repris : " .. tostring(problem))
				end
				agent.waypoints = {}
			end
		end)
	end
	local waypoint = agent.waypoints[agent.waypointIndex]
	if waypoint then
		if
			(waypoint.Position - agent.root.Position).Magnitude < 3
			and agent.waypointIndex < #agent.waypoints
		then
			agent.waypointIndex += 1
			waypoint = agent.waypoints[agent.waypointIndex]
		end
		agent.humanoid:MoveTo(waypoint.Position)
	else
		agent.humanoid:MoveTo(goal)
	end
end

-- Marche ou repos, et ses pas : d'apres sa vitesse reelle au sol.
local function animate(agent: Agent)
	local velocity = agent.root.AssemblyLinearVelocity
	local moving = Vector3.new(velocity.X, 0, velocity.Z).Magnitude > 1.5
	local move, idle = agent.moveTrack, agent.idleTrack
	if move and idle then
		if moving and not move.IsPlaying then
			idle:Stop(0.25)
			move:Play(0.25)
		elseif not moving and move.IsPlaying then
			move:Stop(0.3)
			idle:Play(0.3)
		end
	end
	local steps = agent.steps
	if steps then
		if moving and not steps.IsPlaying then
			steps:Play()
		elseif not moving and steps.IsPlaying then
			steps:Stop()
		end
	end
end

-- Le Hurleur crie : tout ce qui dort ou rode a portee accourt vers celui
-- qu'il a vu.
local function scream(agent: Agent, target: Player, at: Vector3, now: number)
	local s = agent.kind.scream
	if s == nil or now - agent.lastScream < s.cooldown then
		return
	end
	agent.lastScream = now
	agent.frozenUntil = now + s.freezeSeconds
	agent.humanoid:MoveTo(agent.root.Position)
	Sfx.at("hurlement", agent.head)
	for _, other in agents do
		if other ~= agent and (other.root.Position - agent.root.Position).Magnitude <= s.radius then
			wakeUp(other, target, at)
		end
	end
end

-- Le Guetteur, sur son toit : il voit, il crie, il previent l'Oeil.
local function watch(agent: Agent, now: number)
	local cooldown = agent.kind.alertCooldown
	if cooldown == nil or now - agent.lastAlert < cooldown then
		return
	end
	for _, player in Players:GetPlayers() do
		local root = huntable(player)
		if
			root
			and (root.Position - agent.root.Position).Magnitude <= agent.kind.chaseRadius
			and canSee(agent, root)
		then
			agent.lastAlert = now
			Sfx.at("guet", agent.head)
			for _, listener in watchListeners do
				task.spawn(listener, player)
			end
			return
		end
	end
end

-- Le Rampant : un joueur cache tout pres, il le sent et va l'arracher.
local function sniff(agent: Agent): (Player?, BasePart?)
	local radius = agent.kind.sniffRadius
	if radius == nil then
		return nil, nil
	end
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if
			player:GetAttribute("Hidden")
			and root
			and root:IsA("BasePart")
			and (root.Position - agent.root.Position).Magnitude <= radius
		then
			return player, root
		end
	end
	return nil, nil
end

local function think(agent: Agent, now: number)
	local r = Config.repris
	if agent.model.Parent == nil then
		remove(agent, false)
		return
	end
	animate(agent)
	if agent.kind.speed <= 0 then
		watch(agent, now)
		return
	end
	if now < agent.frozenUntil then
		return
	end

	if agent.mode == "dormant" then
		for _, player in Players:GetPlayers() do
			local root = huntable(player)
			if root then
				local distance = (root.Position - agent.root.Position).Magnitude
				-- Courir fait du bruit : on le lit a la vitesse au sol.
				local flatSpeed = Vector3.new(
					root.AssemblyLinearVelocity.X,
					0,
					root.AssemblyLinearVelocity.Z
				).Magnitude
				local noise: Repris.Noise = if flatSpeed > Config.movement.walkSpeed + 3
					then "sprint"
					else "none"
				if Repris.wakes(r.wake, distance, noise) then
					wakeUp(agent, player)
					return
				end
			end
		end
		for _, n in noises do
			if Repris.wakes(r.wake, (n.position - agent.root.Position).Magnitude, n.kind) then
				wakeUp(agent, nil, n.position)
				return
			end
		end
		return
	end

	-- Une barricade devant lui : il frappe dedans jusqu'a ce qu'elle cede.
	local provider = obstacleNear
	local obstacle = provider and provider(agent.root.Position, agent.kind.attackRange + 2)
	if obstacle then
		agent.humanoid:MoveTo(agent.root.Position)
		if now - agent.lastAttack >= agent.kind.attackSeconds then
			agent.lastAttack = now
			obstacle(agent.kind.damage * agent.kind.obstacleFactor)
			Sfx.at("coup", agent.root)
		end
		return
	end

	-- Le Rampant : quelqu'un se cache tout pres. Il y va, et l'en arrache.
	local hiddenPlayer, hiddenRoot = sniff(agent)
	if hiddenPlayer and hiddenRoot then
		if agent.mode == "dormant" then
			wakeUp(agent, hiddenPlayer, hiddenRoot.Position)
		end
		local distance = (hiddenRoot.Position - agent.root.Position).Magnitude
		if distance <= agent.kind.attackRange + 2 then
			local release = unhide
			if release then
				release(hiddenPlayer)
			end
			agent.target = hiddenPlayer
			agent.lastSeen = now
		else
			moveTowards(agent, hiddenRoot.Position)
			return
		end
	end

	-- Eveille : choisir une cible parmi ceux qu'il voit.
	local candidates: { Repris.Candidate } = {}
	local roots: { [Player]: BasePart } = {}
	for _, player in Players:GetPlayers() do
		local root = huntable(player)
		if root then
			roots[player] = root
			local distance = (root.Position - agent.root.Position).Magnitude
			table.insert(candidates, {
				id = player,
				distance = distance,
				visible = distance <= agent.kind.chaseRadius and canSee(agent, root),
			})
		end
	end
	local seen = Repris.pickTarget(candidates, agent.kind.chaseRadius)
	if seen then
		agent.target = seen
		agent.lastSeen = now
		local seenRoot = roots[seen]
		if seenRoot then
			agent.lead = seenRoot.Position
			scream(agent, seen, seenRoot.Position, now)
		end
	end

	local target = agent.target
	local targetRoot = target and roots[target]
	if target and targetRoot and now - agent.lastSeen <= r.forgetSeconds then
		local distance = (targetRoot.Position - agent.root.Position).Magnitude
		if distance <= agent.kind.attackRange then
			agent.humanoid:MoveTo(agent.root.Position)
			if now - agent.lastAttack >= agent.kind.attackSeconds then
				agent.lastAttack = now
				CombatService.damagePlayer(target, agent.kind.damage)
				Sfx.at("coup", targetRoot)
			end
		else
			moveTowards(agent, targetRoot.Position)
		end
		return
	end

	-- Plus de cible en vue : il va encore voir la ou il l'a vue (ou entendue)
	-- pendant `forgetSeconds`, puis abandonne.
	local lead = agent.lead
	if lead and now - agent.lastSeen <= r.forgetSeconds then
		if (lead - agent.root.Position).Magnitude > 3 then
			moveTowards(agent, lead)
			return
		end
	end
	agent.lead = nil
	agent.target = nil
	if agent.night then
		-- La nuit, ils convergent vers la Planque.
		agent.mode = "roaming"
		moveTowards(agent, WorldService.get().spawn.Position)
	else
		-- Le jour, il se rendort la ou il est.
		agent.mode = "dormant"
		agent.humanoid.WalkSpeed = 0
		agent.humanoid:MoveTo(agent.root.Position)
	end
end

-- Les Guetteurs, a partir de leur jour : chacun perche au faite d'un toit
-- encore entier, la ou il voit loin.
local function perchWatchers(dayNumber: number)
	local r = Config.repris
	if dayNumber < r.arrivals.guetteur.fromDay then
		return
	end
	local count = math.floor(Growth.onDay(r.perches, dayNumber))
	local world = WorldService.get()
	local houses: { Model } = {}
	for _, house in world.root:GetDescendants() do
		if house:IsA("Model") and house:GetAttribute(Config.world.buildingAttribute) == true then
			table.insert(houses, house)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { getFolder() }
	local placed = 0
	for _ = 1, count * 10 do
		if placed >= count or #houses == 0 then
			break
		end
		local house = table.remove(houses, random:NextInteger(1, #houses)) :: Model
		local top = house:GetPivot().Position
		local hit = workspace:Raycast(top + Vector3.new(0, 80, 0), Vector3.new(0, -120, 0), params)
		-- Un toit (au-dessus d'un etage), pas un trou jusqu'au plancher.
		if
			hit
			and hit.Position.Y > 6
			and (hit.Position - world.spawn.Position).Magnitude > r.outdoorMinPlanqueDistance
		then
			local kind = r.kinds.guetteur
			local stand = hit.Position + Vector3.new(0, 3.2 * kind.look.scale, 0)
			spawnAgent(
				"guetteur",
				CFrame.new(stand) * CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0),
				false
			)
			placed += 1
		end
	end
end

-- Le matin : les Repris de la nuit se dissipent, d'autres s'endorment dans
-- une partie des maisons.
function ReprisService.newDay(dayNumber: number)
	for i = #agents, 1, -1 do
		remove(agents[i], agents[i].night)
	end
	local r = Config.repris
	local world = WorldService.get()
	-- Les sortes deja arrivees, parmi les endormis du jour.
	local dayShares = Repris.shares(r.arrivals, dayNumber, false)
	local function dayKind(): string
		return Repris.pickKind(dayShares, random:NextNumber(), "errant")
	end
	local candidates: { BasePart } = {}
	for _, house in world.root:GetDescendants() do
		if house:IsA("Model") and house:GetAttribute(Config.world.buildingAttribute) == true then
			local floor = house:FindFirstChild("Plancher")
			if floor and floor:IsA("BasePart") then
				table.insert(candidates, floor)
			end
		end
	end
	local count = math.floor(#candidates * Growth.onDay(r.day.houseShare, dayNumber) + 0.5)
	for _ = 1, count do
		if #candidates == 0 then
			break
		end
		local floor = table.remove(candidates, random:NextInteger(1, #candidates)) :: BasePart
		for _ = 1, random:NextInteger(r.dormantPerHouse.min, r.dormantPerHouse.max) do
			local offset = Vector3.new(
				random:NextNumber(-floor.Size.X / 2 + 3, floor.Size.X / 2 - 3),
				3.2,
				random:NextNumber(-floor.Size.Z / 2 + 3, floor.Size.Z / 2 - 3)
			)
			local at = CFrame.new(floor.Position + offset)
				* CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0)
			spawnAgent(dayKind(), at, false)
		end
	end
	-- Dehors : debout dans une rue ou un jardin, sur le sol (pas sur un toit).
	local bounds = world.bounds
	local half = bounds.Size / 2
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { getFolder() }
	local placed = 0
	local outdoor = math.floor(Growth.onDay(r.day.outdoor, dayNumber))
	for _ = 1, outdoor * 10 do
		if placed >= outdoor then
			break
		end
		local x = bounds.Position.X + random:NextNumber(-half.X, half.X)
		local z = bounds.Position.Z + random:NextNumber(-half.Z, half.Z)
		local hit = workspace:Raycast(Vector3.new(x, 80, z), Vector3.new(0, -120, 0), params)
		if
			hit
			and hit.Position.Y < 1.5
			and (hit.Position - world.spawn.Position).Magnitude > r.outdoorMinPlanqueDistance
		then
			local at = CFrame.new(hit.Position + Vector3.new(0, 3.2, 0))
				* CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0)
			spawnAgent(dayKind(), at, false)
			placed += 1
		end
	end
	perchWatchers(dayNumber)
end

-- La nuit : une vague tombe de la Fissure, loin des joueurs.
-- `extra` : ceux qu'attire la Planque (sa Visibilite).
function ReprisService.beginNight(nightNumber: number, extra: number)
	local r = Config.repris
	local world = WorldService.get()
	local bounds = world.bounds
	local half = bounds.Size / 2
	local players = Players:GetPlayers()
	local count = math.min(Repris.waveSize(r.night, nightNumber, #players) + extra, r.night.max)
	local runners = Repris.runnerShare(r.night, nightNumber)
	-- Les Guetteurs descendent de leurs toits et disparaissent : ce sont
	-- des yeux du jour.
	for i = #agents, 1, -1 do
		if agents[i].kind.speed <= 0 then
			remove(agents[i], true)
		end
	end
	-- La part de chaque sorte dans la vague : les Coureurs, puis ceux qui
	-- sont arrives.
	local shares = Repris.shares(r.arrivals, nightNumber, true)
	table.insert(shares, 1, { id = "coureur", share = runners })
	-- Les endormis du jour se reveillent : ils sont de la nuit aussi.
	for _, agent in agents do
		agent.night = true
		wakeUp(agent, nil)
		agent.mode = "roaming"
	end
	for _ = 1, count do
		local at: Vector3? = nil
		for _ = 1, 20 do
			local candidate = bounds.Position
				+ Vector3.new(
					random:NextNumber(-half.X, half.X),
					r.spawnHeight,
					random:NextNumber(-half.Z, half.Z)
				)
			local farEnough = true
			for _, player in players do
				local character = player.Character
				if
					character
					and (character:GetPivot().Position - candidate).Magnitude
						< r.spawnMinDistance
				then
					farEnough = false
				end
			end
			if farEnough then
				at = candidate
				break
			end
		end
		if at then
			spawnAgent(Repris.pickKind(shares, random:NextNumber(), "errant"), CFrame.new(at), true)
		end
	end
end

-- Un Repris qui jaillit d'une cachette qu'on ouvre.
function ReprisService.ambush(at: CFrame, victim: Player)
	local agent = spawnAgent("errant", at, false)
	if agent then
		wakeUp(agent, victim, nil)
	end
end

function ReprisService.count(): number
	return #agents
end

-- Un corps de Repris neuf, pour qui en fait autre chose (le Gardien : le
-- meme, en geant). Nil avant le demarrage.
function ReprisService.body(): Model?
	return templateFor("errant"):Clone()
end

function ReprisService.clear()
	for i = #agents, 1, -1 do
		remove(agents[i], false)
	end
end

function ReprisService.start()
	-- Les corps de chaque sorte, prepares une fois : les cloner est
	-- instantane, les construire non.
	for kindId in Config.repris.kinds do
		templateFor(kindId)
	end
	task.spawn(function()
		while true do
			local now = os.clock()
			-- Un bruit ne reveille que dans la seconde ou il a lieu.
			for i = #noises, 1, -1 do
				if now - noises[i].at > 1 then
					table.remove(noises, i)
				end
			end
			for i = #agents, 1, -1 do
				local agent = agents[i]
				if agent then
					local ok, problem = pcall(think, agent, now)
					if not ok then
						warn("[Survivor] Repris : " .. tostring(problem))
					end
				end
			end
			task.wait(Config.repris.thinkSeconds)
		end
	end)
end

return ReprisService
