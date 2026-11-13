class_name Player
extends CharacterBody3D
## O bode. Lógica de movimento em funções estáticas, testáveis sem cena.

signal died

const WALK_SPEED := 5.0
const JUMP_SPEED := 9.0
const GRAVITY := 25.0
const MAX_HP := 5
const INVULN_SECONDS := 1.0
const HAMMER_DAMAGE := 1
const ATTACK_COOLDOWN := 0.5
const HAMMER_ACTIVE_SECONDS := 0.1

var facing: int = 1
var health: Health = Health.new(MAX_HP, INVULN_SECONDS)
var cooldown_left := 0.0
var active_left := 0.0
## Alvos já atingidos nesta pancada; esvaziada a cada novo ataque.
var swing_hits: Array[Node] = []

@onready var visual: Node3D = $Visual
@onready var hammer_hitbox: Area3D = $HammerHitbox


func _ready() -> void:
	add_to_group("player")
	health.died.connect(func(): died.emit())


func _physics_process(delta: float) -> void:
	health.tick(delta)
	if Input.is_action_just_pressed("attack"):
		try_attack()
	tick_attack(delta)
	var input_x := read_input_x(Input.is_action_pressed("move_left"), Input.is_action_pressed("move_right"))
	velocity = compute_velocity(velocity, input_x, Input.is_action_just_pressed("jump"), is_on_floor(), delta)
	facing = facing_for(facing, input_x)
	visual.scale.x = facing
	move_and_slide()


## Começa uma pancada na direção em que o bode encara. False na recarga.
func try_attack() -> bool:
	if cooldown_left > 0.0:
		return false
	cooldown_left = ATTACK_COOLDOWN
	active_left = HAMMER_ACTIVE_SECONDS
	swing_hits.clear()
	hammer_hitbox.position = hitbox_offset(facing)
	hammer_hitbox.visible = true
	return true


## Avança recarga e tempo ativo; enquanto ativo, bate em cada alvo uma vez.
## O HammerHitbox monitora sempre (ligar `monitoring` na hora não detecta
## corpo parado já sobreposto); só conta golpe enquanto `active_left > 0`.
func tick_attack(delta: float) -> void:
	cooldown_left = max(cooldown_left - delta, 0.0)
	if active_left <= 0.0:
		return
	for body in hammer_hitbox.get_overlapping_bodies():
		_hit(body)
	for area in hammer_hitbox.get_overlapping_areas():
		_hit(area)
	active_left -= delta
	if active_left <= 0.0:
		active_left = 0.0
		hammer_hitbox.visible = false


func _hit(node: Node) -> void:
	if node == self or swing_hits.has(node):
		return
	if not node.is_in_group("hurtable") or not node.has_method("take_hit"):
		return
	swing_hits.append(node)
	node.take_hit(HAMMER_DAMAGE, global_position.x)


func take_hit(damage: int, _from_x: float) -> void:
	health.take_damage(damage)


static func hitbox_offset(p_facing: int) -> Vector3:
	return Vector3(1.2 * p_facing, 0.8, 0)


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
