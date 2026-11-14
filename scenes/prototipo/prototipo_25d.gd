extends Control
## Protótipo 2.5D (só para avaliar o visual; o jogo de verdade é main.tscn).
## Começa na sala 2, câmera inclinada, bode e ovelha em sprite.
## Rodar no editor com F6 nesta cena.

## Liga para comparar com a câmera ortográfica inclinada.
@export var orthographic := false

const SHEEP_FRAMES := preload("res://assets/sprites/ovelha/ovelha.tres")
const SHADOW := preload("res://scenes/prototipo/sombra_contato.tres")
const ORTHO_SIZE := 9.0
const FOV := 30.0

@onready var camera: SideCamera = find_child("SideCamera", true, false)
@onready var world: World = find_child("World", true, false)


func _ready() -> void:
	if orthographic:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = ORTHO_SIZE
	else:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = FOV
	world.room_changed.connect(func(_id): _dress_room())
	world.load_room("sala2")


## As salas instanciam sheep.tscn (modelo 3D); aqui a ovelha vira sprite
## sem mexer na cena dela.
func _dress_room() -> void:
	for n in world.current_room.find_children("*", "CharacterBody3D", true, false):
		if n is Sheep:
			use_sprite(n.get_node("Visual"), SHEEP_FRAMES)


static func use_sprite(visual: Node3D, frames: SpriteFrames) -> void:
	if visual.has_node("Sprite"):
		return
	for c in visual.get_children():
		if c is Node3D:
			c.visible = false
	var s := CharacterSprite.new()
	s.name = "Sprite"
	s.sprite_frames = frames
	s.animation = &"parado"
	visual.add_child(s)
	var shadow := MeshInstance3D.new()
	shadow.name = "Sombra"
	shadow.mesh = SHADOW
	shadow.position.y = 0.01
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.add_child(shadow)
