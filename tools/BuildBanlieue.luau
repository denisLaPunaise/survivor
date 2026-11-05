--!strict
--[[
	Recette : le premier morceau de la Banlieue (chapitre 1).

	Se charge par un ModuleScript jetable (Source = ce fichier, require, appel,
	Destroy) : `loadstring` est ferme au pont MCP. Elle detruit d'abord ce qui
	repond au contrat de nommage (Workspace.Ville, ServerStorage.SurvivorCachettes,
	les effets de Lighting prefixes « Survivor »), reconstruit tout, pose la
	lumiere, puis SE MESURE et rend un rapport.

	La ville n'est ni dans Git ni dans Rojo : cette recette est sa sauvegarde.

	Plan (vu du ciel, X vers l'est, Z vers le nord) :
	- une rue principale est-ouest (z = 0) et une rue nord-sud (x = 0) ;
	- huit parcelles autour du carrefour : sept maisons et un terrain vide, la
	  ou l'Oeil a aspire une maison entiere ;
	- la Planque : une cave sous le jardin de la maison en ruine du sud-ouest.
]]

local Lighting = game:GetService("Lighting")
local ServerStorage = game:GetService("ServerStorage")

-- Le contrat, recopie de Config.world. La recette ne peut pas requerir
-- Config (elle tourne depuis le pont, hors du jeu) ; la mesure de fin verifie
-- que le serveur trouvera bien tout.
local CONTRACT = {
	folder = "Ville",
	planque = "Planque",
	spawn = "Depart",
	chest = "Coffre",
	bounds = "Limites",
	solidSpots = "CachettesSolides",
	anchors = "Emplacements",
	containers = "Fouilles",
	prefabs = "SurvivorCachettes",
	inside = "Interieur",
	exit = "Sortie",
	cover = "Couvert",
}

-- La hauteur de l'Oeil au-dessus du sol, recopiee de Config.eye.height pour
-- la mesure de couverture.
local EYE_HEIGHT = 600

-- Le ciel, recopie de Config.world.
local SKY = { folder = "Ciel", eye = "Oeil", debris = "Debris" }

-- Les limites que l'Oeil balaie.
local BOUNDS_SIZE = Vector3.new(300, 1, 230)

local random = Random.new(1957)

--------------------------------------------------------------------------------
-- Palette : une banlieue grise et passee. Un accent depense partout ne
-- designe plus rien : le rouge est reserve a l'Oeil.
--------------------------------------------------------------------------------

local C = {
	asphalt = Color3.fromRGB(58, 58, 60),
	asphaltPatch = Color3.fromRGB(46, 46, 48),
	line = Color3.fromRGB(176, 170, 150),
	concrete = Color3.fromRGB(150, 146, 138),
	concreteDark = Color3.fromRGB(104, 101, 96),
	curb = Color3.fromRGB(128, 125, 118),
	sidingCream = Color3.fromRGB(196, 186, 164),
	sidingSage = Color3.fromRGB(132, 140, 122),
	sidingBlue = Color3.fromRGB(116, 126, 136),
	sidingGray = Color3.fromRGB(150, 148, 142),
	brickRed = Color3.fromRGB(128, 78, 62),
	brickBrown = Color3.fromRGB(110, 88, 72),
	roofSlate = Color3.fromRGB(58, 58, 62),
	roofBrown = Color3.fromRGB(86, 62, 52),
	trim = Color3.fromRGB(210, 204, 192),
	wood = Color3.fromRGB(112, 86, 62),
	woodGray = Color3.fromRGB(118, 110, 100),
	glass = Color3.fromRGB(150, 168, 176),
	leaves = Color3.fromRGB(78, 92, 58),
	leavesDry = Color3.fromRGB(110, 104, 64),
	hedge = Color3.fromRGB(64, 80, 50),
	bark = Color3.fromRGB(72, 60, 50),
	metal = Color3.fromRGB(88, 92, 94),
	rust = Color3.fromRGB(112, 70, 48),
	black = Color3.fromRGB(22, 22, 24),
	fabric = Color3.fromRGB(96, 84, 74),
	plaster = Color3.fromRGB(184, 178, 168),
	eyeWhite = Color3.fromRGB(232, 226, 214),
	eyeIris = Color3.fromRGB(196, 72, 50),
	rift = Color3.fromRGB(255, 120, 80),
}

local SIDINGS = { C.sidingCream, C.sidingSage, C.sidingBlue, C.sidingGray }
local CAR_COLORS = {
	Color3.fromRGB(120, 124, 128),
	Color3.fromRGB(86, 96, 110),
	Color3.fromRGB(128, 112, 92),
	Color3.fromRGB(96, 60, 52),
	Color3.fromRGB(170, 168, 160),
}

--------------------------------------------------------------------------------
-- Outils de construction
--------------------------------------------------------------------------------

local partCount = 0

local function P(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	material: Enum.Material,
	color: Color3,
	options: { [string]: any }?
): BasePart
	local o = options or {}
	local p: BasePart = Instance.new(o.class or "Part") :: BasePart
	if o.shape and p:IsA("Part") then
		p.Shape = o.shape
	end
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Material = material
	p.Color = color
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if o.transparency then
		p.Transparency = o.transparency
	end
	if o.collide == false then
		p.CanCollide = false
	end
	if o.query == false then
		p.CanQuery = false
		p.CanTouch = false
	end
	if o.shadow == false then
		p.CastShadow = false
	end
	if o.cover then
		p:SetAttribute(CONTRACT.cover, o.cover)
	end
	p.Parent = parent
	partCount += 1
	return p
end

local function folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function model(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- Un marqueur invisible : interieur, sortie, depart.
local function marker(parent: Instance, name: string, cframe: CFrame): BasePart
	return P(parent, name, Vector3.new(2, 2, 2), cframe, Enum.Material.SmoothPlastic, C.black, {
		transparency = 1,
		collide = false,
		query = false,
		shadow = false,
	})
end

-- Un triangle plein, fait de deux coins. Methode classique : on oriente
-- chaque coin par une base calculee, sans dependre du sens par defaut d'une
-- WedgePart.
local function triangle(
	parent: Instance,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	thickness: number,
	material: Enum.Material,
	color: Color3
)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local right = ac:Cross(ab).Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	P(
		parent,
		"Pignon",
		Vector3.new(thickness, height, math.abs(ab:Dot(back))),
		CFrame.fromMatrix((a + b) / 2, right, up, back),
		material,
		color,
		{ class = "WedgePart" }
	)
	P(
		parent,
		"Pignon",
		Vector3.new(thickness, height, math.abs(ac:Dot(back))),
		CFrame.fromMatrix((a + c) / 2, -right, up, -back),
		material,
		color,
		{ class = "WedgePart" }
	)
end

type Opening = {
	x: number,
	w: number,
	b: number,
	t: number,
	kind: string?, -- "window" | "door" | "garage"
}

-- Un mur droit le long de son X local, du sol (y = 0) a `height`, perce
-- d'ouvertures. Les fenetres recoivent une vitre (parfois cassee, parfois
-- condamnee par des planches) et un encadrement.
local function wall(
	parent: Instance,
	cf: CFrame,
	length: number,
	height: number,
	thick: number,
	openings: { Opening },
	material: Enum.Material,
	color: Color3
)
	table.sort(openings, function(o1, o2)
		return o1.x < o2.x
	end)
	local function segment(x0: number, x1: number, y0: number, y1: number)
		if x1 - x0 < 0.05 or y1 - y0 < 0.05 then
			return
		end
		P(
			parent,
			"Mur",
			Vector3.new(x1 - x0, y1 - y0, thick),
			cf * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, 0),
			material,
			color
		)
	end
	local cursor = -length / 2
	for _, o in openings do
		local left, right = o.x - o.w / 2, o.x + o.w / 2
		segment(cursor, left, 0, height)
		segment(left, right, 0, o.b)
		segment(left, right, o.t, height)
		cursor = right

		-- L'encadrement : c'est lui qui fait d'un trou une fenetre.
		if o.kind == "window" or o.kind == "door" then
			local fw = 0.35
			for _, sx in { -1, 1 } do
				P(
					parent,
					"Cadre",
					Vector3.new(fw, o.t - o.b, thick + 0.3),
					cf * CFrame.new(o.x + sx * (o.w / 2 + fw / 2), (o.b + o.t) / 2, 0),
					Enum.Material.SmoothPlastic,
					C.trim
				)
			end
			P(
				parent,
				"Cadre",
				Vector3.new(o.w + fw * 2, fw, thick + 0.3),
				cf * CFrame.new(o.x, o.t + fw / 2, 0),
				Enum.Material.SmoothPlastic,
				C.trim
			)
		end
		if o.kind == "window" then
			local roll = random:NextNumber()
			local glassCf = cf * CFrame.new(o.x, (o.b + o.t) / 2, 0)
			if roll < 0.18 then
				-- Condamnee : des planches clouees, opaques.
				for i = 0, 2 do
					P(
						parent,
						"Planche",
						Vector3.new(o.w + 0.6, 0.7, 0.2),
						glassCf
							* CFrame.new(0, (i - 1) * (o.t - o.b) / 3, -thick / 2 - 0.1)
							* CFrame.Angles(0, 0, math.rad(random:NextNumber(-8, 8))),
						Enum.Material.WoodPlanks,
						C.woodGray
					)
				end
			elseif roll > 0.32 then
				P(
					parent,
					"Vitre",
					Vector3.new(o.w, o.t - o.b, 0.15),
					glassCf,
					Enum.Material.Glass,
					C.glass,
					{ transparency = 0.6, shadow = false }
				)
			end
			-- Rebord sous la fenetre.
			P(
				parent,
				"Rebord",
				Vector3.new(o.w + 0.6, 0.3, thick + 0.4),
				cf * CFrame.new(o.x, o.b - 0.15, 0),
				Enum.Material.SmoothPlastic,
				C.trim
			)
		end
	end
	segment(cursor, length / 2, 0, height)
end

-- Une pente de toit : une dalle de l'egout au faitage.
local function slab(
	parent: Instance,
	from: Vector3,
	to: Vector3,
	width: number,
	thick: number,
	material: Enum.Material,
	color: Color3,
	name: string
): BasePart
	local mid = (from + to) / 2
	return P(
		parent,
		name,
		Vector3.new(width, thick, (to - from).Magnitude),
		CFrame.lookAt(mid, to),
		material,
		color
	)
