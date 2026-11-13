class_name TestCase
extends RefCounted
## Base dos testes. Cada método `test_*` de uma subclasse vira um caso.
## Métodos `test_*` podem usar `await`. Use `tree` para pôr nós em cena.

var tree: SceneTree
var failures: Array[String] = []
var checks_run := 0


func check(cond: bool, msg: String) -> void:
	checks_run += 1
	if not cond:
		failures.append(msg)


func check_eq(actual, expected, msg: String) -> void:
	checks_run += 1
	if typeof(actual) != typeof(expected) or actual != expected:
		failures.append("%s (esperado %s, veio %s)" % [msg, str(expected), str(actual)])


## Espera `n` quadros de física.
func physics_frames(n: int) -> void:
	for i in n:
		await tree.physics_frame
