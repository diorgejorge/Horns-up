class_name CenarioGelo
extends Node3D
## Cenário caprichado do protótipo 2.5D (sala 2): materiais em alta
## resolução nas peças da sala, lago de água atrás do chão com blocos de gelo
## boiando, pingentes, montes de neve, neve caindo, céu e névoa.
## Só visual: nenhum nó daqui tem colisão, e a sala não muda de forma.

const ROCHA := preload("res://assets/shaders/rocha.gdshader")
const NEVE := preload("res://assets/shaders/neve.gdshader")
const GELO := preload("res://assets/shaders/gelo.gdshader")
const AGUA := preload("res://assets/shaders/agua.gdshader")
const T_ROCHA := preload("res://assets/texturas/rocha_ruido.png")
const T_ROCHA_N := preload("res://assets/texturas/rocha_normal.png")
const T_NEVE_N := preload("res://assets/texturas/neve_normal.png")
const T_BRILHO := preload("res://assets/texturas/neve_brilho.png")
const T_RACH := preload("res://assets/texturas/gelo_rachaduras.png")
const T_GELO_N := preload("res://assets/texturas/gelo_normal.png")
const T_AGUA_N := preload("res://assets/texturas/agua_normal.png")

var _floes: Array[Node3D] = []
var _time := 0.0


## Veste a sala; chamar de novo não duplica.
static func vestir(room: Node3D) -> CenarioGelo:
	if room.has_node("Cenario"):
		return room.get_node("Cenario")
	var c := CenarioGelo.new()
	c.name = "Cenario"
	c.add_to_group("cenario")
	room.add_child(c)
	c._materiais(room)
	c._ambiente(room)
	c._lago()
	c._pingentes()
	c._montes_de_neve()
	c._neve_caindo()
	return c


func _process(delta: float) -> void:
	_time += delta
	for i in _floes.size():
		var f := _floes[i]
		f.position.y = -0.55 + 0.04 * sin(_time * 1.1 + i * 1.7)
		f.rotation.z = 0.03 * sin(_time * 0.8 + i)


# ------------------------------------------------------------- materiais

static func mat_rocha(neve_topo := 0.65) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = ROCHA
	m.set_shader_parameter("ruido", T_ROCHA)
	m.set_shader_parameter("relevo", T_ROCHA_N)
	m.set_shader_parameter("neve_topo", neve_topo)
	return m


static func mat_neve() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = NEVE
	m.set_shader_parameter("relevo", T_NEVE_N)
	m.set_shader_parameter("brilho", T_BRILHO)
	return m


static func mat_gelo() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = GELO
	m.set_shader_parameter("rachaduras", T_RACH)
	m.set_shader_parameter("relevo", T_GELO_N)
	return m


static func mat_agua() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = AGUA
	m.set_shader_parameter("ondas", T_AGUA_N)
	m.set_shader_parameter("espuma_ruido", T_ROCHA)
	return m


func _materiais(room: Node3D) -> void:
	var neve := mat_neve()
	var rocha := mat_rocha()
	var gelo := mat_gelo()
	for path in ["Geometry/Floor/Mesh", "Geometry/TopPlatform/Mesh"]:
		_aplicar(room, path, neve)
	for path in ["Geometry/WallLeft/Mesh", "Geometry/Ledge/Mesh", "Geometry/EndWall/Mesh",
			"Geometry/ShaftRock/Mesh", "StoneBlock/Visual/Block"]:
		_aplicar(room, path, rocha)
	var montanha := mat_rocha(0.8)
	montanha.set_shader_parameter("escala", 0.06)
	montanha.set_shader_parameter("neve_altura", 9.0)
	for path in ["Background/Mountain", "Background/MountainPeak"]:
		_aplicar(room, path, montanha)
	for wall in room.find_children("*", "StaticBody3D", true, false):
		if wall.is_in_group("ice_wall"):
			for mi in wall.find_children("*", "MeshInstance3D", false, false):
				mi.material_override = gelo


static func _aplicar(room: Node3D, path: String, m: Material) -> void:
	var mi := room.get_node_or_null(path) as MeshInstance3D
	if mi:
		mi.material_override = m


