class_name Health
extends RefCounted
## Vida com invulnerabilidade após dano. Sem nó: testável em headless.

signal changed(hp: int)
signal died

var max_hp: int
var hp: int
var invuln_seconds: float
var invuln_left := 0.0
var _died_emitted := false


func _init(p_max_hp: int, p_invuln_seconds: float = 0.0) -> void:
	max_hp = p_max_hp
	hp = p_max_hp
	invuln_seconds = p_invuln_seconds


## Devolve true se o dano foi aplicado. Ignora durante a invulnerabilidade
## ou com a vida já em 0.
func take_damage(amount: int) -> bool:
	if invuln_left > 0.0 or hp <= 0 or amount <= 0:
		return false
	hp = max(hp - amount, 0)
	invuln_left = invuln_seconds
	changed.emit(hp)
	if hp == 0 and not _died_emitted:
		_died_emitted = true
		died.emit()
	return true


## Cura total. É o único jeito de reviver: explícito, zera a invulnerabilidade,
## rearma o sinal `died` e emite `changed`.
func heal_full() -> void:
	hp = max_hp
	invuln_left = 0.0
	_died_emitted = false
	changed.emit(hp)


## Protege de dano por `seconds` (ex.: ao renascer).
func grant_invulnerability(seconds: float) -> void:
	invuln_left = max(invuln_left, seconds)


func tick(delta: float) -> void:
	invuln_left = max(invuln_left - delta, 0.0)


func is_dead() -> bool:
	return hp <= 0
