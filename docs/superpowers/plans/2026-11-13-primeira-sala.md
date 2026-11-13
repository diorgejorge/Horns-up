# Primeira Sala Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Uma sala jogável em que o bode anda, pula e ataca com o martelo pelo teclado, uma ovelha soldado o fere e apanha, e uma estátua de Thor cura e salva.

**Architecture:** Projeto Godot 4 em 3D. A lógica (vida, save, movimento, patrulha) fica em funções estáticas ou classes sem nó, testáveis em modo headless. As cenas só ligam essa lógica a nós. O jogo é renderizado num SubViewport de baixa resolução, com câmera ortográfica de lado, e ampliado com filtro sem suavização.

**Tech Stack:** Godot 4 (GDScript), renderer `gl_compatibility`, sem addons. Testes por um runner próprio em `tests/run_tests.gd`.

**Spec:** `docs/superpowers/specs/2026-11-13-bode-metroidvania-design.md`

## Global Constraints

- Plataforma: PC, teclado e mouse. Sem mira com mouse. Sem mobile.
- Engine: Godot 4. Sem addons de terceiros.
- Câmera fixa de lado, como em Hollow Knight. Nada de câmera livre.
- Visual: 3D em baixa resolução, cor chapada, filtro sem suavização (nearest).
- O ataque sai na direção em que o bode encara.
- A estátua de Thor cura vida total ao tocar e salva o jogo.
- Ovelha soldado: lança e escudo, sem espada.
- Modelos finais do Blender não entram nesta entrega. Usar formas primitivas de cor chapada como substitutas.
- Fora desta entrega: habilidades, chefe, ferreiro, amuletos, runas, vídeo final.

## Review Focus

- Esquerda e direita apertadas juntas: o bode fica parado.
- Arquivo de save ausente, vazio ou corrompido: o jogo começa no ponto inicial, sem travar.
- Dano durante a invulnerabilidade, ou com vida já em 0: ignorado; a vida nunca fica negativa e `died` sai uma vez só.
- Uma mesma pancada atingindo a ovelha mais de uma vez, ou atacar de novo durante o tempo de recarga: conta um golpe só.
- Atacar uma ovelha que já caiu: sem efeito e sem erro.

Estas escolhas são do plano, não do autor: valores numéricos (vida 5 do bode, 3 da ovelha, dano do martelo 1, invulnerabilidade 1 s, recarga do ataque 0,5 s), teclas, resolução 320x180 e renascer na última estátua ao morrer.

---

### Task 1: Esqueleto do projeto, runner de testes e teclas

**Files:**
- Create: `project.godot`, `.gitignore`, `tests/test_case.gd`, `tests/run_tests.gd`, `tests/test_input_map.gd`

**Interfaces:**
- Produces: `class_name TestCase extends RefCounted` com `check(cond: bool, msg: String) -> void` e `check_eq(actual, expected, msg: String) -> void`. Métodos `test_*` podem usar `await`. `run_tests.gd` roda todo `tests/test_*.gd` e sai com código 1 se algo falhar.
- Produces: ações de entrada `move_left` (A, Seta esquerda), `move_right` (D, Seta direita), `jump` (Espaço), `attack` (J).

- [ ] **Step 1: Escrever o teste que falha** em `tests/test_input_map.gd`: `test_actions_exist` checa, para cada uma das quatro ações, `InputMap.has_action(a)` e `InputMap.action_get_events(a).size() >= 1`.
- [ ] **Step 2: Rodar e ver falhar.** Antes de tudo, `godot --version` deve responder; se não, parar e avisar o autor. Run: `godot --headless --path . -s tests/run_tests.gd`. Expected: falha em `test_actions_exist`. Para isso o runner e `TestCase` já devem existir; escreva-os neste passo, antes do `project.godot` com as teclas.
- [ ] **Step 3: Implementar** `project.godot` (nome "Horns-up", renderer `gl_compatibility`, `rendering/textures/canvas_textures/default_texture_filter` = nearest, mapa de entrada com as quatro ações), `.gitignore` (só `.godot/`) e o runner.
- [ ] **Step 4: Rodar e ver passar.** Expected: `0 failed`, código de saída 0.
- [ ] **Step 5: Commit** `feat: esqueleto do projeto Godot, runner de testes e teclas`.

