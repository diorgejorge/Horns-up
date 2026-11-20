extends SceneTree
## Gera UMA VEZ as cenas 3D a partir dos .glb de assets/diorge:
##   scenes/3d/pecas/<kit>/<peca>.tscn   (uma cena por peça, com Peca3D)
##   scenes/3d/batalha_3d.tscn, scenes/3d/mapa_mundi_3d.tscn
## Arquivos que já existem NÃO são sobrescritos (para não apagar o que você editou).
## Para forçar: godot --headless --path . -s tools/gerar_cenas_3d.gd -- --forcar
## Peças novas que aparecerem nas pastas ganham cena ao rodar de novo.

const KITS := ["terreno2", "floresta", "pantano", "castelo", "terreno", "props", "terreno3"]
const PECAS := "res://scenes/3d/pecas/%s/%s.tscn"
const BATALHA := "res://scenes/3d/batalha_3d.tscn"
const MAPA := "res://scenes/3d/mapa_mundi_3d.tscn"

## Pisos: altura do topo (onde se pisa, medida no centro da peça) e se dá para andar.
const PISOS := {
	"t01_grama": [0.31, true], "t02_terra_vermelha": [0.25, true], "t03_areia": [0.25, true],
	"t04_agua_rasa_pedras": [0.15, true], "t05_agua_escura": [0.26, false],
	"t06_pantano_raizes": [0.35, true], "t07_rocha_musgo_alta": [0.64, true],
	"t08_rampa_terra": [0.30, true], "t09_escada_terra": [0.47, true],
	"t10_lama_raizes": [0.44, true], "t11_cachoeira_rocha": [0.47, false],
	"t12_chao_floresta": [0.32, true], "t13_laje_rachada": [0.29, true],
	"t14_agua_vitorias_regias": [0.35, false],
	"f11_chao_folhas": [0.12, true], "f12_chao_raizes": [0.13, true],
	"s01_vitorias_regias": [0.28, false], "s04_lama_juncos": [0.24, true],
	"s07_potes_barro": [0.22, false], "s08_lama_fungos": [0.26, true],
	"s09_deque_madeira": [0.06, true], "s10_poca_agua": [0.12, true],
	"s14_monte_lama": [0.39, true], "c03_piso_entalhado_2x2": [0.17, true],
	# terreno3 (várzea / mata, 1 casa por tile): topo medido no centro
	"m01_raizes_musgo": [0.36, true], "m02_deque_tabuas": [0.25, true], "m03_lama_cupins": [0.31, true], "m04_agua_vitorias_regias": [0.23, false], "m05_lama_furos": [0.23, true], "m06_terra_vermelha": [0.25, true], "m07_deque_estacas": [0.26, true], "m08_raizes_terra": [0.64, true], "m09_brejo_capim": [0.32, true], "m10_capim_pedras": [0.27, true], "m11_capim_ouricos": [0.38, true], "m12_lodo_ouricos": [0.55, true], "m13_areia": [0.23, true], "m14_pedra_musgo_alta": [0.67, true], "m15_raiz_tronco": [0.70, false], "m16_raizes_grama": [0.74, false], "m17_agua_rasa_pedras": [0.29, true], "m18_pedras_escuras": [0.28, true], "m19_areia_margem": [0.21, true], "m20_folhas_secas_pedra": [0.36, true], "m21_tronco_caido_grama": [0.46, true], "m22_folhas_ouricos": [0.52, true], "m23_riacho_pedras": [0.40, true], "m24_agua_funda": [0.27, false], "m25_terra_rachada": [0.34, true], "m26_arbustos_ouricos": [0.55, true], "m27_terra_marrom": [0.27, true], "m28_lodo_ouricos_b": [0.55, true], "m29_piso_marajoara": [0.31, true], "m30_corredeira_pedras": [0.26, false],
}
## Quantas casas ocupa (o resto é 1x1).
const TAMANHOS := {
	"c01_escada_pedra": Vector2i(2, 2), "c02_palicada_canto": Vector2i(3, 3),
	"c03_piso_entalhado_2x2": Vector2i(2, 2), "c04_muro_canto": Vector2i(2, 2),
	"c05_ponte_corda": Vector2i(3, 1), "c06_rampa_pedra": Vector2i(2, 2),
	"c07_oca_palha": Vector2i(2, 2), "c11_portao_entalhado": Vector2i(1, 4),
	"c12_muro_ruina_cipos": Vector2i(3, 2), "s13_toco_musgo_juncos": Vector2i(2, 2),
}

