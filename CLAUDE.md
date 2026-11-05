# Survivor — notes pour l'assistant

Nom de code du dépôt : **Survivor**. Titre de travail du jeu : **Sous le
Regard**. Jeu de survie coopératif Roblox, 3 à 5 amis sur un serveur privé, à
la manette, à la première personne. Le jour, on fouille une ville en ruine
pendant qu'un Œil géant balaie les rues depuis le ciel, et il faut se cacher ;
la nuit, on défend sa Planque contre ceux qu'il a aspirés.

**Le concept complet est dans [docs/CONCEPT.md](docs/CONCEPT.md)**, chaque
point marqué *décidé*, *proposé* ou *ouvert*. Un point *décidé* ne change
qu'avec Josh. Une décision prise sans lui se note dans
[docs/DECISIONS.md](docs/DECISIONS.md).

Les notes communes à tous les jeux de Josh sont dans
`C:\Users\boill\.claude\CLAUDE.md` ; le détail et l'histoire de chaque leçon
sont dans `..\Arena\CLAUDE.md`. Ce fichier ne contient que ce qui est propre à
Survivor.

## Qui fait quoi

| | Rôle |
| --- | --- |
| L'assistant | Tout le code Luau, la structure, la configuration, les tests, la construction dans Studio (serveur MCP), le visuel |
| Josh | Les parties avec ses amis, le jugement sur le plaisir de jeu, la publication |

Après chaque mécanique vérifiée, dire à Josh quoi regarder en jouant et dans
quel ordre, et le tenir dans [docs/A-TESTER.md](docs/A-TESTER.md).

## Les principes à ne jamais casser

1. **Bien caché, on est en sécurité.** L'Œil ne triche jamais : être vu, c'est
   une ligne de vue réelle entre l'Œil et le joueur, mesurée au rayon comme les
   sondes. Une cachette « marquée » n'est dangereuse que parce que l'Œil
   l'arrache, à la vue de tous.
2. **La manette décide.** Une action qui ne rentre pas dans
   `Config.controls` se sacrifie. Un test refuse toute collision.
3. **Aucun achat ne donne de puissance**, sauf le revive (une fois par partie et
   par équipe). Jamais de relance ni d'amélioration payante : ce serait un
   tirage payant.
4. **Aucun cumul d'améliorations ne casse le jeu**, même pour un joueur
   chanceux : chaque valeur se règle sur le nombre de niveaux atteints, avec un
   plafond par statistique, et une simulation le vérifie.
5. **Une sauvegarde illisible n'est pas une sauvegarde vide** : si la lecture
   échoue, on n'écrit jamais.
6. **Beau dès la première version.** Pas de blocs gris (décidé par Josh).

## Architecture

Celle d'Arena, sans changement.

```
src/shared/     ReplicatedStorage.Survivor       — logique pure et données
src/server/     ServerScriptService.Survivor     — autorité
src/client/     StarterPlayerScripts.Survivor    — interface et entrées
tests/          suites Lune, hors du projet Rojo
tools/          recettes de maps, hors Rojo et hors Selene
docs/           concept, décisions, points à tester
```

- **La logique pure ne touche à aucune API Roblox et ne requiert rien** : ses
  dépendances arrivent en argument.
- **Tous les chiffres dans `src/shared/Config.luau`**, chacun avec sa raison.
  Une table n'y entre que le jour où un service l'exécute (seule exception en
  cours : `controls`, notée dans le fichier).
- **Un seul point d'entrée par côté** : `Bootstrap.server.luau` et
  `Bootstrap.client.luau`.
- **Tout remote passe par `RemoteGuard.wrap`.**
- **Le serveur est l'autorité** ; le client affiche et envoie des intentions.

## La frontière Rojo / la place

| Propriétaire | Ce qu'il possède |
| --- | --- |
| Rojo (ce dépôt) | `ServerScriptService`, `ReplicatedStorage`, `StarterPlayer` |
| La place (Studio) | `Workspace` — la ville se construit, elle ne se code pas |

