# Cenário 3D com Personagens 2D (2.5D) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** O cenário continua em 3D (com profundidade, luz e camadas de fundo) e os personagens viram sprites 2D dentro do mundo 3D, como em Ragnarok Online e nos jogos HD-2D (Octopath Traveler). Os sprites são pré-renderizados no Blender a partir dos modelos 3D que já existem. A jogabilidade lateral (pulo, martelada, escalada no gelo) não muda.

**Architecture:** A física já é 3D: o bode e a ovelha são `CharacterBody3D` com `axis_lock_linear_z`, e as salas são `StaticBody3D`. Por isso a mudança é só visual. O nó `Visual` de cada personagem troca o modelo `.glb` por um `AnimatedSprite3D` (billboard só no eixo Y, recorte de alfa, pés na origem). A câmera de lado ganha uma inclinação pequena e perspectiva, para o cenário 3D aparecer com profundidade. Um script `bpy` novo renderiza cada modelo, de lado e na mesma inclinação da câmera, quadro a quadro, em PNG com fundo transparente. Uma ferramenta Godot monta os `SpriteFrames`.

**Tech Stack:** Godot 4.3 (GDScript), renderer `gl_compatibility`, sem addons. Blender via `bpy==4.2.0` (o mesmo de `arte/blender/modelar_personagens.py`). Testes pelo runner próprio em `tests/run_tests.gd`.

**Spec:** `docs/superpowers/specs/2026-11-13-bode-metroidvania-design.md`. Este plano muda duas regras do spec, que só valem depois do sim do autor no ponto de decisão da Task 4: "nenhum sprite entra no jogo" (linha 49) e o personagem como modelo 3D na tela. Os sprites novos não são os de `refs-bode/`: são renders dos modelos do Blender, então "tudo modelado no Blender" continua valendo.

**Planos anteriores:** `2026-11-13-primeira-sala.md` e `2026-11-13-segunda-sala-martelo-gelo.md` (mergeados).

---

## O que é "2.5D como Ragnarok" aqui

Ragnarok Online tem duas partes: o **visual** (mapa 3D, personagens como sprites 2D sempre de frente para a câmera, câmera inclinada) e a **jogabilidade** (vista de cima, andar em 8 direções no chão, sem pulo). O Horns Up é metroidvania de lado. Este plano pega só o visual.

### Opção A (recomendada): de lado, com cenário 3D e sprites

- Câmera continua de lado, seguindo x e y, agora com perspectiva e inclinada uns 12° para baixo. Dá para ver o topo das plataformas e o fundo com profundidade.
- Personagens em sprite 2D. Como a câmera nunca gira em volta do bode, basta **uma direção renderizada** (o bode olhando para a direita); a esquerda é o mesmo sprite espelhado. Isso deixa o pipeline barato.
- Física, colisão, martelada e gelo ficam iguais. Os 87 testes atuais seguem valendo, exceto os que checam o visual (`test_view.gd`).

### Opção B: vista de cima, como Ragnarok de verdade

- Movimento em 8 direções no plano do chão, câmera alta a ~45°, sprites renderizados em 5 direções (as outras 3 espelhadas), mais quadros por animação.
- Sem gravidade de plataforma: pulo, poço de gelo e pulo de parede deixam de existir. A habilidade `martelo_gelo` perde metade do sentido. As salas 1 e 2 precisam ser redesenhadas, e boa parte dos testes de movimento, gelo e playthrough vai fora.
- Na prática é outro jogo (RPG de ação), não uma troca de visual.

**O autor escolheu a Opção A em 2026-11-14.** O plano abaixo implementa só ela. A Opção B fica registrada para referência.

---

## Prós e contras da Opção A

**Prós**
- Visual próprio e mais "jogo de época": o personagem tem contorno nítido de desenho, o cenário tem luz, profundidade e parallax de verdade (não precisa simular com camadas 2D).
- Os modelos HD e voxel já existem. O sprite sai deles por script, então o custo de arte é animar no Blender e rodar o render. Trocar de HD para voxel (PR 7) é trocar o modelo de entrada do render.
- O personagem desenha mais leve que um modelo com esqueleto (um quad por personagem). Ajuda quando houver bando de ovelhas e no mobile, que o spec deixa para depois.
- Dá para retocar quadros à mão (brilho no martelo, borrão de movimento) sem mexer no modelo.

