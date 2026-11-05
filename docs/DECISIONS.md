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
