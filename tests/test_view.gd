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
