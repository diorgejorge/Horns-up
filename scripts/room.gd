class_name Room
extends Node3D
## Primeira sala. Põe o bode no ponto de renascer ao iniciar e ao morrer.

## Proteção ao renascer, para não apanhar de inimigo perto da estátua.
const RESPAWN_INVULN_SECONDS := 1.5

@export var save_path: String = SaveGame.DEFAULT_PATH

@onready var player: Player = $Player
@onready var spawn_point: Node3D = $SpawnPoint


func _ready() -> void:
	for statue in _statues():
		statue.save_path = save_path
	player.died.connect(_on_player_died)
	_place_player()


## Posição da estátua gravada no save; o SpawnPoint se o save estiver
## ausente, ruim ou apontar para uma estátua que não existe.
func respawn_position() -> Vector3:
	var id = SaveGame.read(save_path).get("statue_id")
	if id is String:
		for statue in _statues():
			if statue.statue_id == id:
				return statue.global_position
	return spawn_point.global_position


func _on_player_died() -> void:
	_place_player()
	player.health.heal_full()
	player.health.grant_invulnerability(RESPAWN_INVULN_SECONDS)


func _place_player() -> void:
	player.global_position = respawn_position()
	player.velocity = Vector3.ZERO


func _statues() -> Array[ThorStatue]:
	var out: Array[ThorStatue] = []
	for n in find_children("*", "Area3D"):
		if n is ThorStatue:
			out.append(n)
	return out