**Contras**
- A luz do personagem fica "assada" no sprite. Uma tocha na sala não ilumina o bode do jeito certo. Dá para atenuar com `modulate` por sala; luz dinâmica de verdade exigiria normal map, que fica fora deste plano.
- Cada animação nova vira um ciclo: animar no Blender → renderizar → reimportar. Erro no modelo exige renderizar tudo de novo. O script automatiza, mas o ciclo é mais lento que usar o `.glb` direto.
- Os modelos ainda **não têm animação** (só esqueleto com pesos rígidos). Isso é trabalho de qualquer jeito, mas no 2.5D cada animação também precisa de render, e o número de quadros vira decisão de arte (12 quadros por segundo dá o ar "sprite"; 24 fica liso como 3D).
- Mistura de 2D e 3D tem armadilhas conhecidas: sprite atravessando parede na profundidade, ordem de desenho com transparência, sombra. O plano trata cada uma (recorte de alfa, sprite em z = 0, sombra de contato num quad).
- Perspectiva confunde a borda da plataforma num jogo de pulo. Por isso a inclinação é pequena e o FOV é estreito; o protótipo compara com a câmera ortográfica inclinada.
- Muda duas regras do spec (sprite no jogo, personagem 3D na tela). Por isso o protótipo vem primeiro, com ponto de decisão.

## Impacto na jogabilidade lateral atual

| Sistema | O que muda | O que não muda |
|---|---|---|
| Colisão | Nada. A cápsula do bode (raio 0,4, altura 1,6) e as caixas da sala continuam as mesmas; o sprite é só visual, sem colisão. | `axis_lock_linear_z`, `collision_layer`/`mask`, `move_and_slide`. |
| Martelada | O cubo cinza `HammerHead` (que hoje mostra o golpe) sai; o golpe aparece na animação `martelada` do sprite. O sprite precisa encaixar o martelo onde o `HammerHitbox` está (`hitbox_offset` = 1,2 à frente, 0,8 de altura); a Task 7 tem teste disso. | `try_attack`, `tick_attack`, recarga 0,5 s, tempo ativo 0,1 s, `swing_hits`, pedra e ovelha. |
| Gelo | Animação `grudado` (bode de costas para a parede). O `facing` já é calculado do jeito certo em `step`. | `should_cling`, `cling_velocity`, pulo de parede, trava de 0,15 s. |
| Virar de lado | Hoje é `visual.scale.x = facing`, que já espelha um `Sprite3D` filho. Mantido; nenhuma mudança em `player.gd` para virar. | `facing_for`. |
| Câmera | Perspectiva, inclinada ~12°, mais recuada. O `SideCamera.target_position` continua seguindo x e y. | Câmera fixa de lado (não gira, não é livre). |
| Render HD | Continua 1280x720, MSAA 4x, filtro linear. Sprites renderizados em 2x a densidade da tela, com mipmaps. | `stretch_shrink = 1`. |
| Ovelha | Mesma troca do bode (`Visual` → sprite). | Patrulha, contato, 3 golpes. |
| Testes | `test_view.gd::test_main_scene_is_hd` (hoje exige ortográfica) e `test_characters_use_hd_models` mudam na Task 10. | Todos os outros. |

## Global Constraints

- Tudo dos planos anteriores continua valendo: PC, teclado, ataque na direção em que o bode encara, troca de sala com `call_deferred`, render HD.
- **Como rodar os testes:** `godot --headless --path . --import` antes da primeira rodada e sempre que houver `class_name` novo ou PNG novo em `assets/`. Depois `godot --headless --path . -s tests/run_tests.gd`. Expected em todo "ver passar": `0 failed`, código de saída 0.
- **Alvos de colisão reais nos testes:** como no plano da segunda sala (corpo de física de verdade, `await physics_frames(2)` antes de checar contato).
- **Sprite nunca tem colisão** e fica sempre em z = 0 local. Física e visual separados: nenhuma regra de jogo lê o sprite.
- **Sprites são gerados, não editados à mão:** a fonte é o modelo + `arte/blender/renderizar_sprites.py`. Retoque à mão, se houver, fica num passo separado e documentado.
- **Não mexer no PR 7** (personagens em voxel). O script de render recebe o nome do modelo (`bode_hd` ou `bode_voxel`) e funciona com os dois.
- Até o ponto de decisão (fim da Task 4), nada muda em `scenes/main.tscn`, `scenes/player.tscn` ou `scenes/sheep.tscn`. O protótipo vive em cenas próprias.

