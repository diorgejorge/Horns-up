class_name VitrineModelo
extends SubViewportContainer
## Vitrine 3D do personagem selecionado (tela de grupo): o modelo inteiro
## girando devagar sobre um pedestal de cerâmica com anel marajoara luminoso.
## Só primitivas do Godot (cilindro, toro) e o GLB que já existe; sem assets novos.
## Arrastar com o mouse gira o modelo; soltando, ele volta a girar sozinho.

const VEL := 0.35  # rad/s

var _vp: SubViewport
var _giro: Node3D
var _cam: Camera3D
var _anel: MeshInstance3D
var _caminho := ""
var _arrastando := false


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_4X
	add_child(_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.62, 0.55)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-35, 35, 0)
	sol.light_energy = 1.4
	sol.light_color = Color(1, 0.93, 0.82)
	sol.shadow_enabled = true
	_vp.add_child(sol)
	var contra := DirectionalLight3D.new()  # luz de recorte quente, por trás
	contra.rotation_degrees = Vector3(-15, 200, 0)
	contra.light_energy = 1.3
	contra.light_color = Color(1.0, 0.55, 0.3)
	_vp.add_child(contra)
	_pedestal()
	_giro = Node3D.new()
	_vp.add_child(_giro)
	_cam = Camera3D.new()
	_cam.fov = 28.0
	_vp.add_child(_cam)


func _pedestal() -> void:
	var base := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.62
	cil.bottom_radius = 0.7
	cil.height = 0.16
	base.mesh = cil
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.95, 0.5, 0.32)  # terracota sobre a argila (textura CC0, ver CREDITS.md)
	m.albedo_texture = PainelMarajoara.ARGILA
	m.normal_enabled = true
	m.normal_texture = PainelMarajoara.ARGILA_NOR
	m.uv1_scale = Vector3(2, 1, 1)
	m.roughness = 0.7
	base.material_override = m
	base.position.y = -0.08
	_vp.add_child(base)
	_anel = MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.6
	t.outer_radius = 0.66
	_anel.mesh = t
	var ma := StandardMaterial3D.new()
	ma.albedo_color = TemaUI.CREME
	ma.emission_enabled = true
	ma.emission = TemaUI.OURO
	ma.emission_energy_multiplier = 1.6
	_anel.material_override = ma
	_anel.position.y = 0.005
	_vp.add_child(_anel)
	# disco escuro por cima: o topo do pedestal com os triângulos do grafismo
	for i in 12:
		var tri := MeshInstance3D.new()
		var p := PrismMesh.new()
		p.size = Vector3(0.14, 0.12, 0.01)
		tri.mesh = p
		var mt := StandardMaterial3D.new()
		mt.albedo_color = TemaUI.PRETO if i % 2 == 0 else TemaUI.CREME
		tri.material_override = mt
		var ang := TAU * i / 12.0
		tri.position = Vector3(sin(ang) * 0.5, 0.006, cos(ang) * 0.5)
		tri.rotation = Vector3(-PI / 2.0, ang, 0)
		if i % 2 == 1:
			tri.rotation.z = PI
		_vp.add_child(tri)


## Mostra o modelo (caminho do .glb), de corpo inteiro sobre o pedestal.
func mostrar(caminho: String, cor_anel := TemaUI.OURO) -> void:
	(_anel.material_override as StandardMaterial3D).emission = cor_anel
	if caminho == _caminho:
		return
	_caminho = caminho
	for c in _giro.get_children():
		c.queue_free()
	if caminho == "" or not ResourceLoader.exists(caminho):
		return
	var modelo: Node3D = load(caminho).instantiate()
	var suporte := Node3D.new()  # escala/centra sem mexer na transformação do GLB
	_giro.add_child(suporte)
	suporte.add_child(modelo)
	var ap := modelo.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap and ap.has_animation("idle"):
		ap.play("idle")
	var box := _aabb(suporte, Transform3D.IDENTITY)
	if box.size == Vector3.ZERO:
		return
	# normaliza para ~1.6 de altura, pés no pedestal e centrado no eixo de giro
	var esc := 1.6 / box.size.y
	suporte.scale = Vector3.ONE * esc
	var c := box.get_center() * esc
	suporte.position = Vector3(-c.x, -box.position.y * esc, -c.z)
	var alvo := Vector3(0, 0.78, 0)
	var dist := 1.15 / tan(deg_to_rad(_cam.fov * 0.5))
	_cam.position = alvo + Vector3(0, 0.32, 1).normalized() * dist
	_cam.look_at(alvo, Vector3.UP)
	_giro.rotation.y = 0.35


func _process(delta: float) -> void:
	if not _arrastando:
		_giro.rotation.y += VEL * delta
	_anel.rotation.y -= delta * 0.5


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		_arrastando = e.pressed
	elif e is InputEventMouseMotion and _arrastando:
		_giro.rotation.y += e.relative.x * 0.012


func _aabb(n: Node, xf: Transform3D) -> AABB:
	var t: Transform3D = xf * n.transform if n is Node3D else xf
	var a := AABB()
	if n is MeshInstance3D and n.mesh:
		a = t * n.mesh.get_aabb()
	for c in n.get_children():
		var b := _aabb(c, t)
		if b.size != Vector3.ZERO:
			a = b if a.size == Vector3.ZERO else a.merge(b)
	return a
