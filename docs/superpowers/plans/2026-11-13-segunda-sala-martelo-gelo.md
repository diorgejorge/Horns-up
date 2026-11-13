# Segunda Sala e Martelo de Gelo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** O bode sai da primeira sala por uma porta, entra numa sala de gelo, pega a primeira habilidade (o martelo quebra pedra e gruda no gelo), quebra a pedra que fecha o poço de gelo e escala as paredes de gelo até o topo, onde há uma segunda estátua de Thor. A habilidade e a sala ficam no save.

**Architecture:** O bode sai de dentro da sala. Um nó `World` dentro do `SubViewport` guarda o `Player` e troca a sala atual (`Room`) ao passar por uma porta, ao morrer e ao carregar o save. Cada sala vira uma cena em `scenes/rooms/` com estátuas, portas e um `SpawnPoint`. A lógica nova (formato do save, grudar no gelo, pulo de parede) fica em funções estáticas, testáveis em headless, como na primeira sala.

**Tech Stack:** Godot 4.3 (GDScript), renderer `gl_compatibility`, sem addons. Testes pelo runner próprio em `tests/run_tests.gd`.

**Spec:** `docs/superpowers/specs/2026-11-13-bode-metroidvania-design.md` (seções "Habilidades e caminho", "Mundo e cenário" e "Ordem de construção").

**Plano anterior:** `docs/superpowers/plans/2026-11-13-primeira-sala.md` (mergeado nos PRs 2 e 3).

## Global Constraints

- Tudo da primeira sala continua valendo: PC, teclado, sem mira com mouse; câmera fixa de lado; 3D em baixa resolução, cor chapada, filtro nearest; ataque na direção em que o bode encara; estátua de Thor cura tudo e salva; ovelha com lança e escudo.
- A primeira habilidade é uma só: o martelo quebra pedra **e** gruda no gelo. Não dividir em duas.
- O caminho bloqueado precisa de pista visual: a parede de gelo e a pedra rachada são visíveis antes de o bode ter a habilidade.
- Modelos finais do Blender não entram. Formas primitivas de cor chapada.
- Fora desta entrega: peças do Mjolnir, runas, amuletos, ferreiro, chefe, outras habilidades, mapa/minimapa, bando de ovelhas, vídeo final.
- **Como rodar os testes (correção do plano anterior):** antes da primeira rodada, e sempre que um arquivo novo com `class_name` for criado, rodar `godot --headless --path . --import` (registra os `class_name`; sem isso o runner falha com "Identifier not declared"). Depois: `godot --headless --path . -s tests/run_tests.gd`. Expected em todo "ver passar": `0 failed`, código de saída 0.
- **Alvos de colisão reais nos testes (correção do plano anterior):** todo alvo que um `Area3D` precisa detectar é um corpo de física de verdade (`StaticBody3D` ou `CharacterBody3D` com `CollisionShape3D` e shape não vazia), dentro da árvore, nunca um `Node3D` solto. Depois de posicionar, esperar `await physics_frames(2)` antes de checar `get_overlapping_bodies()` ou sinais de contato. Reusar `tests/fake_target.gd` (já é `StaticBody3D`) quando servir.
- **Render 320x180 (correção do plano anterior):** com `SubViewportContainer.stretch = true`, o container sobrescreve o `size` do `SubViewport`. O tamanho de 320x180 vem de `stretch_shrink = 4` sobre a janela de 1280x720. Ao mexer em `scenes/main.tscn`, manter `stretch = true` e `stretch_shrink = 4`; `tests/test_view.gd` continua passando sem mudança.
- Troca de sala sempre com `call_deferred` (nunca dentro de `body_entered` ou de `_physics_process`), para não remover corpos durante a consulta de física.

## Review Focus

