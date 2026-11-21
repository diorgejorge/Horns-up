extends SceneTree
## Teste visual da HUD marajoara (arte 2D do Diorge): fotos da batalha 04 (diálogo,
## iniciativa, HUD, resultado) e da loja da vila, mais a saída de erros do console.
##   Godot --path . -s res://tools/teste_hud.gd -- <pasta onde salvar as fotos>

var saida := "."


func _foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(saida.path_join(nome + ".png"))
	print("foto: ", nome)


func _enter() -> void:
	for p in [true, false]:
		var e := InputEventKey.new()
		e.keycode = KEY_ENTER
		e.pressed = p
		Input.parse_input_event(e)
		await process_frame


func _init() -> void:
	await process_frame
	if OS.get_cmdline_user_args().size() > 0:
		saida = OS.get_cmdline_user_args()[0]
	var c = root.get_node("Campanha")
	c.novo_jogo()
	c.vencidas = [1, 2, 3]
	c.ouro = 120
	change_scene_to_file("res://scenes/3d/ato1/batalha_04.tscn")
	await create_timer(2.5).timeout
	await _foto("1_abertura")
	# diálogo de abertura e tela de iniciativa: Enter até a batalha começar
	for i in 12:
		await _enter()
		await create_timer(0.8).timeout
		if i == 3:
			await _foto("2_dialogo_ou_iniciativa")
	await create_timer(2.0).timeout
	await _foto("3_batalha")
	var huds := root.find_children("*", "HudBatalha", true, false)
	if not huds.is_empty():
		huds[0].mostrar_resultado(true, {"xp": 40, "ouro": 35, "itens": {"pocao": 1, "pocao_mana": 1}}, {"bufalo": {}})
		await create_timer(1.0).timeout
		await _foto("4_resultado")
	else:
		print("ERRO: HudBatalha não encontrada")
	change_scene_to_file("res://scenes/3d/ato1/mapa_arua.tscn")
	await create_timer(2.0).timeout
	current_scene.abrir_loja()
	await create_timer(1.0).timeout
	await _foto("5_loja")
	quit()
