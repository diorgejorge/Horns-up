extends TestCase

const MAIN_SCENE := preload("res://scenes/main.tscn")


func test_camera_follows_x_and_y_keeps_z() -> void:
	check_eq(SideCamera.target_position(Vector3(3, 2, 0), Vector3(0, 1, 12)), Vector3(3, 3, 12), "segue x e y, mantém z")


func test_main_scene_is_low_res_and_sharp() -> void:
	var main: Node = MAIN_SCENE.instantiate()
	tree.root.add_child(main) # o tamanho do SubViewport só vale dentro da árvore
	await tree.process_frame
	await tree.process_frame
	var container: SubViewportContainer = main.find_children("*", "SubViewportContainer")[0]
	var vp: SubViewport = main.find_children("*", "SubViewport")[0]
	var cam: Camera3D = main.find_child("SideCamera", true, false)
	check_eq(vp.size, Vector2i(320, 180), "SubViewport 320x180")
	check(cam is SideCamera, "câmera é SideCamera")
	check_eq(cam.projection, Camera3D.PROJECTION_ORTHOGONAL, "câmera ortográfica")
	check_eq(container.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST, "sem suavização")
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
