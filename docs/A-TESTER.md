# À tester en jouant

Ce qu'un test en solo ne peut pas dire : si c'est amusant, lisible, juste.
Chaque point dit quoi regarder, dans quel ordre, et ce qui a été vérifié avant.

## Montage du projet (5 novembre 2026)

1. Ouvrir la place **Survivor**, lancer `rojo serve`, connecter le plugin Rojo,
   puis **Play**. La console doit afficher les lignes `[Survivor]` du
   `README.md`. *Vérifié par l'assistant : formatage, analyse, 89 tests et
   build passent en ligne de commande.*
2. **Les boutons proposés** (`src/shared/Config.luau`, section « Les
   commandes ») : les lire et dire si un choix te gêne. Ils seront vraiment
   testables à la première version jouable.

## Première version jouable (5 novembre 2026)

**Avant de jouer** : dans Studio, panneau *Explorer* → **Lighting** →
propriété **Technology** → **Future**. Je ne peux pas la régler moi-même.

Ce qui a été **vérifié seul dans Studio** : le serveur démarre et trouve toute
la ville ; un joueur à découvert sous le regard est aspiré ; seul et aspiré,
la partie recommence et ramène à la Planque ; fouiller remplit le sac et un
contenant fouillé reste vide ; se cacher marque la cachette, et le Balayage
suivant l'arrache ; le joueur dans la cave n'est pas vu. La recette du
quartier se mesure elle-même (0 problème).

Ce qui n'a **jamais été vu** : les invites (« Fouiller », « Se cacher »,
« Déposer ») déclenchées par une vraie touche ou une vraie manette — les
touches simulées par le pont ne les atteignent pas. C'est le premier point.

Dans l'ordre :

1. **Les invites à la manette** : devant un placard de cuisine, X maintenu
   doit fouiller ; devant une cachette, X doit te cacher (écran noir) ; X de
   nouveau doit te faire sortir. Dis-moi si l'une ne répond pas.
2. **La première personne, la course et la glissade** : L3 bascule la course ;
   B en courant glisse ; B à l'arrêt accroupit. La glissade est-elle utile, ou
   juste décorative ?
3. **Les signes** : le ciel rougit 10 s avant. Est-ce assez visible pour avoir
   le temps de courir à une cachette ? Trop ?
4. **Le premier Balayage** (environ 55 s après le départ) : reste une fois à
   découvert pour voir la jauge « IL TE VOIT ». Traverser le faisceau en
   courant doit passer ; rester planté non.
5. **Caché** : tu ne vois rien, seule une lueur monte quand le regard passe
   près. Est-ce stressant, ou frustrant ?
6. **La cachette arrachée** : cache-toi dans un abri pendant un Balayage, puis
   reviens-y au suivant. Elle doit être arrachée (avec la lueur pâle de la
   marque avant). As-tu eu le temps de fuir ?
7. **À plusieurs** : le Veilleur est-il trop facile ou trop dur à trois ? La
   vraie question de cette version : **se cacher du regard est-il amusant ?**

## Première passe visuelle (5 novembre 2026)

*Vu en image par l'assistant* : la Fissure, l'Œil, les débris, la rue, les
poteaux et leurs fils, les arbres générés. *Vérifié en jeu, seul* : l'Œil
tourne et les débris montent, sans erreur dans la console. *Jamais vu* : la
lumière en mode Future (je ne peux pas la régler), et le jeu à plusieurs.

1. **Lève les yeux** dès la sortie de la cave. L'Œil fait-il peur, ou fait-il
   rire ? C'est le juge le plus important de l'ambiance.
2. **Pendant un Balayage, regarde l'Œil** : il doit suivre le faisceau. Est-ce
   qu'on comprend où il cherche ?
3. **La rue** : est-ce assez « abandonné » ? Qu'est-ce qui fait encore faux
   (les sacs poubelle en boules, les voitures en blocs, les maisons) ?

## La Banlieue en grand (5 novembre 2026)