- Save antigo da primeira sala (`{"statue_id": "sala1"}`): carrega na sala 1, na estátua, sem habilidades.
- Save com `room_id` desconhecido, `abilities` que não é lista, ou itens da lista que não são texto: ignora o que for ruim e cai no `SpawnPoint` da sala 1.
- Pegar a habilidade duas vezes, ou voltar à sala 2 já com ela: a lista não repete o item e o objeto não aparece de novo.
- Bater na pedra sem a habilidade: a pedra não quebra e nada dá erro. Com a habilidade, uma pancada quebra uma vez só, mesmo com vários quadros ativos.
- Grudar só em parede de gelo e só com a habilidade. Parede de pedra ou sem habilidade: cai normal.
- Chegar por uma porta não faz o bode voltar pela mesma porta.
- Morrer na sala 2 com a última estátua na sala 1: renasce na sala 1, na estátua, com a habilidade (ela é salva na hora em que é pega).

Estas escolhas são do plano, não do autor: nome do id da habilidade (`martelo_gelo`), salvar a habilidade na hora em que é pega (como em Hollow Knight), pedra quebrada não fica salva (volta ao recarregar, e o bode quebra de novo), grudar = parar no gelo enquanto segura a direção da parede, pulo de parede com empurrão 6 e trava de entrada de 0,15 s, layout da sala 2, texto do aviso da habilidade no HUD.

---

### Task 1: Formato do save com sala e habilidades

**Files:**
- Create: `scripts/save_data.gd`, `tests/test_save_data.gd`

**Interfaces:**
- Consumes: `SaveGame` (sem mudança: `write`/`read` de `Dictionary`).
- Produces: `class_name SaveData extends RefCounted`; `const DEFAULT_ROOM := "sala1"`; `var room_id: String = DEFAULT_ROOM`; `var statue_id: String = ""`; `var abilities: PackedStringArray = []`; `static func from_dict(d: Dictionary) -> SaveData`; `func to_dict() -> Dictionary` (`{"room_id", "statue_id", "abilities"}`); `func add_ability(id: String) -> bool` (false se já tinha).

- [ ] **Step 1: Escrever os testes** em `tests/test_save_data.gd`: `test_empty_dict_gives_defaults` (sala `sala1`, estátua vazia, sem habilidades); `test_old_save_maps_to_sala1` (`{"statue_id": "sala1"}` → `room_id == "sala1"`, `statue_id == "sala1"`); `test_roundtrip` (`from_dict(x.to_dict())` igual campo a campo); `test_bad_types_are_ignored` (`{"room_id": 3, "abilities": "x"}` → padrões; `{"abilities": ["a", 2, null]}` → só `["a"]`); `test_add_ability_no_duplicate` (true, depois false, tamanho 1).
- [ ] **Step 2: Rodar e ver falhar.** Run: `godot --headless --path . --import` e depois `godot --headless --path . -s tests/run_tests.gd`. Expected: falhas em `test_save_data`.
- [ ] **Step 3: Implementar `SaveData`.** Campo com tipo errado vira o padrão; itens não-texto de `abilities` são descartados; sem duplicatas.
- [ ] **Step 4: Rodar e ver passar** (rodar `--import` antes, por causa do `class_name` novo).
- [ ] **Step 5: Commit** `feat: save guarda sala e habilidades, aceita save antigo`.

---

### Task 2: Habilidades no bode e objeto da habilidade

**Files:**
- Modify: `scripts/player.gd`
- Create: `scripts/ability_pickup.gd`, `scenes/ability_pickup.tscn`, `tests/test_ability_pickup.gd`

**Interfaces:**
- Produces em `Player`: `const ABILITY_ICE_HAMMER := "martelo_gelo"`; `signal ability_gained(id: String)`; `var abilities: PackedStringArray = []`; `func has_ability(id: String) -> bool`; `func grant_ability(id: String) -> bool` (false e sem sinal se já tinha).
- Produces: `class_name AbilityPickup extends Area3D`; `@export var ability_id: String = Player.ABILITY_ICE_HAMMER`; `signal collected(id: String)`; `func refresh(player: Player) -> void` (esconde e desliga `monitoring` se o bode já tem a habilidade). Ao tocar um `Player`: `grant_ability`, emite `collected` uma vez, some.
- Cena: bloco pequeno azul-gelo brilhante (`emission`) sobre um pedestal cinza; `CollisionShape3D` de gatilho.

