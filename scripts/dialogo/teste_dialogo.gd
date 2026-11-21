extends Node3D
## Vitrine do diálogo: toca cenas sobre um fundo 3D simples.
##   godot --path . res://scenes/ui/dialogo/teste_dialogo.tscn -- --cena=b03_antes
##   ... -- --fotos=pasta   (tira uma foto por fala e sai)

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var cenas := ["b01_antes", "b03_antes", "b12_antes", "b12_durante", "b12_depois"]
	var fotos := ""
	for a in args:
		if a.begins_with("--cena="):
			cenas = [a.trim_prefix("--cena=")]
		elif a.begins_with("--fotos="):
			fotos = a.trim_prefix("--fotos=")
	if fotos != "":
		Dialogo.comecou.connect(func(id): _fotografar(id, fotos))
	for id in cenas:
		await Dialogo.tocar(id)
	print("TESTE_DIALOGO_OK pausado=", get_tree().paused)
	get_tree().quit()


func _fotografar(id: String, pasta: String) -> void:
	DirAccess.make_dir_recursive_absolute(pasta)
	var n := Dialogo.falas(id).size()
	for i in n:
		await get_tree().create_timer(2.5, true, false, true).timeout
		get_viewport().get_texture().get_image().save_png("%s/%s_%d.png" % [pasta, id, i])
		Input.parse_input_event(_enter())
		await get_tree().process_frame
		Input.parse_input_event(_enter())
		await get_tree().create_timer(0.1, true, false, true).timeout


func _enter() -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = KEY_ENTER
	e.pressed = true
	return e
