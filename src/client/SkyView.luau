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

local Players = game:GetService("Players")
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
	-- Les eclairs : chaque branche a son rythme ; la lueur la parcourt.
	type Crack = { part: BasePart, rank: number, branch: number }
	local cracks: { Crack } = {}
	local branchRhythm: { [number]: { period: number, phase: number, ranks: number } } = {}
	local rhythmRandom = Random.new()
	for _, part in sky:GetDescendants() do
		local branch = part:GetAttribute("Branche")
		local rank = part:GetAttribute("Rang")
		if part:IsA("BasePart") and typeof(branch) == "number" and typeof(rank) == "number" then
			table.insert(cracks, { part = part, rank = rank, branch = branch })
			local rhythm = branchRhythm[branch]
			if rhythm == nil then
				rhythm = {
					period = rhythmRandom:NextNumber(
						s.crackPulseSeconds.min,
						s.crackPulseSeconds.max
					),
					phase = rhythmRandom:NextNumber(),
					ranks = 0,
				}
				branchRhythm[branch] = rhythm
			end
			rhythm.ranks = math.max(rhythm.ranks, rank)
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

	-- Les bords brulants, cote par cote et d'ouest en est : chacun relie sa
	-- bande a la suivante, pour que la jointure soit une courbe continue et
	-- non un escalier.
	local edges: { [number]: { Strip } } = { [-1] = {}, [1] = {} }
	local reachX = 0
	for _, strip in strips do
		if strip.edge then
			table.insert(edges[strip.side], strip)
		end
		reachX = math.max(reachX, math.abs(strip.x))
	end
	for _, list in edges do
		table.sort(list, function(a, b)
			return a.x < b.x
		end)
	end
	local ember = Color3.fromRGB(table.unpack(s.seamEmber))
	local hot = Color3.fromRGB(table.unpack(s.seamHot))

	-- La part de la demi-largeur que couvre la paupiere `side` : la paupiere
	-- du haut descend plus loin que celle du bas remonte, comme un vrai oeil.
	-- Elles se rejoignent sur une courbe en sourire, pas sur une droite.
	local function coverOf(strip: Strip, c: number): number
		return strip.half * c * (1 + strip.side * s.lidSeamBias)
	end

	local function placeLids(c: number, glow: Color3)
		for _, strip in strips do
			if not strip.edge then
				local covered = coverOf(strip, c)
				local size = strip.part.Size
				strip.part.Size = Vector3.new(size.X, size.Y, math.max(covered, 0.05))
				strip.part.CFrame =
					CFrame.new(strip.x, strip.y, strip.side * (strip.half - covered / 2))
			end
		end
		for _, list in edges do
			for i, strip in list do
				local nextStrip = list[i + 1]
				-- Ouverte, la jointure disparait sous la levre de la Fissure ;
				-- la derniere bande n'a pas de voisine a rejoindre.
				if c < 0.02 or nextStrip == nil then
					strip.part.LocalTransparencyModifier = 1
					continue
				end
				local a =
					Vector3.new(strip.x, strip.y, strip.side * (strip.half - coverOf(strip, c)))
				local b = Vector3.new(
					nextStrip.x,
					nextStrip.y,
					nextStrip.side * (nextStrip.half - coverOf(nextStrip, c))
				)
				local length = (b - a).Magnitude
				strip.part.Size = Vector3.new(s.seamWidth, strip.part.Size.Y, length + 0.6)
				strip.part.CFrame = CFrame.lookAt((a + b) / 2, b)
				strip.part.Color = glow
				-- Aux coins de l'oeil, la jointure s'efface.
				local tip = math.abs((a.X + b.X) / 2) / reachX
				strip.part.LocalTransparencyModifier =
					math.clamp((tip - s.seamFadeFrom) / (1 - s.seamFadeFrom), 0, 1)
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
		-- Fermee, la jointure respire comme une braise ; en mouvement, elle
		-- brule.
		local breath = 0.5 + 0.5 * math.sin(now * math.pi * 2 / s.seamBreathSeconds)
		local glow = if wantOpen or closure < 0.98 then hot else ember:Lerp(hot, breath * 0.6)
		placeLids(shown, glow)
		-- A l'ouverture la pupille est large, puis elle se resserre : il
		-- cherche. Redimensionner une part garde son centre : la fente reste
		-- en place.
		local focus = math.clamp((now - openedAt) / s.pupilFocusSeconds, 0, 1)
		local scale = if wantOpen
			then s.pupilWide + (s.pupilNarrow - s.pupilWide) * focus
			else s.pupilWide
		-- Il te voit : sa pupille se serre en une fente minuscule, sur toi.
		local seen = Players.LocalPlayer:GetAttribute("Exposure")
		if typeof(seen) == "number" and seen > 0.02 then
			scale = math.min(scale, s.pupilSeen)
		end
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
		-- Pendant un Balayage il suit son faisceau de pres : le regard sort de
		-- sa pupille, il doit la tourner vers ce qu'il vise.
		local turnRate = if beam then s.eyeTurnRateSweep else s.eyeTurnRate
		local alpha = math.clamp(dt * turnRate, 0, 1)
		looking = looking:Lerp(target, alpha)
		eye:PivotTo(CFrame.lookAt(center, looking))

		-- Les eclairs : une lueur qui court du trou vers le dehors, et un
		-- leger crepitement.
		local rest = s.crackRest + (s.crackRestAwake - s.crackRest) * (1 - closure)
		for _, crack in cracks do
			local rhythm = branchRhythm[crack.branch]
			-- La position de la lueur sur la branche, un peu avant le premier
			-- rang et un peu apres le dernier : elle entre et sort en douceur.
			local wave = ((now / rhythm.period + rhythm.phase) % 1) * (rhythm.ranks + 3) - 1
			local pulse = math.exp(-((crack.rank - wave) ^ 2))
			local crackle = math.noise(now * 6, crack.branch, crack.rank) * 0.15
			local shine = math.clamp(rest + pulse * (1 - rest) + crackle, 0, 1)
			crack.part.LocalTransparencyModifier = 1 - shine
		end

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