- [ ] **Step 1: Escrever os testes**: `test_grant_ability_once` (bode novo: `grant_ability` true, depois false, `ability_gained` emitido 1 vez); `test_touch_grants_and_hides` (instanciar `player.tscn` e `ability_pickup.tscn` na árvore, bode com `set_physics_process(false)` colocado sobre o gatilho, `await physics_frames(2)`: bode tem a habilidade, `collected` emitido 1 vez, pickup invisível); `test_refresh_hides_if_already_owned`. Alvos são o `Player` real com sua cápsula de colisão, não um `Node3D`.
- [ ] **Step 2: Rodar e ver falhar.** Expected: falhas em `test_ability_pickup`.
- [ ] **Step 3: Implementar.** O toque usa `body_entered`; depois de coletado, `monitoring` desligado com `set_deferred`.
- [ ] **Step 4: Rodar e ver passar** (com `--import` antes).
- [ ] **Step 5: Commit** `feat: bode ganha habilidade ao tocar o objeto`.

---

### Task 3: Pedra que o martelo quebra

**Files:**
- Modify: `scripts/player.gd` (`_hit`)
- Create: `scripts/stone_block.gd`, `scenes/stone_block.tscn`, `tests/test_stone_block.gd`

**Interfaces:**
- Consumes: `Player.has_ability` (Task 2); `HammerHitbox` e `swing_hits` (primeira sala).
- Produces: contrato de quebrável: nó no grupo `breakable` com `func smash() -> void`. `class_name StoneBlock extends StaticBody3D`; `signal smashed`; `var broken := false`; `func smash()` (na primeira vez: `broken = true`, emite `smashed`, desliga colisão com `set_deferred` e esconde a malha; depois: nada); `func bonk()` (sem habilidade: tremidinha visual de 0,1 s, pista de que algo falta).
- Em `Player._hit`: se o nó está em `breakable`, chama `smash()` quando `has_ability(ABILITY_ICE_HAMMER)`, senão `bonk()`. Registra em `swing_hits` nos dois casos.
- Cena: bloco 2x3 cinza-escuro com faixas mais claras (rachaduras pintadas como malhas finas).

- [ ] **Step 1: Escrever os testes**: `test_smash_once` (`smash()` duas vezes → `smashed` 1 vez, `broken`); `test_swing_without_ability_does_not_break` (bode real e pedra real na frente dele, distância `hitbox_offset(1)`, `await physics_frames(2)`, `try_attack()`, rodar `tick_attack` por vários quadros → `broken == false`); `test_swing_with_ability_breaks_once` (mesma montagem com `grant_ability` → `smashed` 1 vez); `test_sheep_still_takes_hits` (regressão: `fake_target.gd` no grupo `hurtable` continua recebendo 1 golpe).
- [ ] **Step 2: Rodar e ver falhar.** Expected: falhas em `test_stone_block`.
- [ ] **Step 3: Implementar** `StoneBlock` e o desvio em `_hit`.
- [ ] **Step 4: Rodar e ver passar** (com `--import` antes). `test_hammer_attack` continua verde.
- [ ] **Step 5: Commit** `feat: martelo quebra pedra com a habilidade`.

---

### Task 4: Grudar no gelo e pulo de parede

**Files:**
- Modify: `scripts/player.gd`
- Create: `scripts/ice_wall.gd`, `scenes/ice_wall.tscn`, `tests/test_ice_climb.gd`

**Interfaces:**
- Produces: `class_name IceWall extends StaticBody3D` (entra no grupo `ice_wall` em `_ready`); cena com bloco azul-claro, `@export var size: Vector3` aplicado à malha e à shape.
- Produces em `Player`: `const WALL_JUMP_PUSH := 6.0`, `WALL_JUMP_LOCK := 0.15`; `var clinging := false`; `var input_lock_left := 0.0`; `static func should_cling(on_floor: bool, wall_is_ice: bool, has_ability: bool, input_x: float, wall_normal_x: float) -> bool` (true só no ar, em gelo, com habilidade e segurando contra a parede: `input_x * wall_normal_x < 0`); `static func cling_velocity(v: Vector3) -> Vector3` (zera `y` e `x`); `static func wall_jump_velocity(wall_normal_x: float) -> Vector3` (`Vector3(WALL_JUMP_PUSH * wall_normal_x, JUMP_SPEED, 0)`).
- Em `_physics_process`: depois de `move_and_slide()`, achar a parede pelo `get_slide_collision(i)` com normal quase horizontal; se o colisor está em `ice_wall` e `should_cling(...)`, `clinging = true`. Grudado: `cling_velocity` no lugar da gravidade; `jump` faz `wall_jump_velocity` e liga `input_lock_left = WALL_JUMP_LOCK` (durante a trava, `input_x` é 0 para o bode se afastar antes de voltar).