---

### Task 2: Vida (Health)

**Files:**
- Create: `scripts/health.gd`, `tests/test_health.gd`

**Interfaces:**
- Produces: `class_name Health extends RefCounted`; `signal changed(hp: int)`; `signal died`; `var max_hp: int`; `var hp: int`; `func _init(p_max_hp: int, p_invuln_seconds: float = 0.0)`; `func take_damage(amount: int) -> bool` (true se aplicou); `func heal_full() -> void`; `func tick(delta: float) -> void` (consome a invulnerabilidade); `func is_dead() -> bool`.

- [ ] **Step 1: Escrever os testes** (todos em `tests/test_health.gd`): `test_damage_reduces_hp` (5 → dano 1 → 4); `test_never_below_zero` (dano 99 → hp 0); `test_died_emitted_once` (dois danos letais seguidos, contador de `died` = 1); `test_invulnerable_ignores_damage` (`_init(5, 1.0)`, dano 1 devolve true, segundo devolve false, hp 4; após `tick(1.0)`, dano volta a valer); `test_heal_full_restores_max` ; `test_dead_ignores_damage`.
- [ ] **Step 2: Rodar e ver falhar.** Run: `godot --headless --path . -s tests/run_tests.gd`. Expected: falhas em `test_health`.
- [ ] **Step 3: Implementar `Health`** em `scripts/health.gd`. `take_damage` só aplica se `invuln_left <= 0` e `hp > 0`, e então inicia a invulnerabilidade. `heal_full` não revive de forma silenciosa: zera a invulnerabilidade e emite `changed`.
- [ ] **Step 4: Rodar e ver passar.** Expected: `0 failed`.
- [ ] **Step 5: Commit** `feat: vida com invulnerabilidade`.

---

### Task 3: Save em disco (SaveGame)

**Files:**
- Create: `scripts/save_game.gd`, `tests/test_save_game.gd`

**Interfaces:**
- Produces: `class_name SaveGame extends RefCounted`; `const DEFAULT_PATH := "user://save.json"`; `static func write(data: Dictionary, path: String = DEFAULT_PATH) -> bool`; `static func read(path: String = DEFAULT_PATH) -> Dictionary` (vazio se ausente, vazio, corrompido ou não for objeto JSON).
- Formato salvo: `{"statue_id": String}`.

- [ ] **Step 1: Escrever os testes**, usando `user://test_save.json` e apagando o arquivo ao fim: `test_roundtrip` (escreve `{"statue_id": "a"}`, lê igual); `test_missing_file_returns_empty`; `test_corrupt_file_returns_empty` (escreve texto `{nao json` direto no arquivo); `test_non_dict_json_returns_empty` (arquivo com `[1,2]`).
- [ ] **Step 2: Rodar e ver falhar.** Expected: falhas em `test_save_game`.
- [ ] **Step 3: Implementar `SaveGame`** com `FileAccess` e `JSON.parse_string`; qualquer resultado que não seja `Dictionary` vira `{}`.
- [ ] **Step 4: Rodar e ver passar.** Expected: `0 failed`.
- [ ] **Step 5: Commit** `feat: save em JSON tolerante a arquivo ruim`.

---

### Task 4: Movimento e direção do bode

**Files:**
- Create: `scripts/player.gd`, `scenes/player.tscn`, `tests/test_player_movement.gd`