## Review Focus

- O sprite tem os pés exatamente na origem do personagem (não flutua, não afunda) e fica do mesmo tamanho que a cápsula de colisão.
- Espelhar o sprite para a esquerda não desloca o personagem (o pivô é o centro dos pés).
- O martelo da animação `martelada` cai dentro do `HammerHitbox`.
- A câmera inclinada não esconde o bode atrás de cenário da frente (o cenário da frente não passa de z = +1,5, ou some perto da câmera).
- Nenhum nó de cenário novo tem colisão sem querer (testes de layout das salas seguem passando).
- Trocar a fonte do render de `_hd` para `_voxel` é só um argumento.

Estas escolhas são do plano, não do autor: inclinação de 12° e FOV de 30°, uma direção renderizada e espelhada, sprites a 160 px por metro (2x a densidade da tela), 12 quadros por segundo, nomes das animações em português (`parado`, `andar`, `pular`, `cair`, `martelada`, `grudado`, `dano`), sombra de contato num quad em vez de `Decal` (o `gl_compatibility` não tem `Decal`), pasta `assets/sprites/<personagem>/`, fonte do render padrão `_hd` (troca para `_voxel` se o PR 7 entrar).

---

### Task 1: Render de um quadro parado do bode (Blender)

Primeira peça do protótipo: provar que o modelo vira um PNG limpo, do tamanho certo, com os pés no lugar certo.

**Files:**
- Create: `arte/blender/renderizar_sprites.py`, `assets/sprites/bode/parado_00.png`, `tests/test_sprite_render.gd`

**Interfaces:**
- Produces (bpy): `renderizar(modelo: str, animacao: str | None, quadros: int, saida: str, inclinacao_graus=12.0, px_por_metro=160, altura_quadro_m=2.4, largura_quadro_m=3.2)`. Câmera ortográfica olhando de +Z para o modelo (que olha para +X), inclinada `inclinacao_graus` para baixo, enquadrada de modo que a origem (pés) fique no **centro da borda de baixo**, a uma margem fixa de 8 px. Fundo transparente (`film_transparent`), engine EEVEE, luz de sol fixa vinda de cima à esquerda da câmera.
- Linha de comando: `python arte/blender/renderizar_sprites.py bode_hd parado 1` → `assets/sprites/bode/parado_00.png`.
- Tamanho do quadro: 3,2 m x 2,4 m a 160 px/m = **512 x 384 px**.

- [ ] **Step 1: Escrever os testes** em `tests/test_sprite_render.gd` (lê o PNG com `Image.load_from_file`, sem depender do import): `test_frame_size` (512x384); `test_corners_transparent` (os 4 cantos com alfa 0); `test_feet_on_bottom_center` (na linha y = 384 − 8 − 1 há pixel opaco a até 40 px do centro, e a linha y = 384 − 8 + 2 é toda transparente); `test_height_matches_capsule` (do pixel opaco mais alto até os pés: entre 1,4 m e 2,2 m, ou seja 224 a 352 px; a cápsula tem 1,6 m e os chifres passam dela).
- [ ] **Step 2: Rodar e ver falhar.** Expected: falhas em `test_sprite_render` (arquivo não existe).
- [ ] **Step 3: Implementar o script.** Reusar `limpar_cena` e a importação de `.glb` do jeito de `modelar_personagens.py`. Importar `assets/modelos/personagens/<modelo>.glb`; não modelar nada aqui.
- [ ] **Step 4: Rodar o script e os testes e ver passar.**
- [ ] **Step 5: Commit** `feat: script que renderiza sprite do modelo 3D`.

---

### Task 2: Nó de sprite do personagem

**Files:**
- Create: `scripts/character_sprite.gd`, `tests/test_character_sprite.gd`

**Interfaces:**
- Produces: `class_name CharacterSprite extends AnimatedSprite3D`. `const PX_PER_METER := 160.0`; `const FOOT_MARGIN_PX := 8`; `static func pixel_size_for(px_per_meter: float) -> float` (= 1 / px_per_meter); `static func feet_offset(frame_height_px: int) -> Vector2` (deslocamento para os pés ficarem na origem: `Vector2(0, frame_height_px / 2.0 - FOOT_MARGIN_PX)`); em `_ready`: `billboard = BaseMaterial3D.BILLBOARD_FIXED_Y`, `alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD`, `shaded = false`, `texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS`, `pixel_size` e `offset` pelas funções acima.

