--!strict
--[[
	Sweep — le trajet du regard de l'Oeil au sol, pendant un Balayage.

	Logique pure : aucun require, aucune API Roblox, aucun Vector3. Un point
	est { x, z, pause, spotId } : le regard y arrive, s'y attarde `pause`
	secondes, et s'il porte `spotId`, c'est une cachette marquee qu'il vient
	arracher.

	Le trajet se mesure en studs et se parcourt a vitesse constante : la duree
	d'un Balayage se DEDUIT de sa longueur, elle n'est recopiee nulle part.
]]

local Sweep = {}

export type Point = {
	x: number,
	z: number,
	pause: number,
	spotId: string?,
}

export type Bounds = {
	minX: number,
	maxX: number,
	minZ: number,
	maxZ: number,
}

export type Target = {
	id: string,
	x: number,
	z: number,
}

export type Timeline = {
	points: { Point },
	-- Instant d'arrivee a chaque point, puis instant de depart (apres pause).
	arrive: { number },
	depart: { number },
	total: number,
}

local function point(x: number, z: number): Point
	return { x = x, z = z, pause = 0 }
end

-- Un rateau : des allers-retours paralleles espaces de `spacing`. Entre deux
-- passages il reste une bande que le regard ne touche pas : c'est la qu'on
-- survit quand on n'a pas trouve de cachette.
function Sweep.linePath(
	bounds: Bounds,
	spacing: number,
	alongX: boolean,
	reverse: boolean
): { Point }
	local path: { Point } = {}
	local fromA = if alongX then bounds.minZ else bounds.minX
	local toA = if alongX then bounds.maxZ else bounds.maxX
	local lowB = if alongX then bounds.minX else bounds.minZ
	local highB = if alongX then bounds.maxX else bounds.maxZ

	local lanes: { number } = {}
	local a = fromA
	while a <= toA do
		table.insert(lanes, a)
		a += spacing
	end
	if reverse then
		local flipped: { number } = {}
		for i = #lanes, 1, -1 do
			table.insert(flipped, lanes[i])
		end
		lanes = flipped
	end

	for i, lane in lanes do
		local startB = if i % 2 == 1 then lowB else highB
		local endB = if i % 2 == 1 then highB else lowB
		if alongX then
			table.insert(path, point(startB, lane))
			table.insert(path, point(endB, lane))
		else
			table.insert(path, point(lane, startB))
			table.insert(path, point(lane, endB))
		end
	end
	return path
end

-- Une spirale rectangulaire, du bord vers le centre : on la voit venir, et
-- elle finit la ou l'on croyait etre tranquille.
function Sweep.spiralPath(bounds: Bounds, spacing: number): { Point }
	local path: { Point } = {}
	local minX, maxX, minZ, maxZ = bounds.minX, bounds.maxX, bounds.minZ, bounds.maxZ
	table.insert(path, point(minX, minZ))
	while minX < maxX and minZ < maxZ do
		table.insert(path, point(maxX, minZ))
		table.insert(path, point(maxX, maxZ))
		table.insert(path, point(minX, maxZ))
		minZ += spacing
		if minZ >= maxZ then
			break
		end
		table.insert(path, point(minX, minZ))
		minX += spacing
		maxX -= spacing
		maxZ -= spacing
		if minX >= maxX then
			break
		end
		table.insert(path, point(minX, minZ))
	end
	return path
end

-- Les cachettes marquees passent EN PREMIER : l'Oeil va les verifier avant de
-- balayer, et s'attarde sur chacune le temps de l'arracher.
function Sweep.withInspections(
	path: { Point },
	targets: { Target },
	inspectSeconds: number
): { Point }
	local out: { Point } = {}
	for _, target in targets do
		table.insert(
			out,
			{ x = target.x, z = target.z, pause = inspectSeconds, spotId = target.id }
		)
	end
	for _, p in path do
		table.insert(out, p)
	end
	return out
end

-- La zone qu'un Balayage couvre : un carre de `size` centre sur (x, z),
-- ramene dans les limites du quartier (un joueur au bord ne fait pas
-- balayer le vide au-dela).
function Sweep.zoneAround(x: number, z: number, size: number, bounds: Bounds): Bounds
	local width = math.min(size, bounds.maxX - bounds.minX)
	local depth = math.min(size, bounds.maxZ - bounds.minZ)
	local cx = math.clamp(x, bounds.minX + width / 2, bounds.maxX - width / 2)
	local cz = math.clamp(z, bounds.minZ + depth / 2, bounds.maxZ - depth / 2)
	return {
		minX = cx - width / 2,
		maxX = cx + width / 2,
		minZ = cz - depth / 2,
		maxZ = cz + depth / 2,
	}
end

-- Les cachettes marquees que l'Oeil vient verifier pendant CE Balayage : celles
-- de sa zone, elargie de `margin`. Aller en arracher une a l'autre bout du
-- quartier prendrait plus de temps que le Balayage lui-meme.
function Sweep.targetsIn(targets: { Target }, zone: Bounds, margin: number): { Target }
	local out: { Target } = {}
	for _, target in targets do
		if
			target.x >= zone.minX - margin
			and target.x <= zone.maxX + margin
			and target.z >= zone.minZ - margin
			and target.z <= zone.maxZ + margin
		then
			table.insert(out, target)
		end
	end
	return out
end

function Sweep.timeline(points: { Point }, speed: number): Timeline
	local arrive: { number } = {}
	local depart: { number } = {}
	local t = 0
	for i, p in points do
		if i > 1 then
			local prev = points[i - 1]
			local dx, dz = p.x - prev.x, p.z - prev.z
			t += math.sqrt(dx * dx + dz * dz) / speed
		end
		arrive[i] = t
		t += p.pause
		depart[i] = t
	end
	return { points = points, arrive = arrive, depart = depart, total = t }
end

-- Ou regarde l'Oeil a l'instant `t`, et le dernier point atteint (0 avant le
-- premier). Au-dela de la fin, il reste sur le dernier point.
function Sweep.sample(timeline: Timeline, t: number): (number, number, number)
	local points = timeline.points
	if #points == 0 then
		return 0, 0, 0
	end
	local reached = 0
	for i = 1, #points do
		if timeline.arrive[i] <= t then
			reached = i
		else
			break
		end
	end
	if reached == 0 then
		return points[1].x, points[1].z, 0
	end
	local here = points[reached]
	if reached == #points or t <= timeline.depart[reached] then
		return here.x, here.z, reached
	end
	local nextPoint = points[reached + 1]
	local span = timeline.arrive[reached + 1] - timeline.depart[reached]
	local alpha = if span > 0 then (t - timeline.depart[reached]) / span else 1
	return here.x + (nextPoint.x - here.x) * alpha, here.z + (nextPoint.z - here.z) * alpha, reached
end

return Sweep
