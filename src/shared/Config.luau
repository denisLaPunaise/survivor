--!strict
--[[
	Config — tous les chiffres reglables du jeu, a un seul endroit.

	Regle absolue du projet : aucun de ces nombres n'est ecrit en dur ailleurs
	dans le code, et aucun repli cache (`or 1`) ne le remplace en silence. Ils
	seront modifies des dizaines de fois pendant les tests, et il faut pouvoir
	en changer un sans ouvrir un seul module de logique.

	Chaque valeur porte la raison de sa valeur. « A REGLER » marque un point de
	depart a valider en jouant.

	Ce module ne requiert rien et ne touche a aucune API Roblox : il se charge
	aussi bien dans Studio que dans les tests Lune.

	UNE TABLE N'ENTRE ICI QUE LE JOUR OU UN SERVICE L'EXECUTE. La panne la plus
	chere d'Arena etait une table de Config testee mais lue par personne : le
	jeu annoncait une regle qui ne s'appliquait pas. La duree des jours, l'Oeil
	et les ameliorations arriveront avec leur service, pas avant.
]]

local Config = {}

-- Numero de version du reglage, affiche au demarrage. A incrementer quand on
-- change un chiffre qui modifie l'equilibrage, pour savoir de quoi on parle
-- quand on compare deux sessions de test.
Config.version = 1

--------------------------------------------------------------------------------
-- RESEAU
--------------------------------------------------------------------------------

Config.network = {
	-- Le garde-fou contre l'inondation, repris d'Arena ou il a ete regle : une
	-- rafale de 8 laisse passer un double clic et les deux messages d'un meme
	-- geste ; 4 par seconde tenus, c'est plus qu'aucun humain a la manette.
	remoteThrottle = {
		burst = 8,
		perSecond = 4,
	},
}

--------------------------------------------------------------------------------
-- LA VILLE — le contrat de nommage entre le code et la place
--------------------------------------------------------------------------------

-- Seule interface entre le code et ce qui est construit dans Studio. Le
-- serveur verifie ces noms au demarrage et dit exactement ce qui manque.
Config.world = {
	-- Workspace.<folder> contient tout le quartier.
	folder = "Ville",
	-- Un Model : la cave de depart. Contient `spawn` et `chest`.
	planque = "Planque",
	spawn = "Depart",
	chest = "Coffre",
	-- Une part invisible qui couvre la zone que l'Oeil balaie.
	bounds = "Limites",
	-- Les cachettes solides, fixes (caves, dessous de pont).
	solidSpots = "CachettesSolides",
	-- Les emplacements possibles des cachettes fragiles : des parts portant
	-- l'attribut `Prefab` (le nom du modele a poser). Noms uniques.
	anchors = "Emplacements",
	-- Les contenants a fouiller : parts ou modeles portant l'attribut `Table`.
	containers = "Fouilles",
	-- ServerStorage.<prefabs> : les modeles de cachettes fragiles. Hors Rojo :
	-- construits par la recette de tools/.
	prefabs = "SurvivorCachettes",
	-- Dans chaque cachette (fragile ou solide) : ou l'on se tient cache, et ou
	-- l'on ressort.
	spotInside = "Interieur",
	spotExit = "Sortie",
	-- Attribut d'une part qui ne couvre qu'a moitie (buisson, grillage) :
	-- la part du regard qu'elle laisse passer, entre 0 et 1.
	coverAttribute = "Couvert",
	-- Un batiment ou l'on peut s'abriter (attribut booleen sur son Model) et
	-- les parts que l'Oeil arrache quand il vient chercher ceux qui s'y
	-- abritent : toits, plafonds, etage.
	buildingAttribute = "Batiment",
	roofAttribute = "Toiture",
	-- Workspace.<folder>.<sky> : la Fissure, l'Oeil (<eye>, un Model dont
	-- l'avant -Z regarde le sol) et les debris qu'il aspire (<debris>).
	-- Dans la Planque : l'etabli (le menu de construction) et les
	-- emplacements des constructions, une part `Slot<id>` par construction.
	workbench = "Etabli",
	slotPrefix = "Slot",
	sky = "Ciel",
	eye = "Oeil",
	debris = "Debris",
}

--------------------------------------------------------------------------------
-- LE CIEL — ce qu'on voit de l'Oeil (purement visuel, cote client)
--------------------------------------------------------------------------------

