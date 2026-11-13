class_name AbilityPickup
extends Area3D
## Objeto que dá uma habilidade ao bode no toque. Some depois de pego.

signal collected(id: String)

@export var ability_id: String = Player.ABILITY_ICE_HAMMER

var taken := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


## Esconde o objeto se o bode já tem a habilidade (ex.: voltou à sala).
func refresh(player: Player) -> void:
	if player.has_ability(ability_id):
		_hide()


func _on_body_entered(body: Node) -> void:
	if taken or not body is Player:
		return
	body.grant_ability(ability_id)
	_hide()
	collected.emit(ability_id)


func _hide() -> void:
	taken = true
	visible = false
	set_deferred("monitoring", false)
