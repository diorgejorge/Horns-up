extends Control
## Galeria dos modelos dos personagens, com câmera ortográfica de lado.
## H troca o estilo: voxel (o do jogo), HD liso, ou pixel low-poly 320x180.
## Espaço: liga e desliga o giro. Setas: giram na mão. R: volta à vista de lado.

enum Estilo { VOXEL, HD, PIXEL }

const VELOCIDADE_GIRO := 0.8
const ENCOLHER_PIXEL := 4

var girando := false
var estilo := Estilo.VOXEL

@onready var container: SubViewportContainer = $ViewportContainer
@onready var viewport: SubViewport = $ViewportContainer/GameViewport
@onready var grupos := {
	Estilo.VOXEL: $ViewportContainer/GameViewport/ModelosVoxel,
	Estilo.HD: $ViewportContainer/GameViewport/ModelosHD,
	Estilo.PIXEL: $ViewportContainer/GameViewport/Modelos,
}


func _ready() -> void:
	usar_estilo(estilo)


func _process(delta: float) -> void:
	var giro := 0.0
	if girando:
		giro = VELOCIDADE_GIRO * delta
	if Input.is_key_pressed(KEY_LEFT):
		giro -= 2.0 * delta
	if Input.is_key_pressed(KEY_RIGHT):
		giro += 2.0 * delta
	for grupo in grupos.values():
		for modelo in grupo.get_children():
			(modelo as Node3D).rotate_y(giro)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				girando = not girando
			KEY_H:
				usar_estilo((estilo + 1) % Estilo.size())
			KEY_R:
				for grupo in grupos.values():
					for modelo in grupo.get_children():
						(modelo as Node3D).rotation = Vector3.ZERO
				girando = false


func usar_estilo(novo: int) -> void:
	estilo = novo
	for chave in grupos:
		grupos[chave].visible = chave == estilo
	var pixel := estilo == Estilo.PIXEL
	container.stretch_shrink = ENCOLHER_PIXEL if pixel else 1
	container.texture_filter = (CanvasItem.TEXTURE_FILTER_NEAREST if pixel
		else CanvasItem.TEXTURE_FILTER_LINEAR)
	viewport.msaa_3d = Viewport.MSAA_DISABLED if pixel else Viewport.MSAA_4X
