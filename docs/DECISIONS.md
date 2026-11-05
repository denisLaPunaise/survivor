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