Config.sky = {
	-- L'Oeil tourne vers ce qu'il regarde : on voit ou il cherche. Une
	-- fraction par seconde du chemin restant ; 2,5 le fait suivre le faisceau
	-- sans a-coups, avec un leger retard qui le rend vivant.
	eyeTurnRate = 2.5,
	-- Entre deux Balayages il derive lentement, comme s'il cherchait.
	idleWanderSeconds = 9,
	idleWanderRadius = 140,
	-- Les debris montent vers la Fissure puis disparaissent et recommencent
	-- en bas : la ville est aspiree en continu, lentement.
	debrisRiseSpeed = 4,
	debrisSpinSpeed = 0.15,
	debrisLowest = 120,
	debrisHighest = 560,
}

--------------------------------------------------------------------------------
-- LA JOURNEE
--------------------------------------------------------------------------------

-- A REGLER. Le concept vise un jour de ~12 min ; la premiere version est plus
-- courte, pour tester la tension des Balayages sans attendre. La nuit n'existe
-- dure `nightSeconds` : les Repris tombent de la Fissure et convergent vers la
-- Planque.
Config.day = {
	sweepsPerDay = 4,
	-- Le temps de sortir de la cave et de commencer a fouiller.
	firstSweepSeconds = 45,
	-- Entre la fin d'un Balayage et le signal du suivant : assez pour fouiller
	-- une maison et changer de rue, pas assez pour tout faire.
	gapSeconds = { min = 70, max = 110 },
	-- Apres le dernier Balayage : le temps de rentrer avant la nuit.
	duskSeconds = 30,
	-- Le concept vise ~6 min ; 4 pour les premiers essais.
	nightSeconds = 240,
	-- La part des emplacements qui portent une cachette fragile chaque matin.
	-- Moins de la moitie vide les rues ; plus des trois quarts rend tout facile.
	fragileShare = 0.6,
	-- Le temps de lire « plus personne debout » avant que tout recommence.
	wipeMessageSeconds = 6,
}

--------------------------------------------------------------------------------
-- L'OEIL
--------------------------------------------------------------------------------

Config.eye = {
	-- Au-dessus du centre des Limites. Haut, pour que les toits couvrent : vu
	-- de presque a la verticale, un toit cache ce qui est dessous.
	height = 600,
	-- Les signes avant le Balayage (decide : ~10 s).
	warningSeconds = 10,
	-- Rayon du regard au sol, en studs. Un trottoir plus une voie.
	beamRadius = 16,
	-- Vitesse du regard au sol. 45 studs/s : on le voit venir, on court plus
	-- vite que lui en ligne droite (22 en sprint) seulement s'il ne vous suit
	-- pas — il ne vous suit pas.
	beamSpeed = 45,
	-- Ecart entre deux passages du rateau et deux tours de spirale. Plus de
	-- deux fois le rayon : il reste des bandes jamais touchees.
	laneSpacing = 55,
	patterns = { "line", "spiral" },
	-- Un Balayage ne couvre pas tout le quartier (800 studs : plusieurs
	-- minutes) mais une zone de ce cote, centree sur un joueur tire au hasard
	-- (decision du 5 novembre 2026). 280 : un pate de maisons et ses jardins,
	-- parcouru en ~30 s ; se disperser rend plus probable d'etre pris.
	zoneSize = 280,
	-- Les cachettes marquees que l'Oeil va arracher : celles de la zone, plus
	-- cette marge.
	inspectMargin = 60,
	-- Le temps que l'Oeil s'attarde sur une cachette marquee : il l'arrache au
	-- debut, celui qui est dedans a ce temps-la pour fuir le cercle.
	inspectSeconds = 1.6,
	-- La cachette arrachee monte vers le ciel et disparait.
	ripLiftSeconds = 2,
	ripLiftHeight = 120,
	exposure = {
		-- Plein regard pendant 2 s = aspire. Traverser le cercle par le centre
		-- (32 studs) en sprint prend ~1,45 s : on en sort a ~70 %, de justesse.
		-- A 1,4 s on y restait : le test l'a montre.
		fillSeconds = 2,
		-- Hors du regard, la jauge se vide en 3 s.
		drainSeconds = 3,
	},
	-- Le joueur aspire monte, puis disparait jusqu'au matin.
	takenLiftSeconds = 3,
	takenLiftHeight = 350,
	-- Une marque s'efface au bout de ce nombre de jours (decide : un ou deux).
	markDays = 2,
	-- Frequence des controles de ligne de vue : 10 par seconde suffisent a une
	-- jauge qui met 1,4 s a se remplir.
	checkSeconds = 0.1,
	-- Une part plus transparente que ca ne cache rien (vitres) : un rayon
	-- trouve de la geometrie, pas ce qu'on voit.
	seeThroughTransparency = 0.5,
	-- Nombre de parts transparentes ou couvrantes qu'un rayon traverse avant
	-- d'abandonner (et de considerer le joueur cache).
	maxRayHops = 8,
}

