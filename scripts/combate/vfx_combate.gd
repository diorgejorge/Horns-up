class_name VfxCombate
extends RefCounted
## Efeitos visuais de combate só com recursos do Godot (partículas, luzes,
## malhas primitivas e shaders). Cada `visual` de Habilidade tem um jeito de
## viajar (lancar) e um jeito de acertar (acertar):
##   corpo   golpe de perto (só o impacto)
##   flecha  haste em arco com rastro de faíscas (rangers)
##   magia   orbe com rastro (genérico)
##   penas   orbe sombrio com penas girando (Murucututu, coruja)
##   esporos nuvem lenta de esporos que fica no alvo (Diabrete Cogumelo)
##   bote    orbe que serpenteia e dá o bote (Naga)
##   fumaca  baforada de fumaça que envolve o alvo (Sapo-cururu)
##   luz     raio de luz contínuo (clérigos: boto, tartaruga-da-amazônia)
##   cura    brilho que sobe · mare  onda no chão + cura · escudo  anel dourado

const SH_RAIO := preload("res://scripts/combate/shaders/raio_luz.gdshader")
const SH_ANEL := preload("res://scripts/combate/shaders/anel_chao.gdshader")


## Leva a ação de `de` até `para` (await). `i` = dicionário de Combate.info().
static func lancar(pai: Node3D, i: Dictionary, de: Vector3, para: Vector3, rapido := false) -> void:
	var cor: Color = i.get("cor", Color.WHITE)
	match i.get("visual", "corpo"):
		"flecha":
			await _viajar(pai, _flecha(cor), de, para, 0.6, 0.4, rapido)
		"magia", "cura", "mare":
			if de.distance_to(para) > 0.3:
				await _viajar(pai, _orbe(cor, 0.13), de, para, 0.25, 0.4, rapido)
		"penas":
			await _viajar(pai, _orbe_penas(cor), de, para, 0.35, 0.55, rapido)
		"esporos":
			await _viajar(pai, _nuvem(cor, 0.12, 40), de, para, 0.5, 0.8, rapido)
		"bote":
			await _viajar(pai, _orbe(cor, 0.11), de, para, 0.15, 0.5, rapido, 0.35)
		"fumaca":
			await _viajar(pai, _nuvem(cor.darkened(0.2), 0.2, 30), de, para, 0.3, 0.7, rapido)
		"luz":
			await raio(pai, de, para, cor, 0.15 if rapido else 0.45)


## Impacto da ação no ponto `pos` (não espera).
static func acertar(pai: Node3D, i: Dictionary, pos: Vector3) -> void:
	var cor: Color = i.get("cor", Color.WHITE)
	match i.get("visual", "corpo"):
		"penas":
			impacto(pai, pos, cor.darkened(0.4), true)
			_penas_caindo(pai, pos, cor)
		"esporos":
			impacto(pai, pos, cor)
			_nuvem_parada(pai, pos, cor, 0.1, 1.6)
		"bote":
			impacto(pai, pos, cor, true)
			_anel(pai, pos + Vector3.DOWN * 0.5, cor, 1.4, 0.5)
		"fumaca":
			_nuvem_parada(pai, pos, cor.darkened(0.2), 0.22, 1.8)
		"luz":
			impacto(pai, pos, cor.lightened(0.4), true)
		"cura":
			cura(pai, pos, cor)
		"mare":
			cura(pai, pos, cor)
		"escudo":
			escudo(pai, pos, cor)
		_:
			impacto(pai, pos, cor, i.get("tipo", "") == "area" or i.get("visual", "") == "magia")


## Onda de cura no chão (Maré Curativa) com raio em casas.
static func onda(pai: Node3D, centro: Vector3, cor: Color, raio_casas: int) -> void:
	_anel(pai, centro, cor, (raio_casas + 0.5) * 2.0, 0.9)


# --- efeitos básicos (os mesmos de scripts/campanha/efeitos.gd) -------------------------------

