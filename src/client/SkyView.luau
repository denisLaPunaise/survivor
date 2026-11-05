--!strict
--[[
	SkyView — l'Oeil qui regarde, et la ville qui monte vers lui.

	Purement visuel, et local : chaque client tourne l'Oeil et fait monter les
	debris pour lui-meme. Le serveur n'en sait rien et n'en a pas besoin ; le
	vrai regard, c'est la part `Regard` et la ligne de vue de l'EyeService.

	Quand un Balayage tourne, l'Oeil suit le bout du faisceau : on voit ou il
	cherche, et c'est un signe de plus pour savoir ou ne pas etre.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Survivor = ReplicatedStorage:WaitForChild("Survivor")
local Config = require(Survivor:WaitForChild("Config"))

local SkyView = {}

-- Un debris : une part seule, ou un modele entier (une voiture monte d'un
-- bloc, elle ne se defait pas en pieces).
type Drifter = {
	item: PVInstance,
	parts: { BasePart },
	base: CFrame,
	x: number,
	z: number,
	height: number,
	spinAxis: Vector3,
}

function SkyView.start()
	local w = Config.world
	local s = Config.sky
	local root = workspace:WaitForChild(w.folder)
	local sky = root:WaitForChild(w.sky)
	local eye = sky:WaitForChild(w.eye) :: Model
	local center = eye:GetPivot().Position
	local ground = Vector3.new(center.X, 0, center.Z)
	local looking = ground

	local drifters: { Drifter } = {}
	local debris = sky:FindFirstChild(w.debris)
	if debris then
		for _, item in debris:GetChildren() do
			if not item:IsA("PVInstance") then
				continue
			end
			local parts: { BasePart } = {}
			if item:IsA("BasePart") then
				table.insert(parts, item)
			else
				for _, part in item:GetDescendants() do
					if part:IsA("BasePart") then
						table.insert(parts, part)
					end
				end
			end
			local pivot = item:GetPivot()
			local p = pivot.Position
			table.insert(drifters, {
				item = item,
				parts = parts,
				base = pivot - p,
				x = p.X,
				z = p.Z,
				height = p.Y,
				spinAxis = Vector3.new(
					math.noise(p.X * 0.01, 1),
					math.noise(p.Z * 0.01, 2),
					math.noise(p.Y * 0.01, 3)
				).Unit,
			})
		end
	end

	-- La nuit, l'Oeil se ferme : il pâlit jusqu'a presque disparaitre.
	local closed = false
	local eyeParts: { BasePart } = {}
	for _, part in eye:GetDescendants() do
		if part:IsA("BasePart") then
			table.insert(eyeParts, part)
		end
	end
	local remotes = Survivor:WaitForChild("Remotes")
	local eyeState = remotes:WaitForChild("EyeState") :: RemoteEvent
	eyeState.OnClientEvent:Connect(function(data: any)
		if data.phase == "night" then
			closed = true
		elseif data.phase == "dawn" then
			closed = false
		end
	end)
	local openness = 1

	RunService.RenderStepped:Connect(function(dt: number)
		openness = math.clamp(openness + (if closed then -dt / 5 else dt / 5), 0, 1)
		for _, part in eyeParts do
			part.LocalTransparencyModifier = 1 - (0.15 + 0.85 * openness)
		end
		-- Ou regarde-t-il ? Le bout du faisceau, ou une derive lente.
		local target: Vector3
		local beam = workspace:FindFirstChild("Regard")
		if beam and beam:IsA("BasePart") then
			target = beam.Position + beam.CFrame.RightVector * (beam.Size.X / 2)
		else
			local t = os.clock() / s.idleWanderSeconds
			target = ground
				+ Vector3.new(
					math.noise(t, 11) * s.idleWanderRadius * 2,
					0,
					math.noise(t, 23) * s.idleWanderRadius * 2
				)
		end
		local alpha = math.clamp(dt * s.eyeTurnRate, 0, 1)
		looking = looking:Lerp(target, alpha)
		eye:PivotTo(CFrame.lookAt(center, looking))

		-- La ville qui monte.
		for _, d in drifters do
			d.height += s.debrisRiseSpeed * dt
			if d.height > s.debrisHighest then
				d.height = s.debrisLowest
			end
			d.base = CFrame.fromAxisAngle(d.spinAxis, s.debrisSpinSpeed * dt) * d.base
			d.item:PivotTo(CFrame.new(d.x, d.height, d.z) * d.base)
			-- Pres de la Fissure, le debris s'efface : il est pris.
			local fade = math.clamp((d.height - (s.debrisHighest - 60)) / 60, 0, 1)
			for _, part in d.parts do
				part.LocalTransparencyModifier = fade
			end
		end
	end)
end

return SkyView
