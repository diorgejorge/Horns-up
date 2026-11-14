extends TestCase
## Protótipo 2.5D: o bode em sprite tem a mesma física do bode em modelo.

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const SPRITE_PLAYER_SCENE := preload("res://scenes/prototipo/player_sprite.tscn")
const PROTO_SCENE := preload("res://scenes/prototipo/prototipo_25d.tscn")
const PATH := "user://test_prototipo.json"
const DT := 1.0 / 60.0

var _nodes: Array[Node] = []


func after_each() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)
	await tree.process_frame


func test_player_has_sprite_not_model() -> void:
	var p: Node = SPRITE_PLAYER_SCENE.instantiate()
	_nodes.append(p)
	check(p.get_node("Visual/Sprite") is CharacterSprite, "Visual/Sprite é CharacterSprite")
	check(p.get_node("Visual/Sprite").visible, "sprite visível")
	check(not p.get_node("Visual/BodeHD").visible, "modelo 3D escondido")
	check(p.get_node("Visual/Sombra") is MeshInstance3D, "tem sombra de contato")


func test_collision_unchanged() -> void:
	var a: Node = PLAYER_SCENE.instantiate()
	var b: Node = SPRITE_PLAYER_SCENE.instantiate()
	_nodes.append_array([a, b])
	var sa: CapsuleShape3D = a.get_node("CollisionShape3D").shape
	var sb: CapsuleShape3D = b.get_node("CollisionShape3D").shape
	check_eq(sb.radius, sa.radius, "mesmo raio")
	check_eq(sb.height, sa.height, "mesma altura")
	check_eq(b.get_node("CollisionShape3D").transform, a.get_node("CollisionShape3D").transform, "mesma posição")
	check_eq(b.collision_layer, a.collision_layer, "mesma camada")


func test_flip_does_not_move_feet() -> void:
	var p: Player = SPRITE_PLAYER_SCENE.instantiate()
	_nodes.append(p)
	tree.root.add_child(p)
	p.set_physics_process(false)
	await tree.process_frame
	p.step(DT, -1.0, false)
	check_eq(p.facing, -1, "virou para a esquerda")
	var sprite: Node3D = p.get_node("Visual/Sprite")
	var shadow: Node3D = p.get_node("Visual/Sombra")
	check(absf(sprite.global_position.x - p.global_position.x) < 0.001, "sprite no x do bode")
	check(absf(shadow.global_position.x - p.global_position.x) < 0.001, "sombra no x do bode")
	check(sprite.global_transform.basis.x.x < 0.0, "sprite espelhado")


func test_ice_climb_still_works() -> void:
	# o mesmo roteiro de test_sala2_playthrough.gd, com o bode em sprite
	var w := World.new()
	w.save_path = PATH
	var p: Player = SPRITE_PLAYER_SCENE.instantiate()
	p.name = "Player"
	w.add_child(p)
	tree.root.add_child(w)
	_nodes.append(w)
	p.set_physics_process(false)
	p.grant_ability(Player.ABILITY_ICE_HAMMER)
	w.load_room("sala2")
	p.global_position = Vector3(2, 0, 0)
	await physics_frames(2)
	for i in 40 + 60 * 12:
		await tree.physics_frame
		if i == 20:
			p.try_attack()
		p.step(DT, 1.0, p.clinging or (p.is_on_floor() and p.is_on_wall()))
	var top: Vector3 = w.current_room.statue_position("sala2_topo")
	check(p.global_position.y > top.y - 0.2, "chegou ao topo (y=%f)" % p.global_position.y)


func test_prototype_scene() -> void:
	var main: Node = PROTO_SCENE.instantiate()
	main.find_child("World", true, false).save_path = PATH
	tree.root.add_child(main)
	_nodes.append(main)
	await tree.process_frame
	await tree.process_frame
	var cam: SideCamera = main.find_child("SideCamera", true, false)
	var world: World = main.find_child("World", true, false)
	check_eq(cam.projection, Camera3D.PROJECTION_PERSPECTIVE, "perspectiva")
	check(cam.pitch_degrees > 0.0, "inclinada")
	check_eq(world.current_room.room_id, "sala2", "começa na sala 2")
	check(world.player.get_node_or_null("Visual/Sprite") is CharacterSprite, "bode em sprite")
	var sheep: Node = world.current_room.get_node("Sheep")
	check(sheep.get_node_or_null("Visual/Sprite") is CharacterSprite, "ovelha em sprite")
	check(not sheep.get_node("Visual/OvelhaHD").visible, "modelo da ovelha escondido")


func test_prototype_can_be_orthographic() -> void:
	var main: Node = PROTO_SCENE.instantiate()
	main.orthographic = true
	main.find_child("World", true, false).save_path = PATH
	tree.root.add_child(main)
	_nodes.append(main)
	await tree.process_frame
	var cam: SideCamera = main.find_child("SideCamera", true, false)
	check_eq(cam.projection, Camera3D.PROJECTION_ORTHOGONAL, "ortográfica quando pedida")
	check(cam.pitch_degrees > 0.0, "continua inclinada")
