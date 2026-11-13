class_name SaveData
extends RefCounted
## Conteúdo do save: sala, última estátua e habilidades. Tolerante a save
## antigo (só `statue_id`, da primeira sala) e a campos com tipo errado.

const DEFAULT_ROOM := "sala1"

var room_id: String = DEFAULT_ROOM
var statue_id: String = ""
var abilities: PackedStringArray = []


static func from_dict(d: Dictionary) -> SaveData:
	var out := SaveData.new()
	var room = d.get("room_id")
	if room is String and room != "":
		out.room_id = room
	var statue = d.get("statue_id")
	if statue is String:
		out.statue_id = statue
	var list = d.get("abilities")
	if list is Array:
		for item in list:
			if item is String:
				out.add_ability(item)
	return out


func to_dict() -> Dictionary:
	return {"room_id": room_id, "statue_id": statue_id, "abilities": Array(abilities)}


## False se já tinha.
func add_ability(id: String) -> bool:
	if abilities.has(id):
		return false
	abilities.append(id)
	return true
