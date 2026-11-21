class_name RetratoModelo
extends SubViewportContainer
## Retrato "estilo Final Fantasy" feito do próprio modelo 3D (sem imagem pronta):
## renderiza o rosto do GLB (close no osso Head) num SubViewport com mundo próprio, câmera e luz.
## Personagens sem modelo (Morador, Voz) usam o losango de IconeUnidade.

var _vp: SubViewport
var _pivo: Node3D
var _cam: Camera3D
var _caminho := ""


func _init() -> void:
	stretch = true
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_2X
	add_child(_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.7, 0.65)
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-25, 30, 0)
	sol.light_energy = 1.5
	sol.light_color = Color(1, 0.92, 0.8)
	_vp.add_child(sol)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-10, 200, 0)
	rim.light_energy = 0.8
	rim.light_color = Color(1.0, 0.6, 0.35)
	_vp.add_child(rim)
	_pivo = Node3D.new()
	_vp.add_child(_pivo)
	_cam = Camera3D.new()
	_cam.fov = 30.0
	_vp.add_child(_cam)


## Mostra o modelo (caminho do .glb). Vazio = nada.
func mostrar(caminho: String) -> void:
	if caminho == _caminho:
		aproximar()
		return
	_caminho = caminho
	for c in _pivo.get_children():
		c.queue_free()
	if caminho == "" or not ResourceLoader.exists(caminho):
		return
	var m: Node3D = load(caminho).instantiate()
	_pivo.add_child(m)
	var ap := m.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap and ap.has_animation("idle"):
		ap.play("idle")
	var box := _aabb(m, Transform3D.IDENTITY)
	# Close no rosto: caixa dos vértices presos ao osso Head (o osso em si fica em
	# alturas diferentes em cada rig). Sem osso Head, usa o quinto de cima do modelo.
	var rosto := _caixa_cabeca(m)
	if rosto.size == Vector3.ZERO:
		rosto = AABB(Vector3(box.position.x, box.end.y - box.size.y * 0.2, box.position.z), Vector3(box.size.x, box.size.y * 0.2, box.size.z))
	var meia := rosto.size.y * 0.62  # meia altura do quadro
	_alvo = Vector3(rosto.get_center().x, rosto.position.y + rosto.size.y * 0.4, rosto.get_center().z)
	if rosto.size.y < box.size.y * 0.12:
		# Rig com poucos vértices presos à cabeça (Mapinguari): usa só a altura dela.
		meia = box.size.y * 0.24
		_alvo.y = rosto.get_center().y + box.size.y * 0.05
	# Barriga/casco podem ficar à frente da cabeça: a câmera recua até sair do
	# modelo e fecha a lente (teleobjetiva) para manter o mesmo close.
	_dist = maxf(meia / tan(deg_to_rad(FOV * 0.5)), box.end.z - _alvo.z + box.size.y * 0.4)  # folga p/ braços no idle
	_cam.fov = rad_to_deg(2.0 * atan(meia / _dist))
	aproximar()


const FOV := 30.0
var _alvo := Vector3.ZERO
var _dist := 1.0
var _zoom: Tween


## Zoom lento de cinema no rosto de quem fala (recomeça a cada fala).
func aproximar(duracao := 4.0) -> void:
	if _zoom:
		_zoom.kill()
	var dir := Vector3(0.22, 0.04, 1.0).normalized()
	_cam.position = _alvo + dir * _dist * 1.12
	_cam.look_at(_alvo, Vector3.UP)
	_zoom = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_zoom.tween_property(_cam, "position", _alvo + dir * _dist * 0.94, duracao)


## AABB (no espaço do modelo) dos vértices com peso > 0.5 no osso "Head".
func _caixa_cabeca(m: Node3D) -> AABB:
	var pts := PackedVector3Array()
	for mi: MeshInstance3D in m.find_children("*", "MeshInstance3D", true, false):
		var sk := mi.get_node_or_null(mi.skeleton) as Skeleton3D
		if mi.mesh == null or sk == null or sk.find_bone("Head") < 0:
			continue
		var cabeca := sk.find_bone("Head")
		var xf := _xf_global(mi)
		for sf in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(sf)
			var bones = arr[Mesh.ARRAY_BONES]
			var pesos = arr[Mesh.ARRAY_WEIGHTS]
			if bones == null or pesos == null:
				continue
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var n: int = bones.size() / verts.size()  # influências por vértice (4 ou 8)
			for v in verts.size():
				for k in n:
					var b: int = bones[v * n + k]
					if mi.skin:
						b = sk.find_bone(mi.skin.get_bind_name(b)) if mi.skin.get_bind_name(b) != &"" else mi.skin.get_bind_bone(b)
					if b == cabeca and pesos[v * n + k] > 0.5:
						pts.append(xf * verts[v])
	if pts.is_empty():
		return AABB()
	var a := AABB(pts[0], Vector3.ZERO)
	for p in pts:
		a = a.expand(p)
	return a


func _xf_global(n: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	while n and n != _pivo:
		if n is Node3D:
			xf = n.transform * xf
		n = n.get_parent()
	return xf


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
