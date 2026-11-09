<!-- Copie des notes communes de Josh (C:\Users\boill\.claude\CLAUDE.md), pour qui n'a pas sa machine. Copiée le 9 novembre 2026 : si l'original change, recopier. -->

# Notes communes à tous les projets de Josh

Lues dans **chaque** projet. Ce qui est propre à un jeu vit dans le
`CLAUDE.md` de son dossier ; ici, seulement ce qui vaut partout.

Les jeux sont rangés dans `C:\Users\boill\OneDrive\Desktop\JR Project\`, un
dossier par jeu. Le premier, **Arena** (PvP d'arène à classes), est la
référence : son `CLAUDE.md` contient le détail et l'histoire de chaque leçon
ci-dessous. En cas de doute sur la façon de faire, le lire.

## Josh et la façon de travailler

- **Toujours en français**, simplement. Josh n'est pas développeur : il
  joue, juge si c'est amusant, et publie. Tout le code, la structure, les
  tests et la construction dans Studio sont pour l'assistant.
- **Josh joue à la manette.** Tout jeu doit marcher à la manette dès le
  départ, panneaux compris, pas en fin de projet.
- **La conception se fixe AVANT le code**, par des questions à Josh. Une
  question de conception se tranche avec lui, jamais en silence dans le code.
  Une décision prise sans lui se note dans `docs/DECISIONS.md`.
- **Commencer par la plus petite version jouable**, puis ajouter étape par
  étape. Si ce n'est pas amusant en petit, ça ne le sera pas en grand.
- **Un test en solo dit qu'une mécanique fonctionne, jamais qu'elle est
  amusante.** Après chaque mécanique vérifiée, dire à Josh quoi regarder en
  jouant, dans quel ordre, et tenir ces points dans `docs/A-TESTER.md`.
- **Être honnête sur ce qui n'a pas été vérifié** : « vérifié par le calcul »,
  « vérifié seul », « jamais vu à l'écran » sont trois choses différentes.
- **Git** : commit et push seulement quand Josh le demande.

## Le squelette d'un projet Roblox (celui d'Arena)

- **Rojo** synchronise le dépôt vers Studio ; **Rokit** fixe les versions des
  outils ; **StyLua** formate (tabulations, 100 colonnes) ; **Selene** analyse ;
  **Lune** fait tourner les tests sans Studio ; **GitHub Actions** relance tout à
  chaque push.
- `src/shared` (logique pure et données), `src/server` (autorité),
  `src/client` (interface et entrées), `tests/` hors du projet Rojo, `tools/`
  pour les recettes de maps (hors Rojo et hors Selene).
- **Un seul point d'entrée par côté** (`Bootstrap.server.luau`,
  `Bootstrap.client.luau`), qui appelle des modules.
- `--!strict` partout. Identifiants en anglais ; commentaires en français
  **sans accents** dans le `.luau` ; les chaînes affichées aux joueurs **avec**
  leurs accents.
- Un commentaire dit **pourquoi**, pas quoi.

## Les règles d'architecture qui ont le plus servi

- **La logique pure ne touche à aucune API Roblox**, et **ne requiert rien** :
  ses dépendances arrivent en argument (`Module.f(config, ...)`). Roblox
  résout les `require` par instances et Lune par chemins, donc un module pur
  qui en requiert un autre ne se charge pas des deux côtés.
- **Tous les chiffres dans `Config.luau`**, chacun avec la raison de sa valeur.
  Un chiffre en dur est un bug, même juste. **Un repli caché (`or 1`) aussi** :
  la valeur devient illisible depuis `Config`.
- **Le serveur est l'autorité** ; le client affiche et envoie des intentions.
  Les remotes ont un garde-fou contre l'inondation.
- **Une règle que seuls les tests appellent ne s'applique pas.** C'est la panne
  la plus chère d'Arena, vue quatre fois : une table de `Config` ou une
  fonction pure testée mais lue par aucun service. Parades : un test qui
  refuse toute fonction pure non appelée dans `src/` ; un serveur qui refuse
  de démarrer quand `Config` annonce ce qu'aucun service n'exécute ; et des
  tests qui vérifient ce que le jeu FAIT, pas qu'un chiffre de `Config` est
  cohérent avec un autre.
- **Deux réglages qui doivent s'accorder se testent ensemble** (touches de
  clavier et boutons de manette sans collision, formats et tailles d'équipe…).
- **Les mesures d'interface se DÉDUISENT du contenu**, jamais recopiées.
- **Un service mesure son résultat au lieu de croire son appel**, et un
  `pcall` dont on jette l'erreur est un aveu qu'on ne saura jamais pourquoi.
- **Un refus doit fermer, pas figer** : un panneau verrouillé doit laisser
  l'écran fermé.

## Studio par le serveur MCP

- **`execute_luau` a son propre cache de modules** : un `require` depuis le
  pont rend une copie neuve, pas celle du jeu, et garde l'ancienne version
  d'un module modifié (cache indexé sur l'instance). Pour piloter le jeu,
  **injecter un `Script`** (ou un `LocalScript`) puis le détruire ; pour un
  module modifié, en `require` un clone.
- **La place peut être en retard sur le dépôt, sans rien dire** (Rojo
  déconnecté, ou pas lancé du tout). La vérification en un appel : comparer la
  **taille** de chaque `Source` contre `wc -c`. Rattrapage : `python -m
  http.server` sur `127.0.0.1` + `HttpService:GetAsync`, puis **remettre
  `HttpEnabled` comme il était**.
- **Rojo peut créer des doublons** (deux RemoteEvent du même nom = client et
  serveur qui se parlent dans le vide). Lister les enfants avant de conclure.
- **Rojo écrase** : le code s'écrit dans le dépôt, jamais dans Studio. Une
  **partie en cours garde l'ancien code** : arrêter et relancer.
- **`Source` est coupé à 200 000 caractères** depuis le pont ; garder les gros
  modules de données sous cette taille si on doit les recharger.
- **`loadstring` est fermé** au pont : charger une recette par un
  `ModuleScript` jetable (`Source`, `require`, `Destroy`).
- **`screen_capture`** : ne montre pas les `BillboardGui` ; peut rendre une 3D
  vide si Studio est en arrière-plan. **Poser un témoin** avant de conclure
  qu'un objet ne s'affiche pas. Les paramètres de caméra de `screen_capture`
  marchent en mode édition ; un `CFrame` de caméra posé par code, non.
- **Les connexions prises depuis `execute_luau` survivent à l'appel** et se
  battent contre les suivantes : utiliser un vrai `LocalScript` injecté.
- **`user_keyboard_input` envoie les boutons de manette comme du clavier** :
  reconnaître la manette au **nom** du bouton (`Button*`, `DPad*`), pas à
  l'origine de l'entrée. La navigation de Roblox dans les menus ne tourne
  qu'avec une vraie manette : à faire vérifier par Josh.
- **`ReserveServer` ne marche pas dans Studio** (jeu publié seulement).
- **Générateurs** : `generate_mesh` et `generate_material` rendent des
  **propositions**, pas des réussites — regarder avant de garder ;
  `generate_mesh` se limite en parallèle (appeler un par un) ;
  `generate_material` ne marche qu'en mode **édition**, range ses variantes
  dans `MaterialService.AssistantMaterials`, et dessine le **sujet** qu'on
  nomme (demander une surface, interdire l'architecture). `search_asset` n'est
  pas une recherche par le sens.
- **Ce qui est généré n'existe que dans la place** : noter les identifiants
  d'assets dans le dépôt, c'est la sauvegarde.

## Les pièges du moteur Roblox

- **Géométrie** : un `Ball` est une sphère du **plus petit** côté ; un
  `Cylinder` prend sa longueur sur `Size.X` et son diamètre sur le plus petit
  des deux autres côtés. **L'avant est -Z.** Un angle d'Euler ne dit pas où
  pointe une part : mesurer `LookVector` / `UpVector`, et nommer les angles
  par leur effet, convertis à **un seul** endroit.
- **Un test de direction reproduit le calcul de Roblox** et vérifie d'abord
  qu'il retrouve un témoin mesuré en jeu ; comparer deux conventions entre
  elles ne teste rien.
- **Personnages** : plus de `Motor6D` dans le corps moderne, utiliser
  `IKControl` (piloter les jambes casse la marche). Un `Humanoid` mort ne se
  soigne pas, il se reconstruit. Une sonde relit `player.Character` à chaque
  mesure. Une articulation posée sur un membre se détruit avec ce qu'elle
  tient.
- **Physique** : un chiffre nommé en studs doit donner des studs (hauteur :
  `v = racine(2 g h)`) ; l'`Humanoid` mange les coups de vitesse horizontaux,
  utiliser un `LinearVelocity` **avec la limite de force coupée**.
- **Avatar** : le type R15 est un réglage de place ; retirer les accessoires
  modernes demande `SetAccessories({}, true)` ; `BodyTypeScale` et
  `ProportionScale` à zéro pour un corps standard ; prendre les proportions de
  référence sur un rig standard, jamais sur l'avatar qu'on a sous la main.
- **Interface** : `AbsolutePosition` et `AbsoluteSize` ne se comparent pas
  entre repères ; la barre du haut se dessine par-dessus ; un `ScreenGui`
  désactivé ne met plus à jour sa taille ; brancher le suivi de fenêtre dans
  `build()` ; un `UIStroke` sur un bouton cerne le texte (`ApplyStrokeMode =
  Border`). **Roblox déplace la sélection manette tout seul** quand le bouton
  sélectionné est détruit : garder des noms stables aux boutons et remettre la
  sélection en place.
- **Son** : un son modéré ou du mauvais type échoue **en silence** (précharger
  et nommer ce qui manque au démarrage) ; `Sound.TimeLength` vaut 0 au début
  (nettoyer sur `Ended`). **Je ne peux pas écouter** : choisir sur le nom et la
  durée, et le dire à Josh.
- **Lumière et maps** : soleil rasant (10–22°) pour que les ombres existent,
  mais **perpendiculaire à l'axe des camps** pour ne favoriser personne ;
  `Lighting` et `MaterialService` sont des réglages de place, donc chaque map
  pose les siens ; le brouillard court est l'ancien `FogEnd`, qui ne marche
  qu'**sans** `Atmosphere` ; `Clouds` vit sous le Terrain ; le ciel est une
  texture ; `Glass` reflète le ciel ; `CorrodedMetal` impose sa couleur ;
  détruire la `Baseplate` et le `SpawnLocation`.
- **Une map ne se juge pas à l'œil, elle se mesure au rayon** (lignes de tir
  entre départs, sol sous chaque départ, couvert du centre, pente des rampes),
  et **la recette se mesure elle-même** à chaque construction. Les sondes
  respectent les collisions (`RespectCanCollide`) et la portée du jeu. Un
  rayon trouve de la géométrie, pas ce qu'on voit (sauter les parts
  invisibles). Si le combat parle de « couvert », il doit demander une **ligne
  de vue** comme les sondes.
- **Les maps se sauvegardent en recette** dans `tools/` : une map n'est ni
  dans Git ni dans Rojo, et une fausse manœuvre l'efface sans trace. Les
  recettes détruisent ce qui répond au **contrat** de nommage, pas une liste
  de noms qui se périme.
- **Une matière se juge sur la map, de près ET de loin dans la même image**,
  à la couleur où elle ira, par rangée avec le témoin en premier ;
  `StudsPerTile` est propre à chaque matière.
- **Variété** : elle doit se voir sur la silhouette (trois sphères empilées
  restent une sphère) ; un accent de couleur dépensé partout ne désigne plus
  rien.

## Argent et règles de Roblox

- **Les tirages payants (même indirectement)** : afficher chaque résultat et
  sa probabilité avant l'achat, total 100 %, un lien qui porte un **mot** ;
  tout tirage doit donner quelque chose ; une garantie s'explique chiffrée ;
  couper la vente si `ArePaidRandomItemsRestricted`. À prévoir dès la
  conception de l'écran.
- **Un jeu ne peut pas créer de serveur privé** ; `ReserveServer` est ce qui
  existe.
- **Si la lecture d'un profil échoue, ne jamais écrire** : un profil illisible
  n'est pas un profil vide.
- **Une récompense se demande** : qui peut provoquer cette issue exprès, et
  avec combien de comptes ?
