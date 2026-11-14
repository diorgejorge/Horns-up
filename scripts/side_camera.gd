class_name SideCamera
extends Camera3D
## Câmera fixa de lado, como em Hollow Knight: segue x e y do bode
## e nunca muda a profundidade.
## Com `pitch_degrees` > 0 ela fica inclinada para baixo (visual 2.5D),
## a `distance` do ponto que olha, 1 m acima dos pés do bode.

@export var follow_offset := Vector3(0, 1, 12)
## 0 = câmera reta de lado (comportamento original).
@export var pitch_degrees := 0.0
@export var distance := 12.0


func _ready() -> void:
	if pitch_degrees != 0.0:
		follow_offset = tilted_offset(distance, pitch_degrees, follow_offset.y)
		rotation_degrees.x = -pitch_degrees


func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player:
		global_position = target_position(player.global_position, follow_offset)


static func target_position(player_pos: Vector3, offset: Vector3) -> Vector3:
	return Vector3(player_pos.x + offset.x, player_pos.y + offset.y, offset.z)


## Posição relativa ao bode para olhar um ponto `look_height` acima dos pés,
## a `p_distance` dele, inclinada `p_pitch_degrees` para baixo.
static func tilted_offset(p_distance: float, p_pitch_degrees: float, look_height: float) -> Vector3:
	var r := deg_to_rad(p_pitch_degrees)
	return Vector3(0, look_height + p_distance * sin(r), p_distance * cos(r))
