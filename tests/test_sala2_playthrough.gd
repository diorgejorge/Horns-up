extends TestCase
## Percorre a sala 2 como o jogador: quebra a pedra, entra no poço e escala
## o gelo até a estátua do topo, só com step() (sem teclado).

const PATH := "user://test_playthrough.json"
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const DT := 1.0 / 60.0

var _world: World


func after_each() -> void:
	if is_instance_valid(_world):
		_world.queue_free()
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)
	await tree.process_frame


func _make_world(with_ability: bool) -> World:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)
	_world = World.new()
	_world.save_path = PATH
	var p: Player = PLAYER_SCENE.instantiate()
	p.name = "Player"
	_world.add_child(p)
	tree.root.add_child(_world)
	p.set_physics_process(false)
	if with_ability:
		p.grant_ability(Player.ABILITY_ICE_HAMMER)
	_world.load_room("sala2")
	p.global_position = Vector3(2, 0, 0)
	return _world


## Anda/sobe segurando para a direita; pula do chão quando encosta numa
## parede e pula de novo sempre que estiver grudado.
func _run_right(p: Player, frames: int, attack_at := -1) -> void:
	for i in frames:
		await tree.physics_frame
		if i == attack_at:
			p.try_attack()
		p.step(DT, 1.0, p.clinging or (p.is_on_floor() and p.is_on_wall()))


func test_without_ability_stone_blocks_the_shaft() -> void:
	var w := _make_world(false)
	var p := w.player
	await physics_frames(2)
	await _run_right(p, 120, 30)
	check(not w.current_room.get_node("StoneBlock").broken, "pedra inteira")
	check(p.global_position.x < 4.0, "barrado pela pedra (x=%f)" % p.global_position.x)


func test_with_ability_reaches_top_statue() -> void:
	var w := _make_world(true)
	var p := w.player
	await physics_frames(2)
	await _run_right(p, 40, 20) # encosta na pedra e bate
	check(w.current_room.get_node("StoneBlock").broken, "pedra quebrou")
	await _run_right(p, 60 * 12)
	var top: Vector3 = w.current_room.statue_position("sala2_topo")
	check(p.global_position.y > top.y - 0.2, "chegou ao topo (y=%f)" % p.global_position.y)
	check_eq(SaveData.from_dict(SaveGame.read(PATH)).statue_id, "sala2_topo", "estátua do topo salvou")
