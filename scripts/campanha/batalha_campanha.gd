extends "res://scripts/batalha_3d.gd"
## Batalha do Ato I com combate por turnos. Reaproveita a leitura do terreno e
## as regras de passo de batalha_3d.gd (degrau máximo, água, obstáculos).
##   Terreno/ Cenario/   peças (editáveis)
##   Personagens/        inimigos (Unidade3D, editáveis no Inspector)
##   Inicio/             casas onde o grupo começa (Marker3D, na ordem)
## O grupo (Búfalo e, depois da batalha 03, a Tartaruga) entra pela Campanha.
## Ordem dos turnos: iniciativa. Poções podem ser usadas (gastam a ação); equipamento só fora.
## Ações: ataque básico (corpo a corpo, flecha ou magia da espécie) e habilidades
## da API Combate (scripts/combate/). Magia gasta MP; o Golpe Pesado tem recarga.
## Diálogos: autoload Dialogo ("bNN_antes", "bNN_depois", "b12_durante").
## Sons: assets/diorge/audio/acoes/<especie>_ataque|dano|morte.wav e hab_<id>.wav.
## Teste automático: godot --path . <cena> -- --auto [--campanha]

signal turno_acabou

const D := preload("res://scripts/campanha/dados_ato1.gd")
const MAPA := "res://scenes/3d/ato1/mapa_arua.tscn"
const SONS := "res://assets/diorge/audio/acoes/"
## Música de cada batalha: campo "trilha" em DadosAto1.BATALHAS (uma por cenário; a 12 é a do chefe).
const TRILHAS := "res://assets/diorge/audio/trilhas/"
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

## Autoload Campanha (por get_node: o script compila também no gerador headless).
var campanha: Node:
	get: return get_node("/root/Campanha")

## Autoload Dialogo (mesmo motivo).
var dialogo: Node:
	get: return get_node("/root/Dialogo")

## Número da batalha (1–12) em DadosAto1.BATALHAS.
@export var numero := 1

var _st := {}            # Unidade3D -> estado de combate
var _atual: Unidade3D
var _modo := ""          # "" | "mover" | id da ação ("ataque", "golpe", "cura_forte"...)
var _movido := false
var _agiu := false
var _fim := false
var _meio_dito := false
var _auto := false
var _rodada := 0
var _rng := RandomNumberGenerator.new()
var _painel_hud: HudBatalha
var _cursor: MeshInstance3D
var _alcance_mov := {}   # casa -> pai (caminho)
var _alvos := []         # unidades que podem ser alvo agora
var _molhado := {}       # casa -> true (lama, brejo, água rasa)
var _mata := {}          # casa -> true (chão de floresta, raízes, folhas)
var _agua := {}          # casa -> true (água funda, vitórias-régias: só nadadores)
var _custo := {}         # casa -> custo de movimento (2 = terreno difícil)
var _especial := {}      # casa -> "salto" | "voo" (só quem salta/voa entra)
var _iniciativa := {}    # Unidade3D -> d20 + Destreza (rolado no início)
var _cobertura := {}     # casa -> true: objeto do Cenário que bloqueia ataque à distância
## Clima da batalha ("dia", "noite", "chuva", "noite_chuva"): ver scripts/campanha/clima.gd.
var clima := "dia"


func _ready() -> void:
	_auto = "--auto" in OS.get_cmdline_user_args()
	_rng.seed = 4242 + numero + 97 * int(campanha.get_meta("tentativas", 0)) if _auto else Time.get_ticks_usec()
	campanha.iniciar_batalha(numero)
	clima = Clima.sortear(D.BATALHAS[numero], _rng)
	_criar_grupo()
	_units = find_children("*", "Unidade3D", true, false)
	_ler_terreno()
	_ler_tipos_de_terreno()
	_ler_cobertura()
	_aplicar_clima()
	_overlays = Node3D.new()
	_overlays.name = "Destaques"
	add_child(_overlays)
	_cursor = _quad(Color(1, 0.9, 0.4), 0.5)
	_cursor.hide()
	add_child(_cursor)
	for u in _units:
		_st[u] = _estado_inicial(u)
		_marca_estado(u)
	_painel_hud = HudBatalha.new()
	_painel_hud.batalha = self
	add_child(_painel_hud)
	_painel_hud.acao.connect(_on_acao)
	_painel_hud.atualizar()
	_iniciar.call_deferred()


func _iniciar() -> void:
	var trilha: String = D.BATALHAS[numero].get("trilha", "")
	if trilha != "":
		_musica(TRILHAS + trilha + ".wav")
	await _dialogo("b%02d_antes" % numero)
	# Só depois que as falas saem da tela: iniciativa (d20 + Destreza) define a ordem.
	var tela: TelaIniciativa = preload("res://scripts/campanha/tela_iniciativa.gd").new()
	tela.auto = _auto
	add_child(tela)
	_iniciativa = await tela.rolar(_units, _rng)
	if _auto:
		tela.queue_free()
	_painel_hud.atualizar()
	_painel_hud.mostrar_objetivo()
	await get_tree().create_timer(0.2 if _auto else 1.0).timeout
	_laco()


# --- montagem ------------------------------------------------------------------------------

func _criar_grupo() -> void:
	var casas := get_node_or_null("Inicio")
	var pers := get_node("Personagens")
	var i := 0
	for id in campanha.grupo_da_batalha(numero):
		var h: Dictionary = D.HEROIS[id]
		var u := Unidade3D.new()
		u.name = id.capitalize()
		u.modelo = load(h["modelo"])
		u.display_name = h["curto"]
		u.classe = h["classe"]
		u.especie = id
		u.escala = h["escala"]
		var a: Dictionary = campanha.atributos(id)
		u.nivel = campanha.herois[id]["nivel"]
		u.forca = a["forca"]
		u.destreza = a["destreza"]
		u.constituicao = a["constituicao"]
		u.inteligencia = a["inteligencia"]
		u.sabedoria = a["sabedoria"]
		u.carisma = a["carisma"]
		var pos := Vector3(7.5, 0.3, 12.5 + i)
		if casas and i < casas.get_child_count():
			pos = casas.get_child(i).position
		u.position = pos
		u.rotation_degrees.y = 180.0  # olha para o norte
		pers.add_child(u)
		i += 1


