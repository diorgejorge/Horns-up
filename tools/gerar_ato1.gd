extends SceneTree
## Gera as cenas do Ato I (O Despertar do Mapinguari) a partir das peças
## existentes em scenes/3d/pecas/ — nenhum asset novo:
##   scenes/3d/ato1/mapa_arua.tscn          mapa-múndi do Arquipélago de Aruã
##   scenes/3d/ato1/batalha_01..12.tscn     as 12 batalhas (16x16)
## Como o gerador antigo, NÃO sobrescreve cenas que já existem (edições no editor
## ficam salvas). Refazer uma cena: apague o arquivo e rode de novo.
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tools/gerar_ato1.gd
## Opções (depois de --): --so=3 (só a batalha 3), --so=mapa, --forcar (refaz TUDO
## do Ato I, apagando edições nessas cenas).
## Antes de salvar, confere cada batalha: casas de início andáveis e pelo menos
## duas rotas diferentes entre o grupo e os inimigos (regras de batalha_3d.gd).

const PECAS := "res://scenes/3d/pecas/%s/%s.tscn"
const SAIDA := "res://scenes/3d/ato1/"
const SALTO := 0.45     # igual a batalha_3d.gd
const NIVEL := 0.3      # altura de um degrau de plataforma (camada "alturas")

## Pisos: caractere -> [kit, peça]. Topo e "andável" vêm da cena da peça.
const PISO := {
	"g": ["terreno2", "t01_grama"], "r": ["terreno2", "t02_terra_vermelha"],
	"a": ["terreno2", "t03_areia"], "w": ["terreno2", "t04_agua_rasa_pedras"],
	"P": ["terreno2", "t07_rocha_musgo_alta"], "E": ["terreno2", "t09_escada_terra"],
	"F": ["terreno2", "t12_chao_floresta"], "L": ["terreno2", "t13_laje_rachada"],
	"y": ["floresta", "f11_chao_folhas"], "Y": ["floresta", "f12_chao_raizes"],
	"u": ["pantano", "s04_lama_juncos"],
	"m": ["terreno3", "m01_raizes_musgo"], "d": ["terreno3", "m02_deque_tabuas"],
	"c": ["terreno3", "m03_lama_cupins"], "V": ["terreno3", "m04_agua_vitorias_regias"],
	"l": ["terreno3", "m05_lama_furos"], "e": ["terreno3", "m06_terra_vermelha"],
	"D": ["terreno3", "m07_deque_estacas"], "x": ["terreno3", "m08_raizes_terra"],
	"b": ["terreno3", "m09_brejo_capim"], "p": ["terreno3", "m10_capim_pedras"],
	"f": ["terreno3", "m11_capim_ouricos"], "n": ["terreno3", "m13_areia"],
	"h": ["terreno3", "m14_pedra_musgo_alta"], "R": ["terreno3", "m15_raiz_tronco"],
	"S": ["terreno3", "m16_raizes_grama"], "o": ["terreno3", "m17_agua_rasa_pedras"],
	"s": ["terreno3", "m18_pedras_escuras"], "N": ["terreno3", "m19_areia_margem"],
	"q": ["terreno3", "m20_folhas_secas_pedra"], "T": ["terreno3", "m21_tronco_caido_grama"],
	"j": ["terreno3", "m23_riacho_pedras"], "W": ["terreno3", "m24_agua_funda"],
	"z": ["terreno3", "m25_terra_rachada"], "k": ["terreno3", "m27_terra_marrom"],
	"M": ["terreno3", "m29_piso_marajoara"], "K": ["terreno3", "m30_corredeira_pedras"],
	"1": ["pantano", "s14_monte_lama"], "0": ["pantano", "s07_potes_barro"],
}
## Pisos que o roteiro manda bloquear mesmo que a peça diga "andável":
## tronco caído (m21) e cupinzeiro (s14). Só muda a instância, não a peça.
const BLOQUEAR := ["T", "1"]
const GIRO_LIVRE := "gmlbpfFyYkezuqsnLcNM"

## Objetos: caractere -> [kit, peça, piso embaixo, escala, fogo?]. Bloqueiam a casa.
const OBJ := {
	"A": ["floresta", "f01_samauma", "m", 1.9], "B": ["floresta", "f02_acaizeiros", "F", 1.6],
	"C": ["floresta", "f03_palmeira_leque", "g", 1.6], "G": ["floresta", "f04_arvore_copa_densa", "F", 1.5],
	"H": ["floresta", "f06_planta_folhas_largas", "F", 1.2], "J": ["floresta", "f07_cogumelos_brilhantes", "m", 1.0],
	"O": ["floresta", "f09_tronco_oco_caido", "F", 1.0], "Q": ["floresta", "f10_toco", "F", 1.0],
	"U": ["floresta", "f05_pedra_musgo", "s", 1.0],
	"Z": ["pantano", "s02_mangue", "l", 1.3], "X": ["pantano", "s12_cabana_palafita", "b", 1.2],
	"I": ["pantano", "s11_planta_folhas", "u", 1.0], "6": ["pantano", "s06_canoa", "N", 0.9],
	"2": ["props", "e03_cestos_peixe", "D", 1.0], "3": ["props", "e04_suporte_remos", "D", 1.0],
	"4": ["props", "e02_secador_rede", "n", 1.0], "5": ["props", "v25_cobertura_palha", "k", 1.0],
	"7": ["props", "v01_rede_dormir", "k", 1.0], "8": ["props", "v20_banca_coberta", "k", 1.0],
	"9": ["props", "v18_cerca", "p", 1.0], "v": ["props", "v04_cesto_acai", "k", 1.0],
	"t": ["props", "v16_caixa_frutas", "k", 1.0],
	"!": ["castelo", "c09_vaso_marajoara", "M", 0.55], "#": ["castelo", "c10_totem", "M", 0.7],
	"$": ["castelo", "c13_braseiro", "M", 0.55, true], "%": ["props", "r04_altar_cristal", "M", 1.0],
	"&": ["props", "p3_03_pedra_runica", "M", 0.9], "*": ["props", "u01_totem_penas", "M", 0.9],
	"+": ["props", "p3_02_tambor", "M", 0.9], "?": ["props", "r02_urna_ouro", "M", 0.8],
}