- [ ] **Step 1: Escrever os testes**: `test_pixel_size` (160 → 0,00625); `test_feet_offset` (384 → `Vector2(0, 184)`); `test_ready_config` (instanciar com um `SpriteFrames` de 1 quadro do PNG da Task 1, pôr na árvore: billboard Y, recorte de alfa, sem sombreamento); `test_feet_at_origin_in_world` (com a config, a borda de baixo do AABB do sprite fica a `FOOT_MARGIN_PX * pixel_size` abaixo de y = 0, com tolerância de 0,01).
- [ ] **Step 2: Rodar e ver falhar** (com `--import`).
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Rodar e ver passar.**
- [ ] **Step 5: Commit** `feat: sprite de personagem com pés na origem`.

---

### Task 3: Câmera inclinada

**Files:**
- Modify: `scripts/side_camera.gd`
- Modify: `tests/test_view.gd` (só acrescenta testes; não mexe nos que existem)

**Interfaces:**
- Produces em `SideCamera`: `@export var pitch_degrees := 0.0` (0 = comportamento atual, então `main.tscn` não muda); `static func tilted_offset(distance: float, pitch_degrees: float, look_height: float) -> Vector3` (posição relativa ao bode para olhar um ponto `look_height` acima dos pés, a `distance` de distância, inclinada `pitch_degrees` para baixo); em `_ready`, `rotation_degrees.x = -pitch_degrees`.

- [ ] **Step 1: Escrever os testes**: `test_tilted_offset_zero_pitch` (pitch 0, distância 12, altura 1 → `Vector3(0, 1, 12)`, igual ao atual); `test_tilted_offset_12` (pitch 12 → y = 1 + 12·sen 12°, z = 12·cos 12°, tolerância 0,001); `test_camera_looks_at_player` (câmera de teste na árvore com pitch 12: o bode em (5, 2, 0) projeta perto do centro da tela, até 5% de distância, com `unproject_position`); o teste antigo `test_camera_follows_x_and_y_keeps_z` continua passando.
- [ ] **Step 2: Rodar e ver falhar.**
- [ ] **Step 3: Implementar.** `target_position` continua igual; quem usa a inclinação passa o `follow_offset` calculado por `tilted_offset`.
- [ ] **Step 4: Rodar e ver passar.**
- [ ] **Step 5: Commit** `feat: câmera de lado pode inclinar`.

---

### Task 4: Protótipo jogável na sala 2 (ponto de decisão)

O protótipo mínimo. Cena separada: o jogo de verdade continua igual.

**Files:**
- Create: `scenes/prototipo/player_sprite.tscn`, `scenes/prototipo/prototipo_25d.tscn`, `tests/test_prototipo_25d.gd`, `assets/sprites/bode/bode.tres` (`SpriteFrames` com a animação `parado`, 1 quadro)
- Create: `arte/previas/prototipo_25d_*.png` (capturas para o autor comparar)

**Interfaces:**
- `player_sprite.tscn`: herda de `scenes/player.tscn` (cena herdada), esconde `Visual/BodeHD`, acrescenta `Visual/Sprite` (`CharacterSprite`) e `Visual/Sombra` (quad horizontal escuro, transparente, raio 0,45, em y = 0,01).
- `prototipo_25d.tscn`: copia de `main.tscn` com `SideCamera` em perspectiva (FOV 30, `pitch_degrees = 12`, distância 22), o `Player` trocado por `player_sprite.tscn`, e a sala 2 carregada direto. Uma luz direcional e um `WorldEnvironment` simples (céu de cor, névoa leve de profundidade) para o cenário ganhar volume. Um `@export var orthographic := false` na raiz troca para ortográfica inclinada, para comparar.

