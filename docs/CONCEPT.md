# Sous le Regard — le concept

Titre de travail. Concept construit avec Josh le 5 novembre 2026.

Chaque point porte son statut :

- **Décidé** : validé par Josh, ne se change qu'avec lui.
- **Proposé** : proposé par l'assistant, pas contredit, à confirmer en jouant.
- **Ouvert** : à trancher avant le code concerné.

Tous les chiffres sont des valeurs de départ : ils iront dans `Config.luau` et se
règlent en jouant.

---

## 1. Le principe

**Décidé.** Jeu de survie coopératif, **3 à 5 amis** sur un serveur privé, **à la
manette**. On survit dans une ville en ruine : le jour, on **fouille** pendant
que **l'Œil du ciel balaie les rues** et il faut **se cacher** ; la nuit, on
**défend sa Planque** contre ceux que l'Œil a aspirés. La Planque doit grandir
sans se faire repérer.

Ce que Josh voulait et que le concept doit tenir :

- il faut une **stratégie**, sinon on meurt ;
- **farmer et améliorer la base servent vraiment** ;
- une **vraie histoire** ;
- long, presque infini, **pas répétitif** ;
- pas des mois de code avant de pouvoir jouer.

## 2. L'histoire

**Proposé.** Il y a un an, le ciel s'est fendu. Derrière la Fissure, un œil
immense : **le Veilleur**. Plusieurs fois par jour il balaie la ville, et tout ce
qu'il voit est **aspiré vers le ciel**. Les survivants vivent cachés. Ceux qui
ont été aspirés redescendent parfois la nuit, changés : **les Repris**.

Le Veilleur **cherche quelque chose** qui est tombé du ciel le jour de la
Fissure. Ce qu'il cherche était **sous la Planque des joueurs depuis le début**.
À la fin : **le lui rendre, ou l'aveugler** — deux fins.

L'histoire se raconte par la radio, les survivants, et des objets trouvés
(cassettes, lettres, photos).

## 3. La partie et la sauvegarde

- **Décidé** : une **partie** se crée sur un serveur privé, les amis rejoignent.
  Elle est **sauvegardée** (Planque, réserves, jour, histoire) et reprend à la
  séance suivante.
- **Décidé** : on rejoint une partie par un **code de partie**, assez long pour
  qu'on ne puisse pas le deviner, avec un nombre d'essais limité par joueur. La
  sauvegarde appartient à la **partie**, pas à une personne : on peut jouer
  même si le créateur est absent. **Proposé** : le créateur reste chef (il peut
  changer le code) ; un bouton « Rejoindre un ami » liste les parties des amis
  Roblox, parce qu'un code se tape mal à la manette. Les serveurs réservés ne
  marchent que dans le jeu publié, pas dans Studio.
- **Décidé** (idée de Josh) : un **menu** puis une **salle d'attente** où l'on
  voit les joueurs arriver ; on peut lancer **à partir de 3 joueurs**.
  **Proposé** : menu = Nouvelle partie / Continuer / Rejoindre par code /
  Rejoindre un ami ; un joueur peut rejoindre une partie déjà en cours ; dans
  Studio, le minimum est levé pour les tests seul.
- **Décidé** : **l'équipe peut changer** d'une séance à l'autre : une partie
  lancée à 3 peut reprendre à 5, ou avec un joueur qui en remplace un autre. Un
  joueur absent garde son niveau. Un joueur **très en retard de niveau** gagne
  de l'**XP boostée**, pour rattraper petit à petit, pas d'un coup. **Proposé** :
  la difficulté suit le nombre de joueurs présents ; 5 joueurs au plus par
  partie.
- **Décidé** : la défaite, c'est quand **plus aucun joueur n'est debout**
  (tombé ou aspiré). La partie est alors perdue et **tout recommence depuis le
  début** : on n'a pas atteint le bout, il faut tout refaire, mais en sachant
  quoi faire on va plus vite.
