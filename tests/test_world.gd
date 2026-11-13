extends TestCase

const PATH := "user://test_world.json"
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const MAIN_SCENE := preload("res://scenes/main.tscn")

var _world: World


func after_each() -> void:
	if is_instance_valid(_world):
		_world.queue_free()
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)
	await tree.process_frame


func _clear() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)


func _make_world() -> World:
	_world = World.new()
	_world.save_path = PATH
	var p: Player = PLAYER_SCENE.instantiate()
	p.name = "Player"
	_world.add_child(p)
	tree.root.add_child(_world)
	p.set_physics_process(false)
	return _world


func test_no_save_starts_sala1_spawn() -> void:
	_clear()
	var w := _make_world()
	check_eq(w.current_room.room_id, "sala1", "sala 1")
	check_eq(w.player.global_position, w.current_room.spawn_position(), "ponto inicial")
	check_eq(w.player.abilities.size(), 0, "sem habilidades")


func test_old_save_starts_at_statue() -> void:
	SaveGame.write({"statue_id": "sala1"}, PATH)
	var w := _make_world()
	check_eq(w.current_room.room_id, "sala1", "sala 1")
	check_eq(w.player.global_position, w.current_room.statue_position("sala1"), "na estátua")


func test_corrupt_save_falls_back() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("{nao json")
	f.close()
	var w := _make_world()
	check_eq(w.current_room.room_id, "sala1", "sala 1")
	check_eq(w.player.global_position, w.current_room.spawn_position(), "ponto inicial")


func test_unknown_room_falls_back() -> void:
	SaveGame.write({"room_id": "x", "statue_id": "sala1"}, PATH)
	var w := _make_world()
	check_eq(w.current_room.room_id, "sala1", "sala desconhecida vira sala 1")


func test_unknown_statue_falls_back_to_spawn() -> void:
	SaveGame.write({"room_id": "sala1", "statue_id": "nao_existe"}, PATH)
	var w := _make_world()
	check_eq(w.player.global_position, w.current_room.spawn_position(), "estátua inexistente: ponto inicial")


func test_save_restores_abilities_without_signal() -> void:
	SaveGame.write({"abilities": [Player.ABILITY_ICE_HAMMER]}, PATH)
	var w := _make_world()
	check(w.player.has_ability(Player.ABILITY_ICE_HAMMER), "habilidade carregada")


func test_door_moves_to_other_room() -> void:
	_clear()
	var w := _make_world()
	var door: Door = w.current_room.get_node("DoorLeste")
	door.used.emit(door.target_room, door.target_door)
	await tree.process_frame
	check_eq(w.current_room.room_id, "sala2", "foi para a sala 2")
	check_eq(w.player.global_position, w.current_room.arrival_position("oeste"), "chegou pela porta oeste")
	check_eq(w.get_children().filter(func(n): return n is Room).size(), 1, "só uma sala carregada")
	await physics_frames(3)
	check(not w.player.has_ability(Player.ABILITY_ICE_HAMMER), "entrar na sala não dá a habilidade")
	check_eq(w.current_room.room_id, "sala2", "não voltou pela porta")


func test_round_trip_through_doors() -> void:
	_clear()
	var w := _make_world()
	w.load_room("sala2", "oeste")
	w.load_room("sala1", "leste")
	check_eq(w.current_room.room_id, "sala1", "voltou")
	check_eq(w.player.global_position, w.current_room.arrival_position("leste"), "chegou pela porta leste")


func test_statue_touch_saves_room_and_statue() -> void:
	_clear()
	var w := _make_world()
	w.load_room("sala2")
	var statue: ThorStatue = w.current_room.get_node("ThorStatue")
	statue.activate(w.player)
	var saved := SaveData.from_dict(SaveGame.read(PATH))
	check_eq(saved.room_id, "sala2", "sala salva")
	check_eq(saved.statue_id, "sala2_topo", "estátua salva")


func test_pickup_saves_ability_immediately() -> void:
	_clear()
	var w := _make_world()
	w.load_room("sala2")
	var pickup: AbilityPickup = w.current_room.get_node("AbilityPickup")
	pickup.body_entered.emit(w.player)
	check(w.player.has_ability(Player.ABILITY_ICE_HAMMER), "bode tem")
	check_eq(SaveData.from_dict(SaveGame.read(PATH)).abilities, PackedStringArray([Player.ABILITY_ICE_HAMMER]), "save tem")


func test_pickup_hidden_when_returning() -> void:
	_clear()
	var w := _make_world()
	w.player.grant_ability(Player.ABILITY_ICE_HAMMER)
	w.load_room("sala2")
	check(not w.current_room.get_node("AbilityPickup").visible, "objeto não aparece de novo")


func test_death_in_sala2_respawns_at_saved_statue() -> void:
	_clear()
	var w := _make_world()
	w.current_room.get_node("ThorStatue").activate(w.player)
	w.load_room("sala2")
	w.current_room.get_node("AbilityPickup").body_entered.emit(w.player)
	w.player.health.take_damage(Player.MAX_HP)
	await tree.process_frame
	check_eq(w.current_room.room_id, "sala1", "voltou para a sala 1")
	check_eq(w.player.global_position, w.current_room.statue_position("sala1"), "na estátua")
	check_eq(w.player.health.hp, Player.MAX_HP, "vida cheia")
	check(w.player.has_ability(Player.ABILITY_ICE_HAMMER), "manteve a habilidade")


func test_respawn_grants_short_invulnerability() -> void:
	_clear()
	var w := _make_world()
	w.player.health.take_damage(Player.MAX_HP)
	await tree.process_frame
	check(not w.player.health.take_damage(1), "logo após renascer, dano é ignorado")
	w.player.health.tick(World.RESPAWN_INVULN_SECONDS)
	check(w.player.health.take_damage(1), "proteção acaba")


func test_main_scene_has_world_and_player() -> void:
	var main: Node = MAIN_SCENE.instantiate()
	main.find_child("World", true, false).save_path = PATH
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame
	var w: World = main.find_child("World", true, false)
	check(w.current_room != null, "sala carregada")
	check_eq(main.find_children("*", "SubViewport")[0].size, Vector2i(320, 180), "segue 320x180")
	main.queue_free()
	await tree.process_frame
