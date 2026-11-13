extends TestCase

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const FakeTarget := preload("res://tests/fake_target.gd")
const DT := 1.0 / 60.0

var _nodes: Array[Node] = []


func after_each() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	await tree.process_frame


func _spawn_player() -> Player:
	var p: Player = PLAYER_SCENE.instantiate()
	tree.root.add_child(p)
	p.set_physics_process(false) # sem gravidade nem leitura de teclado
	_nodes.append(p)
	return p


func _spawn_target(pos: Vector3) -> Node3D:
	var t := FakeTarget.new()
	tree.root.add_child(t)
	t.global_position = pos
	_nodes.append(t)
	return t


func test_hitbox_offset_follows_facing() -> void:
	check(is_equal_approx(Player.hitbox_offset(-1).x, -1.2), "esquerda")
	check(Player.hitbox_offset(1).is_equal_approx(Vector3(1.2, 0.8, 0)), "direita")


func test_attack_has_cooldown() -> void:
	var p := _spawn_player()
	check(p.try_attack(), "primeiro ataque sai")
	check(not p.try_attack(), "durante a recarga não sai")
	var t := 0.0
	while t < Player.ATTACK_COOLDOWN - 0.001:
		p.tick_attack(DT)
		t += DT
	p.tick_attack(DT)
	check(p.try_attack(), "sai de novo após a recarga")


func test_swing_hits_target_in_front_once() -> void:
	var p := _spawn_player()
	var target = _spawn_target(Vector3(1.2, 0.8, 0))
	await physics_frames(2)
	check(p.try_attack(), "ataque sai")
	for i in 10: # mais quadros que o tempo ativo
		await tree.physics_frame
		p.tick_attack(DT)
	check_eq(target.hits, 1, "uma pancada = um golpe")


func test_swing_ignores_target_behind() -> void:
	var p := _spawn_player()
	p.facing = 1
	var target = _spawn_target(Vector3(-1.2, 0.8, 0))
	await physics_frames(2)
	p.try_attack()
	for i in 10:
		await tree.physics_frame
		p.tick_attack(DT)
	check_eq(target.hits, 0, "alvo atrás não apanha")