## Explosão de faíscas + clarão no ponto (golpe ou magia).
static func impacto(pai: Node3D, pos: Vector3, cor: Color, grande := false) -> void:
	var p := _particulas(cor, 40 if grande else 22, 0.6, 2.4 if grande else 1.6, Vector3(0, -4, 0), 0.07 if grande else 0.05)
	_por(pai, p, pos)
	p.emitting = true
	var l := _luz(cor, 4.0 if grande else 2.5, 3.0)
	_por(pai, l, pos + Vector3.UP * 0.3)
	l.create_tween().tween_property(l, "light_energy", 0.0, 0.4)
	_sumir(p, 1.2)
	_sumir(l, 0.5)


## Brilho subindo em anel em volta dos pés (cura).
static func cura(pai: Node3D, pes: Vector3, cor := Color(0.5, 1.0, 0.6)) -> void:
	var p := _particulas(cor, 30, 1.0, 1.2, Vector3(0, 1.5, 0), 0.05)
	p.spread = 25.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = 0.35
	p.emission_ring_inner_radius = 0.25
	p.emission_ring_height = 0.05
	_por(pai, p, pes)
	p.emitting = true
	var l := _luz(cor, 2.5, 2.5)
	_por(pai, l, pes + Vector3.UP * 0.6)
	l.create_tween().tween_property(l, "light_energy", 0.0, 1.0)
	_sumir(p, 1.6)
	_sumir(l, 1.1)


## Anel que sobe dos pés (aumento de defesa).
static func escudo(pai: Node3D, pes: Vector3, cor := Color(1.0, 0.85, 0.35)) -> void:
	var anel := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.38
	t.outer_radius = 0.44
	anel.mesh = t
	anel.material_override = _mat(cor, 3.0)
	_por(pai, anel, pes + Vector3.UP * 0.05)
	var tw := anel.create_tween()
	tw.tween_property(anel, "position:y", anel.position.y + 1.0, 0.8)
	tw.parallel().tween_property(anel, "scale", Vector3.ONE * 1.3, 0.8)
	tw.tween_callback(anel.queue_free)
	impacto(pai, pes + Vector3.UP * 0.5, cor)


## Raio de luz de `de` até `para` que acende e apaga em `dur` segundos (await).
static func raio(pai: Node3D, de: Vector3, para: Vector3, cor: Color, dur := 0.45) -> void:
	var r := MeshInstance3D.new()
	var c := CylinderMesh.new()
	var comp := de.distance_to(para)
	c.top_radius = 0.07
	c.bottom_radius = 0.07
	c.height = comp
	c.radial_segments = 12
	c.rings = 1
	r.mesh = c
	var m := ShaderMaterial.new()
	m.shader = SH_RAIO
	m.set_shader_parameter("cor", cor)
	m.set_shader_parameter("faixas", maxf(2.0, comp * 3.0))
	r.material_override = m
	_por(pai, r, (de + para) * 0.5)
	# o cilindro nasce em pé (eixo Y): deita na direção do alvo
	var dir := (para - de).normalized()
	var lado := dir.cross(Vector3.UP) if absf(dir.y) < 0.99 else Vector3.RIGHT
	r.global_basis = Basis(lado.normalized(), dir, lado.cross(dir).normalized()).orthonormalized()
	var l1 := _luz(cor, 3.0, 2.5)
	var l2 := _luz(cor, 4.0, 3.0)
	_por(pai, l1, de)
	_por(pai, l2, para)
	var tw := r.create_tween()
	tw.tween_method(func(f: float): m.set_shader_parameter("forca", f), 0.0, 1.0, dur * 0.25)
	tw.tween_interval(dur * 0.45)
	tw.tween_method(func(f: float):
		m.set_shader_parameter("forca", f)
		l1.light_energy = 3.0 * f
		l2.light_energy = 4.0 * f, 1.0, 0.0, dur * 0.3)
	await tw.finished
	for n in [r, l1, l2]:
		n.queue_free()


# --- peças -------------------------------------------------------------------------------------

