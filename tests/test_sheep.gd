extends TestCase

const SHEEP_SCENE := preload("res://scenes/sheep.tscn")
const PLAYER_SCENE := preload("res://scenes/player.tscn")

var _nodes: Array[Node] = []


func after_each() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	await tree.process_frame


func _add(scene: PackedScene) -> Node:
	var n := scene.instantiate()
	tree.root.add_child(n)
	n.set_physics_process(false)
	_nodes.append(n)
	return n


func test_next_direction_flips_at_bounds() -> void:
	check_eq(Sheep.next_direction(5.0, 1, 0.0, 5.0), -1, "vira no limite direito")
	check_eq(Sheep.next_direction(0.0, -1, 0.0, 5.0), 1, "vira no limite esquerdo")
	check_eq(Sheep.next_direction(2.0, 1, 0.0, 5.0), 1, "no meio mantém")
	check_eq(Sheep.next_direction(6.0, 1, 0.0, 5.0), -1, "passou do limite: vira")
	check_eq(Sheep.next_direction(6.0, -1, 0.0, 5.0), -1, "passou mas já volta: mantém")


func test_three_hits_down_the_sheep() -> void:
	var s: Sheep = _add(SHEEP_SCENE)
	check(s.is_in_group("hurtable"), "ovelha é hurtable")
	var count := [0]
	s.downed.connect(func(): count[0] += 1)
	for i in 3:
		s.take_hit(1, 0.0)
	check_eq(count[0], 1, "downed uma vez após 3 golpes")


func test_hit_after_downed_is_ignored() -> void:
	var s: Sheep = _add(SHEEP_SCENE)
	var count := [0]
	s.downed.connect(func(): count[0] += 1)
	for i in 4:
		s.take_hit(1, 0.0)
	check_eq(count[0], 1, "4º golpe não muda nada")
	check_eq(s.health.hp, 0, "vida em 0")


func test_contact_damages_player() -> void:
	var s: Sheep = _add(SHEEP_SCENE)
	var p: Player = _add(PLAYER_SCENE)
	s.get_node("ContactArea").body_entered.emit(p)
	check_eq(p.health.hp, 4, "encostar tira 1 de vida")


func test_downed_sheep_does_not_hurt() -> void:
	var s: Sheep = _add(SHEEP_SCENE)
	var p: Player = _add(PLAYER_SCENE)
	for i in 3:
		s.take_hit(1, 0.0)
	s.get_node("ContactArea").body_entered.emit(p)
	check_eq(p.health.hp, 5, "ovelha caída não fere")
