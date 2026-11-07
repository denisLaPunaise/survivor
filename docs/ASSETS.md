# Assets générés

Ce qui est généré n'existe que dans la place : ce fichier est la sauvegarde.
Pour reconstruire un modèle perdu, créer une `MeshPart` avec ces identifiants
(ou relancer la génération avec la même description).

## Modèles (ServerStorage.SurvivorModeles)

| Nom | Description donnée au générateur | MeshId | TextureID | Gardé ? |
| --- | --- | --- | --- | --- |
| `Arbre` | realistic deciduous suburban tree, thick dark bark trunk, sparse muted olive-green late autumn foliage, slightly overgrown, natural irregular crown | `rbxassetid://91456604386363` | `rbxassetid://117383140726701` | Oui, le 5 novembre 2026 : bien plus crédible que les arbres en boules. Feuillage un peu pâle. |
| `Voiture1` | abandoned old sedan car, faded dusty paint with rust patches, dirty windows, slightly flat tires, realistic, 1990s suburban family car | `rbxassetid://118456716580222` | `rbxassetid://76327974453445` | Oui : très crédible. Rouge vif, alors que le rouge est en principe réservé à l'Œil — à surveiller. |
| `Voiture2` | abandoned old station wagon car, faded beige grey paint, dust and rust, dirty cracked windows, realistic, suburban | `rbxassetid://79544487506810` | `rbxassetid://130542278747095` | Oui. |
| — | dead leafless tree, gnarled dark gray bark, bare twisted branches reaching upward, eerie, realistic | `rbxassetid://136766100983379` | `rbxassetid://124800948705941` | **Non** : tronc bleu de dessin animé. Les arbres morts restent construits en parts. |

`tools/BuildBanlieue.luau` utilise `SurvivorModeles.Arbre`, `Voiture1` et
`Voiture2` s'ils existent, et retombe sur des arbres et des voitures en parts
sinon (en le disant dans son rapport).

## Sons (Config.sounds.library)

Tous de **Pro Sound Effects** ou **APM Music**, les bibliothèques mises à
disposition par Roblox (publiques, durables). Choisis sur leur nom et leur
durée : l'assistant ne peut pas écouter, c'est à Josh de juger. Tous vérifiés
chargés dans Studio le 6 novembre 2026.

| Nom | Quand | Asset | Titre d'origine | Durée |
| --- | --- | --- | --- | --- |
| `signal` | le ciel rougit | 9125484367 | Deep Hits Big Reverberant Booms Rumbling Tail | 4,4 s |
| `menace` | pendant les signes | 9125485274 | Deep Synth Drone Modulating Sub Rumble | 13,5 s |
| `regard` | son regard qui approche (boucle) | 9114353261 | Evil Drone Deep Unsetting Rumbly Keening | 36 s |
| `ouverture` | paupières qui s'ouvrent / se ferment | 9043343895 | Reverse Noise Hard End (APM) | 2,1 s |
| `aspiration` | aspiré, ou une cachette avalée | 9118840222 | Screaming Suck Burst | 2,6 s |
| `toit` | un toit qui craque avant d'être arraché | 9126240449 | Wood Crack Thick Splintering Bursts Creaking | 3,4 s |
| `radio` | chaque ligne de Mara | 9118027586 | Radio Static 9 | 0,7 s |
| `vent` | ambiance du jour (boucle) | 9114625552 | Gods Wind Spooky Eerie | 68 s |
| `nuit` | ambiance de la nuit (boucle) | 9114353377 | Evil Drone Deep Unsetting Rumbly Keening | 18 s |
| `coeur` | dans le Ventre (boucle) | 9043365842 | Heartbeat 02 96 BPM (APM) | 60 s |
| `murmure` | il te voit | 9114228525 | Eerie Whispering Reverberant Demon | 6,9 s |
| `cri` | il a mal (on le fait cligner) | 9113980319 | Creature Mix Giant Crab Monster Roar Growl | 3,1 s |
| `chute` | une épave qui s'écrase | 9125484700 | Deep Hits Big Reverberant Booms Rumbling Tail | 4,4 s |