var forcar := false
var _rng := RandomNumberGenerator.new()
var _rocha: Material


func _init() -> void:
	forcar = "--forcar" in OS.get_cmdline_user_args()
	_rng.seed = 2026
	_rocha = _material_rocha()
	for kit in KITS:
		_pecas_do_kit(kit)
	if forcar or not FileAccess.file_exists(BATALHA):
		_salvar(_batalha(), BATALHA)
	if forcar or not FileAccess.file_exists(MAPA):
		_salvar(_mapa(), MAPA)
	quit()


# --- cenas de peça -------------------------------------------------------------

func _pecas_do_kit(kit: String) -> void:
	var dir := "res://assets/diorge/%s/" % kit
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes/3d/pecas/" + kit))
	for f in DirAccess.get_files_at(dir):
		if not f.ends_with(".glb"):
			continue
		var nome := f.get_basename()
		var out := PECAS % [kit, nome]
		if FileAccess.file_exists(out) and not forcar:
			continue
		var root := Node3D.new()
		root.name = nome
		root.set_script(load("res://scripts/components/peca_3d.gd"))
		var glb: Node3D = load(dir + f).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		glb.name = "Modelo"
		root.add_child(glb)
		glb.owner = root
		var aabb := _aabb(glb, Transform3D.IDENTITY)
		if PISOS.has(nome):
			root.piso = true
			root.altura_topo = PISOS[nome][0]
			root.andavel = PISOS[nome][1]
		elif kit == "terreno" and nome.contains("bloco"):
			root.piso = true  # blocos cinza: topo ~ altura da caixa (sem a franja)
			root.altura_topo = snappedf(aabb.size.y * 0.92, 0.01)
		else:
			root.piso = false
			root.andavel = false
		root.tamanho = TAMANHOS.get(nome, Vector2i(1, 1))
		if kit == "terreno":
			root.material_sobrepor = _rocha
		_salvar(root, out)


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


func _material_rocha() -> Material:
	var path := "res://scenes/3d/pecas/rocha_cinza.tres"
	if FileAccess.file_exists(path) and not forcar:
		return load(path)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.62, 0.6, 0.55)
	m.albedo_texture = load("res://assets/textures/Rock030_1K-JPG_Color.jpg")
	m.normal_enabled = true
	m.normal_texture = load("res://assets/textures/Rock030_1K-JPG_NormalGL.jpg")
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(0.8, 0.8, 0.8)
	m.roughness = 0.9
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes/3d/pecas"))
	ResourceSaver.save(m, path)
	return load(path)


# --- ajudantes de montagem -------------------------------------------------------

func _peca(parent: Node3D, owner_: Node, kit: String, nome: String, cx: float, cz: float, y := 0.0, giro := 0.0, escala := 1.0) -> Node3D:
	var p: Node3D = load(PECAS % [kit, nome]).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	p.position = Vector3(cx, y, cz)
	p.rotation_degrees.y = giro
	if escala != 1.0:
		p.scale = Vector3.ONE * escala
	parent.add_child(p, true)
	p.owner = owner_
	return p


func _grupo(parent: Node, nome: String, owner_: Node) -> Node3D:
	var n := Node3D.new()
	n.name = nome
	parent.add_child(n)
	n.owner = owner_
	return n


func _unidade(parent: Node3D, owner_: Node, modelo: String, nome: String, classe: String, inimigo: bool, cell: Vector2i, y: float, giro: float, des: int, escala := 1.0) -> Node3D:
	var u := Node3D.new()
	u.set_script(load("res://scripts/components/unidade_3d.gd"))
	u.name = nome.replace(" ", "_")
	u.modelo = load("res://assets/diorge/rigged/%s.glb" % modelo)
	u.display_name = nome
	u.classe = classe
	u.enemy = inimigo
	u.escala = escala
	u.destreza = des
	u.forca = _rng.randi_range(8, 16)
	u.constituicao = _rng.randi_range(8, 16)
	u.inteligencia = _rng.randi_range(8, 16)
	u.sabedoria = _rng.randi_range(8, 16)
	u.carisma = _rng.randi_range(8, 16)
	u.position = Vector3(cell.x + 0.5, y, cell.y + 0.5)
	u.rotation_degrees.y = giro
	parent.add_child(u, true)
	u.owner = owner_
	return u


