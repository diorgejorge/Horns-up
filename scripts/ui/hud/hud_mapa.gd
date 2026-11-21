class_name HudMapa
extends CanvasLayer
## HUD do mapa-múndi de Aruã (seção 7.8 do roteiro): região atual, regiões
## visitadas, próximo destino, rotas, marcador da missão principal, resumo da
## região selecionada e um resumo do grupo com acesso à tela de gerenciamento.
## Só desenha e avisa: quem anda, luta e troca de cena é o mapa (mapa_arua.gd).
##
## Uso no mapa:
##   _hud = HudMapa.new(); add_child(_hud)
##   _hud.selecionou.connect(...); _hud.viajar.connect(...); _hud.lutar.connect(...)
##   _hud.abrir_grupo.connect(...)
##   _hud.atualizar(_sel, _andando)   # sempre que algo mudar

signal selecionou(indice: int)
signal viajar(regiao: String)
signal lutar(batalha: int)
signal abrir_grupo

const D := preload("res://scripts/campanha/dados_ato1.gd")

## Autoload Campanha (por get_node: o script compila também no modo headless).
var campanha: Node:
	get: return get_node("/root/Campanha")

var _sel := 0
var _andando := false
var _topo: Label
var _etapa: Label
var _missao: Label
var _lista: VBoxContainer
var _detalhe: VBoxContainer
var _grupo: VBoxContainer


func _ready() -> void:
	var raiz := Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.theme = TemaUI.tema()
	add_child(raiz)

	# Topo: região atual, etapa e missão principal
	var topo := PainelMarajoara.new(10.0)
	topo.set_anchors_preset(Control.PRESET_TOP_WIDE)
	topo.offset_left = 16
	topo.offset_right = -16
	topo.offset_top = 12
	raiz.add_child(topo)
	var tv := VBoxContainer.new()
	topo.add_child(tv)
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 16)
	tv.add_child(th)
	_topo = TemaUI.rotulo("", 22, TemaUI.OURO)
	_topo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	th.add_child(_topo)
	_etapa = TemaUI.rotulo("", 17, Color(TemaUI.CREME, 0.8))
	th.add_child(_etapa)
	var bg := Button.new()
	bg.text = "Grupo (G)"
	bg.tooltip_text = "Grupo, equipamento, inventário e habilidades"
	bg.focus_mode = Control.FOCUS_NONE
	bg.pressed.connect(func(): abrir_grupo.emit())
	th.add_child(bg)
	tv.add_child(FaixaMarajoara.new())
	_missao = TemaUI.rotulo("", 17)
	_missao.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tv.add_child(_missao)

	# Esquerda: regiões (visitadas ✓, missão !, bloqueadas ???)
	var esq := PainelMarajoara.new()
	esq.offset_left = 16
	esq.offset_top = 160
	esq.offset_right = 340
	raiz.add_child(esq)
	var ev := VBoxContainer.new()
	esq.add_child(ev)
	ev.add_child(TemaUI.rotulo("Regiões de Aruã", 20, TemaUI.OURO))
	ev.add_child(FaixaMarajoara.new())
	_lista = VBoxContainer.new()
	ev.add_child(_lista)
	ev.add_child(TemaUI.rotulo("✓ visitada   ! missão   ◆ você", 13, Color(TemaUI.CREME, 0.6)))

	# Baixo-esquerda: resumo do grupo
	var gp := PainelMarajoara.new(8.0)
	gp.anchor_top = 1.0
	gp.anchor_bottom = 1.0
	gp.offset_left = 16
	gp.offset_right = 340
	gp.offset_bottom = -16
	gp.grow_vertical = Control.GROW_DIRECTION_BEGIN
	raiz.add_child(gp)
	_grupo = VBoxContainer.new()
	_grupo.add_theme_constant_override("separation", 4)
	gp.add_child(_grupo)

	# Baixo-direita: detalhe da região selecionada
	var dir := PainelMarajoara.new()
	dir.anchor_left = 1.0
	dir.anchor_right = 1.0
	dir.anchor_top = 1.0
	dir.anchor_bottom = 1.0
	dir.offset_left = -480
	dir.offset_right = -16
	dir.offset_bottom = -16
	dir.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	dir.grow_vertical = Control.GROW_DIRECTION_BEGIN
	raiz.add_child(dir)
	_detalhe = VBoxContainer.new()
	_detalhe.add_theme_constant_override("separation", 8)
	_detalhe.custom_minimum_size.x = 420
	dir.add_child(_detalhe)
	var atraso := 0.0
	for p in [topo, esq, gp, dir]:
		p.entrar(atraso)
		atraso += 0.07


