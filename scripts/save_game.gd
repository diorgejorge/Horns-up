class_name SaveGame
extends RefCounted
## Save em JSON. Formato: {"statue_id": String}.
## Leitura tolerante: arquivo ausente, vazio, corrompido ou que não seja
## objeto JSON devolve {}.

const DEFAULT_PATH := "user://save.json"


static func write(data: Dictionary, path: String = DEFAULT_PATH) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("SaveGame: não abriu %s para gravar" % path)
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	return true


static func read(path: String = DEFAULT_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	if text.strip_edges().is_empty():
		return {}
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	return data
