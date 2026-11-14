extends SceneTree
## Capturas do protótipo 2.5D lado a lado com o jogo atual, na sala 2.
## xvfb-run godot --path . -s tools/capturar_prototipo.gd
## Saída: arte/previas/prototipo_25d_*.png

const DT := 1.0 / 60.0
const SAVE := "user://captura_prototipo.json"
const OUT := "res://arte/previas/"
const MOMENTOS := ["chegada", "martelada", "grudado", "topo"]
const VISTAS := [
	["atual", "res://scenes/main.tscn", false],
	["perspectiva", "res://scenes/prototipo/prototipo_25d.tscn", false],
	["ortografica", "res://scenes/prototipo/prototipo_25d.tscn", true],
]


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var grade := {}
	for v in VISTAS:
		grade[v[0]] = await _capturar(v[1], v[2])
	# grade: linhas = momentos, colunas = vistas, cada quadro em 640x360
	var w := 640
	var h := 360
	var out := Image.create(w * VISTAS.size(), h * MOMENTOS.size(), false, Image.FORMAT_RGBA8)
	for c in VISTAS.size():
		var fotos: Array = grade[VISTAS[c][0]]
		for r in MOMENTOS.size():
			var img: Image = fotos[r].duplicate()
			img.save_png(ProjectSettings.globalize_path(OUT + "prototipo_25d_%s_%d_%s.png" % [VISTAS[c][0], r + 1, MOMENTOS[r]])) if c == 1 else null
			img.resize(w, h, Image.INTERPOLATE_LANCZOS)
			out.blit_rect(img, Rect2i(0, 0, w, h), Vector2i(c * w, r * h))
	out.save_png(ProjectSettings.globalize_path(OUT + "prototipo_25d_comparacao.png"))
	print("capturas em ", OUT)
	quit()


func _capturar(path: String, ortho: bool) -> Array:
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(SAVE)
	var main: Node = load(path).instantiate()
	if ortho:
		main.orthographic = true
	var world: World = main.find_child("World", true, false)
	world.save_path = SAVE
	root.add_child(main)
	await process_frame
	var vp: SubViewport = main.find_child("GameViewport", true, false)
	var p: Player = world.player
	p.set_physics_process(false)
	p.grant_ability(Player.ABILITY_ICE_HAMMER)
	if world.current_room.room_id != "sala2":
		world.load_room("sala2")
	p.global_position = Vector3(2, 0, 0)
	var fotos := []
	for i in 10:
		await physics_frame
		p.step(DT, 0.0, false)
	fotos.append(await _foto(vp))
	var i := 0
	while i < 22:
		await physics_frame
		if i == 20:
			p.try_attack()
		p.step(DT, 1.0, p.clinging or (p.is_on_floor() and p.is_on_wall()))
		i += 1
	fotos.append(await _foto(vp))
	var top: Vector3 = world.current_room.statue_position("sala2_topo")
	var grudou := false
	while i < 60 * 14:
		await physics_frame
		p.step(DT, 1.0, p.clinging or (p.is_on_floor() and p.is_on_wall()))
		i += 1
		if not grudou and p.clinging and p.global_position.y > 3.0:
			grudou = true
			fotos.append(await _foto(vp))
		if grudou and p.global_position.y > top.y - 0.2 and p.is_on_floor():
			break
	for k in 20:
		await physics_frame
		p.step(DT, 0.0, false)
	if not grudou:
		fotos.append(await _foto(vp))
	fotos.append(await _foto(vp))
	main.queue_free()
	await process_frame
	return fotos


func _foto(vp: SubViewport) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return vp.get_texture().get_image()
