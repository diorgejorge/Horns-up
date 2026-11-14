class_name AbilityNotice
extends Label
## Aviso na tela quando o bode ganha uma habilidade. Provisório até haver
## arte de HUD.

const SHOW_SECONDS := 3.0
const TEXTS := {
	"martelo_gelo": "Martelo desperto: quebra pedra e gruda no gelo",
}

var time_left := 0.0
var _player: Player


func _ready() -> void:
	visible = false


func _process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Player
		if _player:
			_player.ability_gained.connect(show_for)
	tick(delta)


func show_for(id: String) -> void:
	text = TEXTS.get(id, id)
	time_left = SHOW_SECONDS
	visible = true


func tick(delta: float) -> void:
	if time_left <= 0.0:
		return
	time_left = max(time_left - delta, 0.0)
	if time_left == 0.0:
		visible = false