*Vérifié seul* : le quartier se construit sans problème mesuré (87
emplacements, 107 contenants, 6 cachettes solides) ; un Balayage vient bien
chercher autour du joueur (au plus près 15 studs) et dure ~45 s.

1. **La taille et la densité** (75 maisons depuis le 5 novembre) : est-ce
   qu'on s'y perd un peu, ou trop ? Reste-t-il des coins vides ? Combien de temps
   pour aller de la Planque (tout au sud-ouest) jusqu'à la supérette ?
2. **Le Balayage qui vient vers vous** : est-ce injuste, ou juste stressant ?
   Séparez-vous une fois, et restez groupés une autre fois.
3. **Les maisons à étage** : on ne peut pas monter. Est-ce que ça gêne ?

## Les points 1 à 4 (5 novembre 2026)

*Vérifié seul dans Studio* : un toit est arraché quand on s'y est abrité au
Balayage précédent ; un Repris endormi ne bouge pas quand on passe en silence
et se réveille à une fouille toute proche ; au contact il frappe et fait
tomber, et seul à terre la partie recommence ; quatre coups de pied-de-biche
tuent un Errant ; une nuit fait tomber le bon nombre de Repris, qui se
rapprochent de la Planque ; les cinq constructions se bâtissent en payant la
réserve ; la barricade perd ses points sous les coups ; le repas remet la faim
à plein. Les 211 tests passent.

*Jamais vu à l'écran* : les Repris eux-mêmes (leur allure), le panneau de
l'établi, la nuit côté joueur, les mots sur les murs (la capture d'écran ne
montre pas leur texte). *Jamais tenu en main* : tout ce qui suit.

1. **Les maisons ne sont plus sûres** : abrite-toi deux Balayages de suite
   dans la même maison. Le toit part-il bien au deuxième, et as-tu le temps
   de fuir ?
2. **Les Repris endormis** : entre dans quelques maisons. Est-ce qu'on les voit
   assez tôt ? Passer à côté en marchant doit être possible ; courir ou
   fouiller près d'eux les réveille. Est-ce lisible ?
3. **Le combat** : R2 frappe. Est-ce que le coup « porte » (on sent qu'on
   touche) ? Trois coups pour un Errant, est-ce juste ?
4. **À terre et relevé** : à deux, laisse-toi tomber et fais-toi relever
   (maintenir X près de toi).
5. **La nuit** : est-ce trop sombre, assez inquiétant ? La petite lumière
   suffit-elle ?
6. **L'établi** : à la manette, le panneau doit s'ouvrir avec X devant
   l'établi, se parcourir à la croix, construire avec A, se fermer avec B.
7. **Le repas** : rentrer le soir avec des conserves et de l'eau, et sentir la
   différence le lendemain si on ne l'a pas fait.
8. **La variété** : les maisons se ressemblent-elles encore trop ? Les mots,
   les repères (église, station, château d'eau) aident-ils à se repérer ?

## Après les retours (5 novembre 2026)

*Vu à l'écran par l'assistant, seul* : l'arrachage d'un toit (l'étage éclate
vers le ciel), les Repris dans une ruine de jour et de nuit, la nuit
éclaircie, le panneau du sac (ouvert par I) et celui de l'établi, les collines
boisées. *Vérifié par sonde* : manger une eau fait passer la faim de 28 à 53 ;
une cachette occupée fait sortir un Repris. *Jamais tenu à la manette* : Y
pour le sac, A pour manger.

1. **L'arrachage** : le tremblement d'une seconde suffit-il pour comprendre
   et sortir ?
2. **Les cachettes occupées** : est-ce une bonne surprise, ou injuste quand on
   s'y jette en plein Balayage ?
3. **Les Repris dehors** : effrayants, ou faciles à éviter ?
4. **Le sac** : Y à la manette, choisir à la croix, A pour manger. Est-ce
   rapide quand on est pressé ?
5. **La nuit** : maintenant assez claire pour jouer, mais encore inquiétante ?

## La campagne (5 novembre 2026)

*Vu par l'assistant* : la carte de loin (ville, fermes, bosquets, collines
au hasard) et une ferme au niveau du sol. *Mesuré* : 0 problème, 204
emplacements de cachettes, 307 contenants, 103 bâtiments. *En jeu, seul* : le
premier jour, 25 Repris dorment sous un toit, 14 sont dehors en ville et 13
dans la campagne.