- [ ] **Step 1: Escrever os testes**: `test_should_cling_cases` (tabela: no chão → false; parede de pedra → false; sem habilidade → false; segurando para longe da parede → false; no ar + gelo + habilidade + contra a parede → true); `test_cling_stops_fall` (`cling_velocity(Vector3(0, -5, 0)) == Vector3.ZERO`); `test_wall_jump_pushes_away` (`wall_jump_velocity(-1) == Vector3(-6, 9, 0)`); `test_clings_on_real_ice_wall` (cena com `IceWall` real e bode real com a habilidade, bode no ar encostado nela; simular quadros chamando um método `step(delta, input_x, jump_pressed)` extraído de `_physics_process` para não depender do teclado; após `physics_frames(10)` a altura não caiu mais que 0,05); `test_no_cling_without_ability` (mesma cena sem habilidade: o bode cai).
- [ ] **Step 2: Rodar e ver falhar.** Expected: falhas em `test_ice_climb`.
- [ ] **Step 3: Implementar.** Extrair `step(delta, input_x, jump_pressed)` de `_physics_process` (que passa a só ler o teclado e chamar `step`). Os testes de movimento existentes continuam verdes.
- [ ] **Step 4: Rodar e ver passar** (com `--import` antes).
- [ ] **Step 5: Commit** `feat: bode gruda no gelo e pula de parede com o martelo`.

---

### Task 5: Salas sem bode e portas

**Files:**
- Move: `scenes/room.tscn` → `scenes/rooms/sala1.tscn` (`git mv`; tirar o nó `Player`; abrir um vão de 3 de altura na `WallRight`, no nível do chão)
- Modify: `scripts/room.gd`
- Create: `scripts/door.gd`, `scenes/door.tscn`, `tests/test_door.gd`
- Modify: `tests/test_room.gd` (passa a testar só a sala, sem bode)
- Modify: `scenes/main.tscn` (só o caminho novo da sala; o jogo fica sem bode entre esta task e a Task 6, os testes não dependem dele)

**Interfaces:**
- Produces: `class_name Door extends Area3D`; `@export var door_id: String`; `@export var target_room: String`; `@export var target_door: String`; `signal used(target_room: String, target_door: String)` (emitido ao tocar um `Player`); nó filho `Arrival` (`Marker3D`) 1,5 para dentro da sala, fora do gatilho.
- Produces em `Room`: `@export var room_id: String`; `func spawn_position() -> Vector3`; `func statue_position(id: String) -> Variant` (posição ou `null`); `func arrival_position(door_id: String) -> Variant`; `func statues() -> Array[ThorStatue]`; `func doors() -> Array[Door]`. `Room` não guarda mais `Player`, `save_path` nem lógica de morte (vão para `World` na Task 6).
- `sala1.tscn`: `room_id = "sala1"`, porta `Door` com `door_id = "leste"`, `target_room = "sala2"`, `target_door = "oeste"` no vão da parede direita.

- [ ] **Step 1: Escrever os testes**: em `test_room.gd`, `test_spawn_position`, `test_statue_position_known_and_unknown` (`"sala1"` → posição da estátua; `"x"` → `null`), `test_arrival_inside_room` (o `Arrival` da porta leste fica à esquerda do gatilho); em `test_door.gd`, `test_touch_emits_used_once` (porta real + bode real com `set_physics_process(false)` dentro do gatilho, `await physics_frames(2)` → `used("sala2", "oeste")` 1 vez) e `test_arrival_outside_trigger` (bode no `Arrival`, `await physics_frames(2)` → `used` não sai).
- [ ] **Step 2: Rodar e ver falhar.** Expected: falhas em `test_room` e `test_door`.
- [ ] **Step 3: Implementar** `Door`, o novo `Room` e o `git mv` da cena. A estátua deixa de gravar o save: `ThorStatue.activate` cura e emite `signal activated(statue_id: String)`; quem grava é o `World`. Ajustar `tests/test_thor_statue.gd`: `test_activate_saves_statue_id` vira `test_activate_emits_statue_id`.
- [ ] **Step 4: Rodar e ver passar** (com `--import` antes). Os testes de morte e save saem de `test_room.gd` e voltam na Task 6.
- [ ] **Step 5: Commit** `refactor: sala sem bode, com portas e estátua que avisa`.

