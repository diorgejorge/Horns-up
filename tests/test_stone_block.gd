extends TestCase

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const STONE_SCENE := preload("res://scenes/stone_block.tscn")
const FakeTarget := preload("res://tests/fake_target.gd")
const DT := 1.0 / 60.0

var _nodes: Array[Node] = []


func after_each() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	await tree.process_frame


func _spawn_player(x: float) -> Player:
	var p: Player = PLAYER_SCENE.instantiate()
	tree.root.add_child(p)
	p.set_physics_process(false)
	p.global_position = Vector3(x, 0, 0)
	_nodes.append(p)
	return p


## Pedra real (StaticBody3D com shape) logo à frente do bode.
func _spawn_stone(x: float) -> StoneBlock:
	var s: StoneBlock = STONE_SCENE.instantiate()
	tree.root.add_child(s)
	s.global_position = Vector3(x + 1.6, 0, 0)
	_nodes.append(s)
	return s


func _swing(p: Player) -> void:
	await physics_frames(2)
	p.try_attack()
	for i in 10:
		await tree.physics_frame
		p.tick_attack(DT)


func test_smash_once() -> void:
	var s := _spawn_stone(100)
	var count := [0]
	s.smashed.connect(func(): count[0] += 1)
	s.smash()
	s.smash()
	check(s.broken, "quebrou")
	check_eq(count[0], 1, "smashed uma vez")


func test_swing_without_ability_does_not_break() -> void:
	var p := _spawn_player(200)
	var s := _spawn_stone(200)
	await _swing(p)
	check(not s.broken, "sem habilidade não quebra")


func test_swing_with_ability_breaks_once() -> void:
	var p := _spawn_player(300)
	var s := _spawn_stone(300)
	p.grant_ability(Player.ABILITY_ICE_HAMMER)
	var count := [0]
	s.smashed.connect(func(): count[0] += 1)
	await _swing(p)
	check(s.broken, "com habilidade quebra")
	check_eq(count[0], 1, "uma pancada = uma quebra")


func test_hurtable_still_takes_hits() -> void:
	var p := _spawn_player(400)
	p.grant_ability(Player.ABILITY_ICE_HAMMER)
	var t := FakeTarget.new()
	tree.root.add_child(t)
	t.global_position = Vector3(401.2, 0.8, 0)
	_nodes.append(t)
	await _swing(p)
	check_eq(t.hits, 1, "alvo hurtable segue apanhando")
