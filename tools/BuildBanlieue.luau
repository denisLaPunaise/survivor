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
	- la Planque : une cave derriere une ferme en ruine, seule dans le coin sud-ouest.
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
	workbench = "Etabli",
	table = "Table",
	slotPrefix = "Slot",
	building = "Batiment",
	roof = "Toiture",
	loose = "Aspirable",
	exit = "Sortie",
	cover = "Couvert",
}

-- La hauteur de l'Oeil au-dessus du sol, recopiee de Config.eye.height pour
-- la mesure de couverture.
local EYE_HEIGHT = 600

-- Le ciel, recopie de Config.world.
local SKY = { folder = "Ciel", eye = "Oeil", debris = "Debris", lids = "Paupieres" }

-- Les limites que l'Oeil balaie.
-- 800 x 640 (decide avec Josh : ~800 x 800 ; 640 en profondeur suffit a
-- quatre rangees de maisons et une bande centrale).
-- Toute la zone jouable : la ville (800 x 800) et sa campagne. L'Oeil
-- balaie partout ou l'on peut aller.
local BOUNDS_SIZE = Vector3.new(1400, 1, 1400)

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
-- Les modeles de voitures generees (docs/ASSETS.md), s'ils sont dans la place.
local carTemplates: { Model } = {}
local generatedCars = 0

