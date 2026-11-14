extends TestCase

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const ICE_SCENE := preload("res://scenes/ice_wall.tscn")
const DT := 1.0 / 60.0

var _nodes: Array[Node] = []


func after_each() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	await tree.process_frame


func test_should_cling_cases() -> void:
	check(not Player.should_cling(true, true, true, 1, -1), "no chão não")
	check(not Player.should_cling(false, false, true, 1, -1), "pedra não")
	check(not Player.should_cling(false, true, false, 1, -1), "sem habilidade não")
	check(not Player.should_cling(false, true, true, -1, -1), "segurando para longe não")
	check(not Player.should_cling(false, true, true, 0, -1), "sem segurar não")
	check(Player.should_cling(false, true, true, 1, -1), "parede à direita, segurando direita")
	check(Player.should_cling(false, true, true, -1, 1), "parede à esquerda, segurando esquerda")


func test_cling_stops_fall() -> void:
	check_eq(Player.cling_velocity(Vector3(2, -5, 0)), Vector3.ZERO, "para no gelo")


func test_wall_jump_pushes_away() -> void:
	check_eq(Player.wall_jump_velocity(-1), Vector3(-6, 9, 0), "empurra para longe e sobe")


## Parede real (StaticBody3D com shape) à direita do bode, que está no ar.
func _setup(x: float, with_ability: bool, ice: bool) -> Player:
	var wall: StaticBody3D
	if ice:
		wall = ICE_SCENE.instantiate()
		wall.size = Vector3(1, 20, 4)
	else:
		wall = StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1, 20, 4)
		cs.shape = box
		wall.add_child(cs)
	tree.root.add_child(wall)
	wall.global_position = Vector3(x + 1.0, 10, 0)
	var p: Player = PLAYER_SCENE.instantiate()
	tree.root.add_child(p)
	p.set_physics_process(false)
	p.global_position = Vector3(x, 10, 0)
	if with_ability:
		p.grant_ability(Player.ABILITY_ICE_HAMMER)
	_nodes.append_array([wall, p])
	return p


func _steps(p: Player, n: int, input_x: float, jump := false) -> void:
	for i in n:
		await tree.physics_frame
		p.step(DT, input_x, jump and i == 0)


func test_clings_on_real_ice_wall() -> void:
	var p := _setup(1000, true, true)
	await physics_frames(2)
	await _steps(p, 10, 1.0)
	check(p.clinging, "grudou")
	var y := p.global_position.y
	await _steps(p, 20, 1.0)
	check(p.clinging, "segue grudado")
	check(absf(p.global_position.y - y) < 0.05, "não caiu (caiu %f)" % (y - p.global_position.y))


func test_release_falls() -> void:
	var p := _setup(1100, true, true)
	await physics_frames(2)
	await _steps(p, 10, 1.0)
	var y := p.global_position.y
	await _steps(p, 10, 0.0)
	check(not p.clinging, "soltou")
	check(p.global_position.y < y - 0.1, "caiu")


func test_wall_jump_goes_up_and_away() -> void:
	var p := _setup(1200, true, true)
	await physics_frames(2)
	await _steps(p, 10, 1.0)
	var start := p.global_position
	await _steps(p, 6, 1.0, true) # segurando contra a parede: a trava afasta mesmo assim
	check(not p.clinging, "saiu da parede")
	check(p.global_position.y > start.y + 0.3, "subiu")
	check(p.global_position.x < start.x - 0.3, "afastou")


func test_no_cling_without_ability() -> void:
	var p := _setup(1300, false, true)
	await physics_frames(2)
	var y := p.global_position.y
	await _steps(p, 20, 1.0)
	check(not p.clinging, "sem habilidade não gruda")
	check(p.global_position.y < y - 0.5, "cai")


func test_no_cling_on_stone() -> void:
	var p := _setup(1400, true, false)
	await physics_frames(2)
	var y := p.global_position.y
	await _steps(p, 20, 1.0)
	check(not p.clinging, "pedra não gruda")
	check(p.global_position.y < y - 0.5, "cai")