func _estado_inicial(u: Unidade3D) -> Dictionary:
	var attrs := {"forca": u.forca, "destreza": u.destreza, "constituicao": u.constituicao,
		"inteligencia": u.inteligencia, "sabedoria": u.sabedoria, "carisma": u.carisma}
	var e := {"attrs": attrs, "nivel": u.nivel, "classe": u.classe, "papel": u.papel, "xp": 0,
		"heroi": "", "arma": 0, "defesa": 0, "recarga": {}, "efeitos": {},
		"especie": u.especie, "habs": Combate.acoes(u.especie).slice(1), "bonus_def": 0}
	if not u.enemy and D.HEROIS.has(u.especie):
		var id: String = u.especie
		e["heroi"] = id
		e["hpmax"] = campanha.hp_max(id)
		e["mpmax"] = campanha.mp_max(id)
		e["hp"] = campanha.herois[id]["hp"]
		e["mp"] = campanha.herois[id]["mp"]
		e["arma"] = campanha.ataque_bonus(id)
		var arma: String = campanha.herois[id]["equipamento"].get("arma", "")
		e["peso_arma"] = D.ITENS[arma].get("peso", "") if D.ITENS.has(arma) else ""
		e["defesa"] = campanha.defesa_bonus(id)
		e["contra"] = campanha.arma_contra(id)
		e["bloqueio_flecha"] = campanha.bloqueio_flecha(id)
	else:
		var fator := Regras.FATOR_CHEFE if u.papel == "chefe" else (Regras.FATOR_LIDER if u.papel == "lider" else Regras.FATOR_COMUM)
		e["hpmax"] = Regras.hp_max(attrs, u.nivel, fator)
		e["defesa"] = Regras.armadura_natural(u.classe)
		e["peso_arma"] = Regras.peso_arma_da_classe(u.classe)
		e["mpmax"] = Regras.mp_max(attrs, u.nivel, u.classe)
		e["hp"] = e["hpmax"]
		e["mp"] = e["mpmax"]
	return e


# --- consultas usadas pelo HUD ----------------------------------------------------------------

func estado(u: Unidade3D) -> Dictionary:
	return _st.get(u, {})


func vivos(inimigos: bool) -> Array:
	return _units.filter(func(u): return u.enemy == inimigos)


## Ordem dos turnos: iniciativa rolada no começo (d20 + Destreza). Antes da
## rolagem, e em empates, vale a Destreza; empate total: o grupo antes.
func ordem() -> Array:
	var o := _units.duplicate()
	o.sort_custom(func(a, b):
		var ia: int = _iniciativa.get(a, a.destreza)
		var ib: int = _iniciativa.get(b, b.destreza)
		if ia != ib:
			return ia > ib
		return a.destreza > b.destreza or (a.destreza == b.destreza and not a.enemy and b.enemy))
	return o


func iniciativa(u: Unidade3D) -> int:
	return _iniciativa.get(u, 0)


func atual() -> Unidade3D:
	return _atual


func modo() -> String:
	return _modo


func pode_mover() -> bool:
	return _atual != null and not _atual.enemy and not _movido and not _fim and not _auto


func pode_agir() -> bool:
	return _atual != null and not _atual.enemy and not _agiu and not _fim and not _auto


func movimento(u: Unidade3D) -> int:
	var m: int = Regras.movimento(_st[u]["classe"], _st[u]["attrs"].get("destreza", 10))
	if _st[u]["efeitos"].has("lento"):
		m += Regras.EFEITOS["lento"]["mov"]
	m += Clima.efeito(_st[u]["especie"], clima)["mov"]
	return maxi(1, m)


## Clima da batalha para o HUD, ex.: "Noite com chuva".
func clima_nome() -> String:
	return Clima.nome(clima)


## Como o clima muda esta unidade (vazio se nada muda), ex.: "Chuva: dano +20%".
func clima_texto(u: Unidade3D) -> String:
	return Clima.texto(_st[u]["especie"], clima) if _st.has(u) else ""


## Chance de crítico da unidade (0 a 1).
func chance_critico(u: Unidade3D) -> float:
	return Regras.chance_critico(_st[u]["classe"], _st[u].get("peso_arma", "")) if _st.has(u) else 0.0


## Dados de uma ação ("ataque" ou id de habilidade) para esta unidade (API Combate).
## O ataque mágico sem MP vira "Golpe de cajado".
## Itens: ação "item:<id do item>" (poções), alcance 1, gasta a ação do turno.
func info_acao(u: Unidade3D, acao: String) -> Dictionary:
	if acao.begins_with("item:"):
		var id := acao.substr(5)
		var it: Dictionary = D.ITENS[id]
		return {"id": acao, "item": id, "nome": it["nome"], "tipo": "item", "alc": 1, "mp": 0, "recarga": 0,
			"cura": it.get("cura", 0), "mana": it.get("mana", 0), "visual": "cura",
			"cor": Color(0.5, 1.0, 0.6) if it.get("cura", 0) > 0 else Color(0.45, 0.7, 1.0)}
	return Combate.info(_st[u]["especie"], acao, _st[u]["mp"], _st[u])


func pode_usar(u: Unidade3D, acao: String) -> bool:
	if acao.begins_with("item:"):
		return not u.enemy and campanha.inventario.get(acao.substr(5), 0) > 0
	return Combate.pode_usar(info_acao(u, acao), _st[u]["mp"], _st[u]["recarga"])


## Ações do personagem para o HUD: [id, rótulo, disponível].
func acoes(u: Unidade3D) -> Array:
	var out := []
	out.append(["ataque", Combate.rotulo(info_acao(u, "ataque")), pode_agir()])
	for h in _st[u]["habs"]:
		out.append([h, Combate.rotulo(info_acao(u, h), _st[u]["recarga"]), pode_agir() and pode_usar(u, h) and not alvos_de(u, u.grid(), h).is_empty()])
	if not u.enemy:
		for item in campanha.consumiveis():
			var a: String = "item:" + str(item)
			out.append([a, "%s x%d" % [D.ITENS[item]["nome"], campanha.inventario[item]], pode_agir() and pode_usar(u, a) and not alvos_de(u, u.grid(), a).is_empty()])
	return out


func unidade_em(c: Vector2i) -> Unidade3D:
	for u in _units:
		if u.grid() == c:
			return u
	return null