local function car(parent: Instance, cf: CFrame, color: Color3, wrecked: boolean): (Model, CFrame)
	if #carTemplates > 0 then
		local clone = carTemplates[random:NextInteger(1, #carTemplates)]:Clone()
		clone.Name = "Voiture"
		local size = clone:GetExtentsSize()
		local tilt = if wrecked
			then CFrame.Angles(
				math.rad(random:NextNumber(-2, 2)),
				0,
				math.rad(random:NextNumber(2, 5))
			)
			else CFrame.identity
		clone:PivotTo(cf * tilt * CFrame.new(0, size.Y / 2, 0))
		for _, part in clone:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = true
			end
		end
		clone.Parent = parent
		generatedCars += 1
		return clone, cf * CFrame.new(0, size.Y * 0.5, 0)
	end
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
	-- 2 : une maison a etage. L'etage n'est pas accessible (pas d'escalier) :
	-- c'est la silhouette qui compte, la rue ne doit pas etre une rangee de
	-- bungalows identiques.
	storeys: number,
	-- La variete des interieurs : le plan en miroir (cuisine a gauche, salle
	-- de bain a droite), et une chambre a la place de la salle a manger.
	mirror: boolean,
	bedroom: boolean,
	-- Une maison qui raconte : "barricadee", "brulee", "mot", ou rien.
	story: string?,
}

type HouseResult = {
	inside: Vector3, -- un point du salon, pour la mesure de couverture
	kitchen: CFrame,
	bathroom: CFrame,
	garage: CFrame?,
}

local HOUSE_W, HOUSE_D, WALL_H, FLOOR_Y, THICK = 26, 22, 10, 0.6, 0.8

-- Ce que l'Oeil arrache quand il vient chercher ceux qui s'abritent dans un
-- batiment : les toits, les plafonds, et tout ce qui est au-dessus du
-- rez-de-chaussee. Le serveur les retrouve par l'attribut.
local ROOF_NAMES = {
	Toit = true,
	Plafond = true,
	PlafondRez = true,
	Pignon = true,
	Cheminee = true,
	Gouttiere = true,
	Chevron = true,
}

-- Les mots laisses sur les murs. Pas d'explication : des bribes.
local NOTES = {
	"Ne restez jamais deux fois sous le même toit. Il s'en souvient.",
	"Maman est montée. Elle souriait en montant.",
	"Ils dorment dans les maisons. Ne courez pas.",
	"Le ciel rougit avant. Toujours avant.",
	"On a entendu frapper à la cave toute la nuit. De l'intérieur.",
	"La radio parle encore, parfois. Une voix, vers l'ouest.",
	"Si tu lis ça, prends les conserves. On n'en aura plus besoin.",
}

-- Ce que l'aspiration emporte de l'interieur en meme temps que le toit.
local LOOSE_NAMES = {
	Chaise = true,
	Papier = true,
	Tapis = true,
	Oreiller = true,
	Fauteuil = true,
	Lampadaire = true,
	Tele = true,
	Cadre = false,
	Banc = true,
	Produit = true,
}

local function tagBuilding(m: Model, groundY: number)
	local covered = false
	for _, part in m:GetDescendants() do
		if part:IsA("BasePart") then
			local bottom = part.Position.Y - part.Size.Y / 2
			-- Avec le toit partent aussi les linteaux et tout ce qui est au-dessus
			-- des fenetres : le haut des murs est dechiquete, pas tranche net.
			if ROOF_NAMES[part.Name] or bottom >= groundY + FLOOR_Y + 7 then
				part:SetAttribute(CONTRACT.roof, true)
				covered = true
			elseif LOOSE_NAMES[part.Name] then
				part:SetAttribute(CONTRACT.loose, true)
			end
		end
	end
	-- Une ruine sans toit n'abrite personne : ce n'est pas un batiment pour
	-- l'Oeil.
	if covered then
		m:SetAttribute(CONTRACT.building, true)
	end
end

-- `cf` : le milieu du bas de la facade, l'axe Z local entrant dans la maison.
local function house(
	parent: Instance,
	cf: CFrame,
	o: HouseOptions,
	containers: Instance
): HouseResult
	local m = model(parent, o.name)
	local w, d = HOUSE_W, HOUSE_D
	local tall = o.storeys == 2
	local h = if tall then WALL_H * 1.8 else WALL_H
	local upperB, upperT = WALL_H + 2.2, WALL_H + 6.4
	local floorCf = cf * CFrame.new(0, FLOOR_Y, 0)
	-- Le miroir ne touche que l'interieur : la porte d'entree reste face a son
	-- allee.
	local mx = if o.mirror then -1 else 1
	local function mirror(c: CFrame): CFrame
		if mx == 1 then
			return c
		end
		return CFrame.new(-c.X, c.Y, c.Z) * (c - c.Position)
	end

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

	-- Facade : porte, deux fenetres (et deux a l'etage).
	local frontOpenings: { Opening } = {
		{ x = -2.5, w = 4, b = 0, t = 7.5, kind = "door" },
		{ x = 6.5, w = 5, b = 3, t = 7.2, kind = "window" },
		{ x = -9.5, w = 4, b = 3, t = 7.2, kind = "window" },
	}
	local backOpenings: { Opening } = {
		{ x = 3 * mx, w = 3.6, b = 0, t = 7.5, kind = "door" },
		{ x = -6 * mx, w = 4, b = 3.5, t = 7, kind = "window" },
	}
	-- Le mur se construit par etage : deux rangees d'ouvertures qui se
	-- chevauchent en largeur casseraient le decoupage d'un mur d'un seul tenant.
	wall(
		m,
		floorCf * CFrame.new(0, 0, THICK / 2),
		w,
		WALL_H,
		THICK,
		frontOpenings,
		o.material,
		o.siding
	)
	wall(
		m,
		floorCf * CFrame.new(0, 0, d - THICK / 2),
		w,
		WALL_H,
		THICK,
		backOpenings,
		o.material,
		o.siding
	)
	if tall then
		local up = h - WALL_H
		local b, t = upperB - WALL_H, upperT - WALL_H
		wall(m, floorCf * CFrame.new(0, WALL_H, THICK / 2), w, up, THICK, {
			{ x = -7, w = 4, b = b, t = t, kind = "window" },
			{ x = 6, w = 4, b = b, t = t, kind = "window" },
		}, o.material, o.siding)
		wall(m, floorCf * CFrame.new(0, WALL_H, d - THICK / 2), w, up, THICK, {
			{ x = 0, w = 4, b = b, t = t, kind = "window" },
		}, o.material, o.siding)
		for _, side in { -1, 1 } do
			wall(
				m,
				floorCf
					* CFrame.new(side * (w / 2 - THICK / 2), WALL_H, d / 2)
					* CFrame.Angles(0, math.rad(90), 0),
				d - THICK * 2,
				up,
				THICK,
				{ { x = 0, w = 4, b = b, t = t, kind = "window" } },
				o.material,
				o.siding
			)
		end
	end
	-- Cotes.
	for _, side in { -1, 1 } do
		wall(
			m,
			floorCf
				* CFrame.new(side * (w / 2 - THICK / 2), 0, d / 2)
				* CFrame.Angles(0, math.rad(90), 0),
			d - THICK * 2,
			WALL_H,
			THICK,
			{ { x = 0, w = 4, b = 3, t = 7, kind = "window" } },
			o.material,
			o.siding
		)
	end
	-- Cloison : la salle de bain au fond a gauche.
	wall(m, floorCf * CFrame.new((-w / 4 - 0.5) * mx, 0, d - 8), w / 2 - 1, WALL_H, 0.5, {
		{ x = 2 * mx, w = 3.4, b = 0, t = 7.4, kind = "door" },
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
		floorCf * CFrame.new(5 * mx, 1.2, 9),
		Enum.Material.Fabric,
		C.fabric
	)
	if o.bedroom then
		-- Une chambre : un lit defait et une armoire a fouiller.
		P(
			m,
			"Lit",
			Vector3.new(4.4, 1.6, 7),
			floorCf * mirror(CFrame.new(-8, 0.8, 6)),
			Enum.Material.Fabric,
			C.fabric:Lerp(C.trim, 0.3)
		)
		P(
			m,
			"Oreiller",
			Vector3.new(3, 0.5, 1.2),
			floorCf * mirror(CFrame.new(-8, 1.85, 3.2)),
			Enum.Material.Fabric,
			C.trim
		)
		local wardrobe = P(
			containers,
			o.name .. "_Armoire",
			Vector3.new(1.6, 6, 4),
			floorCf * mirror(CFrame.new(-w / 2 + 1.6, 3, 10)),
			Enum.Material.WoodPlanks,
			C.wood
		)
		wardrobe:SetAttribute("Table", "chambre")
	else
		P(
			m,
			"Table",
			Vector3.new(4, 2.6, 2.6),
			floorCf * CFrame.new(-6 * mx, 1.3, 6),
			Enum.Material.WoodPlanks,
			C.wood
		)
		P(
			m,
			"Chaise",
			Vector3.new(1.6, 2.8, 1.6),
			floorCf * CFrame.new(-3.5 * mx, 0.8, 8) * CFrame.Angles(math.rad(85), math.rad(30), 0),
			Enum.Material.WoodPlanks,
			C.wood
		)
	end

	-- Les contenants a fouiller (le serveur y pose les invites).
	local kitchenCf = floorCf * CFrame.new((w / 2 - 3.2) * mx, 1.5, d - 1.6)
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
		floorCf * CFrame.new((w / 2 - 4) * mx, 3.1, d - 1.7),
		Enum.Material.Granite,
		C.concrete
	)
	local bathCf = floorCf * CFrame.new((-w / 2 + 2.6) * mx, 4, d - 1.1)
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
		floorCf * CFrame.new((-w / 2 + 3) * mx, 1, d - 4.6),
		Enum.Material.SmoothPlastic,
		C.plaster
	)

	-- L'interieur : la cuisine, le salon, la salle de bain. Un decor qu'on a
	-- quitte en courant.
	local furniture = {
		{
			"Frigo",
			Vector3.new(2.6, 6.6, 2.4),
			CFrame.new(w / 2 - 1.8, 3.3, d - 6.2),
			Enum.Material.SmoothPlastic,
			C.trim,
		},
		{
			"Cuisiniere",
			Vector3.new(2.6, 3, 2.2),
			CFrame.new(w / 2 - 6.6, 1.5, d - 1.6),
			Enum.Material.Metal,
			C.metal,
		},
		{
			"Meuble",
			Vector3.new(6, 2.2, 1.6),
			CFrame.new(5, 1.1, 1.6),
			Enum.Material.WoodPlanks,
			C.wood,
		},
		{
			"Tele",
			Vector3.new(3.6, 2.2, 0.5),
			CFrame.new(5, 3.3, 1.6),
			Enum.Material.SmoothPlastic,
			C.black,
		},
		{
			"Tapis",
			Vector3.new(8, 0.1, 6),
			CFrame.new(4, 0.25, 6),
			Enum.Material.Fabric,
			Color3.fromRGB(102, 66, 58),
		},
		{
			"Fauteuil",
			Vector3.new(3, 2.6, 3),
			CFrame.new(9.5, 1.3, 6) * CFrame.Angles(0, math.rad(-70), 0),
			Enum.Material.Fabric,
			C.fabric:Lerp(C.sidingSage, 0.4),
		},
		{
			"Lavabo",
			Vector3.new(2.4, 3, 1.6),
			CFrame.new(-w / 2 + 6.5, 1.5, d - 1.3),
			Enum.Material.SmoothPlastic,
			C.plaster,
		},
		{
			"Toilettes",
			Vector3.new(1.6, 2.2, 2.4),
			CFrame.new(-4.4, 1.1, d - 1.6),
			Enum.Material.SmoothPlastic,
			C.plaster,
		},
		{
			"Cadre",
			Vector3.new(2.6, 2, 0.2),
			CFrame.new(-9, 6, d - 8.4),
			Enum.Material.WoodPlanks,
			C.wood,
		},
		{
			"Lampadaire",
			Vector3.new(0.4, 5.6, 0.4),
			CFrame.new(-11.5, 2.8, 2),
			Enum.Material.Metal,
			C.metal,
		},
	}
	for _, f in furniture do
		P(m, f[1], f[2], floorCf * mirror(f[3]), f[4], f[5])
	end
	-- Des papiers et des objets tombes par terre.
	for _ = 1, 6 do
		P(
			m,
			"Papier",
			Vector3.new(random:NextNumber(0.6, 1.4), 0.05, random:NextNumber(0.8, 1.6)),
			floorCf
				* CFrame.new(random:NextNumber(-10, 10), 0.24, random:NextNumber(2, d - 9))
				* CFrame.Angles(0, random:NextNumber(0, 6), 0),
			Enum.Material.SmoothPlastic,
			Color3.fromRGB(214, 208, 192),
			{ collide = false, query = false }
		)
	end
	if tall then
		-- Le plancher de l'etage : il couvre le rez-de-chaussee du ciel, et
		-- la seule facon de le savoir est de lever les yeux.
		P(
			m,
			"PlafondRez",
			Vector3.new(w - 1, 0.6, d - 1),
			floorCf * CFrame.new(0, WALL_H + 0.3, d / 2),
			Enum.Material.SmoothPlastic,
			C.plaster
		)
	end

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

	-- LES MAISONS QUI RACONTENT.
	if o.story == "barricadee" then
		-- Ceux d'ici se sont enfermes : planches sur la porte, meuble contre la
		-- porte du jardin. On entre par une fenetre.
		for i = -1, 1 do
			P(
				m,
				"Planche",
				Vector3.new(5, 0.8, 0.3),
				floorCf
					* CFrame.new(-2.5, 3.6 + i * 2, -0.25)
					* CFrame.Angles(0, 0, math.rad(i * 9)),
				Enum.Material.WoodPlanks,
				C.woodGray
			)
		end
		P(
			m,
			"Buffet",
			Vector3.new(5, 5, 1.8),
			floorCf * mirror(CFrame.new(3, 2.5, d - 2)),
			Enum.Material.WoodPlanks,
			C.wood
		)
	elseif o.story == "brulee" then
		-- Un feu, il y a longtemps : tout est noirci, et ca sent encore.
		for _, part in m:GetDescendants() do
			if part:IsA("BasePart") then
				part.Color = part.Color:Lerp(Color3.fromRGB(26, 24, 22), 0.75)
			end
		end
	elseif o.story == "mot" then
		local note = P(
			m,
			"Mot",
			Vector3.new(3.4, 2.4, 0.05),
			floorCf * mirror(CFrame.new(-7, 5.4, d - 8.3)),
			Enum.Material.SmoothPlastic,
			Color3.fromRGB(214, 206, 186),
			{ collide = false }
		)
		local surface = Instance.new("SurfaceGui")
		surface.Face = Enum.NormalId.Front
		surface.PixelsPerStud = 60
		surface.LightInfluence = 1
		surface.Parent = note
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.TextWrapped = true
		text.TextScaled = true
		text.Font = Enum.Font.IndieFlower
		text.TextColor3 = Color3.fromRGB(40, 32, 28)
		text.Text = NOTES[random:NextInteger(1, #NOTES)]
		text.Parent = surface
	end

	tagBuilding(m, cf.Position.Y)
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
	-- Les voitures : on se cache dans l'habitacle. Une variante par modele
	-- genere, pour que les rues ne soient pas pleines de la meme voiture.
	local all = carTemplates
	for variant = 1, math.max(#all, 1) do
		local name = if variant == 1 then "Voiture" else "Voiture" .. variant
		local m = prefabRoot(storage, name, Vector3.new(7, 1, 15))
		if #all > 0 then
			carTemplates = { all[variant] }
		end
		local color = CAR_COLORS[random:NextInteger(1, #CAR_COLORS)]
		local _, cabin = car(m, CFrame.new(0, 0, 0), color, false)
		-- Le modele de voiture est un sous-modele : on remonte ses parts.
		local sub = m:FindFirstChild("Voiture")
		if sub and sub ~= m then
			for _, child in sub:GetChildren() do
				child.Parent = m
			end
			sub:Destroy()
		end
		marker(m, CONTRACT.inside, cabin)
		-- Une portiere de chaque cote : on y entre (et on en ressort) par le
		-- cote ou l'on est (Josh : « que d'un cote, c'est un peu chiant »).
		marker(m, CONTRACT.exit, CFrame.new(5.2, 3, 0))
		marker(m, CONTRACT.exit, CFrame.new(-5.2, 3, 0))
	end
	carTemplates = all
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
	-- Les petites cachettes de partout (Josh : « pas de petits recoins ») :
	-- un buisson touffu ou l'on se glisse, une tole appuyee contre un mur.
	do
		local m, g = prefabRoot(storage, "Buisson", Vector3.new(7, 1, 7))
		local leaf = Color3.fromRGB(56, 76, 42)
		-- Un Ball est une sphere du plus petit cote : tailles cubiques.
		local function ball(at: Vector3, size: number)
			P(
				m,
				"Feuillage",
				Vector3.new(size, size, size),
				g * CFrame.new(at),
				Enum.Material.LeafyGrass,
				leaf:Lerp(Color3.fromRGB(78, 96, 52), random:NextNumber(0, 1)),
				{ shape = Enum.PartType.Ball, collide = false, cover = 0.4 }
			)
		end
		for k = 0, 5 do
			local a = k * math.pi / 3 + random:NextNumber(-0.2, 0.2)
			ball(
				Vector3.new(math.cos(a) * 2.4, 1.9, math.sin(a) * 2.4),
				random:NextNumber(3.8, 4.6)
			)
		end
		for k = 0, 3 do
			local a = k * math.pi / 2 + 0.6
			ball(Vector3.new(math.cos(a) * 1.3, 3.9, math.sin(a) * 1.3), random:NextNumber(3.4, 4))
		end
		ball(Vector3.new(0, 5.1, 0), 3.2)
		marker(m, CONTRACT.inside, CFrame.new(0, 2.2, 0))
		marker(m, CONTRACT.exit, CFrame.new(0, 3, -5))
	end
	do
		local m, g = prefabRoot(storage, "Tole", Vector3.new(8, 1, 6))
		-- Un panneau de planches derriere : la tole tient seule, contre un mur
		-- ou au milieu d'un champ.
		P(
			m,
			"Panneau",
			Vector3.new(7.6, 5.8, 0.4),
			g * CFrame.new(0, 2.9, 2.2),
			Enum.Material.WoodPlanks,
			C.woodGray
		)
		-- La tole : du sol (z = -2,6) au haut du panneau (z = 1,9, y = 5,6).
		-- Angle negatif autour de X : l'axe Z local monte vers +Z.
		local rise, run = 5.6, 4.5
		P(
			m,
			"Tole",
			Vector3.new(7.2, 0.2, math.sqrt(rise * rise + run * run)),
			g
				* CFrame.new(0, rise / 2, -2.6 + run / 2)
				* CFrame.Angles(-math.atan2(rise, run), 0, 0),
			Enum.Material.CorrodedMetal,
			C.metal
		)
		P(
			m,
			"Planche",
			Vector3.new(0.6, 0.3, 6),
			g * CFrame.new(3.2, 0.15, -0.6) * CFrame.Angles(0, math.rad(8), 0),
			Enum.Material.WoodPlanks,
			C.wood
		)
		marker(m, CONTRACT.inside, CFrame.new(0, 2.2, 0.6))
		marker(m, CONTRACT.exit, CFrame.new(0, 3, -5))
	end
end

--------------------------------------------------------------------------------
-- La Planque : une cave sous le jardin
--------------------------------------------------------------------------------

local function buildPlanque(root: Instance, terrain: Terrain, x0: number, z0: number): Vector3
	local m = model(root, CONTRACT.planque)
	-- Origine : le haut de l'escalier, dans le jardin de la maison du
	-- sud-ouest (sa facade regarde le nord, son jardin est au sud).
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

	-- La table : on y mange sur la reserve.
	P(
		m,
		CONTRACT.table,
		Vector3.new(4, 2.6, 3),
		CFrame.new(cx - 1, floorY + 1.3, cz - 1.5),
		Enum.Material.WoodPlanks,
		C.wood:Lerp(C.trim, 0.2)
	)
	-- L'etabli : on y construit avec la reserve (Config.planque.builds).
	local bench = P(
		m,
		CONTRACT.workbench,
		Vector3.new(6, 3, 2.4),
		CFrame.new(cx + 2, floorY + 1.5, cz + 6.6),
		Enum.Material.WoodPlanks,
		C.wood
	)
	P(
		m,
		"Outils",
		Vector3.new(1.6, 0.4, 0.6),
		bench.CFrame * CFrame.new(-1.6, 1.7, 0),
		Enum.Material.Metal,
		C.metal
	)
	-- Les emplacements des constructions : invisibles tant que rien n'y est bati.
	local function slot(id: string, size: Vector3, cf: CFrame)
		P(m, CONTRACT.slotPrefix .. id, size, cf, Enum.Material.SmoothPlastic, C.black, {
			transparency = 1,
			collide = false,
			query = false,
			shadow = false,
		})
	end
	-- La barricade bouche le passage entre l'escalier et la piece.
	slot("barricade", Vector3.new(6, 7.4, 1), CFrame.new(cx, floorY + 3.7, roomZ0 - 0.6))
	slot("lit", Vector3.new(3, 1.2, 7), CFrame.new(cx + 4.5, floorY + 0.6, cz + 3.5))
	slot("rechaud", Vector3.new(2, 1.6, 2), CFrame.new(cx - 3, floorY + 0.8, cz - 6))
	slot("periscope", Vector3.new(1, 1, 1), CFrame.new(cx + 8.5, floorY, cz - 6.5))
	slot("radio", Vector3.new(2, 1.4, 1), CFrame.new(cx + 0.5, floorY + 3.7, cz + 6.6))
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
	-- Des veines sur le devant du globe, qui se ramifient en allant vers le
	-- bord : sombres pour la plupart, quelques-unes brulantes. Toutes en neon,
	-- le globe paraissait un jouet propre (vu en image le 5 novembre 2026).
	local function onGlobe(a: number, r: number): Vector3
		local z = -math.sqrt(math.max(radius * radius - r * r, 0)) - 0.4
		return (look * CFrame.new(math.cos(a) * r, math.sin(a) * r, z)).Position
	end
	local function vein(a0: number, r0: number, a1: number, r1: number, width: number)
		local hot = random:NextNumber() < 0.25
		local v = slab(
			eye,
			onGlobe(a0, r0),
			onGlobe(a1, r1),
			width,
			0.6,
			if hot then Enum.Material.Neon else Enum.Material.SmoothPlastic,
			if hot then Color3.fromRGB(150, 30, 26) else Color3.fromRGB(112, 30, 26),
			"Veine"
		)
		v.CanCollide = false
		v.CanQuery = false
		v.CastShadow = false
	end
	for i = 1, 34 do
		local a = (i / 34) * math.pi * 2 + random:NextNumber(-0.08, 0.08)
		local r0 = random:NextNumber(60, 66)
		local mid = random:NextNumber(82, 92)
		local bend = a + random:NextNumber(-0.08, 0.08)
		vein(a, r0, bend, mid, random:NextNumber(1, 2.2))
		-- Deux branches plus fines vers le bord.
		for _, side in { -1, 1 } do
			if random:NextNumber() < 0.7 then
				vein(
					bend,
					mid,
					bend + side * random:NextNumber(0.04, 0.12),
					random:NextNumber(100, 114),
					random:NextNumber(0.5, 1.1)
				)
			end
		end
	end
	-- Un reflet humide, fixe sur le globe : il lui donne du volume.
	do
		local a, r = math.rad(135), 78
		local at = onGlobe(a, r)
		local normal = (at - look.Position).Unit
		P(
			eye,
			"Reflet",
			Vector3.new(0.4, 16, 16),
			CFrame.lookAt(at + normal * 0.6, at + normal * 2) * CFrame.Angles(0, math.rad(90), 0),
			Enum.Material.Neon,
			Color3.fromRGB(255, 246, 232),
			{
				shape = Enum.PartType.Cylinder,
				collide = false,
				query = false,
				shadow = false,
				transparency = 0.35,
			}
		)
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
	-- Un anneau chaud qui rougeoie, puis le coeur sombre autour de la pupille.
	P(
		eye,
		"IrisChaud",
		Vector3.new(14, 98, 98),
		face * CFrame.new(front + 0.6, 0, 0),
		Enum.Material.Neon,
		Color3.fromRGB(176, 62, 22),
		{
			shape = Enum.PartType.Cylinder,
			collide = false,
			query = false,
			shadow = false,
			transparency = 0.25,
		}
	)
	P(
		eye,
		"AnneauIris",
		Vector3.new(14, 74, 74),
		face * CFrame.new(front + 1.2, 0, 0),
		Enum.Material.SmoothPlastic,
		Color3.fromRGB(58, 16, 8),
		{
			shape = Enum.PartType.Cylinder,
			collide = false,
			query = false,
			shadow = false,
		}
	)
	-- Les fibres de l'iris, du coeur vers l'anneau chaud.
	local irisFace = front + 8.4
	for i = 1, 48 do
		local a = (i / 48) * math.pi * 2 + random:NextNumber(-0.04, 0.04)
		local r0 = random:NextNumber(16, 22)
		local r1 = random:NextNumber(40, 50)
		local fiber = slab(
			eye,
			(look * CFrame.new(math.cos(a) * r0, math.sin(a) * r0, -irisFace)).Position,
			(look * CFrame.new(math.cos(a) * r1, math.sin(a) * r1, -irisFace)).Position,
			random:NextNumber(0.8, 1.8),
			0.4,
			Enum.Material.Neon,
			Color3.fromRGB(220, 110, 44)
				:Lerp(Color3.fromRGB(120, 30, 14), random:NextNumber(0, 0.7)),
			"Fibre"
		)
		fiber.CanCollide = false
		fiber.CanQuery = false
		fiber.CastShadow = false
		fiber.Transparency = random:NextNumber(0.2, 0.55)
	end
	-- La pupille fendue, DEVANT les fibres (avant, elle etait derriere les
	-- anneaux et l'on ne voyait qu'un disque noir). Une amande faite de
	-- tranches : une seule barre droite barrait l'iris comme un panneau
	-- d'interdiction (vu en image). Leur largeur est sur X : la vue du ciel
	-- les resserre quand il cherche.
	for _, cut in { { 0, 16, 34 }, { 22, 11, 12 }, { 32, 6, 9 }, { 39, 2.5, 6 } } do
		for _, sign in (if cut[1] == 0 then { 1 } else { -1, 1 }) do
			P(
				eye,
				"Pupille",
				Vector3.new(cut[2], cut[3], 4),
				look * CFrame.new(0, sign * cut[1], -(front + 9.5)),
				Enum.Material.SmoothPlastic,
				Color3.fromRGB(4, 2, 2),
				noRay
			)
		end
	end

	-- LES PAUPIERES : la Fissure se referme sur l'Oeil entre deux Balayages et
	-- la nuit (Josh : « qu'il se ferme quand il est pas actif »). Deux rideaux
	-- noirs aux bords brulants, faits de bandes que la vue du ciel allonge ;
	-- fermees, il ne reste qu'une couture rougeoyante. Elles passent SOUS le
	-- globe (qui deborde de la dechirure), et depassent largement le trou pour
	-- le cacher aussi vu de biais. Construites fermees.
	do
		local lids = folder(m, SKY.lids)
		local lidY = eyeAt.Y - radius - 6
		local strips = 32
		local span = (halfLong + 30) * 2
		local stripW = span / strips
		for i = 1, strips do
			local x = -span / 2 + (i - 0.5) * stripW
			-- La demi-largeur du trou a cet endroit : le plus grand ecart des
			-- points du bord dont l'abscisse tombe dans la bande.
			local h = 0
			for k = 0, 719 do
				local a = k / 720 * math.pi * 2
				local p = almond(a, 0)
				if math.abs(p.X - x) <= stripW / 2 + 4 then
					h = math.max(h, math.abs(p.Z))
				end
			end
			h += 45
			for _, side in { -1, 1 } do
				local lid = P(
					lids,
					"Paupiere",
					Vector3.new(stripW + 1, 2, h),
					CFrame.new(x, lidY, side * h / 2),
					Enum.Material.SmoothPlastic,
					-- Une chair sombre, pas le noir de la dechirure : fermee,
					-- on doit voir l'amande d'une paupiere (en noir, ce n'etait
					-- qu'une tache, vu en jeu).
					Color3.fromRGB(46, 18, 16),
					noRay
				)
				lid:SetAttribute("X", x)
				lid:SetAttribute("Demi", h)
				lid:SetAttribute("Cote", side)
				local edge = P(
					lids,
					"Bord",
					Vector3.new(stripW + 1, 2.4, 6),
					CFrame.new(x, lidY - 1.8, 0),
					Enum.Material.Neon,
					C.rift,
					noRay
				)
				edge:SetAttribute("X", x)
				edge:SetAttribute("Demi", h)
				edge:SetAttribute("Cote", side)
			end
		end
	end

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
	-- Assez dense pour noyer le lointain, pas au point de cacher la rue d'en
	-- face.
	atmosphere.Density = 0.42
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

--------------------------------------------------------------------------------
-- Le plan du quartier
--------------------------------------------------------------------------------

-- Deux rues est-ouest bordees de maisons des deux cotes, trois rues nord-sud
-- qui les relient, et entre les deux rangees du milieu une bande centrale
-- (superette, terrain de basket, terrains vagues).
-- Pas tout a fait au cordeau : des rues decalees, pour qu'aucune moitie de la
-- ville ne soit le miroir de l'autre (« trop symetrique », Josh).
local EW_ROADS = { -176, 162 }
local NS_ROADS = { -258, 6, 244 }
local HALF_X, HALF_Z = 400, 400
-- Le chemin de terre du bord, et les deux batiments du centre.
local OUTER_ROAD = 372
-- La campagne autour de la ville, jusqu'a FIELD (la zone jouable fait
-- 2 x FIELD de cote), et les collines jusqu'a HORIZON.
local FIELD = 700
local HORIZON = 1050
-- La largeur des chemins de terre de la campagne.
local TRACK_W = 9
-- La Planque : une ferme isolee au fond du coin sud-ouest, a l'ecart de la
-- ville (decide avec Josh). Sa facade regarde le nord, la cave est derriere.
local PLANQUE_AT = Vector3.new(-590, 0, -560)
local SUPERETTE_X = -125
local BASKET_X = 125
-- Les reperes : on doit savoir ou l'on est sans carte.
local CHURCH_X = -201
local STATION_X = -301
local TOWER = Vector3.new(200, 0, 392)
-- Les morceaux de rue entre deux carrefours, ou l'on pose les parcelles :
-- deduits des rues nord-sud (18 studs de rue et de trottoir de chaque cote).
local function segmentsBetween(from: number, to: number): { { number } }
	local out: { { number } } = {}
	local cursor = from
	for _, xr in NS_ROADS do
		table.insert(out, { cursor, xr - 18 })
		cursor = xr + 18
	end
	table.insert(out, { cursor, to })
	return out
end
local SEGMENTS = segmentsBetween(-400, 400)
local SIDEWALK_SEGMENTS = segmentsBetween(-420, 420)
-- Le centre : les memes morceaux, moins la superette (et son parking) et le
-- terrain de basket.
local MIDDLE_SEGMENTS: { { number } } = {}
for _, seg in SEGMENTS do
	local pieces = { { seg[1], seg[2] } }
	for _, taken in { { SUPERETTE_X - 40, SUPERETTE_X + 36 }, { BASKET_X - 31, BASKET_X + 31 } } do
		local next: { { number } } = {}
		for _, piece in pieces do
			if taken[2] <= piece[1] or taken[1] >= piece[2] then
				table.insert(next, piece)
			else
				table.insert(next, { piece[1], taken[1] })
				table.insert(next, { taken[2], piece[2] })
			end
		end
		pieces = next
	end
	for _, piece in pieces do
		if piece[2] - piece[1] >= 40 then
			table.insert(MIDDLE_SEGMENTS, piece)
		end
	end
end
local PLOT_W = 66

local function nearCrossing(x: number, margin: number): boolean
	for _, xr in NS_ROADS do
		if math.abs(x - xr) < margin then
			return true
		end
	end
	return false
end

local function build(): string
	partCount = 0
	generatedTrees = 0
	local library = ServerStorage:FindFirstChild("SurvivorModeles")
	local template = library and library:FindFirstChild("Arbre")
	treeTemplate = if template and template:IsA("Model") then template else nil
	generatedCars = 0
	carTemplates = {}
	for _, name in { "Voiture1", "Voiture2" } do
		local carModel = library and library:FindFirstChild(name)
		if carModel and carModel:IsA("Model") then
			table.insert(carTemplates, carModel)
		end
	end

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
	terrain.GrassLength = 0.45
	terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(92, 100, 70))
	terrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(84, 92, 62))
	terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(92, 82, 70))
	-- Le terrain arrondit sa surface sur une grille de 4 studs : rempli
	-- jusqu'a y = 0, sa surface se retrouvait a y = 2, PAR-DESSUS les rues
	-- (mesure au rayon). Rempli jusqu'a -2, elle tombe a 0.
	terrain:FillBlock(
		CFrame.new(0, -9, 0),
		Vector3.new(HALF_X * 2 + 1400, 14, HALF_Z * 2 + 1400),
		Enum.Material.Grass
	)
	-- L'herbe decorative traverse les parts minces posees dessus : sous les
	-- rues et les trottoirs, le terrain est d'une matiere sans herbe.
	for _, zr in EW_ROADS do
		terrain:FillBlock(
			CFrame.new(0, -4, zr),
			Vector3.new(HALF_X * 2 + 30, 4, 44),
			Enum.Material.Pavement
		)
	end
	for _, xr in NS_ROADS do
		terrain:FillBlock(
			CFrame.new(xr, -4, 0),
			Vector3.new(40, 4, OUTER_ROAD * 2),
			Enum.Material.Pavement
		)
	end
	-- Des plaques de terre nue, la ou rien ne pousse plus.
	for _ = 1, 70 do
		local at = Vector3.new(
			random:NextNumber(-HALF_X, HALF_X),
			-2.8,
			random:NextNumber(-HALF_Z, HALF_Z)
		)
		terrain:FillCylinder(CFrame.new(at), 1.6, random:NextNumber(4, 12), Enum.Material.Ground)
	end
	task.wait()

	local root = folder(workspace, CONTRACT.folder)
	P(
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
	local solid = folder(root, CONTRACT.solidSpots)
	local anchors = folder(root, CONTRACT.anchors)
	local containers = folder(root, CONTRACT.containers)
	local streets = folder(root, "Rues")
	local houses = folder(root, "Maisons")
	local nature = folder(root, "Nature")
	local props = folder(root, "Decor")

	local anchorCount = 0
	local function anchor(prefab: string, cf: CFrame)
		anchorCount += 1
		-- Une voiture : l'une des variantes, au hasard.
		if prefab == "Voiture" and #carTemplates > 1 then
			local variant = random:NextInteger(1, #carTemplates)
			prefab = if variant == 1 then "Voiture" else "Voiture" .. variant
		end
		local part = P(
			anchors,
			string.format("E%03d", anchorCount),
			Vector3.new(4, 1, 4),
			CFrame.new(cf.Position.X, 0.5, cf.Position.Z) * (cf - cf.Position),
			Enum.Material.SmoothPlastic,
			Color3.fromRGB(255, 0, 200),
			{ transparency = 1, collide = false, query = false, shadow = false }
		)
		part:SetAttribute("Prefab", prefab)
	end

	-- LES RUES. Rien ne se chevauche a la meme hauteur (scintillement) : la
	-- rue est-ouest passe, les rues nord-sud s'arretent a ses bords.
	for _, zr in EW_ROADS do
		P(
			streets,
			"RueEstOuest",
			Vector3.new(HALF_X * 2 + 40, 0.4, 24),
			CFrame.new(0, 0.2, zr),
			Enum.Material.Asphalt,
			C.asphalt
		)
		for _, sz in { -1, 1 } do
			for _, seg in SIDEWALK_SEGMENTS do
				local len = seg[2] - seg[1]
				local cx = (seg[1] + seg[2]) / 2
				P(
					streets,
					"Trottoir",
					Vector3.new(len, 0.7, 8),
					CFrame.new(cx, 0.35, zr + sz * 16),
					Enum.Material.Concrete,
					C.concrete
				)
				P(
					streets,
					"Bordure",
					Vector3.new(len, 0.8, 0.6),
					CFrame.new(cx, 0.4, zr + sz * 12.3),
					Enum.Material.Concrete,
					C.curb
				)
			end
		end
		-- Le marquage, efface par endroits.
		for x = -HALF_X, HALF_X, 14 do
			if not nearCrossing(x, 16) and random:NextNumber() > 0.25 then
				P(
					streets,
					"Marquage",
					Vector3.new(6, 0.05, 0.5),
					CFrame.new(x, 0.42, zr),
					Enum.Material.SmoothPlastic,
					C.line,
					{ query = false }
				)
			end
		end
	end
	for _, xr in NS_ROADS do
		for _, seg in { { -OUTER_ROAD + 7, -182 }, { -158, 158 }, { 182, OUTER_ROAD - 7 } } do
			local len = seg[2] - seg[1]
			local cz = (seg[1] + seg[2]) / 2
			P(
				streets,
				"RueNordSud",
				Vector3.new(20, 0.4, len),
				CFrame.new(xr, 0.2, cz),
				Enum.Material.Asphalt,
				C.asphalt
			)
		end
		for _, sx in { -1, 1 } do
			for _, seg in
				{ { -OUTER_ROAD + 7, -190 }, { -150, -4 }, { 4, 150 }, { 190, OUTER_ROAD - 7 } }
			do
				local len = seg[2] - seg[1]
				local cz = (seg[1] + seg[2]) / 2
				P(
					streets,
					"Trottoir",
					Vector3.new(8, 0.7, len),
					CFrame.new(xr + sx * 14, 0.35, cz),
					Enum.Material.Concrete,
					C.concrete
				)
				P(
					streets,
					"Bordure",
					Vector3.new(0.6, 0.8, len),
					CFrame.new(xr + sx * 10.3, 0.4, cz),
					Enum.Material.Concrete,
					C.curb
				)
			end
		end
	end
	-- Rapiecages.
	for _ = 1, 60 do
		local onEW = random:NextNumber() < 0.6
		local at = if onEW
			then Vector3.new(
				random:NextNumber(-HALF_X, HALF_X),
				0.41,
				EW_ROADS[random:NextInteger(1, 2)] + random:NextNumber(-10, 10)
			)
			else Vector3.new(
				NS_ROADS[random:NextInteger(1, 3)] + random:NextNumber(-8, 8),
				0.41,
				random:NextNumber(-HALF_Z, HALF_Z)
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

	-- LES PARCELLES. Une rangee = des maisons qui regardent la meme voie :
	-- une rue, le chemin de terre du bord ou l'allee du centre.
	-- `front` : distance de l'axe de la voie a la facade ; `edge` : demi-largeur
	-- de la voie et de son trottoir ; `back` : distance au fond du jardin.
	-- Vu le 5 novembre 2026 : sans les rangees du centre et du bord, le
	-- quartier etait 39 maisons perdues dans les pelouses.
	type Row = {
		zr: number,
		side: number,
		front: number,
		edge: number,
		back: number,
		segments: { { number } },
		width: number,
	}
	local rows: { Row } = {}
	for _, zr in EW_ROADS do
		for _, side in { -1, 1 } do
			table.insert(rows, {
				zr = zr,
				side = side,
				front = 40,
				edge = 20,
				back = 115,
				segments = SEGMENTS,
				width = PLOT_W,
			})
		end
	end
	-- Le fond des jardins de la rangee de la rue `zr`, du cote `side`.
	local function backOf(zr: number, side: number): number
		return zr + side * 115
	end
	-- Le bord : maisons tournees vers le chemin de terre, dos aux jardins de la
	-- rangee exterieure.
	for _, zr in { -OUTER_ROAD, OUTER_ROAD } do
		-- Le jardin s'arrete 1 stud avant la palissade de la rangee voisine :
		-- deux palissades sur la meme ligne scintillent.
		local neighbour = if zr > 0 then backOf(EW_ROADS[2], 1) else backOf(EW_ROADS[1], -1)
		table.insert(rows, {
			zr = zr,
			side = if zr > 0 then -1 else 1,
			front = 26,
			edge = 7,
			back = math.abs(zr - neighbour) - 1,
			segments = SEGMENTS,
			width = 60,
		})
	end
	-- Le centre : deux rangees qui se font face de part et d'autre d'une allee
	-- pietonne, autour de la superette et du terrain de basket.
	for _, side in { -1, 1 } do
		local neighbour = if side == 1 then backOf(EW_ROADS[2], -1) else backOf(EW_ROADS[1], 1)
		table.insert(rows, {
			zr = 0,
			side = side,
			front = 12,
			edge = 4,
			back = math.abs(neighbour) - 2,
			segments = MIDDLE_SEGMENTS,
			width = 60,
		})
	end

	-- Des parcelles de largeurs inegales : d'une rangee a l'autre, les maisons
	-- ne tombent jamais les unes en face des autres.
	type Plot = { x: number, width: number, row: Row }
	local plots: { Plot } = {}
	for _, row in rows do
		for _, seg in row.segments do
			local length = seg[2] - seg[1]
			local n = math.max(1, math.floor(length / row.width))
			local weights: { number } = {}
			local total = 0
			for i = 1, n do
				weights[i] = random:NextNumber(0.8, 1.2)
				total += weights[i]
			end
			local cursor = seg[1]
			for i = 1, n do
				local width = length * weights[i] / total
				table.insert(plots, { x = cursor + width / 2, width = width, row = row })
				cursor += width
			end
		end
	end
	-- Le terrain vide (la maison aspiree) : une rangee du milieu, pres du centre.
	local aspiredIndex = 0
	local best = math.huge
	for i, plot in plots do
		if plot.row.zr == EW_ROADS[2] and plot.row.side == -1 and math.abs(plot.x - 60) < best then
			best = math.abs(plot.x - 60)
			aspiredIndex = i
		end
	end

	-- Ce qui rend un jardin habite : on y vivait encore il y a un an.
	local function backyardProp(parent: Instance, cf: CFrame)
		local kind = random:NextInteger(1, 6)
		local wood, metal = C.woodGray, C.metal
		if kind == 1 then
			-- Une balancoire, une chaine cassee.
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					slab(
						parent,
						(cf * CFrame.new(sx * 4, 0, sz * 2.2)).Position,
						(cf * CFrame.new(sx * 4, 7.5, 0)).Position,
						0.4,
						0.4,
						Enum.Material.Metal,
						metal,
						"Balancoire"
					)
				end
			end
			P(
				parent,
				"Barre",
				Vector3.new(8.4, 0.4, 0.4),
				cf * CFrame.new(0, 7.5, 0),
				Enum.Material.Metal,
				metal
			)
			P(
				parent,
				"Siege",
				Vector3.new(1.8, 0.2, 0.9),
				cf * CFrame.new(-1.5, 2, 0),
				Enum.Material.Plastic,
				C.fabric
			)
			P(
				parent,
				"Siege",
				Vector3.new(1.8, 0.2, 0.9),
				cf * CFrame.new(1.8, 0.4, 0.6) * CFrame.Angles(0.5, 0.4, 0),
				Enum.Material.Plastic,
				C.fabric
			)
		elseif kind == 2 then
			-- Une piscine hors-sol vide, la bache effondree.
			P(
				parent,
				"Piscine",
				Vector3.new(2.6, 9, 9),
				cf * CFrame.new(0, 1.3, 0) * CFrame.Angles(0, 0, math.rad(90)),
				Enum.Material.SmoothPlastic,
				Color3.fromRGB(96, 122, 132),
				{ shape = Enum.PartType.Cylinder }
			)
			P(
				parent,
				"Bache",
				Vector3.new(0.2, 8.4, 8.4),
				cf * CFrame.new(0, 1.4, 0) * CFrame.Angles(0, 0, math.rad(90)),
				Enum.Material.Fabric,
				Color3.fromRGB(56, 70, 60),
				{ shape = Enum.PartType.Cylinder }
			)
		elseif kind == 3 then
			-- Un etendoir, du linge raidi par un an de pluie.
			for _, sx in { -1, 1 } do
				P(
					parent,
					"Poteau",
					Vector3.new(0.3, 6, 0.3),
					cf * CFrame.new(sx * 6, 3, 0),
					Enum.Material.Metal,
					metal
				)
			end
			P(
				parent,
				"Fil",
				Vector3.new(12, 0.08, 0.08),
				cf * CFrame.new(0, 5.8, 0),
				Enum.Material.SmoothPlastic,
				C.black,
				{ collide = false }
			)
			for i = 1, 4 do
				P(
					parent,
					"Linge",
					Vector3.new(1.6, random:NextNumber(1.4, 2.6), 0.1),
					cf * CFrame.new(-5 + i * 2.2, 4.8, 0),
					Enum.Material.Fabric,
					SIDINGS[random:NextInteger(1, #SIDINGS)]:Lerp(C.trim, 0.4),
					{ collide = false }
				)
			end
		elseif kind == 4 then
			-- Une table de jardin et ses chaises renversees.
			P(
				parent,
				"Table",
				Vector3.new(4, 0.3, 4),
				cf * CFrame.new(0, 2.6, 0),
				Enum.Material.Plastic,
				C.trim
			)
			P(
				parent,
				"Pied",
				Vector3.new(0.4, 2.6, 0.4),
				cf * CFrame.new(0, 1.3, 0),
				Enum.Material.Plastic,
				C.trim
			)
			for i = 1, 3 do
				local a = i * 2.1
				P(
					parent,
					"Chaise",
					Vector3.new(1.6, 2.6, 1.6),
					cf
						* CFrame.new(math.cos(a) * 3, 0.8, math.sin(a) * 3)
						* CFrame.Angles(random:NextNumber(0, 1.5), a, 0),
					Enum.Material.Plastic,
					C.trim
				)
			end
		elseif kind == 5 then
			-- Un potager retourne a la friche.
			P(
				parent,
				"Bordure",
				Vector3.new(10, 0.8, 6),
				cf * CFrame.new(0, 0.4, 0),
				Enum.Material.WoodPlanks,
				wood
			)
			P(
				parent,
				"Terre",
				Vector3.new(9.4, 0.3, 5.4),
				cf * CFrame.new(0, 0.85, 0),
				Enum.Material.Ground,
				Color3.fromRGB(70, 56, 44),
				{ collide = false }
			)
			for i = 1, 6 do
				P(
					parent,
					"Plant",
					Vector3.new(0.8, random:NextNumber(0.6, 1.6), 0.8),
					cf * CFrame.new(-4 + i * 1.3, 1.3, random:NextNumber(-1.6, 1.6)),
					Enum.Material.LeafyGrass,
					C.leavesDry,
					{ collide = false }
				)
			end
		else
			-- Des jouets oublies : un tricycle, un ballon, une niche.
			P(
				parent,
				"Niche",
				Vector3.new(3.4, 3, 4),
				cf * CFrame.new(0, 1.5, 0),
				Enum.Material.WoodPlanks,
				C.wood
			)
			P(
				parent,
				"Ballon",
				Vector3.new(1.4, 1.4, 1.4),
				cf * CFrame.new(3.5, 0.7, 2),
				Enum.Material.Plastic,
				Color3.fromRGB(150, 80, 60),
				{ shape = Enum.PartType.Ball }
			)
			P(
				parent,
				"Tricycle",
				Vector3.new(1.4, 1.8, 2.4),
				cf * CFrame.new(-3.5, 0.9, 1.5) * CFrame.Angles(0, 0, math.rad(80)),
				Enum.Material.Metal,
				Color3.fromRGB(80, 96, 120)
			)
		end
	end

	-- Deux parcelles laissent leur place a des reperes : l'eglise au centre, la
	-- station-service sur la rue nord, a l'ouest.
	local churchIndex, stationIndex = 0, 0
	local churchBest, stationBest = math.huge, math.huge
	for i, plot in plots do
		if plot.row.zr == 0 and plot.row.side == 1 and math.abs(plot.x - CHURCH_X) < churchBest then
			churchBest = math.abs(plot.x - CHURCH_X)
			churchIndex = i
		end
		if
			plot.row.zr == EW_ROADS[2]
			and plot.row.side == 1
			and math.abs(plot.x - STATION_X) < stationBest
		then
			stationBest = math.abs(plot.x - STATION_X)
			stationIndex = i
		end
	end

	local insides: { { name: string, at: Vector3, covered: boolean, ruin: boolean } } = {}
	local yards = folder(root, "Jardins")
	for i, plot in plots do
		if i == churchIndex or i == stationIndex then
			continue
		end
		local row = plot.row
		local side = row.side
		-- Chaque maison un peu plus en retrait, un peu decalee, un peu de
		-- biais que sa voisine : une vraie rue n'est pas tracee a la regle.
		local setback = if row.front >= 26 then random:NextNumber(0, 7) else random:NextNumber(0, 2)
		local front = row.zr + side * (row.front + setback)
		local shift = random:NextNumber(-1, 1) * math.max(plot.width / 2 - HOUSE_W / 2 - 16, 0)
		local skew = CFrame.Angles(0, math.rad(random:NextNumber(-3, 3)), 0)
		-- La facade regarde sa voie : vers -Z pour une maison au nord de la voie.
		local cf = (
			if side == 1
				then CFrame.new(plot.x + shift, 0, front)
				else CFrame.new(plot.x + shift, 0, front) * CFrame.Angles(0, math.pi, 0)
		) * skew
		-- Longueur de l'allee, de la facade au bord de la voie.
		local walk = row.front + setback - row.edge
		local aspired = i == aspiredIndex
		-- Un terrain vague de temps en temps : des herbes hautes, des gravats,
		-- une epave, la ou une maison n'a jamais ete finie.
		local vacant = not aspired and random:NextNumber() < 0.1
		local damageRoll = random:NextNumber()
		local damage = if damageRoll < 0.12
			then "ruine"
			elseif damageRoll < 0.3 then "trou"
			else "intact"
		local storeys = if damage == "intact" and random:NextNumber() < 0.4 then 2 else 1
		local storyRoll = random:NextNumber()
		-- Au centre, l'allee est trop etroite pour une voiture : pas de garage.
		local garage = not vacant and not aspired and walk >= 15 and random:NextNumber() < 0.5
		local name = "Maison" .. i

		if walk >= 15 then
			-- La boite aux lettres au bord de la voie, parfois renversee.
			local fallen = random:NextNumber() < 0.3
			local mailCf = cf
				* CFrame.new(-7, 0, -(walk - 0.6))
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
		end
		-- Allee de la voie a la porte, sur un terrain sans herbe.
		terrain:FillBlock(
			cf * CFrame.new(-2.5, -4, -walk / 2),
			Vector3.new(6, 4, walk + 1),
			Enum.Material.Pavement
		)
		P(
			streets,
			"Allee",
			Vector3.new(4, 0.3, walk - 0.6),
			cf * CFrame.new(-2.5, 0.15, -walk / 2),
			Enum.Material.Concrete,
			C.concrete
		)

		if vacant then
			terrain:FillBlock(
				cf * CFrame.new(0, -4, HOUSE_D / 2),
				Vector3.new(plot.width - 6, 4, HOUSE_D + 10),
				Enum.Material.LeafyGrass
			)
			-- Les gravats d'un cote, l'emplacement de l'autre : un emplacement
			-- pose dans les gravats est bloque (vu a la mesure).
			rubble(houses, (cf * CFrame.new(-9, 0.2, HOUSE_D / 2)).Position, 5, 10)
			local kinds = { "Caisses", "Voiture", "Benne", "Buisson" }
			anchor(
				kinds[random:NextInteger(1, #kinds)],
				cf
					* CFrame.new(9, 0, HOUSE_D / 2 + 2)
					* CFrame.Angles(0, math.rad(random:NextNumber(0, 360)), 0)
			)
		elseif not aspired then
			local wood = random:NextNumber() < 0.55
			local r = house(houses, cf, {
				name = name,
				siding = if wood
					then SIDINGS[random:NextInteger(1, #SIDINGS)]
					else (if random:NextNumber() < 0.5 then C.brickRed else C.brickBrown),
				material = if wood then Enum.Material.WoodPlanks else Enum.Material.Brick,
				roof = if random:NextNumber() < 0.6 then C.roofSlate else C.roofBrown,
				damage = damage,
				garage = garage,
				storeys = storeys,
				mirror = random:NextNumber() < 0.5,
				bedroom = random:NextNumber() < 0.5,
				story = if storyRoll < 0.1
					then "barricadee"
					elseif storyRoll < 0.18 then "brulee"
					elseif storyRoll < 0.32 then "mot"
					else nil,
			}, containers)
			table.insert(insides, {
				name = name,
				at = r.inside,
				covered = damage == "intact",
				ruin = damage == "ruine",
			})
			terrain:FillBlock(
				cf * CFrame.new(0, -4, HOUSE_D / 2),
				Vector3.new(HOUSE_W + 4, 4, HOUSE_D + 4),
				Enum.Material.Pavement
			)
			if garage then
				terrain:FillBlock(
					cf * CFrame.new(HOUSE_W / 2 + 6.2, -4, -walk / 2 + 8),
					Vector3.new(14, 4, walk + 18),
					Enum.Material.Pavement
				)
				P(
					streets,
					"AlleeGarage",
					Vector3.new(10, 0.3, walk + 1),
					cf * CFrame.new(HOUSE_W / 2 + 6.2, 0.15, -walk / 2 + 0.5),
					Enum.Material.Concrete,
					C.concreteDark
				)
				-- Une voiture peut etre garee devant (cachette fragile).
				anchor("Voiture", cf * CFrame.new(HOUSE_W / 2 + 6.2, 0, -walk / 2))
			end
		else
			-- La maison a ete prise : il reste la dalle, des gravats, un cratere.
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

		-- Haie devant, ouverte pour l'allee et le garage (pas au centre : on
		-- y vit porte contre porte).
		if walk >= 15 then
			local hz = row.zr + side * (row.edge + 4)
			local gaps = { { (cf * CFrame.new(-2.5, 0, 0)).Position.X, 3.5 } }
			if garage then
				table.insert(gaps, { (cf * CFrame.new(HOUSE_W / 2 + 6.2, 0, 0)).Position.X, 6.5 })
			end
			table.sort(gaps, function(g1, g2)
				return g1[1] < g2[1]
			end)
			local cursor = plot.x - plot.width / 2 + 2
			for _, gap in gaps do
				if gap[1] - gap[2] - cursor > 1 then
					hedge(nature, Vector3.new(cursor, 0, hz), Vector3.new(gap[1] - gap[2], 0, hz))
				end
				cursor = gap[1] + gap[2]
			end
			if plot.x + plot.width / 2 - 2 - cursor > 1 then
				hedge(
					nature,
					Vector3.new(cursor, 0, hz),
					Vector3.new(plot.x + plot.width / 2 - 2, 0, hz)
				)
			end
		end
		-- Palissades : au fond du jardin et entre les jardins.
		local back = row.zr + side * row.back
		fence(
			nature,
			Vector3.new(plot.x - plot.width / 2, 0, back),
			Vector3.new(plot.x + plot.width / 2, 0, back),
			6
		)
		fence(
			nature,
			Vector3.new(plot.x + plot.width / 2, 0, row.zr + side * (row.front + HOUSE_D + 4)),
			Vector3.new(plot.x + plot.width / 2, 0, back),
			5
		)

		-- Un arbre sur la pelouse (cote oppose au garage), s'il y a une pelouse.
		if walk >= 15 then
			local garageX = (cf * CFrame.new(HOUSE_W / 2 + 6.2, 0, 0)).Position.X
			local lawnX = if garage
				then plot.x - (garageX - plot.x) * 0.9
				else plot.x + random:NextNumber(10, 22) * (if random:NextNumber() < 0.5
					then 1
					else -1)
			tree(
				nature,
				Vector3.new(lawnX, 0, row.zr + side * (row.edge + walk * 0.55)),
				random:NextNumber() < 0.15
			)
			-- Un buisson touffu contre la haie, du cote oppose a l'arbre.
			local away = if lawnX > plot.x then -1 else 1
			anchor(
				"Buisson",
				CFrame.new(plot.x + away * (plot.width / 2 - 6), 0, row.zr + side * (row.edge + 8))
					* CFrame.Angles(0, (if side == 1 then 0 else math.pi), 0)
			)
		end
		-- Le jardin : ce qu'on y a laisse, un arbre, une cachette fragile.
		local yardFront = row.front + HOUSE_D + 4
		local yardDepth = row.back - yardFront
		if yardDepth > 14 then
			local yardZ = function(t: number): number
				return row.zr + side * (yardFront + yardDepth * t)
			end
			local yardYaw = CFrame.Angles(
				0,
				(if side == 1 then 0 else math.pi) + math.rad(random:NextNumber(-12, 12)),
				0
			)
			backyardProp(
				yards,
				CFrame.new(plot.x - random:NextNumber(4, 14), 0, yardZ(0.35)) * yardYaw
			)
			if yardDepth > 30 then
				tree(
					nature,
					Vector3.new(
						plot.x + random:NextNumber(-24, -16),
						0,
						yardZ(random:NextNumber(0.7, 0.85))
					),
					random:NextNumber() < 0.25
				)
			end
			-- Une tole appuyee contre la palissade, au fond du jardin (contre
			-- la maison, elle tombait devant une porte de cote).
			anchor(
				"Tole",
				CFrame.new(plot.x + plot.width / 2 - 3.4, 0, yardZ(math.min(8 / yardDepth, 0.4)))
					* CFrame.Angles(0, math.pi / 2, 0)
			)
			local roll = random:NextNumber()
			anchor(
				if roll < 0.5 then "Abri" elseif roll < 0.75 then "Caisses" else "Buisson",
				CFrame.new(plot.x + random:NextNumber(10, 18), 0, yardZ(0.6)) * yardYaw
			)
		end
		if i % 4 == 0 then
			task.wait()
		end
	end

	-- L'allee pietonne du centre, et le chemin de terre du bord.
	terrain:FillBlock(CFrame.new(0, -4, 0), Vector3.new(HALF_X * 2, 4, 8), Enum.Material.Ground)
	P(
		streets,
		"AlleeCentrale",
		Vector3.new(HALF_X * 2, 0.25, 6),
		CFrame.new(0, 0.12, 0),
		Enum.Material.Concrete,
		C.concreteDark
	)
	for _, zr in { -OUTER_ROAD, OUTER_ROAD } do
		terrain:FillBlock(
			CFrame.new(0, -4, zr),
			Vector3.new(HALF_X * 2 + 80, 4, 16),
			Enum.Material.Ground
		)
		P(
			streets,
			"Chemin",
			Vector3.new(HALF_X * 2 + 40, 0.3, 14),
			CFrame.new(0, 0.15, zr),
			Enum.Material.Pebble,
			Color3.fromRGB(104, 98, 90)
		)
		-- Au-dela du chemin : un rideau d'arbres jusqu'a la limite.
		for x = -HALF_X + 10, HALF_X - 10, 34 do
			tree(
				nature,
				Vector3.new(
					x + random:NextNumber(-8, 8),
					0,
					zr + (if zr > 0 then 1 else -1) * random:NextNumber(14, 24)
				),
				random:NextNumber() < 0.35
			)
		end
	end

	-- LA BANDE CENTRALE : la superette et le terrain de basket.
	local center = folder(root, "Centre")
	-- La superette : un grand cube plat, vitrine tournee vers son parking a
	-- l'ouest.
	do
		local cf = CFrame.new(SUPERETTE_X, 0, 0) * CFrame.Angles(0, math.rad(90), 0)
		local m = model(center, "Superette")
		local w, d, h = 56, 36, 12
		P(
			m,
			"Dalle",
			Vector3.new(w + 2, 1, d + 2),
			cf * CFrame.new(0, 0.1, d / 2),
			Enum.Material.Concrete,
			C.concrete
		)
		wall(m, cf * CFrame.new(0, 0.6, 0.4), w, h, THICK, {
			{ x = -16, w = 14, b = 1.2, t = 9, kind = "window" },
			{ x = 0, w = 6, b = 0, t = 8, kind = "door" },
			{ x = 16, w = 14, b = 1.2, t = 9, kind = "window" },
		}, Enum.Material.Concrete, C.sidingGray)
		wall(m, cf * CFrame.new(0, 0.6, d - 0.4), w, h, THICK, {
			{ x = 20, w = 4, b = 0, t = 7.5, kind = "door" },
		}, Enum.Material.Concrete, C.sidingGray)
		for _, sideX in { -1, 1 } do
			wall(
				m,
				cf
					* CFrame.new(sideX * (w / 2 - 0.4), 0.6, d / 2)
					* CFrame.Angles(0, math.rad(90), 0),
				d - 1.6,
				h,
				THICK,
				{},
				Enum.Material.Concrete,
				C.sidingGray
			)
		end
		-- Le toit est creve sur un coin : on y voit le ciel.
		P(
			m,
			"Toit",
			Vector3.new(w + 1, 0.8, d * 0.7),
			cf * CFrame.new(0, h + 1, d * 0.65),
			Enum.Material.Concrete,
			C.concreteDark
		)
		P(
			m,
			"Toit",
			Vector3.new(w * 0.55, 0.8, d * 0.32),
			cf * CFrame.new(-w * 0.22, h + 1, d * 0.16),
			Enum.Material.Concrete,
			C.concreteDark
		)
		P(
			m,
			"Enseigne",
			Vector3.new(30, 4, 0.6),
			cf * CFrame.new(0, h + 3.4, -0.2),
			Enum.Material.SmoothPlastic,
			Color3.fromRGB(150, 60, 50)
		)
		for rayonIndex = 1, 4 do
			local rayon = P(
				containers,
				"Superette_Rayon" .. rayonIndex,
				Vector3.new(30, 5, 2),
				cf * CFrame.new(-6, 3.1, 8 + rayonIndex * 5),
				Enum.Material.Metal,
				C.trim
			)
			rayon:SetAttribute("Table", "superette")
		end
		for _ = 1, 30 do
			P(
				m,
				"Produit",
				Vector3.new(0.8, 1, 0.8),
				cf
					* CFrame.new(random:NextNumber(-20, 8), 0.9, random:NextNumber(6, 30))
					* CFrame.Angles(random:NextNumber(0, 3), random:NextNumber(0, 3), 0),
				Enum.Material.SmoothPlastic,
				CAR_COLORS[random:NextInteger(1, #CAR_COLORS)],
				{ collide = false }
			)
		end
		-- Le parking devant, a l'ouest.
		P(
			streets,
			"Parking",
			Vector3.new(36, 0.3, 56),
			CFrame.new(SUPERETTE_X - 20, 0.15, 0),
			Enum.Material.Asphalt,
			C.asphaltPatch
		)
		terrain:FillBlock(
			CFrame.new(SUPERETTE_X, -4, 0),
			Vector3.new(96, 4, 62),
			Enum.Material.Pavement
		)
		anchor("Voiture", CFrame.new(SUPERETTE_X - 22, 0, -14) * CFrame.Angles(0, math.rad(90), 0))
		anchor("Voiture", CFrame.new(SUPERETTE_X - 22, 0, 12) * CFrame.Angles(0, math.rad(90), 0))
		anchor("Benne", CFrame.new(SUPERETTE_X + 42, 0, 22) * CFrame.Angles(0, math.rad(90), 0))
		tagBuilding(m, 0)
	end
	-- Le terrain de basket, derriere un grillage qu'on voit au travers.
	do
		local cx = BASKET_X
		P(
			center,
			"Terrain",
			Vector3.new(56, 0.3, 32),
			CFrame.new(cx, 0.15, 0),
			Enum.Material.Asphalt,
			Color3.fromRGB(70, 66, 64)
		)
		terrain:FillBlock(CFrame.new(cx, -4, 0), Vector3.new(64, 4, 40), Enum.Material.Pavement)
		for _, sx in { -1, 1 } do
			P(
				center,
				"Poteau",
				Vector3.new(0.6, 11, 0.6),
				CFrame.new(cx + sx * 26, 5.5, 0),
				Enum.Material.Metal,
				C.metal
			)
			P(
				center,
				"Panneau",
				Vector3.new(0.3, 3.6, 6),
				CFrame.new(cx + sx * 25.4, 10, 0),
				Enum.Material.SmoothPlastic,
				C.trim
			)
		end
		for _, fenceEdge in
			{
				{ Vector3.new(60, 8, 0.2), Vector3.new(cx, 4, -18) },
				{ Vector3.new(60, 8, 0.2), Vector3.new(cx, 4, 18) },
				{ Vector3.new(0.2, 8, 36), Vector3.new(cx - 30, 4, 0) },
			}
		do
			P(
				center,
				"Grillage",
				fenceEdge[1],
				CFrame.new(fenceEdge[2]),
				Enum.Material.DiamondPlate,
				C.metal,
				{ transparency = 0.7 }
			)
		end
		anchor("Caisses", CFrame.new(cx + 14, 0, -8))
	end
	task.wait()

	-- LES REPERES.
	local landmarks = folder(root, "Reperes")
	-- L'eglise : une nef de pierre et un clocher, qu'on voit de partout au
	-- centre.
	do
		local cf = CFrame.new(CHURCH_X, 0, 4)
		local m = model(landmarks, "Eglise")
		local w, d, h = 22, 40, 14
		local stone = Color3.fromRGB(150, 144, 132)
		P(
			m,
			"Dalle",
			Vector3.new(w + 2, 1, d + 2),
			cf * CFrame.new(0, 0.1, d / 2),
			Enum.Material.Concrete,
			C.concreteDark
		)
		wall(
			m,
			cf * CFrame.new(0, 0.6, 0.4),
			w,
			h,
			THICK,
			{ { x = 0, w = 5, b = 0, t = 9, kind = "door" } },
			Enum.Material.Cobblestone,
			stone
		)
		wall(m, cf * CFrame.new(0, 0.6, d - 0.4), w, h, THICK, {}, Enum.Material.Cobblestone, stone)
		for _, side in { -1, 1 } do
			wall(
				m,
				cf
					* CFrame.new(side * (w / 2 - 0.4), 0.6, d / 2)
					* CFrame.Angles(0, math.rad(90), 0),
				d - 1.6,
				h,
				THICK,
				{
					{ x = -10, w = 3, b = 4, t = 11, kind = "window" },
					{ x = 0, w = 3, b = 4, t = 11, kind = "window" },
					{ x = 10, w = 3, b = 4, t = 11, kind = "window" },
				},
				Enum.Material.Cobblestone,
				stone
			)
		end
		local top = h + 0.6
		slab(
			m,
			(cf * CFrame.new(-w / 2 - 1, top, d / 2)).Position,
			(cf * CFrame.new(0, top + 9, d / 2)).Position,
			d + 2,
			0.8,
			Enum.Material.Slate,
			C.roofSlate,
			"Toit"
		)
		slab(
			m,
			(cf * CFrame.new(w / 2 + 1, top, d / 2)).Position,
			(cf * CFrame.new(0, top + 9, d / 2)).Position,
			d + 2,
			0.8,
			Enum.Material.Slate,
			C.roofSlate,
			"Toit"
		)
		-- Les bancs.
		for row = 1, 6 do
			for _, side in { -1, 1 } do
				P(
					m,
					"Banc",
					Vector3.new(7, 1.2, 1.6),
					cf * CFrame.new(side * 5, 1.2, 8 + row * 4),
					Enum.Material.WoodPlanks,
					C.wood
				)
			end
		end
		local sacristy = P(
			containers,
			"Eglise_Sacristie",
			Vector3.new(4, 4, 1.6),
			cf * CFrame.new(0, 2.6, d - 1.8),
			Enum.Material.WoodPlanks,
			C.wood
		)
		sacristy:SetAttribute("Table", "salleDeBain")
		-- Le clocher, et sa fleche.
		P(
			m,
			"Clocher",
			Vector3.new(8, 34, 8),
			cf * CFrame.new(0, 17.6, -4),
			Enum.Material.Cobblestone,
			stone
		)
		-- La fleche : quatre faces en triangle qui se rejoignent en pointe.
		local spireBase = (cf * CFrame.new(0, 34.6, -4)).Position
		local apex = spireBase + Vector3.new(0, 18, 0)
		local corners = {
			spireBase + Vector3.new(-4, 0, -4),
			spireBase + Vector3.new(4, 0, -4),
			spireBase + Vector3.new(4, 0, 4),
			spireBase + Vector3.new(-4, 0, 4),
		}
		for i = 1, 4 do
			triangle(
				m,
				corners[i],
				corners[(i % 4) + 1],
				apex,
				0.6,
				Enum.Material.Slate,
				C.roofSlate
			)
		end
		-- Les pignons de la nef : sans eux, le toit est ouvert aux deux bouts.
		for _, z in { 0.4, d - 0.4 } do
			triangle(
				m,
				(cf * CFrame.new(-w / 2, top, z)).Position,
				(cf * CFrame.new(w / 2, top, z)).Position,
				(cf * CFrame.new(0, top + 9, z)).Position,
				THICK,
				Enum.Material.Cobblestone,
				stone
			)
		end
		P(
			m,
			"Cloche",
			Vector3.new(3, 3, 3),
			cf * CFrame.new(0, 30, -8.2),
			Enum.Material.Metal,
			Color3.fromRGB(110, 96, 60),
			{ shape = Enum.PartType.Ball }
		)
		tagBuilding(m, 0)
	end
	-- La station-service : un auvent sur des pompes, une petite boutique.
	do
		local cf = CFrame.new(STATION_X, 0, EW_ROADS[2] + 24)
		local m = model(landmarks, "Station")
		P(
			streets,
			"Piste",
			Vector3.new(44, 0.3, 30),
			cf * CFrame.new(0, 0.15, 15),
			Enum.Material.Asphalt,
			C.asphaltPatch
		)
		terrain:FillBlock(
			cf * CFrame.new(0, -4, 22),
			Vector3.new(50, 4, 48),
			Enum.Material.Pavement
		)
		for _, sx in { -1, 1 } do
			for _, sz in { 0, 1 } do
				P(
					m,
					"Pilier",
					Vector3.new(1, 9, 1),
					cf * CFrame.new(sx * 14, 4.6, 6 + sz * 16),
					Enum.Material.Metal,
					C.trim
				)
			end
			P(
				m,
				"Pompe",
				Vector3.new(2, 4.6, 1.4),
				cf * CFrame.new(sx * 6, 2.6, 14),
				Enum.Material.SmoothPlastic,
				Color3.fromRGB(150, 60, 50)
			)
		end
		P(
			m,
			"Toit",
			Vector3.new(32, 1.2, 22),
			cf * CFrame.new(0, 9.6, 14),
			Enum.Material.Metal,
			C.trim
		)
		P(
			m,
			"Bandeau",
			Vector3.new(32.4, 1.6, 22.4),
			cf * CFrame.new(0, 8.4, 14),
			Enum.Material.SmoothPlastic,
			Color3.fromRGB(150, 60, 50)
		)
		local shop = cf * CFrame.new(0, 0, 32)
		P(
			m,
			"Dalle",
			Vector3.new(22, 1, 14),
			shop * CFrame.new(0, 0.1, 7),
			Enum.Material.Concrete,
			C.concrete
		)
		wall(m, shop * CFrame.new(0, 0.6, 0.4), 22, 9, THICK, {
			{ x = -5, w = 8, b = 1.2, t = 7, kind = "window" },
			{ x = 5, w = 4, b = 0, t = 7.5, kind = "door" },
		}, Enum.Material.Concrete, C.sidingGray)
		wall(
			m,
			shop * CFrame.new(0, 0.6, 13.6),
			22,
			9,
			THICK,
			{},
			Enum.Material.Concrete,
			C.sidingGray
		)
		for _, side in { -1, 1 } do
			wall(
				m,
				shop * CFrame.new(side * 10.6, 0.6, 7) * CFrame.Angles(0, math.rad(90), 0),
				12.4,
				9,
				THICK,
				{},
				Enum.Material.Concrete,
				C.sidingGray
			)
		end
		P(
			m,
			"Toit",
			Vector3.new(23, 0.8, 15),
			shop * CFrame.new(0, 10, 7),
			Enum.Material.Concrete,
			C.concreteDark
		)
		local counter = P(
			containers,
			"Station_Comptoir",
			Vector3.new(8, 3, 2),
			shop * CFrame.new(-4, 1.6, 9),
			Enum.Material.SmoothPlastic,
			C.trim
		)
		counter:SetAttribute("Table", "superette")
		local workshop = P(
			containers,
			"Station_Atelier",
			Vector3.new(6, 4.2, 1.6),
			shop * CFrame.new(5, 2.6, 12.4),
			Enum.Material.Metal,
			C.metal
		)
		workshop:SetAttribute("Table", "garage")
		tagBuilding(m, 0)
		anchor("Voiture", cf * CFrame.new(0, 0, 26) * CFrame.Angles(0, math.rad(90), 0))
	end
	-- Le chateau d'eau : au nord, au-dela du chemin, plus haut que tout.
	do
		local m = model(landmarks, "ChateauDEau")
		local legH = 44
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				P(
					m,
					"Pied",
					Vector3.new(legH, 1.4, 1.4),
					CFrame.new(TOWER + Vector3.new(sx * 7, legH / 2, sz * 7))
						* CFrame.Angles(0, 0, math.rad(90)),
					Enum.Material.Metal,
					C.metal,
					{ shape = Enum.PartType.Cylinder }
				)
			end
		end
		P(
			m,
			"Cuve",
			Vector3.new(16, 26, 26),
			CFrame.new(TOWER + Vector3.new(0, legH + 8, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Enum.Material.Metal,
			Color3.fromRGB(150, 156, 152),
			{ shape = Enum.PartType.Cylinder }
		)
		P(
			m,
			"Chapeau",
			Vector3.new(20, 4, 20),
			CFrame.new(TOWER + Vector3.new(0, legH + 18, 0)),
			Enum.Material.Metal,
			C.metal
		)
		P(
			m,
			"Echelle",
			Vector3.new(1.4, legH, 0.3),
			CFrame.new(TOWER + Vector3.new(0, legH / 2, -8)),
			Enum.Material.Metal,
			C.metal
		)
	end
	task.wait()

	-- LE LONG DES RUES : poteaux et fils, lampadaires, voitures, bennes, sacs.
	for _, zr in EW_ROADS do
		local previous: { Attachment }? = nil
		for x = -HALF_X + 12, HALF_X - 12, 46 do
			if nearCrossing(x, 22) then
				previous = nil
				continue
			end
			local leaning = random:NextNumber() < 0.12
			local base = CFrame.new(x, 0.7, zr + 21.5)
				* (
					if leaning
						then CFrame.Angles(math.rad(-14), 0, math.rad(6))
						else CFrame.identity
				)
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
				-- WorldPosition se lit comme une position locale (vu en image).
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
					wire.CurveSize0 = -4
					wire.CurveSize1 = 4
					wire.Parent = pole
				end
			end
			previous = current
		end
		for x = -HALF_X + 20, HALF_X - 20, 52 do
			if not nearCrossing(x, 24) then
				lamp(props, Vector3.new(x, 0.7, zr - 18), Vector3.new(0, 0, 1))
			end
		end
		for _ = 1, 6 do
			local x = random:NextNumber(-HALF_X + 20, HALF_X - 20)
			if not nearCrossing(x, 30) then
				local sz = if random:NextNumber() < 0.5 then 1 else -1
				anchor(
					"Voiture",
					CFrame.new(x, 0, zr + sz * 7)
						* CFrame.Angles(0, math.rad(if sz == 1 then 90 else -90), 0)
				)
			end
		end
		for _ = 1, 3 do
			local x = random:NextNumber(-HALF_X + 30, HALF_X - 30)
			if not nearCrossing(x, 34) then
				anchor(
					"Benne",
					-- Le trottoir nord seulement : au sud, les lampadaires (vu a la mesure).
					CFrame.new(x, 0, zr + 16) * CFrame.Angles(0, math.rad(90), 0)
				)
			end
		end
		-- Sacs poubelle eventres. Sans collision : un sac ne doit jamais
		-- bloquer une cachette.
		for _ = 1, 10 do
			local at = Vector3.new(
				random:NextNumber(-HALF_X, HALF_X),
				0.7,
				zr + (if random:NextNumber() < 0.5 then 1 else -1) * random:NextNumber(13, 19)
			)
			if nearCrossing(at.X, 20) then
				continue
			end
			for _ = 1, random:NextInteger(2, 4) do
				local size = random:NextNumber(1.6, 2.4)
				P(
					props,
					"Sac",
					Vector3.new(size, size * 0.75, size * 0.9),
					CFrame.new(
						at
							+ Vector3.new(
								random:NextNumber(-1.4, 1.4),
								size * 0.3,
								random:NextNumber(-1, 1)
							)
					)
						* CFrame.Angles(
							random:NextNumber(-0.3, 0.3),
							random:NextNumber(0, 6),
							random:NextNumber(-0.3, 0.3)
						),
					Enum.Material.Plastic,
					Color3.fromRGB(26, 26, 28),
					{ collide = false }
				)
			end
		end
	end
	-- Voitures sur les rues nord-sud, et une epave a fouiller par rue.
	for i, xr in NS_ROADS do
		anchor("Voiture", CFrame.new(xr + 6, 0, random:NextNumber(30, 140)))
		anchor(
			"Voiture",
			CFrame.new(xr - 6, 0, -random:NextNumber(30, 140)) * CFrame.Angles(0, math.pi, 0)
		)
		local wreckCf = CFrame.new(
			xr + random:NextNumber(-4, 4),
			0.4,
			(if i % 2 == 0 then 1 else -1) * random:NextNumber(200, 290)
		) * CFrame.Angles(0, random:NextNumber(-0.4, 0.4), 0)
		local carModel = car(props, wreckCf, CAR_COLORS[random:NextInteger(1, #CAR_COLORS)], true)
		carModel.Name = "Epave" .. i
		local glove = P(
			containers,
			"Epave" .. i .. "_BoiteAGants",
			Vector3.new(2, 1, 1.4),
			wreckCf * CFrame.new(1.2, 3.2, -2.4),
			Enum.Material.SmoothPlastic,
			C.black,
			{ transparency = 1, collide = false }
		)
		glove:SetAttribute("Table", "voiture")
	end
	-- Barricades aux bouts des rues : la ville continue, pas nous.
	local function barricade(cf: CFrame, length: number)
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
	for _, zr in EW_ROADS do
		barricade(CFrame.new(-HALF_X - 8, 0.4, zr), 26)
		barricade(CFrame.new(HALF_X + 8, 0.4, zr), 26)
	end
	for _, xr in NS_ROADS do
		local _ = xr
	end
	-- Les rues nord-sud finissent sur le chemin du bord ; c'est lui qu'on barre.
	for _, zr in { -OUTER_ROAD, OUTER_ROAD } do
		barricade(CFrame.new(-HALF_X - 8, 0.4, zr), 16)
		barricade(CFrame.new(HALF_X + 8, 0.4, zr), 16)
	end
	-- LA CAMPAGNE. Autour de la ville, jusqu'a FIELD, une zone qu'on peut
	-- parcourir : des bosses et des collines au hasard, des maisons isolees
	-- abandonnees le long d'un chemin de terre, des epaves, des abris, des
	-- bosquets. Remplace un anneau de collines regulier autour du quartier,
	-- « bizarre » et « vide » pour Josh (5 novembre 2026).
	local country = folder(root, "Campagne")
	local function inCountry(x: number, z: number, margin: number): boolean
		local outsideTown = math.abs(x) > HALF_X + 30 + margin or math.abs(z) > HALF_Z + 30 + margin
		local insideField = math.abs(x) < FIELD - margin and math.abs(z) < FIELD - margin
		return outsideTown and insideField
	end

	-- Les chemins de terre : ils partent des sorties de la ville et serpentent
	-- vers le dehors, au hasard. Un autre mene a la Planque.
	type Segment = { a: Vector3, b: Vector3 }
	local tracks: { Segment } = {}
	local function wander(start: Vector3, direction: Vector3, goal: Vector3?)
		local at = start
		local dir = direction.Unit
		for _ = 1, 40 do
			local turn = math.rad(random:NextNumber(-32, 32))
			dir = Vector3.new(
				dir.X * math.cos(turn) - dir.Z * math.sin(turn),
				0,
				dir.X * math.sin(turn) + dir.Z * math.cos(turn)
			)
			-- Toujours un peu tire vers le dehors (ou vers son but) : un chemin
			-- ne revient pas en ville.
			local pull = if goal then (goal - at).Unit else Vector3.new(at.X, 0, at.Z).Unit
			dir = (dir + pull * 0.6).Unit
			local nextAt = at + dir * random:NextNumber(40, 75)
			if goal and (goal - nextAt).Magnitude < 40 then
				table.insert(tracks, { a = at, b = goal })
				return
			end
			if math.max(math.abs(nextAt.X), math.abs(nextAt.Z)) > FIELD - 30 then
				return
			end
			table.insert(tracks, { a = at, b = nextAt })
			at = nextAt
		end
	end
	local exits = {
		{ Vector3.new(NS_ROADS[1], 0, -OUTER_ROAD - 7), Vector3.new(0, 0, -1) },
		{ Vector3.new(NS_ROADS[2], 0, OUTER_ROAD + 7), Vector3.new(0, 0, 1) },
		{ Vector3.new(NS_ROADS[3], 0, -OUTER_ROAD - 7), Vector3.new(0, 0, -1) },
		{ Vector3.new(NS_ROADS[3], 0, OUTER_ROAD + 7), Vector3.new(0, 0, 1) },
		{ Vector3.new(HALF_X, 0, 0), Vector3.new(1, 0, 0) },
		{ Vector3.new(-HALF_X, 0, 0), Vector3.new(-1, 0, 0) },
		{ Vector3.new(HALF_X, 0, EW_ROADS[1]), Vector3.new(1, 0, 0) },
	}
	for _, exit in exits do
		wander(exit[1], exit[2], nil)
	end
	-- Le chemin de la Planque, depuis la sortie sud-ouest de la ville.
	wander(
		Vector3.new(-HALF_X, 0, EW_ROADS[1]),
		Vector3.new(-1, 0, -0.4),
		PLANQUE_AT + Vector3.new(0, 0, 12)
	)
	local function nearTrack(position: Vector3, distance: number): boolean
		for _, t in tracks do
			local ab = t.b - t.a
			local along = math.clamp((position - t.a):Dot(ab) / ab:Dot(ab), 0, 1)
			local closest = t.a + ab * along
			if (Vector3.new(position.X, 0, position.Z) - closest).Magnitude < distance then
				return true
			end
		end
		return false
	end
	for _, t in tracks do
		local mid = (t.a + t.b) / 2
		local length = (t.b - t.a).Magnitude + TRACK_W
		terrain:FillBlock(
			CFrame.lookAt(mid + Vector3.new(0, -4, 0), t.b + Vector3.new(0, -4, 0)),
			Vector3.new(TRACK_W, 4, length),
			Enum.Material.Ground
		)
	end

	-- Les fermes : quelques hameaux de deux a quatre maisons, et des maisons
	-- seules, eparpillees au hasard (plus de boucle reguliere : « un cercle de
	-- maisons », Josh). Jamais tout pres de la Planque.
	local farmSpots: { Vector3 } = { PLANQUE_AT }
	local farmCount = 0
	local function farFromFarms(at: Vector3, distance: number): boolean
		for _, spot in farmSpots do
			if (spot - at).Magnitude < distance then
				return false
			end
		end
		return true
	end
	local function farm(at: Vector3, yaw: number)
		local cf = CFrame.new(at) * CFrame.Angles(0, yaw, 0)
		farmCount += 1
		local roll = random:NextNumber()
		local damage = if roll < 0.3 then "ruine" elseif roll < 0.55 then "trou" else "intact"
		local wood = random:NextNumber() < 0.7
		local r = house(houses, cf, {
			name = "Ferme" .. farmCount,
			siding = if wood
				then SIDINGS[random:NextInteger(1, #SIDINGS)]:Lerp(C.woodGray, 0.4)
				else C.brickBrown,
			material = if wood then Enum.Material.WoodPlanks else Enum.Material.Brick,
			roof = if random:NextNumber() < 0.5 then C.roofSlate else C.roofBrown,
			damage = damage,
			garage = random:NextNumber() < 0.35,
			storeys = if damage == "intact" and random:NextNumber() < 0.3 then 2 else 1,
			mirror = random:NextNumber() < 0.5,
			bedroom = random:NextNumber() < 0.6,
			story = if random:NextNumber() < 0.3
				then "mot"
				elseif random:NextNumber() < 0.2 then "barricadee"
				else nil,
		}, containers)
		table.insert(insides, {
			name = "Ferme" .. farmCount,
			at = r.inside,
			covered = damage == "intact",
			ruin = damage == "ruine",
		})
		terrain:FillBlock(
			cf * CFrame.new(0, -4, HOUSE_D / 2),
			Vector3.new(HOUSE_W + 24, 4, HOUSE_D + 24),
			Enum.Material.Ground
		)
		table.insert(farmSpots, (cf * CFrame.new(0, 0, HOUSE_D / 2)).Position)
		-- Une tole debout devant la ferme, sur son panneau (contre le mur,
		-- elle tombait devant une porte de cote ; sur le flanc, dans le
		-- garage de certaines fermes).
		anchor(
			"Tole",
			cf * CFrame.new(-14, 0, -7) * CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0)
		)
		anchor("Buisson", cf * CFrame.new(random:NextNumber(8, 11), 0, -5.5))
		anchor(
			if random:NextNumber() < 0.6 then "Abri" else "Caisses",
			cf
				* CFrame.new(random:NextNumber(-16, 16), 0, HOUSE_D + 14)
				* CFrame.Angles(0, math.pi, 0)
		)
		fence(
			country,
			(cf * CFrame.new(-24, 0, HOUSE_D + 26)).Position,
			(cf * CFrame.new(random:NextNumber(0, 20), 0, HOUSE_D + 26)).Position,
			4
		)
		tree(
			nature,
			(cf * CFrame.new(
				random:NextNumber(18, 26) * (if random:NextNumber() < 0.5 then 1 else -1),
				0,
				random:NextNumber(4, 20)
			)).Position,
			random:NextNumber() < 0.3
		)
		if random:NextNumber() < 0.5 then
			anchor(
				"Voiture",
				cf
					* CFrame.new(random:NextNumber(-8, 8), 0, -14)
					* CFrame.Angles(0, math.rad(90), 0)
			)
		end
	end
	-- Les hameaux.
	local hamlets = 0
	for _ = 1, 200 do
		if hamlets >= 6 then
			break
		end
		local center =
			Vector3.new(random:NextNumber(-FIELD, FIELD), 0, random:NextNumber(-FIELD, FIELD))
		if
			inCountry(center.X, center.Z, 50)
			and farFromFarms(center, 170)
			and (center - PLANQUE_AT).Magnitude > 200
		then
			hamlets += 1
			local baseYaw = random:NextNumber(0, math.pi * 2)
			for k = 1, random:NextInteger(2, 4) do
				local angle = baseYaw + k * random:NextNumber(1.2, 1.9)
				local at = center
					+ Vector3.new(math.cos(angle), 0, math.sin(angle))
						* random:NextNumber(30, 48)
				if inCountry(at.X, at.Z, 30) and farFromFarms(at, 36) and not nearTrack(at, 16) then
					-- Les maisons d'un hameau se tournent vers son centre.
					local toCenter = center - at
					farm(at, math.atan2(toCenter.X, toCenter.Z) + math.pi)
				end
			end
			task.wait()
		end
	end
	-- Les maisons seules.
	local alone = 0
	for _ = 1, 300 do
		if alone >= 9 then
			break
		end
		local at =
			Vector3.new(random:NextNumber(-FIELD, FIELD), 0, random:NextNumber(-FIELD, FIELD))
		if
			inCountry(at.X, at.Z, 40)
			and farFromFarms(at, 110)
			and not nearTrack(at, 18)
			and (at - PLANQUE_AT).Magnitude > 160
		then
			alone += 1
			farm(at, random:NextNumber(0, math.pi * 2))
		end
	end

	-- LA PLANQUE : une ferme en ruine, seule au fond du coin sud-ouest, et sa
	-- cave sous le jardin.
	do
		local cf = CFrame.new(PLANQUE_AT) * CFrame.Angles(0, math.pi, 0)
		house(houses, cf, {
			name = "FermePlanque",
			siding = C.sidingGray:Lerp(C.woodGray, 0.5),
			material = Enum.Material.WoodPlanks,
			roof = C.roofBrown,
			damage = "ruine",
			garage = false,
			storeys = 1,
			mirror = false,
			bedroom = false,
			story = nil,
		}, containers)
		terrain:FillBlock(
			cf * CFrame.new(0, -4, HOUSE_D / 2),
			Vector3.new(HOUSE_W + 30, 4, HOUSE_D + 40),
			Enum.Material.Ground
		)
		fence(
			country,
			(cf * CFrame.new(-26, 0, -6)).Position,
			(cf * CFrame.new(-26, 0, HOUSE_D + 34)).Position,
			5
		)
		tree(nature, (cf * CFrame.new(22, 0, 6)).Position, true)
	end

	local function clear(position: Vector3, distance: number): boolean
		for _, spot in farmSpots do
			if (spot - position).Magnitude < distance then
				return false
			end
		end
		return not nearTrack(position, distance * 0.4)
	end

	-- Les bosses : de petites boules de terrain a demi enterrees, partout dans
	-- la campagne, loin des maisons et des chemins.
	for _ = 1, 170 do
		local at =
			Vector3.new(random:NextNumber(-FIELD, FIELD), 0, random:NextNumber(-FIELD, FIELD))
		local radius = random:NextNumber(10, 32)
		if inCountry(at.X, at.Z, radius * 0.6) and clear(at, radius + 26) then
			terrain:FillBall(
				at - Vector3.new(0, radius * random:NextNumber(0.55, 0.75), 0),
				radius,
				if random:NextNumber() < 0.75 then Enum.Material.Grass else Enum.Material.LeafyGrass
			)
		end
	end
	-- Quelques vraies collines dans la campagne, et beaucoup au-dela : placees
	-- au hasard, pas en anneau.
	for _ = 1, 26 do
		local at =
			Vector3.new(random:NextNumber(-FIELD, FIELD), 0, random:NextNumber(-FIELD, FIELD))
		local radius = random:NextNumber(30, 70)
		if inCountry(at.X, at.Z, radius) and clear(at, radius + 30) then
			terrain:FillBall(at - Vector3.new(0, radius * 0.62, 0), radius, Enum.Material.Grass)
		end
	end
	for _ = 1, 140 do
		local at = Vector3.new(
			random:NextNumber(-HORIZON, HORIZON),
			0,
			random:NextNumber(-HORIZON, HORIZON)
		)
		-- Par endroits des collines hautes, ailleurs presque rien : un bruit
		-- doux module leur taille, pour qu'elles ne fassent pas un anneau.
		local patch = math.noise(at.X / 260, at.Z / 260, 0.37) + 0.5
		if math.max(math.abs(at.X), math.abs(at.Z)) > FIELD + 40 and patch > 0.15 then
			local radius = random:NextNumber(40, 125) * math.clamp(patch * 1.4, 0.4, 1.3)
			terrain:FillBall(
				at - Vector3.new(0, radius * random:NextNumber(0.45, 0.7), 0),
				radius,
				if random:NextNumber() < 0.7 then Enum.Material.Grass else Enum.Material.LeafyGrass
			)
		end
	end
	task.wait()

	-- Les arbres, poses sur le sol (bosses comprises) : en bosquets dans la
	-- campagne, en foret au-dela.
	local groundRay = RaycastParams.new()
	groundRay.FilterType = Enum.RaycastFilterType.Include
	groundRay.FilterDescendantsInstances = { terrain }
	local function groundAt(x: number, z: number): Vector3?
		local hit = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -500, 0), groundRay)
		return hit and hit.Position
	end
	for g = 1, 22 do
		local center =
			Vector3.new(random:NextNumber(-FIELD, FIELD), 0, random:NextNumber(-FIELD, FIELD))
		if inCountry(center.X, center.Z, 20) and clear(center, 40) then
			for _ = 1, random:NextInteger(3, 7) do
				local x, z =
					center.X + random:NextNumber(-22, 22), center.Z + random:NextNumber(-22, 22)
				local ground = groundAt(x, z)
				if ground then
					tree(nature, ground - Vector3.new(0, 0.5, 0), random:NextNumber() < 0.2)
				end
			end
		end
		if g % 6 == 0 then
			task.wait()
		end
	end
	for n = 1, 190 do
		local x, z =
			random:NextNumber(-HORIZON + 80, HORIZON - 80),
			random:NextNumber(-HORIZON + 80, HORIZON - 80)
		if math.max(math.abs(x), math.abs(z)) > FIELD + 20 then
			local ground = groundAt(x, z)
			if ground then
				tree(country, ground - Vector3.new(0, 0.5, 0), random:NextNumber() < 0.25)
			end
		end
		if n % 30 == 0 then
			task.wait()
		end
	end

	-- Les epaves le long des chemins (a fouiller), et des cachettes fragiles
	-- un peu partout sur le plat.
	for i = 1, 8 do
		local t = tracks[random:NextInteger(1, #tracks)]
		local at = t.a:Lerp(t.b, random:NextNumber(0.15, 0.85))
		local dir = (t.b - t.a).Unit
		local wreckCf = CFrame.lookAt(
			at + Vector3.new(0, 0.4, 0) + Vector3.new(-dir.Z, 0, dir.X) * 8,
			at + Vector3.new(0, 0.4, 0) + Vector3.new(-dir.Z, 0, dir.X) * 8 + dir
		) * CFrame.Angles(0, random:NextNumber(-0.5, 0.5), 0)
		local carModel = car(country, wreckCf, CAR_COLORS[random:NextInteger(1, #CAR_COLORS)], true)
		carModel.Name = "EpaveCampagne" .. i
		local glove = P(
			containers,
			"EpaveCampagne" .. i .. "_BoiteAGants",
			Vector3.new(2, 1, 1.4),
			wreckCf * CFrame.new(1.2, 3.2, -2.4),
			Enum.Material.SmoothPlastic,
			C.black,
			{ transparency = 1, collide = false }
		)
		glove:SetAttribute("Table", "voiture")
	end
	local placedSpots = 0
	for _ = 1, 400 do
		if placedSpots >= 30 then
			break
		end
		local x, z = random:NextNumber(-FIELD, FIELD), random:NextNumber(-FIELD, FIELD)
		local ground = groundAt(x, z)
		if ground and math.abs(ground.Y) < 0.6 and inCountry(x, z, 10) and clear(ground, 30) then
			local kinds = { "Abri", "Caisses", "Benne", "Voiture", "Buisson", "Buisson", "Tole" }
			anchor(
				kinds[random:NextInteger(1, #kinds)],
				CFrame.new(x, 0, z) * CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0)
			)
			placedSpots += 1
		end
	end
	task.wait()

	-- Murs invisibles : au bord de la campagne, au pied des collines.
	for _, w in
		{
			{ Vector3.new(4, 60, FIELD * 2 + 40), Vector3.new(-FIELD - 12, 30, 0) },
			{ Vector3.new(4, 60, FIELD * 2 + 40), Vector3.new(FIELD + 12, 30, 0) },
			{ Vector3.new(FIELD * 2 + 40, 60, 4), Vector3.new(0, 30, -FIELD - 12) },
			{ Vector3.new(FIELD * 2 + 40, 60, 4), Vector3.new(0, 30, FIELD + 12) },
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

	-- Les cachettes solides : des buses de beton couchees, dans la bande
	-- centrale et au bout des rues nord-sud.
	for i, at in
		{
			-- A cote de la superette et du terrain de basket, et dans le
			-- rideau d'arbres au-dela du chemin du bord.
			CFrame.new(SUPERETTE_X, 1.6, 44),
			CFrame.new(BASKET_X, 1.6, -38),
			CFrame.new(-300, 1.6, OUTER_ROAD + 13),
			CFrame.new(60, 1.6, OUTER_ROAD + 13),
			CFrame.new(-60, 1.6, -OUTER_ROAD - 13),
			CFrame.new(300, 1.6, -OUTER_ROAD - 13),
		}
	do
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

	local prefabs = folder(ServerStorage, CONTRACT.prefabs)
	buildPrefabs(prefabs)
	task.wait()

	-- La cave : derriere la ferme (dont la facade regarde le nord, le jardin
	-- est au sud).
	local spawnAt = buildPlanque(root, terrain, PLANQUE_AT.X, PLANQUE_AT.Z - HOUSE_D - 8)
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
		-- Une maison au toit perce peut couvrir son salon par endroits (un
		-- chevron, l'etage) : seule une maison intacte DOIT couvrir. Une ruine
		-- ne doit pas couvrir... quand l'Oeil la voit presque d'en haut. Plus
		-- loin du centre, il regarde en biais et ses murs protegent : c'est vrai
		-- en jeu aussi (vu a la mesure, les fermes de la campagne).
		local flat = Vector3.new(entry.at.X, 0, entry.at.Z).Magnitude
		local steep = flat < EYE_HEIGHT * 0.4
		-- De meme, tres en biais, l'Oeil peut voir un salon intact par une
		-- fenetre (vu a la mesure : une ferme a etage au bord de la carte).
		-- C'est une vraie ligne de vue : on ne l'exige qu'a la verticale.
		local wrong = (entry.covered and not ok and steep) or (entry.ruin and ok and steep)
		if wrong then
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
	local streetHit = workspace:Raycast(Vector3.new(-120, 50, -170), Vector3.new(0, -100, 0))
	-- La sonde peut tomber sur le marquage, qui est pose SUR la rue : il
	-- compte aussi comme « la rue se voit ».
	local streetOk = streetHit ~= nil
		and (streetHit.Instance.Name == "RueEstOuest" or streetHit.Instance.Name == "Marquage")
	table.insert(report, "La rue est visible au-dessus du terrain : " .. tostring(streetOk))
	if not streetOk then
		problems += 1
	end
	table.insert(
		report,
		string.format("%d emplacements, %d bloqués", #anchors:GetChildren(), blocked)
	)
	table.insert(report, string.format("%d contenants à fouiller", #containers:GetChildren()))
	table.insert(
		report,
		string.format("%d voitures générées (%d modèles)", generatedCars, #carTemplates)
	)
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