## Câmera ortográfica fixa (30° de inclinação, 45° de giro), sol, luz de
## preenchimento e ambiente com AO, brilho e névoa leve.
func _camera_luz(root: Node3D, alvo: Vector3, tamanho: float) -> void:
	var cam := Camera3D.new()
	cam.name = "Camera"
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = tamanho
	cam.near = 1.0
	cam.far = 300.0
	cam.rotation_degrees = Vector3(-30, 45, 0)
	cam.position = alvo + cam.basis.z * 100.0
	cam.current = true
	root.add_child(cam)
	cam.owner = root
	var quad := MeshInstance3D.new()  # contorno escuro (pós-processo)
	quad.name = "Contorno"
	var qm := QuadMesh.new()
	qm.size = Vector2(2, 2)
	quad.mesh = qm
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/outline_post.gdshader")
	sm.render_priority = Material.RENDER_PRIORITY_MIN
	sm.set_shader_parameter("strength", 0.6)
	quad.material_override = sm
	quad.extra_cull_margin = 16384.0
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cam.add_child(quad)
	quad.owner = root

	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.32, 0.55, 0.8)
	sky_mat.sky_horizon_color = Color(0.85, 0.82, 0.72)
	sky_mat.ground_horizon_color = Color(0.5, 0.55, 0.45)
	sky_mat.ground_bottom_color = Color(0.2, 0.25, 0.18)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.06, 0.09, 0.1)
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.15
	env.ssao_enabled = true
	env.ssao_radius = 0.6
	env.ssao_intensity = 1.6
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	env.adjustment_contrast = 1.05
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	root.add_child(we)
	we.owner = root

	var sol := DirectionalLight3D.new()
	sol.name = "Sol"
	sol.rotation_degrees = Vector3(-48, -20, 0)
	sol.light_color = Color(1.0, 0.9, 0.74)
	sol.light_energy = 1.7
	sol.shadow_enabled = true
	sol.shadow_blur = 1.5
	sol.directional_shadow_max_distance = 200.0
	root.add_child(sol)
	sol.owner = root
	var ceu := DirectionalLight3D.new()
	ceu.name = "LuzDoCeu"  # preenchimento azulado do lado oposto, sem sombra
	ceu.rotation_degrees = Vector3(-35, 160, 0)
	ceu.light_color = Color(0.55, 0.7, 1.0)
	ceu.light_energy = 0.35
	root.add_child(ceu)
	ceu.owner = root


func _fogo(parent: Node3D, owner_: Node, pos: Vector3) -> void:
	var l := OmniLight3D.new()
	l.name = "Fogo"
	l.set_script(load("res://scripts/components/flicker_light.gd"))
	l.light_color = Color(1.0, 0.6, 0.25)
	l.omni_range = 4.0
	l.base_energy = 2.0
	l.position = pos
	parent.add_child(l, true)
	l.owner = owner_


func _salvar(root: Node, path: String) -> void:
	var ps := PackedScene.new()
	var err := ps.pack(root)
	if err == OK:
		err = ResourceSaver.save(ps, path)
	print("SALVO " if err == OK else "ERRO %d " % err, path)
	root.free()


# --- batalha 16x16 -------------------------------------------------------------