- **Proposé** : pour que refaire ne soit pas répéter, ce qui se place au hasard
  change d'une partie à l'autre (cachettes fragiles, butin, survivants, repaires
  de Repris).
- **Décidé** : ne se perdent jamais l'histoire découverte, et le record de jours
  survécus.
- **Décidé** : **un revive payant, une fois par partie et par équipe** : il
  ramène la partie au début de la nuit perdue, avec tout ce qu'elle avait.
  N'importe quel joueur peut le payer pour l'équipe. C'est **le seul achat qui
  touche au jeu** ; le reste sera cosmétique. Prix : **ouvert**.
- **Décidé** : un **objet très rare** fait la même chose gratuitement, et un
  revive est **offert pour la première partie**. **Proposé** : offert à la
  première partie créée par un compte (une nouvelle partie repart de zéro, donc
  un second compte n'en tire rien).
- Les achats sont simulés dans Studio : le vrai paiement ne se vérifie qu'au jeu
  publié.

## 4. La journée

**Décidé** pour le rythme de départ ; à ajuster selon le nombre de jours qu'il
faut en moyenne pour finir un quartier (on rallonge les jours si besoin).

| Moment | Durée | Ce qui se passe |
| --- | --- | --- |
| Aube | ~1 min | Calme, on s'organise |
| Jour | ~12 min | Fouille, 4 à 5 Balayages |
| Crépuscule | ~1 min | Rentrer, construire, manger |
| Nuit | ~6 min | Les Repris attaquent la Planque ; butin de nuit dehors |

Un jour ≈ 20 min ; une séance de 1 h 30 ≈ 4 à 5 jours.

## 5. Le Veilleur

- **Décidé** : **bien caché, on est en sécurité** — s'il ne voit pas, il
  n'aspire pas. Être vu, c'est une **ligne de vue** entre l'Œil et le joueur.
- **Proposé** : des **signes** ~10 s avant (ciel rouge, silence, bourdonnement).
  Le périscope et la radio les donnent plus tôt.
- **Proposé** : une **jauge d'exposition** qui monte quand l'Œil te voit et
  redescend à l'abri ; pleine = aspiré. Traverser une rue en courant passe ;
  rester planté au milieu, non.
- **Proposé** : plusieurs Balayages (ligne, spirale, fouille vers le bruit,
  faux départ, regard long), de plus en plus rusés au fil des jours.
- **Décidé** : **cachettes fragiles** (abri de jardin, voiture, poubelle,
  buisson — partout) et **cachettes solides** (caves, dessous de pont, tunnels —
  rares, loin, fixes).
- **Décidé** : une cachette fragile utilisée est **marquée** (trace pâle visible
  de tous). Au Balayage suivant, l'Œil vient d'abord sur les cachettes marquées
  et **les arrache** : celui qui est dedans se retrouve à découvert, avec une ou
  deux secondes pour fuir. Une cachette solide ne s'arrache pas. La marque
  s'efface au bout d'un jour ou deux (**proposé**).
- **Décidé** (5 novembre 2026) : l'Œil **arrache aussi au hasard**, sur son
  passage, des cachettes fragiles et des toits, un peu plus chaque jour. Même
  une cachette occupée : on est éjecté, il nous repère, mais on a un **répit**
  (2 s sans que la jauge monte) pour courir. Un toit **tremble plusieurs
  secondes** avant de partir, et ceux qui sont dessous sont prévenus. Les toits
  ne reviennent pas : le quartier s'abîme jusqu'à ce qu'on le quitte.
- **Décidé** : l'Œil **traque** : il vise de mieux en mieux, poursuit qui il
  voit, garde sa piste un moment. Le premier jour, on lui échappe en marchant.

## 5 bis. La force de l'Œil sur les 7 quartiers

**Décidé** avec Josh (5 novembre 2026), sur son idée : **à chaque quartier,
l'Œil gagne une amélioration qui monte jour après jour**, et il **garde toutes
les précédentes**. Chaque amélioration a un plafond. On ressent ce qui change
d'un quartier à l'autre, et on peut s'y préparer.

| Quartier | Ce qui monte jour après jour | La parade qu'on y trouve (**proposé**) |
| --- | --- | --- |
| 1. La Banlieue | **La traque** : vitesse de poursuite (plus lente que la marche, puis plus rapide que la course), visée, mémoire de la piste | Le **fumigène** : un nuage qui coupe la ligne de vue, il perd ta piste (en plus de la radio et du périscope) |
| 2. La Zone commerciale | **La taille de la zone** balayée (280 → ~450 studs) | Les **plaques d'égout** qu'on ouvre : passer sous la zone |
| 3. Le Parc | **Les arrachages au hasard** : de plus en plus de cachettes et de toits | Le **filet de camouflage** : une cachette qui ne se marque pas et ne s'arrache pas au hasard |
| 4. L'Hôpital | **Le nombre de Balayages** par jour (4 → 6) | La **montre** qui dit quand vient le prochain Balayage, et l'**adrénaline** (courir plus longtemps) |
| 5. La Zone industrielle | **L'ouïe** : il vient vers le bruit (course, fouille, combat) | Le **leurre** bruyant qui l'attire ailleurs, les **semelles** silencieuses |
| 6. Le Centre-ville | **Un deuxième faisceau** (« un deuxième Œil s'ouvre ») | La **bâche de plomb** : une cachette qu'il ne peut pas arracher |
| 7. La Fissure | **Le faisceau plus large** | La **cape d'ombre** : la jauge monte deux fois moins vite |

- **Décidé** : chaque quartier donne **au moins une nouvelle parade**, trouvée ou
  fabriquée avec un matériau du quartier.
- **Décidé** : le jeu ne doit **jamais devenir facile** (Josh : « faut pas qu'on
  se dise : c'est facile, on se fait chier »). Ce qui s'additionne d'un
  quartier à l'autre ne redescend pas. Une parade aide face à une menace, mais
  ne l'annule jamais.
- **Proposé** : une simulation vérifie, quartier par quartier, qu'un joueur
  qui court vers la cachette la plus proche s'en sort *la plupart du temps*,
  pas toujours.

## 5 ter. Combien de temps dans un quartier

- **Décidé** (5 novembre 2026) : on vise **8 à 10 jours par quartier**, mais le
  suivant **ne s'ouvre pas au bout d'un nombre de jours** : il s'ouvre par des
  **quêtes et des fabrications** (l'outil qui ouvre le passage, le boss). Des
  amis efficaces passent plus vite ; d'autres restent plus longtemps, pendant
  que l'Œil durcit et que la ville s'abîme, ce qui pousse à partir.

## 6. Une ville qui change chaque jour

**Décidé** (idée de Josh) :

- chaque quartier a beaucoup d'**emplacements possibles** de cachettes
  fragiles ; chaque matin, le jeu en choisit une partie au hasard, et celles qui
  ont été arrachées ne reviennent pas au même endroit ;
- l'Œil transforme la ville : une maison aspirée laisse gravats et recoins, les
  Reliques tombées font des débris qui couvrent ;
- des événements : effondrement qui ouvre un passage, rue inondée, incendie ;
- les cachettes solides ne bougent pas : ce sont les repères qu'on apprend.

## 7. La fouille

**Décidé** : beaucoup d'objets différents, et chaque objet est une ligne de
données (en ajouter ne demande pas de code nouveau).

**Proposé** :

- chaque lieu a sa fouille (pharmacie → soins, garage → outils, commissariat →
  armes, épicerie → nourriture) ;
- catégories : nourriture et eau, matériaux, énergie, soins, armes et outils,
  objets à effet (café, boules Quies, sifflet, extincteur…), objets d'histoire,
  clés et codes ;
- états (usé, intact), outils qui s'abîment et se réparent, raretés ;
- **Reliques du ciel** : après certains Balayages, l'Œil lâche des choses qu'il
  avait prises ; il faut courir les ramasser avant le suivant ;
- **objets lourds à porter à deux** (générateur, batterie de voiture) ;
- **sac limité**, et plus il est lourd, plus on est lent ;
- le butin revient un peu chaque jour, le meilleur est toujours plus loin.

## 8. Les monstres et les boss

- **Décidé** : **le jour**, les Repris **dorment à l'intérieur** (caves,
  tunnels, grands bâtiments), toujours aux mêmes endroits ; ils se réveillent au
  bruit, à la lumière, ou si on les touche. Dehors c'est l'Œil, dedans ce sont
  les Repris : il faut choisir son danger.
- **Décidé** : **la nuit**, ils sortent partout et sont **attirés par le bruit
  et la lumière de la Planque**.
- **Décidé** : plusieurs types, plus ou moins forts. **Proposé** : Errant (lent,
  nombreux), Coureur (rapide, fragile), Hurleur (attire les autres), Rampant
  (trouve ceux qui sont cachés), Brute (casse les barricades), Guetteur (sur les
  toits le jour, prévient l'Œil). Chaque quartier en apporte un nouveau.
- **Décidé** : **un boss par quartier**, dans son repaire, qui garde la suite de
  l'histoire ; un **boss de Nuit Rouge** toutes les 7 nuits (**proposé**), qui
  attaque la Planque.

## 9. La Planque

**Décidé** : améliorer la base sert vraiment, et **plus elle grandit, plus elle
se voit**.

**Proposé**, le départ : une **cave sous une maison en ruine**, qui est déjà une
cachette solide (l'Œil ne la voit pas tant qu'elle reste discrète). Dedans, un
matelas, une lampe à la pile presque vide, une radio qui grésille, quelques
conserves et un pied-de-biche. Rien d'autre.

**Proposé**, la construction :

- **sur une grille**, partout : on vise une case, un fantôme vert ou rouge
  montre la pièce, son coût s'affiche ; poser prend quelques secondes de
  marteau ;
- **trois endroits** : la **cave** (sous terre, peu visible : lits, cuisine,
  atelier, infirmerie, réserve, radio, carte), la **maison au-dessus** (murs,
  toit, fenêtres condamnées, étage — plus visible), la **cour** (palissade,
  pièges, potager, récupérateur d'eau, générateur — très visible) ;
- **deux sortes de pièces** : les **structures** (murs, portes, barricades,
  sols ; bois → métal → renforcé ; elles ont des points de vie, les Repris les
  abîment, on répare) et les **postes** (atelier, cuisine… avec des niveaux qui
  débloquent des fabrications) ;
- **la base s'agrandit** en déblayant les gravats de la cave et en **annexant
  les maisons voisines** reliées par des tunnels ;
- **dans la ville**, seulement à des emplacements prévus : mini-planques,
  pièges, échelles et planches-ponts (raccourcis) ; plus tard, des
  **avant-postes** dans les quartiers lointains ;
- **ce qui limite** : les ressources, la place, la **Visibilité**, et un nombre
  maximum de pièces (performances et taille de la sauvegarde) ;
- **pas possible** : creuser le terrain librement, construire n'importe où en
  ville, des effondrements physiques.

**Proposé** :

- une **jauge de Visibilité** (lumière, bruit, fumée, taille, survivants) : trop
  haute, l'Œil trouve la Planque et un Balayage énorme la vise ; la nuit, elle
  attire aussi les Repris ;
- survivre : lits, cuisine, eau, infirmerie ;
- se défendre : barricades, portes renforcées, pièges, lampes ;
- rester caché : filets de camouflage, toit de plomb, isolation ;
- voir venir : périscope, radio, guetteur ;
- avancer : l'atelier (outils qui ouvrent les quartiers, leurres) ;
- **mini-planques** dans la ville : cachettes sûres et coffres sur les trajets ;
- **survivants sauvés** : ils travaillent pour la Planque, mais mangent et font
  du bruit.

## 9 bis. Aspiré, le Ventre, recraché

**Décidé** avec Josh (6 novembre 2026) :

- **Le Ventre de l'Œil.** L'aspiré attend dans une salle à part. Il y lit
  des souvenirs d'autres aspirés (l'histoire), et il peut **regarder la
  ville par l'Œil** : la prochaine zone balayée, ses amis. Il les prévient à
  la voix.
- **Recraché la nuit.** L'Œil aspire le jour et rend la nuit : l'aspiré
  retombe avec les Repris, loin de la Planque, **attaché dans un cocon**.
  Seuls ses amis peuvent le détacher.
- **La nuit, il recrache aussi des épaves** de ce qu'il a avalé : du butin
  rare, à fouiller de nuit, qui disparaît à l'aube.

## 10. Quand ça tourne mal

**Proposé**, sauf la défaite (décidée, voir §3) :

| Situation | Conséquence |
| --- | --- |
| Aspiré le jour | Perd ce qu'il portait ; attend dans le Ventre de l'Œil ; recraché la nuit, attaché dans un cocon que ses amis doivent venir ouvrir (**décidé**) |
| Tombé la nuit | Un ami peut le relever ; sinon il revient à l'aube, affaibli |
| Plus personne debout | **Partie perdue**, tout recommence (revive possible une fois) |
| Planque repérée | Grand Balayage : ce qui n'est pas protégé est aspiré |

## 11. Les quartiers et la carte

- **Décidé** : les quartiers se **débloquent petit à petit**. Il faut avancer
  dans l'histoire, fabriquer l'outil qui ouvre le passage, et cet outil demande
  un matériau du quartier précédent. Chaque quartier est plus dur que le
  précédent. Dans un quartier aussi, tout ne s'ouvre pas tout de suite
  (bâtiments à clé, coffres à code, sous-sols barricadés).
- **Décidé** : **7 quartiers**.
- **Décidé** pour la Banlieue : ~800 × 800 (construit en 800 × 640). Ancienne proposition : ~1000 × 1000 studs par quartier (~280 m de côté), la Planque
  **en bordure** du premier quartier, pour que partir fouiller soit un vrai
  trajet. En ligne droite on traverse en ~1 min, mais avec les clôtures, les
  intérieurs et les Balayages, un aller-retour réel prend plusieurs minutes. Les
  quartiers suivants sont plus loin : les expéditions s'allongent, et les
  mini-planques deviennent nécessaires. Repère : la plaque de base de Roblox
  fait 512 × 512 studs ; 1 stud ≈ 28 cm. Ouvert : à confirmer par Josh.
- **Proposé** : **construire un seul quartier d'abord**, les autres un par un.

| Chapitre | Quartier | Ce qu'on y découvre |
| --- | --- | --- |
| 1 | La Banlieue — beaucoup de recoins | La radio, d'autres survivants, le premier boss |
| 2 | La Zone commerciale — un hypermarché | Une communauté de survivants, et ce qu'elle cache |
| 3 | Le Parc — presque aucun couvert | Les Repris se souviennent de qui ils étaient |
| 4 | L'Hôpital | Ce qui arrive vraiment aux gens aspirés |
| 5 | La Zone industrielle | Le Veilleur cherche quelque chose |
| 6 | Le Centre-ville — tours et toits | Un deuxième Œil s'ouvre |
| 7 | La Fissure | Ce qu'il cherche était sous la Planque ; deux fins |

Ancienne version à 5 quartiers, gardée pour mémoire :

| Chapitre | Quartier | Ce qu'on y découvre |
| --- | --- | --- |
| 1 | La Banlieue — beaucoup de recoins | La radio, d'autres survivants, le premier boss |
| 2 | Le Parc — presque aucun couvert | Les Repris se souviennent de qui ils étaient |
| 3 | La Zone industrielle | Le Veilleur cherche quelque chose |
| 4 | Le Centre-ville — tours et toits | Un deuxième Œil s'ouvre |
| 5 | La Fissure | Ce qu'il cherche était sous la Planque ; deux fins |

## 12. Les quêtes

**Décidé** :

- la **quête principale** (radio, survivants) raconte l'histoire et ouvre les
  quartiers ;
- les **quêtes des survivants**, chacun avec sa petite histoire ;
- les **missions de la radio**, renouvelées chaque jour, avec récompense.

**Décidé** avec Josh (5 novembre 2026) — la quête principale de la Banlieue,
**« La voix dans la radio »** :

1. **Le poste** : la radio de la Planque est cassée. Trouver la lampe (à
   l'atelier de la station-service ; « la gare » de la proposition n'existe
   pas dans la ville) et la réparer. Une voix de femme
   répond : « Il y a quelqu'un ? »
2. **Le signal** : prendre l'antenne de l'église et monter la poser en haut
   du château d'eau, tout là-haut, à découvert, **pendant qu'un autre règle la
   radio à la Planque**. La radio capte : un survivant est caché en
   ville.
3. **Le survivant** : le trouver (un endroit différent à chaque partie) et
   **l'escorter** jusqu'à la Planque. Il nous suit, et il faut le cacher aussi
   pendant les Balayages ; s'il est aspiré, on le retrouve plus tard ailleurs.
4. **Le fumigène** : il sait le fabriquer, avec des ingrédients de la
   supérette. C'est la première parade contre l'Œil.
5. **Le repaire** : la sortie de la ville est barrée par le nid du boss (le lieu
   est à fixer : la ville n'a pas de gare). Fabriquer de quoi ouvrir la grille et le vaincre : fin du
   chapitre 1.

- **Décidé** : l'histoire se raconte en **sous-titres radio** (la radio
  grésille, le texte s'affiche chez tous les joueurs en même temps), et par des
  objets trouvés (lettres, photos). Pas de voix enregistrées.
- **Décidé** : quand la partie est perdue, **les quêtes recommencent** avec
  elle ; les textes déjà lus restent dans un journal, et certains lieux changent
  (le survivant est ailleurs).
- **Ordre de construction** : les étapes 1 à 4, puis le boss à part.

## 13. Les actions et la manette

- **Décidé** : **tout le jeu à la première personne.**
- **Décidé** (Josh, 5 novembre 2026, revenu sur sa première idée après avoir
  essayé) : **dans une cachette, on voit dehors normalement**, avec un rappel
  discret pour sortir. L'écran noir gênait.
- **Décidé** (idée de Josh) : **se repérer s'obtient en fabriquant.** Sans
  objet, on ne voit pas ses amis. **Proposé** : un **talkie-walkie** que chacun
  porte (il montre la direction des amis sur une boussole en haut de l'écran,
  et use des piles) et une **carte** posée à la Planque. Les signaux rapides de
  la croix directionnelle restent, sans position affichée.
- **Décidé** : corps à corps (batte, pied-de-biche) et objets à lancer ; les
  **armes à feu sont rares et bruyantes**, et le bruit attire les Repris et
  l'Œil.
- **Décidé** : **la manette décide.** Si une action ne rentre pas dans les
  boutons de la manette, on la sacrifie. Un test vérifie qu'aucun bouton n'a
  deux actions dans le même contexte.
- **Proposé** : glisser en courant, ramper, enjamber, grimper, retenir son
  souffle, jeter un objet, traîner un ami tombé, barricader une porte. Certaines
  actions sont **contextuelles** (le même bouton fait glisser en courant, ramper
  à l'arrêt, enjamber devant un muret).
- Chaque action demande une animation, simple au début.

## 14. Les niveaux et les améliorations

**Décidé** (idée de Josh) :

- on gagne de l'XP, on monte de niveau ;
- à chaque niveau, **3 améliorations tirées au hasard** dans un grand catalogue,
  on en choisit **une** ;
- elles **se cumulent** (la même peut revenir) et durent **pour la partie** ;
- **raretés** : commune (petit chiffre), rare (plus gros ou double), épique (un
  effet nouveau), légendaire (effet marquant, très rare) ;
- **aucun cumul ne doit rendre le jeu cassé**, même pour un joueur chanceux : la
  valeur de chaque amélioration se règle à partir du nombre de niveaux qu'on
  atteindra, et se **vérifie par le calcul** ;
- Josh préfère que **ça reste de la chance** : pas de garantie d'épique ni de
  légendaire ;
- **jamais de relance ni d'amélioration payante** ;
- XP, au cas par cas :
  - monstre tué à plusieurs : XP **répartie selon les dégâts** ;
  - objet ramassé : XP **de celui qui ramasse** ;
  - fabrication : XP **partagée entre tous** ;
  - ce qui est commun reste commun.

**Proposé** :

- le niveau gagné reste **en attente** et se choisit quand on est à l'abri
  (pas de pause en multijoueur) : trois cartes, stick, A ;
- des améliorations **d'équipe** (« tes alliés proches fouillent 5 % plus
  vite ») ;
- les chances de chaque rareté **affichées** dans le jeu ;
- une vingtaine d'améliorations au début, puis d'autres par mises à jour ;
- niveau 40 à 50 à la fin de l'histoire, sans maximum ensuite.

**Décidé** : **une relance tous les 10 niveaux**, pas de garantie de rareté ;
l'XP de fabrication : **chacun reçoit la totalité**.

**Vérifié par le calcul** (simulation de 20 000 joueurs jusqu'au niveau 45,
90 améliorations, chances par carte 60 / 28 / 10 / 2 %) : une commune précise
se présente en moyenne 2 à 3 fois, 6 fois ou plus chez ~5 % des joueurs, 8 fois
ou plus chez ~0,5 % ; aucun joueur n'a eu 10 tirages de suite sans rare ;
~6 % ne voient jamais de légendaire. Donc chaque valeur se règle pour rester
correcte prise 8 fois, avec un plafond sur le total de chaque statistique, et un
test refait ce calcul.

## 15. Combien de temps ça dure

**Proposé**, estimations :

| | Durée de jeu |
| --- | --- |
| Un jour | ~20 min |
| Un chapitre | ~8 à 10 jours, ~3 h |
| L'histoire | 15 à 20 h |
| Ensuite | Mode sans fin, l'autre fin, les mises à jour |

## 16. Le style visuel

**Décidé** : laissé à l'assistant, avec un objectif : **le plus beau possible,
un jeu qui paraît abouti.** **Proposé** : semi-réaliste et sombre, une banlieue
grise et un ciel qui rougit. Lumière « Future », atmosphère, brume, matières
réalistes, retouche de l'image.

**Décidé** : **pas de blocs gris.** Dès la première version, même avec un seul
quartier, le jeu doit être beau et se tester dans les vraies conditions. Les
modèles générés sont des propositions ; c'est l'œil de Josh qui tranche.

## 17. L'ordre de construction

1. **La plus petite version jouable** : un pâté de maisons, la fouille, l'Œil
   et ses signes, cachettes fragiles et solides, la glissade, être aspiré, une
   Planque simple. Question à laquelle elle répond : **se cacher du regard est-il
   amusant et stressant, à trois ?**
2. Un jour complet : la nuit, les Repris, la construction, la Visibilité, la
   sauvegarde, les niveaux.
3. Le chapitre 1, publiable : la Banlieue complète, son boss, les survivants,
   les quêtes, des menus manette propres.
4. Les chapitres 2 à 5, un par un.
