extends TestCase

const SALA1 := preload("res://scenes/rooms/sala1.tscn")

var _room: Room


func after_each() -> void:
	if is_instance_valid(_room):
		_room.queue_free()
	await tree.process_frame


func _make_room() -> Room:
	_room = SALA1.instantiate()
	tree.root.add_child(_room)
	return _room


func test_room_id() -> void:
	check_eq(_make_room().room_id, "sala1", "id da sala")


func test_spawn_position() -> void:
	var room := _make_room()
	check_eq(room.spawn_position(), room.get_node("SpawnPoint").global_position, "ponto inicial")


func test_statue_position_known_and_unknown() -> void:
	var room := _make_room()
	check_eq(room.statue_position("sala1"), room.get_node("ThorStatue").global_position, "estátua conhecida")
	check_eq(room.statue_position("x"), null, "estátua desconhecida")
	check_eq(room.statue_position(""), null, "sem id")


func test_arrival_inside_room() -> void:
	var room := _make_room()
	var door: Door = room.get_node("DoorLeste")
	check_eq(door.target_room, "sala2", "leva à sala 2")
	check_eq(door.target_door, "oeste", "chega pela porta oeste")
	var arrival = room.arrival_position("leste")
	check(arrival != null, "porta leste existe")
	check(arrival.x < door.global_position.x - 1.0, "chegada fica para dentro da sala")
	check_eq(room.arrival_position("nao_existe"), null, "porta desconhecida")


func test_room_has_no_player() -> void:
	check(_make_room().find_children("*", "CharacterBody3D").all(func(n): return not n is Player), "bode mora no World")
