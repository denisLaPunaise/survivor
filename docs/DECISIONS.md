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

## 5 novembre 2026 — le laser sort de la pupille, une jointure en braise

- **Le regard part du bout de la pupille**, tournée vers le point visé
  (Josh : « que le laser sorte de la pupille »). Pour que le jeu ne mente pas,
  la **ligne de vue part du même point** : l'EyeService mesure le globe et la
  pupille sur le modèle du ciel au début de chaque Balayage. Comme c'est le
  modèle qui donne la hauteur, `Config.eye.height` est supprimé. La mesure
  de la recette vise de la même façon.
- **Pendant un Balayage, l'Œil suit son faisceau de près** (vitesse de
  rotation 12 au lieu de 2,5). Mesuré en jeu : 0,2° d'écart entre son regard
  et le faisceau, qui part à 8 studs du centre de la pupille.
- **La jointure des paupières fermées** n'est plus une droite jaune :
  - la paupière du haut descend plus loin que celle du bas ne remonte, donc
    elles se rejoignent sur une courbe ;
  - le bord est une ligne continue qui s'efface aux coins de l'œil ;
  - fermée, elle respire comme une braise (rouge sombre ↔ orange, toutes les
    3,5 s).
- **Les éclairs autour de la Fissure s'animent** : une lueur court le long de
  chaque branche, du trou vers le dehors (toutes les 2,5 à 6 s), avec un léger
  crépitement. Ils restent à 35 % de leur éclat quand l'Œil est fermé et
  montent à 80 % quand il est ouvert.

## 5 novembre 2026 — la quête principale, étapes 1 et 2

Josh a validé « La voix dans la radio » (`CONCEPT.md` §12). Il a ajouté que
l'histoire doit durer environ 8 à 10 jours, sans pouvoir aller beaucoup plus
vite, et rester intéressante à 3 comme à 5. Il a laissé l'assistant régler la
suite.

- **Le rythme** : Mara ne parle que la nuit. Une étape réussie se raconte la
  nuit suivante, et la suivante s'ouvre à l'aube, jamais avant son jour
  (`Config.story.opensOnDay`). Il faut donc au moins un jour par étape.
  - Jours prévus : le poste au jour 1, le signal au jour 2, le survivant au
    jour 4, le fumigène au jour 6, le repaire au jour 8.
  - Joué parfaitement, le boss ne s'ouvre donc pas avant le jour 8.
  - Un test joue la partie la plus rapide possible et vérifie qu'aucune étape
    ne s'ouvre avant son jour.
- **À plusieurs, chaque étape demande de se séparer ou de se partager le
  travail.**
  - Le signal se fait à deux endroits à la fois : l'un pose l'antenne en haut
    du château d'eau, un autre règle la radio à la Planque, à moins de 25 s
    d'écart. Les deux lieux sont à 1 200 studs l'un de l'autre.
  - Pour les étapes suivantes (proposé) :
    - l'escorte : les autres éclairent le chemin et gardent les cachettes ;
    - les ingrédients du fumigène : autant que de joueurs, un par personne ;
    - le boss : il s'adapte au nombre de joueurs.
- **Seul dans Studio**, poser l'antenne suffit (`soloInStudio`), comme la salle
  d'attente qui lève son minimum dans Studio. Jamais dans le jeu publié.
- **Il n'y a pas de gare dans la ville** : la proposition parlait de la gare,
  mais le repère est une station-service. La lampe est à l'atelier de la
  station-service. Le lieu du repaire du boss sera fixé avec lui.
- **La radio coûte maintenant la lampe et une pile**, au lieu de deux piles et
  une clé : la lampe ne se trouve qu'à la station-service. Elle continue de dire
  de quel côté l'Œil va chercher.
- **L'antenne reste dans le sac quand on dépose** : il faut la porter là-haut,
  et la réserve ne rend rien. Un contenant de quête donne son objet une fois
  par partie, puis redevient un contenant normal.
- **Le château d'eau se grimpe** : une échelle jusqu'à une passerelle sous la
  cuve, une seconde jusqu'au rebord du haut, où se pose l'antenne, à découvert.
- **Ce qui s'affiche** : l'objectif en haut à gauche, discret ; les lignes de
  Mara en bas de l'écran, une toutes les 6 s, chez tout le monde.
