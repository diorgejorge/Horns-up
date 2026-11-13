class_name Door
extends Area3D
## Passagem para outra sala. Ao toque do bode, avisa para onde levar.
## O bode chega por uma porta no ponto `arrival_position()`, fora do gatilho,
## para não voltar na hora pela mesma porta.

signal used(target_room: String, target_door: String)

@export var door_id: String = ""
@export var target_room: String = ""
@export var target_door: String = ""
## Onde o bode aparece ao chegar por esta porta, relativo a ela.
@export var arrival_offset := Vector3(-1.6, 0, 0)


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func arrival_position() -> Vector3:
	return global_position + arrival_offset


func _on_body_entered(body: Node) -> void:
	if body is Player:
		used.emit(target_room, target_door)