1. **Aller dans la campagne** : est-ce que ça vaut le trajet (fermes à
   fouiller) ? Est-ce trop vide entre les fermes ?
2. **L'Œil en biais** : se cacher dans une ferme est-il trop facile ?
3. **Le nombre de Repris** : assez le premier jour ? Trop vers le jour 5 ?

## La traque de l'Œil et la nouvelle carte (5 novembre 2026)

*Vu par l'assistant* : la ville d'en haut (rues décalées, maisons en
désordre), la ferme de la Planque seule dans son coin. *Mesuré* : 0 problème,
184 emplacements de cachettes, 257 contenants. *En jeu, seul, par sonde* :
immobile sous le regard, il reste collé dessus et aspire en 2 s ; en courant
sur le côté dès qu'il frôle, on s'échappe le premier jour (de justesse depuis
le centre) et il reprend son trajet. *Jamais vu par un humain* : est-ce que
la poursuite fait peur ou paraît injuste.

1. **Se faire voir exprès le premier jour** et courir vers un abri : est-ce
   qu'on a le sentiment de pouvoir s'en sortir ?
2. **Fuir sur le côté** plutôt que tout droit, loin de la ville : est-ce que
   ça se comprend en voyant la tache de lumière ?
3. **Les jours suivants** : vers le jour 5, sent-on qu'il vise mieux ?
4. **Le départ** : la Planque au fond de la campagne, est-ce trop loin de la
   ville (environ 20 secondes de course jusqu'au bord de la ville) ?
5. **La ville** : moins « tracée à la règle » ? Les terrains vagues se
   remarquent-ils ?
6. **La campagne** : les hameaux et maisons seules donnent-ils envie
   d'explorer ?

## Les petites cachettes (5 novembre 2026)

*Vu à l'écran par l'assistant* : un buisson dans le coin d'une haie, une tôle
contre une palissade. *En jeu, seul, par sonde* : on entre dans un buisson et
sous une tôle ; chaque voiture a une invite de chaque côté. *Jamais tenu à la
manette* : entrer par le côté passager.

1. **Les voitures** : entrer par n'importe quel côté, et ressortir du même
   côté.
2. **En fuyant le regard** : trouve-t-on maintenant une cachette à quelques
   secondes, partout en ville ?
3. **Trop facile ?** On est passé à environ 140 cachettes par jour (40 %).
   A-t-on encore peur ? Faut-il en enlever, ou en remettre ?
4. **Le buisson et la tôle** : se reconnaissent-ils de loin comme des
   cachettes ?

## Voir dehors, arrachages au hasard (5 novembre 2026)

*En jeu, seul, par sonde* : depuis une voiture, on voit dehors avec le rappel
en bas. Une cachette arrachée avec moi dedans m'a éjecté, avec un répit de
2 s pendant lequel la jauge est restée à 0. Un toit arraché avec moi dessous
affiche « Le toit tremble : sors vite ! » et tremble 3,5 s. Pendant un
Balayage du jour 1, une cachette au hasard est partie en plus de la mienne.
*Jamais vu par un humain* : est-ce juste ou frustrant ?

1. **Caché** : la vue depuis un buisson, une tôle, une voiture. Gêne-t-elle,
   ou est-ce mieux que l'écran noir ?
2. **Éjecté** : comprend-on tout de suite qu'il faut courir ? 2 s suffisent-elles ?
3. **Le toit qui tremble** : a-t-on le temps de sortir de la maison ?
4. **La ville qui s'abîme** : vers le jour 5, reste-t-il assez de toits ?

## La difficulté de la Banlieue (5 novembre 2026)

*Vérifié en jeu, seul* : 140 cachettes le matin, dont 100 en ville.
*Vérifié par le calcul* : 20 toits arrachés au hasard au jour 10, en plus de
ceux où l'on s'est abrité. *Jamais joué par un humain* : est-ce assez dur ?

1. **Le premier jour** : trouve-t-on une cachette sans trop chercher, sans
   que ce soit gratuit ?
2. **Vers le jour 5** : la traque fait-elle vraiment peur ? A-t-on déjà été
   aspiré en courant ?
3. **S'ennuie-t-on** à un moment de la journée ? Si oui, quand ?

## L'Œil qui s'impatiente (5 novembre 2026)

*Vérifié par le calcul* : 32 toits arrachés au hasard au jour 8, 60 au jour 12.
*Vérifié en jeu, seul* : 140 cachettes au jour 1, 84 au jour 13 ; un Balayage
tourne sans erreur. *Jamais vu* : le message du jour 9 (il faut jouer
jusque-là), ni la ville réelle au jour 12.

1. **Vers le jour 8** : la ville est-elle assez abîmée pour qu'on le sente, sans
   être vide ?
2. **Au jour 9** : le message « L'Œil s'impatiente » donne-t-il envie de se
   presser ?
3. **Si on traîne jusqu'au jour 12** : est-ce vraiment dur ? C'est voulu.

## L'Œil vivant (5 novembre 2026)

*Vu à l'écran par l'assistant* : l'Œil ouvert (iris, fibres, veines, reflet),
la couture brûlante quand il est fermé, et en jeu, son ouverture au premier
Balayage, tourné vers son faisceau. *Jamais vu* : un clignement, ni la
fermeture en mouvement (seulement les états ouvert et fermé).

1. **Le réveil** : le voir s'ouvrir au signal fait-il peur ? Est-ce un bon
   signe pour se cacher ?
2. **Fermé** : la couture se voit-elle de partout dans la ville ?
3. **Les clignements** : trop souvent, pas assez ?

## Le laser, la jointure, les éclairs (5 novembre 2026)

*Mesuré en jeu* : le regard de l'Œil et son faisceau sont alignés à 0,2° près,
et le faisceau part juste devant la pupille. *Vu à l'écran* : la jointure
courbe quand il est fermé, les éclairs plus vifs quand il est ouvert.
*Jamais vu en mouvement* : la lueur qui court dans les éclairs, la braise qui
respire.

1. **Le laser** : sort-il bien de l'œil, de partout dans la ville ?
2. **Fermé** : la jointure est-elle plus belle que la droite jaune ?
3. **Les éclairs** : l'animation est-elle trop rapide, trop lente,
   ou fatigante à la longue ?

## La quête : la radio et le château d'eau (5 novembre 2026)

*En jeu, seul, par sonde* :
- la lampe sort de l'atelier de la station-service et l'antenne de la sacristie
  de l'église ;
- une fois la lampe déposée, la radio se construit ;
- l'objectif passe à « Attendre la nuit », et la nuit, Mara parle en
  sous-titres ;
- au jour 2, poser l'antenne seul attend, puis régler la radio 3 s après
  valide l'étape.

*Jamais fait* : **grimper le château d'eau** (le pont ne peut pas faire
grimper le personnage ; ce sont de vraies échelles Roblox, mais personne ne
les a essayées), et le faire **à deux vrais joueurs**.

