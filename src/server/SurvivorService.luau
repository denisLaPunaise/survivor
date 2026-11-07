--!strict
--[[
	SurvivorService — le survivant de la quete, etape 3 (decide avec Josh le
	7 novembre 2026, CONCEPT 12).

	- Il attend dans un REFUGE (un par partie, parmi ceux de la recette) :
	  Mara le decrit a la radio, rien n'est marque a l'ecran. Tant qu'on ne
	  l'a pas trouve, il est terre au fond et l'Oeil ne le voit pas.
	- On le TROUVE (maintenir X) : il suit celui qui l'a trouve, son guide,
	  en boitant (plus lent que la marche).
	- On le CACHE soi-meme : X sur lui, il va a la cachette libre la plus
	  proche ; X sur lui cache, il ressort et suit celui qui l'a fait sortir.
	  Dehors, l'Oeil le voit comme un joueur (EyeService lit `target`).
	- ASPIRE, il est recrache ailleurs : Mara redit ou il se cache la nuit,
	  il attend dans un autre refuge au matin.
	- A la PLANQUE, la quete avance ; il y reste et mange chaque nuit un plat
	  de la reserve, comme un joueur.
	- A partir de l'etape 4, s'il a mange, il FABRIQUE des fumigenes la nuit
	  avec la reserve (Config.smoke.recipe) ; au matin, on les lui prend (X).

	Une seule invite (X), dont le texte suit ce qu'il fait : une invite par
	bouton, la plus proche (celle des cachettes reste a portee).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Survivor = ReplicatedStorage:WaitForChild("Survivor")
local Config = require(Survivor:WaitForChild("Config"))
local Planque = require(Survivor:WaitForChild("Planque"))

local CrewService = require(script.Parent:WaitForChild("CrewService"))
local HidingService = require(script.Parent:WaitForChild("HidingService"))
local LootService = require(script.Parent:WaitForChild("LootService"))
local QuestService = require(script.Parent:WaitForChild("QuestService"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))
local WorldService = require(script.Parent:WaitForChild("WorldService"))

local SurvivorService = {}

type State = "absent" | "waiting" | "following" | "going" | "hidden" | "home"

local STEP = "survivant"
local SMOKE_STEP = "fumigene"
local random = Random.new()

local state: State = "absent"
local refuge: BasePart? = nil
local character: Model? = nil
local humanoid: Humanoid? = nil
local root: BasePart? = nil
local prompt: ProximityPrompt? = nil
local walkTrack: AnimationTrack? = nil
local idleTrack: AnimationTrack? = nil
local guide: Player? = nil
-- La cachette ou il va (ou il est) et la sortie par ou il y entre.
local spotId: string? = nil
local spotExit: BasePart? = nil
local goingSince = 0
-- Chasse de sa cachette : l'Oeil le laisse courir un instant.
local graceUntil = 0
-- Il a dit a son guide qu'il ne suivait plus (une fois, pas a chaque pas).
local toldLost = false
-- Deja trouve : s'il attend un nouveau guide, il attend dehors, a la vue de
-- l'Oeil (avant, il est terre au fond de son refuge).
local found = false
-- Les pas de son guide, du plus ancien au plus recent (voir LA TRACE).
local trail: { Vector3 } = {}
-- Les fumigenes qu'il a faits et qu'on ne lui a pas encore pris.
local smokes = 0

local function name(): string
	return Config.survivor.name
end

local function say(message: string, kind: string?)
	LootService.broadcast(message, kind)
end

local function setPrompt(text: string?, hold: number?)
	local p = prompt
	if p == nil then
		return
	end
	p.Enabled = text ~= nil
	if text then
		p.ActionText = text
		p.HoldDuration = hold or 0
	end
end

local function stop()
	local h, r = humanoid, root
	if h and r then
		h:MoveTo(r.Position)
	end
end

local function chooseRefuge()
	local refuges = WorldService.get().refuges
	local pool: { BasePart } = {}
	for _, candidate in refuges do
		if candidate ~= refuge then
			table.insert(pool, candidate)
		end
	end
	refuge = pool[random:NextInteger(1, #pool)]
	local clue = (refuge :: BasePart):GetAttribute(Config.world.refugeClue) :: string
	QuestService.setValue("indice", clue)
end

local function despawn()
	if character then
		character:Destroy()
	end
	character, humanoid, root, prompt, walkTrack, idleTrack = nil, nil, nil, nil, nil, nil
	guide, spotId, spotExit = nil, nil, nil
end

-- Un homme ordinaire, la veste sale et la jambe bandee.
local function makeCharacter(): Model?
	local look = Config.survivor.look
	local function rgb(c: { number }): Color3
		return Color3.fromRGB(c[1], c[2], c[3])
	end
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = rgb(look.skin)
	description.LeftArmColor = rgb(look.skin)
	description.RightArmColor = rgb(look.skin)
	description.TorsoColor = rgb(look.jacket)
	description.LeftLegColor = rgb(look.trousers)
	description.RightLegColor = rgb(look.trousers)
	local ok, result = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok then
		warn("[Survivor] Le survivant ne se construit pas : " .. tostring(result))
		return nil
	end
	local model = result :: Model
	model.Name = "Survivant"
	-- Un script Animate de joueur ne tourne pas sur un PNJ : le serveur joue
	-- sa marche lui-meme.
	local animate = model:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end
	-- Une part soudee a un membre, decalee de `offset` dans son repere.
	local function wear(
		limbName: string,
		partName: string,
		shape: Enum.PartType,
		size: Vector3,
		offset: CFrame,
		color: { number }
	)
		local limb = model:FindFirstChild(limbName)
		if not (limb and limb:IsA("BasePart")) then
			return
		end
		local part = Instance.new("Part")
		part.Name = partName
		part.Shape = shape
		part.Size = size
		part.CFrame = limb.CFrame * offset
		part.Color = rgb(color)
		part.Material = Enum.Material.Fabric
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = limb
		weld.Part1 = part
		weld.Parent = part
		part.Parent = model
	end
	local leg = model:FindFirstChild("RightLowerLeg") :: BasePart
	wear(
		"RightLowerLeg",
		"Bandage",
		Enum.PartType.Block,
		Vector3.new(leg.Size.X + 0.12, 0.5, leg.Size.Z + 0.12),
		CFrame.new(),
		look.bandage
	)
	-- Le bonnet : une boule (sphere du plus petit cote) posee haut sur la tete.
	wear(
		"Head",
		"Bonnet",
		Enum.PartType.Ball,
		Vector3.one * 1.3,
		CFrame.new(0, 0.38, 0.05),
		look.cap
	)
	-- L'echarpe autour du cou, et le sac dans le dos (l'avant est -Z).
	wear(
		"UpperTorso",
		"Echarpe",
		Enum.PartType.Block,
		Vector3.new(1.4, 0.4, 1.15),
		CFrame.new(0, 0.75, 0),
		look.scarf
	)
	wear(
		"UpperTorso",
		"Sac",
		Enum.PartType.Block,
		Vector3.new(1.4, 1.5, 0.7),
		CFrame.new(0, 0.05, 0.8),
		look.pack
	)
	return model
end

-- A la Planque, son invite propose ses fumigenes (s'il en a).
local function homePrompt()
	if state ~= "home" then
		return
	end
	if smokes > 0 then
		setPrompt(string.format("Prendre un fumigène (%d)", smokes))
	else
		setPrompt(nil)
	end
end

local function onPrompt(player: Player)
	if player:GetAttribute("Taken") or player:GetAttribute("Bound") then
		return
	end
	if state == "waiting" then
		guide = player
		table.clear(trail)
		found = true
		toldLost = false
		state = "following"
		setPrompt("Cacher " .. name())
		say(
			string.format(
				"%s a trouvé %s. Ramenez-le à la Planque : il boite, cachez-le quand le ciel rougit.",
				player.DisplayName,
				name()
			),
			"quest"
		)
	elseif state == "following" then
		local r = root
		if r == nil then
			return
		end
		local id, exit = HidingService.freeSpotNear(r.Position, Config.survivor.hideRadius)
		if id == nil or exit == nil then
			LootService.sendHud(player, "Pas de cachette libre près de " .. name() .. ".")
			return
		end
		spotId, spotExit = id, exit
		goingSince = os.clock()
		state = "going"
		setPrompt(nil)
	elseif state == "home" then
		if smokes > 0 and LootService.giveItem(player, "fumigene") then
			smokes -= 1
			homePrompt()
		end
	elseif state == "hidden" then
		local id = spotId
		local exit = if id then HidingService.releaseGuest(id) else nil
		spotId, spotExit = nil, nil
		local r = root
		if r then
			r.Anchored = false
			if exit then
				r.CFrame = exit
			end
		end
		guide = player
		table.clear(trail)
		toldLost = false
		state = "following"
		setPrompt("Cacher " .. name())
	end
end

local function spawnAtRefuge()
	local at = refuge
	if at == nil then
		return
	end
	despawn()
	local model = makeCharacter()
	if model == nil then
		return
	end
	local h = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local r = model:FindFirstChild("HumanoidRootPart") :: BasePart
	h.DisplayName = name()
	h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	h.NameDisplayDistance = 30
	h.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	h.WalkSpeed = Config.survivor.limpSpeed
	-- Personne ne doit pouvoir le tuer par une chute ou un coup perdu : sa
	-- seule fin est l'Oeil.
	h.BreakJointsOnDeath = false
	h:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	model:PivotTo(at.CFrame)
	model.Parent = WorldService.get().root

	local s = Config.survivor
	local onFoot = Config.controls.contexts.onFoot
	local p = Instance.new("ProximityPrompt")
	p.ObjectText = name()
	p.MaxActivationDistance = s.promptDistance
	p.RequiresLineOfSight = false
	p.GamepadKeyCode = (Enum.KeyCode :: any)[onFoot.interact.gamepad]
	p.KeyboardKeyCode = (Enum.KeyCode :: any)[onFoot.interact.keyboard]
	p.Parent = r
	p.Triggered:Connect(onPrompt)

	local animator = h:FindFirstChildOfClass("Animator")
	if animator == nil then
		animator = Instance.new("Animator")
		animator.Parent = h
	end
	local function load(id: number): AnimationTrack
		local animation = Instance.new("Animation")
		animation.AnimationId = "rbxassetid://" .. id
		return (animator :: Animator):LoadAnimation(animation)
	end
	walkTrack = load(s.walkAnimation)
	idleTrack = load(s.idleAnimation)
	idleTrack.Looped = true
	idleTrack:Play()

	character, humanoid, root, prompt = model, h, r, p
	r:SetNetworkOwner(nil)
	found = false
	state = "waiting"
	setPrompt("Aider", s.findHoldSeconds)
end

-- Ce que l'Oeil peut voir de lui : rien s'il attend au fond de son refuge,
-- s'il est cache, a la Planque, ou s'il vient d'etre chasse de sa cachette.
local function exposed(): boolean
	return state == "following" or state == "going" or (state == "waiting" and found)
end

function SurvivorService.target(): (BasePart?, BasePart?)
	if not exposed() then
		return nil, nil
	end
	if workspace:GetServerTimeNow() < graceUntil then
		return nil, nil
	end
	local model = character
	local head = model and model:FindFirstChild("Head")
	if not (head and head:IsA("BasePart") and root) then
		return nil, nil
	end
	return head, root
end

function SurvivorService.model(): Model?
	return character
end

-- L'Oeil l'a vu assez longtemps : il monte vers lui, et il est recrache
-- ailleurs (decide : « s'il est aspire, on le retrouve plus tard ailleurs »).
function SurvivorService.take()
	if not exposed() then
		return
	end
	local model, r = character, root
	character, humanoid, root, prompt = nil, nil, nil, nil
	guide, spotId, spotExit = nil, nil, nil
	state = "absent"
	say("L'Œil a pris " .. name() .. " !", "danger")
	chooseRefuge()
	QuestService.sayAgainTonight()
	if model and r then
		Sfx.at("aspiration", r.Position)
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = true
				part.CanCollide = false
			end
		end
		local s = Config.survivor
		local origin = model:GetPivot()
		local started = os.clock()
		local connection: RBXScriptConnection? = nil
		connection = RunService.Heartbeat:Connect(function()
			local t = math.clamp((os.clock() - started) / s.liftSeconds, 0, 1)
			model:PivotTo(
				origin
					* CFrame.new(0, s.liftHeight * t * t, 0)
					* CFrame.Angles(0, t * math.pi * 6, t * math.pi)
			)
			if t >= 1 then
				if connection then
					connection:Disconnect()
				end
				model:Destroy()
			end
		end)
	end
end

local function guideRoot(): BasePart?
	local g = guide
	if g == nil or g.Parent == nil or CrewService.isTaken(g) or CrewService.isBound(g) then
		return nil
	end
	local c = g.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	if r and r:IsA("BasePart") then
		return r
	end
	return nil
end

-- LA TRACE : il marche dans les pas de son guide. Le calcul de chemin de
-- Roblox ne trouve pas la sortie des maisons (vu dans Studio le 7 novembre
-- 2026 : aucun chemin depuis le salon d'une ferme, ou un joueur passe) ; la
-- ou le guide est passe, lui passe aussi.
local lastMoved = 0
local lastPosition = Vector3.zero

local sight = RaycastParams.new()
sight.FilterType = Enum.RaycastFilterType.Exclude

local function record(position: Vector3)
	local s = Config.survivor
	local last = trail[#trail]
	if last == nil or (position - last).Magnitude >= s.trailStep then
		table.insert(trail, position)
		if #trail > s.trailMax then
			table.remove(trail, 1)
		end
	end
end

-- Rien entre lui et ce point, a hauteur de hanche : il peut y aller droit.
local function clearTo(from: Vector3, to: Vector3): boolean
	local ignore: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	if character then
		table.insert(ignore, character)
	end
	sight.FilterDescendantsInstances = ignore
	return workspace:Raycast(from, to - from, sight) == nil
end

local function walkTo(goal: Vector3, useTrail: boolean)
	local h, r = humanoid, root
	if h == nil or r == nil then
		return
	end
	local s = Config.survivor
	local aim = goal
	if useTrail then
		if clearTo(r.Position, goal) then
			table.clear(trail)
		else
			-- Les pas deja faits (ou qu'il a coupes) ne servent plus.
			while trail[1] and (trail[1] - r.Position).Magnitude < s.trailStep do
				table.remove(trail, 1)
			end
			aim = trail[1] or goal
		end
	end
	h:MoveTo(aim)
	-- Bloque contre une barriere : il saute.
	if (r.Position - lastPosition).Magnitude > 1 then
		lastPosition = r.Position
		lastMoved = os.clock()
	elseif os.clock() - lastMoved > s.stuckSeconds then
		h.Jump = true
		lastMoved = os.clock()
	end
end

local function atPlanque(position: Vector3): boolean
	return (position - WorldService.get().spawn.Position).Magnitude <= Config.planque.radius
end

local function tick()
	local s = Config.survivor
	local r = root
	if r == nil then
		return
	end
	local moving = false
	if state == "following" then
		if atPlanque(r.Position) then
			state = "home"
			guide = nil
			homePrompt()
			local h = humanoid :: Humanoid
			h:MoveTo(WorldService.get().spawn.Position)
			say(name() .. " est à l'abri à la Planque.", "quest")
			QuestService.notify("rescued")
			return
		end
		local target = guideRoot()
		if target == nil then
			-- Son guide n'est plus la (aspire, attache, parti) : il attend
			-- que quelqu'un d'autre le prenne en charge.
			stop()
			state = "waiting"
			guide = nil
			setPrompt("Aider", s.findHoldSeconds)
			return
		end
		record(target.Position)
		local distance = (target.Position - r.Position).Magnitude
		if distance > s.lostDistance then
			stop()
			if not toldLost and guide then
				toldLost = true
				LootService.sendHud(
					guide,
					name() .. " ne te suit plus : reviens le chercher.",
					"danger"
				)
			end
		elseif distance > s.followDistance then
			toldLost = false
			walkTo(target.Position, true)
			moving = true
		else
			stop()
		end
	elseif state == "going" then
		local exit, id = spotExit, spotId
		if exit == nil or id == nil or exit.Parent == nil or os.clock() - goingSince > 15 then
			state = "following"
			spotId, spotExit = nil, nil
			setPrompt("Cacher " .. name())
			return
		end
		local flat = Vector3.new(exit.Position.X - r.Position.X, 0, exit.Position.Z - r.Position.Z)
		if flat.Magnitude <= 4 then
			local inside = HidingService.hostGuest(id, exit, guide)
			if inside then
				stop()
				r.Anchored = true
				r.CFrame = inside
				state = "hidden"
				setPrompt("Faire sortir " .. name())
			else
				spotId, spotExit = nil, nil
				state = "following"
				setPrompt("Cacher " .. name())
				if guide then
					LootService.sendHud(guide, "Cette cachette est prise.")
				end
			end
		else
			walkTo(exit.Position, false)
			moving = true
		end
	end
	local track, idle = walkTrack, idleTrack
	if track and idle then
		if moving and not track.IsPlaying then
			idle:Stop(0.2)
			track:Play(0.2, 1, s.walkAnimationSpeed)
		elseif not moving and track.IsPlaying then
			track:Stop(0.3)
			idle:Play(0.3)
		end
	end
end

-- Appele par DayService a chaque aube, apres la quete : l'etape ouverte, il
-- attend dans son refuge.
function SurvivorService.dawn()
	if state == "absent" and QuestService.isOpen(STEP) then
		spawnAtRefuge()
	end
end

-- La nuit : a la Planque, il mange un plat de la reserve.
function SurvivorService.night()
	if state ~= "home" then
		return
	end
	local stock = LootService.stock()
	local fed = Planque.serveMeal(stock, Config.planque.menu, Config.survivor.meals)
	local crafting = QuestService.hasReached(SMOKE_STEP)
	if fed == 0 then
		say(
			name()
				.. " n'a rien eu à manger ce soir"
				.. (if crafting then " : il ne fabriquera rien." else "."),
			"danger"
		)
		return
	end
	if not crafting then
		say(name() .. " a mangé sur la réserve.")
		return
	end
	-- Il a mange : il travaille, tant que la reserve a de quoi.
	local made = 0
	for _ = 1, Config.smoke.perNight do
		if not Planque.pay(stock, Config.smoke.recipe) then
			break
		end
		made += 1
	end
	smokes += made
	homePrompt()
	if made > 0 then
		say(
			string.format(
				"%s a mangé, puis fabriqué %d fumigène%s : au matin, prenez-les auprès de lui (X).",
				name(),
				made,
				if made > 1 then "s" else ""
			),
			"quest"
		)
	else
		say(
			name()
				.. " a mangé, mais n'a rien pour ses fumigènes : produits chimiques et ferraille, au coffre."
		)
	end
end

-- Une defaite : il disparait, et il se cache ailleurs dans la partie suivante.
function SurvivorService.reset()
	local id = spotId
	if state == "hidden" and id then
		HidingService.releaseGuest(id)
	end
	despawn()
	state = "absent"
	smokes = 0
	chooseRefuge()
end

-- Le meme chemin que l'invite : les touches simulees par le pont MCP
-- n'atteignent pas les invites (comme HidingService.tryEnter).
function SurvivorService.tryPrompt(player: Player)
	onPrompt(player)
end

function SurvivorService.state(): string
	return state
end

function SurvivorService.start()
	chooseRefuge()
	-- Chasse de sa cachette (arrachee, ou disparue au matin) : il ressort et
	-- court rejoindre son guide, avec le meme repit qu'un joueur.
	HidingService.onGuestEjected(function(exit: CFrame)
		local r = root
		spotId, spotExit = nil, nil
		if r == nil or state ~= "hidden" then
			return
		end
		r.Anchored = false
		r.CFrame = exit
		graceUntil = workspace:GetServerTimeNow() + Config.eye.ripGraceSeconds
		state = "following"
		setPrompt("Cacher " .. name())
		say("La cachette de " .. name() .. " est arrachée !", "danger")
	end)
	task.spawn(function()
		while true do
			task.wait(0.2)
			local ok, err = pcall(tick)
			if not ok then
				warn("[Survivor] Survivant : " .. tostring(err))
			end
		end
	end)
end

return SurvivorService
