extends SceneTree
## Confere os dados de scripts/combate/ e (opcional) fotografa cada efeito.
##   godot --headless --path . -s tools/testar_combate.gd
##   godot --path . -s tools/testar_combate.gd -- --fotos=C:/pasta
## Imprime COMBATE_OK ou a lista de problemas.

const D := preload("res://scripts/campanha/dados_ato1.gd")
const R := preload("res://scripts/campanha/regras.gd")

var _erros := PackedStringArray()


func _initialize() -> void:
	_conferir()
	var fotos := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fotos="):
			fotos = a.trim_prefix("--fotos=")
	if fotos != "":
		await _fotografar(fotos)
	quit(0 if _erros.is_empty() else 1)


func _conferir() -> void:
	var todos := {}
	for id in D.HEROIS:
		todos[id] = D.HEROIS[id]["classe"]
	for id in D.ESPECIES:
		todos[id] = D.ESPECIES[id]["classe"]
	for esp in todos:
		var cls: String = todos[esp]
		var regra: Dictionary = R.classe(cls)
		if not ResourceLoader.exists(Combate.PASTA + "ataques/" + esp + ".tres"):
			_erros.append("%s: falta ataques/%s.tres" % [esp, esp])
			continue
		var a := Combate.info(esp, "ataque")
		if regra["mp"] and regra["tipo"] == "magia" and a["mp"] <= 0:
			_erros.append("%s (%s): magia sem custo de MP" % [esp, cls])
		if not regra["mp"] and a["mp"] > 0:
			_erros.append("%s (%s): classe sem MP gastando MP" % [esp, cls])
		if a["alc"] != regra["alc"]:
			_erros.append("%s: alcance %d, classe diz %d" % [esp, a["alc"], regra["alc"]])
		if cls in ["mago", "ranger", "clerigo"] and a["alc"] < 3:
			_erros.append("%s (%s): deveria atacar de longe" % [esp, cls])
		if cls == "ranger" and a["visual"] != "flecha":
			_erros.append("%s: ranger sem flecha" % esp)
		if cls == "clerigo" and a["visual"] != "luz":
			_erros.append("%s: clérigo sem luz" % esp)
		if a["mp"] > 0 and Combate.info(esp, "ataque", 0)["id"] != "ataque":
			_erros.append("%s: fallback sem MP perdeu o id" % esp)
		for h in Combate.acoes(esp):
			if Combate.info(esp, h).is_empty():
				_erros.append("%s: habilidade %s não existe" % [esp, h])
		# o que a batalha atual usa em dados_ato1 deve bater com o kit novo
		var fonte: Dictionary = D.HEROIS.get(esp, D.ESPECIES.get(esp, {}))
		if fonte.has("habs") and fonte["habs"] != Combate.KIT.get(esp, []):
			_erros.append("%s: habs em dados_ato1 %s ≠ Combate.KIT %s" % [esp, fonte["habs"], Combate.KIT.get(esp, [])])
		if fonte.has("atq") and fonte["atq"][0] != a["nome"]:
			_erros.append("%s: nome do ataque '%s' ≠ '%s'" % [esp, fonte["atq"][0], a["nome"]])
	# as habilidades antigas de Regras devem ter os mesmos números
	for id in R.HABILIDADES:
		var velho: Dictionary = R.HABILIDADES[id]
		var novo := Combate.info("", id)
		for k in ["tipo", "alc", "mp", "recarga", "mult", "poder", "raio", "bonus", "turnos"]:
			if velho.has(k) and str(velho[k]) != str(novo[k]):
				_erros.append("%s.%s: Regras %s ≠ Combate %s" % [id, k, velho[k], novo[k]])
	# dano das habilidades cresce com nível e atributo; ataque corpo a corpo/flecha não
	var fraco := {"attrs": {"forca": 10}, "nivel": 1, "classe": "guerreiro"}
	var forte := {"attrs": {"forca": 16}, "nivel": 4, "classe": "guerreiro"}
	var g1: float = Combate.info("bufalo", "golpe", 0, fraco)["mult"]
	var g2: float = Combate.info("bufalo", "golpe", 0, forte)["mult"]
	if not is_equal_approx(g1, Combate.hab("golpe").mult) or g2 <= g1:
		_erros.append("escala do Golpe Pesado: nível 1 %.2f, nível 4 %.2f" % [g1, g2])
	if Combate.info("bufalo", "ataque", 0, forte)["mult"] != 1.0:
		_erros.append("ataque corpo a corpo não deveria escalar aqui (já escala em Regras.dano)")
	var mago := {"attrs": {"inteligencia": 16}, "nivel": 5, "classe": "mago"}
	if Combate.info("naga", "ataque", 9, mago)["mult"] <= 1.0:
		_erros.append("magia básica do mago deveria escalar")
	print("ESCALA golpe nv1/FOR10 %.2f · nv4/FOR16 %.2f" % [g1, g2])
	if _erros.is_empty():
		print("COMBATE_OK %d espécies" % todos.size())
	else:
		for e in _erros:
			print("COMBATE_ERRO ", e)