func info_casa(c: Vector2i) -> String:
	if not _pisos.has(c):
		return ""
	var t := "Casa %d,%d · altura %.2f" % [c.x, c.y, _pisos[c]]
	if _especial.has(c) and _bloqueio.has(c):
		t += " · só quem " + ("voa" if _especial[c] == "voo" else "salta ou voa")
	elif _custo.get(c, 1) > 1:
		t += " · terreno difícil (custa 2)"
	if _molhado.has(c):
		t += " · molhado"
	elif _mata.has(c):
		t += " · mata"
	if _atual and no_terreno(_st[_atual]["especie"], c):
		t += " · terreno de %s: %s" % [_atual.display_name, "+%d armadura" % Regras.BONUS_ARMADURA_TERRENO if Regras.defensivo(_st[_atual]["especie"]) else "+25% dano"]
	if _cobertura.has(c):
		return t + " · cobertura (bloqueia flechas e magias)"
	if _atual and not _atual.enemy and _protegida(_atual, c):
		t += " · protegida de ataques à distância"
	return t + (" · não andável" if _bloqueio.has(c) else "")


func efeitos_texto(u: Unidade3D) -> String:
	var p := PackedStringArray()
	for k in _st[u]["efeitos"]:
		p.append("%s (%d)" % [Regras.EFEITOS[k]["nome"], _st[u]["efeitos"][k]])
	return ", ".join(p)


# --- laço de turnos -----------------------------------------------------------------------------

func _laco() -> void:
	while not _fim:
		_rodada += 1
		for u in ordem():
			if _fim:
				break
			if not u in _units:
				continue
			_atual = u
			_movido = false
			_agiu = false
			await _inicio_do_turno(u)
			if _fim:
				break
			if not u in _units:
				continue
			_painel_hud.atualizar()
			if u.enemy or _auto:
				await _ia(u)
			else:
				_entrar_modo("mover")
				await turno_acabou
			_fim_do_turno(u)
			_limpar()
			if _rodada > 60:
				_terminar(false)
		_painel_hud.atualizar()


## Veneno faz dano no começo do turno.
func _inicio_do_turno(u: Unidade3D) -> void:
	var ef: Dictionary = _st[u]["efeitos"]
	if ef.has("veneno"):
		var d: int = Regras.EFEITOS["veneno"]["dano"]
		_st[u]["hp"] = maxi(0, _st[u]["hp"] - d)
		_numero(u, str(d), Regras.EFEITOS["veneno"]["cor"])
		VfxCombate.impacto(self, u.global_position + Vector3.UP * 0.5, Regras.EFEITOS["veneno"]["cor"])
		_som_unidade(u, "dano")
		await _espera(0.4)
		if _st[u]["hp"] <= 0:
			_derrubar(u)
			await _checar_fim()


## Efeitos e recargas contam um turno a menos ao fim do turno da unidade.
func _fim_do_turno(u: Unidade3D) -> void:
	if not _st.has(u):
		return
	for dic in [_st[u]["efeitos"], _st[u]["recarga"]]:
		for k in dic.keys():
			dic[k] -= 1
			if dic[k] <= 0:
				dic.erase(k)
	_marca_estado(u)


func _encerrar_turno() -> void:
	_modo = ""
	_limpar()
	turno_acabou.emit()


func _on_acao(nome: String) -> void:
	if _atual == null or _atual.enemy or _fim or dialogo.ativo():
		return
	if nome == "esperar":
		_encerrar_turno()
	elif nome == "mover":
		if pode_mover():
			_entrar_modo("mover")
	elif pode_agir() and pode_usar(_atual, nome):
		if info_acao(_atual, nome).get("tipo", "") == "defesa":
			_agiu = true
			_limpar()
			await _executar(_atual, _atual, nome)
			_depois_da_acao()
		else:
			_entrar_modo(nome)


## "mover": casas azuis + alvos do ataque básico; ação: só os alvos dela.
func _entrar_modo(m: String) -> void:
	_modo = m
	_limpar()
	_alcance_mov = {}
	_alvos = []
	var acao := "ataque" if m == "mover" else m
	if m == "mover" and pode_mover():
		_alcance_mov = _bfs(_atual, movimento(_atual))
		for c in _alcance_mov:
			# verde-água = casa protegida dos atiradores adversários (atrás de árvore, muro...)
			_add_overlay(c, Color(0.2, 0.95, 0.75) if _protegida(_atual, c) else Color(0.3, 0.6, 1.0), 0.4)
	if pode_agir():
		_alvos = alvos_de(_atual, _atual.grid(), acao)
	for t in _alvos:
		_add_overlay(t.grid(), Color(0.3, 1.0, 0.4) if t.enemy == _atual.enemy else Color(1.0, 0.25, 0.2), 0.55)
	_painel_hud.atualizar()


func _limpar() -> void:
	for c in _overlays.get_children():
		c.free()


# --- entrada do jogador ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if _fim or dialogo.ativo():
		return
	if event is InputEventMouseMotion:
		var c := _casa_sob(event.position)
		_painel_hud.hover(c)
		if _pisos.has(c):
			_cursor.position = Vector3(c.x + 0.5, _pisos[c] + 0.12, c.y + 0.5)
			_cursor.show()
		else:
			_cursor.hide()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_clique(_casa_sob(event.position))
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if _atual and not _atual.enemy:
			_entrar_modo("mover")
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				_on_acao("esperar")
			KEY_A:
				_on_acao("ataque")
			KEY_1, KEY_2:
				var hs: Array = _st[_atual]["habs"] if _atual else []
				var i: int = event.keycode - KEY_1
				if i < hs.size():
					_on_acao(hs[i])
			KEY_ESCAPE:
				get_viewport().set_input_as_handled()
				if _atual and not _atual.enemy:
					_entrar_modo("mover")


func _clique(c: Vector2i) -> void:
	if _atual == null or _atual.enemy or _auto:
		return
	var alvo := unidade_em(c)
	if alvo and alvo in _alvos:
		_agiu = true
		var acao := "ataque" if _modo == "mover" else _modo
		_limpar()
		await _executar(_atual, alvo, acao)
		_depois_da_acao()
	elif _alcance_mov.has(c) and pode_mover():
		_movido = true
		_limpar()
		await _andar(_atual, c, _alcance_mov)
		_depois_da_acao()


func _depois_da_acao() -> void:
	if _fim or _atual == null:
		return
	var resta_acao := pode_agir() and acoes(_atual).any(func(a): return a[2] and (a[0] != "ataque" or not alvos_de(_atual, _atual.grid(), "ataque").is_empty()))
	if not pode_mover() and not resta_acao:
		_encerrar_turno()
	else:
		_entrar_modo("mover")