## Os 12 mapas (linha = z de norte a sul, coluna = x de oeste a leste).
## "alturas": dígito por casa = degraus de 0.3 (plataformas); "extras": peças
## de mais de uma casa [kit, peça, centro x, centro z, giro, escala].
const MAPAS := {
	1: {"casas": [
		"WWWWWWWooWWWWWWW", "WWWW6NNooNNWWWWW", "WWNNNnnrrnnNN6WW", "WDnpppprrppffndW",
		"XDppCpprrppfppdW", "WDppppgrrgpp9pdW", "WDp9pgggrggpppdW", "XDpppggrrgggCpdW",
		"WDffpgrrggppppdW", "WDfCpgrggpp9ppdW", "W2kkkkrrkkkkkkDW", "WDk5kkrrkk8kkkD3",
		"WDkkkkrrkkkkvkDW", "WDk7kkkkkktkkkDW", "WWDkkkkkkkkk5DWW", "WWWDDDDDDDDDDWWW"],
		"extras": [["castelo", "c07_oca_palha", 9.0, 13.0, 0.0, 0.8]]},
	2: {"casas": [
		"WWWNNnnnrrnzhhhh", "WWNNnnpprrpzzhhh", "WWN6npprrpppzzhU", "WooNnprrppCppzzh",
		"WooNpprpppppfpzz", "WWNnprrp999pffpz", "WWNpprpppppppfpp", "WNNprrpxxpCpppgg",
		"WNpprppxxppprrgg", "WNpCrpppprrrrggg", "WNpprrrrrrrppgCg", "WNnpppppppppgggg",
		"WWNnpffpppCppggg", "WWNNnpffppppgggg", "WWWNnnpppkkkkggg", "WWWWNnkkkk5kkkgg"]},
	3: {"casas": [
		"ZZllbbbbbbbbllZZ", "ZlbbubbIbbubbblZ", "lbbbbbcbbbbbcbbl", "WlbbIbbbbbbbbIlW",
		"WWlbbblllbbbllWW", "WWWdWWVooVWWdWWW", "WVWdWWooooWWdVWW", "WWWdVWWooWWVdWWW",
		"WWldlWWooWWldlWW", "WlbbblubbulbbblW", "ZlbbbbbbbbbbbblZ", "Zlb1bbbbbbbb1blZ",
		"llbbbbbbbbbbbbll", "ZlbbIbbbbbbIbblZ", "ZZllbb6NNbbbllZZ", "WZZllNNWWNlllZZW"]},
	4: {"casas": [
		"ZlbbbddddbbbblZZ", "lbbIbdWWdbIbbblZ", "WWdWWdWWdWWWdWWW", "WWdWVdVWdWVWdWWW",
		"lbbbbbllbbbbbblW", "lbZbbbbbb1bbIblW", "WWWWdWWWWWdWWWdW", "WVWWdWVWVWdWWVdW",
		"WWWWdWWWWWdWWWdW", "lbbbbbluulbbbbbl", "lbIbbbbbbbb1bbbl", "WWdWWWWooWWWWdWW",
		"WWdWVWWooWVWWdWW", "lbbbblbbbbblbbbl", "Zlbb6bbbbbbb6blZ", "ZZllNNNWWNNNllZZ"]},
	5: {"casas": [
		"ZZmllWWoWllmmZZZ", "ZmmlTlWoWlTlmmZZ", "ZmllllWoWlllllmZ", "Zmlu1lWdWl1ullmZ",
		"ZmllllddddllllmZ", "ZZmlTlWoWlTlmZZZ", "ZmmllsWoWsllmmmZ", "ZmllssWoWssllUmZ",
		"ZmlllsWWWsllllmZ", "ZZmlTlWVWlTlmmZZ", "ZmlllldddddllmmZ", "ZmlullWoWllulmZZ",
		"ZmllllWoWlllllmZ", "ZZmllTWoWTllmmZZ", "ZZmmllNoNllmmZZZ", "ZZZmmNNoNNmmZZZZ"]},
	6: {"casas": [
		"AAFFGFFFFBFFGAAA", "AFFFFFJmmFFFFFFA", "GFyyFFmmmFFyyFFG", "FFyyyFFOFFyyyFFF",
		"FFFyFFFFFFFyFFRF", "BFFFFSFFFFSFFFFB", "FFxxFFFFFFFFxxFF", "FFxPPFFHFFFPPxFF",
		"GFFPPFFFFFFPPFFG", "FFFFFFOFFJFFFFFF", "FyyFFFFFFmFFFyyF", "FyyyFFQFFFFFyyyF",
		"AFyyFFFFFFFFyyFA", "AFFFFFmmmFFFFFFA", "AAFFBFFJFFFBFFAA", "AAAFFFFFFFFFFAAA"]},
	7: {"casas": [
		"AFFFGFFFFFFGFFFA", "FFJFFFFmmFFFFJFF", "FFFFSRxmmxRSFFFF", "FFFRmmmmmmmmRFFF",
		"GFSmmMMMMMMmmSFG", "FFRmMM&MM&MMmRFF", "FFxmMMMMMMMMmxFF", "FmmmMMM%MMMMmmmF",
		"FmmmMMMMMMMMmmmF", "FFxmMMMMMMMMmxFF", "FFRmMM&MM&MMmRFF", "GFSmmMMMMMMmmSFG",
		"FFFRmmmmmmmmRFFF", "FFFFSRxmmxRSFFFF", "FJFFFFFmmFFFFFJF", "AFFGFFFFFFFFGFFA"]},
	8: {"casas": [
		"PPLLLLMMMMLLLLPP", "PL!LLMMMMMMLL#LP", "LLLLMM$MM$MMLLLL", "LLLMMMMMMMMMMLLL",
		"zzLLMMMMMMMMLLzz", "zzzLLLLMMLLLLzzz", "qqzzzzzMMzzzzzqq", "FFqqzzqqqqzzqqFF",
		"FFFqqFFqqFFqqFFF", "GFFFFFFFFFFFFFFG", "FFHFFFmmmmFFFHFF", "FFFFFmmmmmmFFFFF",
		"BFFFFFmmmmFFFFFB", "FFFQFFFFFFFFQFFF", "AFFFFFFFFFFFFFFA", "AAFFGFFFFFFGFFAA"],
		"alturas": ["1111111111111111", "1111111111111111", "1111111111111111", "1111111111111111",
			"1111111111111111", "0001111111111000"],
		"extras": [["castelo", "c12_muro_ruina_cipos", 2.5, 6.0, 0.0, 0.8], ["castelo", "c12_muro_ruina_cipos", 13.5, 6.0, 0.0, 0.8],
			["castelo", "c08_torre_vigia", 0.5, 2.5, 0.0, 0.9], ["castelo", "c08_torre_vigia", 15.5, 2.5, 0.0, 0.9],
			["castelo", "c11_portao_entalhado", 8.0, 0.5, 90.0, 0.8]]},
	9: {"casas": [
		"LLL!LLMMMMLL!LLL", "L#LLLMM&&MMLLL#L", "LLL!LMMMMMMLL!LL", "LLLLLMMMMMMLLLLL",
		"!LL!LLLMMLLL!LL!", "LLLLLLLMMLLLLLLL", "LL!L!LLMMLL!L!LL", "LLLLLLLMMLLLLLLL",
		"L&LLLLMMMMLLLL&L", "LLL!L$MMMM$L!LLL", "LLLLLLMMMMLLLLLL", "!LLLLLLLLLLLLLL!",
		"LL#LL!LLLL!LL#LL", "LLLLLLLLLLLLLLLL", "eeLLLLLLLLLLLLee", "eeeLLLLLLLLLLeee"],
		"alturas": ["0000011111100000", "0000011111100000", "0000011111100000", "0000011111100000"],
		"extras": [["castelo", "c04_muro_canto", 1.0, 15.0, 0.0, 0.8], ["castelo", "c04_muro_canto", 15.0, 15.0, 90.0, 0.8]]},
	10: {"casas": [
		"AFFGFFqqqqFFGFFA", "FFJFzzLLLLzzFJFF", "FFzzLLLLLLLLzzFF", "FzzLL#LMMLL#LzzF",
		"FzLLMMMMMMMMLLzF", "qLL$MMMMMMMM$LLq", "qLLMMM&MM&MMMLLq", "qLLMMMM%MMMMMLLq",
		"qLLMMMMMMMMMMLLq", "qLL$MMMMMMMM$LLq", "FzLLMMMMMMMMLLzF", "FzzLL!LLLL!LLzzF",
		"FFzzLLLLLLLLzzFF", "FFFFzzLLLLzzFFFF", "FJFFFFmmmmFFFFJF", "AFFGFFmmmmFFGFFA"],
		"alturas": ["0000000000000000", "0000000000000000", "0000000000000000", "0000000000000000",
			"0001111111111000", "0001111111111000", "0001122222211000", "0001122222211000",
			"0001122222211000", "0001111111111000", "0001111111111000"]},
	11: {"casas": [
		"AAAmmllmmmlmmAAA", "AJmmsslmmssmmmJA", "ARmmssTmmmsTmmRA", "SmmlllmmmmlllmmS",
		"mmllZlmxxmlZllmm", "mTmlllmxxmlllmTm", "mmmsssmmmmsssmmm", "AmmsUsmJmmsUsmmA",
		"AmmssslmmlsssmmA", "mmlllllmmllllllm", "mTlZllmmmmllZlTm", "mmllllmxxmllllmm",
		"AmmmmmmxxmmmmmmA", "AJmmmmmmmmmmmmJA", "AAmmmmmmmmmmmmAA", "AAAAmmmmmmmmAAAA"]},
	12: {"casas": [
		"AAASmmM%&MmmSAAA", "AASmmmMMMMmmmSAA", "ARmmmmmMMmmmmmRA", "AmmmTmmmmmmTmmmA",
		"WollmmmmmmmmlloW", "WollmmsmmsmmlloW", "AoJmmmmmmmmmmJoA", "ATmmmmmmmmmmmmTA",
		"AlmmmsmmmmsmmmlA", "WollmmmmmmmmlloW", "WolTmmmmmmmmTloW", "AlmmmmmmmmmmmmlA",
		"ARmmJmmmmmmJmmRA", "AAmmmmmmmmmmmmAA", "AASmmmmmmmmmmSAA", "AAAAAmmmmmmAAAAA"]},
}

