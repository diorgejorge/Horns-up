extends Node
## Autoload de navegação entre os protótipos (não é jogabilidade).
## F1 = batalha 3D, F2 = mapa-múndi 3D.
## Para capturas de tela automáticas: godot --path . <cena> -- --shot=C:/caminho/arquivo.png

const SCENES := {
	KEY_F1: "res://scenes/3d/batalha_3d.tscn",
	KEY_F2: "res://scenes/3d/mapa_mundi_3d.tscn",
}

var _shot_path := ""
var _shot_frames := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot_path = arg.substr(7)
	if _shot_path != "":
		_take_shot_later()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if SCENES.has(event.keycode):
			get_tree().change_scene_to_file(SCENES[event.keycode])
		elif event.keycode == KEY_ESCAPE:
			get_tree().quit()


func _take_shot_later() -> void:
	# Espera a cena montar, as sombras assentarem e os efeitos aparecerem.
	await get_tree().create_timer(2.2).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_shot_path)
	print("SHOT_SAVED ", _shot_path)
	get_tree().quit()