---

### Task 6: Mundo que troca de sala, salva e renasce

**Files:**
- Create: `scripts/world.gd`, `tests/test_world.gd`
- Modify: `scenes/main.tscn` (no `GameViewport`, trocar a instância de `Room` por um nó `World` com uma instância de `player.tscn` como filho; manter `stretch = true` e `stretch_shrink = 4`), `scripts/side_camera.gd` (achar o bode pelo grupo `player`, se ainda não achar)

**Interfaces:**
- Consumes: `SaveData` (Task 1), `Player` (Tasks 2 e 4), `AbilityPickup` (Task 2), `Room`/`Door`/`ThorStatue` (Task 5), `SaveGame`.
- Produces: `class_name World extends Node3D`; `const ROOMS := {"sala1": "res://scenes/rooms/sala1.tscn", "sala2": "res://scenes/rooms/sala2.tscn"}`; `const RESPAWN_INVULN_SECONDS := 1.5` (vindo do `Room` antigo); `@export var save_path: String = SaveGame.DEFAULT_PATH`; `var current_room: Room`; `var data: SaveData`; `func load_room(id: String, arrival_door: String = "") -> void` (id desconhecido vira `sala1`; posição: `Arrival` da porta, senão estátua salva se a sala bater, senão `SpawnPoint`); `func respawn() -> void`; `signal room_changed(id: String)`.
- Ligações ao carregar uma sala: `Door.used` → `call_deferred("load_room", target_room, target_door)`; `ThorStatue.activated` → `data.statue_id = id`, `data.room_id = current_room.room_id`, grava; `AbilityPickup.collected` → `data.add_ability(id)`, grava na hora; `AbilityPickup.refresh(player)`.
- Ao iniciar: `data = SaveData.from_dict(SaveGame.read(save_path))`, passa `data.abilities` ao bode e chama `load_room(data.room_id)`. Ao `Player.died`: `respawn()` = `load_room(data.room_id)`, `heal_full()`, `grant_invulnerability(RESPAWN_INVULN_SECONDS)`.

- [ ] **Step 1: Escrever os testes**, com `save_path = "user://test_world.json"` apagado ao fim, e um `sala2.tscn` mínimo provisório (chão, `SpawnPoint`, porta `oeste`) só para os testes passarem antes da Task 7: `test_no_save_starts_sala1_spawn`; `test_old_save_starts_at_statue` (`{"statue_id": "sala1"}`); `test_unknown_room_falls_back` (`{"room_id": "x"}` → `sala1` no spawn); `test_door_moves_to_other_room` (chamar `load_room("sala2", "oeste")`, `await tree.process_frame`: `current_room.room_id == "sala2"`, bode no `Arrival` da porta oeste); `test_statue_touch_saves_room_and_statue`; `test_pickup_saves_ability_immediately`; `test_death_in_sala2_respawns_at_saved_statue` (save na estátua da sala 1, `load_room("sala2")`, zerar a vida, `await tree.process_frame` → sala 1, na estátua, vida cheia, com a habilidade); `test_main_scene_still_low_res` (instanciar `main.tscn`, `await tree.process_frame`, `GameViewport.size == Vector2i(320, 180)`).
- [ ] **Step 2: Rodar e ver falhar.** Expected: falhas em `test_world`.
- [ ] **Step 3: Implementar `World`.** A sala antiga sai com `queue_free()` e a nova entra no mesmo quadro diferido; o bode nunca é recriado (mantém vida e habilidades).
- [ ] **Step 4: Rodar a suíte inteira e ver passar** (com `--import` antes).
- [ ] **Step 5: Commit** `feat: mundo troca de sala, salva sala e habilidade`.

---

### Task 7: Sala 2, gelo

