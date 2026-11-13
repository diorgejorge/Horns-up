extends TestCase

const PATH := "user://test_statue.json"
const STATUE_SCENE := preload("res://scenes/thor_statue.tscn")
const PLAYER_SCENE := preload("res://scenes/player.tscn")

var _nodes: Array[Node] = []


func after_each() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)
	await tree.process_frame


func _setup() -> Array:
	var st: ThorStatue = STATUE_SCENE.instantiate()
	st.statue_id = "sala1"
	st.save_path = PATH
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


func test_activate_saves_statue_id() -> void:
	var nodes := _setup()
	nodes[0].activate(nodes[1])
	check_eq(SaveGame.read(PATH).get("statue_id"), "sala1", "salvou a estátua")


func test_touch_triggers_activate() -> void:
	var nodes := _setup()
	nodes[0].body_entered.emit(nodes[1])
	check_eq(nodes[1].health.hp, 5, "toque cura")
	check_eq(SaveGame.read(PATH).get("statue_id"), "sala1", "toque salva")
