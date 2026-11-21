# Créditos de assets

Todos os assets abaixo são PROVISÓRIOS. Os caminhos ficam só em `scripts/asset_db.gd`;
para trocar pela arte oficial, edite aquele arquivo.

## Texturas — ambientCG.com (CC0 1.0), em `assets/textures/` (Color + NormalGL, 1K)
- Grass004, Ground037, Ground054, Rock030, PavingStones070 — https://ambientcg.com/

## Modelos 3D — Poly Haven (CC0 1.0), em `assets/models/` (glTF 1K)
- island_tree_01, shrub_02, boulder_01, rock_moss_set_01, rock_07, fern_02,
  grass_medium_01, tree_stump_01 — https://polyhaven.com/models

## Arte do Diorge (autoral) — `assets/diorge/`
- Folhas de cenário `image-*.png` (são JPEG; marcadas como "keep" no Godot) recortadas por
  `tools/slice_sheets.gd` em `assets/diorge/cut/`.
- `coruja.png` (Mago Coruja) e `bufalo.png` (Guerreiro Búfalo) recortadas por seção
  (idle, walk, cast/attack, charge, hit, death, direções, efeitos) por `tools/slice_characters.gd`
  em `assets/diorge/chars/`.
- Liga/desliga: `AssetDB.USE_DIORGE_ART` em `scripts/asset_db.gd`.

## Personagens 2D
- `assets/sprites/`: gerados por `tools/make_placeholder_sprites.gd` (sem licença externa).

## Texturas da HUD — Poly Haven (CC0 1.0, sem exigência de atribuição), em `assets/diorge/ui/texturas/` (1K, JPG)
- Dark Wood (`dark_wood_diff_1k`, `dark_wood_nor_gl_1k`) — Dimitrios Savva, Dario Barresi, Rico Cilliers — https://polyhaven.com/a/dark_wood
- Clay Plaster (`clay_plaster_diff_1k`, `clay_plaster_nor_gl_1k`) — Amal Kumar — https://polyhaven.com/a/clay_plaster
- Usadas no shader dos painéis (`scripts/ui/hud/painel_marajoara.gdshader`) e no pedestal da vitrine 3D.