--------------------------------------------------------------------------------
-- LES REPRIS
--------------------------------------------------------------------------------

-- A REGLER : premiere version, aucun de ces chiffres n'a ete joue.
Config.repris = {
	-- Ce qui reveille un Repris endormi (le jour, dans les maisons).
	wake = {
		-- Courir pres de lui, dans la piece d'a cote : il entend.
		sprintRadius = 24,
		-- Fouiller un placard dans la meme maison.
		searchRadius = 20,
		-- Passer a le frôler, meme en marchant.
		touchRadius = 5,
	},
	-- La part des maisons intactes ou dorment des Repris chaque matin, et
	-- combien. Un quart : on ne sait jamais, mais pas a chaque porte.
	dormantHouseShare = 0.25,
	dormantPerHouse = { min = 1, max = 2 },
	-- Il abandonne une cible qu'il ne voit plus depuis ce temps : le jour il se
	-- rendort sur place, la nuit il repart rôder.
	forgetSeconds = 6,
	-- Il recalcule son chemin a cette frequence : assez pour suivre un joueur
	-- qui tourne au coin, sans saturer le serveur a trente Repris.
	thinkSeconds = 0.3,
	repathSeconds = 1,
	kinds = {
		-- L'Errant : lent, encaisse, la base. Plus lent que la marche (14).
		errant = {
			name = "Errant",
			speed = 10,
			health = 60,
			damage = 14,
			attackRange = 4.5,
			attackSeconds = 1.3,
			chaseRadius = 70,
		},
		-- Le Coureur : plus rapide que la course (22), fragile.
		coureur = {
			name = "Coureur",
			speed = 23,
			health = 30,
			damage = 9,
			attackRange = 4,
			attackSeconds = 0.9,
			chaseRadius = 90,
		},
	},
	-- La nuit : combien descendent de la Fissure.
	night = {
		base = 5,
		perNight = 2,
		perPlayer = 2,
		-- Au-dela, le serveur et la lisibilite souffrent.
		max = 30,
		runnerShareStart = 0,
		runnerSharePerNight = 0.1,
		runnerShareMax = 0.5,
	},
	-- Ils tombent du ciel a au moins cette distance de tout joueur : on les
	-- voit descendre, on a le temps de se preparer.
	spawnMinDistance = 90,
	spawnHeight = 60,
}

--------------------------------------------------------------------------------
-- LE COMBAT ET LA SANTE
--------------------------------------------------------------------------------

Config.combat = {
	-- Le pied-de-biche du depart : trois coups pour un Errant, deux pour un
	-- Coureur.
	meleeDamage = 22,
	meleeRange = 7,
	-- Un coup tous les 0,6 s : on ne peut pas tenir un groupe a distance.
	meleeSeconds = 0.6,
	-- Le coup part devant soi : cosinus de l'angle maximal (environ 50 deg).
	meleeCone = 0.64,
	playerHealth = 100,
	-- Relever un ami tombe : maintenir X pres de lui.
	reviveSeconds = 3,
	reviveDistance = 7,
	-- Relevé, on repart avec cette sante ; et a l'aube, celui que personne n'a
	-- releve se releve seul, affaibli (concept).
	reviveHealth = 35,
	dawnHealth = 30,
	-- A terre, on rampe.
	downedSpeed = 2,
}

--------------------------------------------------------------------------------
-- LA FAIM ET LA PLANQUE
--------------------------------------------------------------------------------

-- A REGLER. La faim descend de 100 a 0 en ~25 min, soit environ deux jours :
-- sauter un repas se sent, en sauter deux se paie.
Config.needs = {
	hungerMax = 100,
	hungerPerMinute = 4,
	-- Affame : on ralentit.
	hungryBelow = 30,
	hungrySpeedFactor = 0.85,
	-- Vide : on perd de la sante, jusqu'a tomber.
	starvingDamagePerSecond = 0.5,
}

