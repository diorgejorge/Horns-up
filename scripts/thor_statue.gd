class_name ThorStatue
extends Area3D
## Estátua de Thor: ao toque, cura a vida toda e salva o jogo.

@export var statue_id: String = ""
@export var save_path: String = SaveGame.DEFAULT_PATH


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func activate(player: Player) -> void:
	player.health.heal_full()
	SaveGame.write({"statue_id": statue_id}, save_path)


func _on_body_entered(body: Node) -> void:
	if body is Player:
		activate(body)