## Luz de cada cenário (a atmosfera vem só de luz, névoa e cor — sem objetos novos).
const AMBIENTES := {
	"vila": {"sol": Color(1.0, 0.92, 0.78), "sol_e": 1.8, "sol_rot": Vector3(-48, -20, 0), "amb": 0.6,
		"fundo": Color(0.42, 0.62, 0.78), "sat": 1.18, "nevoa": 0.0, "nevoa_cor": Color(0.7, 0.8, 0.9), "brilho": []},
	"varzea": {"sol": Color(1.0, 0.9, 0.75), "sol_e": 1.5, "sol_rot": Vector3(-40, -35, 0), "amb": 0.6,
		"fundo": Color(0.45, 0.55, 0.55), "sat": 1.05, "nevoa": 0.002, "nevoa_cor": Color(0.66, 0.72, 0.66), "brilho": []},
	"igarape": {"sol": Color(0.85, 0.85, 0.75), "sol_e": 1.1, "sol_rot": Vector3(-35, -60, 0), "amb": 0.45,
		"fundo": Color(0.2, 0.26, 0.24), "sat": 0.9, "nevoa": 0.0045, "nevoa_cor": Color(0.36, 0.42, 0.36), "brilho": []},
	"floresta": {"sol": Color(0.95, 0.95, 0.75), "sol_e": 1.2, "sol_rot": Vector3(-55, -10, 0), "amb": 0.45,
		"fundo": Color(0.12, 0.2, 0.14), "sat": 1.1, "nevoa": 0.0035, "nevoa_cor": Color(0.3, 0.42, 0.3), "brilho": ["J"]},
	"ruinas": {"sol": Color(1.0, 0.8, 0.55), "sol_e": 1.5, "sol_rot": Vector3(-30, -30, 0), "amb": 0.5,
		"fundo": Color(0.35, 0.28, 0.22), "sat": 1.15, "nevoa": 0.0015, "nevoa_cor": Color(0.6, 0.5, 0.4), "brilho": ["&", "%"]},
	"covil": {"sol": Color(0.8, 0.72, 0.95), "sol_e": 1.0, "sol_rot": Vector3(-60, 10, 0), "amb": 0.4,
		"fundo": Color(0.05, 0.04, 0.08), "sat": 0.95, "nevoa": 0.005, "nevoa_cor": Color(0.22, 0.16, 0.3), "brilho": ["J", "&", "%"]},
}