end

--------------------------------------------------------------------------------
-- Les pieces de la ville
--------------------------------------------------------------------------------

-- Le modele d'arbre genere (docs/ASSETS.md), s'il est dans la place.
local treeTemplate: Model? = nil
local generatedTrees = 0

local function tree(parent: Instance, position: Vector3, dead: boolean)
	if not dead and treeTemplate then
		local clone = treeTemplate:Clone()
		clone.Name = "Arbre"
		clone:ScaleTo(random:NextNumber(0.9, 1.3))
		local size = clone:GetExtentsSize()
		clone:PivotTo(
			CFrame.new(position + Vector3.new(0, size.Y / 2, 0))
				* CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0)
		)
		for _, part in clone:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = true
				-- Le feuillage ne bloque pas les joueurs et ne couvre qu'a
				-- moitie vu du ciel ; le tronc, lui, est une part a part.
				part.CanCollide = false
				part:SetAttribute(CONTRACT.cover, 0.55)
			end
		end
		clone.Parent = parent
		P(
			clone,
			"Tronc",
			Vector3.new(size.Y * 0.45, 1.6, 1.6),
			CFrame.new(position + Vector3.new(0, size.Y * 0.225, 0))
				* CFrame.Angles(0, 0, math.rad(90)),
			Enum.Material.Wood,
			C.bark,
			{
				shape = Enum.PartType.Cylinder,
				transparency = 1,
				shadow = false,
			}
		)
		generatedTrees += 1
		return
	end
	local m = model(parent, "Arbre")
	local height = random:NextNumber(14, 20)
	-- Un cylindre prend sa longueur sur X : on le redresse.
	P(
		m,
		"Tronc",
		Vector3.new(height, 1.6, 1.6),
		CFrame.new(position + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Enum.Material.Wood,
		C.bark,
		{ shape = Enum.PartType.Cylinder }
	)
	if dead then
		for i = 1, 4 do
			local yaw = math.rad(i * 90 + random:NextNumber(-20, 20))
			local branch = Vector3.new(math.cos(yaw), 0.8, math.sin(yaw)).Unit
			local start = position + Vector3.new(0, height * random:NextNumber(0.55, 0.85), 0)
			slab(m, start, start + branch * 6, 0.6, 0.6, Enum.Material.Wood, C.bark, "Branche")
		end
		return
	end
	local color = if random:NextNumber() < 0.4 then C.leavesDry else C.leaves
	for i = 1, 5 do
		local size = random:NextNumber(7, 11)
		local offset = Vector3.new(
			random:NextNumber(-3, 3),
			random:NextNumber(-1.5, 2.5),
			random:NextNumber(-3, 3)
		)
		if i == 1 then
			offset = Vector3.zero
		end
		-- Un Ball est une sphere du plus petit cote : taille cubique.
		P(
			m,
			"Feuillage",
			Vector3.new(size, size, size),
			CFrame.new(position + Vector3.new(0, height, 0) + offset),
			Enum.Material.LeafyGrass,
			color,
			{ shape = Enum.PartType.Ball, collide = false, cover = 0.55 }
		)
	end
end

local function hedge(parent: Instance, from: Vector3, to: Vector3)
	local length = (to - from).Magnitude
	P(
		parent,
		"Haie",
		Vector3.new(2.6, 3.6, length),
		CFrame.lookAt((from + to) / 2 + Vector3.new(0, 1.8, 0), to + Vector3.new(0, 1.8, 0)),
		Enum.Material.LeafyGrass,
		C.hedge,
		{ cover = 0.5 }
	)
end

local function fence(parent: Instance, from: Vector3, to: Vector3, height: number)
	local length = (to - from).Magnitude
	local dir = (to - from).Unit
	local cf = CFrame.lookAt(from, to)
	local posts = math.max(2, math.floor(length / 8) + 1)
	for i = 0, posts - 1 do
		local at = from + dir * (length * i / (posts - 1))
		P(
			parent,
			"Poteau",
			Vector3.new(0.6, height + 0.6, 0.6),
			CFrame.new(at + Vector3.new(0, (height + 0.6) / 2, 0)),
			Enum.Material.Wood,
			C.woodGray
		)
	end
	-- Des planches verticales serrees : on ne voit pas au travers.
	P(
		parent,
		"Palissade",
		Vector3.new(0.3, height, length),
		cf * CFrame.new(0, height / 2, -length / 2),
		Enum.Material.WoodPlanks,
		C.woodGray
	)
end

local function lamp(parent: Instance, position: Vector3, facing: Vector3)
	local m = model(parent, "Lampadaire")
	P(
		m,
		"Mat",
		Vector3.new(14, 0.7, 0.7),
		CFrame.new(position + Vector3.new(0, 7, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Enum.Material.Metal,
		C.metal,
		{ shape = Enum.PartType.Cylinder }
	)
	local arm = position + Vector3.new(0, 14, 0)
	slab(m, arm, arm + facing * 3.5, 0.5, 0.5, Enum.Material.Metal, C.metal, "Bras")
	local head = P(
		m,
		"Tete",
		Vector3.new(1.6, 0.6, 2.4),
		CFrame.lookAt(
			arm + facing * 3.8 - Vector3.new(0, 0.3, 0),
			arm + facing * 8 - Vector3.new(0, 0.3, 0)
		),
		Enum.Material.Metal,
		C.metal
	)
	-- Eteint : il n'y a plus de courant. Un seul, au carrefour, clignote
	-- faiblement (pose par l'appelant).
	return head
end

-- Une voiture, le long de son Z local. Rend le modele et le point de la
-- cabine (pour se cacher dedans).
local function car(parent: Instance, cf: CFrame, color: Color3, wrecked: boolean): (Model, CFrame)
	local m = model(parent, "Voiture")
	local tilt = if wrecked
		then CFrame.Angles(math.rad(random:NextNumber(-2, 2)), 0, math.rad(random:NextNumber(2, 5)))
		else CFrame.identity
	local base = cf * tilt
	local paint = if wrecked then color:Lerp(C.rust, 0.45) else color
	P(
		m,
		"Carrosserie",
		Vector3.new(6.2, 2.1, 14),
		base * CFrame.new(0, 1.75, 0),
		Enum.Material.SmoothPlastic,
		paint
	)
	P(
		m,
		"Capot",
		Vector3.new(6.0, 0.5, 4.2),
		base * CFrame.new(0, 2.95, -4.6),
		Enum.Material.SmoothPlastic,
		paint
	)
	P(
		m,
		"Coffre",
		Vector3.new(6.0, 0.5, 3.0),
		base * CFrame.new(0, 2.95, 5.2),
		Enum.Material.SmoothPlastic,
		paint
	)
	P(
		m,
		"Toit",
		Vector3.new(5.6, 0.4, 6.0),
		base * CFrame.new(0, 4.75, 0.4),
		Enum.Material.SmoothPlastic,
		paint
	)
	-- Cabine vitree, sombre.
	P(
		m,
		"Vitres",
		Vector3.new(5.5, 1.6, 6.6),
		base * CFrame.new(0, 3.75, 0.4),
		Enum.Material.Glass,
		Color3.fromRGB(40, 46, 52),
		{ transparency = if wrecked then 0.75 else 0.35 }
	)
	for _, side in { -1, 1 } do
		for _, front in { -1, 1 } do
			if wrecked and side == 1 and front == 1 then
				continue
			end
			P(
				m,
				"Roue",
				Vector3.new(1.1, 2.5, 2.5),
				base * CFrame.new(side * 2.85, 1.25, front * 4.6),
				Enum.Material.SmoothPlastic,
				C.black,
				{ shape = Enum.PartType.Cylinder }
			)
		end
		P(
			m,
			"Phare",
			Vector3.new(1.2, 0.5, 0.2),
			base * CFrame.new(side * 2.2, 2.3, -7.05),
			Enum.Material.Glass,
			C.trim
		)
		P(
			m,
			"Feu",
			Vector3.new(1.2, 0.5, 0.2),
			base * CFrame.new(side * 2.2, 2.3, 7.05),
			Enum.Material.Glass,
			Color3.fromRGB(120, 40, 36)
		)
	end
	P(
		m,
		"PareChoc",
		Vector3.new(6.4, 0.6, 0.5),
		base * CFrame.new(0, 1.0, -7.1),
		Enum.Material.Metal,
		C.metal
	)
	P(
		m,
		"PareChoc",
		Vector3.new(6.4, 0.6, 0.5),
		base * CFrame.new(0, 1.0, 7.1),
		Enum.Material.Metal,
		C.metal
	)
	return m, base * CFrame.new(0, 3.2, 0.4)
end

local function rubble(parent: Instance, center: Vector3, radius: number, count: number)
	for _ = 1, count do
		local angle = random:NextNumber(0, math.pi * 2)
		local dist = random:NextNumber(0, radius)
		local at = center + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
		local s = random:NextNumber(0.8, 2.6)
		local isWood = random:NextNumber() < 0.45
		P(
			parent,
			"Gravat",
			if isWood then Vector3.new(0.4, 0.4 * s, s * 2.2) else Vector3.new(s, s * 0.6, s * 0.9),
			CFrame.new(at + Vector3.new(0, s * 0.25, 0))
				* CFrame.Angles(
					random:NextNumber(-0.6, 0.6),
					random:NextNumber(0, math.pi),
					random:NextNumber(-0.6, 0.6)
				),
			if isWood then Enum.Material.WoodPlanks else Enum.Material.Concrete,
			if isWood then C.woodGray else C.concreteDark
		)
	end
end

--------------------------------------------------------------------------------
-- Les maisons
--------------------------------------------------------------------------------

type HouseOptions = {
	name: string,
	siding: Color3,
	material: Enum.Material,
	roof: Color3,
	damage: string, -- "intact" | "trou" | "ruine"
	garage: boolean,
}

type HouseResult = {
	inside: Vector3, -- un point du salon, pour la mesure de couverture
	kitchen: CFrame,
	bathroom: CFrame,
	garage: CFrame?,
}

local HOUSE_W, HOUSE_D, WALL_H, FLOOR_Y, THICK = 26, 22, 10, 0.6, 0.8

-- `cf` : le milieu du bas de la facade, l'axe Z local entrant dans la maison.
local function house(
	parent: Instance,
	cf: CFrame,
	o: HouseOptions,
	containers: Instance
): HouseResult
	local m = model(parent, o.name)
	local w, d, h = HOUSE_W, HOUSE_D, WALL_H
	local floorCf = cf * CFrame.new(0, FLOOR_Y, 0)

	P(
		m,
		"Fondation",
		Vector3.new(w + 0.4, FLOOR_Y + 1, d + 0.4),
		cf * CFrame.new(0, (FLOOR_Y - 1) / 2, d / 2),
		Enum.Material.Concrete,
		C.concreteDark
	)
	P(
		m,
		"Plancher",
		Vector3.new(w - 1, 0.2, d - 1),
		floorCf * CFrame.new(0, 0.1, d / 2),
		Enum.Material.WoodPlanks,
		C.wood
	)

	-- Facade : porte, deux fenetres.
	wall(m, floorCf * CFrame.new(0, 0, THICK / 2), w, h, THICK, {
		{ x = -2.5, w = 4, b = 0, t = 7.5, kind = "door" },
		{ x = 6.5, w = 5, b = 3, t = 7.2, kind = "window" },
		{ x = -9.5, w = 4, b = 3, t = 7.2, kind = "window" },
	}, o.material, o.siding)
	-- Arriere : porte de jardin, fenetre.
	wall(m, floorCf * CFrame.new(0, 0, d - THICK / 2), w, h, THICK, {
		{ x = 3, w = 3.6, b = 0, t = 7.5, kind = "door" },
		{ x = -6, w = 4, b = 3.5, t = 7, kind = "window" },
	}, o.material, o.siding)
	-- Cotes.
	for _, side in { -1, 1 } do
		wall(
			m,
			floorCf
				* CFrame.new(side * (w / 2 - THICK / 2), 0, d / 2)
				* CFrame.Angles(0, math.rad(90), 0),
			d - THICK * 2,
			h,
			THICK,
			{ { x = 0, w = 4, b = 3, t = 7, kind = "window" } },
			o.material,
			o.siding
		)
	end
	-- Cloison : la salle de bain au fond a gauche.
	wall(m, floorCf * CFrame.new(-w / 4 - 0.5, 0, d - 8), w / 2 - 1, h, 0.5, {
		{ x = 2, w = 3.4, b = 0, t = 7.4, kind = "door" },
	}, Enum.Material.SmoothPlastic, C.plaster)

	-- Le seuil et la marche devant la porte.
	P(
		m,
		"Marche",
		Vector3.new(5, 0.6, 2.4),
		cf * CFrame.new(-2.5, 0.3, -1.2),
		Enum.Material.Concrete,
		C.concrete
	)
	-- La porte, entrouverte contre le mur.
	P(
		m,
		"Porte",
		Vector3.new(3.8, 7.3, 0.3),
		floorCf * CFrame.new(-4.5, 3.65, 1.9) * CFrame.Angles(0, math.rad(80), 0),
		Enum.Material.WoodPlanks,
		o.siding:Lerp(C.wood, 0.6)
	)

	-- Meubles : un canape, une table, une chaise renversee.
	P(
		m,
		"Canape",
		Vector3.new(7, 2.4, 2.6),
		floorCf * CFrame.new(5, 1.2, 9),
		Enum.Material.Fabric,
		C.fabric
	)
	P(
		m,
		"Table",
		Vector3.new(4, 2.6, 2.6),
		floorCf * CFrame.new(-6, 1.3, 6),
		Enum.Material.WoodPlanks,
		C.wood
	)
	P(
		m,
		"Chaise",
		Vector3.new(1.6, 2.8, 1.6),
		floorCf * CFrame.new(-3.5, 0.8, 8) * CFrame.Angles(math.rad(85), math.rad(30), 0),
		Enum.Material.WoodPlanks,
		C.wood
	)

	-- Les contenants a fouiller (le serveur y pose les invites).
	local kitchenCf = floorCf * CFrame.new(w / 2 - 3.2, 1.5, d - 1.6)
	local kitchen = P(
		containers,
		o.name .. "_Cuisine",
		Vector3.new(4.6, 3, 1.8),
		kitchenCf,
		Enum.Material.WoodPlanks,
		C.trim:Lerp(C.wood, 0.3)
	)
	kitchen:SetAttribute("Table", "cuisine")
	P(
		m,
		"Plan",
		Vector3.new(6, 0.25, 2.2),
		floorCf * CFrame.new(w / 2 - 4, 3.1, d - 1.7),
		Enum.Material.Granite,
		C.concrete
	)
	local bathCf = floorCf * CFrame.new(-w / 2 + 2.6, 4, d - 1.1)
	local bath = P(
		containers,
		o.name .. "_SalleDeBain",
		Vector3.new(2.6, 2.6, 0.9),
		bathCf,
		Enum.Material.SmoothPlastic,
		C.trim
	)
	bath:SetAttribute("Table", "salleDeBain")
	P(
		m,
		"Baignoire",
		Vector3.new(4.2, 2, 7),
		floorCf * CFrame.new(-w / 2 + 3, 1, d - 4.6),
		Enum.Material.SmoothPlastic,
		C.plaster
	)

	-- Plafond et toit, selon les degats.
	local top = FLOOR_Y + h
	if o.damage ~= "ruine" then
		if o.damage == "trou" then
			-- Le salon est a ciel ouvert : on y croit etre a l'abri, a tort.
			P(
				m,
				"Plafond",
				Vector3.new(w, 0.4, d * 0.45),
				cf * CFrame.new(0, top + 0.2, d * 0.775),
				Enum.Material.SmoothPlastic,
				C.plaster
			)
			rubble(m, (cf * CFrame.new(2, FLOOR_Y, 6)).Position, 5, 10)
		else
			P(
				m,
				"Plafond",
				Vector3.new(w, 0.4, d),
				cf * CFrame.new(0, top + 0.2, d / 2),
				Enum.Material.SmoothPlastic,
				C.plaster
			)
		end
		local ridgeH = 6.5
		local eaveFront = (cf * CFrame.new(0, top, -1.4)).Position
		local eaveBack = (cf * CFrame.new(0, top, d + 1.4)).Position
		local ridge = (cf * CFrame.new(0, top + ridgeH, d / 2)).Position
		if o.damage ~= "trou" then
			slab(m, eaveFront, ridge, w + 2.4, 0.6, Enum.Material.Slate, o.roof, "Toit")
		else
			-- Il reste quelques chevrons du pan arrache.
			for i = -2, 2 do
				local offset = (cf.RightVector * i * 5)
				slab(
					m,
					eaveFront + offset,
					ridge + offset,
					0.5,
					0.5,
					Enum.Material.Wood,
					C.wood,
					"Chevron"
				)
			end
		end
		slab(m, eaveBack, ridge, w + 2.4, 0.6, Enum.Material.Slate, o.roof, "Toit")
		for _, side in { -1, 1 } do
			local x = side * (w / 2 - THICK / 2)
			triangle(
				m,
				(cf * CFrame.new(x, top, 0)).Position,
				(cf * CFrame.new(x, top, d)).Position,
				(cf * CFrame.new(x, top + ridgeH, d / 2)).Position,
				THICK,
				o.material,
				o.siding
			)
		end
		-- Gouttieres le long des egouts.
		for _, eave in { eaveFront, eaveBack } do
			P(
				m,
				"Gouttiere",
				Vector3.new(w + 2.4, 0.5, 0.5),
				CFrame.new(eave - Vector3.new(0, 0.45, 0)) * (cf - cf.Position),
				Enum.Material.Metal,
				C.metal
			)
		end
		-- Cheminee.
		P(
			m,
			"Cheminee",
			Vector3.new(2.4, 6, 2.4),
			cf * CFrame.new(w / 2 - 5, top + 5, d * 0.7),
			Enum.Material.Brick,
			C.brickBrown
		)
	else
		rubble(m, (cf * CFrame.new(0, FLOOR_Y, d / 2)).Position, 9, 24)
	end

	-- Le porche : un petit auvent sur deux poteaux.
	if o.damage == "intact" then
		P(
			m,
			"Auvent",
			Vector3.new(7, 0.4, 4),
			cf * CFrame.new(-2.5, FLOOR_Y + 8.4, -2),
			Enum.Material.WoodPlanks,
			C.trim
		)
		for _, side in { -1, 1 } do
			P(
				m,
				"Poteau",
				Vector3.new(0.5, 8.2, 0.5),
				cf * CFrame.new(-2.5 + side * 3.1, 4.4, -3.6),
				Enum.Material.Wood,
				C.trim
			)
		end
	end

	local result: HouseResult = {
		inside = (cf * CFrame.new(5, FLOOR_Y + 3, 5)).Position,
		kitchen = kitchenCf,
		bathroom = bathCf,
		garage = nil,
	}

	if o.garage then
		local gx = w / 2 + 6.2
		local gcf = cf * CFrame.new(gx, 0, 2)
		local gm = model(m, "Garage")
		P(
			gm,
			"Dalle",
			Vector3.new(12, 0.6, 16),
			gcf * CFrame.new(0, 0.3, 8),
			Enum.Material.Concrete,
			C.concrete
		)
		wall(gm, gcf * CFrame.new(0, 0.6, 0.4), 12, 8, THICK, {
			{ x = 0, w = 9, b = 0, t = 6.6, kind = "garage" },
		}, o.material, o.siding)
		-- La porte basculante, coincee a mi-hauteur.
		P(
			gm,
			"PorteGarage",
			Vector3.new(9, 3.4, 0.3),
			gcf * CFrame.new(0, 5.5, 0.9),
			Enum.Material.Metal,
			C.trim
		)
		wall(gm, gcf * CFrame.new(0, 0.6, 15.6), 12, 8, THICK, {}, o.material, o.siding)
		wall(
			gm,
			gcf * CFrame.new(5.6, 0.6, 8) * CFrame.Angles(0, math.rad(90), 0),
			14.4,
			8,
			THICK,
			{},
			o.material,
			o.siding
		)
		P(
			gm,
			"Toit",
			Vector3.new(13, 0.6, 17),
			gcf * CFrame.new(0, 8.9, 8),
			Enum.Material.Slate,
			o.roof
		)
		local shelfCf = gcf * CFrame.new(0, 2.4, 14.6)
		local shelf = P(
			containers,
			o.name .. "_Garage",
			Vector3.new(7, 4.2, 1.6),
			shelfCf,
			Enum.Material.Metal,
			C.metal
		)
		shelf:SetAttribute("Table", "garage")
		P(
			gm,
			"Etabli",
			Vector3.new(4, 3, 2),
			gcf * CFrame.new(-3.5, 2.1, 12),
			Enum.Material.WoodPlanks,
			C.wood
		)
		result.garage = shelfCf
	end

	return result
end

--------------------------------------------------------------------------------
-- Les cachettes fragiles (modeles dans ServerStorage)
--------------------------------------------------------------------------------

-- Chaque modele a une part `Socle` invisible : c'est elle qui se pose sur
-- l'emplacement (centre a y = 0,5 au-dessus du sol).
local function prefabRoot(parent: Instance, name: string, footprint: Vector3): (Model, CFrame)
	local m = model(parent, name)
	local base = CFrame.new(0, 0.5, 0)
	local socle = P(
		m,
		"Socle",
		Vector3.new(footprint.X, 1, footprint.Z),
		base,
		Enum.Material.SmoothPlastic,
		C.black,
		{
			transparency = 1,
			collide = false,
			query = false,
			shadow = false,
		}
	)
	m.PrimaryPart = socle
	-- Le sol est a y = 0 : on construit depuis lui.
	return m, CFrame.new(0, 0, 0)
end

local function buildPrefabs(storage: Instance)
	-- L'abri de jardin : on se cache dedans.
	do
		local m, g = prefabRoot(storage, "Abri", Vector3.new(8, 1, 9))
		P(
			m,
			"Plancher",
			Vector3.new(7, 0.4, 8),
			g * CFrame.new(0, 0.2, 0),
			Enum.Material.WoodPlanks,
			C.woodGray
		)
		wall(
			m,
			g * CFrame.new(0, 0.4, -3.8),
			7,
			7,
			0.4,
			{ { x = 0, w = 3, b = 0, t = 6, kind = "door" } },
			Enum.Material.WoodPlanks,
			C.sidingSage:Lerp(C.woodGray, 0.5)
		)
		wall(
			m,
			g * CFrame.new(0, 0.4, 3.8),
			7,
			6,
			0.4,
			{},
			Enum.Material.WoodPlanks,
			C.sidingSage:Lerp(C.woodGray, 0.5)
		)
		for _, side in { -1, 1 } do
			wall(
				m,
				g * CFrame.new(side * 3.3, 0.4, 0) * CFrame.Angles(0, math.rad(90), 0),
				7.2,
				6.5,
				0.4,
				{},
				Enum.Material.WoodPlanks,
				C.sidingSage:Lerp(C.woodGray, 0.5)
			)
		end
		slab(
			m,
			Vector3.new(0, 7.6, -4.6),
			Vector3.new(0, 6.6, 4.6),
			8.4,
			0.4,
			Enum.Material.CorrodedMetal,
			C.metal,
			"Toit"
		)
		P(
			m,
			"PorteAbri",
			Vector3.new(2.9, 5.8, 0.25),
			g * CFrame.new(-2.4, 3.3, -5) * CFrame.Angles(0, math.rad(70), 0),
			Enum.Material.WoodPlanks,
			C.woodGray
		)
		marker(m, CONTRACT.inside, CFrame.new(0, 3, 1))
		marker(m, CONTRACT.exit, CFrame.new(0, 3, -6.5))
	end
	-- La voiture : on se cache dans l'habitacle.
	do
		local m = prefabRoot(storage, "Voiture", Vector3.new(7, 1, 15))
		local color = CAR_COLORS[random:NextInteger(1, #CAR_COLORS)]
		local _, cabin = car(m, CFrame.new(0, 0, 0), color, false)
		-- Le modele de voiture est un sous-modele : on remonte ses parts.
		local sub = m:FindFirstChild("Voiture")
		if sub then
			for _, child in sub:GetChildren() do
				child.Parent = m
			end
			sub:Destroy()
		end
		marker(m, CONTRACT.inside, cabin)
		marker(m, CONTRACT.exit, CFrame.new(5.2, 3, 0))
	end
	-- La benne : dedans, couvercle ferme.
	do
		local m, g = prefabRoot(storage, "Benne", Vector3.new(8.5, 1, 5.5))
		P(
			m,
			"Cuve",
			Vector3.new(8, 4.4, 5),
			g * CFrame.new(0, 2.5, 0),
			Enum.Material.Metal,
			Color3.fromRGB(58, 74, 60)
		)
		P(
			m,
			"Couvercle",
			Vector3.new(8.2, 0.3, 5.3),
			g * CFrame.new(0, 4.85, 0.1) * CFrame.Angles(math.rad(-4), 0, 0),
			Enum.Material.Plastic,
			C.black
		)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				P(
					m,
					"Roulette",
					Vector3.new(0.5, 0.8, 0.8),
					g * CFrame.new(sx * 3.4, 0.4, sz * 2),
					Enum.Material.SmoothPlastic,
					C.black,
					{ shape = Enum.PartType.Cylinder }
				)
			end
		end
		marker(m, CONTRACT.inside, CFrame.new(0, 2.2, 0))
		marker(m, CONTRACT.exit, CFrame.new(0, 3, -5))
	end
	-- Une pile de caisses creuse.
	do
		local m, g = prefabRoot(storage, "Caisses", Vector3.new(9, 1, 9))
		for layer = 0, 1 do
			for ix = -1, 1 do
				for iz = -1, 1 do
					if ix == 0 and iz == 0 and layer == 0 then
						continue
					end
					if ix == 0 and iz == -1 and layer == 0 then
						-- L'entree, devant.
						continue
					end
					P(
						m,
						"Caisse",
						Vector3.new(2.9, 2.9, 2.9),
						g
							* CFrame.new(ix * 3, 1.5 + layer * 3, iz * 3)
							* CFrame.Angles(0, math.rad(random:NextNumber(-6, 6)), 0),
						Enum.Material.WoodPlanks,
						C.wood:Lerp(C.woodGray, random:NextNumber(0, 0.6))
					)
				end
			end
		end
		P(
			m,
			"Bache",
			Vector3.new(9.6, 0.2, 9.6),
			g * CFrame.new(0, 6.2, 0) * CFrame.Angles(math.rad(3), 0, math.rad(-2)),
			Enum.Material.Fabric,
			Color3.fromRGB(62, 78, 92)
		)
		marker(m, CONTRACT.inside, CFrame.new(0, 2.4, 0))
		marker(m, CONTRACT.exit, CFrame.new(0, 3, -6))
	end
end

--------------------------------------------------------------------------------
-- La Planque : une cave sous le jardin
--------------------------------------------------------------------------------

local function buildPlanque(root: Instance, terrain: Terrain): Vector3
	local m = model(root, CONTRACT.planque)
	-- Origine : le haut de l'escalier, dans le jardin de la maison du
	-- sud-ouest (sa facade regarde le nord, son jardin est au sud).
	local x0, z0 = -115, -70
	local depth = 10
	local stepRun = 2
	local steps = depth
	local roomZ0 = z0 - steps * stepRun -- -90
	local roomLen, roomW = 16, 20

	-- Sous la cave, du beton : l'herbe decorative traverse les parts minces,
	-- et elle poussait au milieu de la piece (vu en jeu le 5 novembre 2026).
	terrain:FillBlock(
		CFrame.new(x0, -15, z0 - (steps * stepRun + roomLen) / 2),
		Vector3.new(roomW + 10, 26, steps * stepRun + roomLen + 10),
		Enum.Material.Concrete
	)
	-- Creuser : l'escalier puis la piece.
	terrain:FillBlock(
		CFrame.new(x0, -depth / 2, z0 - steps * stepRun / 2),
		Vector3.new(7, depth + 2, steps * stepRun + 1),
		Enum.Material.Air
	)
	terrain:FillBlock(
		CFrame.new(x0, -depth / 2, roomZ0 - roomLen / 2),
		Vector3.new(roomW + 2, depth + 2, roomLen + 2),
		Enum.Material.Air
	)

	-- Les marches : des blocs pleins, du fond jusqu'a chaque marche.
	for i = 0, steps - 2 do
		local topY = -(i + 1)
		local height = depth + topY
		P(
			m,
			"Marche",
			Vector3.new(6, height, stepRun),
			CFrame.new(x0, -depth + height / 2, z0 - i * stepRun - stepRun / 2),
			Enum.Material.Concrete,
			C.concrete
		)
	end
	-- Les murs de la descente, qui depassent un peu du sol.
	for _, side in { -1, 1 } do
		P(
			m,
			"MurEscalier",
			Vector3.new(0.8, depth + 0.6, steps * stepRun),
			CFrame.new(x0 + side * 3.4, -depth / 2 + 0.3, z0 - steps * stepRun / 2),
			Enum.Material.Concrete,
			C.concreteDark
		)
	end
	-- Les battants de la trappe, ouverts.
	for _, side in { -1, 1 } do
		P(
			m,
			"Battant",
			Vector3.new(3, 0.3, 5),
			CFrame.new(x0 + side * 4.6, 1.1, z0 - 2.2) * CFrame.Angles(0, 0, math.rad(side * -70)),
			Enum.Material.Metal,
			C.rust
		)
	end

	-- La piece.
	local floorY = -depth
	local cx, cz = x0, roomZ0 - roomLen / 2
	P(
		m,
		"Sol",
		Vector3.new(roomW, 1, roomLen),
		CFrame.new(cx, floorY - 0.5, cz),
		Enum.Material.Concrete,
		C.concreteDark
	)
	P(
		m,
		"Plafond",
		Vector3.new(roomW + 1.6, 1, roomLen + 1.6),
		CFrame.new(cx, -0.5, cz),
		Enum.Material.Concrete,
		C.concrete
	)
	-- Le plafond prolonge jusque sous l'escalier pour boucher le haut.
	for _, side in { -1, 1 } do
		P(
			m,
			"Mur",
			Vector3.new(0.8, depth, roomLen),
			CFrame.new(cx + side * (roomW / 2 + 0.4), floorY + depth / 2, cz),
			Enum.Material.Concrete,
			C.concreteDark
		)
	end
	P(
		m,
		"Mur",
		Vector3.new(roomW, depth, 0.8),
		CFrame.new(cx, floorY + depth / 2, cz - roomLen / 2 - 0.4),
		Enum.Material.Concrete,
		C.concreteDark
	)
	-- Mur nord : ouvert la ou arrive l'escalier.
	for _, side in { -1, 1 } do
		local wSeg = (roomW - 6) / 2
		P(
			m,
			"Mur",
			Vector3.new(wSeg, depth, 0.8),
			CFrame.new(cx + side * (3 + wSeg / 2), floorY + depth / 2, roomZ0 + 0.4),
			Enum.Material.Concrete,
			C.concreteDark
		)
	end

	-- Le peu qu'on a : un matelas, une lampe, une radio, des etageres.
	P(
		m,
		"Matelas",
		Vector3.new(4, 0.8, 7),
		CFrame.new(cx + 6.5, floorY + 0.4, cz - 3),
		Enum.Material.Fabric,
		Color3.fromRGB(150, 140, 120)
	)
	local lampPart = P(
		m,
		"Lampe",
		Vector3.new(0.8, 1.4, 0.8),
		CFrame.new(cx + 3.5, floorY + 2.7, cz - 6.2),
		Enum.Material.Neon,
		Color3.fromRGB(255, 196, 130)
	)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 190, 130)
	light.Brightness = 1.4
	light.Range = 22
	light.Shadows = true
	light.Parent = lampPart
	P(
		m,
		"Caisse",
		Vector3.new(2.4, 2, 2.4),
		CFrame.new(cx + 3.5, floorY + 1, cz - 6.2),
		Enum.Material.WoodPlanks,
		C.wood
	)
	P(
		m,
		"Radio",
		Vector3.new(1.6, 1, 0.8),
		CFrame.new(cx - 7.5, floorY + 3.5, cz - 7.2),
		Enum.Material.SmoothPlastic,
		Color3.fromRGB(70, 66, 58)
	)
	P(
		m,
		"Etagere",
		Vector3.new(6, 6, 1.4),
		CFrame.new(cx - 6, floorY + 3, cz - 7.4),
		Enum.Material.WoodPlanks,
		C.wood
	)
	for i = 1, 5 do
		P(
			m,
			"Boite",
			Vector3.new(0.7, 0.9, 0.7),
			CFrame.new(cx - 8 + i * 0.9, floorY + 3.95, cz - 7.3),
			Enum.Material.Metal,
			C.metal
		)
	end

	local chest = P(
		m,
		CONTRACT.chest,
		Vector3.new(4, 2.4, 2.4),
		CFrame.new(cx - 6.5, floorY + 1.2, cz + 2),
		Enum.Material.WoodPlanks,
		C.wood:Lerp(C.rust, 0.3)
	)
	P(
		m,
		"Couvercle",
		Vector3.new(4.2, 0.3, 2.6),
		chest.CFrame * CFrame.new(0, 1.35, 0),
		Enum.Material.Metal,
		C.metal
	)
	local spawn = marker(m, CONTRACT.spawn, CFrame.new(cx, floorY + 3, cz + 3))
	return spawn.Position
end

--------------------------------------------------------------------------------
-- Le ciel : la Fissure et l'Oeil
--------------------------------------------------------------------------------

local function buildSky(root: Instance, center: Vector3)
	local m = model(root, SKY.folder)
	-- Toujours charge chez chaque client : l'Oeil se voit de partout, et la
	-- vue du ciel ne prend que les debris presents au demarrage.
	m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local noRay = { collide = false, query = false, shadow = false }
	local riftY = center.Y + EYE_HEIGHT + 10
	local eyeAt = center + Vector3.new(0, EYE_HEIGHT + 95, 0)

	-- LA FISSURE : une dechirure noire en amande, orientee est-ouest, aux
	-- bords irreguliers et brulants. On voit l'Oeil par le trou.
	local halfLong, halfShort = 190, 105
	local segments = 44
	-- Le bord : une couronne pleine entre le trou et un contour exterieur
	-- dechiquete, remplie de triangles (un seul plan, pas des pics).
	local function almond(angle: number, grow: number): Vector3
		local sx = math.cos(angle)
		local sz = math.sin(angle) * (0.55 + 0.45 * math.abs(math.sin(angle)))
		return Vector3.new(sx * (halfLong + grow), riftY, sz * (halfShort + grow))
	end
	local inner: { Vector3 } = {}
	local outer: { Vector3 } = {}
	for i = 0, segments - 1 do
		local a = (i / segments) * math.pi * 2
		table.insert(inner, almond(a, random:NextNumber(-6, 6)))
		-- Le contour exterieur alterne pointes et creux : une dechirure.
		local reach = if i % 2 == 0 then random:NextNumber(90, 190) else random:NextNumber(35, 80)
		table.insert(outer, almond(a, reach))
	end
	local black = Color3.fromRGB(10, 7, 9)
	for i = 1, segments do
		local j = (i % segments) + 1
		triangle(m, inner[i], outer[i], outer[j], 3, Enum.Material.SmoothPlastic, black)
		triangle(m, inner[i], outer[j], inner[j], 3, Enum.Material.SmoothPlastic, black)
		-- La levre brulante, juste au bord du trou.
		local lip = slab(
			m,
			inner[i] - Vector3.new(0, 2, 0),
			inner[j] - Vector3.new(0, 2, 0),
			random:NextNumber(3, 6),
			1.5,
			Enum.Material.Neon,
			C.rift,
			"Levre"
		)
		lip.CanCollide = false
		lip.CanQuery = false
		lip.CastShadow = false
		-- Les coins du remplissage ne doivent ni bloquer ni ombrer.
		for _, child in m:GetChildren() do
			if child:IsA("BasePart") and child.Name == "Pignon" then
				child.CanCollide = false
				child.CanQuery = false
				child.CastShadow = false
				child.Name = "Dechirure"
			end
		end
	end
	-- Les fissures qui courent dans le ciel autour de la dechirure, en zigzag.
	for i = 1, 16 do
		local angle = (i / 16) * math.pi * 2 + random:NextNumber(-0.15, 0.15)
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local at = Vector3.new(dir.X * (halfLong + 80), riftY - 1, dir.Z * (halfShort + 80))
		for _ = 1, random:NextInteger(4, 8) do
			local turn = random:NextNumber(-0.7, 0.7)
			local step = Vector3.new(
				dir.X * math.cos(turn) - dir.Z * math.sin(turn),
				0,
				dir.X * math.sin(turn) + dir.Z * math.cos(turn)
			) * random:NextNumber(40, 90)
			local crack = slab(
				m,
				at,
				at + step,
				random:NextNumber(1.5, 4),
				1.5,
				Enum.Material.Neon,
				C.rift,
				"Fissure"
			)
			crack.CanCollide = false
			crack.CanQuery = false
			crack.CastShadow = false
			crack.Transparency = random:NextNumber(0.1, 0.45)
			at += step
		end
	end
	-- Le fond de la dechirure : un noir profond derriere l'Oeil.
	P(
		m,
		"Neant",
		Vector3.new(halfLong * 2.4, 4, halfShort * 2.4),
		CFrame.new(0, eyeAt.Y + 120, 0),
		Enum.Material.SmoothPlastic,
		Color3.fromRGB(4, 2, 4),
		noRay
	)

	-- L'OEIL. Un modele dont l'avant (-Z) regarde le sol ; la vue du ciel le
	-- tourne vers ce qu'il cherche.
	local eye = model(m, SKY.eye)
	local look = CFrame.lookAt(eyeAt, eyeAt - Vector3.new(0, 1, 0), Vector3.new(0, 0, 1))
	local radius = 120
	local globe = P(
		eye,
		"Globe",
		Vector3.new(radius * 2, radius * 2, radius * 2),
		look,
		Enum.Material.SmoothPlastic,
		Color3.fromRGB(184, 168, 136),
		{
			shape = Enum.PartType.Ball,
			collide = false,
			query = false,
			shadow = false,
		}
	)
	eye.PrimaryPart = globe
	-- Des veines rouges sur le devant du globe.
	for i = 1, 22 do
		local a = (i / 22) * math.pi * 2 + random:NextNumber(-0.1, 0.1)
		local r0 = random:NextNumber(52, 62)
		local r1 = random:NextNumber(85, 112)
		local function onGlobe(r: number): Vector3
			local local_ = Vector3.new(math.cos(a) * r, math.sin(a) * r, 0)
			local z = -math.sqrt(math.max(radius * radius - r * r, 0)) - 0.4
			return (look * CFrame.new(local_.X, local_.Y, z)).Position
		end
		local vein = slab(
			eye,
			onGlobe(r0),
			onGlobe(r1),
			random:NextNumber(0.8, 2.2),
			0.6,
			Enum.Material.Neon,
			Color3.fromRGB(150, 30, 26),
			"Veine"
		)
		vein.CanCollide = false
		vein.CanQuery = false
		vein.CastShadow = false
	end
	-- Iris, anneau sombre, pupille fendue. Un cylindre a son axe sur X : on le
	-- tourne pour que son axe soit l'avant de l'Oeil.
	local face = look * CFrame.Angles(0, math.rad(90), 0)
	local front = radius - 6
	-- Un liseré brulant autour d'un iris sombre : le neon partout faisait un
	-- jouet rouge (vu en image le 5 novembre 2026).
	P(
		eye,
		"Lisere",
		Vector3.new(13, 122, 122),
		face * CFrame.new(front - 0.5, 0, 0),
		Enum.Material.Neon,
		Color3.fromRGB(170, 56, 26),
		{
			shape = Enum.PartType.Cylinder,
			collide = false,
			query = false,
			shadow = false,
		}
	)
	P(
		eye,
		"Iris",
		Vector3.new(14, 116, 116),
		face * CFrame.new(front, 0, 0),
		Enum.Material.SmoothPlastic,
		Color3.fromRGB(66, 20, 12),
		{
			shape = Enum.PartType.Cylinder,
			collide = false,
			query = false,
			shadow = false,
		}
	)
	P(
		eye,
		"AnneauIris",
		Vector3.new(14, 84, 84),
		face * CFrame.new(front + 1.5, 0, 0),
		Enum.Material.SmoothPlastic,
		Color3.fromRGB(32, 8, 6),
		{
			shape = Enum.PartType.Cylinder,
			collide = false,
			query = false,
			shadow = false,
		}
	)
	P(
		eye,
		"Pupille",
		Vector3.new(4, 92, 26),
		look * CFrame.new(0, 0, -(front + 8.5)),
		Enum.Material.SmoothPlastic,
		Color3.fromRGB(4, 2, 2),
		noRay
	)

	-- LES DEBRIS : la ville qui monte vers la Fissure. Des morceaux de murs,
	-- de toits, une voiture, un canape, des planches. La vue du ciel les fait
	-- monter ; ils sont ancres et hors de portee des rayons.
	local debris = folder(m, SKY.debris)
	local kinds = {
		{ Vector3.new(14, 10, 0.8), Enum.Material.WoodPlanks, C.sidingCream },
		{ Vector3.new(12, 0.6, 9), Enum.Material.Slate, C.roofSlate },
		{ Vector3.new(6, 2.4, 2.6), Enum.Material.Fabric, C.fabric },
		{ Vector3.new(0.4, 0.4, 9), Enum.Material.WoodPlanks, C.woodGray },
		{ Vector3.new(8, 8, 0.8), Enum.Material.Brick, C.brickRed },
		{ Vector3.new(3, 3, 3), Enum.Material.WoodPlanks, C.wood },
	}
	for i = 1, 34 do
		local k = kinds[(i % #kinds) + 1]
		local angle = random:NextNumber(0, math.pi * 2)
		local dist = random:NextNumber(40, 230)
		local at =
			Vector3.new(math.cos(angle) * dist, random:NextNumber(120, 560), math.sin(angle) * dist)
		P(
			debris,
			"Debris",
			k[1],
			CFrame.new(at)
				* CFrame.Angles(
					random:NextNumber(0, 6),
					random:NextNumber(0, 6),
					random:NextNumber(0, 6)
				),
			k[2],
			k[3],
			noRay
		)
	end
	for i = 1, 2 do
		local angle = random:NextNumber(0, math.pi * 2)
		local carModel = car(
			debris,
			CFrame.new(math.cos(angle) * 120, 260 + i * 120, math.sin(angle) * 120)
				* CFrame.Angles(random:NextNumber(0, 6), random:NextNumber(0, 6), 0),
			CAR_COLORS[i],
			true
		)
		for _, part in carModel:GetDescendants() do
			if part:IsA("BasePart") then
				part.CanCollide = false
				part.CanQuery = false
				part.CastShadow = false
			end
		end
	end
end

--------------------------------------------------------------------------------
-- La lumiere : basse, grise, sans soleil franc
--------------------------------------------------------------------------------

local function buildLighting()
	for _, child in Lighting:GetChildren() do
		if
			string.sub(child.Name, 1, 8) == "Survivor"
			or child:IsA("Sky")
			or child:IsA("Atmosphere")
		then
			child:Destroy()
		end
	end
	-- Lighting.Technology ne se lit ni ne s'ecrit depuis le pont : a regler a
	-- la main sur Future (Lighting > Technology), une fois pour la place.
	-- Soleil rasant (10 a 22 degres), pour que les ombres existent.
	Lighting.ClockTime = 16.9
	Lighting.GeographicLatitude = 40
	Lighting.Brightness = 2.2
	Lighting.Ambient = Color3.fromRGB(34, 34, 38)
	Lighting.OutdoorAmbient = Color3.fromRGB(112, 110, 108)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.ShadowSoftness = 0.25
	Lighting.ExposureCompensation = 0.1
	Lighting.FogEnd = 100000

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "SurvivorAtmosphere"
	atmosphere.Density = 0.36
	atmosphere.Offset = 0.12
	atmosphere.Color = Color3.fromRGB(178, 172, 164)
	atmosphere.Decay = Color3.fromRGB(110, 96, 88)
	atmosphere.Glare = 0.2
	atmosphere.Haze = 2.2
	atmosphere.Parent = Lighting

	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "SurvivorEtalonnage"
	grade.Saturation = -0.28
	grade.Contrast = 0.12
	grade.Brightness = -0.02
	grade.TintColor = Color3.fromRGB(255, 248, 240)
	grade.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Name = "SurvivorBloom"
	bloom.Intensity = 0.6
	bloom.Size = 28
	bloom.Threshold = 1.6
	bloom.Parent = Lighting

	local rays = Instance.new("SunRaysEffect")
	rays.Name = "SurvivorRayons"
	rays.Intensity = 0.04
	rays.Spread = 0.6
	rays.Parent = Lighting

	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	-- Un ciel couvert, sans trouee bleue : le bleu disait « beau temps ».
	clouds.Cover = 0.92
	clouds.Density = 0.7
	clouds.Color = Color3.fromRGB(140, 136, 134)
	clouds.Parent = workspace.Terrain
end

--------------------------------------------------------------------------------
-- La ville
--------------------------------------------------------------------------------

local function build(): string
	partCount = 0
	generatedTrees = 0
	local library = ServerStorage:FindFirstChild("SurvivorModeles")
	local template = library and library:FindFirstChild("Arbre")
	treeTemplate = if template and template:IsA("Model") then template else nil
	-- Detruire ce qui repond au contrat, et la plaque de depart de Studio.
	for _, name in { CONTRACT.folder, "Baseplate", "SpawnLocation" } do
		local old = workspace:FindFirstChild(name)
		while old do
			old:Destroy()
			old = workspace:FindFirstChild(name)
		end
	end
	local oldPrefabs = ServerStorage:FindFirstChild(CONTRACT.prefabs)
	if oldPrefabs then
		oldPrefabs:Destroy()
	end

	local terrain = workspace.Terrain
	terrain:Clear()
	terrain.Decoration = true
	terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(92, 100, 70))
	terrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(84, 92, 62))
	terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(92, 82, 70))
	-- Le terrain arrondit sa surface sur une grille de 4 studs : rempli
	-- jusqu'a y = 0, sa surface se retrouvait a y = 2, PAR-DESSUS les rues
	-- (mesure au rayon). Rempli jusqu'a -2, elle tombe a 0.
	terrain:FillBlock(CFrame.new(0, -9, 0), Vector3.new(460, 14, 380), Enum.Material.Grass)
	-- L'herbe decorative traverse les parts minces posees dessus : sous les
	-- rues, les trottoirs et les maisons, le terrain est d'une matiere sans
	-- herbe. Vu en image le 5 novembre 2026 : la rue avait disparu.
	terrain.GrassLength = 0.45
	terrain:FillBlock(CFrame.new(0, -4, 0), Vector3.new(460, 4, 28), Enum.Material.Asphalt)
	terrain:FillBlock(CFrame.new(0, -4, 0), Vector3.new(28, 4, 380), Enum.Material.Asphalt)
	for _, sz in { -1, 1 } do
		terrain:FillBlock(
			CFrame.new(0, -4, sz * 16),
			Vector3.new(460, 4, 12),
			Enum.Material.Pavement
		)
		for _, sx in { -1, 1 } do
			terrain:FillBlock(
				CFrame.new(sx * 14, -4, sz * 118),
				Vector3.new(12, 4, 200),
				Enum.Material.Pavement
			)
			for _, px in { 49, 115 } do
				-- Emprise de la maison et de son garage, et des allees.
				terrain:FillBlock(
					CFrame.new(sx * px, -4, sz * 51),
					Vector3.new(56, 4, 26),
					Enum.Material.Pavement
				)
			end
		end
	end
	-- Des plaques de terre nue, la ou rien ne pousse plus.
	for _ = 1, 26 do
		local at = Vector3.new(random:NextNumber(-200, 200), -2.8, random:NextNumber(-170, 170))
		terrain:FillCylinder(CFrame.new(at), 1.6, random:NextNumber(4, 12), Enum.Material.Ground)
	end
	task.wait()

	local root = folder(workspace, CONTRACT.folder)
	local bounds = P(
		root,
		CONTRACT.bounds,
		BOUNDS_SIZE,
		CFrame.new(0, 0, 0),
		Enum.Material.SmoothPlastic,
		C.black,
		{
			transparency = 1,
			collide = false,
			query = false,
			shadow = false,
		}
	)
	local _ = bounds
	local solid = folder(root, CONTRACT.solidSpots)
	local anchors = folder(root, CONTRACT.anchors)
	local containers = folder(root, CONTRACT.containers)
	local streets = folder(root, "Rues")
	local houses = folder(root, "Maisons")
	local nature = folder(root, "Nature")
	local props = folder(root, "Decor")

	-- Les rues. Rien ne se chevauche a la meme hauteur (scintillement).
	P(
		streets,
		"RuePrincipale",
		Vector3.new(420, 0.4, 24),
		CFrame.new(0, 0.2, 0),
		Enum.Material.Asphalt,
		C.asphalt
	)
	for _, sz in { -1, 1 } do
		P(
			streets,
			"RueTransversale",
			Vector3.new(20, 0.4, 200),
			CFrame.new(0, 0.2, sz * 112),
			Enum.Material.Asphalt,
			C.asphalt
		)
		for _, sx in { -1, 1 } do
			-- Trottoirs de la rue principale, coupes au carrefour.
			P(
				streets,
				"Trottoir",
				Vector3.new(200, 0.7, 8),
				CFrame.new(sx * 110, 0.35, sz * 16),
				Enum.Material.Concrete,
				C.concrete
			)
			P(
				streets,
				"Bordure",
				Vector3.new(200, 0.8, 0.6),
				CFrame.new(sx * 110, 0.4, sz * 12.3),
				Enum.Material.Concrete,
				C.curb
			)
			-- Trottoirs de la rue transversale.
			P(
				streets,
				"Trottoir",
				Vector3.new(8, 0.7, 196),
				CFrame.new(sx * 14, 0.35, sz * 118),
				Enum.Material.Concrete,
				C.concrete
			)
			P(
				streets,
				"Bordure",
				Vector3.new(0.6, 0.8, 196),
				CFrame.new(sx * 10.3, 0.4, sz * 118),
				Enum.Material.Concrete,
				C.curb
			)
		end
	end
	-- Le marquage, efface par endroits.
	for x = -200, 200, 14 do
		if math.abs(x) > 14 and random:NextNumber() > 0.25 then
			P(
				streets,
				"Marquage",
				Vector3.new(6, 0.05, 0.5),
				CFrame.new(x, 0.42, 0),
				Enum.Material.SmoothPlastic,
				C.line,
				{ query = false }
			)
		end
	end
	-- Des rapiecages et des fissures.
	for _ = 1, 22 do
		local onMain = random:NextNumber() < 0.65
		local at = if onMain
			then Vector3.new(random:NextNumber(-190, 190), 0.41, random:NextNumber(-10, 10))
			else Vector3.new(
				random:NextNumber(-8, 8),
				0.41,
				random:NextNumber(14, 200) * (if random:NextNumber() < 0.5 then 1 else -1)
			)
		P(
			streets,
			"Rapiecage",
			Vector3.new(random:NextNumber(2, 7), 0.04, random:NextNumber(2, 6)),
			CFrame.new(at) * CFrame.Angles(0, random:NextNumber(0, math.pi), 0),
			Enum.Material.Asphalt,
			C.asphaltPatch,
			{ query = false }
		)
	end
	task.wait()

	-- Les huit parcelles. Facade a 40 studs de l'axe de la rue.
	local plots = {
		{ x = -115, side = 1, opts = { damage = "intact", garage = true } },
		{ x = -49, side = 1, opts = { damage = "trou", garage = false } },
		{ x = 49, side = 1, opts = nil }, -- le terrain vide : la maison aspiree
		{ x = 115, side = 1, opts = { damage = "intact", garage = true } },
		{ x = -115, side = -1, opts = { damage = "ruine", garage = false } }, -- au-dessus de la Planque
		{ x = -49, side = -1, opts = { damage = "intact", garage = true } },
		{ x = 49, side = -1, opts = { damage = "intact", garage = false } },
		{ x = 115, side = -1, opts = { damage = "trou", garage = true } },
	}
	local insides: { { name: string, at: Vector3, covered: boolean } } = {}
	for i, plot in plots do
		local front = plot.side * 40
		local cf = if plot.side == 1
			then CFrame.new(plot.x, 0, front)
			else CFrame.new(plot.x, 0, front) * CFrame.Angles(0, math.pi, 0)
		-- La boite aux lettres au bord du trottoir, parfois renversee.
		local fallen = random:NextNumber() < 0.3
		local mailCf = cf
			* CFrame.new(-7, 0, -19.4)
			* (
				if fallen
					then CFrame.new(0, 0.4, 0) * CFrame.Angles(math.rad(80), 0, 0)
					else CFrame.identity
			)
		P(
			props,
			"PoteauBoite",
			Vector3.new(0.4, 3.6, 0.4),
			mailCf * CFrame.new(0, 1.8, 0),
			Enum.Material.Wood,
			C.woodGray
		)
		P(
			props,
			"BoiteAuxLettres",
			Vector3.new(1.2, 1.2, 2),
			mailCf * CFrame.new(0, 4, 0),
			Enum.Material.Metal,
			if fallen then C.rust else C.metal
		)
		-- Allee du trottoir a la porte, sur un terrain sans herbe.
		terrain:FillBlock(
			cf * CFrame.new(-2.5, -4, -10.3),
			Vector3.new(6, 4, 20),
			Enum.Material.Pavement
		)
		if plot.opts and plot.opts.garage then
			terrain:FillBlock(
				cf * CFrame.new(HOUSE_W / 2 + 6.2, -4, -9.5),
				Vector3.new(12, 4, 22),
				Enum.Material.Pavement
			)
		end
		P(
			streets,
			"Allee",
			Vector3.new(4, 0.3, 19.4),
			cf * CFrame.new(-2.5, 0.15, -10.3),
			Enum.Material.Concrete,
			C.concrete
		)
		if plot.opts then
			local wood = random:NextNumber() < 0.55
			local r = house(houses, cf, {
				name = "Maison" .. i,
				siding = if wood
					then SIDINGS[random:NextInteger(1, #SIDINGS)]
					else (if random:NextNumber() < 0.5 then C.brickRed else C.brickBrown),
				material = if wood then Enum.Material.WoodPlanks else Enum.Material.Brick,
				roof = if random:NextNumber() < 0.6 then C.roofSlate else C.roofBrown,
				damage = plot.opts.damage,
				garage = plot.opts.garage,
			}, containers)
			table.insert(
				insides,
				{ name = "Maison" .. i, at = r.inside, covered = plot.opts.damage == "intact" }
			)
			if plot.opts.garage then
				-- L'allee du garage.
				P(
					streets,
					"AlleeGarage",
					Vector3.new(10, 0.3, 21),
					cf * CFrame.new(HOUSE_W / 2 + 6.2, 0.15, -9.5),
					Enum.Material.Concrete,
					C.concreteDark
				)
			end
		else
			-- La maison a ete prise : il reste la dalle, des gravats, un
			-- cratere de terre retournee.
			P(
				houses,
				"DalleNue",
				Vector3.new(HOUSE_W + 0.4, 1.2, HOUSE_D + 0.4),
				cf * CFrame.new(0, 0.1, HOUSE_D / 2),
				Enum.Material.Concrete,
				C.concreteDark
			)
			rubble(houses, (cf * CFrame.new(0, 0.7, HOUSE_D / 2)).Position, 14, 40)
			terrain:FillCylinder(
				cf * CFrame.new(0, -2.6, HOUSE_D + 12),
				2,
				14,
				Enum.Material.Ground
			)
		end
		-- Haie le long du trottoir, ouverte pour l'allee et le garage. Les
		-- trouees se calculent depuis la maison : au sud, elle est retournee.
		local hz = plot.side * 24
		local gaps = { { (cf * CFrame.new(-2.5, 0, 0)).Position.X, 3.5 } }
		if plot.opts and plot.opts.garage then
			table.insert(gaps, { (cf * CFrame.new(HOUSE_W / 2 + 6.2, 0, 0)).Position.X, 6.5 })
		end
		table.sort(gaps, function(g1, g2)
			return g1[1] < g2[1]
		end)
		local cursor = plot.x - 30
		for _, gap in gaps do
			if gap[1] - gap[2] - cursor > 1 then
				hedge(nature, Vector3.new(cursor, 0, hz), Vector3.new(gap[1] - gap[2], 0, hz))
			end
			cursor = gap[1] + gap[2]
		end
		if plot.x + 30 - cursor > 1 then
			hedge(nature, Vector3.new(cursor, 0, hz), Vector3.new(plot.x + 30, 0, hz))
		end
		-- Palissade du fond de jardin et entre les jardins.
		fence(
			nature,
			Vector3.new(plot.x - 32, 0, plot.side * 115),
			Vector3.new(plot.x + 32, 0, plot.side * 115),
			6
		)
		fence(
			nature,
			Vector3.new(plot.x + 32, 0, plot.side * 66),
			Vector3.new(plot.x + 32, 0, plot.side * 115),
			5
		)
		task.wait()
	end

	-- Les arbres : dans les jardins et sur les pelouses, quelques-uns morts.
	local treeSpots = {
		Vector3.new(-135, 0, 30),
		Vector3.new(-70, 0, 32),
		Vector3.new(28, 0, 30),
		Vector3.new(140, 0, 31),
		Vector3.new(-90, 0, -30),
		Vector3.new(-25, 0, -32),
		Vector3.new(72, 0, -30),
		Vector3.new(84, 0, -32),
		Vector3.new(-100, 0, 85),
		Vector3.new(-20, 0, 80),
		Vector3.new(85, 0, 100),
		Vector3.new(30, 0, 70),
		Vector3.new(-140, 0, -100),
		Vector3.new(-70, 0, -82),
		Vector3.new(20, 0, -84),
		Vector3.new(140, 0, -76),
	}
	for i, at in treeSpots do
		tree(nature, at, i % 4 == 0)
	end
	task.wait()

	-- Les poteaux electriques et leurs fils : c'est ce qui dit « banlieue »
	-- au premier coup d'oeil. Les fils sont des Beam (courbes, sans rayon).
	local previous: { Attachment }? = nil
	for x = -165, 165, 46 do
		local leaning = math.abs(x - 19) < 1
		local base = CFrame.new(x, 0.7, 21.5)
			* (if leaning then CFrame.Angles(math.rad(-14), 0, math.rad(6)) else CFrame.identity)
		local pole = P(
			props,
			"Poteau",
			Vector3.new(24, 1.1, 1.1),
			base * CFrame.new(0, 12, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Enum.Material.Wood,
			C.bark,
			{ shape = Enum.PartType.Cylinder }
		)
		P(
			props,
			"Traverse",
			Vector3.new(7, 0.5, 0.5),
			base * CFrame.new(0, 21.5, 0),
			Enum.Material.Wood,
			C.bark
		)
		local current: { Attachment } = {}
		for i, offset in { -3, 0, 3 } do
			local a = Instance.new("Attachment")
			a.Name = "Fil" .. i
			-- Parenter AVANT de poser la position monde : sans parent,
			-- WorldPosition se lit comme une position locale, et le fil
			-- partait vers le ciel (vu en image).
			a.Parent = pole
			a.WorldPosition = (base * CFrame.new(offset, 21.9, 0)).Position
			table.insert(current, a)
		end
		if previous then
			for i = 1, 3 do
				local wire = Instance.new("Beam")
				wire.Attachment0 = previous[i]
				wire.Attachment1 = current[i]
				wire.Width0 = 0.12
				wire.Width1 = 0.12
				wire.Color = ColorSequence.new(Color3.fromRGB(20, 20, 22))
				wire.LightInfluence = 1
				wire.Segments = 12
				wire.FaceCamera = true
				-- La flèche du fil : un peu plus pour le poteau penche.
				wire.CurveSize0 = -4
				wire.CurveSize1 = 4
				wire.Parent = pole
			end
		end
		previous = current
	end

	-- Sacs poubelle eventres sur les trottoirs.
	for _ = 1, 12 do
		local at = Vector3.new(
			random:NextNumber(-160, 160),
			0.7,
			(if random:NextNumber() < 0.5 then 1 else -1) * random:NextNumber(13, 19)
		)
		if math.abs(at.X) < 20 then
			continue
		end
		for _ = 1, random:NextInteger(2, 4) do
			local size = random:NextNumber(1.6, 2.4)
			P(
				props,
				"Sac",
				Vector3.new(size, size, size),
				CFrame.new(
					at
						+ Vector3.new(
							random:NextNumber(-1.4, 1.4),
							size * 0.35,
							random:NextNumber(-1, 1)
						)
				),
				Enum.Material.Plastic,
				Color3.fromRGB(26, 26, 28),
				-- Sans collision : un sac ne doit jamais bloquer une cachette.
				{ shape = Enum.PartType.Ball, collide = false }
			)
		end
	end

	-- Lampadaires (eteints), voitures abandonnees qu'on peut fouiller.
	for x = -180, 180, 52 do
		lamp(props, Vector3.new(x, 0.7, 18), Vector3.new(0, 0, -1))
		lamp(props, Vector3.new(x + 26, 0.7, -18), Vector3.new(0, 0, 1))
	end
	local wrecks = {
		{ cf = CFrame.new(-138, 0.4, -6) * CFrame.Angles(0, math.rad(78), 0), id = "Epave1" },
		{ cf = CFrame.new(78, 0.4, 6) * CFrame.Angles(0, math.rad(-96), 0), id = "Epave2" },
		{ cf = CFrame.new(-4, 0.4, -98) * CFrame.Angles(0, math.rad(12), 0), id = "Epave3" },
	}
	for _, wreck in wrecks do
		local carModel = car(props, wreck.cf, CAR_COLORS[random:NextInteger(1, #CAR_COLORS)], true)
		carModel.Name = wreck.id
		-- La boite a gants : la part de carrosserie sert de contenant.
		local glove = P(
			containers,
			wreck.id .. "_BoiteAGants",
			Vector3.new(2, 1, 1.4),
			wreck.cf * CFrame.new(1.2, 3.2, -2.4),
			Enum.Material.SmoothPlastic,
			C.black,
			{ transparency = 1, collide = false }
		)
		glove:SetAttribute("Table", "voiture")
	end
	-- Barricades aux bouts des rues : la ville continue, pas nous.
	for _, end_ in
		{
			{ CFrame.new(-168, 0.4, 0), 26 },
			{ CFrame.new(168, 0.4, 0), 26 },
			{ CFrame.new(0, 0.4, -132) * CFrame.Angles(0, math.rad(90), 0), 22 },
			{ CFrame.new(0, 0.4, 132) * CFrame.Angles(0, math.rad(90), 0), 22 },
		}
	do
		local cf, length = end_[1], end_[2]
		for i = -2, 2 do
			P(
				props,
				"Barricade",
				Vector3.new(2.4, 3.2, length / 5 - 0.6),
				cf
					* CFrame.new(random:NextNumber(-1, 1), 1.6, i * length / 5)
					* CFrame.Angles(0, math.rad(random:NextNumber(-12, 12)), 0),
				Enum.Material.Concrete,
				C.concrete
			)
		end
	end
	-- Murs invisibles : on ne sort pas du quartier.
	for _, w in
		{
			{ Vector3.new(4, 40, 300), Vector3.new(-172, 20, 0) },
			{ Vector3.new(4, 40, 300), Vector3.new(172, 20, 0) },
			{ Vector3.new(352, 40, 4), Vector3.new(0, 20, -136) },
			{ Vector3.new(352, 40, 4), Vector3.new(0, 20, 136) },
		}
	do
		P(
			props,
			"Limite",
			w[1],
			CFrame.new(w[2]),
			Enum.Material.SmoothPlastic,
			C.black,
			{ transparency = 1, query = false, shadow = false }
		)
	end
	task.wait()

	-- Les cachettes solides : deux buses de beton couchees au bord des rues.
	for i, at in { CFrame.new(28, 1.6, -28), CFrame.new(-28, 1.6, 30) } do
		local m = model(solid, "Buse" .. i)
		P(
			m,
			"Buse",
			Vector3.new(11, 6.4, 6.4),
			at,
			Enum.Material.Concrete,
			C.concrete,
			{ shape = Enum.PartType.Cylinder }
		)
		for _, sx in { -1, 1 } do
			P(
				m,
				"Ouverture",
				Vector3.new(0.2, 5, 5),
				at * CFrame.new(sx * 5.55, 0, 0),
				Enum.Material.SmoothPlastic,
				C.black,
				{ shape = Enum.PartType.Cylinder, query = false }
			)
		end
		marker(m, CONTRACT.inside, at * CFrame.new(0, 0.4, 0))
		marker(m, CONTRACT.exit, at * CFrame.new(-7.5, 1.4, 0))
	end

	-- Les emplacements des cachettes fragiles : jardins, allees, trottoirs.
	local anchorList = {
		{ "Abri", -128, 96, 0 },
		{ "Abri", -42, 100, 10 },
		{ "Caisses", 58, 90, 0 },
		{ "Abri", 122, 98, -8 },
		{ "Abri", -95, -100, 180 },
		{ "Caisses", -55, -94, 0 },
		{ "Abri", 44, -100, 170 },
		{ "Benne", 120, -90, 90 },
		{ "Voiture", -96.8, 30, 0 },
		{ "Voiture", 133.2, 30, 0 },
		{ "Voiture", -67.4, -30, 180 },
		{ "Voiture", 96.6, -30, 180 },
		{ "Voiture", -72, 7, 90 },
		{ "Voiture", 32, -7, -90 },
		{ "Voiture", 104, 7, 90 },
		{ "Voiture", 6, 72, 0 },
		{ "Voiture", -6, -66, 180 },
		{ "Benne", -40, 16, 90 },
		{ "Benne", 40, -16, 90 },
		{ "Caisses", -152, -32, 0 },
		{ "Caisses", 152, 32, 0 },
		{ "Benne", -60, 75, 90 },
	}
	for i, a in anchorList do
		local part = P(
			anchors,
			string.format("E%02d", i),
			Vector3.new(4, 1, 4),
			CFrame.new(a[2], 0.5, a[3]) * CFrame.Angles(0, math.rad(a[4]), 0),
			Enum.Material.SmoothPlastic,
			Color3.fromRGB(255, 0, 200),
			{ transparency = 1, collide = false, query = false, shadow = false }
		)
		part:SetAttribute("Prefab", a[1])
	end

	local prefabs = folder(ServerStorage, CONTRACT.prefabs)
	buildPrefabs(prefabs)
	task.wait()

	local spawnAt = buildPlanque(root, terrain)
	buildSky(root, Vector3.zero)
	buildLighting()
	task.wait()

	----------------------------------------------------------------------------
	-- LA MESURE : la recette se verifie elle-meme.
	----------------------------------------------------------------------------
	local report: { string } = {}
	local problems = 0
	local eye = Vector3.new(0, EYE_HEIGHT, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = false

	-- Couvert vu de l'Oeil : un rayon de l'Oeil au point doit toucher une
	-- part opaque (meme regle que l'EyeService, en plus simple).
	local function coveredFromEye(target: Vector3, ignore: { Instance }): boolean
		local filter = table.clone(ignore)
		local origin = eye
		for _ = 1, 8 do
			params.FilterDescendantsInstances = filter
			local hit = workspace:Raycast(origin, target - origin, params)
			if hit == nil then
				return false
			end
			if
				hit.Instance:GetAttribute(CONTRACT.cover) == nil
				and hit.Instance.Transparency < 0.5
			then
				return true
			end
			table.insert(filter, hit.Instance)
			origin = hit.Position
		end
		return true
	end

	local planque = root:FindFirstChild(CONTRACT.planque) :: Model
	local spawnCovered =
		coveredFromEye(spawnAt, { planque:FindFirstChild(CONTRACT.spawn) :: Instance })
	table.insert(
		report,
		string.format("Depart de la Planque couvert vu du ciel : %s", tostring(spawnCovered))
	)
	if not spawnCovered then
		problems += 1
	end

	for _, spot in solid:GetChildren() do
		local inside = spot:FindFirstChild(CONTRACT.inside) :: BasePart
		local ok = coveredFromEye(inside.Position, {})
		table.insert(
			report,
			string.format("Cachette solide %s couverte : %s", spot.Name, tostring(ok))
		)
		if not ok then
			problems += 1
		end
	end

	for _, entry in insides do
		local ok = coveredFromEye(entry.at, {})
		table.insert(
			report,
			string.format(
				"%s : salon %s (attendu %s)",
				entry.name,
				if ok then "couvert" else "à découvert",
				if entry.covered then "couvert" else "à découvert"
			)
		)
		if ok ~= entry.covered then
			problems += 1
		end
	end

	-- Chaque emplacement a du sol dessous, et rien de solide dans les 4
	-- studs autour de son centre (sinon la cachette poserait dans un mur).
	local groundParams = RaycastParams.new()
	groundParams.FilterType = Enum.RaycastFilterType.Exclude
	groundParams.FilterDescendantsInstances = { anchors }
	local blocked = 0
	for _, anchor in anchors:GetChildren() do
		local p = (anchor :: BasePart).Position
		local down =
			workspace:Raycast(p + Vector3.new(0, 3, 0), Vector3.new(0, -8, 0), groundParams)
		if down == nil then
			problems += 1
			table.insert(report, "Emplacement sans sol : " .. anchor.Name)
		end
		local overlap = OverlapParams.new()
		overlap.FilterType = Enum.RaycastFilterType.Exclude
		overlap.FilterDescendantsInstances = { anchors, workspace.Terrain, streets }
		local touching = workspace:GetPartBoundsInBox(
			CFrame.new(p + Vector3.new(0, 3, 0)),
			Vector3.new(4, 4, 4),
			overlap
		)
		local solidHits = 0
		for _, hit in touching do
			if hit.CanCollide and hit.Transparency < 1 then
				solidHits += 1
			end
		end
		if solidHits > 0 then
			blocked += 1
			table.insert(
				report,
				string.format(
					"Emplacement %s : %d part(s) solides au centre",
					anchor.Name,
					solidHits
				)
			)
		end
	end

	-- La rue doit etre AU-DESSUS du terrain (vu le 5 novembre 2026 : non).
	local streetHit = workspace:Raycast(Vector3.new(-40, 50, -4), Vector3.new(0, -100, 0))
	local streetOk = streetHit ~= nil and streetHit.Instance.Name == "RuePrincipale"
	table.insert(report, "La rue est visible au-dessus du terrain : " .. tostring(streetOk))
	if not streetOk then
		problems += 1
	end
	table.insert(
		report,
		string.format("%d emplacements, %d bloqués", #anchors:GetChildren(), blocked)
	)
	table.insert(report, string.format("%d contenants à fouiller", #containers:GetChildren()))
	table.insert(report, string.format("%d parts posées", partCount))
	table.insert(
		report,
		string.format(
			"%d arbres générés (modèle %s)",
			generatedTrees,
			if treeTemplate then "trouvé" else "ABSENT, arbres en parts"
		)
	)
	table.insert(report, string.format("%d problème(s)", problems + blocked))
	return table.concat(report, "\n")
end

return build