func _ambiente(room: Node3D) -> void:
	var we := room.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we:
		var sky_mat := ProceduralSkyMaterial.new()
		sky_mat.sky_top_color = Color(0.22, 0.42, 0.72)
		sky_mat.sky_horizon_color = Color(0.78, 0.86, 0.95)
		sky_mat.ground_horizon_color = Color(0.78, 0.86, 0.95)
		sky_mat.ground_bottom_color = Color(0.3, 0.38, 0.5)
		sky_mat.sun_angle_max = 20.0
		var sky := Sky.new()
		sky.sky_material = sky_mat
		var env := Environment.new()
		env.background_mode = Environment.BG_SKY
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_energy = 0.55
		# linear: o sprite (sem sombreamento) mantém as cores do render
		env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		env.glow_enabled = true
		env.glow_intensity = 0.5
		env.glow_bloom = 0.0
		env.glow_hdr_threshold = 1.1
		env.fog_enabled = true
		env.fog_light_color = Color(0.74, 0.83, 0.94)
		env.fog_density = 0.0035
		env.fog_sky_affect = 0.3
		we.environment = env
	var sun := room.get_node_or_null("Sun") as DirectionalLight3D
	if sun:
		sun.light_color = Color(1.0, 0.95, 0.86)
		sun.light_energy = 1.0
		sun.shadow_enabled = true
		sun.directional_shadow_max_distance = 60.0


# ---------------------------------------------------------------- peças

func _lago() -> void:
	var plano := PlaneMesh.new()
	plano.size = Vector2(90, 46)
	plano.subdivide_width = 160
	plano.subdivide_depth = 60
	var lago := MeshInstance3D.new()
	lago.name = "Lago"
	lago.mesh = plano
	lago.material_override = mat_agua()
	# na frente e atrás do chão: a sala vira uma plataforma de gelo no lago
	lago.position = Vector3(1, -0.6, -11.0)
	lago.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lago)
	# blocos de gelo boiando
	var gelo := mat_gelo()
	var sorte := RandomNumberGenerator.new()
	sorte.seed = 4
	for i in 9:
		var caixa := BoxMesh.new()
		caixa.size = Vector3(sorte.randf_range(1.2, 3.5), 0.35, sorte.randf_range(0.8, 2.2))
		var bloco := MeshInstance3D.new()
		bloco.name = "Bloco%d" % i
		bloco.mesh = caixa
		bloco.material_override = gelo
		var z := sorte.randf_range(-16, -3.5) if i % 3 else sorte.randf_range(3.5, 7.0)
		bloco.position = Vector3(sorte.randf_range(-20, 24), -0.55, z)
		bloco.rotation.y = sorte.randf_range(-0.6, 0.6)
		add_child(bloco)
		_floes.append(bloco)


func _pingentes() -> void:
	var gelo := mat_gelo()
	var sorte := RandomNumberGenerator.new()
	sorte.seed = 9
	# embaixo da plataforma do topo (y = 11) e da saliência (y = 0,7)
	var linhas := [[12.2, 17.8, 11.0, 14], [-3.4, -0.6, 0.7, 6]]
	for l in linhas:
		for i in l[3]:
			var comp := sorte.randf_range(0.4, 1.4) if l[2] > 5.0 else sorte.randf_range(0.15, 0.35)
			var cone := CylinderMesh.new()
			cone.top_radius = sorte.randf_range(0.06, 0.13)
			cone.bottom_radius = 0.0
			cone.height = comp
			cone.radial_segments = 8
			var p := MeshInstance3D.new()
			p.name = "Pingente"
			p.mesh = cone
			p.material_override = gelo
			# na saliência (baixa) só atrás, para não tapar o bode
			var z := -1.2 if (i % 2 or l[2] < 5.0) else 1.2
			p.position = Vector3(lerpf(l[0], l[1], (i + 0.5) / l[3]), l[2] - comp / 2.0, z)
			add_child(p)


func _montes_de_neve() -> void:
	var neve := mat_neve()
	var xs := [-13.0, -10.2, -7.5, -3.8, 1.6, 3.4, 13.8, 16.6]
	for i in xs.size():
		var bola := SphereMesh.new()
		bola.radius = 0.55 + 0.2 * (i % 3)
		bola.height = bola.radius * 2.0
		bola.radial_segments = 24
		bola.rings = 12
		var m := MeshInstance3D.new()
		m.name = "Monte%d" % i
		m.mesh = bola
		m.material_override = neve
		# achatado e afundado no chão; atrás do bode quando é alto
		var frente := i % 2 == 0
		m.scale = Vector3(1.3, 0.35 if frente else 0.6, 0.4)
		m.position = Vector3(xs[i], -0.05, 1.4 if frente else -1.4)
		add_child(m)


func _neve_caindo() -> void:
	var floco := QuadMesh.new()
	floco.size = Vector2(0.06, 0.06)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 1, 1, 0.85)
	floco.material = mat
	var p := CPUParticles3D.new()
	p.name = "Neve"
	p.mesh = floco
	p.amount = 1400
	p.lifetime = 16.0
	p.preprocess = 16.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(22, 0.5, 8)
	p.position = Vector3(1, 22, -2)
	p.direction = Vector3(0.3, -1, 0)
	p.spread = 25.0
	p.gravity = Vector3(0, -0.4, 0)
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 1.6
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.6
	p.visibility_aabb = AABB(Vector3(-25, -30, -12), Vector3(50, 32, 24))
	add_child(p)