var forcar := false
var so := ""
var _rng := RandomNumberGenerator.new()
var _info := {}   # cache: "kit/peça" -> [piso, andavel, altura_topo]


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--forcar":
			forcar = true
		elif a.begins_with("--so="):
			so = a.substr(5)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
	var falhas := 0
	for n in MAPAS:
		if so != "" and so != str(n):
			continue
		var out := DadosAto1.cena_batalha(n)
		if FileAccess.file_exists(out) and not forcar:
			print("JA EXISTE (pulado) ", out)
			continue
		_rng.seed = 1000 + n
		var root := _batalha(n)
		if root == null:
			falhas += 1
			continue
		_salvar(root, out)
	if so == "" or so == "mapa":
		var out := SAIDA + "mapa_arua.tscn"
		if FileAccess.file_exists(out) and not forcar:
			print("JA EXISTE (pulado) ", out)
		else:
			_rng.seed = 77
			_salvar(_mapa(), out)
	print("FIM (falhas: %d)" % falhas)
	quit(1 if falhas > 0 else 0)


# --- peças --------------------------------------------------------------------------------

func _peca_info(kit: String, nome: String) -> Array:
	var k := kit + "/" + nome
	if not _info.has(k):
		var p: Node = load(PECAS % [kit, nome]).instantiate()
		_info[k] = [p.piso, p.andavel, p.altura_topo]
		p.free()
	return _info[k]


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


func _piso_de(ch: String) -> String:
	return OBJ[ch][2] if OBJ.has(ch) else ch


# --- batalhas -------------------------------------------------------------------------------

