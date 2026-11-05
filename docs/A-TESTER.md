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