## Legenda do mapa da batalha (linha = z, coluna = x):
const LEGENDA := {
	"g": ["terreno2", "t01_grama"], "r": ["terreno2", "t02_terra_vermelha"],
	"a": ["terreno2", "t03_areia"], "w": ["terreno2", "t04_agua_rasa_pedras"],
	"W": ["terreno2", "t05_agua_escura"], "p": ["terreno2", "t06_pantano_raizes"],
	"H": ["terreno2", "t07_rocha_musgo_alta"], "R": ["terreno2", "t08_rampa_terra"],
	"E": ["terreno2", "t09_escada_terra"], "m": ["terreno2", "t10_lama_raizes"],
	"c": ["terreno2", "t11_cachoeira_rocha"], "F": ["terreno2", "t12_chao_floresta"],
	"L": ["terreno2", "t13_laje_rachada"], "l": ["terreno2", "t14_agua_vitorias_regias"],
	"f": ["floresta", "f11_chao_folhas"], "z": ["floresta", "f12_chao_raizes"],
	"u": ["pantano", "s04_lama_juncos"], "x": ["pantano", "s08_lama_fungos"],
	"d": ["pantano", "s09_deque_madeira"], "o": ["pantano", "s10_poca_agua"],
	"C": ["castelo", "c03_piso_entalhado_2x2"],  # 2x2: "." nas outras 3 casas
}
const MAPA_BATALHA := [
	"zfffFgggrrLLLLLL",
	"fFzffggggrLC.C.L",
	"ffFfFgHHgrL....L",
	"fzFfgHHHRrLLLLLL",
	"fFfggEggrrrLLLLL",
	"zffgggggrggggggg",
	"fFggaggrrggggggg",
	"ffgaacwwrwwagggg",
	"fgaawwWWrWwaggmg",
	"Fgawwlllrllwagpm",
	"fgaaggpprppaaupm",
	"ggggpmmprmppuoum",
	"gggpmmlpdpmlluom",
	"ggpmuoplWlpmmxum",
	"gpmmxuppWWpmuxmm",
	"gpmuuxmppWpmmmuu",
]


