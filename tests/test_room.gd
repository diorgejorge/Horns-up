extends TestCase

const PATH := "user://test_room.json"
const ROOM_SCENE := preload("res://scenes/room.tscn")

var _room: Room


func after_each() -> void:
	if is_instance_valid(_room):
		_room.queue_free()
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)
	await tree.process_frame


func _write_raw(text: String) -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _make_room() -> Room:
	_room = ROOM_SCENE.instantiate()
	_room.save_path = PATH
	tree.root.add_child(_room)
	return _room


func _spawn_pos(room: Room) -> Vector3:
	return room.get_node("SpawnPoint").global_position


func _statue_pos(room: Room) -> Vector3:
	return room.get_node("ThorStatue").global_position


func test_starts_at_spawn_without_save() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)
	var room := _make_room()
	check_eq(room.respawn_position(), _spawn_pos(room), "sem save: ponto inicial")
	check_eq(room.get_node("Player").global_position, _spawn_pos(room), "bode começa no ponto inicial")


func test_starts_at_statue_with_save() -> void:
	SaveGame.write({"statue_id": "sala1"}, PATH)
	var room := _make_room()
	check_eq(room.respawn_position(), _statue_pos(room), "com save: na estátua")
	check_eq(room.get_node("Player").global_position, _statue_pos(room), "bode começa na estátua")


func test_corrupt_save_falls_back_to_spawn() -> void:
	_write_raw("{nao json")
	var room := _make_room()
	check_eq(room.respawn_position(), _spawn_pos(room), "save corrompido: ponto inicial")


func test_unknown_statue_id_falls_back_to_spawn() -> void:
	SaveGame.write({"statue_id": "nao_existe"}, PATH)
	var room := _make_room()
	check_eq(room.respawn_position(), _spawn_pos(room), "estátua inexistente: ponto inicial")


func test_death_respawns_with_full_hp() -> void:
	SaveGame.write({"statue_id": "sala1"}, PATH)
	var room := _make_room()
	var player: Player = room.get_node("Player")
	player.global_position = Vector3(3, 5, 0)
	player.health.take_damage(Player.MAX_HP)
	check_eq(player.global_position, _statue_pos(room), "renasce na estátua")
	check_eq(player.health.hp, Player.MAX_HP, "vida cheia")
	player.health.tick(Player.INVULN_SECONDS)
	player.health.take_damage(Player.MAX_HP)
	check_eq(player.health.hp, Player.MAX_HP, "segunda morte também renasce")


func test_respawn_grants_short_invulnerability() -> void:
	var room := _make_room()
	var player: Player = room.get_node("Player")
	player.health.take_damage(Player.MAX_HP)
	check(not player.health.take_damage(1), "logo após renascer, dano é ignorado")
	check_eq(player.health.hp, Player.MAX_HP, "vida segue cheia")
	player.health.tick(Room.RESPAWN_INVULN_SECONDS)
	check(player.health.take_damage(1), "proteção acaba após RESPAWN_INVULN_SECONDS")


func test_room_statue_uses_room_save_path() -> void:
	var room := _make_room()
	check_eq(room.get_node("ThorStatue").save_path, PATH, "estátua grava no save da sala")
