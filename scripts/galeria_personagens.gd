extends Control
## Galeria dos modelos dos personagens.
## Começa no render do jogo (320x180 sem suavizar, câmera ortográfica de lado)
## com os modelos low-poly. H troca para a vista HD: modelos _hd em
## resolução cheia, com antisserrilhado.
## Espaço: liga e desliga o giro. Setas: giram na mão. R: volta à vista do jogo.

const VELOCIDADE_GIRO := 0.8
const ENCOLHER_PIXEL := 4

var girando := false
var hd := false

@onready var container: SubViewportContainer = $ViewportContainer
@onready var viewport: SubViewport = $ViewportContainer/GameViewport
@onready var modelos: Node3D = $ViewportContainer/GameViewport/Modelos
@onready var modelos_hd: Node3D = $ViewportContainer/GameViewport/ModelosHD


func _process(delta: float) -> void:
	var giro := 0.0
	if girando:
		giro = VELOCIDADE_GIRO * delta
	if Input.is_key_pressed(KEY_LEFT):
		giro -= 2.0 * delta
	if Input.is_key_pressed(KEY_RIGHT):
		giro += 2.0 * delta
	for grupo in [modelos, modelos_hd]:
		for modelo in grupo.get_children():
			(modelo as Node3D).rotate_y(giro)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				girando = not girando
			KEY_H:
				usar_hd(not hd)
			KEY_R:
				for grupo in [modelos, modelos_hd]:
					for modelo in grupo.get_children():
						(modelo as Node3D).rotation = Vector3.ZERO
				girando = false


func usar_hd(ligar: bool) -> void:
	hd = ligar
	modelos.visible = not hd
	modelos_hd.visible = hd
	container.stretch_shrink = 1 if hd else ENCOLHER_PIXEL
	container.texture_filter = (CanvasItem.TEXTURE_FILTER_LINEAR if hd
		else CanvasItem.TEXTURE_FILTER_NEAREST)
	viewport.msaa_3d = Viewport.MSAA_4X if hd else Viewport.MSAA_DISABLED
