@tool
class_name Npc3D
extends Peca3D
## Personagem de cena (não luta): ocupa a casa como um objeto e toca uma
## animação do próprio modelo em loop (ex.: a Moradora, cuca.glb: idle, talk, walk).

@export var animacao := "idle"


func _ready() -> void:
	super._ready()
	if not Engine.is_editor_hint():
		tocar(animacao)


func tocar(nome: String) -> void:
	var ap := find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap and ap.has_animation(nome):
		ap.get_animation(nome).loop_mode = Animation.LOOP_LINEAR
		ap.play(nome)