- **Réécouter Mara** (Josh : « si la personne n'est pas attentive »). L'invite
  de la radio de la Planque change de rôle : « Régler la radio » pendant
  l'étape du signal, « Réécouter la radio » le reste du temps. Elle rejoue le
  dernier message à celui qui la tient, à lui seul. Il n'y a pas de bouton en
  plus, et l'objectif reste affiché en haut à gauche. Le dernier message est
  gardé même après une défaite : c'est le début du journal prévu par le
  concept.
- **Le journal** (idée de Josh, on garde aussi la réécoute à la radio) : un
  onglet dans le panneau du sac. Y l'ouvre, L1 / R1 passent du Sac au Journal
  (Q / R au clavier). On y lit la quête en cours, puis tout ce que Mara a dit,
  nuit par nuit, le plus récent en haut ; le stick droit fait défiler. Quand
  Mara a parlé, un message dit « Journal mis à jour : Y, puis R1 ».
  - Pas de bouton à part : à pied, tous les boutons de la manette sont pris, et
    Select appartient à Roblox.
  - Au clavier, l'onglet suivant est sur R et non E : près de l'établi,
    l'invite de Roblox prenait E avant le panneau (vu en jeu).
  - Les boutons du panneau sont dans `Config.controls.contexts.bag`, que le
    test des collisions surveille.

## 6 novembre 2026 — les textes, l'Œil qui te voit, le Ventre, le cocon

Décidé avec Josh (ses réponses, et « on le met en place »).

- **Les textes** :
  - **Deux voix.** Une police de machine à écrire (Special Elite) pour ce
    qui raconte : la radio, le journal, les jours, les murmures, les
    souvenirs. Une police nette pour ce qu'on lit d'un coup d'œil.
  - **Les animations.** Les lignes de Mara s'écrivent lettre par lettre, et
    le « RADIO » grésille. Les messages glissent puis s'effacent, chacun dans
    la couleur de sa sorte (info, danger, quête). « Jour N » s'écrit en grand
    au centre, avec la suite en rouge quand l'Œil s'impatiente.
  - **L'objectif** porte un petit titre doré, et sa hauteur suit le texte : il
    était coupé.
  - **Pas de bandeau sombre** derrière les textes, un léger contour à la
    place : le bandeau faisait une boîte aux bords durs.
- **Quand l'Œil te voit** :
  - les bords de l'écran rougissent et battent comme un cœur, plus vite
    quand la jauge monte ;
  - un murmure tremble au centre : « Je te vois… », puis « Ne bouge pas… »,
    puis « À moi. » ;
  - la vue tremble un peu, et sa pupille se serre sur toi dans le ciel ;
  - il reste une fine jauge en haut.
- **Quand il t'aspire** :
  - **pour toi**, un flash blanc qui vire au rouge, la caméra forcée vers
    l'Œil pendant que tu montes en tournoyant, puis le noir et « Il t'a
    pris. » ;
  - **pour les autres**, tu montes en tournoyant dans une colonne de lumière.
- **Le Ventre de l'Œil**, où l'on attend :
  - **Le lieu.** Une salle fermée, à 6 000 studs de la ville, invisible : de
    la roche sombre veinée de rouge autour d'une pupille qui brûle, des
    morceaux de ville qui flottent. Elle est toujours chargée chez chaque
    client (sinon la vue l'attendait).
  - **Six souvenirs à lire** (`Memories`). Laissés par d'autres aspirés, ils
    s'ajoutent au journal et racontent ce que deviennent les aspirés et ce
    qu'il cherche.
  - **L'Oculus : regarder par l'Œil.** La caméra passe juste sous sa pupille
    et regarde la ville. On y voit la zone du prochain Balayage en rouge dès
    le signal, puis le bout du faisceau, et les amis surlignés en vert. On
    les prévient à la voix ; B revient.
  - **Trois réglages pour que la ville se voie.** Pendant cette vue, la
    brume, les nuages et le flou de profondeur sont coupés localement : de
    si haut, on ne voyait que le dessus des nuages et un sol couleur ciel.
    Et la ville reste chargée pour l'aspiré (`ReplicationFocus`), sinon il
    regardait du vide.
- **Recraché la nuit** (idée de Josh : l'Œil aspire le jour, rend la nuit) :
  - **La chute.** À la tombée de la nuit, avec les Repris, il recrache ceux
    qu'il a pris. Ils tombent du ciel en tournoyant, loin de la Planque
    (250 studs au moins), et restent **attachés dans un cocon** : une gangue,
    des filaments brûlants, une lueur et un trait de lumière vers le ciel.
  - **Le cocon.** Seul un ami peut le détacher (X maintenu 3 s) ; on ne se
    libère jamais seul (choix de Josh). Attaché, l'Œil ne te reprend pas
    (sinon ça boucle), les Repris et les coups t'ignorent, et tu ne comptes
    pas comme debout pour la défaite.
  - **La fin du retour du matin.** Le retour « au matin, sur une cachette au
    hasard » est supprimé.
- **Il avale au lieu de juste arracher** : les morceaux de toit et les
  cachettes montent en spirale jusque sous sa pupille, en rétrécissant.
- **La nuit, il recrache des épaves** (idée de Josh) :
  - **Combien.** 2 au moins, plus une pour deux choses avalées dans la
    journée, 10 au plus.
  - **Comment.** Des caisses aux fentes brûlantes tombent loin de la
    Planque, à côté d'un emplacement de cachette, jamais dedans : une épave
    était tombée dans un buisson, donc un rayon vérifie qu'elle touche le sol.
  - **Ce qu'elles donnent.** Elles se fouillent comme le reste, avec du
    butin rare (médicaments, piles, plomb, clés), et disparaissent à l'aube.

## 6 novembre 2026 — après une partie d'essai de l'assistant

Ce qu'il a corrigé après avoir joué seul :

- **« Jour 1 » ne s'affichait pas** au lancement : le serveur l'annonçait avant
  que l'écran du joueur soit prêt. Le titre du jour est gardé en attribut
  (`Config.world.dayAttribute`), et l'écran le montre en arrivant. C'est aussi
  utile à qui rejoint en cours de partie.
- **Des textes coupés au milieu** (« Tu es attaché : », « venir te ») : le
  message central, le rappel du bas et la légende de la vue par l'Œil ont
  maintenant une hauteur qui suit le texte.
- **Vue par l'Œil** :
  - le sac et la réserve sont cachés pendant qu'on regarde ;
  - la zone du prochain Balayage est un volume rouge (à plat, les collines la
    perçaient) ;
  - l'Œil ne vise plus un joueur attaché.
- **La lumière du cocon** est baissée (2 → 0,8) : elle repeignait tout l'écran
  en rouge.
- **Le « ? » de l'objectif** reste collé au mot d'avant (espace insécable).
- **Le cocon refait** : la première version (un cylindre sombre et des bâtons
  rouges) était laide, vue en jeu. C'est maintenant une chrysalide sombre
  enlacée de quatre spirales de veines brûlantes qui battent doucement, sur
  des racines dans une tache de terre brûlée, avec un fil de lumière fin
  qui monte du haut du cocon. Elle tombe sur une place libre, comme les
  épaves (`LootService.landingSpot`) : la première était tombée contre une
  palissade, à moitié dans une tôle. Photos dans `docs/images/`.
- **Le Ventre dit quand on sort** (Josh : on ne savait pas) : à l'arrivée,
  « Le Ventre de l'Œil. Il te recrachera à la tombée de la nuit. » ; puis en
  permanence en bas, « Encore N Balayages avant la nuit » et ce qu'on peut
  faire (regarder par l'Œil, chercher les souvenirs). Le nombre de Balayages
  restants est un attribut de Workspace (`Config.world.sweepsLeftAttribute`),
  posé dès l'aube.
- **On garde le recrachage à la nuit** (Josh), avec 8 à 10 minutes d'attente
  au plus pour qui est pris au premier Balayage.
- **Le faire cligner depuis le Ventre** (décidé avec Josh, « pas trop fort,
  pas en boucle ») :
  - **Comment.** Pendant un Balayage, les aspirés frappent les piliers de
    chair du Ventre (R2, le bouton des coups) ; chaque coup embrase une
    veine. Au 6ᵉ coup (les coups de tous s'additionnent), l'Œil cligne de
    douleur.
  - **L'effet.** Ses paupières se ferment, son regard s'éteint 1,5 s et ne
    voit plus personne, et il perd la piste de celui qu'il poursuivait. Une
    seule fois par Balayage.
  - **Le rythme.** Seul, il faut environ 4 s de coups.
  - **Hors Balayage**, frapper ne fait rien et on le dit.
- **Aucun son dans le jeu pour l'instant** : à ajouter (question de Josh).

## 6 novembre 2026 — les sons

Josh : « il faudrait penser à en ajouter ».

- **Treize sons**, tous de Pro Sound Effects ou d'APM Music (les bibliothèques
  de Roblox : un son d'utilisateur peut être retiré, et un son qui ne charge
  pas échoue en silence). La liste est dans `docs/ASSETS.md`.
- **Choisis sur le nom et la durée**, sans les écouter : à Josh de dire
  lesquels changer.
- **Ce qu'on entend de son propre point de vue** (`SoundView`, côté client) :
  - l'ambiance en fondu : vent le jour, drone la nuit, cœur dans le Ventre ;
  - l'Œil : un coup sourd et un grondement au signal, ses paupières, son
    regard qui bourdonne de plus en plus fort quand le bout du faisceau
    approche, un murmure quand il te voit, son cri quand on le fait cligner ;
  - le souffle de l'aspiration, et la radio qui grésille à chaque ligne de
    Mara.
- **Ce qui se passe dans le monde, que tout le monde entend d'où il est**
  (`Sfx`, côté serveur) : un toit qui craque puis est aspiré, une cachette
  avalée, quelqu'un qu'on aspire, une épave qui s'écrase.
- Les sons sont préchargés au démarrage ; un son qui ne charge pas est nommé
  dans la console. Un test vérifie que chaque son de la liste est joué
  quelque part.
- **Pas encore de sons** pour les Repris, la fouille, les coups et les pas.
- **Bug corrigé** (vu dans la console en essayant les sons) : depuis
  l'aspiration en spirale, les copies des toits avalés n'étaient jamais
  supprimées. Elles s'accumulaient, invisibles. C'est réparé : après un toit
  arraché, plus aucune ne reste.

## Le survivant, étape 3 de « La voix dans la radio » (7 novembre 2026)

Décidé avec Josh : on le trouve par les indices de Mara, il boite, on le
cache soi-même, il mange à la Planque (`CONCEPT.md` §12). Le reste, pris
sans lui :

- **Il s'appelle Élie**. L'étape s'ouvre au **jour 4** ; Mara dit où il se
  cache **la nuit d'avant** (un « briefing », que la quête sait maintenant
  dire pour n'importe quelle étape).
- **Quatre refuges** posés par la recette : la supérette, l'église, la
  station-service, une ferme intacte d'un hameau. Un par partie, au hasard.
  Avant d'être trouvé, il est terré au fond : l'Œil ne le voit pas.
- **Une seule invite (X) sur lui**, dont le texte suit ce qu'il fait :
  « Aider » (maintenir), « Cacher Élie », « Faire sortir Élie ». Celui qui le
  trouve ou le fait sortir devient son guide. Son invite porte à 5 studs et il
  s'arrête à 7 de son guide : quand il suit, elle ne prend pas celle des
  cachettes.
- **Il marche dans les pas de son guide** : le calcul de chemin de Roblox ne
  trouve aucune sortie aux maisons (vu dans Studio). Trop loin (70 studs), il
  s'arrête et le dit.
- **« Cacher »** l'envoie à la cachette libre la plus proche (25 studs).
  Sa cachette se marque comme celle d'un joueur ; arrachée, il est éjecté
  avec le même répit.
- **L'Œil le voit comme un joueur** (même ligne de vue, même jauge), et
  s'abriter avec lui dans une maison la marque. L'Œil ne le **poursuit** pas
  (la traque reste sur les joueurs).
- **Aspiré** : Mara le redit la nuit, il attend dans un autre refuge au
  matin. **Les Repris l'ignorent** la nuit.
- **Il ne peut pas mourir** autrement que par l'Œil.
- **À la Planque**, il mange un plat de la réserve chaque nuit. S'il n'y a
  rien, on le dit, **sans autre conséquence pour l'instant** : à décider avec
  l'étape 4 (il fabrique le fumigène).
- Son allure : bonnet rouge, écharpe, sac à dos, jambe bandée, pour le
  reconnaître de loin à sa silhouette.

## Le fumigène, étape 4 (7 novembre 2026)

Josh a décidé : Élie le fabrique, on le lance avec L2, l'Œil guette autour du
nuage avant de perdre la piste, et sans repas Élie ne fabrique rien
(`CONCEPT.md` §12). Pris sans lui :

- **La recette** : un produit chimique et une ferraille par fumigène, **deux
  au plus par nuit**. Les produits chimiques ne se trouvent que dans la
  **réserve au fond de la supérette** (une petite pièce derrière les rayons,
  deux étagères, table `arriere`) : Mara le dit la nuit du jour 5.
- **L'étape s'ouvre au jour 6** et se réussit en **lançant le premier
  fumigène** : ainsi la quête apprend à la fois à le fabriquer et à s'en
  servir. Élie ne fabrique qu'à partir de l'étape 4 ; ensuite, toujours.
- **On prend les fumigènes auprès d'Élie** (X sur lui à la Planque,
  « Prendre un fumigène (2) ») : la réserve ne rend rien, et c'est lui qui
  les a faits. Un fumigène **reste dans le sac** quand on dépose au coffre.
- **L2 lance directement** le fumigène du sac, sans le choisir (L1 / R1 ne
  servent pas encore) : c'est le seul objet qui se lance.
- **Le nuage** : 14 studs de rayon (le regard en fait 16), 20 secondes, il
  s'ouvre en 1,5 s et rétrécit les 4 dernières secondes. On le lance à ~40
  studs à plat, ~75 vers le haut.
- **L'Œil guette 7 secondes** en tournant autour du nuage, le bord de son
  regard sur le bord du nuage : qui sort pendant ce temps et se fait voir est
  repris. Sa ronde va à 70 % de sa vitesse de poursuite (plus vite, il ne
  suit plus son cercle : vu le jour 1).
- **Les Repris ignorent la fumée** pour l'instant.
- **Pas de son** pour la boîte qui éclate : à ajouter.

## Le Gardien, étape 5 (9 novembre 2026)

Josh a décidé : le tunnel sous la voie rapide, un Repris géant, on le livre à
l'Œil, un écran de fin puis on continue (`CONCEPT.md` §12). Pris sans lui :

- **Où** : la rue est-ouest du nord sort de la ville par l'est et file jusqu'au
  bord de la zone, où elle passe sous une **voie rapide sur un remblai** (de
  28 de haut, qui barre tout l'horizon est). Le tunnel (88 studs, 18 de large,
  16 de haut) est fermé par une grille ; le fond s'est effondré.
- **La grille** s'ouvre avec un **coupe-boulon** fabriqué à l'établi
  (2 ferrailles, 1 clé à molette). C'est un outil : il va dans le sac de qui
  le fabrique, reste au coffre, et se refait s'il est perdu. Couper la chaîne :
  maintenir X 6 s. **Le bruit réveille le Gardien.**
- **L'étape s'ouvre au jour 8** ; Mara en parle la nuit du jour 7.
- **Le Gardien** : environ 12 studs de haut (2,2 fois un Repris), 17 studs/s (on le
  distance en courant, il rattrape qui marche), deux coups mettent à terre. Il
  ne meurt pas sous les coups (ils le réveillent). Entrer dans le tunnel le
  réveille aussi.
- **Il ne triche pas** : s'il te perd de vue, il va là où il t'a vu en dernier
  et y cherche 12 s, puis rentre au nid, plus lentement, et se rendort. La
  nuit, il est dans son nid.
- **L'Œil le voit comme un joueur**, mais il faut **6 s de plein regard** (un
  joueur : 2 s) et la jauge redescend lentement (12 s). Le Gardien **rougeoit**
  d'autant plus que l'Œil le tient : tout le monde voit où on en est.
- **Aspiré** : il monte en se débattant, l'Œil crie, et l'écran « Fin du
  chapitre 1 — La Banlieue, vous avez tenu N jours » s'affiche 9 s chez tous.
  Mara raconte la nuit suivante ; ensuite l'objectif dit « Chapitre 1
  terminé ».
- **Après une défaite**, tout recommence : grille refermée, Gardien absent
  jusqu'au jour 8.

## Les Repris, la construction libre, la Visibilité (9 novembre 2026)

Josh a décidé : les quatre nouveaux Repris arrivent au fil des jours dans la
Banlieue ; la Visibilité attire des Repris puis fait venir l'Œil ; on
construit sur une grille dans la cour et la maison (`CONCEPT.md` §8 et §9).
Pris sans lui :

**Les corps des Repris**
- Le corps reste celui d'un humain de Roblox (articulé, pour marcher), en
  cendre ; la **tête est un crâne généré**, texture retirée (elle faisait
  dessin animé), aux orbites qui luisent. Le Hurleur a un crâne à cornes et
  mâchoire ouverte ; la Brute porte une bosse de gravats générée ; le Guetteur
  a un seul grand œil rouge. Identifiants dans `docs/ASSETS.md`.
- Ils **marchent et courent avec les animations Zombie** de Roblox (avant : ils
  glissaient, raides) et **on entend leurs pas** de près.
- Leurs proportions changent d'une sorte à l'autre (Coureur maigre, Rampant
  petit et bas, Brute 1,6 fois plus grande, Guetteur grand et fin).

**Les nouveaux Repris**
- **Hurleur** (jour 3) : quand il voit quelqu'un, il se fige et crie ; tout
  Repris à 90 studs accourt. Au plus un cri toutes les 10 s.
- **Rampant** (jour 5) : il sent un joueur caché à 14 studs ou moins et
  l'arrache de sa cachette. De plus loin, une cachette reste sûre.
- **Brute** (jour 7, la nuit seulement) : 240 de santé, lente, ses coups valent
  triple contre la barricade et les constructions.
- **Guetteur** (jour 9) : 2 puis jusqu'à 6, perchés sur des toits le jour,
  immobiles, hors d'atteinte. S'il voit quelqu'un (110 studs, ligne de vue),
  il siffle : pendant un Balayage, l'Œil fonce sur lui ; sinon, le prochain
  Balayage le vise sans erreur. Il disparaît la nuit.

**Les sons** (Pro Sound Effects, choisis sur le nom et la durée, je n'ai pas
pu les écouter) : grognement au réveil, cri du Hurleur, sifflement du
Guetteur, pas, coups, fouille (pendant qu'on maintient X), sifflement du
fumigène.

**La construction libre**
- Mode construction : **flèche gauche** dans un rayon de 70 studs autour de la
  Planque. R2 pose, L1 / R1 tournent, haut / bas changent de pièce, B ou
  flèche gauche sortent. Le fantôme est vert ou rouge.
- **Six pièces** : palissade (2 planches), mur de tôle (2 ferrailles, 1
  planche), chevaux de frise, piège à clous (blesse les Repris qui passent),
  lampe (s'allume la nuit), filet de camouflage (tendu au-dessus, cache).
- Grille de 4 studs ; 60 pièces au plus. Les Repris frappent ce qui leur barre
  la route ; une pièce abîmée noircit ; **X pour réparer** (1 planche).
- On ne démonte pas encore une pièce posée.

**La Visibilité**
- Le niveau additionne les constructions (le filet en retire 8), les postes
  de l'établi (2 chacun), la fumée du réchaud (5), Élie (8) et le bruit des
  coups la nuit.
- Chaque nuit, la jauge monte de la moitié du niveau et perd 4. **Un Repris de
  plus la nuit par tranche de 15.**
- **Pleine (100)** : au matin, « l'Œil a trouvé la Planque » ; le premier
  Balayage vise la Planque et **arrache 3 constructions qui ne sont pas sous
  un filet**. La jauge redescend à 40.
- Elle s'affiche au-dessus de la réserve : « Planque repérée : X % ».

**Corrigé en route, en testant une vraie nuit** :
- la nuit, les Repris calculaient leurs chemins un par un et la boucle
  attendait chaque calcul : à cent Repris, la plupart restaient plantés. Le
  calcul se fait maintenant en tâche de fond ;
- ils visaient le point de départ de la Planque, **sous terre** (aucun chemin)
  et cherchaient un chemin trop large pour les portes : **après une minute de
  nuit, aucun ne marchait**, ils poussaient contre un mur. Le chemin est
  calculé pour un corps plus fin qui saute, et celui qui n'avance plus saute
  et fait un pas de côté. Mesuré : deux tiers marchent, et ils arrivent à la
  Planque en trois minutes environ (la nuit en dure quatre). Un tiers reste
  encore coincé dans des maisons sans issue : à surveiller.