## Casa sob o mouse: projeta o topo de cada casa na tela e pega a mais perto.
func _casa_sob(pos: Vector2) -> Vector2i:
	var cam := get_viewport().get_camera_3d()
	var melhor := Vector2i(-99, -99)
	var dmin := 42.0
	for c in _pisos:
		var p := cam.unproject_position(Vector3(c.x + 0.5, _pisos[c], c.y + 0.5))
		var d := p.distance_to(pos)
		if d < dmin:
			dmin = d
			melhor = c
	return melhor


# --- movimento e alvos -----------------------------------------------------------------------------

## Casas alcançáveis com o caminho (casa -> casa anterior). Mesmas regras de
## alcance() da batalha de teste: degrau <= salto, sem água funda/obstáculo,
## passa por aliado, não por inimigo, não para em casa ocupada.
func _bfs(u: Unidade3D, mov: int) -> Dictionary:
	var ocupado := {}
	for o in _units:
		if o != u:
			ocupado[o.grid()] = o.enemy != u.enemy
	var mob := Regras.mobilidade(_st[u]["especie"])
	var esp: String = _st[u]["especie"]
	var nada := Regras.nadador(esp)
	var ini := u.grid()
	var dist := {ini: 0}
	var pai := {ini: ini}
	var fila: Array[Vector2i] = [ini]
	# Menor custo primeiro (terreno difícil custa 2): fila ordenada pelo custo.
	while fila.size() > 0:
		var c: Vector2i = fila.pop_front()
		for d in DIRS:
			var n: Vector2i = c + d
			if not _pisos.has(n) or not pode_entrar(mob, c, n, nada):
				continue
			if ocupado.get(n, false):
				continue
			var passo: int = 1 if mob == "voo" or no_terreno(esp, n) else _custo.get(n, 1)
			var custo: int = dist[c] + passo
			if custo > mov or (dist.has(n) and dist[n] <= custo):
				continue
			dist[n] = custo
			pai[n] = c
			var i := 0
			while i < fila.size() and dist[fila[i]] <= custo:
				i += 1
			fila.insert(i, n)
	for o in ocupado:
		pai.erase(o)
	pai.erase(ini)
	return pai


## Lê o tipo de cada piso: terreno difícil (custo 2) e casas só para quem
## salta/voa (água funda, vitórias-régias, troncos...). Objetos em cima (árvores,
## muros) continuam bloqueando para todos.
func _ler_tipos_de_terreno() -> void:
	var objeto := {}
	for p in find_children("*", "Peca3D", true, false):
		var nome: String = p.scene_file_path.get_file().get_basename()
		for c in p.casas():
			if not p.piso:
				if not p.andavel:
					objeto[c] = true
				continue
			if nome in Regras.TERRENO_DIFICIL:
				_custo[c] = 2
			if nome in Regras.TERRENO_MOLHADO:
				_molhado[c] = true
			if nome in Regras.TERRENO_MATA:
				_mata[c] = true
			if nome in Regras.TERRENO_AGUA:
				_agua[c] = true
			if Regras.TERRENO_ESPECIAL.has(nome):
				_especial[c] = Regras.TERRENO_ESPECIAL[nome]
	for c in objeto:
		_especial.erase(c)


## Pode passar da casa `de` para a vizinha `para` com essa mobilidade?
func pode_entrar(mob: String, de: Vector2i, para: Vector2i, nada := false) -> bool:
	if _bloqueio.has(para):
		var tipo: String = _especial.get(para, "")
		var nadando: bool = nada and _agua.has(para)
		if not nadando and (tipo == "" or mob == "" or (tipo == "voo" and mob != "voo")):
			return false
		if nadando:
			return absf(_pisos[para] - _pisos.get(de, _pisos[para])) <= salto
	if mob == "voo":
		return true
	var degrau := Regras.DEGRAU_SALTO if mob == "salto" else salto
	return absf(_pisos[para] - _pisos.get(de, _pisos[para])) <= degrau


## A casa é do terreno do ambiente desse animal (molhado ou mata)?
func no_terreno(especie: String, c: Vector2i) -> bool:
	match Regras.afinidade(especie):
		"molhado":
			return _molhado.has(c) or (Regras.nadador(especie) and _agua.has(c))
		"mata":
			return _mata.has(c)
	return false


