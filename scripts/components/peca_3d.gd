@tool
class_name Peca3D
extends Node3D
## Peça 3D do cenário (piso, árvore, casa...). Arraste no editor: ela encaixa
## no centro da casa da grade. A altura (Y) fica livre, para empilhar peças.
## As cenas prontas de cada peça ficam em scenes/3d/pecas/<kit>/.

## Piso: as unidades pisam nele (usa altura_topo). Objeto: fica em cima do piso.
@export var piso := true
## Dá para andar nesta casa? (água funda, árvore, muro = não)
@export var andavel := true
## Altura onde os pés das unidades ficam, medida a partir da base da peça.
@export_range(0.0, 3.0, 0.01) var altura_topo := 0.3
## Quantas casas a peça ocupa (x, z) antes de girar. O piso 2x2 do castelo = (2, 2).
@export var tamanho := Vector2i(1, 1)
## Encaixar na grade ao arrastar e girar só de 90 em 90 graus.
@export var encaixar := true
## Material aplicado em toda a peça (útil nas peças cinza sem textura). Vazio = original.
@export var material_sobrepor: Material:
	set(v):
		material_sobrepor = v
		if is_inside_tree():
			_aplicar_material(self)

var _pending := false


func _ready() -> void:
	set_notify_transform(true)
	if material_sobrepor:
		_aplicar_material(self)


func _aplicar_material(n: Node) -> void:
	if n is MeshInstance3D:
		n.material_override = material_sobrepor
	for c in n.get_children():
		_aplicar_material(c)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint() and encaixar and not _pending:
		_pending = true
		_snap.call_deferred()


## Tamanho já considerando o giro (90° troca x e z).
func tamanho_girado() -> Vector2i:
	var q := posmod(roundi(rotation_degrees.y / 90.0), 4)
	return tamanho if q % 2 == 0 else Vector2i(tamanho.y, tamanho.x)


## Casas da grade que a peça cobre.
func casas() -> Array[Vector2i]:
	var t := tamanho_girado()
	var x0 := roundi(global_position.x - t.x * 0.5)
	var z0 := roundi(global_position.z - t.y * 0.5)
	var out: Array[Vector2i] = []
	for x in t.x:
		for z in t.y:
			out.append(Vector2i(x0 + x, z0 + z))
	return out


## Altura (Y global) onde uma unidade fica em pé sobre esta peça.
func topo_global() -> float:
	return global_position.y + altura_topo * scale.y


func _snap() -> void:
	_pending = false
	if not is_inside_tree():
		return
	var r := rotation_degrees
	if piso:  # objetos podem girar livre (variedade); pisos só de 90 em 90
		r.y = roundf(r.y / 90.0) * 90.0
	var t := tamanho_girado()
	var p := position
	p.x = (floorf(p.x - t.x * 0.5 + 0.5)) + t.x * 0.5
	p.z = (floorf(p.z - t.y * 0.5 + 0.5)) + t.y * 0.5
	if not p.is_equal_approx(position) or not r.is_equal_approx(rotation_degrees):
		set_notify_transform(false)
		position = p
		rotation_degrees = r
		set_notify_transform(true)
