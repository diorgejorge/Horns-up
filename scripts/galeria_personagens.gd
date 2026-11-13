extends Control
## Galeria dos modelos dos personagens, no mesmo render do jogo
## (320x180 sem suavizar, câmera ortográfica de lado).
## Espaço: liga e desliga o giro. Setas: giram na mão.

const VELOCIDADE_GIRO := 0.8

var girando := false

@onready var modelos: Node3D = $ViewportContainer/GameViewport/Modelos


func _process(delta: float) -> void:
	var giro := 0.0
	if girando:
		giro = VELOCIDADE_GIRO * delta
	if Input.is_key_pressed(KEY_LEFT):
		giro -= 2.0 * delta
	if Input.is_key_pressed(KEY_RIGHT):
		giro += 2.0 * delta
	for modelo in modelos.get_children():
		(modelo as Node3D).rotate_y(giro)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			girando = not girando
		elif event.keycode == KEY_R:
			for modelo in modelos.get_children():
				(modelo as Node3D).rotation = Vector3.ZERO
			girando = false
