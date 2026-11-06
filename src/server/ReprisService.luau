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
]]

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Survivor = ReplicatedStorage:WaitForChild("Survivor")
local Config = require(Survivor:WaitForChild("Config"))
local Growth = require(Survivor:WaitForChild("Growth"))
local Repris = require(Survivor:WaitForChild("Repris"))

local CombatService = require(script.Parent:WaitForChild("CombatService"))
local WorldService = require(script.Parent:WaitForChild("WorldService"))

local ReprisService = {}

type Kind = {
	name: string,
	speed: number,
	health: number,
	damage: number,
	attackRange: number,
	attackSeconds: number,
	chaseRadius: number,
}

type Agent = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	head: BasePart,
	kind: Kind,
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
	-- Ce qu'il est alle voir : l'endroit d'un bruit, ou ou il a vu sa cible
	-- pour la derniere fois.
	lead: Vector3?,
}

local random = Random.new()
local agents: { Agent } = {}
local folder: Folder? = nil
local template: Model? = nil
local noises: { { position: Vector3, kind: Repris.Noise, at: number } } = {}
-- Ce qui leur barre la route (la barricade de la Planque) : fourni par le
-- Bootstrap, pour que les Repris ne dependent pas de la Planque.
local obstacleNear: ((Vector3, number) -> ((number) -> ())?)? = nil

function ReprisService.setObstacleProvider(provider: (Vector3, number) -> ((number) -> ())?)
	obstacleNear = provider
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

-- Un corps de Repris : un humain decolore, maigre, sans visage, aux yeux pâles.
local function buildTemplate(): Model
	local description = Instance.new("HumanoidDescription")
	-- Plus grands et plus maigres qu'un joueur : on les reconnait de loin a la
	-- silhouette. Un mannequin gris de Roblox ne faisait pas peur (vu en jeu
	-- le 5 novembre 2026).
	description.HeightScale = 1.15
	description.WidthScale = 0.7
	description.DepthScale = 0.75
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
	-- Une peau de cendre durcie.
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.Material = Enum.Material.Basalt
		end
	end
	local head = model:FindFirstChild("Head") :: BasePart
	-- Pas de visage : le sourire par defaut de Roblox etait encore la sous les
	-- yeux (vu en jeu le 5 novembre 2026). Il peut etre un Decal ou la texture
	-- de la tete elle-meme.
	for _, child in head:GetDescendants() do
		if child:IsA("Decal") or child:IsA("FaceControls") then
			child:Destroy()
		end
	end
	if head:IsA("MeshPart") then
		head.TextureID = ""
	end
	for _, side in { -1, 1 } do
		local eye = Instance.new("Part")
		eye.Name = "Oeil"
		eye.Shape = Enum.PartType.Ball
		-- Petits et un peu enfonces : de gros yeux blancs faisaient dessin
		-- anime (vu en jeu).
		eye.Size = Vector3.new(0.14, 0.14, 0.14)
		eye.Material = Enum.Material.Neon
		eye.Color = Color3.fromRGB(214, 196, 170)
		eye.CanCollide = false
		eye.CanQuery = false
		eye.Massless = true
		eye.CFrame = head.CFrame * CFrame.new(side * 0.2, 0.08, -head.Size.Z / 2 + 0.04)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = eye
		weld.Parent = eye
		eye.Parent = model
	end
	-- Une fumee sombre qui s'echappe d'eux : ils sont faits de ce qui brule.
	local torso = model:FindFirstChild("UpperTorso")
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
	return model
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
	if agent.mode == "dormant" then
		agent.mode = "hunting"
		agent.humanoid.WalkSpeed = agent.kind.speed
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
	local base = template
	if base == nil then
		return nil
	end
	local kind = (Config.repris.kinds :: any)[kindId] :: Kind
	local model = base:Clone()
	model.Name = kind.name
	model:PivotTo(at)
	model.Parent = getFolder()
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local head = model:FindFirstChild("Head") :: BasePart
	humanoid.WalkSpeed = if night then kind.speed else 0
	root:SetNetworkOwner(nil)
	local agent: Agent = {
		model = model,
		humanoid = humanoid,
		root = root,
		head = head,
		kind = kind,
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
		lead = nil,
	}
	table.insert(agents, agent)
	CombatService.registerTarget({
		root = root,
		hit = function(damage: number, from: Player)
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

local function moveTowards(agent: Agent, goal: Vector3)
	local now = os.clock()
	local r = Config.repris
	-- De pres et en vue, tout droit ; sinon par un chemin, recalcule de temps
	-- en temps (les maisons ont des murs et des portes).
	local direct = (goal - agent.root.Position).Magnitude < 14
	if direct then
		agent.waypoints = {}
		agent.humanoid:MoveTo(goal)
		return
	end
	if
		now - agent.lastPath >= r.repathSeconds
		or agent.pathGoal == nil
		or (agent.pathGoal - goal).Magnitude > 8
	then
		agent.lastPath = now
		agent.pathGoal = goal
		local path = PathfindingService:CreatePath({
			AgentRadius = 2,
			AgentHeight = 5.5,
			AgentCanJump = false,
		})
		local ok = pcall(function()
			path:ComputeAsync(agent.root.Position, goal)
		end)
		if ok and path.Status == Enum.PathStatus.Success then
			agent.waypoints = path:GetWaypoints()
			agent.waypointIndex = math.min(2, #agent.waypoints)
		else
			-- Pas de chemin : il fonce tout droit, comme une bete.
			agent.waypoints = {}
		end
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

local function think(agent: Agent, now: number)
	local r = Config.repris
	if agent.model.Parent == nil then
		remove(agent, false)
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
			obstacle(agent.kind.damage)
		end
		return
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

-- Le matin : les Repris de la nuit se dissipent, d'autres s'endorment dans
-- une partie des maisons.
function ReprisService.newDay(dayNumber: number)
	for i = #agents, 1, -1 do
		remove(agents[i], agents[i].night)
	end
	local r = Config.repris
	local world = WorldService.get()
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
			spawnAgent("errant", at, false)
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
			spawnAgent("errant", at, false)
			placed += 1
		end
	end
end

-- La nuit : une vague tombe de la Fissure, loin des joueurs.
function ReprisService.beginNight(nightNumber: number)
	local r = Config.repris
	local world = WorldService.get()
	local bounds = world.bounds
	local half = bounds.Size / 2
	local players = Players:GetPlayers()
	local count = Repris.waveSize(r.night, nightNumber, #players)
	local runners = Repris.runnerShare(r.night, nightNumber)
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
			spawnAgent(
				if random:NextNumber() < runners then "coureur" else "errant",
				CFrame.new(at),
				true
			)
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

function ReprisService.clear()
	for i = #agents, 1, -1 do
		remove(agents[i], false)
	end
end

function ReprisService.start()
	template = buildTemplate()
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
