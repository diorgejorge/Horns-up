extends TestCase

const DOOR_SCENE := preload("res://scenes/door.tscn")
const PLAYER_SCENE := preload("res://scenes/player.tscn")

var _nodes: Array[Node] = []


func after_each() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	await tree.process_frame


func _setup(x: float) -> Array:
	var d: Door = DOOR_SCENE.instantiate()
	d.door_id = "leste"
	d.target_room = "sala2"
	d.target_door = "oeste"
	tree.root.add_child(d)
	d.global_position = Vector3(x, 0, 0)
	var p: Player = PLAYER_SCENE.instantiate()
	tree.root.add_child(p)
	p.set_physics_process(false)
	p.global_position = Vector3(5000, 0, 0)
	_nodes.append_array([d, p])
	return [d, p]


func test_touch_emits_used_once() -> void:
	var nodes := _setup(2000)
	var d: Door = nodes[0]
	var calls: Array = []
	d.used.connect(func(r, t): calls.append([r, t]))
	nodes[1].global_position = d.global_position # corpo real dentro do gatilho
	await physics_frames(3)
	check_eq(calls.size(), 1, "used uma vez")
	if calls.size() > 0:
		check_eq(calls[0], ["sala2", "oeste"], "destino")


func test_arrival_outside_trigger() -> void:
	var nodes := _setup(2100)
	var d: Door = nodes[0]
	var calls := [0]
	d.used.connect(func(_r, _t): calls[0] += 1)
	nodes[1].global_position = d.arrival_position()
	await physics_frames(3)
	check_eq(calls[0], 0, "chegar não aciona a porta")
