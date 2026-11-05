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
