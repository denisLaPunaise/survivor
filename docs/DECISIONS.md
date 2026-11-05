# Décisions prises sans Josh

Ce que l'assistant a tranché seul, avec la raison. Josh peut revenir sur
n'importe laquelle.

## 5 novembre 2026 — montage du projet

- **Pas de Wally.** Arena l'avait déclaré sans aucune dépendance. On l'ajoutera
  le jour où un paquet remplace du code qu'on aurait écrit soi-même.
- **Mêmes versions d'outils qu'Arena** (Rojo 7.7.1, StyLua 2.6.0,
  Selene 0.32.0, Lune 0.11.1) : un seul jeu d'outils pour tous les projets.
- **Nom des dossiers dans Studio : `Survivor`**, comme le dépôt, plutôt que le
  titre de travail « Sous le Regard », qui peut encore changer.
- **Les boutons de la manette sont fixés dans `Config.controls` avant le
  code**, avec un test anti-collision. C'est une proposition à tenir en main :
  Josh la valide en jouant.
- **Le throttle et `RemoteGuard` repris d'Arena** tels quels, avec leurs
  réglages (rafale 8, 4 par seconde).

## 5 novembre 2026 — première version jouable

- **La nuit n'existe pas encore** : après le dernier Balayage et le
  crépuscule, elle « passe » en 8 s et tout le monde se retrouve à la Planque.
  Les Repris viendront à l'étape suivante.
- **Un jour plus court que le concept** (4 Balayages, ~8 min au lieu de
  ~12) pour tester la tension sans attendre. Réglable dans `Config.day`.
