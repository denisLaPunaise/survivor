# Survivor — *Sous le Regard*

Jeu de survie coopératif sur Roblox, de 3 à 5 amis, à la manette et à la
première personne. Le jour, on fouille une ville en ruine en se cachant d'un Œil
géant qui balaie les rues depuis le ciel ; la nuit, on défend sa Planque.

- Le concept complet : [docs/CONCEPT.md](docs/CONCEPT.md)
- Les notes de travail de l'assistant : [CLAUDE.md](CLAUDE.md)
- Ce qu'il faut regarder en jouant : [docs/A-TESTER.md](docs/A-TESTER.md)

---

## Installation

Les outils sont les mêmes que pour Arena, et déjà installés sur cette machine.
Sur une nouvelle machine, suivre les étapes 1 à 9 du `README.md` d'Arena, en
remplaçant le dossier `Arena` par `Survivor`.

Dans PowerShell, dans le dossier du projet :

```powershell
rokit install
lune run tests/run
```

Les tests doivent finir par « tout est cohérent ».

## Brancher le code sur Studio

1. Ouvre la place **Survivor** dans Studio.
2. Dans PowerShell, dans le dossier du projet :

   ```powershell
   rojo serve
   ```

   Laisse cette fenêtre ouverte.
3. Dans Studio : onglet *Plugins* → **Rojo** → **Connect**.
4. Lance une partie de test (**Play**, ou F5) et ouvre la console
   (**View → Output**). Tu dois lire :

   ```
   [Survivor] Serveur démarré — réglages version 1
   [Survivor] Si tu lis ces lignes, Rojo est branché.
   [Survivor] Client démarré pour <ton pseudo> — réglages version 1
   ```