func _batalha(n: int) -> Node3D:
	var dados: Dictionary = DadosAto1.BATALHAS[n]
	var mapa: Dictionary = MAPAS[n]
	var casas: Array = mapa["casas"]
	var alturas: Array = mapa.get("alturas", [])
	assert(casas.size() == 16, "batalha %d: %d linhas" % [n, casas.size()])
	var root := Node3D.new()
	root.name = "Batalha%02d" % n
	root.set_script(load("res://scripts/campanha/batalha_campanha.gd"))
	root.numero = n
	var terreno := _grupo(root, "Terreno", root)
	var cenario := _grupo(root, "Cenario", root)
	var pers := _grupo(root, "Personagens", root)
	var inicio := _grupo(root, "Inicio", root)
	var topo := {}
	var bloq := {}
	for z in 16:
		var linha: String = casas[z]
		if linha.length() != 16:
			push_error("batalha %d linha %d tem %d casas" % [n, z, linha.length()])
			return null
		for x in 16:
			var ch := linha[x]
			var pch := _piso_de(ch)
			if not PISO.has(pch):
				push_error("batalha %d: caractere '%s' sem legenda" % [n, ch])
				return null
			var k: Array = PISO[pch]
			var info := _peca_info(k[0], k[1])
			var nivel := 0
			if z < alturas.size():
				nivel = int(String(alturas[z])[x])
			var base := nivel * NIVEL
			for i in nivel:  # enchimento de barro vermelho embaixo da plataforma
				_peca(terreno, root, "terreno3", "m06_terra_vermelha", x + 0.5, z + 0.5, i * NIVEL)
			var giro := 90.0 * _rng.randi_range(0, 3) if pch in GIRO_LIVRE else 0.0
			var p := _peca(terreno, root, k[0], k[1], x + 0.5, z + 0.5, base, giro)
			if pch in BLOQUEAR:
				p.andavel = false
			topo[Vector2i(x, z)] = base + info[2]
			if not info[1] or pch in BLOQUEAR:
				bloq[Vector2i(x, z)] = true
			if OBJ.has(ch):
				var o: Array = OBJ[ch]
				_peca(cenario, root, o[0], o[1], x + 0.5, z + 0.5, topo[Vector2i(x, z)], _rng.randf_range(0, 360) if o[0] != "castelo" else 0.0, o[3])
				bloq[Vector2i(x, z)] = true
				if o.size() > 4 and o[4]:
					_fogo(cenario, root, Vector3(x + 0.5, topo[Vector2i(x, z)] + 0.9, z + 0.5))
	for e in mapa.get("extras", []):
		var p := _peca(cenario, root, e[0], e[1], e[2], e[3], 0.0, e[4], e[5])
		var y := 0.0
		var tg: Vector2i = p.tamanho_girado()
		var cel: Array[Vector2i] = []
		for dx in tg.x:
			for dz in tg.y:
				cel.append(Vector2i(roundi(e[2] - tg.x * 0.5) + dx, roundi(e[3] - tg.y * 0.5) + dz))
		for c in cel:
			y = maxf(y, topo.get(c, 0.0))
			bloq[c] = true
		p.position.y = y
	_brilhos(cenario, root, casas, topo, AMBIENTES[dados["ambiente"]]["brilho"])
	if n == 1:  # a Moradora (cuca.glb) assiste da vila; ocupa a casa dela
		var c := Vector2i(12, 13)
		_moradora(cenario, root, Vector3(c.x + 0.5, topo[c], c.y + 0.5), 200.0)
		bloq[c] = true

	# Inimigos (nós da cena: mova no editor) e marcadores de início do grupo.
	for e in dados["inimigos"]:
		var esp: Dictionary = DadosAto1.ESPECIES[e[0]]
		var permitido: bool = esp["modelo"].begins_with("mobs/") or esp["modelo"].begins_with("minions/") 			or esp["classe"] == "chefe" or n < esp.get("so_antes_de", 0)
		if not permitido:
			push_error("batalha %d: %s não é mob nem minion (heróis não podem ser inimigos)" % [n, e[0]])
			return null
		if n >= esp.get("so_antes_de", 99):
			push_error("batalha %d: %s é herói do grupo e não pode ser inimigo aqui" % [n, e[0]])
			return null
		var c := Vector2i(e[1], e[2])
		if bloq.has(c) or not topo.has(c):
			push_error("batalha %d: inimigo %s em casa bloqueada %s" % [n, e[0], c])
			return null
		_inimigo(pers, root, e, topo[c])
	var i := 0
	for c in dados["inicio"]:
		if bloq.has(c) or not topo.has(c):
			push_error("batalha %d: início em casa bloqueada %s" % [n, c])
			return null
		i += 1
		var m := Marker3D.new()
		m.name = "Casa%d" % i
		m.position = Vector3(c.x + 0.5, topo[c], c.y + 0.5)
		inicio.add_child(m)
		m.owner = root
	if not _rotas_ok(n, topo, bloq, dados):
		return null

	var cam_alvo := Vector3(8, 0.3, 8)
	_camera_luz(root, cam_alvo, 13.5, AMBIENTES[dados["ambiente"]])
	return root