**Interfaces:**
- Consumes: `Health` (Task 2); ações da Task 1.
- Produces: `class_name Player extends CharacterBody3D`; `const WALK_SPEED := 5.0`, `JUMP_SPEED := 9.0`, `GRAVITY := 25.0`; `static func compute_velocity(v: Vector3, input_x: float, jump_pressed: bool, on_floor: bool, delta: float) -> Vector3`; `static func read_input_x(left: bool, right: bool) -> float`; `static func facing_for(current: int, input_x: float) -> int` (devolve `current` se `input_x == 0`); `var facing: int = 1`; `var health: Health` (vida 5, invulnerabilidade 1.0); `signal died`.
- Cena `player.tscn`: `CharacterBody3D` com `axis_lock_linear_z = true`, cápsula de colisão e malha de cápsula de cor chapada marrom-clara (substituta do modelo).

- [ ] **Step 1: Escrever os testes**: `test_walks_right_and_left` (`input_x = 1` → `v.x == WALK_SPEED`; `-1` → `-WALK_SPEED`); `test_both_directions_cancel` (`static func read_input_x(left: bool, right: bool) -> float` devolve 0 quando ambos são true, -1 só esquerda, 1 só direita; e `compute_velocity` com esse 0 dá `v.x == 0`); `test_jump_only_on_floor` (no chão com `jump_pressed` → `v.y == JUMP_SPEED`; no ar → sem impulso); `test_gravity_applies_in_air` (`v.y` diminui `GRAVITY * delta`); `test_facing_keeps_when_idle` e `test_facing_flips` (`facing_for(1, -1) == -1`, `facing_for(-1, 0) == -1`).
- [ ] **Step 2: Rodar e ver falhar.** Expected: falhas em `test_player_movement`.
- [ ] **Step 3: Implementar** as funções estáticas e `_physics_process` chamando `move_and_slide()`; `health.tick(delta)` a cada quadro; ligar `health.died` ao `signal died`; espelhar a malha conforme `facing`.
- [ ] **Step 4: Rodar e ver passar.** Expected: `0 failed`.
- [ ] **Step 5: Commit** `feat: bode anda, pula e encara a direção`.

---

### Task 5: Ataque do martelo

**Files:**
- Modify: `scripts/player.gd`, `scenes/player.tscn`
- Create: `tests/test_hammer_attack.gd`

**Interfaces:**
- Consumes: `Player` (Task 4).
- Produces: contrato de alvo: qualquer nó no grupo `hurtable` com `func take_hit(damage: int, from_x: float) -> void`. Em `Player`: `const HAMMER_DAMAGE := 1`, `ATTACK_COOLDOWN := 0.5`, `HAMMER_ACTIVE_SECONDS := 0.1`; `static func hitbox_offset(facing: int) -> Vector3` (`Vector3(1.2 * facing, 0.8, 0)`); `func try_attack() -> bool` (false durante a recarga); `func take_hit(damage: int, from_x: float) -> void` (chama `health.take_damage`). Nó filho `HammerHitbox` (`Area3D`) que só fica ativo durante `HAMMER_ACTIVE_SECONDS`.

- [ ] **Step 1: Escrever os testes**: `test_hitbox_offset_follows_facing` (`hitbox_offset(-1).x == -1.2`); `test_attack_has_cooldown` (`try_attack()` true, imediatamente de novo false, true após `ATTACK_COOLDOWN` de ticks); `test_swing_hits_target_in_front_once` (alvo falso de grupo `hurtable` dentro do hitbox, uma pancada com vários quadros ativos → `take_hit` chamado 1 vez); `test_swing_ignores_target_behind` (bode encara +1, alvo em -1.2 → 0 chamadas). O alvo falso é um `Node3D` com contador de `take_hit`.
- [ ] **Step 2: Rodar e ver falhar.** Expected: falhas em `test_hammer_attack`.
- [ ] **Step 3: Implementar** a ação `attack` em `_physics_process`: ao `try_attack()`, posicionar `HammerHitbox` em `hitbox_offset(facing)`, ativar por `HAMMER_ACTIVE_SECONDS`, e guardar uma lista `swing_hits` esvaziada a cada pancada para não repetir o mesmo alvo.
- [ ] **Step 4: Rodar e ver passar.** Expected: `0 failed`.
- [ ] **Step 5: Commit** `feat: ataque do martelo na direção em que o bode encara`.

