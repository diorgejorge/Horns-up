class_name Room
extends Node3D
## Uma sala: geometria, estátuas, portas e o ponto inicial. Não guarda o
## bode nem o save; isso é do World.

@export var room_id: String = ""

@onready var spawn_point: Node3D = $SpawnPoint


func spawn_position() -> Vector3:
	return spawn_point.global_position


## Posição da estátua com este id, ou null.
func statue_position(id: String) -> Variant:
	for statue in statues():
		if statue.statue_id == id:
			return statue.global_position
	return null


## Onde o bode chega pela porta com este id, ou null.
func arrival_position(p_door_id: String) -> Variant:
	for door in doors():
		if door.door_id == p_door_id:
			return door.arrival_position()
	return null


func statues() -> Array[ThorStatue]:
	var out: Array[ThorStatue] = []
	for n in find_children("*", "Area3D", true, false):
		if n is ThorStatue:
			out.append(n)
	return out


func doors() -> Array[Door]:
	var out: Array[Door] = []
	for n in find_children("*", "Area3D", true, false):
		if n is Door:
			out.append(n)
	return out


func pickups() -> Array[AbilityPickup]:
	var out: Array[AbilityPickup] = []
	for n in find_children("*", "Area3D", true, false):
		if n is AbilityPickup:
			out.append(n)
	return out
