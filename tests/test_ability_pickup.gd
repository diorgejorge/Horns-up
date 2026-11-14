extends TestCase

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const PICKUP_SCENE := preload("res://scenes/ability_pickup.tscn")

var _nodes: Array[Node] = []


func after_each() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	await tree.process_frame


func _spawn_player(pos: Vector3) -> Player:
	var p: Player = PLAYER_SCENE.instantiate()
	tree.root.add_child(p)
	p.set_physics_process(false)
	p.global_position = pos
	_nodes.append(p)
	return p


func _spawn_pickup(pos: Vector3) -> AbilityPickup:
	var a: AbilityPickup = PICKUP_SCENE.instantiate()
	tree.root.add_child(a)
	a.global_position = pos
	_nodes.append(a)
	return a


func test_grant_ability_once() -> void:
	var p := _spawn_player(Vector3.ZERO)
	var count := [0]
	p.ability_gained.connect(func(_id): count[0] += 1)
	check(p.grant_ability(Player.ABILITY_ICE_HAMMER), "primeira vez")
	check(not p.grant_ability(Player.ABILITY_ICE_HAMMER), "segunda vez não")
	check(p.has_ability(Player.ABILITY_ICE_HAMMER), "tem a habilidade")
	check_eq(count[0], 1, "sinal uma vez")


func test_touch_grants_and_hides() -> void:
	var a := _spawn_pickup(Vector3(20, 0, 0))
	var count := [0]
	a.collected.connect(func(_id): count[0] += 1)
	var p := _spawn_player(Vector3(20, 0, 0)) # corpo real dentro do gatilho
	await physics_frames(3)
	check(p.has_ability(Player.ABILITY_ICE_HAMMER), "bode ganhou")
	check_eq(count[0], 1, "collected uma vez")
	check(not a.visible, "objeto sumiu")
	await physics_frames(3)
	check_eq(count[0], 1, "continua uma vez")


func test_refresh_hides_if_already_owned() -> void:
	var a := _spawn_pickup(Vector3(40, 0, 0))
	var p := _spawn_player(Vector3(0, 0, 0))
	p.grant_ability(Player.ABILITY_ICE_HAMMER)
	a.refresh(p)
	check(not a.visible, "escondido")
	check(a.taken, "marcado como pego")


func test_refresh_keeps_if_not_owned() -> void:
	var a := _spawn_pickup(Vector3(60, 0, 0))
	var p := _spawn_player(Vector3(0, 0, 0))
	a.refresh(p)
	check(a.visible, "continua visível")