---

### Task 6: Ovelha soldado

**Files:**
- Create: `scripts/sheep.gd`, `scenes/sheep.tscn`, `tests/test_sheep.gd`

**Interfaces:**
- Consumes: `Health` (Task 2); contrato `take_hit` e `Player.take_hit` (Task 5).
- Produces: `class_name Sheep extends CharacterBody3D`; `const MAX_HP := 3`, `CONTACT_DAMAGE := 1`, `SPEED := 1.5`; `static func next_direction(x: float, dir: int, left: float, right: float) -> int` (inverte ao alcançar ou passar de um limite; senão mantém); `var health: Health`; `signal downed`; `func take_hit(damage: int, from_x: float) -> void`. Fica no grupo `hurtable`. Nó filho `ContactArea` (`Area3D`): ao tocar um `Player`, chama `player.take_hit(CONTACT_DAMAGE, global_position.x)`.
- Cena: cápsula de cor chapada cinza, com `@export var patrol_left`/`patrol_right`.

- [ ] **Step 1: Escrever os testes**: `test_next_direction_flips_at_bounds` (`next_direction(5.0, 1, 0.0, 5.0) == -1`, `next_direction(0.0, -1, 0.0, 5.0) == 1`, `next_direction(2.0, 1, 0.0, 5.0) == 1`); `test_three_hits_down_the_sheep` (3 chamadas de `take_hit(1, 0)` → `downed` emitido 1 vez); `test_hit_after_downed_is_ignored` (4ª chamada: sem erro, `downed` continua em 1); `test_contact_damages_player` (instanciar ovelha e `Player`, simular `ContactArea.body_entered(player)` → `player.health.hp == 4`).
- [ ] **Step 2: Rodar e ver falhar.** Expected: falhas em `test_sheep`.
- [ ] **Step 3: Implementar** a patrulha (anda sozinha, como no mapa fácil) em `_physics_process` com `next_direction`; ao cair, emitir `downed`, desligar colisão e `queue_free()` após 1 s.
- [ ] **Step 4: Rodar e ver passar.** Expected: `0 failed`.
- [ ] **Step 5: Commit** `feat: ovelha soldado patrulha, fere e cai`.

---

### Task 7: Estátua de Thor

**Files:**
- Create: `scripts/thor_statue.gd`, `scenes/thor_statue.tscn`, `tests/test_thor_statue.gd`

**Interfaces:**
- Consumes: `Player`/`Health` (Tasks 2 e 4), `SaveGame` (Task 3).
- Produces: `class_name ThorStatue extends Area3D`; `@export var statue_id: String`; `@export var save_path: String = SaveGame.DEFAULT_PATH`; `func activate(player: Player) -> void` (cura vida total e grava `{"statue_id": statue_id}` em `save_path`). `body_entered` com um `Player` chama `activate`.

- [ ] **Step 1: Escrever os testes**, com `save_path = "user://test_statue.json"` apagado ao fim: `test_activate_heals_fully` (bode com 2 de vida → 5); `test_activate_saves_statue_id` (`SaveGame.read(path)["statue_id"] == "sala1"`); `test_touch_triggers_activate` (emitir `body_entered(player)` cura e salva sem chamar `activate` à mão).
- [ ] **Step 2: Rodar e ver falhar.** Expected: falhas em `test_thor_statue`.
- [ ] **Step 3: Implementar** a estátua; cena com malha de bloco cinza e `CollisionShape3D` de gatilho um pouco maior que o corpo.
- [ ] **Step 4: Rodar e ver passar.** Expected: `0 failed`.
- [ ] **Step 5: Commit** `feat: estátua de Thor cura e salva ao toque`.

---

### Task 8: Câmera lateral em baixa resolução

**Files:**
- Create: `scripts/side_camera.gd`, `scenes/main.tscn`, `tests/test_view.gd`