func _limpar(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()


func atualizar(sel: int, andando: bool) -> void:
	_sel = sel
	_andando = andando
	var atual: Dictionary = D.regiao(campanha.regiao_atual)
	_topo.text = "Arquipélago de Aruã  ·  Região atual: %s" % atual.get("nome", "?")
	_etapa.text = campanha.etapa_texto()
	_missao.text = "! Missão principal: " + campanha.objetivo_atual()
	_preencher_lista()
	_preencher_grupo()
	_preencher_detalhe()


func _concluida(r: Dictionary) -> bool:
	return r["batalhas"].all(func(n): return n in campanha.vencidas)


func _preencher_lista() -> void:
	_limpar(_lista)
	var prox: int = campanha.proxima_batalha()
	for i in D.REGIOES.size():
		var r: Dictionary = D.REGIOES[i]
		var aberta: bool = campanha.regiao_desbloqueada(r["id"])
		var aqui: bool = r["id"] == campanha.regiao_atual
		var marca := "   "
		if aberta and prox in r["batalhas"]:
			marca = "!  "
		elif _concluida(r):
			marca = "✓  "
		var bt := Button.new()
		bt.alignment = HORIZONTAL_ALIGNMENT_LEFT
		bt.focus_mode = Control.FOCUS_NONE
		bt.text = marca + (r["nome"] if aberta else "???") + ("  ◆" if aqui else "")
		bt.disabled = not aberta
		if i == _sel:
			bt.add_theme_color_override("font_color", TemaUI.OURO)
			bt.add_theme_color_override("font_hover_color", TemaUI.OURO)
		bt.pressed.connect(func(): selecionou.emit(i))
		_lista.add_child(bt)
		# Sub-área de travessia: só depois que o grupo chega lá.
		if r["id"] == "varzea" and D.IGARAPE["aparece_apos"] in campanha.vencidas:
			_lista.add_child(TemaUI.rotulo("      ↳ " + D.IGARAPE["nome"], 14, Color(TemaUI.CREME, 0.7)))


func _preencher_grupo() -> void:
	_limpar(_grupo)
	_grupo.add_child(TemaUI.rotulo("Grupo", 18, TemaUI.OURO))
	for id in campanha.grupo():
		var h: Dictionary = campanha.herois[id]
		var prota: bool = D.HEROIS[id].get("protagonista", false)
		var linha := HBoxContainer.new()
		linha.add_theme_constant_override("separation", 6)
		_grupo.add_child(linha)
		linha.add_child(TemaUI.icone(D.HEROIS[id]["curto"], TemaUI.OURO if prota else TemaUI.ALIADO, 30.0, prota))
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		linha.add_child(col)
		col.add_child(TemaUI.rotulo("%s · Nv %d%s" % [D.HEROIS[id]["curto"], h["nivel"], "  ★" if prota else ""], 15, TemaUI.OURO if prota else TemaUI.CREME))
		var barras := HBoxContainer.new()
		barras.add_theme_constant_override("separation", 4)
		col.add_child(barras)
		var bh := BarraHud.criar(TemaUI.HP, h["hp"], campanha.hp_max(id), 120.0, 12.0)
		bh.tooltip_text = "HP %d/%d" % [h["hp"], campanha.hp_max(id)]
		barras.add_child(bh)
		if campanha.mp_max(id) > 0:
			var bm := BarraHud.criar(TemaUI.MP, h["mp"], campanha.mp_max(id), 80.0, 12.0)
			bm.tooltip_text = "MP %d/%d" % [h["mp"], campanha.mp_max(id)]
			barras.add_child(bm)


## Regiões vizinhas na ordem de progressão (as rotas do mapa), só as já alcançadas.
func _rotas(i: int) -> PackedStringArray:
	var out := PackedStringArray()
	for j in [i - 1, i + 1]:
		if j >= 0 and j < D.REGIOES.size() and campanha.regiao_desbloqueada(D.REGIOES[j]["id"]):
			out.append(D.REGIOES[j]["nome"])
	return out


func _preencher_detalhe() -> void:
	_limpar(_detalhe)
	var r: Dictionary = D.REGIOES[_sel]
	var aqui: bool = r["id"] == campanha.regiao_atual
	var cab := HBoxContainer.new()
	_detalhe.add_child(cab)
	var nome := TemaUI.rotulo(r["nome"], 24, TemaUI.OURO)
	nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cab.add_child(nome)
	var est := "Você está aqui" if aqui else ("Visitada" if _concluida(r) else "Próximo destino")
	cab.add_child(TemaUI.rotulo(est, 14, Color(TemaUI.CREME, 0.7)))
	_detalhe.add_child(FaixaMarajoara.new())
	var res := TemaUI.rotulo(r["resumo"], 16)
	res.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detalhe.add_child(res)
	var rotas := _rotas(_sel)
	if not rotas.is_empty():
		_detalhe.add_child(TemaUI.rotulo("Rotas: " + " · ".join(rotas), 14, Color(TemaUI.CREME, 0.75)))
	var prox: int = campanha.proxima_batalha()
	for n in r["batalhas"]:
		var b: Dictionary = D.BATALHAS[n]
		var feita: bool = n in campanha.vencidas
		if not feita and n != prox:
			_detalhe.add_child(TemaUI.rotulo("Batalha %02d — ???" % n, 16, Color(TemaUI.CREME, 0.45)))
			continue
		var bt := Button.new()
		bt.text = ("✓ " if feita else "! ") + "Batalha %02d — %s" % [n, b["nome"]]
		bt.disabled = feita or not aqui or _andando
		if not feita and not aqui:
			bt.tooltip_text = "Viaje até %s para lutar." % r["nome"]
		bt.pressed.connect(func(): lutar.emit(n))
		_detalhe.add_child(bt)
		if not feita:
			var o := TemaUI.rotulo("Objetivo: " + b["objetivo"], 14, Color(TemaUI.CREME, 0.8))
			o.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_detalhe.add_child(o)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	_detalhe.add_child(h)
	if not aqui:
		var bv := Button.new()
		bv.text = "Viajar para cá (Enter)"
		bv.disabled = _andando or not campanha.regiao_desbloqueada(r["id"])
		bv.pressed.connect(func(): viajar.emit(r["id"]))
		h.add_child(bv)
	if r["id"] == "vila":
		var bd := Button.new()
		bd.text = "Descansar na vila"
		bd.disabled = not aqui or _andando
		bd.tooltip_text = "Recupera HP e MP do grupo."
		bd.pressed.connect(func():
			campanha.descansar()
			atualizar(_sel, _andando))
		h.add_child(bd)
