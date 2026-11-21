class_name Clima
extends RefCounted
## Clima da batalha (pedido do Diorge, 2026-11-21): a noite e a chuva mudam o
## poder dos animais, conforme o hábitat e o costume de cada um.
## Tudo do clima fica AQUI: sorteio, nomes, efeitos por espécie e o visual.
##
## Cada batalha sorteia o período (dia ou noite) e o tempo (seco ou chuva), então
## sai "dia", "noite", "chuva" (dia chuvoso) ou "noite_chuva".
## Para fixar o clima de uma batalha: campo "clima" em DadosAto1.BATALHAS
## (ex.: "clima": "noite"). Para testar: godot ... -- --clima=noite_chuva

const CHANCE_NOITE := 0.3
const CHANCE_CHUVA := 0.3

const NOMES := {"dia": "Dia", "noite": "Noite", "chuva": "Chuva", "noite_chuva": "Noite com chuva"}

## Efeitos por espécie e por condição ("noite" ou "chuva"):
##   "dano": multiplicador do dano que o animal causa (1.2 = +20%)
##   "arm":  pontos de armadura a mais (cada ponto segura 12% do dano, ver Regras)
##   "mov":  casas de movimento a mais (ou a menos)
## Na noite com chuva os dois valem juntos. Espécie que não está aqui não muda.
const AFINIDADE := {
	# heróis
	"bufalo": {"chuva": {"dano": 1.1}},                          # aquático, gosta de lama e chuva
	"tartaruga": {"chuva": {"arm": 1, "mov": -1}},               # casco firme, mas atola
	"tartaruga_paladina": {"chuva": {"arm": 1, "mov": -1}},
	# inimigos genéricos (e heróis de outros atos)
	"murucututu": {"noite": {"dano": 1.25}, "chuva": {"dano": 0.9}},  # coruja: caça à noite, pena molhada pesa
	"guara": {"noite": {"dano": 0.85}},                          # ave do dia
	"boto": {"chuva": {"dano": 1.2, "arm": 1}, "noite": {"dano": 1.1}},  # rio cheio; a lenda sai à noite
	"onca": {"noite": {"dano": 1.2, "mov": 1}},                  # caçadora noturna
	# minions de flora: a chuva os alimenta
	"acaizeiro": {"chuva": {"dano": 1.1}},
	"vitoria_regia": {"chuva": {"dano": 1.1, "arm": 1}},
	"carnivora": {"chuva": {"dano": 1.1}},
	"cogumelo": {"chuva": {"dano": 1.1}, "noite": {"dano": 1.15}},
	"golem_toco": {"chuva": {"arm": 1}},
	"bromelia": {"chuva": {"dano": 1.1}},
	"aninga": {"chuva": {"dano": 1.1}},
	"buriti": {"chuva": {"dano": 1.1}},
	# anfíbios: chuva; os noturnos também à noite
	"sapo_dardo": {"chuva": {"dano": 1.15}},
	"cururu": {"chuva": {"dano": 1.15}, "noite": {"dano": 1.1}},
	"perereca": {"chuva": {"dano": 1.15}, "noite": {"dano": 1.1}},
	# répteis: os de sol perdem força no frio; jacarés e cobras caçam à noite
	"tartaruga_amazonia": {"chuva": {"arm": 1}},
	"iguana": {"chuva": {"dano": 0.85}, "noite": {"dano": 0.85, "mov": -1}},
	"teiu": {"chuva": {"dano": 0.9}, "noite": {"dano": 0.85}},
	"naga": {"chuva": {"dano": 1.1}},
	"coral": {"noite": {"dano": 1.1}},
	"cobra_cavaleira": {"noite": {"dano": 1.1}},
	"jacare_acu": {"chuva": {"dano": 1.2}, "noite": {"dano": 1.1}},
	"jacaretinga": {"chuva": {"dano": 1.15}, "noite": {"dano": 1.15}},
	# chefes (o Mapinguari anda de dia na lenda: não muda)
	"curupira": {"noite": {"dano": 1.2}},
	"iara": {"chuva": {"dano": 1.2}},
	"matinta": {"noite": {"dano": 1.25}},
	"mae_da_mata": {"chuva": {"dano": 1.15}},
	"boitata": {"noite": {"dano": 1.2}, "chuva": {"dano": 0.8}},  # fogo: forte no escuro, fraco na chuva
	"anhanga": {"noite": {"dano": 1.15}},
	"cobra_grande": {"chuva": {"dano": 1.2, "arm": 1}},
}


## Clima desta batalha: argumento --clima=, depois o campo "clima" da batalha, depois sorteio.
static func sortear(dados_batalha: Dictionary, rng: RandomNumberGenerator) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--clima=") and NOMES.has(a.substr(8)):
			return a.substr(8)
	var fixo: String = dados_batalha.get("clima", "")
	if NOMES.has(fixo):
		return fixo
	var noite := rng.randf() < CHANCE_NOITE
	var chuva := rng.randf() < CHANCE_CHUVA
	if noite and chuva:
		return "noite_chuva"
	return "noite" if noite else ("chuva" if chuva else "dia")


