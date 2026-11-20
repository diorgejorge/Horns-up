extends Node3D
## Mapa-múndi 3D EDITÁVEL NO EDITOR: Terreno/ e Cenario/ (Peca3D), Locais/
## (placas com nome, cada uma aponta para uma cena de batalha) e o Grupo (Unidade3D).
## Setas movem o grupo; Enter perto de um local abre a batalha dele.

@export var grupo: NodePath

var _hud: Label


func _ready() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = Label.new()
	_hud.position = Vector2(20, 16)
	_hud.add_theme_font_size_override("font_size", 20)
	_hud.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud.add_theme_constant_override("outline_size", 6)
	layer.add_child(_hud)
	_atualizar_hud()


func _grupo() -> Unidade3D:
	return get_node_or_null(grupo) as Unidade3D


## Local (Marker3D em Locais/) a até 2 casas do grupo, ou null.
func _local_perto() -> Node3D:
	var g := _grupo()
	if g == null:
		return null
	for l in get_node("Locais").get_children():
		if l is Node3D and Vector2(l.position.x - g.position.x, l.position.z - g.position.z).length() <= 2.5:
			return l
	return null


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	var g := _grupo()
	# Câmera na diagonal: cada seta anda 1 casa ao longo da grade (cima = noroeste na tela).
	var dirs := {KEY_UP: Vector3(0, 0, -1), KEY_DOWN: Vector3(0, 0, 1), KEY_LEFT: Vector3(-1, 0, 0), KEY_RIGHT: Vector3(1, 0, 0)}
	if g and dirs.has(event.keycode):
		var passo: Vector3 = dirs[event.keycode]
		g.position += passo
		g.position.y = g.altura_do_piso()
		g.look_at(g.position - passo, Vector3.UP)
		g.tocar("walk")
		g.create_tween().tween_callback(g.tocar.bind("idle")).set_delay(0.35)  # morre junto com o grupo
		_atualizar_hud()
	elif event.keycode in [KEY_ENTER, KEY_KP_ENTER] and not event.echo:
		var l := _local_perto()
		if l and l.has_meta("batalha"):
			get_tree().change_scene_to_file(l.get_meta("batalha"))


func _atualizar_hud() -> void:
	var l := _local_perto()
	var dica := "Setas movem o grupo."
	if l:
		dica = "%s — Enter para lutar aqui." % l.name.replace("_", " ")
	_hud.text = "MAPA-MÚNDI 3D   F1 batalha · F2 mapa-múndi\n" + dica