func _dist(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## Quem `u` pode escolher como alvo da `acao` estando na casa `de`.
func alvos_de(u: Unidade3D, de: Vector2i, acao: String) -> Array:
	var i := info_acao(u, acao)
	var out := []
	match i["tipo"]:
		"dano", "area":
			var longe := _a_distancia(i)
			for o in _units:
				if o.enemy != u.enemy and _dist(de, o.grid()) <= i["alc"] and (not longe or linha_livre(de, o.grid())):
					out.append(o)
		"cura":
			for o in _units:
				if o.enemy == u.enemy and _dist(de, o.grid()) <= i["alc"] and _st[o]["hp"] < _st[o]["hpmax"]:
					out.append(o)
		"cura_area":
			for o in _units:
				if o.enemy == u.enemy and _dist(de, o.grid()) <= i["alc"] and _feridos_em_volta(o).size() > 0:
					out.append(o)
		"defesa":
			if not _st[u]["efeitos"].has("defesa"):
				out.append(u)
		"item":
			for o in _units:
				if o.enemy == u.enemy and _dist(de, o.grid()) <= i["alc"] and _item_serve(i, o):
					out.append(o)
	return out


func _item_serve(i: Dictionary, o: Unidade3D) -> bool:
	return (i["cura"] > 0 and _st[o]["hp"] < _st[o]["hpmax"]) \
		or (i["mana"] > 0 and _st[o]["mpmax"] > 0 and _st[o]["mp"] < _st[o]["mpmax"])


func _feridos_em_volta(centro: Unidade3D, raio := 1) -> Array:
	return _units.filter(func(o): return o.enemy == centro.enemy and _dist(o.grid(), centro.grid()) <= raio and _st[o]["hp"] < _st[o]["hpmax"])


func _virar(u: Unidade3D, para: Vector3) -> void:
	u.virar_para(para, 0.04 if _auto else 0.15)


func _andar(u: Unidade3D, destino: Vector2i, pai: Dictionary) -> void:
	var caminho: Array[Vector2i] = []
	var c := destino
	while pai.has(c):
		caminho.push_front(c)
		c = pai[c]
	u.tocar("walk")
	for p in caminho:
		var alvo := Vector3(p.x + 0.5, _pisos[p], p.y + 0.5)
		_virar(u, alvo)
		var tw := create_tween()
		tw.tween_property(u, "position", alvo, 0.05 if _auto else 0.3)  # um passo do ciclo de andar por casa
		await tw.finished
	u.tocar("idle")


# --- ações -----------------------------------------------------------------------------------------

func _peito(u: Unidade3D) -> Vector3:
	return u.global_position + Vector3.UP * 0.6 * u.escala


func _executar(u: Unidade3D, alvo: Unidade3D, acao: String) -> void:
	var i := info_acao(u, acao)
	var e: Dictionary = _st[u]
	e["mp"] -= i.get("mp", 0)
	if i.get("recarga", 0) > 0:
		e["recarga"][acao] = i["recarga"] + 1  # +1: o fim deste turno já desconta
	if alvo != u:
		_virar(u, alvo.position)
	if i["tipo"] == "item":
		await _usar_item(u, alvo, i)
		return
	u.tocar("attack")
	var cajado: bool = acao == "ataque" and i.get("nome", "") == Combate.hab(Combate.SEM_MP).nome
	if acao == "ataque" and not cajado:
		_som_unidade(u, "ataque")
	else:
		_som(SONS + "hab_%s.wav" % (Combate.SEM_MP if cajado else acao))
	await _espera(0.3)
	match i["tipo"]:
		"cura":
			var v := Regras.cura(e["attrs"], e["nivel"], i["poder"])
			if alvo != u:
				await VfxCombate.lancar(self, i, _peito(u), _peito(alvo), _auto)
			VfxCombate.acertar(self, i, alvo.global_position)
			_curar(alvo, v)
		"cura_area":
			await VfxCombate.lancar(self, i, _peito(u), _peito(alvo), _auto)
			VfxCombate.onda(self, alvo.global_position, i["cor"], i["raio"])
			var v := Regras.cura(e["attrs"], e["nivel"], i["poder"])
			for o in _feridos_em_volta(alvo, i["raio"]):
				VfxCombate.acertar(self, i, o.global_position)
				_curar(o, v)
		"defesa":
			for o in _units:
				if o.enemy == u.enemy and _dist(o.grid(), u.grid()) <= i["raio"]:
					_st[o]["efeitos"]["defesa"] = i["turnos"] + (1 if o == u else 0)
					_st[o]["bonus_def"] = i["bonus"]
					VfxCombate.acertar(self, i, o.global_position)
					_numero(o, "DEF +%d" % i["bonus"], Regras.EFEITOS["defesa"]["cor"])
					_marca_estado(o)
		"dano", "area":
			await VfxCombate.lancar(self, i, _peito(u), _peito(alvo), _auto)
			var alvos := [alvo]
			if i["tipo"] == "area":
				alvos = _units.filter(func(o): return o.enemy != u.enemy and _dist(o.grid(), u.grid()) <= 1)
			for t in alvos:
				VfxCombate.acertar(self, i, _peito(t))
				_ferir(u, t, i["mult"], i["efeito"], i.get("visual", ""))
	await _espera(0.5)
	_painel_hud.atualizar()
	await _checar_fim()


## Poção: gasta do inventário do grupo e cura HP e/ou MP do alvo (vizinho ou si).
func _usar_item(u: Unidade3D, alvo: Unidade3D, i: Dictionary) -> void:
	if not campanha.gastar_item(i["item"]):
		return
	_som(SONS + "hab_cura_leve.wav")
	_mostrar_pocao(alvo)
	await _espera(0.2)
	VfxCombate.acertar(self, i, alvo.global_position)
	if i["cura"] > 0:
		_curar(alvo, i["cura"])
	if i["mana"] > 0:
		var e: Dictionary = _st[alvo]
		var v: int = mini(i["mana"], e["mpmax"] - e["mp"])
		e["mp"] += v
		_numero(alvo, "+%d MP" % v, Color(0.5, 0.75, 1.0))
	await _espera(0.5)
	_painel_hud.atualizar()


## O frasco (itensCura.glb) sobe e some acima de quem bebe.
func _mostrar_pocao(alvo: Unidade3D) -> void:
	if not ResourceLoader.exists(D.MODELO_POCAO):
		return
	var m: Node3D = load(D.MODELO_POCAO).instantiate()
	add_child(m)
	m.global_position = alvo.global_position + Vector3.UP * 1.1 * alvo.escala
	m.scale = Vector3.ONE * 0.35
	var tw := create_tween()
	tw.tween_property(m, "position:y", m.position.y + 0.5, 0.7)
	tw.parallel().tween_property(m, "rotation:y", TAU, 0.7)
	tw.tween_property(m, "scale", Vector3.ZERO, 0.2)
	tw.tween_callback(m.queue_free)


func _curar(alvo: Unidade3D, v: int) -> void:
	_st[alvo]["hp"] = mini(_st[alvo]["hpmax"], _st[alvo]["hp"] + v)
	_numero(alvo, "+%d" % v, Color(0.4, 1.0, 0.5))


func _defesa_total(t: Unidade3D) -> int:
	var d: int = _st[t]["defesa"]
	if _st[t]["efeitos"].has("defesa"):
		d += _st[t]["bonus_def"]
	var esp: String = _st[t]["especie"]
	if Regras.defensivo(esp) and no_terreno(esp, t.grid()):
		d += Regras.BONUS_ARMADURA_TERRENO  # defensivo no próprio terreno
	return maxi(0, d + Clima.efeito(esp, clima)["arm"])


func _ferir(u: Unidade3D, t: Unidade3D, mult: float, efeito: String, visual := "") -> void:
	var a: Dictionary = _st[u]
	var b: Dictionary = _st[t]
	# Escudo de pedra marajoara: chance de bloquear flechas.
	if visual == "flecha" and _rng.randf() < b.get("bloqueio_flecha", 0.0):
		_numero(t, "Bloqueou!", Color(0.9, 0.9, 1.0))
		VfxCombate.escudo(self, t.global_position)
		return
	# Maça marajoara: +50% contra cobras e plantas.
	if b["especie"] in a.get("contra", []):
		mult *= 1.5
	var dif: float = _pisos.get(u.grid(), 0.0) - _pisos.get(t.grid(), 0.0)
	var d := Regras.dano(a["attrs"], a["classe"], a["nivel"], b["attrs"], a["arma"], dif, _rng)
	if a["efeitos"].has("fraco"):
		d += Regras.EFEITOS["fraco"]["dano_feito"]
	if not Regras.defensivo(a["especie"]) and no_terreno(a["especie"], u.grid()):
		mult *= Regras.BONUS_DANO_TERRENO  # ofensivo no próprio terreno (ex.: búfalo na lama)
	mult *= Clima.efeito(a["especie"], clima)["dano"]  # noite e chuva (hábitat do animal)
	var critico := _rng.randf() < Regras.chance_critico(a["classe"], a.get("peso_arma", ""))
	if critico:
		mult *= Regras.mult_critico(a.get("peso_arma", ""))
	d = maxi(1, roundi(d * mult))
	var bruto := d
	d = Regras.absorver(d, _defesa_total(t))  # armadura segura parte do golpe
	b["hp"] = maxi(0, b["hp"] - d)
	var txt := str(d) if d == bruto else "%d  (armadura -%d)" % [d, bruto - d]
	if critico:
		_numero(t, "CRÍTICO! " + txt, Color(1.0, 0.35, 0.2), 46)
		VfxCombate.impacto(self, _peito(t), Color(1.0, 0.45, 0.2), true)
	else:
		_numero(t, txt, Color(1.0, 0.85, 0.4))
	if b["hp"] > 0:
		t.tocar("hurt")
		_som_unidade(t, "dano")
		if efeito != "" and b["papel"] != "chefe":
			b["efeitos"][efeito] = Regras.EFEITOS[efeito]["turnos"]
			_marca_estado(t)
		return
	if a["heroi"] != "":
		a["xp"] += Regras.xp_derrota(b["nivel"])
	_derrubar(t)


func _derrubar(t: Unidade3D) -> void:
	var b: Dictionary = _st[t]
	_som_unidade(t, "dano" if b["papel"] == "lider" else "morte")
	_units.erase(t)
	b["efeitos"].clear()
	_marca_estado(t)
	if b["papel"] == "lider":
		t.tocar("hurt")  # derrotada em batalha, mas viva
	else:
		t.tocar("die")
		if b["papel"] != "chefe" and b["heroi"] == "":
			get_tree().create_timer(1.6).timeout.connect(t.hide)


func _numero(t: Unidade3D, texto: String, cor: Color, tamanho := 34) -> void:
	var l := Label3D.new()
	l.text = texto
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.pixel_size = 0.0012
	l.font_size = tamanho
	l.outline_size = 10
	l.modulate = cor
	l.position = t.position + Vector3(0, 1.2 * t.escala, 0)
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position:y", l.position.y + 0.7, 0.9)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.4)
	tw.tween_callback(l.queue_free)


## Plaquinha de estado acima da unidade (Envenenado, Lento, Enfraquecido, Casco Firme).
func _marca_estado(u: Unidade3D) -> void:
	var l := u.get_node_or_null("Estado") as Label3D
	if l == null:
		l = Label3D.new()
		l.name = "Estado"
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.fixed_size = true
		l.pixel_size = 0.0008
		l.font_size = 24
		l.outline_size = 8
		l.position.y = 1.22 * u.escala
		u.add_child(l)
	var ef: Dictionary = _st[u]["efeitos"]
	var p := PackedStringArray()
	var cor := Color.WHITE
	for k in ef:
		p.append(Regras.EFEITOS[k]["nome"])
		cor = Regras.EFEITOS[k]["cor"]
	l.text = " · ".join(p)
	l.modulate = cor


func _espera(s: float) -> void:
	await get_tree().create_timer(s * (0.2 if _auto else 1.0)).timeout


# --- inteligência dos adversários (e do grupo no modo --auto) --------------------------------------

func _ia(u: Unidade3D) -> void:
	await _espera(0.3)
	var e: Dictionary = _st[u]
	var reach := _bfs(u, movimento(u))
	var casas: Array = reach.keys()
	casas.push_front(u.grid())
	# 0) herói muito ferido (só no --auto) toma poção
	if not u.enemy and _st[u]["hp"] < _st[u]["hpmax"] * 0.3 and pode_usar(u, "item:pocao"):
		await _executar(u, u, "item:pocao")
		return
	# 1) apoio: cura em área, cura, defesa
	for h in e["habs"]:
		if not pode_usar(u, h):
			continue
		var tipo: String = info_acao(u, h)["tipo"]
		if tipo == "cura_area":
			for c in casas:
				for t in alvos_de(u, c, h):
					if _feridos_em_volta(t, info_acao(u, h)["raio"]).filter(func(o): return _st[o]["hp"] < _st[o]["hpmax"] * 0.7).size() >= 2:
						await _ir_e_fazer(u, c, reach, t, h)
						return
		elif tipo == "cura":
			for c in casas:
				for t in alvos_de(u, c, h):
					if _st[t]["hp"] < _st[t]["hpmax"] * 0.55:
						await _ir_e_fazer(u, c, reach, t, h)
						return
		elif tipo == "defesa":
			var perto := _units.filter(func(o): return o.enemy != u.enemy and _dist(o.grid(), u.grid()) <= 3)
			if not perto.is_empty() and not alvos_de(u, u.grid(), h).is_empty():
				await _executar(u, u, h)
				return
	# 1b) só o grupo no modo --auto (faz o papel de um jogador cuidadoso): ferido,
	#     recua para a casa menos ameaçada perto da aliada e bate em quem alcançar dali.
	if not u.enemy and e["hp"] < e["hpmax"] * 0.5 and vivos(false).size() > 1:
		var melhor := u.grid()
		var nota := _ameaca(u, melhor) * 3.0
		for c in casas:
			var n := _ameaca(u, c) * 3.0 + 0.5 * _dist_aliado(u, c)
			if n < nota:
				nota = n
				melhor = c
		if melhor != u.grid():
			var alvos := alvos_de(u, melhor, "ataque")
			alvos.sort_custom(func(x, y): return _st[x]["hp"] < _st[y]["hp"])
			if alvos.is_empty():
				await _andar(u, melhor, reach)
			else:
				await _ir_e_fazer(u, melhor, reach, alvos[0], "ataque")
			return
	# 2) atacar: escolhe casa e alvo (mais fraco; o Búfalo é o alvo preferido;
	#    quem ataca de longe prefere ficar longe dos adversários)
	var acao := "ataque"
	for h in e["habs"]:
		if info_acao(u, h)["tipo"] in ["dano", "area"] and pode_usar(u, h):
			acao = h
	var longe: bool = info_acao(u, "ataque")["alc"] >= 3
	var expo := {}  # casa -> atiradores adversários com mira livre nela
	for c in casas:
		expo[c] = _exposicao(u, c)
	var melhor_c := Vector2i(-1, -1)
	var melhor_t: Unidade3D = null
	var melhor_a := ""
	var melhor_s := -INF
	for a in ([acao, "ataque"] if acao != "ataque" else ["ataque"]):
		for c in casas:
			for t in alvos_de(u, c, a):
				var s := -float(_st[t]["hp"]) - (0.5 if c != u.grid() else 0.0)
				if _st[t]["heroi"] == "bufalo":
					s += 3.0
				if a != "ataque":
					s += 6.0
				if longe:
					s += 1.5 * _menor_dist(u, c)
				s -= PESO_EXPOSTO * expo[c]
				if no_terreno(e["especie"], c):
					s += 2.0  # prefere atacar (ou aguentar o golpe) do próprio terreno
				if s > melhor_s:
					melhor_s = s
					melhor_c = c
					melhor_t = t
					melhor_a = a
	if melhor_t:
		if melhor_a == "area" and _units.filter(func(o): return o.enemy != u.enemy and _dist(o.grid(), melhor_c) <= 1).size() < 2:
			melhor_a = "ataque"
		await _ir_e_fazer(u, melhor_c, reach, melhor_t, melhor_a)
		return
	# 3) aproximar: casa alcançável mais perto (pelo chão) de algum adversário
	# (ganha um pouco de chão a menos para terminar atrás de árvore/muro, longe da mira)
	var perto := _distancias_ate(not u.enemy)
	var dest := u.grid()
	# Defensivo segura posição no próprio terreno (vira uma "parede" no caminho).
	var bonus_terreno := 2.5 if Regras.defensivo(e["especie"]) else 1.0
	var smin: float = perto.get(dest, 9999) + PESO_EXPOSTO * _exposicao(u, dest) - (bonus_terreno if no_terreno(e["especie"], dest) else 0.0)
	for c in reach:
		var sc: float = perto.get(c, 9999) + PESO_EXPOSTO * _exposicao(u, c) - (bonus_terreno if no_terreno(e["especie"], c) else 0.0)
		if sc < smin:
			smin = sc
			dest = c
	if dest != u.grid():
		await _andar(u, dest, reach)
	await _espera(0.15)


# --- clima (noite e chuva) ---------------------------------------------------------------------

## Luz de luar/chuva e gotas sobre o mapa; à noite cada unidade leva uma luz fraca.
func _aplicar_clima() -> void:
	if _pisos.is_empty():
		return
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for c in _pisos:
		mn = mn.min(Vector2(c.x, c.y))
		mx = mx.max(Vector2(c.x + 1, c.y + 1))
	var meio := (mn + mx) * 0.5
	Clima.aplicar_visual(self, clima, Vector3(meio.x, 0, meio.y), mx - mn)
	if Clima.tem(clima, "noite"):
		for u in _units:
			Clima.luz_da_unidade(u, u.enemy)
	if _auto:
		print("CLIMA batalha=%d %s" % [numero, clima])


# --- cobertura (ataques à distância precisam de linha de visão) -----------------------------------

## Peso, na IA, de cada atirador adversário que teria mira livre na casa.
const PESO_EXPOSTO := 2.5


## Objetos do Cenário que não são piso e não deixam passar (árvore, muro, rocha, casa).
## Água funda é piso: não bloqueia a mira.
func _ler_cobertura() -> void:
	_cobertura = {}
	for p in find_children("*", "Peca3D", true, false):
		if not p.piso and not p.andavel:
			for c in p.casas():
				_cobertura[c] = true


## Ação à distância (flecha, magia, luz...): precisa de linha de visão.
## Corpo a corpo e a lança (alcance 2, visual "corpo") não precisam.
func _a_distancia(i: Dictionary) -> bool:
	return i.get("alc", 1) >= 2 and i.get("visual", "corpo") != "corpo"


## A linha entre os centros das casas `a` e `b` não passa por nenhuma casa de cobertura.
func linha_livre(a: Vector2i, b: Vector2i) -> bool:
	var va := Vector2(a) + Vector2(0.5, 0.5)
	var vb := Vector2(b) + Vector2(0.5, 0.5)
	var passos := maxi(2, ceili(va.distance_to(vb) * 6.0))
	for k in range(1, passos):
		var p := va.lerp(vb, float(k) / passos)
		var c := Vector2i(floori(p.x), floori(p.y))
		if c != a and c != b and _cobertura.has(c):
			return false
	return true


## Atiradores adversários de `u` que alcançam a casa `c` (andando + alcance) e
## teriam mira livre nela a partir de onde estão agora.
func _atiradores(u: Unidade3D, c: Vector2i) -> Array:
	var out := []
	for o in _units:
		if o.enemy == u.enemy or not _st.has(o):
			continue
		var i := info_acao(o, "ataque")
		if not _a_distancia(i):
			continue
		if _dist(o.grid(), c) <= i["alc"] + movimento(o):
			out.append(o)
	return out


## Adversários que conseguem bater na casa `c` no próximo turno (andando + alcance,
## com mira livre quando o ataque é à distância).
func _ameaca(u: Unidade3D, c: Vector2i) -> int:
	var n := 0
	for o in _units:
		if o.enemy == u.enemy:
			continue
		var i := info_acao(o, "ataque")
		if _dist(o.grid(), c) <= i["alc"] + movimento(o) and (not _a_distancia(i) or linha_livre(o.grid(), c)):
			n += 1
	return n


func _dist_aliado(u: Unidade3D, c: Vector2i) -> int:
	var m := 0
	for o in _units:
		if o != u and o.enemy == u.enemy:
			m = _dist(o.grid(), c) if m == 0 else mini(m, _dist(o.grid(), c))
	return m


func _exposicao(u: Unidade3D, c: Vector2i) -> int:
	return _atiradores(u, c).filter(func(o): return linha_livre(o.grid(), c)).size()


## Casa protegida: há atirador adversário perto e nenhum tem mira livre nela.
func _protegida(u: Unidade3D, c: Vector2i) -> bool:
	var at := _atiradores(u, c)
	return not at.is_empty() and at.all(func(o): return not linha_livre(o.grid(), c))


func _ir_e_fazer(u: Unidade3D, c: Vector2i, reach: Dictionary, alvo: Unidade3D, acao: String) -> void:
	if c != u.grid():
		await _andar(u, c, reach)
	await _executar(u, alvo, acao)


func _menor_dist(u: Unidade3D, c: Vector2i) -> int:
	var m := 99
	for o in _units:
		if o.enemy != u.enemy:
			m = mini(m, _dist(o.grid(), c))
	return m


## Distância pelo chão de cada casa até a unidade mais próxima do lado `inimigos`.
func _distancias_ate(inimigos: bool) -> Dictionary:
	var dist := {}
	var fila: Array[Vector2i] = []
	for o in _units:
		if o.enemy == inimigos:
			dist[o.grid()] = 0
			fila.append(o.grid())
	while fila.size() > 0:
		var c: Vector2i = fila.pop_front()
		for d in DIRS:
			var n: Vector2i = c + d
			if dist.has(n) or not _pisos.has(n) or _bloqueio.has(n):
				continue
			if absf(_pisos[n] - _pisos[c]) > salto:
				continue
			dist[n] = dist[c] + 1
			fila.append(n)
	return dist


# --- fim da batalha ------------------------------------------------------------------------------

func _checar_fim() -> void:
	if _fim:
		return
	var b: Dictionary = D.BATALHAS[numero]
	var bufalo_vivo := _units.any(func(u): return _st[u]["heroi"] == "bufalo")
	if not bufalo_vivo or vivos(false).is_empty():
		_terminar(false)
		return
	var venceu := vivos(true).is_empty()
	for u in _st:
		var p: String = _st[u]["papel"]
		if p in ["lider", "chefe"] and _st[u]["hp"] <= 0:
			venceu = true
		if p == "chefe" and not _meio_dito and _st[u]["hp"] > 0 and _st[u]["hp"] <= _st[u]["hpmax"] / 2:
			_meio_dito = true
			await _dialogo("b12_durante")
	if venceu:
		_terminar(true)


func _terminar(vitoria: bool) -> void:
	if _fim:
		return
	_fim = true
	_limpar()
	_cursor.hide()
	_atual = null
	turno_acabou.emit()  # solta um turno do jogador que estava esperando
	_finalizar(vitoria)


func _finalizar(vitoria: bool) -> void:
	await _espera(1.2)
	var estado := {}
	for u in _st:
		if _st[u]["heroi"] != "":
			estado[_st[u]["heroi"]] = {"hp": _st[u]["hp"], "mp": _st[u]["mp"], "xp": _st[u]["xp"]}
	if _auto:
		_resultado_auto(vitoria, estado)
		return
	if vitoria:
		for u in _units:
			u.tocar("idle")
		await _dialogo("b%02d_depois" % numero)
		var resumo: Dictionary = campanha.concluir_batalha(numero, estado)
		_painel_hud.mostrar_resultado(true, resumo, estado)
	else:
		_painel_hud.mostrar_resultado(false, {}, estado)


## Modo --auto: imprime o resultado; com --campanha segue para a próxima batalha
## (o grupo descansa entre as batalhas, como o jogador faria com poções/vila).
func _resultado_auto(vitoria: bool, estado: Dictionary) -> void:
	var hp := PackedStringArray()
	for id in estado:
		hp.append("%s=%d/%d nv%d" % [id, estado[id]["hp"], campanha.hp_max(id), campanha.herois[id]["nivel"]])
	print("AUTO_RESULTADO batalha=%d %s rodadas=%d inimigos_vivos=%d cobertura=%d %s" % [numero, "VITORIA" if vitoria else "DERROTA", _rodada, vivos(true).size(), _cobertura.size(), " ".join(hp)])
	if not "--campanha" in OS.get_cmdline_user_args():
		get_tree().quit()
		return
	var tent: int = campanha.get_meta("tentativas", 0)
	if vitoria:
		campanha.concluir_batalha(numero, estado)
		campanha.descansar()
		campanha.set_meta("tentativas", 0)
		if numero >= 12:
			print("AUTO_CAMPANHA concluida")
			get_tree().quit()
		else:
			get_tree().change_scene_to_file(D.cena_batalha(numero + 1))
	elif tent < 2:
		campanha.set_meta("tentativas", tent + 1)
		campanha.derrota()
		get_tree().reload_current_scene()
	else:
		print("AUTO_CAMPANHA travou na batalha %d" % numero)
		get_tree().quit()


## Diálogo pelo autoload Dialogo (pausa a árvore enquanto roda). Se a Moradora
## (Npc3D) está na cena, ela gesticula ("talk") enquanto a conversa dura.
func _dialogo(id: String) -> void:
	if not dialogo.existe(id):
		return
	var npc := find_child("Moradora", true, false)
	if npc and npc.has_method("tocar"):
		npc.process_mode = Node.PROCESS_MODE_ALWAYS  # anima mesmo com a árvore pausada
		npc.tocar("talk")
	await dialogo.tocar(id)
	if npc and npc.has_method("tocar"):
		npc.tocar("idle")


func _som(caminho: String) -> void:
	if _auto or not ResourceLoader.exists(caminho):
		return
	var p := AudioStreamPlayer.new()
	p.stream = load(caminho)
	p.volume_db = -4.0
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


func _som_unidade(u: Unidade3D, tipo: String) -> void:
	_som(SONS + "%s_%s.wav" % [_st[u]["especie"], tipo])


func _musica(caminho: String) -> void:
	if _auto or not ResourceLoader.exists(caminho):
		return
	var p := AudioStreamPlayer.new()
	p.name = "Musica"
	var fluxo: AudioStream = load(caminho)
	var wav := fluxo as AudioStreamWAV
	if wav and wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		# Garantia caso o .import perca o loop (edit/loop_mode=2).
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
	p.stream = fluxo
	p.volume_db = -8.0
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(p)
	p.play()


func voltar_ao_mapa() -> void:
	get_tree().change_scene_to_file(MAPA)


func tentar_de_novo() -> void:
	campanha.derrota()
	get_tree().reload_current_scene()


func _quad(cor: Color, alpha: float) -> MeshInstance3D:
	var q := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(0.92, 0.92)
	q.mesh = pm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(cor, alpha)
	m.no_depth_test = true
	q.material_override = m
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return q
