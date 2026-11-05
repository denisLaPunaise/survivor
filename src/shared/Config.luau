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

	UNE EXCEPTION, ASSUMEE ET A FERMER : `controls`. C'est le contrat de boutons
	fixe avec Josh avant le code, pour que la manette guide la conception. Aucun
	module ne le lit encore ; le module d'entrees de la premiere version doit le
	lire, et ce paragraphe doit alors disparaitre.
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