**Interfaces:**
- Produces: `class_name SideCamera extends Camera3D` com `static func target_position(player_pos: Vector3, offset: Vector3) -> Vector3` (segue `x` e `y` do bode e mantém o `z` de `offset`). `scenes/main.tscn`: `SubViewportContainer` (`stretch = true`, `texture_filter` nearest) com um `SubViewport` de 320x180 que guarda a sala e uma `SideCamera` ortográfica (`size = 9.0`).

- [ ] **Step 1: Escrever os testes**: `test_camera_follows_x_and_y_keeps_z` (`target_position(Vector3(3,2,0), Vector3(0,1,12)) == Vector3(3,3,12)`); `test_main_scene_is_low_res_and_sharp` (instanciar `main.tscn`: `SubViewport.size == Vector2i(320, 180)`, `SideCamera.projection == Camera3D.PROJECTION_ORTHOGONAL`, `SubViewportContainer.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST`).
- [ ] **Step 2: Rodar e ver falhar.** Expected: falhas em `test_view`.
- [ ] **Step 3: Implementar** `SideCamera` seguindo o `Player` a cada quadro. A janela do projeto usa tamanho 1280x720 (escala inteira 4x).
- [ ] **Step 4: Rodar e ver passar.** Expected: `0 failed`.
- [ ] **Step 5: Commit** `feat: câmera de lado e render 320x180 sem suavização`.

---

### Task 9: Montagem da sala, morte e carregamento

**Files:**
- Create: `scripts/room.gd`, `scenes/room.tscn`, `tests/test_room.gd`
- Modify: `scenes/main.tscn` (instanciar `room.tscn` dentro do `SubViewport`; cena principal do projeto)

**Interfaces:**
- Consumes: `Player`, `Sheep`, `ThorStatue`, `SaveGame`.
- Produces: `class_name Room extends Node3D`; `@export var save_path: String = SaveGame.DEFAULT_PATH`; `func respawn_position() -> Vector3` (posição da estátua cujo `statue_id` está no save, ou o nó `SpawnPoint` se o save estiver ausente, ruim ou apontar para uma estátua inexistente); ao `Player.died`: reposicionar o bode em `respawn_position()` e `health.heal_full()`; ao iniciar, colocar o bode em `respawn_position()`.
- Cena `room.tscn`: chão e paredes de blocos de cor chapada, `SpawnPoint`, um `Player`, uma `Sheep` com patrulha dentro da sala, uma `ThorStatue` com `statue_id = "sala1"`. Montanha ao fundo, como bloco simples distante, para respeitar o design.

- [ ] **Step 1: Escrever os testes**, com `save_path = "user://test_room.json"` apagado ao fim: `test_starts_at_spawn_without_save`; `test_starts_at_statue_with_save` (gravar `{"statue_id": "sala1"}`, `respawn_position()` igual à posição da estátua); `test_corrupt_save_falls_back_to_spawn`; `test_unknown_statue_id_falls_back_to_spawn`; `test_death_respawns_with_full_hp` (zerar a vida → bode na posição de renascer com vida 5).
- [ ] **Step 2: Rodar e ver falhar.** Expected: falhas em `test_room`.
- [ ] **Step 3: Implementar** `Room` e montar `room.tscn`; marcar `scenes/main.tscn` como cena principal em `project.godot`.
- [ ] **Step 4: Rodar a suíte inteira e ver passar.** Run: `godot --headless --path . -s tests/run_tests.gd`. Expected: `0 failed`.
- [ ] **Step 5: Verificação manual do critério de pronto.** Rodar `godot --path .` e conferir, na ordem: o bode anda e pula com A/D e Espaço; J bate na ovelha e três pancadas a derrubam; encostar na ovelha tira 1 de vida; tocar a estátua devolve a vida cheia; fechar e reabrir o jogo começa na estátua; morrer renasce na estátua. Registrar o resultado na descrição do PR.
- [ ] **Step 6: Commit** `feat: primeira sala jogável`.
