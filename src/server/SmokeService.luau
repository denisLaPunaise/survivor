--!strict
--[[
	SmokeService — le fumigene : le lancer (L2) et le nuage.

	Le client n'envoie que la direction de son regard ; le serveur verifie
	qu'on peut lancer (un fumigene dans le sac, debout, pas cache), calcule la
	cloche (Smoke.flight), cherche ou elle touche au rayon, fait voler la
	boite (tout le monde la voit) et ouvre le nuage ou elle tombe.

	Le nuage coupe la ligne de vue de l'Oeil : EyeService demande `blocking`
	pour chaque rayon. Les particules sont dessinees sur la meme sphere que
	celle que mesurent les rayons.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Survivor = ReplicatedStorage:WaitForChild("Survivor")
local Config = require(Survivor:WaitForChild("Config"))
local Smoke = require(Survivor:WaitForChild("Smoke"))
local Remotes = Survivor:WaitForChild("Remotes")

local CombatService = require(script.Parent:WaitForChild("CombatService"))
local CrewService = require(script.Parent:WaitForChild("CrewService"))
local HidingService = require(script.Parent:WaitForChild("HidingService"))
local LootService = require(script.Parent:WaitForChild("LootService"))
local QuestService = require(script.Parent:WaitForChild("QuestService"))
local RemoteGuard = require(script.Parent:WaitForChild("RemoteGuard"))

local SmokeService = {}

type Live = {
	cloud: Smoke.Cloud,
	born: number,
	part: BasePart,
	emitter: ParticleEmitter,
}

local live: { Live } = {}
local lastThrow: { [Player]: number } = {}
-- Ce qui vole encore : une defaite le detruit.
local flying: { BasePart } = {}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- Le nuage qui coupe le segment de A a B (nil si aucun) : son centre et son
-- rayon du moment.
function SmokeService.blocking(from: Vector3, to: Vector3): (Vector3?, number?)
	local clouds: { Smoke.Cloud } = {}
	for _, entry in live do
		table.insert(clouds, entry.cloud)
	end
	local hit = Smoke.blocking(clouds, from.X, from.Y, from.Z, to.X, to.Y, to.Z)
	if hit == nil then
		return nil, nil
	end
	return Vector3.new(hit.x, hit.y, hit.z), hit.radius
end

local function makeCloud(center: Vector3)
	local s = Config.smoke
	local look = s.look
	local part = Instance.new("Part")
	part.Name = "Fumee"
	part.Shape = Enum.PartType.Ball
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.one
	part.Position = center

	-- Des bouffees qui naissent dans tout le volume de la sphere, grossissent
	-- et s'effacent : la sphere des rayons, vue de dehors.
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Bouffees"
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Shape = Enum.ParticleEmitterShape.Sphere
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(look.puffSeconds.min, look.puffSeconds.max)
	emitter.Speed = NumberRange.new(0.5, 2)
	emitter.Drag = 1
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-15, 15)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, look.puffSize.from),
		NumberSequenceKeypoint.new(1, look.puffSize.to),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.15, 0),
		NumberSequenceKeypoint.new(0.7, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Color = ColorSequence.new(rgb(look.smoke), rgb(look.smokeDark))
	emitter.LightInfluence = 1
	emitter.Parent = part
	part.Parent = workspace
	-- Un premier jet d'un coup : la boite eclate.
	emitter:Emit(math.floor(look.puffsPerSecond / 2))

	table.insert(live, {
		cloud = { x = center.X, y = center.Y, z = center.Z, radius = 0 },
		born = os.clock(),
		part = part,
		emitter = emitter,
	})
end

local function update()
	local s = Config.smoke
	local now = os.clock()
	for i = #live, 1, -1 do
		local entry = live[i]
		local age = now - entry.born
		local radius = Smoke.radiusAt(s, age)
		entry.cloud.radius = radius
		if age >= s.seconds then
			entry.part:Destroy()
			table.remove(live, i)
			continue
		end
		entry.part.Size = Vector3.one * math.max(radius * 2, 1)
		-- Il ne nait plus de bouffees quand il se dissipe : les dernieres
		-- s'effacent d'elles-memes, avec le rayon des rayons.
		entry.emitter.Rate = if s.seconds - age > s.fadeSeconds
			then s.look.puffsPerSecond * radius / s.radius
			else 0
	end
end

local flightParams = RaycastParams.new()
flightParams.FilterType = Enum.RaycastFilterType.Exclude
flightParams.RespectCanCollide = true

-- La cloche, et le point ou elle touche (le dernier point si rien).
local function trajectory(origin: Vector3, look: Vector3): ({ Vector3 }, Vector3)
	local s = Config.smoke
	local velocity = look * s.throwSpeed + Vector3.yAxis * s.throwLift
	local points = Smoke.flight(
		origin.X,
		origin.Y,
		origin.Z,
		velocity.X,
		velocity.Y,
		velocity.Z,
		s.gravity,
		s.flightStep,
		s.maxFlightSeconds
	)
	local ignore: { Instance } = {}
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(ignore, other.Character)
		end
	end
	flightParams.FilterDescendantsInstances = ignore
	local path: { Vector3 } = { origin }
	for i = 2, #points do
		local a = path[#path]
		local p = points[i]
		local b = Vector3.new(p.x, p.y, p.z)
		local hit = workspace:Raycast(a, b - a, flightParams)
		if hit then
			table.insert(path, hit.Position)
			return path, hit.Position
		end
		table.insert(path, b)
	end
	return path, path[#path]
end

-- La boite vole le long de la cloche, puis s'ouvre en nuage.
local function fly(path: { Vector3 }, landing: Vector3)
	local s = Config.smoke
	local can = Instance.new("Part")
	can.Name = "Fumigene"
	can.Shape = Enum.PartType.Cylinder
	can.Size = Vector3.new(1.1, 0.55, 0.55)
	can.Material = Enum.Material.Metal
	can.Color = rgb(s.look.can)
	can.Anchored = true
	can.CanCollide = false
	can.CanQuery = false
	can.CanTouch = false
	can.CFrame = CFrame.new(path[1])
	can.Parent = workspace
	table.insert(flying, can)
	local started = os.clock()
	local spin = 0
	while can.Parent do
		local index = math.floor((os.clock() - started) / s.flightStep) + 1
		if index >= #path then
			break
		end
		spin += 0.4
		can.CFrame = CFrame.new(path[index]) * CFrame.Angles(spin, spin * 0.7, 0)
		RunService.Heartbeat:Wait()
	end
	local stillThere = can.Parent ~= nil
	local at = table.find(flying, can)
	if at then
		table.remove(flying, at)
	end
	can:Destroy()
	if stillThere then
		makeCloud(landing + Vector3.yAxis * s.radius * s.centerLift)
	end
end

local function throw(player: Player, look: any)
	if typeof(look) ~= "Vector3" or look.Magnitude < 0.01 then
		return
	end
	local now = os.clock()
	if now - (lastThrow[player] or -math.huge) < Config.smoke.throwCooldown then
		return
	end
	if
		HidingService.isHidden(player)
		or CrewService.isTaken(player)
		or CrewService.isBound(player)
		or CombatService.isDowned(player)
	then
		return
	end
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if head == nil or not head:IsA("BasePart") then
		return
	end
	if not LootService.takeItem(player, "fumigene") then
		LootService.sendHud(player, "Pas de fumigène dans le sac.")
		return
	end
	lastThrow[player] = now
	local direction = look.Unit
	local path, landing = trajectory(head.Position + direction * Config.smoke.handOffset, direction)
	task.spawn(fly, path, landing)
	QuestService.notify("thrown:fumigene")
end

-- Le meme chemin que L2, pour les sondes de test.
function SmokeService.tryThrow(player: Player, look: Vector3)
	throw(player, look)
end

-- Une defaite : plus de fumee, plus rien qui vole.
function SmokeService.reset()
	for _, entry in live do
		entry.part:Destroy()
	end
	table.clear(live)
	for _, can in flying do
		can:Destroy()
	end
	table.clear(flying)
end

function SmokeService.start()
	local remote = Remotes:WaitForChild("Throw") :: RemoteEvent
	remote.OnServerEvent:Connect(RemoteGuard.wrap("Throw", throw))
	RunService.Heartbeat:Connect(update)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastThrow[player] = nil
	end)
end

return SmokeService
