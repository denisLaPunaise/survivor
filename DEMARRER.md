# Démarrer sur Survivor — la fiche d'arrivée

Tu arrives sur le projet : un ami de Josh, ou un autre compte Claude. Lis
cette fiche en entier, puis les fichiers qu'elle cite dans l'ordre donné.
C'est tout ce qu'il faut.

---

## 1. Le jeu en une minute

**Sous le Regard** (nom de code du dépôt : *Survivor*) est un jeu de survie
coopératif sur Roblox. On y joue de 3 à 5 amis, sur un serveur privé, à la
manette et à la première personne.

- **Le jour**, on fouille une ville en ruine. Un Œil géant balaie les rues
  depuis le ciel. S'il te voit, il t'aspire. Il faut donc se cacher dans des
  buissons, des voitures ou des maisons.
- **La nuit**, on défend sa Planque, une ferme isolée, contre les Repris : ceux
  que l'Œil a aspirés.

**Où on en est (9 novembre 2026)** : le chapitre 1 (la Banlieue) est complet,
avec la quête de 5 étapes jusqu'au Gardien, six sortes de Repris, la
construction libre et la jauge de Visibilité. Tout a été testé seul dans
Studio. Il n'a encore jamais été joué à plusieurs, ni à la manette. Le
détail jour par jour est dans [CLAUDE.md](CLAUDE.md), section « Où on en est ».

## 2. Qui décide quoi

- **Josh** est le chef du projet. Il n'est pas développeur : il joue, juge si
  c'est amusant, et publie. **Il parle français, simplement**, et joue à la
  manette.
- **Les questions de conception se tranchent avec Josh, avant le code.** Un
  point marqué *décidé* dans [docs/CONCEPT.md](docs/CONCEPT.md) ne change
  qu'avec son accord. Une décision prise sans lui se note dans
  [docs/DECISIONS.md](docs/DECISIONS.md).
- **Commit et push seulement quand Josh le demande.**

## 3. Ce qu'il faut lire, dans l'ordre

1. **[CLAUDE.md](CLAUDE.md)** : les règles propres au projet, l'architecture,
   l'avancement, et les pièges de Studio déjà rencontrés. Un compte Claude le
   charge tout seul ; un humain doit le lire.
2. **[docs/NOTES-COMMUNES.md](docs/NOTES-COMMUNES.md)** : les règles qui valent
   pour tous les jeux de Josh (façon de travailler, architecture, pièges du
   moteur Roblox). C'est une copie : l'original vit sur l'ordinateur de Josh,
   et un autre compte Claude ne le voit pas. **Un compte Claude doit le lire
   lui-même.**
3. **[docs/CONCEPT.md](docs/CONCEPT.md)** : tout le jeu, point par point.
4. **[docs/DECISIONS.md](docs/DECISIONS.md)** : ce qui a été tranché, et pourquoi.
5. **[docs/A-TESTER.md](docs/A-TESTER.md)** : ce qui reste à vérifier en jouant.
6. Au besoin : [docs/ASSETS.md](docs/ASSETS.md) (modèles et sons générés) et
   [tools/README.md](tools/README.md) (la recette de la ville).

Les notes de CLAUDE.md citent parfois `..\Arena\CLAUDE.md`. Arena est un
autre jeu de Josh, dans un autre dépôt. On peut s'en passer : l'essentiel de
ses leçons est dans `docs/NOTES-COMMUNES.md`.

## 4. Ce qu'il faut demander à Josh

- **L'accès au dépôt GitHub** `denisLaPunaise/survivor` (qu'il t'ajoute comme
  collaborateur).
- **L'accès à la place Roblox « Survivor »** (qu'il t'ajoute comme
  collaborateur dans Studio). La ville, la Planque et les modèles générés
  vivent **dans la place, pas dans Git**. Sans la place, voir la section 7.

## 5. Installer (Windows)

1. **Git** et **Roblox Studio**.
2. **Rokit**, le gestionnaire des outils : <https://github.com/rojo-rbx/rokit>
   (suivre son installation, puis rouvrir le terminal).
3. Récupérer le projet, puis installer les outils aux versions fixées dans
   `rokit.toml` :

   ```powershell
   git clone https://github.com/denisLaPunaise/survivor.git Survivor
   cd Survivor
   rokit install
   ```