func _inimigo(parent: Node3D, owner_: Node, e: Array, y: float) -> void:
	var esp: Dictionary = DadosAto1.ESPECIES[e[0]]
	var u := Node3D.new()
	u.set_script(load("res://scripts/components/unidade_3d.gd"))
	u.modelo = load(DadosAto1.RIG + esp["modelo"] + ".glb")
	u.display_name = esp["nome"]
	u.classe = esp["classe"]
	u.enemy = true
	u.especie = e[0]
	u.nivel = e[3]
	u.papel = e[4] if e.size() > 4 else ""
	if u.papel == "chefe":
		u.escala = 1.6
	var a := DadosAto1.atributos_especie(e[0])
	u.forca = a["forca"]
	u.destreza = a["destreza"]
	u.constituicao = a["constituicao"]
	u.inteligencia = a["inteligencia"]
	u.sabedoria = a["sabedoria"]
	u.carisma = a["carisma"]
	u.position = Vector3(e[1] + 0.5, y, e[2] + 0.5)
	u.rotation_degrees.y = 0.0  # frente do rig = +Z (sul): inimigos olham para o grupo
	parent.add_child(u, true)
	u.owner = owner_


## Duas rotas: acha um caminho do grupo aos inimigos, bloqueia o meio dele e
## confere se ainda existe outro caminho.
func _rotas_ok(n: int, topo: Dictionary, bloq: Dictionary, dados: Dictionary) -> bool:
	var de: Array = dados["inicio"]
	var para: Array = []
	for e in dados["inimigos"]:
		para.append(Vector2i(e[1], e[2]))
	var c1 := _caminho(de, para, topo, bloq, {})
	if c1.is_empty():
		push_error("batalha %d: grupo não alcança os inimigos" % n)
		return false
	var extra := {}
	for j in range(2, c1.size() - 2):
		extra[c1[j]] = true
	var c2 := _caminho(de, para, topo, bloq, extra)
	print("batalha %d: rota 1 = %d casas, rota 2 = %s" % [n, c1.size(), str(c2.size()) if not c2.is_empty() else "NENHUMA"])
	if c2.is_empty():
		push_error("batalha %d: só existe uma rota" % n)
		return false
	return true


func _caminho(de: Array, para: Array, topo: Dictionary, bloq: Dictionary, extra: Dictionary) -> Array:
	var pai := {}
	var fila: Array = []
	for c in de:
		pai[c] = c
		fila.append(c)
	while not fila.is_empty():
		var c: Vector2i = fila.pop_front()
		if c in para:
			var out := [c]
			while pai[c] != c:
				c = pai[c]
				out.push_front(c)
			return out
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var v: Vector2i = c + d
			if pai.has(v) or not topo.has(v) or extra.has(v):
				continue
			if bloq.has(v) and not (v in para):
				continue
			if absf(topo[v] - topo[c]) > SALTO:
				continue
			pai[v] = c
			fila.append(v)
	return []


## Pontos de luz suaves em cima dos cogumelos, pedras rúnicas e altares.
func _brilhos(parent: Node3D, owner_: Node, casas: Array, topo: Dictionary, chars: Array) -> void:
	var cores := {"J": Color(0.35, 0.9, 1.0), "&": Color(0.6, 0.45, 1.0), "%": Color(0.55, 0.9, 1.0)}
	for z in casas.size():
		for x in 16:
			var ch: String = String(casas[z])[x]
			if ch in chars:
				var l := OmniLight3D.new()
				l.name = "Brilho"
				l.light_color = cores[ch]
				l.light_energy = 1.4
				l.omni_range = 2.5
				l.position = Vector3(x + 0.5, topo[Vector2i(x, z)] + 0.6, z + 0.5)
				parent.add_child(l, true)
				l.owner = owner_


# --- mapa-múndi de Aruã -----------------------------------------------------------------------

const MW := 32
const MH := 24


## Região de cada casa: o centro de região mais perto decide; rio de oeste a leste
## (z ~16), igarapé subindo da várzea até a floresta, mar nas bordas oeste e sul.
func _regiao_mapa(x: int, z: int) -> String:
	if x == 0 or z == MH - 1 or (x <= 1 and z >= 12) or (z >= MH - 2 and x >= 26):
		return "mar"
	var rio_z := 16 + int(round(sin(x * 0.35) * 1.2))
	if z == rio_z and x < 28:
		return "rio"
	if x == 20 and z >= 11 and z < rio_z:
		return "igarape"
	var melhor := ""
	var dmin := 1e9
	for r in DadosAto1.REGIOES:
		var p: Vector2i = r["pos"]
		var d := Vector2(x - p.x, (z - p.y) * 1.15).length()
		if d < dmin:
			dmin = d
			melhor = r["id"]
	return melhor


func _na_rota(x: int, z: int) -> bool:
	var rota: Array = DadosAto1.ROTA
	for i in rota.size() - 1:
		var a: Vector2i = rota[i]
		var b: Vector2i = rota[i + 1]
		var passos := maxi(absi(b.x - a.x), absi(b.y - a.y))
		for s in passos + 1:
			var t := float(s) / maxf(passos, 1)
			if Vector2i(roundi(lerpf(a.x, b.x, t)), roundi(lerpf(a.y, b.y, t))) == Vector2i(x, z):
				return true
	return false


