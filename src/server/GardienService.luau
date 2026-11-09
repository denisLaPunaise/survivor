--!strict
--[[
	GardienService — le boss de la Banlieue, quete etape 5 (decide avec Josh
	le 9 novembre 2026, CONCEPT 12).

	- Il DORT au fond du tunnel sous la voie rapide, derriere une grille
	  fermee par une chaine. On fabrique un coupe-boulon a l'etabli, on coupe
	  la chaine (maintenir X, bruyant) : il se reveille. Entrer dans l'antre
	  le reveille aussi.
	- EVEILLE, il poursuit le joueur visible le plus proche : plus vite que la
	  marche, moins vite que la course. Deux coups mettent a terre. Il ne
	  meurt pas sous les coups.
	- Il a perdu tout le monde de vue trop longtemps : il RENTRE au nid et se
	  rendort. La nuit, il y est.
	- L'Oeil le voit comme un joueur (EyeService lit `target`), avec une jauge
	  bien plus longue : le garder sous le regard le fait ASPIRER. C'est la
	  fin du chapitre 1 : un ecran chez tous, puis la partie continue.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Survivor = ReplicatedStorage:WaitForChild("Survivor")
local Config = require(Survivor:WaitForChild("Config"))
local Remotes = Survivor:WaitForChild("Remotes")

local CombatService = require(script.Parent:WaitForChild("CombatService"))
local LootService = require(script.Parent:WaitForChild("LootService"))
local QuestService = require(script.Parent:WaitForChild("QuestService"))
local ReprisService = require(script.Parent:WaitForChild("ReprisService"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))
local WorldService = require(script.Parent:WaitForChild("WorldService"))

local GardienService = {}

type State = "none" | "asleep" | "awake" | "returning" | "gone"

local STEP = "repaire"

local state: State = "none"
local body: Model? = nil
local humanoid: Humanoid? = nil
local root: BasePart? = nil
local head: BasePart? = nil
local highlight: Highlight? = nil
local walkTrack: AnimationTrack? = nil
local idleTrack: AnimationTrack? = nil
local target: Player? = nil
local lastSeen = 0
-- La ou il a vu sa proie pour la derniere fois : il y va, pas ou elle est.
local lastSeenAt: Vector3? = nil
local lastAttack = 0
local lastMoved = 0
local lastPosition = Vector3.zero
local dayNumber = 0

-- La grille : ouverte ou non, et ou etaient ses morceaux.
local gateOpen = false
local doorHome: CFrame? = nil
local chainHome: { [BasePart]: CFrame } = {}
local chainPrompt: ProximityPrompt? = nil

local sight = RaycastParams.new()
sight.FilterType = Enum.RaycastFilterType.Exclude

local function say(message: string, kind: string?)
	LootService.broadcast(message, kind)
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
	local r = character and character:FindFirstChild("HumanoidRootPart")
	if r and r:IsA("BasePart") then
		return r
	end
	return nil
end

local function canSee(from: Vector3, to: BasePart): boolean
	local filter: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(filter, player.Character)
		end
	end
	if body then
		table.insert(filter, body)
	end
	sight.FilterDescendantsInstances = filter
	local hit = workspace:Raycast(from, to.Position - from, sight)
	return hit == nil or hit.Instance.Transparency >= Config.eye.seeThroughTransparency
end

-- Le point est-il dans l'antre (la boite du tunnel) ?
local function inDen(position: Vector3): boolean
	local den = WorldService.get().lair.inside
	local p = den.CFrame:PointToObjectSpace(position)
	local half = den.Size / 2
	return math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y + 2 and math.abs(p.Z) <= half.Z
end

local function setChainPrompt()
	local p = chainPrompt
	if p then
		p.Enabled = not gateOpen and QuestService.hasReached(STEP) and state ~= "gone"
	end
end

-- LA GRILLE : la porte pivote vers l'interieur, la chaine tombe.
local function openGate()
	if gateOpen then
		return
	end
	gateOpen = true
	setChainPrompt()
	local lair = WorldService.get().lair
	local door = lair.door
	local from = door:GetPivot()
	local box, size = door:GetBoundingBox()
	local hinge = CFrame.new((box * CFrame.new(0, 0, -size.Z / 2)).Position)
	local offset = hinge:Inverse() * from
	for part in chainHome do
		part.CFrame = CFrame.new(part.Position.X - 1, 0.6, part.Position.Z)
	end
	Sfx.at("toit", lair.chain.Position)
	task.spawn(function()
		local started = os.clock()
		while gateOpen do
			local t = math.clamp((os.clock() - started) / 1.5, 0, 1)
			door:PivotTo(hinge * CFrame.Angles(0, math.rad(100) * t * (2 - t), 0) * offset)
			if t >= 1 then
				break
			end
			RunService.Heartbeat:Wait()
		end
	end)
end

local function closeGate()
	gateOpen = false
	local home = doorHome
	if home then
		WorldService.get().lair.door:PivotTo(home)
	end
	for part, cf in chainHome do
		part.CFrame = cf
	end
	setChainPrompt()
end

local function playMoving(moving: boolean)
	local walk, idle = walkTrack, idleTrack
	if walk == nil or idle == nil then
		return
	end
	if moving and not walk.IsPlaying then
		idle:Stop(0.3)
		walk:Play(0.3, 1, Config.gardien.walkAnimationSpeed)
	elseif not moving and walk.IsPlaying then
		walk:Stop(0.4)
		idle:Play(0.4)
	end
end

local function sleepAtNest()
	local h, b = humanoid, body
	if h == nil or b == nil then
		return
	end
	state = "asleep"
	target = nil
	h.WalkSpeed = 0
	b:PivotTo(WorldService.get().lair.nest.CFrame)
	playMoving(false)
end

local function wake(by: Player?)
	if state ~= "asleep" and state ~= "returning" then
		return
	end
	local h = humanoid
	if h == nil then
		return
	end
	if state == "asleep" then
		say(Config.gardien.name .. " s'est réveillé !", "danger")
	end
	state = "awake"
	h.WalkSpeed = Config.gardien.speed
	lastSeen = os.clock()
	if by then
		target = by
		local character = by.Character
		lastSeenAt = if character then character:GetPivot().Position else nil
	end
end

-- Un Repris geant : le corps des Repris, a l'echelle, plus sombre, des yeux
-- de braise et une fumee epaisse.
local function spawn()
	local b = ReprisService.body()
	if b == nil then
		return
	end
	local g = Config.gardien
	b.Name = "Gardien"
	b:ScaleTo(g.scale)
	for _, part in b:GetDescendants() do
		if part:IsA("BasePart") and part.Name == "Oeil" then
			part.Color = Color3.fromRGB(255, 110, 60)
		elseif part:IsA("Smoke") then
			part.Opacity = 0.3
			part.Size = 4
			part.RiseVelocity = 3
		end
	end
	local torso = b:FindFirstChild("UpperTorso")
	if torso then
		local ember = Instance.new("PointLight")
		ember.Color = Color3.fromRGB(255, 90, 50)
		ember.Range = 18
		ember.Brightness = 0.6
		ember.Parent = torso
	end
	local h = b:FindFirstChildOfClass("Humanoid") :: Humanoid
	local r = b:FindFirstChild("HumanoidRootPart") :: BasePart
	h.WalkSpeed = 0
	h.DisplayName = g.name
	b:PivotTo(WorldService.get().lair.nest.CFrame)
	b.Parent = workspace
	r:SetNetworkOwner(nil)
	local mark = Instance.new("Highlight")
	mark.FillColor = Color3.fromRGB(255, 70, 40)
	mark.FillTransparency = 1
	mark.OutlineTransparency = 1
	mark.Parent = b
	local animator = h:FindFirstChildOfClass("Animator")
	if animator == nil then
		animator = Instance.new("Animator")
		animator.Parent = h
	end
	local walk = Instance.new("Animation")
	walk.AnimationId = "rbxassetid://" .. g.walkAnimation
	local idle = Instance.new("Animation")
	idle.AnimationId = "rbxassetid://" .. g.idleAnimation
	walkTrack = (animator :: Animator):LoadAnimation(walk)
	idleTrack = (animator :: Animator):LoadAnimation(idle)
	body, humanoid, root, highlight = b, h, r, mark
	head = b:FindFirstChild("Head") :: BasePart
	CombatService.registerTarget({
		root = r,
		-- Les coups ne le tuent pas : ils le reveillent, et se voient.
		hit = function(_damage: number, from: Player)
			local flash = Instance.new("Highlight")
			flash.FillColor = Color3.fromRGB(240, 230, 220)
			flash.FillTransparency = 0.5
			flash.OutlineTransparency = 1
			flash.Parent = b
			task.delay(0.12, function()
				flash:Destroy()
			end)
			wake(from)
		end,
	})
	sleepAtNest()
end

local function despawn()
	if root then
		CombatService.unregisterTarget(root :: BasePart)
	end
	if body then
		body:Destroy()
	end
	body, humanoid, root, head, highlight, walkTrack, idleTrack = nil, nil, nil, nil, nil, nil, nil
	target = nil
end

local function tick()
	local b, h, r, hd = body, humanoid, root, head
	if b == nil or h == nil or r == nil or hd == nil then
		return
	end
	local g = Config.gardien
	local now = os.clock()
	if state == "asleep" then
		for _, player in Players:GetPlayers() do
			local pr = huntable(player)
			if pr and inDen(pr.Position) then
				wake(player)
				return
			end
		end
		return
	end
	if state ~= "awake" and state ~= "returning" then
		return
	end

	-- Le plus proche qu'il voit.
	local best: Player? = nil
	local bestRoot: BasePart? = nil
	local bestDistance = g.chaseRadius
	for _, player in Players:GetPlayers() do
		local pr = huntable(player)
		if pr then
			local distance = (pr.Position - r.Position).Magnitude
			if distance <= bestDistance and canSee(hd.Position, pr) then
				best, bestRoot, bestDistance = player, pr, distance
			end
		end
	end
	if best then
		if state == "returning" then
			wake(best)
		end
		target = best
		lastSeen = now
		lastSeenAt = (bestRoot :: BasePart).Position
	end

	local chased = target
	local chasedRoot = chased and huntable(chased)
	if state == "awake" and chased and chasedRoot and now - lastSeen <= g.forgetSeconds then
		local distance = (chasedRoot.Position - r.Position).Magnitude
		if distance <= g.attackRange then
			h:MoveTo(r.Position)
			playMoving(false)
			if now - lastAttack >= g.attackSeconds then
				lastAttack = now
				CombatService.damagePlayer(chased, g.damage)
				Sfx.at("chute", r.Position)
			end
			return
		end
		-- Celui qu'il ne voit plus : il va la ou il l'a vu en dernier, et y
		-- cherche tant qu'il s'en souvient (il ne sait pas ou il est).
		local goal = if bestRoot then bestRoot.Position else lastSeenAt
		if
			goal == nil
			or Vector3.new(goal.X - r.Position.X, 0, goal.Z - r.Position.Z).Magnitude < 3
		then
			h:MoveTo(r.Position)
			playMoving(false)
			return
		end
		h:MoveTo(goal)
		playMoving(true)
		if (r.Position - lastPosition).Magnitude > 1 then
			lastPosition = r.Position
			lastMoved = now
		elseif now - lastMoved > g.stuckSeconds then
			h.Jump = true
			lastMoved = now
		end
		return
	end

	-- Plus personne : il rentre au nid, lentement, et s'y rendort.
	if state == "awake" then
		state = "returning"
		target = nil
		h.WalkSpeed = g.homeSpeed
	end
	local nest = WorldService.get().lair.nest.Position
	local flat = Vector3.new(nest.X - r.Position.X, 0, nest.Z - r.Position.Z)
	if flat.Magnitude < 4 then
		sleepAtNest()
	else
		h:MoveTo(nest)
		playMoving(true)
	end
end

-- Pour l'Oeil : sa tete et son corps quand il est dehors (eveille).
function GardienService.target(): (BasePart?, BasePart?)
	if state ~= "awake" and state ~= "returning" then
		return nil, nil
	end
	return head, root
end

function GardienService.model(): Model?
	return body
end

-- Sa jauge, vue de tous : il rougeoit d'autant plus que l'Oeil le tient.
function GardienService.showExposure(level: number)
	local mark = highlight
	if mark then
		mark.FillTransparency = 1 - level * 0.7
		mark.OutlineTransparency = 1 - level
	end
end

-- L'Oeil l'a aspire : la fin du chapitre.
function GardienService.take()
	if state ~= "awake" and state ~= "returning" then
		return
	end
	local b, r = body, root
	state = "gone"
	setChainPrompt()
	if r then
		CombatService.unregisterTarget(r)
	end
	body, humanoid, root, head, highlight, walkTrack, idleTrack = nil, nil, nil, nil, nil, nil, nil
	say("L'Œil a pris " .. Config.gardien.name .. " !", "quest")
	QuestService.notify("devoured:gardien")
	local chapter = Remotes:WaitForChild("Chapter") :: RemoteEvent
	chapter:FireAllClients({
		chapter = 1,
		days = dayNumber,
		seconds = Config.gardien.endScreenSeconds,
	})
	if b and r then
		Sfx.at("aspiration", r.Position)
		Sfx.at("cri", r.Position)
		for _, part in b:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = true
				part.CanCollide = false
			end
		end
		local g = Config.gardien
		local origin = b:GetPivot()
		local started = os.clock()
		local connection: RBXScriptConnection? = nil
		connection = RunService.Heartbeat:Connect(function()
			local t = math.clamp((os.clock() - started) / g.liftSeconds, 0, 1)
			-- Il se debat : il tremble en montant.
			local shake = (1 - t) * 0.6
			b:PivotTo(
				origin
					* CFrame.new(
						math.sin(t * 90) * shake,
						g.liftHeight * t * t,
						math.cos(t * 70) * shake
					)
					* CFrame.Angles(0, t * math.pi * 4, t * math.pi * 0.8)
			)
			if t >= 1 then
				if connection then
					connection:Disconnect()
				end
				b:Destroy()
			end
		end)
	end
end

local function onCut(player: Player)
	if gateOpen or state == "gone" or not QuestService.hasReached(STEP) then
		return
	end
	if not LootService.hasItem(player, "coupeboulon") then
		LootService.sendHud(player, "Il faut un coupe-boulon (à l'établi de la Planque).")
		return
	end
	openGate()
	say("La chaîne cède. Quelque chose bouge au fond du tunnel…", "danger")
	-- Le bruit le reveille : il sort chercher qui a fait ca.
	wake(player)
end

-- Le meme chemin que l'invite (les sondes ne declenchent pas les invites).
function GardienService.tryCut(player: Player)
	onCut(player)
end

function GardienService.state(): string
	return state
end

-- Appele par DayService a chaque aube, apres la quete.
function GardienService.dawn(day: number)
	dayNumber = day
	if state == "none" and QuestService.hasReached(STEP) then
		spawn()
	elseif state == "awake" or state == "returning" then
		sleepAtNest()
	end
	setChainPrompt()
end

-- La nuit : il est rentre dans son nid.
function GardienService.night()
	if state == "awake" or state == "returning" then
		sleepAtNest()
	end
end

-- Une defaite : tout recommence, grille fermee, Gardien absent jusqu'a ce
-- que l'etape revienne.
function GardienService.reset()
	despawn()
	state = "none"
	closeGate()
end

function GardienService.start()
	local lair = WorldService.get().lair
	doorHome = lair.door:GetPivot()
	chainHome[lair.chain] = lair.chain.CFrame
	local padlock = lair.gate:FindFirstChild("Cadenas")
	if padlock and padlock:IsA("BasePart") then
		chainHome[padlock] = padlock.CFrame
	end
	local onFoot = Config.controls.contexts.onFoot
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Couper la chaîne"
	prompt.ObjectText = "Grille"
	prompt.HoldDuration = Config.gardien.chainHoldSeconds
	prompt.MaxActivationDistance = Config.gardien.chainPromptDistance
	prompt.RequiresLineOfSight = false
	prompt.GamepadKeyCode = (Enum.KeyCode :: any)[onFoot.interact.gamepad]
	prompt.KeyboardKeyCode = (Enum.KeyCode :: any)[onFoot.interact.keyboard]
	prompt.Triggered:Connect(onCut)
	prompt.Parent = lair.chain
	chainPrompt = prompt
	setChainPrompt()
	task.spawn(function()
		while true do
			task.wait(0.15)
			local ok, err = pcall(tick)
			if not ok then
				warn("[Survivor] Gardien : " .. tostring(err))
			end
		end
	end)
end

return GardienService
