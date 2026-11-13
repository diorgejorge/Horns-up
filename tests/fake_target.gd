extends StaticBody3D
## Alvo falso para testes: conta as chamadas de take_hit.

var hits := 0


func _ready() -> void:
	add_to_group("hurtable")
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.5, 0.5, 0.5)
	cs.shape = box
	add_child(cs)


func take_hit(_damage: int, _from_x: float) -> void:
	hits += 1
