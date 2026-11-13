extends TestCase

const DT := 1.0 / 60.0


func test_walks_right_and_left() -> void:
	var v := Player.compute_velocity(Vector3.ZERO, 1.0, false, true, DT)
	check_eq(v.x, Player.WALK_SPEED, "direita")
	v = Player.compute_velocity(Vector3.ZERO, -1.0, false, true, DT)
	check_eq(v.x, -Player.WALK_SPEED, "esquerda")


func test_both_directions_cancel() -> void:
	check_eq(Player.read_input_x(true, true), 0.0, "as duas juntas = 0")
	check_eq(Player.read_input_x(true, false), -1.0, "só esquerda")
	check_eq(Player.read_input_x(false, true), 1.0, "só direita")
	check_eq(Player.read_input_x(false, false), 0.0, "nenhuma")
	var v := Player.compute_velocity(Vector3(3, 0, 0), Player.read_input_x(true, true), false, true, DT)
	check_eq(v.x, 0.0, "fica parado")


func test_jump_only_on_floor() -> void:
	var v := Player.compute_velocity(Vector3.ZERO, 0.0, true, true, DT)
	check_eq(v.y, Player.JUMP_SPEED, "pula do chão")
	v = Player.compute_velocity(Vector3(0, -1, 0), 0.0, true, false, DT)
	check(v.y < 0.0, "no ar não ganha impulso")


func test_gravity_applies_in_air() -> void:
	var v := Player.compute_velocity(Vector3(0, 2, 0), 0.0, false, false, 0.1)
	check(is_equal_approx(v.y, 2.0 - Player.GRAVITY * 0.1), "gravidade reduz v.y")


func test_facing_keeps_when_idle() -> void:
	check_eq(Player.facing_for(-1, 0.0), -1, "parado mantém -1")
	check_eq(Player.facing_for(1, 0.0), 1, "parado mantém 1")


func test_facing_flips() -> void:
	check_eq(Player.facing_for(1, -1.0), -1, "vira para a esquerda")
	check_eq(Player.facing_for(-1, 1.0), 1, "vira para a direita")
