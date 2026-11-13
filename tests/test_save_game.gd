extends TestCase

const PATH := "user://test_save.json"


func after_each() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)


func _write_raw(text: String) -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func test_roundtrip() -> void:
	check(SaveGame.write({"statue_id": "a"}, PATH), "write devolve true")
	check_eq(SaveGame.read(PATH), {"statue_id": "a"}, "lê o que gravou")


func test_missing_file_returns_empty() -> void:
	after_each()
	check_eq(SaveGame.read(PATH), {}, "arquivo ausente vira {}")


func test_empty_file_returns_empty() -> void:
	_write_raw("")
	check_eq(SaveGame.read(PATH), {}, "arquivo vazio vira {}")


func test_corrupt_file_returns_empty() -> void:
	_write_raw("{nao json")
	check_eq(SaveGame.read(PATH), {}, "arquivo corrompido vira {}")


func test_non_dict_json_returns_empty() -> void:
	_write_raw("[1,2]")
	check_eq(SaveGame.read(PATH), {}, "JSON que não é objeto vira {}")