4. **Le plugin Rojo dans Studio** :

   ```powershell
   rojo plugin install
   ```

5. **Vérifier** :

   ```powershell
   lune run tests/run
   ```

   Les tests doivent finir par « tout est coherent ».

## 6. Brancher le code sur Studio

1. Ouvrir la place **Survivor** dans Studio.
2. Dans le dossier du projet : `rojo serve`, et laisser la fenêtre ouverte.
3. Dans Studio : onglet *Plugins* → **Rojo** → **Connect**.
4. **Play** (F5), puis ouvrir la console (*View → Output*). On doit lire
   `[Survivor] Serveur démarré` puis `[Survivor] Client démarré`.

**Le code s'écrit toujours dans le dépôt, jamais dans Studio** : Rojo écrase
les scripts de Studio. Une partie déjà lancée garde l'ancien code : l'arrêter
et la relancer.

## 7. Si tu n'as pas la place

Elle se reconstruit, parce que tout ce qu'elle contient est sauvegardé dans le
dépôt :

1. Créer une place vide (Baseplate), la brancher avec Rojo comme en section 6.
2. **Les modèles générés** (arbres, voitures, têtes des Repris) : les recréer
   dans `ServerStorage.SurvivorModeles` à partir des identifiants de
   [docs/ASSETS.md](docs/ASSETS.md). Sans eux, la recette pose des arbres et
   des voitures en parts, et les Repris n'ont pas de crâne.
3. **La ville** : lancer `tools/BuildBanlieue.luau` en mode édition. C'est un
   module qui rend une fonction : le charger par un `ModuleScript` jetable,
   l'appeler, puis détruire le module. Elle détruit l'ancienne ville,
   reconstruit tout (quartier, campagne, Planque, Ventre, repaire du Gardien),
   puis se mesure et rend un rapport. Elle est longue : depuis le pont MCP, la
   lancer en tâche de fond et lire l'attribut `RapportRecette` de Workspace.
   Le détail est dans CLAUDE.md, « Construire la ville depuis le pont ».
4. Le rapport doit finir par « 0 problème(s) ».

## 8. Les règles à ne jamais casser

Le détail est dans CLAUDE.md. Les plus importantes :

1. **L'Œil ne triche jamais** : être vu, c'est une vraie ligne de vue, mesurée
   au rayon.
2. **Tout se joue à la manette.** Les touches sont dans `Config.controls`, et
   un test refuse toute collision.
3. **Aucun achat ne donne de puissance** (sauf le revive, une fois par partie).
4. **Tous les chiffres vivent dans `src/shared/Config.luau`**, chacun avec la
   raison de sa valeur.
5. **La logique pure** (`src/shared`) ne touche à aucune API Roblox et ne
   requiert rien. Ses dépendances arrivent en argument. Elle est testée par
   Lune dans `tests/specs`.
6. **Une règle que seuls les tests appellent ne s'applique pas** : le test
   `wiring` refuse toute fonction pure qu'aucun service n'utilise.
7. **Le serveur est l'autorité.** Tout remote passe par `RemoteGuard.wrap`.
8. **Beau dès la première version** : pas de blocs gris.

## 9. Avant de rendre son travail

```powershell
stylua .
selene src
lune run tests/run
rojo build --output survivor.rbxl
```

GitHub Actions relance tout cela à chaque push.

Ensuite :

- Dire à Josh **quoi regarder en jouant**, et l'ajouter à
  [docs/A-TESTER.md](docs/A-TESTER.md).
- **Être honnête** : « vérifié par le calcul », « vérifié seul dans Studio »
  et « jamais vu à l'écran » sont trois choses différentes.
- **Mettre à jour la section « Où on en est » de CLAUDE.md.**

## 10. Si deux personnes travaillent en même temps

- Chacun sur sa branche, et Josh décide de ce qui entre sur `main`.
- **Une seule personne à la fois touche à la recette de la ville**
  (`tools/BuildBanlieue.luau`) : c'est un très gros fichier, et deux
  modifications à la fois s'y mélangent mal.
- `src/shared/Config.luau` est touché par presque tout : faire des
  modifications petites, et récupérer `main` souvent.
