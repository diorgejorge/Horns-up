class_name StoneBlock
extends StaticBody3D
## Pedra rachada. Só o martelo com a habilidade a quebra; sem ela, a pedra
## treme (pista de que falta algo).

signal smashed

const BONK_SECONDS := 0.1

var broken := false
var _bonk_left := 0.0

@onready var visual: Node3D = $Visual
@onready var shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	add_to_group("breakable")


func _process(delta: float) -> void:
	if _bonk_left <= 0.0:
		return
	_bonk_left = max(_bonk_left - delta, 0.0)
	visual.position.x = 0.06 * sin(_bonk_left * 120.0) if _bonk_left > 0.0 else 0.0


func smash() -> void:
	if broken:
		return
	broken = true
	shape.set_deferred("disabled", true)
	visual.visible = false
	smashed.emit()


func bonk() -> void:
	if broken:
		return
	_bonk_left = BONK_SECONDS
