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
