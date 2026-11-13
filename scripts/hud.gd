extends Label
## Mostra a vida do bode. Provisório até haver arte de HUD.


func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player:
		text = "Vida: %d / %d" % [player.health.hp, player.health.max_hp]
