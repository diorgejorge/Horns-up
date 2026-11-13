class_name SideCamera
extends Camera3D
## Câmera fixa de lado, como em Hollow Knight: segue x e y do bode
## e nunca muda a profundidade.

@export var follow_offset := Vector3(0, 1, 12)


func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player:
		global_position = target_position(player.global_position, follow_offset)


static func target_position(player_pos: Vector3, offset: Vector3) -> Vector3:
	return Vector3(player_pos.x + offset.x, player_pos.y + offset.y, offset.z)