func _mapa() -> Node3D:
	var root := Node3D.new()
	root.name = "MapaArua"
	root.set_script(load("res://scripts/campanha/mapa_arua.gd"))
	var terreno := _grupo(root, "Terreno", root)
	var cenario := _grupo(root, "Cenario", root)
	var locais := _grupo(root, "Locais", root)
	var topo := {}
	var perto_local := func(x: int, z: int) -> bool:
		for r in DadosAto1.REGIOES:
			if Vector2(x - r["pos"].x, z - r["pos"].y).length() < 1.8:
				return true
		return false
	for z in MH:
		for x in MW:
			var reg := _regiao_mapa(x, z)
			var rota := _na_rota(x, z)
			var r := _rng.randf()
			var ch := "g"
			match reg:
				"mar":
					ch = "W"
				"rio":
					ch = "d" if rota else ("W" if r < 0.8 else "V")
				"igarape":
					ch = "d" if rota else "o"
				"vila":
					ch = "r" if rota else ["p", "p", "g", "f", "k"][int(r * 5)]
				"varzea":
					ch = "d" if rota else ["b", "b", "l", "u", "o", "V"][int(r * 6)]
				"floresta":
					ch = "r" if rota else ["F", "F", "m", "y", "Y"][int(r * 5)]
				"ruinas":
					ch = "e" if rota else ["L", "M", "z", "L"][int(r * 4)]
				"covil":
					ch = "l" if rota else ["m", "s", "l", "m", "x"][int(r * 5)]
			# margens do rio: areia
			var rio_z := 16 + int(round(sin(x * 0.35) * 1.2))
			if reg in ["vila", "varzea"] and absi(z - rio_z) == 1 and not rota:
				ch = "N"
			var k: Array = PISO[ch]
			var info := _peca_info(k[0], k[1])
			var nivel := 1 if reg == "ruinas" else 0
			if nivel > 0:
				_peca(terreno, root, "terreno3", "m06_terra_vermelha", x + 0.5, z + 0.5, 0.0)
			var giro := 90.0 * _rng.randi_range(0, 3) if ch in GIRO_LIVRE else 0.0
			_peca(terreno, root, k[0], k[1], x + 0.5, z + 0.5, nivel * NIVEL, giro)
			var y: float = nivel * NIVEL + info[2]
			topo[Vector2i(x, z)] = y
			if rota or perto_local.call(x, z) or not info[1]:
				continue
			var s := _rng.randf()
			var obj := ""
			match reg:
				"vila":
					if s < 0.08:
						obj = ["C", "9"][_rng.randi_range(0, 1)]
				"varzea":
					if s < 0.18:
						obj = ["Z", "I", "Z"][_rng.randi_range(0, 2)]
				"floresta":
					if s < 0.5:
						obj = ["A", "B", "C", "G", "H", "J"][_rng.randi_range(0, 5)]
				"ruinas":
					if s < 0.1:
						obj = ["!", "#", "*"][_rng.randi_range(0, 2)]
					elif s < 0.25:
						obj = ["A", "G"][_rng.randi_range(0, 1)]
				"covil":
					if s < 0.6:
						obj = ["A", "A", "G", "J", "U"][_rng.randi_range(0, 4)]
			if obj != "":
				var o: Array = OBJ[obj]
				var esc: float = o[3] * (1.25 if o[0] == "floresta" else 1.0)
				_peca(cenario, root, o[0], o[1], x + 0.5, z + 0.5, y, _rng.randf_range(0, 360) if o[0] != "castelo" else 0.0, esc)

	# Composição de cada região (só peças existentes).
	var t := func(x: int, z: int) -> float: return topo.get(Vector2i(x, z), 0.3)
	# Vila de Aruã: palafitas, oca, cobertura de palha, cais e canoas na margem
	_peca(cenario, root, "pantano", "s12_cabana_palafita", 3.5, 17.5, t.call(3, 17), 20.0, 1.3)
	_peca(cenario, root, "pantano", "s12_cabana_palafita", 7.5, 21.5, t.call(7, 21), 200.0, 1.3)
	_peca(cenario, root, "castelo", "c07_oca_palha", 3.0, 21.0, t.call(2, 20), 0.0, 0.8)
	_peca(cenario, root, "props", "v25_cobertura_palha", 7.5, 18.5, t.call(7, 18), 0.0)
	_peca(cenario, root, "props", "e02_secador_rede", 2.5, 19.5, t.call(2, 19), 40.0)
	_peca(cenario, root, "pantano", "s06_canoa", 6.5, 16.5, t.call(6, 16), 70.0, 0.9)
	_peca(cenario, root, "props", "e03_cestos_peixe", 8.5, 20.5, t.call(8, 20), 0.0)
	_moradora(cenario, root, Vector3(6.5, t.call(6, 20), 20.5), 200.0)
	# Várzea: palafita, canoa encalhada, cupinzeiro
	_peca(cenario, root, "pantano", "s12_cabana_palafita", 22.5, 21.5, t.call(22, 21), 160.0, 1.2)
	_peca(cenario, root, "pantano", "s06_canoa", 16.5, 22.5, t.call(16, 22), 10.0, 0.9)
	_peca(cenario, root, "pantano", "s14_monte_lama", 23.5, 18.5, t.call(23, 18), 0.0)
	# Floresta: samaúma gigante e cogumelos
	_peca(cenario, root, "floresta", "f01_samauma", 12.5, 11.5, t.call(12, 11), 0.0, 2.8)
	_peca(cenario, root, "floresta", "f07_cogumelos_brilhantes", 17.5, 11.5, t.call(17, 11), 0.0, 1.2)
	# Ruínas: portão, torre, muro, urnas, totens, braseiro, altar
	_peca(cenario, root, "castelo", "c11_portao_entalhado", 23.0, 7.5, t.call(23, 7), 90.0, 0.8)
	_peca(cenario, root, "castelo", "c08_torre_vigia", 28.5, 3.5, t.call(28, 3), 0.0, 0.9)
	_peca(cenario, root, "castelo", "c12_muro_ruina_cipos", 27.5, 7.0, t.call(27, 7), 0.0, 0.8)
	_peca(cenario, root, "castelo", "c13_braseiro", 26.5, 4.5, t.call(26, 4), 0.0, 0.55)
	_fogo(cenario, root, Vector3(26.5, t.call(26, 4) + 0.9, 4.5))
	_peca(cenario, root, "props", "r04_altar_cristal", 24.5, 3.5, t.call(24, 3), 0.0, 1.0)
	_peca(cenario, root, "props", "p3_03_pedra_runica", 27.5, 5.5, t.call(27, 5), 0.0, 0.9)
	# Covil: raízes, pedra rúnica e altar ao fundo
	_peca(cenario, root, "props", "u03_pedra_runas", 11.5, 1.5, t.call(11, 1), 0.0, 0.9)
	_peca(cenario, root, "floresta", "f01_samauma", 15.5, 1.5, t.call(15, 1), 90.0, 3.0)

	# Locais: um marcador por região (meta "regiao") + o Igarapé (sub-área).
	for reg in DadosAto1.REGIOES:
		var p: Vector2i = reg["pos"]
		_local(locais, root, reg["nome"].replace(" ", "_"), Vector3(p.x + 0.5, t.call(p.x, p.y), p.y + 0.5), reg["id"])
	var ig: Vector2i = DadosAto1.IGARAPE["pos"]
	_local(locais, root, "Igarape_dos_Ossos", Vector3(ig.x + 0.5, t.call(ig.x, ig.y), ig.y + 0.5), "")

	# Grupo: o Búfalo representa o grupo no mapa.
	var g := Node3D.new()
	g.set_script(load("res://scripts/components/unidade_3d.gd"))
	g.name = "Grupo"
	g.modelo = load(DadosAto1.HEROIS["bufalo"]["modelo"])
	g.display_name = "Búfalo Guerreiro"
	g.classe = "guerreiro"
	g.especie = "bufalo"
	g.escala = 1.4
	var v: Vector2i = DadosAto1.REGIOES[0]["pos"]
	g.position = Vector3(v.x + 0.5, t.call(v.x, v.y), v.y + 0.5)
	root.add_child(g)
	g.owner = root
	root.grupo = NodePath("Grupo")
	_camera_luz(root, Vector3(15.5, 0.3, 12.5), 25.5, AMBIENTES["vila"])
	return root


