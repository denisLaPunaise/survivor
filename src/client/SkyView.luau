--!strict
--[[
	SkyView — l'Oeil qui regarde, et la ville qui monte vers lui.

	Purement visuel, et local : chaque client tourne l'Oeil et fait monter les
	debris pour lui-meme. Le serveur n'en sait rien et n'en a pas besoin ; le
	vrai regard, c'est la part `Regard` et la ligne de vue de l'EyeService.

	Quand un Balayage tourne, l'Oeil suit le bout du faisceau : on voit ou il
	cherche, et c'est un signe de plus pour savoir ou ne pas etre.

	Les paupieres : la Fissure se referme sur lui entre deux Balayages et la
	nuit, s'ouvre au signal, cligne de temps en temps ; sa pupille se resserre
	quand il cherche.
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

	-- Les paupieres : des bandes que l'on allonge depuis le bord du trou.
	type Strip = { part: BasePart, x: number, y: number, half: number, side: number, edge: boolean }
	local strips: { Strip } = {}
	local lids = sky:FindFirstChild(w.lids)
	if lids then
		for _, part in lids:GetChildren() do
			if part:IsA("BasePart") then
				table.insert(strips, {
					part = part,
					x = part:GetAttribute("X") :: number,
					-- Le bord passe un peu sous la paupiere : chacun garde sa hauteur.
					y = part.Position.Y,
					half = part:GetAttribute("Demi") :: number,
					side = part:GetAttribute("Cote") :: number,
					edge = part.Name == "Bord",
				})
			end
		end
	end
	-- La pupille : des tranches en amande, que l'on resserre ensemble.
	type Slice = { part: BasePart, size: Vector3 }
	local pupil: { Slice } = {}
	for _, part in eye:GetDescendants() do
		if part:IsA("BasePart") and part.Name == "Pupille" then
			table.insert(pupil, { part = part, size = part.Size })
		end
	end

	-- Ouvert pendant les signes et le Balayage ; ferme sinon. Un joueur qui
	-- arrive en plein Balayage le voit ouvert (le faisceau existe deja).
	local wantOpen = workspace:FindFirstChild("Regard") ~= nil
	local closure = if wantOpen then 0 else 1
	local openedAt = os.clock()
	local random = Random.new()
	local nextBlink = os.clock()
		+ random:NextNumber(s.blinkEverySeconds.min, s.blinkEverySeconds.max)
	local remotes = Survivor:WaitForChild("Remotes")
	local eyeState = remotes:WaitForChild("EyeState") :: RemoteEvent
	eyeState.OnClientEvent:Connect(function(data: any)
		local open = data.phase == "warning" or data.phase == "sweep"
		if open and not wantOpen then
			openedAt = os.clock()
		end
		wantOpen = open
	end)

	local function placeLids(c: number)
		for _, strip in strips do
			local covered = strip.half * c
			if strip.edge then
				-- Le bord brulant suit l'avancee de la paupiere ; ouverte, il
				-- disparait sous la levre de la Fissure.
				strip.part.LocalTransparencyModifier = if c < 0.02 then 1 else 0
				strip.part.CFrame =
					CFrame.new(strip.x, strip.y, strip.side * (strip.half - covered))
			else
				local size = strip.part.Size
				strip.part.Size = Vector3.new(size.X, size.Y, math.max(covered, 0.05))
				strip.part.CFrame =
					CFrame.new(strip.x, strip.y, strip.side * (strip.half - covered / 2))
			end
		end
	end

	RunService.RenderStepped:Connect(function(dt: number)
		-- Les paupieres glissent vers leur but ; ouvert, un clignement rapide
		-- de temps en temps.
		local goal = if wantOpen then 0 else 1
		local rate = if wantOpen then 1 / s.lidOpenSeconds else 1 / s.lidCloseSeconds
		closure = if closure < goal
			then math.min(closure + rate * dt, goal)
			else math.max(closure - rate * dt, goal)
		local shown = closure
		local now = os.clock()
		if wantOpen and closure < 0.05 then
			if now >= nextBlink then
				local t = (now - nextBlink) / s.blinkSeconds
				if t >= 1 then
					nextBlink = now
						+ random:NextNumber(s.blinkEverySeconds.min, s.blinkEverySeconds.max)
				else
					-- Ferme puis rouvre : un triangle sur la duree du clignement.
					shown = math.max(shown, 1 - math.abs(t * 2 - 1))
				end
			end
		end
		placeLids(shown)
		-- A l'ouverture la pupille est large, puis elle se resserre : il
		-- cherche. Redimensionner une part garde son centre : la fente reste
		-- en place.
		local focus = math.clamp((now - openedAt) / s.pupilFocusSeconds, 0, 1)
		local scale = if wantOpen
			then s.pupilWide + (s.pupilNarrow - s.pupilWide) * focus
			else s.pupilWide
		for _, slice in pupil do
			-- La fente : sa largeur est sur X.
			slice.part.Size = Vector3.new(slice.size.X * scale, slice.size.Y, slice.size.Z)
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