static func tem(clima: String, condicao: String) -> bool:
	return condicao in clima.split("_")


static func nome(clima: String) -> String:
	return NOMES.get(clima, "Dia")


## Efeito somado da noite e da chuva para a espécie: {"dano", "arm", "mov"}.
static func efeito(especie: String, clima: String) -> Dictionary:
	var r := {"dano": 1.0, "arm": 0, "mov": 0}
	var af: Dictionary = AFINIDADE.get(especie, {})
	for cond in ["noite", "chuva"]:
		if tem(clima, cond) and af.has(cond):
			r["dano"] *= af[cond].get("dano", 1.0)
			r["arm"] += af[cond].get("arm", 0)
			r["mov"] += af[cond].get("mov", 0)
	return r


## Texto curto para o HUD, ex.: "Chuva: dano +20%, armadura +1". Vazio se nada muda.
static func texto(especie: String, clima: String) -> String:
	var e := efeito(especie, clima)
	var p := PackedStringArray()
	var pct := roundi((e["dano"] - 1.0) * 100.0)
	if pct != 0:
		p.append("dano %+d%%" % pct)
	if e["arm"] != 0:
		p.append("armadura %+d" % e["arm"])
	if e["mov"] != 0:
		p.append("mov %+d" % e["mov"])
	if p.is_empty():
		return ""
	return "%s: %s" % [nome(clima), ", ".join(p)]


# --- visual ---------------------------------------------------------------------------------

## Escurece/esfria a luz da cena (nós "Sol", "LuzDoCeu", "WorldEnvironment") e
## põe chuva sobre o mapa. `centro`/`tamanho`: retângulo do mapa no chão (x, z).
static func aplicar_visual(cena: Node3D, clima: String, centro: Vector3, tamanho: Vector2) -> void:
	var noite := tem(clima, "noite")
	var chuva := tem(clima, "chuva")
	if not noite and not chuva:
		return
	var sol := cena.get_node_or_null("Sol") as DirectionalLight3D
	var ceu := cena.get_node_or_null("LuzDoCeu") as DirectionalLight3D
	var we := cena.get_node_or_null("WorldEnvironment") as WorldEnvironment
	var env: Environment = we.environment.duplicate() if we and we.environment else null
	if noite:
		if sol:  # vira luar
			sol.light_energy *= 0.35
			sol.light_color = Color(0.6, 0.7, 1.0)
		if ceu:
			ceu.light_energy *= 0.6
		if env:
			env.ambient_light_energy *= 0.45
			env.background_color = Color(0.03, 0.05, 0.1)
	if chuva:
		if sol:
			sol.light_energy *= 0.6
			sol.light_color = sol.light_color.lerp(Color(0.75, 0.8, 0.85), 0.5)
			sol.shadow_opacity = 0.6
		if env:
			env.background_color = env.background_color.lerp(Color(0.35, 0.4, 0.45), 0.0 if noite else 0.6)
			env.fog_enabled = true
			env.fog_light_color = Color(0.35, 0.4, 0.45) if not noite else Color(0.08, 0.1, 0.15)
			env.fog_density = 0.012
		_chuva(cena, centro, tamanho, noite)
	if we and env:
		we.environment = env


## Gotas: partículas finas caindo sobre o retângulo do mapa.
static func _chuva(cena: Node3D, centro: Vector3, tamanho: Vector2, noite: bool) -> void:
	var p := GPUParticles3D.new()
	p.name = "Chuva"
	p.amount = 1800
	p.lifetime = 0.9
	p.preprocess = 1.0
	p.position = centro + Vector3(0, 9, 0)
	p.visibility_aabb = AABB(Vector3(-tamanho.x, -14, -tamanho.y), Vector3(tamanho.x * 2, 20, tamanho.y * 2))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(tamanho.x * 0.5 + 2, 0.5, tamanho.y * 0.5 + 2)
	pm.direction = Vector3(0.15, -1, 0.1)
	pm.spread = 2.0
	pm.initial_velocity_min = 13.0
	pm.initial_velocity_max = 16.0
	pm.gravity = Vector3(0, -9.8, 0)
	p.process_material = pm
	var gota := QuadMesh.new()
	gota.size = Vector2(0.015, 0.35)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.billboard_keep_scale = true
	mat.albedo_color = Color(0.7, 0.8, 1.0, 0.35 if noite else 0.45)
	gota.material = mat
	p.draw_pass_1 = gota
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cena.add_child(p)


## À noite cada unidade leva uma luz fraca (tocha/brilho) para o jogador enxergar.
static func luz_da_unidade(u: Node3D, inimigo: bool) -> void:
	var l := OmniLight3D.new()
	l.name = "LuzNoite"
	l.light_color = Color(1.0, 0.6, 0.35) if inimigo else Color(1.0, 0.85, 0.55)
	l.light_energy = 0.9
	l.omni_range = 2.6
	l.position = Vector3(0, 1.2, 0)
	l.shadow_enabled = false
	u.add_child(l)
