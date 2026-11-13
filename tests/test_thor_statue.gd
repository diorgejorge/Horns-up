extends TestCase

const STATUE_SCENE := preload("res://scenes/thor_statue.tscn")
const PLAYER_SCENE := preload("res://scenes/player.tscn")

var _nodes: Array[Node] = []


func after_each() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	await tree.process_frame


func _setup() -> Array:
	var st: ThorStatue = STATUE_SCENE.instantiate()
	st.statue_id = "sala1"
	tree.root.add_child(st)
	var p: Player = PLAYER_SCENE.instantiate()
	tree.root.add_child(p)
	p.set_physics_process(false)
	_nodes.append_array([st, p])
	p.health.take_damage(3)
	return [st, p]


func test_activate_heals_fully() -> void:
	var nodes := _setup()
	check_eq(nodes[1].health.hp, 2, "começa com 2")
	nodes[0].activate(nodes[1])
	check_eq(nodes[1].health.hp, 5, "vida cheia")


func test_activate_emits_statue_id() -> void:
	var nodes := _setup()
	var got: Array = []
	nodes[0].activated.connect(func(id): got.append(id))
	nodes[0].activate(nodes[1])
	check_eq(got, ["sala1"], "avisou o id")


func test_touch_triggers_activate() -> void:
	var nodes := _setup()
	var got: Array = []
	nodes[0].activated.connect(func(id): got.append(id))
	nodes[0].body_entered.emit(nodes[1])
	check_eq(nodes[1].health.hp, 5, "toque cura")
	check_eq(got, ["sala1"], "toque avisa")
