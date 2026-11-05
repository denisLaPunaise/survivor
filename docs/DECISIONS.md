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

## 5 novembre 2026 — après les retours de Josh

- **L'arrachage des toits** : la toiture tremble une seconde (on est encore
  couvert, c'est le signal pour fuir), puis chaque morceau part à son tour en
  tournoyant, dans un nuage de poussière. Partent avec le toit : les
  plafonds, l'étage, **le haut des murs au-dessus des fenêtres** (le mur reste
  déchiqueté), et les objets légers de l'intérieur (chaises, papiers, tapis,
  fauteuil, télé, bancs de l'église, produits de la supérette). Les murs
  entiers restent : les arracher ne changerait presque rien au regard, qui
  vient d'en haut, et viderait le quartier trop vite.
- **Les Repris un peu partout** : en plus des maisons, **une cachette fragile
  sur douze est déjà occupée** (on l'ouvre, un Repris en sort, on reste
  dehors), et **dix Repris debout dehors**, immobiles dans les rues et les
  jardins, jamais près de la Planque. Tout est retiré au hasard chaque matin.
- **Manger depuis son sac** (Josh : « c'est intéressant de devoir garder de
  quoi manger ») : Y ouvre le sac, A mange ou utilise. Conserve +40 de faim,
  eau +25, bandage +25 de santé, médicaments +50. Le repas automatique du
  soir est supprimé ; à la Planque, une **table** permet de manger sur la
  réserve (avec le réchaud, le repas soigne).
- **Au clavier, le sac est sur I** : Tab est gardé par Roblox pour la liste
  des joueurs (vu en jeu, la touche n'arrivait jamais).
- **Le lointain** : les silhouettes en boîtes (« moches », Josh) sont
  remplacées par **des collines boisées** tout autour.
- **L'allure des Repris** : plus grands, maigres, couleur cendre, peau de
  basalte, deux petits yeux pâles, une fumée sombre ; le visage souriant par
  défaut de Roblox est retiré. Ils gardent la silhouette carrée d'un
  personnage Roblox : un vrai modèle de créature reste à faire.
- **La nuit** est éclaircie (lune, ambiance bleutée) : à la première version,
  l'écran était presque noir.

## 5 novembre 2026 — la campagne, et des Repris qui augmentent le jour

- **La zone jouable passe à 1400 × 1400** : la ville (800 × 800) au centre et
  une **campagne** autour, à la place de l'anneau de collines (« bizarre »,
  « vide », Josh). Dans la campagne : une boucle de chemin de terre et quatre
  chemins qui y mènent, **27 fermes isolées** abandonnées (plus souvent en
  ruine qu'en ville), des bosses et quelques collines au hasard, des
  bosquets, des épaves à fouiller, une trentaine de cachettes fragiles. Les
  grandes collines et la forêt ferment l'horizon au-delà, placées au hasard.
- **L'Œil voit la campagne en biais** : il est au-dessus du centre, donc loin
  de la ville il regarde de côté, et les murs protègent davantage (même une
  ruine sans toit). La campagne est plus sûre face à l'Œil ; elle est plus
  loin de la Planque, et les Repris y sont aussi. À surveiller en jouant.
- **Le jour, les Repris augmentent avec les jours** (ils n'augmentaient que la
  nuit) : un quart des maisons le premier jour puis +3 % par jour (la moitié
  au plus) ; une cachette sur douze occupée puis +1 % par jour (une sur cinq
  au plus) ; 16 debout dehors puis +3 par jour (40 au plus).

## 5 novembre 2026 — l'Œil qui traque, la Planque à l'écart, une carte moins régulière

- **L'Œil traque** (Josh : « des zigzags au début, c'est un peu nul ») : il
  vise la zone d'un joueur avec une erreur qui diminue chaque jour (110 studs
  le premier jour, 15 au mieux). Dès qu'il voit quelqu'un, il **fonce sur
  lui** ; s'il le perd de vue, il garde sa piste un moment (1 s le premier
  jour, jusqu'à 3,5 s), puis reprend son trajet là où il l'avait laissé. Un
  Balayage dure au plus 75 s, poursuites comprises.