1. **L'objectif en haut à gauche** : se lit-il bien, sans gêner ?
2. **La lampe** : la trouve-t-on avec l'indice « l'atelier de la
   station-service » ?
3. **La nuit, Mara** : les sous-titres vont-ils assez lentement pour lire en se
   battant ?
4. **Le château d'eau** : grimper les deux échelles à la manette, puis tenir X
   5 s tout en haut, à découvert. Est-ce tendu ?
5. **À deux** : l'un en haut, l'autre à la radio de la Planque. Les 25 s de
   fenêtre suffisent-elles pour se synchroniser à la voix ?
6. **Réécouter** : à la radio de la Planque, tenir X sur « Réécouter la radio »
   rejoue le dernier message de Mara (vérifié seul, par sonde).
7. **Le journal** : Y, puis R1. On y relit la quête et les messages de Mara,
   le plus récent en haut. Le stick droit fait-il bien défiler ? (Vu à
   l'écran, seul ; le défilement à la manette n'a jamais été essayé.)

## Les textes, le Ventre, le cocon, les épaves (6 novembre 2026)

*Vu à l'écran par l'assistant, seul* :
- le « Jour 9 » en grand ;
- les bords rouges et « Ne bouge pas… » ;
- l'aspiration, caméra tournée vers l'Œil ;
- le Ventre fermé et sombre, un souvenir lu lettre par lettre ;
- un toit avalé en spirale vers la Fissure.