func _batalha() -> Node3D:
	var root := Node3D.new()
	root.name = "Batalha3D"
	root.set_script(load("res://scripts/batalha_3d.gd"))
	var terreno := _grupo(root, "Terreno", root)
	var cenario := _grupo(root, "Cenario", root)
	var pers := _grupo(root, "Personagens", root)
	var topo := {}
	for z in MAPA_BATALHA.size():
		var linha: String = MAPA_BATALHA[z]
		assert(linha.length() == 16, "linha %d" % z)
		for x in linha.length():
			var ch := linha[x]
			if ch == ".":
				continue
			var k: Array = LEGENDA[ch]
			if ch == "C":
				_peca(terreno, root, k[0], k[1], x + 1.0, z + 1.0)
				for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
					topo[Vector2i(x, z) + d] = PISOS[k[1]][0]
			else:
				var giro := 90.0 * _rng.randi_range(0, 3) if ch in "gfzFpmuxL" else 0.0
				_peca(terreno, root, k[0], k[1], x + 0.5, z + 0.5, 0.0, giro)
				topo[Vector2i(x, z)] = PISOS[k[1]][0]

	# Floresta (oeste)
	for o in [["f01_samauma", 1, 2, 1.8], ["f04_arvore_copa_densa", 3, 6, 1.6], ["f02_acaizeiros", 0, 9, 1.8],
			["f03_palmeira_leque", 4, 1, 1.8], ["f08_palmeira_jovem", 1, 12, 1.7], ["f05_pedra_musgo", 6, 4, 1.0],
			["f07_cogumelos_brilhantes", 1, 7, 1.0], ["f09_tronco_oco_caido", 3, 10, 1.2], ["f10_toco", 5, 0, 1.0],
			["f14_estatua_ruina", 7, 2, 1.4], ["f06_planta_folhas_largas", 0, 4, 1.2], ["f01_samauma", 0, 14, 1.6]]:
		_peca(cenario, root, "floresta", o[0], o[1] + 0.5, o[2] + 0.5, topo[Vector2i(o[1], o[2])], _rng.randf_range(0, 360), o[3])
	# Aldeia / castelo (nordeste)
	_peca(cenario, root, "castelo", "c07_oca_palha", 14.0, 2.0, PISOS["c03_piso_entalhado_2x2"][0], 0.0, 0.8)
	_peca(cenario, root, "castelo", "c08_torre_vigia", 15.5, 3.5, topo[Vector2i(15, 3)])
	_peca(cenario, root, "castelo", "c10_totem", 15.5, 0.5, topo[Vector2i(15, 0)], 270.0)
	_peca(cenario, root, "castelo", "c09_vaso_marajoara", 10.5, 0.5, topo[Vector2i(10, 0)], 0.0, 0.6)
	for b in [Vector2i(10, 3), Vector2i(13, 4)]:
		_peca(cenario, root, "castelo", "c13_braseiro", b.x + 0.5, b.y + 0.5, topo[b], 0.0, 0.6)
		_fogo(cenario, root, Vector3(b.x + 0.5, topo[b] + 1.1, b.y + 0.5))
	_peca(cenario, root, "castelo", "c12_muro_ruina_cipos", 6.5, 14.0, topo[Vector2i(6, 14)], 0.0, 0.8)
	# Pântano (sul)
	for o in [["s02_mangue", 13, 11, 1.4], ["s12_cabana_palafita", 15, 9, 1.3], ["s03_tronco_em_pe", 6, 11, 1.2],
			["s06_canoa", 8, 13, 0.8], ["s11_planta_folhas", 15, 13, 1.0], ["s02_mangue", 9, 15, 1.2],
			["s07_potes_barro", 15, 10, 0.8]]:
		_peca(cenario, root, "pantano", o[0], o[1] + 0.5, o[2] + 0.5, topo[Vector2i(o[1], o[2])], _rng.randf_range(0, 360), o[3])
	_peca(cenario, root, "pantano", "s13_toco_musgo_juncos", 4.0, 15.0, topo[Vector2i(3, 14)])
	# Pedras cinza do kit de terreno
	_peca(cenario, root, "terreno", "p28_pedra_alta_a", 13.5, 6.5, topo[Vector2i(13, 6)], 30.0, 0.7)
	_peca(cenario, root, "terreno", "p24_ruina_pilar", 12.5, 7.5, topo[Vector2i(12, 7)], 0.0, 0.6)

	# 8 aliados (os 5 bichos jogáveis + reforços) olham para o leste;
	# 8 inimigos (7 minions + o Mapinguari) olham para o oeste.
	var aliados := [["buffalo", "Búfalo", "guerreiro", 6, 5, 11], ["onca", "Onça", "assassino", 7, 6, 17],
		["coruja", "Coruja", "mago", 4, 5, 12], ["boto", "Boto", "clerigo", 5, 6, 10],
		["guara", "Guará", "ranger", 3, 4, 15], ["buffalo", "Búfalo II", "guerreiro", 4, 7, 9],
		["onca", "Onça II", "assassino", 2, 6, 16], ["guara", "Guará II", "ranger", 7, 4, 14]]
	for a in aliados:
		var c := Vector2i(a[3], a[4])
		_unidade(pers, root, a[0], a[1], a[2], false, c, topo[c], 90.0, a[5])
	var inimigos := [["minions/acaizeiro", "Açaizeiro", 12, 9, 10], ["minions/aninga", "Aninga", 13, 10, 12],
		["minions/bromelia", "Bromélia", 10, 11, 13], ["minions/carnivora", "Carnívora", 14, 11, 8],
		["minions/cogumelo", "Cogumelo", 10, 12, 15], ["minions/golem_toco", "Golem de Toco", 13, 5, 6],
		["minions/vitoria_regia", "Vitória-Régia", 12, 13, 11], ["bosses/mapinguari", "Mapinguari", 12, 1, 7]]
	for e in inimigos:
		var c := Vector2i(e[2], e[3])
		_unidade(pers, root, e[0], e[1], "inimigo", true, c, topo[c], -90.0, e[4], 1.2 if e[1] == "Mapinguari" else 1.0)
	root.selected_unit = NodePath("Personagens/Onça")

	_camera_luz(root, Vector3(8, 0.3, 8), 13.5)
	return root


# --- mapa-múndi ------------------------------------------------------------------

const MW := 30
const MH := 22