- **Sa vitesse de poursuite** : 9 le premier jour (moins que la marche, 14),
  +1,5 par jour, plus rapide que la course (22) vers le jour 10. D'abord
  réglée à 15 : en jeu, un joueur frôlé puis qui courait était aspiré quand
  même. À 9, on s'échappe en courant **même depuis le centre** du regard
  (vérifié en jeu, jauge montée à 0,89 sur 1).
- **Loin du centre, le regard arrive de biais** et sa tache au sol s'allonge
  vers l'extérieur (environ 25 studs au lieu de 16 au bout de la carte). En
  fuyant dans ce sens-là, on reste plus longtemps dedans : il vaut mieux fuir
  sur le côté. C'est la vraie ligne de vue (l'Œil ne triche pas), gardé tel
  quel ; à juger en jouant.
- **Les courbes par jour** sont rangées dans un seul module, `Growth`
  (début, pas par jour, plafond), pour les Repris comme pour l'Œil.
- **La Planque est une ferme en ruine isolée, dans le coin sud-ouest de la
  campagne** (Josh : « je croyais qu'on devait le mettre dans un coin à
  l'écart »), la cave derrière, un chemin qui y mène depuis la ville. Aucune
  ferme à moins de 160 studs.
- **La ville moins symétrique** : rues décalées, parcelles de largeurs
  inégales, maisons plus ou moins en retrait, un peu de biais, et environ une
  parcelle sur dix laissée en **terrain vague** (herbes, gravats, une épave ou
  des caisses).
- **La campagne éparpillée** (plus d'anneau de maisons ni de collines) : des
  chemins de terre qui serpentent au hasard depuis les sorties de la ville,
  **six hameaux** de deux à quatre fermes tournées vers leur centre et **neuf
  fermes seules**, 26 collines dedans, et des collines du bord dont la taille
  varie par endroits (certaines zones presque plates).

## 5 novembre 2026 — des petites cachettes partout

- **Les voitures s'ouvrent des deux côtés** (Josh : « que d'un côté, c'est un
  peu chiant ») : une invite par portière, et on ressort du côté par où l'on
  est entré. Toute cachette peut désormais avoir plusieurs sorties.
- **Deux nouvelles petites cachettes** (Josh : « pas de petits recoins ») :
  - le **buisson touffu** : on s'y glisse ;
  - la **tôle rouillée** appuyée sur un panneau de planches : on se tapit
    dessous.
- **Où elles sont posées** :
  - devant chaque maison, un buisson dans le coin de la haie ;
  - au fond de chaque jardin, une tôle contre la palissade ;
  - un jardin sur quatre a un buisson à la place de l'abri ;
  - les terrains vagues ont aussi des bennes ;
  - devant chaque ferme, un buisson et une tôle ;
  - la campagne en a aussi.

  On passe de 184 à 350 emplacements, et 60 % sont occupés chaque matin
  (environ 210 cachettes par jour).
- **La tôle n'est jamais contre un mur de maison** : sur le flanc, elle
  tombait devant une porte de côté (vu à l'écran) ou dans le garage d'une
  ferme (vu à la mesure).
- **La mesure de la ville** n'exige plus qu'un salon intact soit couvert
  quand l'Œil le regarde très en biais : au bord de la carte, il voit par une
  fenêtre d'étage, et c'est une vraie ligne de vue.

## 5 novembre 2026 — voir dehors, arrachages au hasard

- **Caché, on voit dehors normalement** (Josh : l'écran noir et son message
  gênaient). Il reste un rappel discret en bas (« Caché · Sortir : B ») et
  la lueur qui monte quand le regard approche.
- **Arrachages au hasard** (décidé avec Josh, option « même occupées ») : à
  chaque Balayage, l'Œil arrache sur son passage des cachettes et des toits pris
  au hasard dans sa zone :
  - jour 1 : 1,5 cachette et 0,5 toit par Balayage (le chiffre après la
    virgule est une chance) ;
  - jour 8 : 5 cachettes et 1,9 toit ;
  - au plus 6 cachettes et 2 toits.

  Les toits ne reviennent qu'à une défaite : vers le jour 10, plus de la
  moitié des 91 toits sont partis.
- **Cachette arrachée avec quelqu'un dedans** : on est éjecté devant, l'Œil
  nous poursuit, mais la jauge ne monte pas pendant **2 s de répit**, et un
  message dit « cours ! ». Le premier jour, en courant, on a 26 studs d'avance
  à la fin du répit, plus que le rayon du regard (16).
- **Un toit tremble 3,5 s** (au lieu de 1) avant de partir, et ceux qui sont
  dessous lisent « Le toit tremble : sors vite ! ».
- **Pas encore tranché, laissé à Josh** : le nombre de Balayages par jour, qui
  reste à 4. Il dépend de la progression sur les 7 quartiers, proposée dans
  `CONCEPT.md` §5 bis.

## 5 novembre 2026 — un Œil qui s'améliore à chaque quartier

- **Décidé avec Josh**, sur son idée : à chaque quartier, l'Œil gagne une
  amélioration qui monte jour après jour, et il garde toutes les précédentes.
  Chaque quartier donne au moins une parade. Le tableau est dans
  `CONCEPT.md` §5 bis ; les parades y sont encore *proposées*.
- **La Banlieue : seule la traque monte.** On reste à 4 Balayages par jour, et
  les arrachages au hasard deviennent une dose fixe :
  - 2 cachettes par Balayage (8 par jour) ;
  - un toit tous les deux Balayages (2 par jour, 20 au jour 10 sur 91) ;
  - plus, toujours, les cachettes et maisons où l'on s'est caché.

  La montée des arrachages est gardée pour le quartier 3.
- **Moins de cachettes chaque matin**, choisi par l'assistant (Josh : « faut
  pas que le jeu soit trop facile ») : on passe de 60 % à 40 % des
  emplacements, soit environ 140 cachettes, dont une centaine en ville
  (à peu près une par maison). Avec 210, il y en avait dans chaque coin.
  C'est le premier bouton à tourner si c'est encore trop facile, ou trop dur.

## 5 novembre 2026 — la ville plus abîmée, et l'Œil qui s'impatiente

Josh : « faut encore abîmer un peu plus la ville » ; si les joueurs mettent
trop de jours, changer de quartier doit devenir difficile. Il a laissé
l'assistant régler la difficulté.

- **Plus de toits arrachés dès le début** : un toit au hasard par Balayage (au
  lieu d'un tous les deux), soit 32 sur 91 au jour 8. Il faut y ajouter ceux
  où quelqu'un s'est abrité.
- **À partir du jour 9, l'Œil s'impatiente** (`Config.district.pressureDay`).
  Le quartier est prévu pour 8 à 10 jours. Chaque jour de plus :
  - **+0,5 toit par Balayage**, jusqu'à 4. Au jour 12, 60 toits sont partis
    au hasard, les deux tiers ;
  - **+1 cachette arrachée par Balayage**, jusqu'à 6 ;
  - **4 % de cachettes en moins le matin** : 140 au jour 1, 84 au jour 13,
    70 au plus bas.
- **Chaque matin à partir du jour 9**, le message dit « L'Œil s'impatiente : la
  ville ne tiendra plus longtemps ». Les joueurs savent qu'ils traînent.
- **Les courbes par jour ont maintenant un jour de départ** (`fromDay`) : avant
  ce jour, elles ne bougent pas.

## 5 novembre 2026 — la moitié des toits vers le jour 9, et un Œil vivant

- **Les toits** (Josh : « vers le jour 8 ou 10, environ 50 % », puis une
  accélération) : 1,25 toit au hasard par Balayage jusqu'au jour 9, soit
  45 sur 91 au jour 9, plus ceux où l'on s'est abrité. Ensuite +1 par
  Balayage chaque jour : 84 au jour 12.
- **L'Œil a des paupières** : c'est la Fissure qui se referme sur lui.
  - Fermé entre deux Balayages et la nuit : il ne reste qu'une couture
    brûlante dans le ciel.
  - Il s'ouvre en 3 s au signal et se referme en 5 s après le Balayage.
  - Ouvert, il cligne toutes les 5 à 11 s.
  - Sa pupille, une fente en amande, est large quand il s'ouvre, puis se
    resserre en 2 s : il cherche.
  - Il se tourne toujours vers le bout de son faisceau.
- **Le globe retravaillé** : une trentaine de veines ramifiées (sombres pour
  la plupart, quelques-unes brûlantes), un reflet humide, un iris en anneaux
  (un liseré, un anneau qui rougeoie, un cœur sombre) et 48 fibres.
- L'ancien fondu de l'Œil la nuit est remplacé par les paupières.
