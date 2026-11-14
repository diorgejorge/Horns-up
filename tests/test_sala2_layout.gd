extends TestCase

const SALA2 := preload("res://scenes/rooms/sala2.tscn")

var _room: Room


func after_each() -> void:
	if is_instance_valid(_room):
		_room.queue_free()
	await tree.process_frame


func _make() -> Room:
	_room = SALA2.instantiate()
	tree.root.add_child(_room)
	return _room


func _max_jump_height() -> float:
	return Player.JUMP_SPEED * Player.JUMP_SPEED / (2.0 * Player.GRAVITY)


func test_has_required_nodes() -> void:
	var r := _make()
	check_eq(r.room_id, "sala2", "id")
	var door: Door = r.get_node("DoorOeste")
	check_eq([door.door_id, door.target_room, door.target_door], ["oeste", "sala1", "leste"], "porta oeste")
	check_eq(r.pickups().size(), 1, "um objeto de habilidade")
	check_eq(r.pickups()[0].ability_id, Player.ABILITY_ICE_HAMMER, "é o martelo de gelo")
	check_eq(r.find_children("*", "StaticBody3D").filter(func(n): return n is StoneBlock).size(), 1, "uma pedra")
	check(r.find_children("*", "StaticBody3D").filter(func(n): return n is IceWall).size() >= 2, "duas paredes de gelo")
	check(r.statue_position("sala2_topo") != null, "estátua do topo")


func test_top_statue_unreachable_by_jump() -> void:
	var r := _make()
	var h: float = r.statue_position("sala2_topo").y
	check(h > _max_jump_height() * 3.0, "topo bem acima do pulo (%f)" % h)


func test_pickup_reachable_by_jump() -> void:
	var r := _make()
	var h := r.pickups()[0].global_position.y
	check(h < 1.4 and h < _max_jump_height(), "objeto alcançável (%f)" % h)


func test_stone_taller_than_jump() -> void:
	var r := _make()
	var stone: StoneBlock = r.get_node("StoneBlock")
	var box: BoxShape3D = stone.get_node("CollisionShape3D").shape
	check(box.size.y > _max_jump_height() + 1.0, "não dá para pular a pedra")


func test_arrival_inside_room() -> void:
	var r := _make()
	check(r.arrival_position("oeste").x > r.get_node("DoorOeste").global_position.x + 1.0, "chegada para dentro")
