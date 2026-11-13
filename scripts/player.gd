class_name Player
extends CharacterBody3D
## O bode. Lógica de movimento em funções estáticas, testáveis sem cena.

signal died

const WALK_SPEED := 5.0
const JUMP_SPEED := 9.0
const GRAVITY := 25.0
const MAX_HP := 5
const INVULN_SECONDS := 1.0

var facing: int = 1
var health: Health = Health.new(MAX_HP, INVULN_SECONDS)

@onready var visual: Node3D = $Visual


func _ready() -> void:
	health.died.connect(func(): died.emit())


func _physics_process(delta: float) -> void:
	health.tick(delta)
	var input_x := read_input_x(Input.is_action_pressed("move_left"), Input.is_action_pressed("move_right"))
	velocity = compute_velocity(velocity, input_x, Input.is_action_just_pressed("jump"), is_on_floor(), delta)
	facing = facing_for(facing, input_x)
	visual.scale.x = facing
	move_and_slide()


static func read_input_x(left: bool, right: bool) -> float:
	return (1.0 if right else 0.0) - (1.0 if left else 0.0)


static func compute_velocity(v: Vector3, input_x: float, jump_pressed: bool, on_floor: bool, delta: float) -> Vector3:
	var out := v
	out.x = input_x * WALK_SPEED
	if on_floor:
		out.y = JUMP_SPEED if jump_pressed else 0.0
	else:
		out.y = v.y - GRAVITY * delta
	return out


static func facing_for(current: int, input_x: float) -> int:
	if input_x > 0.0:
		return 1
	if input_x < 0.0:
		return -1
	return current