## Região de cada casa do mapa: floresta (oeste), pântano (sul), aldeia (nordeste),
## montanhas (norte), rio (do norte ao pântano), estrada ligando os locais.
func _regiao(x: int, z: int) -> String:
	var rio_x := 15 + int(round(sin(z * 0.45) * 1.5))
	if z >= 2 and z <= 15 and (x == rio_x or (z >= 12 and x == rio_x + 1)):
		return "rio"
	if _na_estrada(x, z):
		return "estrada"
	if z <= 1:
		return "montanha"
	if x <= 10 and z <= 17:
		return "floresta"
	if z >= 14:
		return "pantano"
	if x >= 20 and z <= 9:
		return "aldeia"
	return "campo"


func _na_estrada(x: int, z: int) -> bool:
	# Floresta (5,10) -> leste até x=22 na linha 10 -> norte até a aldeia (22,5);
	# desvio ao sul na coluna 20 até o pântano (20,17).
	if z == 10 and x >= 5 and x <= 22:
		return true
	if x == 22 and z >= 5 and z <= 10:
		return true
	if x == 20 and z >= 10 and z <= 17:
		return true
	return false


func _mapa() -> Node3D:
	var root := Node3D.new()
	root.name = "MapaMundi3D"
	root.set_script(load("res://scripts/mapa_mundi_3d.gd"))
	var terreno := _grupo(root, "Terreno", root)
	var cenario := _grupo(root, "Cenario", root)
	var locais := _grupo(root, "Locais", root)
	var topo := {}
	for z in MH:
		for x in MW:
			var reg := _regiao(x, z)
			var k := ["terreno2", "t01_grama"]
			var r := _rng.randf()
			match reg:
				"rio":
					k = ["terreno2", "t04_agua_rasa_pedras" if r < 0.7 else "t14_agua_vitorias_regias"]
					if z == 2:
						k = ["terreno2", "t11_cachoeira_rocha"]
				"estrada":
					k = ["terreno2", "t02_terra_vermelha"]
				"montanha":
					k = ["terreno2", "t07_rocha_musgo_alta"]
				"floresta":
					k = ["floresta", "f11_chao_folhas"] if r < 0.4 else (["floresta", "f12_chao_raizes"] if r < 0.7 else ["terreno2", "t12_chao_floresta"])
				"pantano":
					k = ["terreno2", ["t06_pantano_raizes", "t10_lama_raizes", "t14_agua_vitorias_regias", "t04_agua_rasa_pedras"][int(r * 4)]]
				"aldeia":
					k = ["terreno2", "t13_laje_rachada" if r < 0.7 else "t01_grama"]
				"campo":
					k = ["terreno2", "t01_grama" if r < 0.75 else ("t03_areia" if r < 0.85 else "t02_terra_vermelha")]
			var giro := 90.0 * _rng.randi_range(0, 3) if reg in ["floresta", "campo", "pantano", "aldeia"] else 0.0
			_peca(terreno, root, k[0], k[1], x + 0.5, z + 0.5, 0.0, giro)
			topo[Vector2i(x, z)] = PISOS[k[1]][0]
			# Vegetação e enfeites
			var livre := not _na_estrada(x, z) and Vector2(x - 5, z - 10).length() > 2.0 \
				and Vector2(x - 22, z - 5).length() > 2.5 and Vector2(x - 20, z - 17).length() > 2.0
			var s := _rng.randf()
			if not livre:
				continue
			var y: float = topo[Vector2i(x, z)]
			if reg == "floresta" and s < 0.55:
				var arv: String = ["f01_samauma", "f02_acaizeiros", "f03_palmeira_leque", "f04_arvore_copa_densa", "f08_palmeira_jovem", "f06_planta_folhas_largas"][_rng.randi_range(0, 5)]
				_peca(cenario, root, "floresta", arv, x + 0.5, z + 0.5, y, _rng.randf_range(0, 360), _rng.randf_range(1.2, 1.8))
			elif reg == "pantano" and s < 0.2 and k[1] != "t14_agua_vitorias_regias":
				var pp: String = ["s02_mangue", "s02_mangue", "s11_planta_folhas", "s05_tronco_caido"][_rng.randi_range(0, 3)]
				_peca(cenario, root, "pantano", pp, x + 0.5, z + 0.5, y, _rng.randf_range(0, 360), _rng.randf_range(1.0, 1.4))
			elif reg == "campo" and s < 0.07:
				var cp: String = ["f05_pedra_musgo", "f10_toco", "f08_palmeira_jovem"][_rng.randi_range(0, 2)]
				_peca(cenario, root, "floresta", cp, x + 0.5, z + 0.5, y, _rng.randf_range(0, 360), 1.2)
			elif reg == "montanha" and s < 0.35:
				var mp: String = ["p28_pedra_alta_a", "p29_pedra_alta_b", "p26_penhasco_a"][_rng.randi_range(0, 2)]
				_peca(cenario, root, "terreno", mp, x + 0.5, z + 0.5, y, 90.0 * _rng.randi_range(0, 3), 0.9)

	# Ponte sobre o rio na estrada (linha 10)
	var rio10 := 15 + int(round(sin(10 * 0.45) * 1.5))
	_peca(cenario, root, "castelo", "c05_ponte_corda", rio10 + 0.5, 10.5, 0.15, 0.0, 0.9)
	# Aldeia: oca, torre, portão, muros, totem, braseiros
	_peca(cenario, root, "castelo", "c03_piso_entalhado_2x2", 22.0, 5.0, 0.13)
	_peca(cenario, root, "castelo", "c07_oca_palha", 25.0, 4.0, topo[Vector2i(24, 3)], 0.0, 0.9)
	_peca(cenario, root, "castelo", "c08_torre_vigia", 27.5, 7.5, topo[Vector2i(27, 7)])
	_peca(cenario, root, "castelo", "c11_portao_entalhado", 20.5, 6.0, topo[Vector2i(20, 6)], 0.0, 0.8)
	_peca(cenario, root, "castelo", "c02_palicada_canto", 27.5, 2.5, topo[Vector2i(27, 2)], 0.0, 0.8)
	_peca(cenario, root, "castelo", "c04_muro_canto", 24.0, 8.0, topo[Vector2i(24, 7)], 90.0, 0.8)
	_peca(cenario, root, "castelo", "c10_totem", 23.5, 6.5, topo[Vector2i(23, 6)], 0.0, 0.7)
	_peca(cenario, root, "castelo", "c13_braseiro", 21.5, 3.5, topo[Vector2i(21, 3)], 0.0, 0.6)
	_fogo(cenario, root, Vector3(21.5, topo[Vector2i(21, 3)] + 1.1, 3.5))
	# Pântano: cabana e canoa; Floresta: samaúma gigante e estátua
	_peca(cenario, root, "pantano", "s12_cabana_palafita", 22.5, 18.5, topo[Vector2i(22, 18)], 200.0, 1.5)
	_peca(cenario, root, "pantano", "s06_canoa", 17.5, 15.5, topo[Vector2i(17, 15)], 30.0)
	_peca(cenario, root, "floresta", "f01_samauma", 3.5, 8.5, topo[Vector2i(3, 8)], 0.0, 2.6)
	_peca(cenario, root, "floresta", "f14_estatua_ruina", 6.5, 12.5, topo[Vector2i(6, 12)], 0.0, 1.5)

	# Locais: placa com nome + qual batalha abre (meta "batalha", editável no Inspector)
	for l in [["Floresta_da_Samaúma", Vector3(5.5, 0.3, 10.5)], ["Aldeia_de_Pedra", Vector3(22.0, 0.3, 5.0)],
			["Pântano_das_Vitórias-Régias", Vector3(20.5, 0.3, 17.5)]]:
		var m := Marker3D.new()
		m.name = l[0]
		m.position = l[1]
		m.set_meta("batalha", BATALHA)
		locais.add_child(m)
		m.owner = root
		var t := Label3D.new()
		t.name = "Nome"
		t.text = String(l[0]).replace("_", " ")
		t.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		t.no_depth_test = true
		t.fixed_size = true
		t.pixel_size = 0.0012
		t.font_size = 30
		t.outline_size = 10
		t.modulate = Color(1, 0.93, 0.7)
		t.position.y = 2.2
		m.add_child(t)
		t.owner = root

	var g := _unidade(root, root, "onca", "Grupo", "assassino", false, Vector2i(7, 10), topo[Vector2i(7, 10)], 90.0, 17, 1.4)
	root.grupo = NodePath(g.name)
	_camera_luz(root, Vector3(15, 0.3, 11), 21.0)
	return root