## Faz `n` viajar de `de` até `para` em arco (altura `arco`), opcionalmente
## serpenteando de lado (`serpente`), e some ao chegar. `base` = duração para 3 casas.
static func _viajar(pai: Node3D, n: Node3D, de: Vector3, para: Vector3, arco: float, base: float, rapido: bool, serpente := 0.0) -> void:
	_por(pai, n, de)
	var lado := (para - de).cross(Vector3.UP).normalized()
	var dur := (base * 0.3 if rapido else base) * clampf(de.distance_to(para) / 3.0, 0.6, 1.6)
	var tw := n.create_tween()
	tw.tween_method(func(t: float):
		var p := de.lerp(para, t) + Vector3.UP * sin(t * PI) * arco + lado * sin(t * TAU * 1.5) * serpente * (1.0 - t)
		if p.distance_to(n.global_position) > 0.001:
			n.look_at(p, Vector3.UP)
		n.global_position = p, 0.0, 1.0, dur)
	await tw.finished
	# deixa o rastro terminar de sumir antes de apagar
	for c in n.get_children():
		if c is CPUParticles3D:
			c.emitting = false
		elif c is GeometryInstance3D:
			c.hide()
		elif c is Light3D:
			c.light_energy = 0.0
	_sumir(n, 0.6)


static func _flecha(cor: Color) -> Node3D:
	var n := Node3D.new()
	var haste := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.015
	c.bottom_radius = 0.015
	c.height = 0.45
	haste.mesh = c
	haste.rotation_degrees.x = 90.0
	haste.material_override = _mat(Color(0.55, 0.38, 0.2), 0.3)
	n.add_child(haste)
	var ponta := MeshInstance3D.new()
	var pm := SphereMesh.new()
	pm.radius = 0.035
	pm.height = 0.07
	ponta.mesh = pm
	ponta.position.z = -0.24
	ponta.material_override = _mat(cor, 1.5)
	n.add_child(ponta)
	var rastro := _rastro(cor, 16, 0.25, 0.025)
	rastro.position.z = 0.2
	n.add_child(rastro)
	return n


static func _orbe(cor: Color, raio_orbe: float) -> Node3D:
	var n := Node3D.new()
	var orbe := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = raio_orbe
	sm.height = raio_orbe * 2.0
	orbe.mesh = sm
	orbe.material_override = _mat(cor, 4.0)
	n.add_child(orbe)
	n.add_child(_luz(cor, 2.5, 2.5))
	n.add_child(_rastro(cor, 24, 0.4, 0.04))
	return n


## Coruja: núcleo escuro com halo roxo e penas girando em volta.
static func _orbe_penas(cor: Color) -> Node3D:
	var n := _orbe(cor.darkened(0.6), 0.1)
	var penas := _penas(cor, 14, 0.5)
	penas.one_shot = false
	penas.explosiveness = 0.0
	penas.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	penas.emission_sphere_radius = 0.18
	penas.gravity = Vector3.ZERO
	n.add_child(penas)
	return n


## Nuvem que viaja (esporos, fumaça): bolas macias que ficam para trás.
static func _nuvem(cor: Color, tam: float, qtd: int) -> Node3D:
	var n := Node3D.new()
	var p := _fofo(cor, qtd, 0.7, tam)
	p.one_shot = false
	p.explosiveness = 0.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.15
	n.add_child(p)
	n.add_child(_luz(cor, 1.2, 2.0))
	return n


## Nuvem parada no alvo por `dur` segundos.
static func _nuvem_parada(pai: Node3D, pos: Vector3, cor: Color, tam: float, dur: float) -> void:
	var p := _fofo(cor, 36, dur, tam)
	p.explosiveness = 0.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.35
	p.initial_velocity_max = 0.4
	p.gravity = Vector3(0, 0.25, 0)
	_por(pai, p, pos)
	p.emitting = true
	var l := _luz(cor, 1.5, 2.0)
	_por(pai, l, pos)
	l.create_tween().tween_property(l, "light_energy", 0.0, dur)
	_sumir(p, dur + 0.5)
	_sumir(l, dur)


static func _penas_caindo(pai: Node3D, pos: Vector3, cor: Color) -> void:
	var p := _penas(cor, 18, 1.4)
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.4
	p.gravity = Vector3(0, -0.9, 0)
	p.damping_min = 1.0
	p.damping_max = 2.0
	_por(pai, p, pos)
	p.emitting = true
	_sumir(p, 2.0)


