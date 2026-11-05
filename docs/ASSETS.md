# Assets générés

Ce qui est généré n'existe que dans la place : ce fichier est la sauvegarde.
Pour reconstruire un modèle perdu, créer une `MeshPart` avec ces identifiants
(ou relancer la génération avec la même description).

## Modèles (ServerStorage.SurvivorModeles)

| Nom | Description donnée au générateur | MeshId | TextureID | Gardé ? |
| --- | --- | --- | --- | --- |
| `Arbre` | realistic deciduous suburban tree, thick dark bark trunk, sparse muted olive-green late autumn foliage, slightly overgrown, natural irregular crown | `rbxassetid://91456604386363` | `rbxassetid://117383140726701` | Oui, le 5 novembre 2026 : bien plus crédible que les arbres en boules. Feuillage un peu pâle. |
| — | dead leafless tree, gnarled dark gray bark, bare twisted branches reaching upward, eerie, realistic | `rbxassetid://136766100983379` | `rbxassetid://124800948705941` | **Non** : tronc bleu de dessin animé. Les arbres morts restent construits en parts. |

`tools/BuildBanlieue.luau` utilise `SurvivorModeles.Arbre` s'il existe, et
retombe sur les arbres en parts sinon (en le disant dans son rapport).