Config.planque = {
	-- Est « a la Planque » celui qui est a cette distance du point de depart
	-- (la cave entiere et le haut de l'escalier).
	radius = 26,
	-- Le repas du soir, par convive : le premier plat que la reserve permet.
	menu = {
		{ conserve = 1, eau = 1 },
		{ conserve = 2 },
	},
	-- Se servir de l'etabli : a portee de bras.
	useDistance = 8,
	builds = {
		{
			id = "barricade",
			name = "Barricade de l'escalier",
			description = "Les Repris doivent la casser pour descendre.",
			cost = { planche = 3, ferraille = 2 },
			health = 300,
		},
		{
			id = "lit",
			name = "Lits de camp",
			description = "À l'aube, ceux qui ont dormi ici repartent en pleine santé.",
			cost = { tissu = 2, planche = 2 },
		},
		{
			id = "rechaud",
			name = "Réchaud",
			description = "Le repas chaud soigne aussi.",
			cost = { ferraille = 2, piles = 1 },
			heal = 30,
		},
		{
			id = "periscope",
			name = "Périscope",
			description = "Il voit le ciel rougir plus tôt.",
			cost = { plomb = 1, ferraille = 2 },
			earlySeconds = 8,
		},
		{
			id = "radio",
			name = "Radio réparée",
			description = "Elle dit de quel côté l'Œil va chercher.",
			cost = { piles = 2, cle = 1 },
		},
	},
	-- Reparer la barricade abimee.
	repairCost = { planche = 1 },
	repairAmount = 120,
}

--------------------------------------------------------------------------------
-- LES DEPLACEMENTS
--------------------------------------------------------------------------------

-- A REGLER en jouant. Vitesses en studs/s ; la marche de Roblox est a 16.
Config.movement = {
	walkSpeed = 14,
	sprintSpeed = 22,
	crouchSpeed = 7,
	-- La camera descend quand on s'accroupit : c'est ce qui se sent.
	crouchCameraOffset = -1.6,
	-- La glissade : un elan dans la direction de la course, accroupi.
	slideSpeed = 34,
	slideSeconds = 0.6,
	slideCooldownSeconds = 1.2,
}

--------------------------------------------------------------------------------
-- LA FOUILLE ET LE SAC
--------------------------------------------------------------------------------

Config.items = {
	conserve = { name = "Conserve", weight = 1 },
	eau = { name = "Bouteille d'eau", weight = 1 },
	piles = { name = "Piles", weight = 0.5 },
	ferraille = { name = "Ferraille", weight = 2 },
	planche = { name = "Planche", weight = 2 },
	plomb = { name = "Plaque de plomb", weight = 3 },
	corde = { name = "Corde", weight = 1 },
	cle = { name = "Clé à molette", weight = 1.5 },
	tissu = { name = "Tissu", weight = 0.5 },
	bandage = { name = "Bandage", weight = 0.5 },
	medicaments = { name = "Médicaments", weight = 0.5 },
}

Config.loot = {
	-- Maintenir X : assez long pour qu'on hesite a fouiller quand le ciel
	-- rougit, assez court pour ne pas lasser.
	searchSeconds = 1.6,
	promptDistance = 7,
	hidePromptDistance = 6,
	-- Chaque matin, un contenant deja fouille a cette chance de se remplir :
	-- le butin revient un peu, le meilleur est toujours plus loin.
	restockChance = 0.35,
	tables = {
		cuisine = {
			rolls = { min = 1, max = 3 },
			entries = {
				{ item = "conserve", weight = 5 },
				{ item = "eau", weight = 4 },
				{ item = "piles", weight = 1 },
			},
		},
		garage = {
			rolls = { min = 1, max = 3 },
			entries = {
				{ item = "ferraille", weight = 4 },
				{ item = "planche", weight = 3 },
				{ item = "corde", weight = 2 },
				{ item = "cle", weight = 1 },
				{ item = "plomb", weight = 1 },
			},
		},
		salleDeBain = {
			rolls = { min = 1, max = 2 },
			entries = {
				{ item = "bandage", weight = 4 },
				{ item = "tissu", weight = 3 },
				{ item = "medicaments", weight = 2 },
			},
		},
		-- L'armoire d'une chambre : du tissu, de quoi se soigner.
		chambre = {
			rolls = { min = 1, max = 2 },
			entries = {
				{ item = "tissu", weight = 4 },
				{ item = "bandage", weight = 2 },
				{ item = "piles", weight = 2 },
				{ item = "medicaments", weight = 1 },
			},
		},
		-- La superette du centre : de quoi manger, mais tout le monde y pense.
		superette = {
			rolls = { min = 1, max = 3 },
			entries = {
				{ item = "conserve", weight = 5 },
				{ item = "eau", weight = 5 },
				{ item = "piles", weight = 2 },
				{ item = "bandage", weight = 1 },
			},
		},
		voiture = {
			rolls = { min = 1, max = 2 },
			entries = {
				{ item = "piles", weight = 3 },
				{ item = "ferraille", weight = 2 },
				{ item = "eau", weight = 2 },
				{ item = "tissu", weight = 1 },
			},
		},
	},
}

Config.bag = {
	slots = 8,
	-- Jusqu'a 6 de poids on court normalement ; a 14 on avance a 60 %.
	freeWeight = 6,
	maxWeight = 14,
	slowestFactor = 0.6,
}

--------------------------------------------------------------------------------
-- LES COMMANDES — la manette decide
--------------------------------------------------------------------------------

-- Decide avec Josh le 5 novembre 2026 : le jeu se concoit a la manette. Si une
-- action ne rentre pas dans ces boutons, on la sacrifie. Le clavier n'est
-- qu'un miroir pour les amis qui jouent au clavier.
--
-- Un test verifie que dans un meme contexte aucun bouton ni aucune touche ne
-- porte deux actions, et que seuls les boutons libres ci-dessous sont utilises.
Config.controls = {
	-- Les boutons qu'un jeu peut prendre. ButtonStart ouvre le menu de Roblox
	-- et ButtonSelect bascule la navigation dans les panneaux : les deux sont
	-- a Roblox, pas a nous. Les sticks bougent et regardent ; les ENFONCER
	-- (L3, R3) reste a nous.
	gamepadButtons = {
		"ButtonA",
		"ButtonB",
		"ButtonX",
		"ButtonY",
		"ButtonL1",
		"ButtonR1",
		"ButtonL2",
		"ButtonR2",
		"ButtonL3",
		"ButtonR3",
		"DPadUp",
		"DPadDown",
		"DPadLeft",
		"DPadRight",
	},

	-- Un contexte = ce qu'on fait a ce moment-la. Le meme bouton peut changer
	-- de sens d'un contexte a l'autre (X fouille a pied, X sort de la
	-- cachette), jamais dans le meme. A REGLER en jouant : c'est la
	-- proposition faite a Josh, pas encore tenue en main.
	contexts = {
		onFoot = {
			jump = { gamepad = "ButtonA", keyboard = "Space" },
			-- Contextuel : en courant on glisse, a l'arret on s'accroupit.
			crouchOrSlide = { gamepad = "ButtonB", keyboard = "C" },
			-- Fouiller, ramasser, ouvrir, entrer dans une cachette.
			interact = { gamepad = "ButtonX", keyboard = "E" },
			bag = { gamepad = "ButtonY", keyboard = "Tab" },
			previousItem = { gamepad = "ButtonL1", keyboard = "Q" },
			nextItem = { gamepad = "ButtonR1", keyboard = "R" },
			aimOrThrow = { gamepad = "ButtonL2", keyboard = "MouseButton2" },
			useOrHit = { gamepad = "ButtonR2", keyboard = "MouseButton1" },
			sprint = { gamepad = "ButtonL3", keyboard = "LeftShift" },
			signalDanger = { gamepad = "DPadUp", keyboard = "Z" },
			signalHere = { gamepad = "DPadDown", keyboard = "X" },
			build = { gamepad = "DPadLeft", keyboard = "B" },
			levelUp = { gamepad = "DPadRight", keyboard = "N" },
		},
		hidden = {
			leave = { gamepad = "ButtonX", keyboard = "E" },
			holdBreath = { gamepad = "ButtonR2", keyboard = "MouseButton1" },
			signalDanger = { gamepad = "DPadUp", keyboard = "Z" },
			signalHere = { gamepad = "DPadDown", keyboard = "X" },
		},
		building = {
			place = { gamepad = "ButtonR2", keyboard = "MouseButton1" },
			rotate = { gamepad = "ButtonX", keyboard = "R" },
			cancel = { gamepad = "ButtonB", keyboard = "Backspace" },
			previousCategory = { gamepad = "ButtonL1", keyboard = "Q" },
			nextCategory = { gamepad = "ButtonR1", keyboard = "E" },
			previousPiece = { gamepad = "DPadUp", keyboard = "Up" },
			nextPiece = { gamepad = "DPadDown", keyboard = "Down" },
			leave = { gamepad = "DPadLeft", keyboard = "B" },
		},
	},
}

return Config