- **Plein regard pendant 2 s = aspiré** (au lieu de 1,4 s d'abord) : le test a
  montré qu'à 1,4 s, traverser le cercle en sprint suffisait à être aspiré, ce
  qui contredisait « traverser une rue en courant passe ».
- **Un joueur aspiré revient au matin**, à un emplacement de cachette pris au
  hasard (la version courte de « revient la nuit suivante, à aller chercher »).
- **Caché, le joueur est ancré dans la cachette** et l'Œil ne le vérifie pas :
  la cachette intacte le couvre par construction. Il ne redevient visible que
  si elle est arrachée.
- **Une cachette est marquée dès qu'on y entre**, mais l'Œil ne vient la
  vérifier qu'au Balayage suivant, jamais pendant celui où l'on s'y cache.
- **Fouiller, se cacher et déposer passent par les invites de Roblox**
  (`ProximityPrompt`) : elles affichent toutes seules le bon bouton de manette
  et la jauge de maintien. Boutons lus dans `Config.controls`.
- **La course se bascule à la manette** (L3 une fois pour courir, une fois
  pour marcher) et se maintient au clavier : L3 se tient mal en bougeant le
  stick.
- **Le quartier mesure 300 × 230 studs** pour cette première version (le
  concept vise ~1000 × 1000) : un carrefour, huit parcelles.
- **`Lighting.Technology` ne se règle pas depuis le pont MCP** (ni en lecture
  ni en écriture) : à passer sur *Future* à la main dans la place.

## 5 novembre 2026 — première passe visuelle

- **L'Œil suit le regard, côté client seulement** (`SkyView`) : c'est un
  signe de plus, purement visuel, que le serveur n'a pas à connaître.
- **La ville est aspirée en continu** : des débris montent lentement vers la
  Fissure et s'effacent près d'elle. Idée de l'assistant, pas du concept.
- **Arbres générés** (`docs/ASSETS.md`) : l'arbre feuillu est gardé, l'arbre
  mort généré est refusé (tronc bleu de dessin animé).
- **Ciel couvert à 92 %** : les trouées bleues disaient « beau temps ».

## 5 novembre 2026 — la Banlieue en grand

- **Où regarde l'Œil** (Josh : « fais comme tu le sens ») : chaque Balayage
  couvre une zone de 280 × 280 studs **centrée sur un joueur encore debout,
  tiré au hasard**. Il reste menaçant où que l'on soit, et se disperser rend
  plus probable d'être pris. L'Œil n'arrache que les cachettes marquées de sa
  zone (plus 60 studs). Réglable dans `Config.eye`.
- **800 × 640 studs** (Josh avait choisi ~800 × 800 ; 640 de profondeur suffit
  à quatre rangées de maisons et une bande centrale).
- **Le plan** : deux rues est-ouest bordées de maisons, trois rues nord-sud,
  39 maisons et un terrain vide, une bande centrale avec une supérette (son
  propre butin), un terrain de basket grillagé et des terrains vagues.
- **Des maisons à étage** (environ 40 % des intactes) : l'étage n'est pas
  accessible, il sert à la silhouette et couvre le rez-de-chaussée.
- **Les voitures sont générées** (deux modèles, `docs/ASSETS.md`) : chaque
  emplacement de voiture tire l'un des deux.
- **Le lointain** : le terrain s'étend loin au-delà des barricades, avec des
  silhouettes sombres de maisons et d'arbres dans la brume.

## 5 novembre 2026 — un quartier rempli

Josh a vu juste : l'agrandissement avait étalé les mêmes maisons dans des
pelouses vides. Le quartier passe à **800 × 800** et à **75 maisons** :

- deux rangées qui se font face de part et d'autre d'une **allée piétonne**
  au centre, autour de la supérette et du terrain de basket (pas de garage :
  l'allée est trop étroite) ;
- deux rangées au bord, tournées vers un **chemin de terre**, dos aux jardins
  de la rue voisine, avec un rideau d'arbres derrière ;
- des **jardins habités** : balançoire, piscine vide, étendoir, table de
  jardin, potager, niche et jouets ;
- les terrains vagues du centre ont disparu au profit des maisons ;
- le lointain est plus dense et plus proche.

## 5 novembre 2026 — les points 1 à 4 (validés par Josh)

Josh a validé l'ordre et les idées ; ce qui suit précise ce que l'assistant a
tranché pour les mettre en place.

**1. L'Œil arrache les toits.** S'abriter dans un bâtiment (maison au toit
entier, supérette, église, station-service) pendant un Balayage le marque. Au
Balayage suivant, si le bâtiment est dans la zone, l'Œil arrache sa toiture :
toits, plafonds et tout l'étage. Le toit arraché ne revient pas de la partie :
le quartier s'abîme jour après jour. La cave de la Planque et les buses restent
sûres.

**2. Les Repris.**
- Le jour, ils dorment dans un quart des maisons (1 ou 2 par maison) et se
  réveillent si l'on court (à moins de 24 studs), fouille (20) ou les frôle (5).
  Réveillés par un bruit, ils vont voir d'où il vient ; s'ils ne voient
  personne pendant 6 s, ils se rendorment là où ils sont.
- La nuit (4 min pour l'instant, le concept en vise 6), ils tombent de la
  Fissure, loin des joueurs, et convergent vers la Planque. Leur nombre monte
  chaque nuit et avec le nombre de joueurs ; les Coureurs arrivent à partir de
  la deuxième nuit.
- Deux types pour commencer : l'Errant (lent, plus lent que la marche) et le
  Coureur (plus rapide que la course, fragile).
- Le combat : R2 frappe avec le pied-de-biche (3 coups pour un Errant). On ne
  meurt pas : on tombe, on rampe, un ami relève en maintenant X (3 s) ; sinon
  on se relève seul à l'aube, affaibli. Tombé compte comme « pas debout » pour
  la défaite.
- La nuit, chacun porte une petite lumière, vue de tous.

**3. La faim et la Planque.**
- La faim descend en ~25 min (environ deux jours). Affamé, on ralentit ; vide,
  on perd de la santé.
- **Le repas du soir** plutôt que manger dans un menu : à la tombée de la nuit,
  ceux qui sont rentrés à la Planque mangent sur la réserve commune (une
  conserve et une eau, ou deux conserves). Manger dans un menu à la manette,
  au milieu des Balayages, aurait été une corvée.
- **L'établi** de la cave ouvre un panneau (à la manette : A construit, B
  ferme). Cinq constructions pour commencer, posées à des emplacements fixes
  de la cave (la construction libre sur grille du concept viendra ensuite) :
  la barricade de l'escalier (les Repris doivent la casser, on la répare), les
  lits (soignent à l'aube), le réchaud (le repas soigne), le périscope (8 s de
  préavis en plus), la radio (dit vers quel joueur l'Œil va chercher).

**4. La variété.**
- Quatre intérieurs : le plan d'origine, son miroir, et chacun avec une
  chambre (lit et armoire à fouiller, nouveau butin « chambre ») à la place de
  la salle à manger.
- Des maisons qui racontent : barricadées de l'intérieur (~10 %), brûlées
  (~8 %), ou avec un mot écrit au mur (~14 %). Les mots sont des bribes, sans
  explication.
- Trois repères : l'église au centre (clocher), la station-service au
  nord-ouest, le château d'eau au nord, plus haut que tout.
