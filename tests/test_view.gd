extends TestCase

const MAIN_SCENE := preload("res://scenes/main.tscn")


func test_camera_follows_x_and_y_keeps_z() -> void:
	check_eq(SideCamera.target_position(Vector3(3, 2, 0), Vector3(0, 1, 12)), Vector3(3, 3, 12), "segue x e y, mantém z")


func test_main_scene_is_hd() -> void:
	var main: Node = MAIN_SCENE.instantiate()
	tree.root.add_child(main) # o tamanho do SubViewport só vale dentro da árvore
	await tree.process_frame
	await tree.process_frame
	var container: SubViewportContainer = main.find_children("*", "SubViewportContainer")[0]
	var vp: SubViewport = main.find_children("*", "SubViewport")[0]
	var cam: Camera3D = main.find_child("SideCamera", true, false)
	check_eq(vp.size, Vector2i(1280, 720), "SubViewport na resolução cheia")
	check_eq(vp.msaa_3d, Viewport.MSAA_4X, "antisserrilhado 4x")
	check(cam is SideCamera, "câmera é SideCamera")
	check_eq(cam.projection, Camera3D.PROJECTION_ORTHOGONAL, "câmera ortográfica")
	check_eq(container.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR, "imagem suavizada")
	main.queue_free()
	await tree.process_frame


func test_ability_notice_shows_and_hides() -> void:
	var main: Node = MAIN_SCENE.instantiate()
	main.find_child("World", true, false).save_path = "user://test_view_notice.json"
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame
	var notice: AbilityNotice = main.find_child("AbilityNotice", true, false)
	var player: Player = main.find_child("Player", true, false)
	check(not notice.visible, "começa escondido")
	player.grant_ability(Player.ABILITY_ICE_HAMMER)
	check(notice.visible, "aparece ao ganhar")
	check(notice.text.begins_with("Martelo desperto"), "texto do martelo")
	notice.tick(AbilityNotice.SHOW_SECONDS + 0.1)
	check(not notice.visible, "some depois de 3 s")
	main.queue_free()
	await tree.process_frame


func test_characters_use_hd_models() -> void:
	var player: Node = load("res://scenes/player.tscn").instantiate()
	var sheep: Node = load("res://scenes/sheep.tscn").instantiate()
	check(player.get_node_or_null("Visual/BodeHD") != null, "bode usa o modelo HD")
	check(sheep.get_node_or_null("Visual/OvelhaHD") != null, "ovelha usa o modelo HD")
	player.free()
	sheep.free()


func test_tilted_offset_zero_pitch() -> void:
	check(SideCamera.tilted_offset(12.0, 0.0, 1.0).is_equal_approx(Vector3(0, 1, 12)), "sem inclinação = câmera atual")


func test_tilted_offset_12() -> void:
	var o := SideCamera.tilted_offset(12.0, 12.0, 1.0)
	var r := deg_to_rad(12.0)
	check(o.is_equal_approx(Vector3(0, 1 + 12 * sin(r), 12 * cos(r))), "inclinada 12°: %s" % o)


func test_tilted_camera_looks_at_player() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	var root := Node3D.new()
	var player := Node3D.new()
	player.add_to_group("player")
	player.position = Vector3(5, 2, 0)
	var cam := SideCamera.new()
	cam.pitch_degrees = 12.0
	cam.distance = 22.0
	cam.fov = 30.0
	root.add_child(player)
	root.add_child(cam)
	vp.add_child(root)
	tree.root.add_child(vp)
	await tree.process_frame
	await tree.process_frame
	check(is_equal_approx(cam.rotation_degrees.x, -12.0), "inclinada para baixo")
	var p := cam.unproject_position(player.global_position + Vector3(0, 1, 0))
	var center := Vector2(640, 360)
	check(p.distance_to(center) < 0.05 * 1280, "bode perto do centro (%s)" % p)
	player.remove_from_group("player")
	vp.queue_free()
	await tree.process_frame