## Monta um palco com lançador e alvo e fotografa cada visual no meio do caminho e no impacto.
func _fotografar(pasta: String) -> void:
	DirAccess.make_dir_recursive_absolute(pasta)
	await process_frame  # em _initialize a árvore ainda não está pronta
	var palco := Node3D.new()
	root.add_child(palco)
	var chao := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(10, 10)
	chao.mesh = pm
	var mc := StandardMaterial3D.new()
	mc.albedo_color = Color(0.22, 0.3, 0.18)
	chao.material_override = mc
	palco.add_child(chao)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.06, 0.08, 0.1)
	env.environment.ambient_light_color = Color(0.4, 0.4, 0.45)
	env.environment.glow_enabled = true
	palco.add_child(env)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50, 30, 0)
	sol.light_energy = 0.4
	palco.add_child(sol)
	var cam := Camera3D.new()
	palco.add_child(cam)
	cam.position = Vector3(0, 3.2, 4.2)
	cam.look_at(Vector3(0, 0.4, 0))
	var de := Vector3(-1.5, 0.6, 0)
	var para := Vector3(1.5, 0.6, 0)
	for p in [de, para]:
		var boneco := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = 0.2
		cm.height = 1.0
		boneco.mesh = cm
		palco.add_child(boneco)
		boneco.position = Vector3(p.x, 0.5, p.z)
	var casos := {
		"flecha_guara": "ataques/guara", "penas_murucututu": "ataques/murucututu",
		"esporos_cogumelo": "ataques/cogumelo", "bote_naga": "ataques/naga",
		"fumaca_cururu": "ataques/cururu", "luz_boto": "ataques/boto",
		"luz_tartaruga_amazonia": "ataques/tartaruga_amazonia",
		"cura_forte": "cura_forte", "mare_curativa": "mare_curativa",
		"casco_firme": "casco_firme", "golpe_bufalo": "golpe",
	}
	for nome in casos:
		var h: Habilidade = load(Combate.PASTA + casos[nome] + ".tres")
		var i := h.como_dict()
		var alvo := para
		if i["tipo"] == "defesa":
			alvo = de
		VfxCombate.lancar(palco, i, de, alvo)
		await create_timer(0.22).timeout
		await _foto(pasta, nome + "_a")
		await create_timer(0.5).timeout
		VfxCombate.acertar(palco, i, alvo if i["visual"] not in ["cura", "mare", "escudo"] else Vector3(alvo.x, 0, alvo.z))
		if i["visual"] == "mare":
			VfxCombate.onda(palco, Vector3(alvo.x, 0, alvo.z), i["cor"], i["raio"])
		await create_timer(0.3).timeout
		await _foto(pasta, nome + "_b")
		await create_timer(1.8).timeout
	print("FOTOS ", pasta)


func _foto(pasta: String, nome: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(pasta.path_join(nome + ".png"))
