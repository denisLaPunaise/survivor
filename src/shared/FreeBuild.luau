--!strict
--[[
	FreeBuild — la grille de la construction libre autour de la Planque.

	Logique pure : les reglages et les positions arrivent en argument.

	Une case de `grid` studs. Une piece couvre `cells` cases en longueur et
	`depthCells` en profondeur ; tournee d'un quart de tour, l'une et l'autre
	s'echangent. Deux pieces ne partagent jamais une case de la meme couche
	(au sol, ou en l'air : un filet se tend au-dessus d'un mur).
]]

local FreeBuild = {}

export type Piece = {
	id: string,
	cells: number,
	depthCells: number,
	layer: string,
}

-- La case qui contient ce point.
function FreeBuild.cellAt(x: number, z: number, grid: number): (number, number)
	return math.floor(x / grid), math.floor(z / grid)
end

-- La piece posee a partir de la case (i, j), tournee de `turns` quarts de
-- tour : les cases qu'elle couvre (des cles "couche:i:j"), et son centre.
function FreeBuild.footprint(
	piece: Piece,
	turns: number,
	i: number,
	j: number,
	grid: number
): ({ string }, number, number)
	local along, across = piece.cells, piece.depthCells
	if turns % 2 == 1 then
		along, across = across, along
	end
	local keys: { string } = {}
	for di = 0, along - 1 do
		for dj = 0, across - 1 do
			table.insert(keys, string.format("%s:%d:%d", piece.layer, i + di, j + dj))
		end
	end
	return keys, (i + along / 2) * grid, (j + across / 2) * grid
end

-- Aucune de ces cases n'est deja prise.
function FreeBuild.fits(occupied: { [string]: boolean }, keys: { string }): boolean
	for _, key in keys do
		if occupied[key] then
			return false
		end
	end
	return true
end

-- Le centre de la piece est-il dans la cour (a `radius` du centre) ?
function FreeBuild.inYard(x: number, z: number, cx: number, cz: number, radius: number): boolean
	local dx, dz = x - cx, z - cz
	return dx * dx + dz * dz <= radius * radius
end

return FreeBuild
