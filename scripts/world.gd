class_name World
extends Node3D
## Guarda o bode e a sala atual. Troca de sala pelas portas, ao morrer e ao
## carregar o save. Grava o save quando uma estátua é tocada e quando o bode
## pega uma habilidade (na hora, como em Hollow Knight).

signal room_changed(id: String)

const ROOMS := {
	"sala1": "res://scenes/rooms/sala1.tscn",
	"sala2": "res://scenes/rooms/sala2.tscn",
}
## Proteção ao renascer, para não apanhar de inimigo perto da estátua.
const RESPAWN_INVULN_SECONDS := 1.5

@export var save_path: String = SaveGame.DEFAULT_PATH

var current_room: Room
var data: SaveData

@onready var player: Player = $Player


func _ready() -> void:
	data = SaveData.from_dict(SaveGame.read(save_path))
	# direto na lista: carregar o save não é "ganhar" a habilidade de novo
	player.abilities = data.abilities.duplicate()
	player.died.connect(_on_player_died)
	load_room(data.room_id)


## Sala desconhecida vira a sala 1. Posição: a porta de chegada; senão a
## estátua salva, se for desta sala; senão o SpawnPoint.
func load_room(id: String, arrival_door: String = "") -> void:
	if not ROOMS.has(id):
		id = SaveData.DEFAULT_ROOM
		arrival_door = ""
	if current_room:
		remove_child(current_room)
		current_room.queue_free()
	current_room = load(ROOMS[id]).instantiate()
	add_child(current_room)
	_wire_room()
	_place_player(_entry_position(id, arrival_door))
	room_changed.emit(id)


func respawn() -> void:
	load_room(data.room_id)
	player.health.heal_full()
	player.health.grant_invulnerability(RESPAWN_INVULN_SECONDS)


func save() -> void:
	SaveGame.write(data.to_dict(), save_path)


func _entry_position(id: String, arrival_door: String) -> Vector3:
	if arrival_door != "":
		var arrival = current_room.arrival_position(arrival_door)
		if arrival != null:
			return arrival
	if id == data.room_id:
		var statue = current_room.statue_position(data.statue_id)
		if statue != null:
			return statue
	return current_room.spawn_position()


func _wire_room() -> void:
	for door in current_room.doors():
		door.used.connect(_on_door_used)
	for statue in current_room.statues():
		statue.activated.connect(_on_statue_activated)
	for pickup in current_room.pickups():
		pickup.refresh(player)
		pickup.collected.connect(_on_pickup_collected)


func _place_player(pos: Vector3) -> void:
	player.global_position = pos
	player.velocity = Vector3.ZERO
	player.clinging = false
	player.input_lock_left = 0.0


func _on_door_used(target_room: String, target_door: String) -> void:
	# nunca trocar de sala dentro da consulta de física
	call_deferred("load_room", target_room, target_door)


func _on_statue_activated(statue_id: String) -> void:
	data.statue_id = statue_id
	data.room_id = current_room.room_id
	save()


func _on_pickup_collected(id: String) -> void:
	data.add_ability(id)
	save()


func _on_player_died() -> void:
	call_deferred("respawn")
