--!strict
--[[
	Story — la quete principale de la Banlieue, « La voix dans la radio »
	(decidee avec Josh, CONCEPT 12). Des donnees seulement : le texte de chaque
	etape, l'evenement du jeu qui la reussit, et ce que Mara dit la nuit
	suivante. Les jours (quand une etape peut s'ouvrir) sont dans
	Config.story.

	Les etapes 3 a 5 (le survivant, le fumigene, le repaire) arrivent une par
	une ; tant qu'elles n'existent pas, l'histoire s'arrete apres la 2.
]]

export type Step = {
	id: string,
	-- L'evenement qui la reussit (envoye par les services du jeu).
	event: string,
	objective: string,
	-- Ce que Mara dit, la nuit suivant la reussite.
	report: { string },
}

local Story: { Step } = {
	{
		id = "poste",
		event = "built:radio",
		objective = "Réparer la radio de la Planque : il lui manque une lampe. L'atelier de la station-service, peut-être ?",
		report = {
			"… crrr … Il y a quelqu'un ? … Si vous m'entendez, ne répondez pas tout de suite.",
			"Je m'appelle Mara. Je ne peux pas dire d'où je parle. Il écoute peut-être.",
			"Votre signal est trop faible. Il faudrait une antenne, très haut. Le château d'eau, au nord.",
			"L'un de vous devra rester près de la radio pour la régler pendant qu'un autre pose l'antenne là-haut.",
			"Il y en avait une sur le clocher de l'église. Je rappellerai demain soir.",
		},
	},
	{
		id = "signal",
		event = "relay",
		objective = "Prendre l'antenne de l'église et la poser en haut du château d'eau, pendant qu'un autre règle la radio à la Planque.",
		report = {
			"Je vous entends ! Clairement, enfin.",
			"Écoutez. Il y a quelqu'un d'autre en ville. Un homme. Il appelle à l'aide sur une autre fréquence depuis trois jours.",
			"Il est blessé, il n'ose plus sortir. Je vais essayer de savoir où il se cache.",
			"Tenez bon. Je rappelle dès que j'ai quelque chose.",
		},
	},
}

return Story
