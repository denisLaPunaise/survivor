--!strict
--[[
	Memories — les souvenirs laisses dans le Ventre de l'Oeil par ceux qu'il a
	aspires avant nous. On les trouve en attendant d'etre recrache ; ils
	s'ajoutent au journal. Ils racontent, par bribes, ce que deviennent les
	aspires et ce que l'Oeil cherche (CONCEPT 2 : ce qu'il cherche est sous la
	Planque).

	Des donnees seulement. L'identifiant de chaque souvenir est celui que porte
	sa part dans la recette (attribut `Souvenir`).
]]

export type Memory = {
	id: number,
	title: string,
	lines: { string },
}

local Memories: { Memory } = {
	{
		id = 1,
		title = "Un ticket de bus",
		lines = {
			"Ligne 12, le 3 mars. Le jour où le ciel s'est ouvert.",
			"Je ne suis jamais descendu à mon arrêt.",
		},
	},
	{
		id = 2,
		title = "Une lettre pliée en quatre",
		lines = {
			"Maman, si quelqu'un te rapporte ceci : ici, il ne fait ni jour ni nuit.",
			"On entend la ville en bas, comme sous l'eau. Le soir, il nous laisse tomber.",
		},
	},
	{
		id = 3,
		title = "Une photo de classe",
		lines = {
			"Une classe entière, souriante. Au dos, au crayon :",
			"« Ils redescendent le soir. Ils ne nous reconnaissent plus. »",
		},
	},
	{
		id = 4,
		title = "Un carnet de chantier",
		lines = {
			"Jour 40. Il ne mange pas ce qu'il prend. Il le garde, puis il le rend.",
			"Il cherche quelque chose. Ce n'est pas nous.",
		},
	},
	{
		id = 5,
		title = "Une clé de voiture",
		lines = {
			"Sur le porte-clés, gravé avec un clou : « Retiens ton souffle. »",
		},
	},
	{
		id = 6,
		title = "Un dessin d'enfant",
		lines = {
			"Un grand œil dans le ciel, une petite maison, et sous la maison, une étoile qui brille.",
			"Signé : Léo, 7 ans.",
		},
	},
}

return Memories