- [ ] **Step 1: Escrever os testes** em `tests/test_prototipo_25d.gd`: `test_player_has_sprite_not_model` (na cena herdada, `Visual/Sprite` visível e `Visual/BodeHD` escondido); `test_collision_unchanged` (a cápsula de `player_sprite.tscn` é igual à de `player.tscn`: raio, altura, posição); `test_flip_does_not_move_feet` (com `facing = -1`, a posição global do sprite e da sombra continua em x do bode); `test_ice_climb_still_works` (repete o roteiro de `test_sala2_playthrough.gd` com `player_sprite.tscn` no lugar do bode: chega ao topo); `test_camera_is_tilted_perspective`.
- [ ] **Step 2: Rodar e ver falhar.**
- [ ] **Step 3: Montar as cenas.**
- [ ] **Step 4: Rodar e ver passar.**
- [ ] **Step 5: Capturas.** Com `xvfb-run`, renderizar o protótipo em 4 momentos da sala 2 (chegada, martelada na pedra, grudado no gelo, topo), uma vez em perspectiva e uma em ortográfica inclinada, lado a lado com as capturas atuais de `segunda-sala/`. Salvar em `arte/previas/`.
- [ ] **Step 6: Commit** `feat: protótipo 2.5D da sala 2`.
- [ ] **Step 7: PONTO DE DECISÃO do autor.** O autor joga `scenes/prototipo/prototipo_25d.tscn` no teclado (F6 no editor) e escolhe: seguir com sprites, voltar aos modelos 3D, ou ajustar câmera (perspectiva ou ortográfica, inclinação). **As Tasks 5 a 10 só começam com o sim.** Se for não, o protótipo fica no repo como referência ou é apagado, a critério do autor.

---

### Task 5: Animações no Blender

**Files:**
- Create: `arte/blender/animar_personagens.py`
- Modify: `assets/modelos/personagens/bode_hd.glb`, `ovelha_hd.glb` (e `_voxel`, se o PR 7 já estiver na main)
- Create: `tests/test_model_animations.gd`

**Interfaces:**
- Produces: ações no esqueleto existente (pesos rígidos, como estão): bode `parado` (laço, 8 quadros), `andar` (laço, 8), `pular` (4), `cair` (laço, 2), `martelada` (6; o quadro 3 é o impacto), `grudado` (laço, 4), `dano` (3). Ovelha: `parado`, `andar`, `dano`, `queda`. A 12 quadros por segundo.
- As ações seguem os quadros de referência de `docs/superpowers/specs/refs-bode/` (silhueta e pose, não desenho).

- [ ] **Step 1: Escrever os testes**: carregar cada `.glb`, achar o `AnimationPlayer`, checar que tem cada nome acima com o comprimento esperado (quadros / 12), e que `parado`, `andar`, `cair` e `grudado` estão em laço.
- [ ] **Step 2: Rodar e ver falhar.**
- [ ] **Step 3: Implementar o script** (chaves de rotação por osso; o script só acrescenta ações, não remodela).
- [ ] **Step 4: Rodar e ver passar** (com `--import`).
- [ ] **Step 5: Commit** `feat: animações do bode e da ovelha`.

---

### Task 6: Render das animações e `SpriteFrames`

**Files:**
- Modify: `arte/blender/renderizar_sprites.py` (todas as ações, uma folha PNG por ação)
- Create: `tools/gerar_sprite_frames.gd`, `assets/sprites/bode/*.png`, `assets/sprites/bode/bode.tres`, `assets/sprites/ovelha/*`, `tests/test_sprite_frames.gd`

**Interfaces:**
- `renderizar_sprites.py <modelo> --todas`: uma folha por ação, quadros lado a lado (largura 512·n, altura 384).
- `tools/gerar_sprite_frames.gd` (`godot --headless -s`): lê as folhas, gera `SpriteFrames` com uma animação por folha, 12 fps, laço igual ao da ação.

- [ ] **Step 1: Escrever os testes**: `bode.tres` tem as 7 animações com o número de quadros da Task 5, 12 fps, laços certos; todo quadro de todas as folhas passa nos mesmos testes de pés e cantos da Task 1 (reusar as funções).
- [ ] **Step 2: Rodar e ver falhar.**
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Rodar e ver passar.**
- [ ] **Step 5: Commit** `feat: folhas de sprite das animações`.

---

### Task 7: Estado de animação do bode

**Files:**
- Modify: `scripts/player.gd`, `scripts/character_sprite.gd`
- Create: `tests/test_player_animation.gd`

**Interfaces:**
- Produces em `Player`: `static func animation_for(on_floor: bool, velocity: Vector3, clinging: bool, attacking: bool, hurt: bool) -> String`. Prioridade: `dano` > `martelada` > `grudado` > no ar (`pular` se `velocity.y > 0`, senão `cair`) > `andar` se `absf(velocity.x) > 0.1` > `parado`.
- Em `step`, depois de `move_and_slide`, se o `Visual` tem um `CharacterSprite`, chama `play(animation_for(...))`. A martelada dura o comprimento da animação, mas o dano continua só nos 0,1 s de `HAMMER_ACTIVE_SECONDS` (regra de jogo não depende do sprite).