## Anel de shader no chão que se abre até `diametro` em `dur` segundos.
static func _anel(pai: Node3D, centro: Vector3, cor: Color, diametro: float, dur: float) -> void:
	var a := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2.ONE * diametro
	a.mesh = pm
	var m := ShaderMaterial.new()
	m.shader = SH_ANEL
	m.set_shader_parameter("cor", cor)
	a.material_override = m
	_por(pai, a, centro + Vector3.UP * 0.04)
	var tw := a.create_tween()
	tw.tween_method(func(f: float): m.set_shader_parameter("progresso", f), 0.0, 1.0, dur)
	tw.tween_callback(a.queue_free)


static func _mat(cor: Color, emissao := 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = cor
	m.emission_enabled = true
	m.emission = cor
	m.emission_energy_multiplier = emissao
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	return m


static func _particulas(cor: Color, qtd: int, vida: float, vel: float, gravidade: Vector3, tamanho := 0.06) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = qtd
	p.lifetime = vida
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = vel * 0.5
	p.initial_velocity_max = vel
	p.gravity = gravidade
	var s := SphereMesh.new()
	s.radius = tamanho
	s.height = tamanho * 2.0
	s.radial_segments = 6
	s.rings = 3
	p.mesh = s
	p.material_override = _mat(cor)
	p.color_ramp = _sumindo(cor)
	return p


## Rastro contínuo (sem gravidade) para coisas que voam.
static func _rastro(cor: Color, qtd: int, vida: float, tam: float) -> CPUParticles3D:
	var p := _particulas(cor, qtd, vida, 0.3, Vector3.ZERO, tam)
	p.one_shot = false
	p.explosiveness = 0.0
	return p


## Penas: quadradinhos achatados que giram de frente para a câmera.
static func _penas(cor: Color, qtd: int, vida: float) -> CPUParticles3D:
	var p := _particulas(cor, qtd, vida, 0.8, Vector3.ZERO)
	var q := QuadMesh.new()
	q.size = Vector2(0.09, 0.22)
	p.mesh = q
	var m := _mat(cor.darkened(0.3), 1.2)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	p.material_override = m
	p.angle_min = -180.0
	p.angle_max = 180.0
	p.angular_velocity_min = -240.0
	p.angular_velocity_max = 240.0
	var g := Gradient.new()
	g.set_color(0, cor.lightened(0.2))
	g.set_color(1, Color(0.05, 0.02, 0.08, 0.0))
	p.color_ramp = g
	return p


## Bolas de fumaça macias (textura radial gerada, sem arquivo de imagem).
static func _fofo(cor: Color, qtd: int, vida: float, tam: float) -> CPUParticles3D:
	var p := _particulas(cor, qtd, vida, 0.15, Vector3(0, 0.3, 0))
	var q := QuadMesh.new()
	q.size = Vector2.ONE * tam * 2.0
	p.mesh = q
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color.WHITE)
	g.set_color(1, Color(1, 1, 1, 0))
	tex.gradient = g
	var m := _mat(cor, 0.8)
	m.albedo_texture = tex
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	p.material_override = m
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	p.angle_min = -180.0
	p.angle_max = 180.0
	var ramp := _sumindo(cor)
	ramp.set_color(0, Color(cor, 0.0))
	ramp.add_point(0.2, Color(cor, 0.85))
	p.color_ramp = ramp
	return p


static func _sumindo(cor: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, cor)
	g.set_color(1, Color(cor, 0.0))
	return g


static func _luz(cor: Color, energia: float, alcance: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = cor
	l.light_energy = energia
	l.omni_range = alcance
	return l


## Põe `n` dentro de `pai` na posição global `pos`.
static func _por(pai: Node3D, n: Node3D, pos: Vector3) -> void:
	pai.add_child(n)
	n.global_position = pos


static func _sumir(n: Node, t: float) -> void:
	n.get_tree().create_timer(t).timeout.connect(n.queue_free)
