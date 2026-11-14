extends TestCase
## Cenário caprichado do protótipo 2.5D na sala 2: só visual, nada de física.

const SALA2 := preload("res://scenes/rooms/sala2.tscn")

var _room: Room


func after_each() -> void:
	if is_instance_valid(_room):
		_room.queue_free()
	await tree.process_frame


func _dressed() -> Room:
	_room = SALA2.instantiate()
	tree.root.add_child(_room)
	CenarioGelo.vestir(_room)
	return _room


func _shader_of(mi: MeshInstance3D) -> String:
	var m := mi.material_override as ShaderMaterial
	return m.shader.resource_path.get_file() if m else ""


func test_decor_has_no_collision() -> void:
	var r := _dressed()
	await tree.process_frame
	var cen := r.get_node("Cenario")
	check(cen.is_in_group("cenario"), "grupo cenario")
	check(cen.find_children("*", "CollisionObject3D", true, false).is_empty(), "nenhuma colisão no cenário")
	check(cen.find_children("*", "Area3D", true, false).is_empty(), "nenhuma área no cenário")


func test_foreground_does_not_hide_player() -> void:
	var r := _dressed()
	await tree.process_frame
	for n in r.get_node("Cenario").find_children("*", "VisualInstance3D", true, false):
		var vi := n as VisualInstance3D
		if vi is GPUParticles3D or vi is CPUParticles3D:
			continue
		var box: AABB = vi.global_transform * vi.get_aabb()
		if box.end.z > 0.6: # tudo que fica na frente do bode é baixo
			if box.end.y > 0.0: # o que fica acima do chão não sai dele (água e blocos ficam abaixo)
				check(box.end.z <= 2.0, "%s não passa da borda do chão (z=%.2f)" % [vi.name, box.end.z])
			check(box.end.y <= 0.6 or box.position.y >= 3.0, "%s baixo ou bem alto (y=%.2f)" % [vi.name, box.end.y])


func test_materials_applied() -> void:
	var r := _dressed()
	await tree.process_frame
	check_eq(_shader_of(r.get_node("Geometry/Floor/Mesh")), "neve.gdshader", "chão de neve")
	check_eq(_shader_of(r.get_node("Geometry/ShaftRock/Mesh")), "rocha.gdshader", "rocha")
	for wall in r.find_children("*", "StaticBody3D", true, false):
		if wall.is_in_group("ice_wall"):
			var mi: MeshInstance3D = wall.find_children("*", "MeshInstance3D", false, false)[0]
			check_eq(_shader_of(mi), "gelo.gdshader", "%s de gelo" % wall.name)


func test_has_water_and_snowfall() -> void:
	var r := _dressed()
	await tree.process_frame
	var agua: MeshInstance3D = r.get_node("Cenario/Lago")
	check_eq(_shader_of(agua), "agua.gdshader", "lago com shader de água")
	check(agua.global_position.y < 0.0, "lago abaixo do chão")
	check(r.get_node("Cenario/Neve") is CPUParticles3D, "neve caindo")


func test_dress_twice_is_harmless() -> void:
	var r := _dressed()
	CenarioGelo.vestir(r)
	await tree.process_frame
	check_eq(r.find_children("Cenario*", "", false, false).size(), 1, "um cenário só")
