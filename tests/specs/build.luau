--!strict
--[[
	La construction libre : la grille, les cases prises, la cour, et des
	pieces dont la taille colle a leurs cases.
]]

local Config = require("../../src/shared/Config")
local FreeBuild = require("../../src/shared/FreeBuild")
local Visibility = require("../../src/shared/Visibility")

local harness = require("../harness")

return function(t: harness.Harness)
	local b = Config.freeBuild

	t.section("La grille")

	local wall = { id = "mur", cells = 2, depthCells = 1, layer = "sol" }
	local keys, cx, cz = FreeBuild.footprint(wall, 0, 3, 5, 4)
	t.equal("un mur couvre deux cases", #keys, 2)
	t.equal("son centre tombe entre ses deux cases (x)", cx, 16)
	t.equal("et au milieu de sa case (z)", cz, 22)
	local turned = FreeBuild.footprint(wall, 1, 3, 5, 4)
	t.check("tourne, il s'etend en z", turned[2] == "sol:3:6")
	local occupied = { ["sol:4:5"] = true }
	t.check("une case prise refuse la piece", not FreeBuild.fits(occupied, keys))
	t.check("une case libre l'accepte", FreeBuild.fits(occupied, turned))
	local net = { id = "filet", cells = 2, depthCells = 2, layer = "air" }
	local netKeys = FreeBuild.footprint(net, 0, 3, 5, 4)
	t.check("un filet se tend au-dessus d'un mur", FreeBuild.fits({ ["sol:3:5"] = true }, netKeys))
	local i, j = FreeBuild.cellAt(-1, 7.9, 4)
	t.check("la case d'un point negatif est bien a gauche", i == -1 and j == 1)
	t.check("dans la cour", FreeBuild.inYard(10, 10, 0, 0, 20))
	t.check("hors de la cour", not FreeBuild.inYard(30, 0, 0, 0, 20))

	t.section("Les pieces")

	for _, piece in b.pieces do
		local along = piece.cells * b.grid
		t.check(
			piece.id .. " : sa longueur colle a ses cases",
			math.abs(piece.size[1] - along) <= b.grid or piece.cells == 1
		)
		t.check(piece.id .. " : au sol ou en l'air", piece.layer == "sol" or piece.layer == "air")
		for itemId in piece.cost do
			t.check(piece.id .. " : " .. itemId .. " est au catalogue", Config.items[itemId] ~= nil)
		end
		t.check(
			piece.id .. " : ce qui barre la route a une sante (les Repris la frappent)",
			not piece.blocks or (piece.health ~= nil and piece.health > 0)
		)
	end
	t.check("on vise moins loin que la cour", b.reach < b.radius * 2)
	local hides = false
	for _, piece in b.pieces do
		if piece.visibility < 0 then
			hides = true
		end
	end
	t.check("au moins une piece cache la Planque (le camouflage)", hides)

	t.section("La Visibilite de la Planque")

	local v = Config.visibility
	t.equal("le camouflage ne rend pas le niveau negatif", Visibility.level({ 3, -10 }), 0)
	-- Une cour bien construite et eclairee : ~50.
	local gauge, nights = 0, 0
	while not Visibility.found(gauge, v) and nights < 50 do
		gauge = Visibility.night(gauge, 50, v)
		nights += 1
	end
	t.check(
		string.format("une cour visible (niveau 50) se fait trouver en %d nuits", nights),
		nights >= 4 and nights <= 7
	)
	local quiet, quietNights = 0, 0
	while not Visibility.found(quiet, v) and quietNights < 50 do
		quiet = Visibility.night(quiet, 8, v)
		quietNights += 1
	end
	t.check("une Planque discrete (niveau 8) ne se fait jamais trouver", quietNights >= 50)
	t.check(
		"apres l'avoir trouvee, il s'en souvient a moitie",
		v.afterFound > 0 and v.afterFound < v.found
	)
	t.check(
		"pleine, elle attire quelques Repris de plus, pas une armee",
		Visibility.extraRepris(v.found, v) <= 8 and Visibility.extraRepris(0, v) == 0
	)
end
