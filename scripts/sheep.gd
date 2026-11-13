class_name Sheep
extends CharacterBody3D
## Ovelha soldado (lança e escudo). Patrulha sozinha entre dois limites,
## fere o bode ao encostar e cai com 3 golpes.

signal downed

const MAX_HP := 3
const CONTACT_DAMAGE := 1
const SPEED := 1.5
const GRAVITY := 25.0
const DOWNED_FREE_SECONDS := 1.0

@export var patrol_left := -2.0
@export var patrol_right := 2.0

var health := Health.new(MAX_HP)
var dir := 1

@onready var contact_area: Area3D = $ContactArea
@onready var visual: Node3D = $Visual


func _ready() -> void:
	add_to_group("hurtable")
	contact_area.body_entered.connect(_on_contact)
	health.died.connect(_on_died)


func _physics_process(delta: float) -> void:
	if health.is_dead():
		return
	dir = next_direction(global_position.x, dir, patrol_left, patrol_right)
	velocity.x = dir * SPEED
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	visual.scale.x = dir
	move_and_slide()
	# body_entered só sai na entrada; quem continua encostado segue apanhando
	# (a invulnerabilidade do bode limita o ritmo).
	for body in contact_area.get_overlapping_bodies():
		_on_contact(body)


func take_hit(damage: int, _from_x: float) -> void:
	if health.is_dead():
		return
	health.take_damage(damage)


static func next_direction(x: float, p_dir: int, left: float, right: float) -> int:
	if p_dir > 0 and x >= right:
		return -1
	if p_dir < 0 and x <= left:
		return 1
	return p_dir


func _on_contact(body: Node) -> void:
	if health.is_dead() or not body is Player:
		return
	body.take_hit(CONTACT_DAMAGE, global_position.x)


func _on_died() -> void:
	downed.emit()
	velocity = Vector3.ZERO
	$CollisionShape3D.set_deferred("disabled", true)
	contact_area.set_deferred("monitoring", false)
	visual.rotation.z = PI / 2 # tombada
	visual.position.y = 0.4
	if is_inside_tree():
		get_tree().create_timer(DOWNED_FREE_SECONDS).timeout.connect(queue_free)
