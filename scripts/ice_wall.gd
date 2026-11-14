class_name IceWall
extends StaticBody3D
## Parede de gelo. Com o martelo de gelo, o bode gruda nela.

const ICE_COLOR := Color(0.62, 0.86, 0.98, 1)

@export var size := Vector3(1, 6, 4)


func _ready() -> void:
	add_to_group("ice_wall")
	var shape := BoxShape3D.new()
	shape.size = size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	add_child(cs)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = ICE_COLOR
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	add_child(mi)
