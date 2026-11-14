class_name Player
extends CharacterBody3D
## O bode. Lógica de movimento em funções estáticas, testáveis sem cena.

signal died
signal ability_gained(id: String)

const WALK_SPEED := 5.0
const JUMP_SPEED := 9.0
const GRAVITY := 25.0
const MAX_HP := 5
const INVULN_SECONDS := 1.0
const HAMMER_DAMAGE := 1
const ATTACK_COOLDOWN := 0.5
const HAMMER_ACTIVE_SECONDS := 0.1
## Primeira habilidade: o martelo quebra pedra e gruda no gelo.
const ABILITY_ICE_HAMMER := "martelo_gelo"
const WALL_JUMP_PUSH := 6.0
## Depois do pulo de parede, ignora a direção por este tempo, para o bode
## se afastar antes de voltar.
const WALL_JUMP_LOCK := 0.15
const CLING_PRESS := 0.5

var facing: int = 1
var health: Health = Health.new(MAX_HP, INVULN_SECONDS)
var cooldown_left := 0.0
var active_left := 0.0
## Alvos já atingidos nesta pancada; esvaziada a cada novo ataque.
var swing_hits: Array[Node] = []
var abilities: PackedStringArray = []
var clinging := false
var input_lock_left := 0.0
## Normal da última parede tocada: +1 parede à esquerda, -1 à direita.
var wall_normal_x := 0.0

@onready var visual: Node3D = $Visual
@onready var hammer_hitbox: Area3D = $HammerHitbox


func _ready() -> void:
	add_to_group("player")
	health.died.connect(func(): died.emit())


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("attack"):
		try_attack()
	var input_x := read_input_x(Input.is_action_pressed("move_left"), Input.is_action_pressed("move_right"))
	step(delta, input_x, Input.is_action_just_pressed("jump"))


## Um quadro de física sem ler o teclado (os testes chamam direto).
func step(delta: float, input_x: float, jump_pressed: bool) -> void:
	health.tick(delta)
	tick_attack(delta)
	var locked := input_lock_left > 0.0
	if locked:
		input_lock_left = max(input_lock_left - delta, 0.0)
		input_x = 0.0
	if clinging:
		if jump_pressed:
			clinging = false
			velocity = wall_jump_velocity(wall_normal_x)
			input_lock_left = WALL_JUMP_LOCK
		elif should_cling(is_on_floor(), true, has_ability(ABILITY_ICE_HAMMER), input_x, wall_normal_x):
			velocity = cling_velocity(velocity)
			# empurrão mínimo contra a parede, para seguir encostado nela
			velocity.x = -wall_normal_x * CLING_PRESS
		else:
			clinging = false
			velocity = compute_velocity(velocity, input_x, false, is_on_floor(), delta)
	else:
		var vx := velocity.x
		velocity = compute_velocity(velocity, input_x, jump_pressed, is_on_floor(), delta)
		if locked:
			velocity.x = vx # mantém o empurrão do pulo de parede
	if clinging:
		facing = 1 if wall_normal_x > 0.0 else -1 # de costas para a parede
	else:
		facing = facing_for(facing, input_x)
	visual.scale.x = facing
	move_and_slide()
	_update_wall(input_x)


## Depois do move_and_slide: acha parede quase vertical e decide se gruda.
func _update_wall(input_x: float) -> void:
	var ice := false
	var touching := false
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var n := col.get_normal()
		if absf(n.x) < 0.7:
			continue
		touching = true
		wall_normal_x = signf(n.x)
		var other := col.get_collider()
		ice = other is Node and other.is_in_group("ice_wall")
		break
	if not touching:
		clinging = false
		return
	if not clinging and should_cling(is_on_floor(), ice, has_ability(ABILITY_ICE_HAMMER), input_x, wall_normal_x):
		clinging = true
		velocity = cling_velocity(velocity)


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
	if node.is_in_group("breakable"):
		swing_hits.append(node)
		if has_ability(ABILITY_ICE_HAMMER):
			node.smash()
		else:
			node.bonk()
		return
	if not node.is_in_group("hurtable") or not node.has_method("take_hit"):
		return
	swing_hits.append(node)
	node.take_hit(HAMMER_DAMAGE, global_position.x)


func has_ability(id: String) -> bool:
	return abilities.has(id)


## False e sem sinal se já tinha.
func grant_ability(id: String) -> bool:
	if abilities.has(id):
		return false
	abilities.append(id)
	ability_gained.emit(id)
	return true


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


## Gruda só no ar, em gelo, com a habilidade e segurando contra a parede.
static func should_cling(on_floor: bool, wall_is_ice: bool, p_has_ability: bool, input_x: float, p_wall_normal_x: float) -> bool:
	return not on_floor and wall_is_ice and p_has_ability and input_x * p_wall_normal_x < 0.0


static func cling_velocity(_v: Vector3) -> Vector3:
	return Vector3.ZERO


static func wall_jump_velocity(p_wall_normal_x: float) -> Vector3:
	return Vector3(WALL_JUMP_PUSH * p_wall_normal_x, JUMP_SPEED, 0)


static func facing_for(current: int, input_x: float) -> int:
	if input_x > 0.0:
		return 1
	if input_x < 0.0:
		return -1
	return current
