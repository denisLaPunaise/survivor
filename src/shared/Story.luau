--!strict
--[[
	Story — la quete principale de la Banlieue, « La voix dans la radio »
	(decidee avec Josh, CONCEPT 12). Des donnees seulement : le texte de chaque
	etape, l'evenement du jeu qui la reussit, et ce que Mara dit la nuit
	suivante. Les jours (quand une etape peut s'ouvrir) sont dans
	Config.story.

	L'etape 5 (le repaire) n'existe pas encore : l'histoire s'arrete apres
	la 4.

	Les trous `{cle}` sont remplis par le jeu (Quest.fill) : `{nom}` le nom du
	survivant, `{indice}` ou il se cache dans cette partie.
]]

export type Step = {
	id: string,
	-- L'evenement qui la reussit (envoye par les services du jeu).
	event: string,
	objective: string,
	-- Ce que Mara dit, la nuit suivant la reussite.
	report: { string },
	-- Ce qu'elle dit la nuit d'avant l'ouverture, et quand il faut tout
	-- recommencer (le survivant aspire, retrouve ailleurs).
	briefing: { string }?,
	again: { string }?,
}

local Story: { Step } = {
	{
		id = "poste",
		event = "built:radio",
		objective = "Réparer la radio de la Planque : il lui manque une lampe. L'atelier de la station-service, peut-être\u{A0}?",
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
	{
		id = "survivant",
		event = "rescued",
		objective = "Trouver {nom} grâce aux indices de Mara (journal : Y, puis R1) et le ramener à la Planque. Il boite : cachez-le quand le ciel rougit.",
		briefing = {
			"… crrr … C'est Mara. Je l'ai eu, enfin, sur sa fréquence.",
			"Il s'appelle {nom}. Il a la jambe abîmée, il ne peut plus courir.",
			"Il dit qu'il se cache {indice}.",
			"Allez le chercher demain. Quand le ciel rougira, cachez-le d'abord : il ne pourra pas fuir.",
		},
		again = {
			"… crrr … Mara. Vous l'avez vu ? L'Œil a pris {nom}.",
			"… Attendez. Je l'entends. Il l'a recraché, loin. Il est vivant.",
			"Il dit qu'il se cache {indice}.",
			"Retournez le chercher demain. Ne le laissez plus à découvert.",
		},
		report = {
			"{nom} est avec vous ? … Merci. Merci.",
			"Il me dit qu'il était chimiste, avant. Il sait faire une fumée épaisse, qui aveugle.",
			"Avec ce qu'il y a à la supérette, il pourrait vous en fabriquer. Écoutez-le.",
			"Mais il faudra le nourrir, comme vous. Gardez de quoi manger dans la réserve.",
		},
	},
	{
		id = "fumigene",
		event = "thrown:fumigene",
		objective = "Déposer au coffre des produits chimiques (la réserve, au fond de la supérette) et de la ferraille : la nuit, {nom} en fera des fumigènes. Puis en lancer un (L2).",
		briefing = {
			"… crrr … Mara. {nom} m'a dicté sa liste.",
			"Des produits chimiques : il y en a dans la réserve de la supérette, la pièce du fond, derrière les rayons.",
			"Et de la ferraille, pour l'enveloppe. Déposez tout au coffre de la Planque.",
			"S'il a mangé, il travaillera la nuit. Au matin, demandez-lui ses fumigènes.",
			"Il dit que l'Œil ne voit pas à travers la fumée. Mais qu'il attend, autour, que ça se dissipe.",
		},
		report = {
			"Je l'ai vu d'ici, je crois. Une tache grise, et son regard qui tournait autour, perdu.",
			"Il cherche encore un moment, puis il abandonne. Ne sortez pas trop tôt.",
			"Il y a autre chose. La route qui sort de la ville… quelque chose s'y est installé.",
			"J'essaie d'en savoir plus. Gardez vos fumigènes.",
		},
	},
}

return Story
