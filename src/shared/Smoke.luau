--!strict
--[[
	Smoke — le nuage du fumigene : sa taille dans le temps, ce qu'il cache,
	la trajectoire du lancer, et la ronde de l'Oeil qui guette autour.

	Logique pure : les positions arrivent en nombres (x, y, z), les reglages
	en argument.

	LE NUAGE EST UNE SPHERE qui coupe la ligne de vue (principe n°1) : un
	rayon de l'Oeil qui la traverse ne voit rien derriere, ni dedans. Le
	nuage visible (des particules) est dessine sur la meme sphere.
]]

local Smoke = {}

export type Cloud = { x: number, y: number, z: number, radius: number }

export type Settings = {
	radius: number,
	seconds: number,
	growSeconds: number,
	fadeSeconds: number,
}

-- Le rayon du nuage `age` secondes apres son ouverture : il s'ouvre, tient,
-- puis retrecit et disparait (0 avant et apres).
function Smoke.radiusAt(settings: Settings, age: number): number
	if age < 0 or age >= settings.seconds then
		return 0
	end
	local grow = math.clamp(age / settings.growSeconds, 0, 1)
	local left = settings.seconds - age
	local fade = math.clamp(left / settings.fadeSeconds, 0, 1)
	return settings.radius * math.min(grow, fade)
end

-- Le premier nuage que coupe le segment de A a B (nil si aucun). Un bout
-- dans le nuage compte : on est cache dedans.
function Smoke.blocking(
	clouds: { Cloud },
	ax: number,
	ay: number,
	az: number,
	bx: number,
	by: number,
	bz: number
): Cloud?
	local dx, dy, dz = bx - ax, by - ay, bz - az
	local length2 = dx * dx + dy * dy + dz * dz
	for _, cloud in clouds do
		if cloud.radius <= 0 then
			continue
		end
		-- Le point du segment le plus proche du centre.
		local t = 0
		if length2 > 0 then
			t = ((cloud.x - ax) * dx + (cloud.y - ay) * dy + (cloud.z - az) * dz) / length2
			t = math.clamp(t, 0, 1)
		end
		local px, py, pz = ax + dx * t - cloud.x, ay + dy * t - cloud.y, az + dz * t - cloud.z
		if px * px + py * py + pz * pz <= cloud.radius * cloud.radius then
			return cloud
		end
	end
	return nil
end

-- La trajectoire du lancer, pas a pas : une cloche sous `gravity`. Rend les
-- points (le premier est le depart) ; le service cherche ou elle touche.
function Smoke.flight(
	x: number,
	y: number,
	z: number,
	vx: number,
	vy: number,
	vz: number,
	gravity: number,
	step: number,
	maxSeconds: number
): { { x: number, y: number, z: number } }
	local points = { { x = x, y = y, z = z } }
	local elapsed = 0
	while elapsed < maxSeconds do
		elapsed += step
		vy -= gravity * step
		x += vx * step
		y += vy * step
		z += vz * step
		table.insert(points, { x = x, y = y, z = z })
	end
	return points
end

-- La ou l'Oeil guette, `elapsed` secondes apres avoir perdu de vue sa proie
-- dans le nuage : il tourne autour, a `ring` du centre, en partant du cote
-- d'ou il arrivait (`startAngle`).
function Smoke.watchPoint(
	cx: number,
	cz: number,
	ring: number,
	startAngle: number,
	turnSpeed: number,
	elapsed: number
): (number, number)
	local angle = startAngle + turnSpeed * elapsed
	return cx + math.cos(angle) * ring, cz + math.sin(angle) * ring
end

return Smoke