*Vérifié par sonde* :
- on arrive dans le Ventre ;
- le recrachage attache dans un cocon loin de la Planque, et on ne s'y
  détache pas seul ;
- 6 épaves tombent sur le sol, fouillables.

*Vu ensuite en jeu, seul (défaite coupée le temps de l'essai)* :
- la vue par l'Œil nette, la zone rouge au signal ;
- le cocon de l'extérieur, la nuit ;
- l'enchaînement vrai « repéré → aspiré ».

*Jamais vu* : **la libération par un ami** (il faut deux joueurs).

1. **Les textes** : plus beaux ? La radio lettre par lettre se lit-elle assez
   vite ?
2. **Vu par l'Œil** : les bords rouges et le murmure font-ils peur ? Trop ?
3. **Aspiré** : l'animation est-elle impressionnante ? Le noir dure-t-il trop ?
4. **Le Ventre** : s'ennuie-t-on ? Trouve-t-on les six souvenirs ?
5. **L'Oculus** (X au bord de la pupille) : voit-on bien la ville, la zone en
   rouge, les amis en vert ? Est-ce utile pour les prévenir à la voix ?
6. **Recraché la nuit** : aller détacher un ami au milieu des Repris,
   est-ce tendu ? Le trait de lumière se voit-il de la Planque ?
7. **Les épaves** : donnent-elles envie de sortir la nuit ?
8. **Arrivée dans le Ventre** : après « Il t'a pris », la vue doit être DANS
   le Ventre, avec en bas « Encore N Balayages avant la nuit ». (Dans les
   parties lancées par l'assistant, la caméra de Roblox ne suit pas le
   personnage : ce retour n'a jamais pu être vu.)
9. **Faire cligner l'Œil** : dans le Ventre, pendant un Balayage, frapper un
   pilier (R2) six fois. L'Œil doit fermer les paupières et son regard
   s'éteindre 1,5 s. Est-ce utile pour sauver un ami poursuivi ? Trop facile ?
   (Vérifié seul, par sonde : le regard s'éteint 1,5 s, une seule fois par
   Balayage.)

## Les sons (6 novembre 2026)

*Vérifié en jeu, seul* :
- les 13 sons se chargent chez le joueur, et le vent joue le jour ;
- au signal, le coup sourd, le grondement et les paupières démarrent
  ensemble, puis le Balayage fait taire le grondement et monter le
  bourdonnement du regard (volume plein quand il passe près) ;
- le murmure part quand il te voit, le cri quand il cligne, le craquement
  dès qu'un toit tremble, puis le souffle de l'aspiration.

*Jamais entendu* : l'assistant ne peut pas écouter.

1. **Chaque son** : lequel est raté, trop fort, trop faible, pas dans
   l'ambiance ? (Leur liste et leur nom sont dans `docs/ASSETS.md`.)
2. **Le regard qui approche** : entend-on venir le faisceau avant de le voir ?
3. **Le cri de l'Œil** quand on le fait cligner : assez douloureux ?
4. **L'ambiance** : le vent du jour et le drone de la nuit fatiguent-ils à la
   longue ?

## Le survivant, étape 3 de la quête (7 novembre 2026)

*Vérifié en jeu, seul, par sondes* :
- à l'aube du jour 4, Élie attend dans son refuge ; la nuit d'avant, Mara dit
  où il se cache (texte vu à l'écran) ;
- maintenir X sur lui : il suit, en boitant ; il a contourné une maison dans
  les pas de son guide et s'est arrêté à 7 studs de lui ;
- X sur lui : il va à la cachette libre la plus proche et y entre (en 4 s) ;
  X sur lui caché : il ressort et suit celui qui l'a fait sortir ;
- laissé dehors pendant un Balayage, l'Œil l'a pris en 12 s ; la nuit, Mara
  dit qu'il a été recraché et où il se cache maintenant (un autre refuge) ;
  au matin, il y attend ;
- à la Planque, la quête avance (« Survivre ») ; la nuit, il mange un plat de
  la réserve.

*Jamais vu* : un vrai guide qui marche (le pont ne peut que téléporter) ;
la sortie d'un refuge, porte comprise ; l'escorte entière d'un bout à
l'autre de la carte.

1. **Le trouver** : l'indice de Mara suffit-il ? Trop facile, trop dur ?
   (Refuges possibles : supérette, église, station-service, une ferme d'un
   hameau à l'est.)
2. **Sortir du refuge** : il doit suivre son guide par la porte. Reste-t-il
   coincé contre un mur ? (Il marche dans tes pas : passe par la porte, pas
   par une fenêtre.)
3. **L'escorte** : sa lenteur rend-elle le trajet tendu, ou pénible ? Combien
   de temps pour le ramener ?
4. **Le cacher** (X sur lui) : est-ce clair ? L'invite de la cachette passe-t-
   elle avant la sienne quand tu veux te cacher toi-même ?
5. **À 3 ou 5** : qui le guide ? Un autre peut-il le faire sortir d'une
   cachette et le reprendre ?
6. **Sa silhouette** (photo : `docs/images/elie.jpg`) : le reconnaît-on de
   loin ?

## Le fumigène, étape 4 (7 novembre 2026)

*Vérifié seul dans Studio, par sondes* :

- les étagères du fond de la supérette donnent des produits chimiques ;
- l'étape s'ouvre à l'aube du jour 6 ; cette nuit-là, Élie a mangé puis fait
  2 fumigènes (2 produits et 2 ferrailles pris dans la réserve) ; X sur lui
  les donne, un par appui ; sans repas, il n'a rien fabriqué ;
- un fumigène lancé à plat tombe à 39 studs ; le nuage coupe la vue de l'Œil
  vers son centre, pas à côté ;
- poursuivi pendant un Balayage, jeté à ses pieds : la jauge tombe à zéro ;
  l'Œil sort au bord du nuage, en fait le tour 7 s, puis repart à son râteau.

*Jamais vu* : lancer à la manette (L2), la boîte qui vole vue par un ami, sortir
du nuage sous ses yeux pendant qu'il guette.

1. **L2** : le fumigène part-il là où tu regardes, à la bonne distance ?
2. **Le nuage** (photo : `docs/images/fumee.jpg`) : assez épais pour qu'on *croie*
   qu'il cache ? Trop gros, trop petit ?
3. **La ronde de l'Œil** : 7 secondes, est-ce assez tendu ? Arrive-t-on à
   s'échapper quand il repart ?
4. **Sortir trop tôt** : se fait-on reprendre ? Est-ce juste ?
5. **L'économie** : deux fumigènes par nuit au plus, est-ce trop, pas assez ?
   Trouve-t-on assez de produits chimiques ?
6. **La réserve de la supérette** : la trouve-t-on avec l'indice de Mara ?
