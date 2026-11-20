extends OmniLight3D
## Luz que tremula (tocha, fogueira). Ajuste a energia base e a variação no Inspector.

@export var base_energy := 2.3
@export var variation := 0.3
@export var speed := 13.0


func _process(_delta: float) -> void:
	light_energy = base_energy + sin(Time.get_ticks_msec() * 0.001 * speed) * variation * 0.6 + randf() * variation * 0.5