- [ ] **Step 1: Escrever os testes**: a tabela de prioridade acima, caso a caso; `test_hammer_frame_inside_hitbox` (no quadro de impacto da `martelada`, o centro dos pixels do martelo, convertido para metros com `pixel_size` e `offset`, cai dentro da caixa do `HammerHitbox` em `hitbox_offset(1)`); `test_model_scene_still_works` (o `player.tscn` com modelo 3D, sem `CharacterSprite`, roda `step` sem erro).
- [ ] **Step 2: Rodar e ver falhar.**
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Rodar e ver passar.**
- [ ] **Step 5: Commit** `feat: bode troca de animação conforme o estado`.

---

### Task 8: Ovelha em sprite

**Files:**
- Modify: `scripts/sheep.gd` (mesmo esquema da Task 7: `parado`, `andar`, `dano`, `queda`)
- Create: `scenes/prototipo/sheep_sprite.tscn`, `tests/test_sheep_animation.gd`

- [ ] **Step 1: Escrever os testes**: `andar` durante a patrulha, `dano` ao apanhar, `queda` depois do terceiro golpe; colisão igual à de `sheep.tscn`.
- [ ] **Step 2–4:** falhar, implementar, passar.
- [ ] **Step 5: Commit** `feat: ovelha em sprite`.

---

### Task 9: Cenário com profundidade nas salas 1 e 2

**Files:**
- Modify: `scenes/rooms/sala1.tscn`, `scenes/rooms/sala2.tscn`
- Create: `tests/test_cenario.gd`

**Interfaces:**
- Cada sala ganha um nó `Cenario` (grupo `cenario`) com: fundo em z de −3 a −15 (montanhas, pinheiros, paredões de gelo, em blocos simples), primeiro plano em z de +1 a +1,5 (pedras baixas, neve), uma `DirectionalLight3D` por sala. Cenário usa os mesmos materiais de cor chapada.

- [ ] **Step 1: Escrever os testes**: nenhum nó dentro de `Cenario` é `CollisionObject3D`; nada em `Cenario` com z > 1,5; nada do primeiro plano mais alto que 0,6 m acima do chão (não tapa o bode); `test_sala2_layout.gd` e `test_room.gd` seguem passando.
- [ ] **Step 2–4:** falhar, implementar, passar.
- [ ] **Step 5: Capturas** novas em `arte/previas/`.
- [ ] **Step 6: Commit** `feat: cenário com profundidade nas salas`.

---

### Task 10: Trocar o jogo para 2.5D

**Files:**
- Modify: `scenes/main.tscn`, `scenes/player.tscn`, `scenes/sheep.tscn`, `tests/test_view.gd`, `docs/superpowers/specs/2026-11-13-bode-metroidvania-design.md`
- Delete: `scenes/prototipo/` (o que virou cena principal)

- [ ] **Step 1: Mudar os testes de visual**: `test_main_scene_is_hd` passa a exigir perspectiva com `pitch_degrees == 12` (continua exigindo 1280x720, MSAA 4x, filtro linear); `test_characters_use_hd_models` vira `test_characters_use_sprites` (`Visual/Sprite` é `CharacterSprite` no bode e na ovelha).
- [ ] **Step 2: Rodar e ver falhar.**
- [ ] **Step 3: Aplicar** as mudanças do protótipo nas cenas de verdade. O modelo 3D sai do `Visual` (continua em `assets/modelos/`, é a fonte dos sprites).
- [ ] **Step 4: Rodar a suíte inteira e ver passar.**
- [ ] **Step 5: Atualizar o spec**: anotar a decisão do autor (data, câmera, sprites gerados dos modelos) no lugar das linhas que ela substitui.
- [ ] **Step 6: Commit** `feat: jogo em 2.5D com personagens em sprite`.

---

## Fora deste plano

- Opção B (vista de cima, 8 direções).
- Normal map nos sprites para luz dinâmica.
- Rei Dragão em sprite (ainda não está no jogo; o script já renderiza ele quando for preciso).
- Retoque à mão dos quadros.
- Animações além das listadas (correr, ataque no pulo, bloqueio).
