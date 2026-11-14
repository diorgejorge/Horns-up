class_name ThorStatue
extends Area3D
## Estátua de Thor: ao toque, cura a vida toda e avisa que foi ativada.
## Quem grava o save é o World.

signal activated(statue_id: String)

@export var statue_id: String = ""


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func activate(player: Player) -> void:
	player.health.heal_full()
	activated.emit(statue_id)


func _on_body_entered(body: Node) -> void:
	if body is Player:
		activate(body)