## A Moradora da vila (modelo cuca.glb, sem esqueleto): uma Peca3D que é
## objeto, não piso, e bloqueia a casa onde está.
func _moradora(parent: Node3D, owner_: Node, pos: Vector3, giro: float) -> void:
	var p := Node3D.new()
	p.set_script(load("res://scripts/components/peca_3d.gd"))
	p.name = "Moradora"
	p.piso = false
	p.andavel = false
	p.position = pos
	p.rotation_degrees.y = giro
	var m: Node3D = load(DadosAto1.MODELO_MORADORA).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	m.name = "Modelo"
	p.add_child(m)
	parent.add_child(p, true)
	m.owner = owner_
	p.owner = owner_


func _local(parent: Node3D, owner_: Node, nome: String, pos: Vector3, regiao: String) -> void:
	var m := Marker3D.new()
	m.name = nome
	m.position = pos
	m.set_meta("regiao", regiao)
	parent.add_child(m)
	m.owner = owner_
	var l := Label3D.new()
	l.name = "Nome"
	l.text = nome.replace("_", " ")
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.pixel_size = 0.0012
	l.font_size = 30
	l.outline_size = 10
	l.modulate = Color(1, 0.93, 0.7)
	l.position.y = 2.0
	m.add_child(l)
	l.owner = owner_


# --- câmera e luz (mesmo padrão de tools/gerar_cenas_3d.gd) --------------------------------

func _camera_luz(root: Node3D, alvo: Vector3, tamanho: float, amb: Dictionary) -> void:
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
	var quad := MeshInstance3D.new()
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
	env.background_color = amb["fundo"]
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = amb["amb"]
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
	env.adjustment_saturation = amb["sat"]
	env.adjustment_contrast = 1.05
	if amb["nevoa"] > 0.0:
		env.fog_enabled = true
		env.fog_light_color = amb["nevoa_cor"]
		env.fog_density = amb["nevoa"]
		env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	root.add_child(we)
	we.owner = root

	var sol := DirectionalLight3D.new()
	sol.name = "Sol"
	sol.rotation_degrees = amb["sol_rot"]
	sol.light_color = amb["sol"]
	sol.light_energy = amb["sol_e"]
	sol.shadow_enabled = true
	sol.shadow_blur = 1.5
	sol.directional_shadow_max_distance = 200.0
	root.add_child(sol)
	sol.owner = root
	var ceu := DirectionalLight3D.new()
	ceu.name = "LuzDoCeu"
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
