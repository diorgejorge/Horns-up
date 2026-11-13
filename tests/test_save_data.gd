extends TestCase


func test_empty_dict_gives_defaults() -> void:
	var d := SaveData.from_dict({})
	check_eq(d.room_id, "sala1", "sala padrão")
	check_eq(d.statue_id, "", "sem estátua")
	check_eq(d.abilities.size(), 0, "sem habilidades")


func test_old_save_maps_to_sala1() -> void:
	var d := SaveData.from_dict({"statue_id": "sala1"})
	check_eq(d.room_id, "sala1", "save antigo cai na sala 1")
	check_eq(d.statue_id, "sala1", "mantém a estátua")


func test_roundtrip() -> void:
	var a := SaveData.new()
	a.room_id = "sala2"
	a.statue_id = "sala2_topo"
	a.add_ability("martelo_gelo")
	var b := SaveData.from_dict(a.to_dict())
	check_eq(b.room_id, "sala2", "sala")
	check_eq(b.statue_id, "sala2_topo", "estátua")
	check_eq(b.abilities, PackedStringArray(["martelo_gelo"]), "habilidades")


func test_roundtrip_through_json() -> void:
	var a := SaveData.new()
	a.add_ability("martelo_gelo")
	var parsed = JSON.parse_string(JSON.stringify(a.to_dict()))
	check_eq(SaveData.from_dict(parsed).abilities, PackedStringArray(["martelo_gelo"]), "sobrevive ao JSON")


func test_bad_types_are_ignored() -> void:
	var d := SaveData.from_dict({"room_id": 3, "statue_id": [], "abilities": "x"})
	check_eq(d.room_id, "sala1", "room_id ruim vira padrão")
	check_eq(d.statue_id, "", "statue_id ruim vira vazio")
	check_eq(d.abilities.size(), 0, "abilities ruim vira vazio")
	var e := SaveData.from_dict({"abilities": ["a", 2, null, "a"]})
	check_eq(e.abilities, PackedStringArray(["a"]), "só texto, sem repetir")


func test_add_ability_no_duplicate() -> void:
	var d := SaveData.new()
	check(d.add_ability("x"), "primeira vez")
	check(not d.add_ability("x"), "segunda vez não")
	check_eq(d.abilities.size(), 1, "uma só")