**Files:**
- Create/replace: `scenes/rooms/sala2.tscn` (substitui o provisório da Task 6)
- Modify: `tests/test_world.gd` (só se os nomes de nós mudarem)
- Create: `tests/test_sala2_layout.gd`

**Interfaces:**
- Consumes: `Room`, `Door`, `ThorStatue`, `Sheep`, `AbilityPickup`, `StoneBlock`, `IceWall`.
- Layout (`room_id = "sala2"`, piso de neve, ambiente mais frio que a sala 1, montanha ao fundo maior que na sala 1):
  - Oeste: porta `oeste` → `sala1`/`leste`. `SpawnPoint` perto dela.
  - Meio: uma ovelha patrulhando no chão (sozinha: mapa fácil).
  - Plataforma alcançável com pulo normal, com o `AbilityPickup` em cima.
  - Leste: entrada do poço fechada por um `StoneBlock`. Atrás dele, um poço de 4 de largura e 12 de altura entre duas `IceWall`, visível de fora (pista visual).
  - Topo do poço: plataforma com `ThorStatue` `statue_id = "sala2_topo"` e, ao fundo, a montanha bem grande. A saída para o próximo mapa fica fechada por uma parede simples (próximo marco).

- [ ] **Step 1: Escrever os testes** de estrutura: `test_has_required_nodes` (porta `oeste` apontando para `sala1`, um `AbilityPickup` com `martelo_gelo`, um `StoneBlock`, pelo menos duas `IceWall`, estátua `sala2_topo`); `test_top_statue_unreachable_by_jump` (diferença de altura entre o chão e a estátua maior que a altura máxima do pulo, `JUMP_SPEED² / (2 * GRAVITY)` ≈ 1,6, com folga); `test_pickup_reachable_by_jump` (altura da plataforma do pickup menor que 1,4).
- [ ] **Step 2: Rodar e ver falhar.** Expected: falhas em `test_sala2_layout`.
- [ ] **Step 3: Montar a cena.** Gelo em azul-claro, pedra cinza-escura rachada, neve branca: as três leituras precisam ser distintas em 320x180.
- [ ] **Step 4: Rodar a suíte inteira e ver passar** (com `--import` antes).
- [ ] **Step 5: Commit** `feat: sala de gelo com poço e primeira habilidade`.

---

### Task 8: Aviso da habilidade no HUD e verificação manual

**Files:**
- Modify: `scripts/hud.gd`, `scenes/main.tscn` (um segundo `Label` para o aviso)
- Modify: `README.md` (seção Rodar: comando de `--import` antes dos testes, que já está lá, e a nova tecla de pulo de parede: Espaço grudado)

**Interfaces:**
- Consumes: `Player.ability_gained` (Task 2).
- Produces: `Label` `AbilityNotice` escondido; ao `ability_gained`, mostra "Martelo desperto: quebra pedra e gruda no gelo" por 3 s.

- [ ] **Step 1: Escrever o teste** em `tests/test_view.gd`: `test_ability_notice_shows_and_hides` (instanciar `main.tscn`, `grant_ability` no bode, aviso visível; após 3 s de `tick` simulado ou chamando o método de tempo do HUD com `delta = 3.1`, invisível).
- [ ] **Step 2: Rodar e ver falhar.**
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Rodar a suíte inteira e ver passar.** Run: `godot --headless --path . --import` e `godot --headless --path . -s tests/run_tests.gd`. Expected: `0 failed`.
- [ ] **Step 5: Verificação manual do critério de pronto.** Apagar o save (`user://save.json`) e rodar `godot --path .`. Conferir, na ordem: tudo da primeira sala ainda funciona; a porta da direita leva à sala 2 e a da esquerda da sala 2 volta; sem a habilidade, a pedra não quebra e não dá para grudar no gelo; pegar o objeto mostra o aviso; a pedra quebra com o martelo; segurando contra o gelo o bode gruda, e Espaço pula de parede até o topo; tocar a estátua do topo salva; fechar e reabrir começa no topo da sala 2 com a habilidade; morrer renasce na última estátua tocada. Registrar o resultado na descrição do PR, com capturas em 320x180.
- [ ] **Step 6: Commit** `feat: aviso da habilidade no HUD`.