Ne jamais ajouter `Workspace` à `default.project.json`. **La ville se sauvegarde
en recette** dans `tools/` : toute construction dans Studio repart avec son
script, sinon elle n'est pas sauvegardée. Les identifiants des assets générés
(maillages, matières) se notent dans le dépôt.

La place Studio s'appelle **Survivor**.

## Conventions

- Identifiants en anglais ; commentaires en français **sans accents** dans le
  `.luau` ; chaînes affichées **avec** accents ; Markdown avec accents.
- `--!strict` partout. Tabulations, 100 colonnes, StyLua.
- Un commentaire dit **pourquoi**, pas quoi.
- Préfixe console : `[Survivor]`.

## Les commandes

```sh
rokit install                    # outils aux versions du projet
rojo serve                       # synchronise vers Studio
lune run tests/run               # tests de logique pure
stylua .                         # formate
selene generate-roblox-std       # une fois, definitions pour Selene
selene src                       # analyse statique
rojo build --output survivor.rbxl
```

GitHub Actions relance formatage, analyse, tests et build à chaque push.

## Où on en est

- **5 novembre 2026** : concept fixé avec Josh, projet monté (outils, CI,
  `Config`, points d'entrée, tests). Aucune mécanique branchée.
- **5 novembre 2026, première version jouable** : la journée, l'Œil (signes,
  Balayages en râteau ou spirale, ligne de vue, jauge, aspiration), les
  cachettes fragiles qui changent chaque matin et que l'Œil arrache, deux
  cachettes solides, la fouille et le sac, la Planque (cave) et sa réserve, la
  défaite qui fait tout recommencer, la première personne, la course et la
  glissade. Le quartier est construit par `tools/BuildBanlieue.luau`.
- **5 novembre 2026, première passe visuelle** : la Fissure en déchirure
  noire, l'Œil sombre qui suit le regard (`SkyView`), les débris aspirés,
  poteaux et fils, encadrements, gouttières, boîtes aux lettres, arbres
  générés (`docs/ASSETS.md`, modèle dans `ServerStorage.SurvivorModeles`).
- **5 novembre 2026, la Banlieue en grand** (puis remplie : 800 × 800, 75 maisons, rangées du centre et du bord, jardins habités) : d'abord 800 × 640, 39 maisons (dont à
  étage), bande centrale (supérette, basket), intérieurs meublés, voitures
  générées, le lointain dans la brume ; le Balayage couvre une zone autour
  d'un joueur. La recette tourne en tâche de fond (`task.spawn`, rapport en
  attribut `RapportRecette`) : elle dépasse le délai d'un appel au pont.
- **Reste à rendre beau** : les sacs poubelle, la lumière en Future (réglage
  manuel de Josh).
- **5 novembre 2026, points 1 à 4** : l'Œil arrache les toits des bâtiments
  où l'on s'est abrité (`HidingService`) ; les Repris (`ReprisService`,
  `CombatService`) endormis le jour, à l'assaut la nuit, le joueur à terre et
  relevé ; la faim, le repas du soir et l'établi de la Planque
  (`PlanqueService`, `BuildPanel`) ; quatre intérieurs, maisons qui
  racontent, trois repères. Détail dans `docs/DECISIONS.md`.
- **Ensuite** : ce que Josh dira après avoir joué ; puis la jauge de
  Visibilité de la Planque, la construction libre sur grille, les autres
  Repris (Rampant, Hurleur, Guetteur, Brute), les quêtes.

## Construire la ville depuis le pont

`HttpService` ne peut pas joindre `127.0.0.1` depuis le pont (« not in the
Assistant HTTP allowlist », vu le 5 novembre 2026). Pour lancer une recette :
la copier dans `src/server/RecetteJetable.luau`, laisser Rojo la synchroniser,
en `require` un CLONE depuis `execute_luau`, l'appeler, puis **supprimer la
copie** du dépôt. Elle ne doit jamais être commitée.

`Lighting.Technology` ne se lit ni ne s'écrit depuis le pont.

Les touches simulées (`user_keyboard_input`) n'atteignent pas les
`ProximityPrompt`, et `InputHoldBegin` depuis le pont non plus : les sondes
passent par `HidingService.tryEnter` et `LootService.trySearch`, qui suivent le
même chemin que les invites.
