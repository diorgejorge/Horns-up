class_name HudBatalha
extends CanvasLayer
## HUD da batalha, organizada como nos JRPGs táticos:
##   topo        título, objetivo e a fila dos próximos turnos (Destreza) em retratos 3D
##   alto/dir.   cabeçalho do alvo sob o mouse (ou do adversário da vez) e a casa
##               (altura, se é andável)
##   baixo/esq.  cards do grupo (retrato, nível, HP/MP), o da vez pulsando
##   baixo/dir.  janela de comandos com cursor e caixa com a descrição da ação
## Sem inventário nem equipamento: isso só existe fora da batalha.
## Painéis de madeira com moldura marajoara (PainelMarajoara, scripts/ui/hud/).

signal acao(nome: String)

const D := preload("res://scripts/campanha/dados_ato1.gd")

## Autoload Campanha (por get_node: o script compila também no gerador headless).
var campanha: Node:
	get: return get_node("/root/Campanha")

var batalha  # batalha_campanha.gd
var _raiz: Control
var _titulo: Label
var _objetivo: Label
var _ordem: HBoxContainer
var _grupo_box: HBoxContainer
var _cards := {}   # Unidade3D (aliado) -> {painel, info}
var _painel_atual: PanelContainer   # caixa de ajuda: descrição da ação sob o cursor
var _ajuda_titulo: Label
var _ajuda: Label
var _painel_alvo: PanelContainer
var _casa: Label
var _painel_casa: PanelContainer
var _botoes := {}
var _resultado: PanelContainer
var _hover := Vector2i(-99, -99)
var _cartas := {}  # Unidade3D -> carta da fila de turnos (retrato 3D reaproveitado)
var _painel_cmd: PainelMarajoara
var _cmds: VBoxContainer
var _info_cmd := {}  # id da ação -> [título, texto da ajuda]


func _ready() -> void:
	layer = 10
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.theme = TemaUI.tema()
	add_child(_raiz)

	# Topo: título, objetivo e fila de turnos
	var topo := PainelMarajoara.new(10.0)
	topo.set_anchors_preset(Control.PRESET_TOP_WIDE)
	topo.offset_left = 16
	topo.offset_right = -16
	topo.offset_top = 12
	topo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(topo)
	var tv := VBoxContainer.new()
	topo.add_child(tv)
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 18)
	tv.add_child(linha)
	_titulo = TemaUI.rotulo("", 22, TemaUI.OURO)
	linha.add_child(_titulo)
	_objetivo = TemaUI.rotulo("", 18)
	_objetivo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_objetivo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	linha.add_child(_objetivo)
	tv.add_child(FaixaMarajoara.new())
	var ol := HBoxContainer.new()
	ol.add_theme_constant_override("separation", 8)
	tv.add_child(ol)
	var ot := TemaUI.rotulo("PRÓXIMOS ▸", 16, TemaUI.OURO)
	ot.tooltip_text = "Ordem dos turnos por Destreza"
	ot.mouse_filter = Control.MOUSE_FILTER_PASS
	ot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ol.add_child(ot)
	_ordem = HBoxContainer.new()
	_ordem.add_theme_constant_override("separation", 5)
	ol.add_child(_ordem)

	# Baixo-esquerda: cards do grupo
	_grupo_box = HBoxContainer.new()
	_grupo_box.add_theme_constant_override("separation", 8)
	_grupo_box.anchor_top = 1.0
	_grupo_box.anchor_bottom = 1.0
	_grupo_box.offset_left = 16
	_grupo_box.offset_top = -16
	_grupo_box.offset_bottom = -16
	_grupo_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_raiz.add_child(_grupo_box)

	# Baixo-direita: janela de comandos com cursor
	_painel_cmd = PainelMarajoara.new(8.0, TemaUI.OURO)
	_painel_cmd.anchor_left = 1.0
	_painel_cmd.anchor_right = 1.0
	_painel_cmd.anchor_top = 1.0
	_painel_cmd.anchor_bottom = 1.0
	_painel_cmd.offset_left = -300
	_painel_cmd.offset_right = -16
	_painel_cmd.offset_top = -16
	_painel_cmd.offset_bottom = -16
	_painel_cmd.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_painel_cmd.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_raiz.add_child(_painel_cmd)
	_cmds = VBoxContainer.new()
	_cmds.add_theme_constant_override("separation", 2)
	_painel_cmd.add_child(_cmds)
	_painel_cmd.hide()

	# Caixa de ajuda à esquerda dos comandos: descrição da ação sob o cursor
	var ajuda := PainelMarajoara.new(6.0, TemaUI.PRETO)
	ajuda.margem = 6.0
	_painel_atual = ajuda
	_painel_atual.anchor_left = 1.0
	_painel_atual.anchor_right = 1.0
	_painel_atual.anchor_top = 1.0
	_painel_atual.anchor_bottom = 1.0
	_painel_atual.offset_left = -620
	_painel_atual.offset_right = -308
	_painel_atual.offset_top = -16
	_painel_atual.offset_bottom = -16
	_painel_atual.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_painel_atual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_painel_atual)
	var av := VBoxContainer.new()
	_painel_atual.add_child(av)
	_ajuda_titulo = TemaUI.rotulo("", 16, TemaUI.OURO)
	av.add_child(_ajuda_titulo)
	_ajuda = TemaUI.rotulo("", 14, Color(TemaUI.CREME, 0.85))
	_ajuda.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ajuda.custom_minimum_size.x = 280
	av.add_child(_ajuda)
	_painel_atual.hide()

	# Alto-direita: cabeçalho do alvo (ou do adversário da vez)
	_painel_alvo = PainelMarajoara.new(10.0, TemaUI.INIMIGO)
	_painel_alvo.anchor_left = 1.0
	_painel_alvo.anchor_right = 1.0
	_painel_alvo.offset_left = -420
	_painel_alvo.offset_right = -16
	_painel_alvo.offset_top = 196
	_painel_alvo.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_painel_alvo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_painel_alvo)
	_painel_alvo.hide()
	# Casa sob o mouse: terreno, altura e se é andável (logo abaixo da fila de turnos)
	_painel_casa = PainelMarajoara.new(6.0, TemaUI.PRETO)
	_painel_casa.margem = 4.0
	_painel_casa.anchor_left = 1.0
	_painel_casa.anchor_right = 1.0
	_painel_casa.offset_right = -16
	_painel_casa.offset_top = 150
	_painel_casa.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_painel_casa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_painel_casa)
	_casa = TemaUI.rotulo("", 15, Color(TemaUI.CREME, 0.9))
	_painel_casa.add_child(_casa)
	_painel_casa.hide()


func _limpar(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()


func mostrar_objetivo() -> void:
	var b: Dictionary = D.BATALHAS[batalha.numero]
	var banner := PainelMarajoara.new(12.0, TemaUI.OURO)
	banner.set_anchors_preset(Control.PRESET_CENTER)
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	banner.add_child(v)
	var t := TemaUI.rotulo("Batalha %02d — %s" % [batalha.numero, b["nome"]], 30, TemaUI.OURO)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	v.add_child(FaixaMarajoara.new())
	var o := TemaUI.rotulo("Objetivo: " + b["objetivo"], 20)
	o.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(o)
	_raiz.add_child(banner)
	banner.entrar()
	var tw := create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(banner, "modulate:a", 0.0, 0.6)
	tw.tween_callback(banner.queue_free)


func atualizar() -> void:
	if batalha == null:
		return
	var b: Dictionary = D.BATALHAS[batalha.numero]
	_titulo.text = "%02d · %s" % [batalha.numero, b["nome"]]
	_objetivo.text = "Objetivo: " + b["objetivo"]
	var atual: Unidade3D = batalha.atual()
	_preencher_ordem(atual)
	_preencher_grupo(atual)
	_preencher_comandos(atual)
	hover(_hover)


# --- fila de turnos ----------------------------------------------------------------------

## Fila começando pela unidade da vez. As cartas são guardadas e só reordenadas
## (cada retrato 3D é um SubViewport, caro de recriar).
func _preencher_ordem(atual: Unidade3D) -> void:
	var o: Array = batalha.ordem()
	var i := o.find(atual)
	if i > 0:
		o = o.slice(i) + o.slice(0, i)
	for u in _cartas.keys():
		if not is_instance_valid(u) or not u in o:
			_cartas[u].queue_free()
			_cartas.erase(u)
	for k in o.size():
		var u: Unidade3D = o[k]
		if not _cartas.has(u):
			_cartas[u] = _carta(u)
			_ordem.add_child(_cartas[u])
		var c: PainelMarajoara = _cartas[u]
		_ordem.move_child(c, k)
		var vez := u == atual
		c.pulso = vez
		c.custom_minimum_size = Vector2(78, 78) if vez else Vector2(56, 56)
		c.visible = k < 10


func _carta(u: Unidade3D) -> PainelMarajoara:
	var c := PainelMarajoara.new(4.0, _cor(u))
	c.margem = 0.0
	c.tooltip_text = "%s · DES %d" % [u.display_name, u.destreza]
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.add_child(_retrato(u))
	return c


func _retrato(u: Unidade3D) -> RetratoModelo:
	var r := RetratoModelo.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.mostrar.call_deferred(u.modelo.resource_path if u.modelo else "")  # depois de entrar na árvore
	return r


func _cor(u: Unidade3D) -> Color:
	return TemaUI.INIMIGO if u.enemy else (TemaUI.OURO if u.especie == "bufalo" else TemaUI.ALIADO)


# --- cards do grupo ----------------------------------------------------------------------

func _preencher_grupo(atual: Unidade3D) -> void:
	var vivos: Array = batalha.vivos(false)
	for u in _cards.keys():
		if not is_instance_valid(u) or not u in vivos:
			_cards[u]["painel"].queue_free()
			_cards.erase(u)
	for u in vivos:
		if not _cards.has(u):
			var p := PainelMarajoara.new(6.0, _cor(u))
			p.margem = 6.0
			p.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var h := HBoxContainer.new()
			h.add_theme_constant_override("separation", 8)
			p.add_child(h)
			var r := _retrato(u)
			r.custom_minimum_size = Vector2(64, 64)
			h.add_child(r)
			var info := VBoxContainer.new()
			info.add_theme_constant_override("separation", 2)
			h.add_child(info)
			_grupo_box.add_child(p)
			_cards[u] = {"painel": p, "info": info}
		var c: Dictionary = _cards[u]
		var vez: bool = u == atual
		c["painel"].pulso = vez
		_info_card(c["info"], u, vez)


func _info_card(v: VBoxContainer, u: Unidade3D, vez: bool) -> void:
	_limpar(v)
	var e: Dictionary = batalha.estado(u)
	var prota: bool = u.especie == "bufalo"
	var nome := ("▶ " if vez else "") + u.display_name + ("  ★" if prota else "")
	v.add_child(TemaUI.rotulo(nome, 17, TemaUI.OURO if (vez or prota) else TemaUI.CREME))
	var cls := Regras.classe(e.get("classe", u.classe))
	var extra := ""
	if vez:
		extra = " · Mov %d · Alc %d" % [batalha.movimento(u), batalha.info_acao(u, "ataque").get("alc", cls["alc"])]
	v.add_child(TemaUI.rotulo("%s · Nv %d%s" % [cls["nome"], e.get("nivel", 1), extra], 13))
	v.add_child(BarraHud.criar(TemaUI.HP, e.get("hp", 0), e.get("hpmax", 1), 190.0, 14.0, true, "hp"))
	if e.get("mpmax", 0) > 0:
		v.add_child(BarraHud.criar(TemaUI.MP, e.get("mp", 0), e.get("mpmax", 1), 190.0, 14.0, true, "mp"))
	var ef: String = batalha.efeitos_texto(u)
	if ef != "":
		v.add_child(TemaUI.rotulo(ef, 12, TemaUI.OURO))


# --- comandos e ajuda -------------------------------------------------------------------

func _preencher_comandos(u: Unidade3D) -> void:
	_limpar(_cmds)
	_botoes.clear()
	_info_cmd.clear()
	var nossa := u != null and not u.enemy
	_painel_cmd.visible = nossa
	_painel_atual.visible = nossa
	if not nossa:
		return
	_cmds.add_child(TemaUI.rotulo("Comandos · " + u.display_name, 16, TemaUI.OURO))
	_cmds.add_child(FaixaMarajoara.new())
	var lista := [["mover", "Mover", batalha.pode_mover()]]
	_info_cmd["mover"] = ["Mover", "Anda até %d casas. Água funda, troncos e vitórias-régias não são andáveis." % batalha.movimento(u)]
	var n := 0
	for a in batalha.acoes(u):
		var tecla := "A" if a[0] == "ataque" else str(n)
		lista.append([a[0], "%s [%s]" % [a[1], tecla], a[2]])
		_info_cmd[a[0]] = _texto_acao(u, a[0])
		n += 1
	lista.append(["esperar", "Esperar [Espaço]", true])
	_info_cmd["esperar"] = ["Esperar", "Encerra o turno de %s." % u.display_name]
	var m: String = batalha.modo()
	for a in lista:
		var id: String = a[0]
		var bt := _comando(a[1], m == id)
		bt.disabled = not a[2]
		bt.pressed.connect(func(): acao.emit(id))
		bt.mouse_entered.connect(func(): _mostrar_ajuda(id))
		bt.mouse_exited.connect(func(): _mostrar_ajuda(m))
		_cmds.add_child(bt)
		_botoes[id] = bt
	_mostrar_ajuda(m)


## [título, texto] da ação, a partir da API de combate (via batalha.info_acao).
func _texto_acao(u: Unidade3D, id: String) -> Array:
	var i: Dictionary = batalha.info_acao(u, id)
	var p := PackedStringArray()
	var alc: int = i.get("alc", 1)
	p.append("em si" if alc == 0 else "alcance %d" % alc)
	if i.get("raio", 0) > 0:
		p.append("área %d" % i["raio"])
	if i.get("mp", 0) > 0:
		p.append("%d MP" % i["mp"])
	if i.get("recarga", 0) > 0:
		p.append("recarga %d" % i["recarga"])
	var desc: String = i.get("desc", "")
	if desc == "" and id == "ataque":
		desc = "Ataque básico."
	return [i.get("nome", id), desc + "\n" + " · ".join(p)]


func _mostrar_ajuda(id: String) -> void:
	var t: Array = _info_cmd.get(id, [])
	if t.is_empty():
		_ajuda_titulo.text = "Sua vez"
		_ajuda.text = "Clique numa casa azul para andar ou num alvo vermelho para o ataque básico."
		return
	_ajuda_titulo.text = t[0]
	_ajuda.text = t[1]
	if batalha and batalha.modo() == id and id != "mover":
		_ajuda.text += "\nClique no alvo marcado."


## Botão de comando: texto à esquerda, faixa vermelha e cursor ▶ no item ativo
## ou sob o mouse (como o dedo apontando dos menus de JRPG).
func _comando(texto: String, ativo: bool) -> Button:
	var bt := Button.new()
	bt.text = ("▶ " if ativo else "   ") + texto
	bt.alignment = HORIZONTAL_ALIGNMENT_LEFT
	bt.focus_mode = Control.FOCUS_NONE
	bt.add_theme_font_size_override("font_size", 15)
	var vazio := StyleBoxEmpty.new()
	vazio.content_margin_left = 6
	vazio.content_margin_top = 3
	vazio.content_margin_bottom = 3
	var faixa := StyleBoxFlat.new()
	faixa.bg_color = Color(TemaUI.VERMELHO, 0.55)
	faixa.border_color = TemaUI.OURO
	faixa.border_width_left = 3
	faixa.content_margin_left = 6
	faixa.content_margin_top = 3
	faixa.content_margin_bottom = 3
	faixa.set_corner_radius_all(2)
	bt.add_theme_stylebox_override("normal", faixa if ativo else vazio)
	bt.add_theme_stylebox_override("hover", faixa)
	bt.add_theme_stylebox_override("pressed", faixa)
	bt.add_theme_stylebox_override("disabled", vazio)
	bt.add_theme_color_override("font_color", TemaUI.OURO if ativo else TemaUI.CREME)
	bt.add_theme_color_override("font_hover_color", TemaUI.OURO)
	bt.mouse_entered.connect(func(): if not bt.disabled: bt.text = "▶ " + texto)
	bt.mouse_exited.connect(func(): bt.text = ("▶ " if ativo else "   ") + texto)
	return bt


# --- alvo e casa sob o mouse ------------------------------------------------------------

func hover(c: Vector2i) -> void:
	_hover = c
	if batalha == null:
		return
	_casa.text = batalha.info_casa(c)
	_painel_casa.visible = _casa.text != "" and _resultado == null
	var u: Unidade3D = batalha.unidade_em(c)
	var atual: Unidade3D = batalha.atual()
	# sem alvo sob o mouse, o cabeçalho mostra o adversário que está agindo
	if (u == null or u == atual) and atual and atual.enemy:
		u = atual
	elif u == atual:
		u = null
	_limpar(_painel_alvo)
	if u == null or _resultado != null:
		_painel_alvo.hide()
		return
	_painel_alvo.show()
	var pa := _painel_alvo as PainelMarajoara
	pa.destaque = _cor(u)
	pa.pulso = u == atual
	var v := VBoxContainer.new()
	_painel_alvo.add_child(v)
	_ficha(v, u)
	if u == atual:
		v.add_child(TemaUI.rotulo("Vez do adversário...", 15, TemaUI.INIMIGO))


## Cabeçalho de unidade: retrato, nome, papel, classe, nível, HP/MP e atributos.
func _ficha(parent: Control, u: Unidade3D) -> void:
	var e: Dictionary = batalha.estado(u)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	parent.add_child(h)
	var r := _retrato(u)
	r.custom_minimum_size = Vector2(72, 72)
	h.add_child(r)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	h.add_child(col)
	var prota: bool = u.especie == "bufalo"
	var nome := u.display_name + ("  ★" if prota else "")
	if e.get("papel", "") == "chefe":
		nome += "  · Boss"
	elif e.get("papel", "") == "lider":
		nome += "  · Líder"
	col.add_child(TemaUI.rotulo(nome, 19, _cor(u) if (u.enemy or prota) else TemaUI.CREME))
	var cls := Regras.classe(e.get("classe", u.classe))
	var mov: int = batalha.movimento(u) if not e.is_empty() else cls["mov"]
	var alc: int = batalha.info_acao(u, "ataque").get("alc", cls["alc"]) if not e.is_empty() else cls["alc"]
	col.add_child(TemaUI.rotulo("%s · Nível %d · Mov %d · Alcance %d" % [cls["nome"], e.get("nivel", 1), mov, alc], 14))
	col.add_child(BarraHud.criar(TemaUI.HP, e.get("hp", 0), e.get("hpmax", 1), 230.0, 15.0, true, "hp"))
	if e.get("mpmax", 0) > 0:
		col.add_child(BarraHud.criar(TemaUI.MP, e.get("mp", 0), e.get("mpmax", 1), 230.0, 15.0, true, "mp"))
	var ef: String = batalha.efeitos_texto(u) if not e.is_empty() else ""
	if ef != "":
		col.add_child(TemaUI.rotulo(ef, 13, TemaUI.OURO))
	var a: Dictionary = e.get("attrs", {})
	parent.add_child(TemaUI.rotulo("FOR %d  DES %d  CON %d  INT %d  SAB %d  CAR %d" % [a.get("forca", 0), a.get("destreza", 0), a.get("constituicao", 0), a.get("inteligencia", 0), a.get("sabedoria", 0), a.get("carisma", 0)], 13, Color(TemaUI.CREME, 0.8)))


# --- resultado --------------------------------------------------------------------------

func resultado_aberto() -> bool:
	return _resultado != null


func mostrar_resultado(vitoria: bool, resumo: Dictionary, estado: Dictionary) -> void:
	_painel_atual.hide()
	_painel_alvo.hide()
	_painel_casa.hide()
	_painel_cmd.hide()
	_grupo_box.hide()
	_resultado = PainelMarajoara.new(12.0, TemaUI.OURO if vitoria else TemaUI.INIMIGO)
	_resultado.set_anchors_preset(Control.PRESET_CENTER)
	_resultado.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_resultado.grow_vertical = Control.GROW_DIRECTION_BOTH
	_resultado.custom_minimum_size = Vector2(520, 0)
	_raiz.add_child(_resultado)
	(_resultado as PainelMarajoara).entrar()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_resultado.add_child(v)
	var t := TemaUI.rotulo("Vitória!" if vitoria else "Derrota", 34, TemaUI.OURO if vitoria else TemaUI.INIMIGO)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	v.add_child(FaixaMarajoara.new())
	if vitoria:
		for id in estado:
			v.add_child(TemaUI.rotulo("%s: +%d XP" % [D.HEROIS[id]["nome"], resumo.get("xp", 0)], 18))
		for n in resumo.get("niveis", []):
			v.add_child(TemaUI.rotulo("%s subiu para o nível %d!" % [D.HEROIS[n[0]]["nome"], n[1]], 18, TemaUI.OURO))
		for item in resumo.get("itens", {}):
			v.add_child(TemaUI.rotulo("Obtido: %s x%d" % [D.ITENS[item]["nome"], resumo["itens"][item]], 18))
		if resumo.get("recruta", "") != "":
			v.add_child(TemaUI.rotulo("%s entrou para o grupo!" % D.HEROIS[resumo["recruta"]]["nome"], 20, TemaUI.OURO))
		var bt := Button.new()
		bt.text = "Continuar para o mapa"
		bt.pressed.connect(batalha.voltar_ao_mapa)
		v.add_child(bt)
		bt.grab_focus()
	else:
		v.add_child(TemaUI.rotulo("O Búfalo caiu. O grupo recua para se recuperar.", 18))
		var h := HBoxContainer.new()
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_theme_constant_override("separation", 12)
		v.add_child(h)
		var b1 := Button.new()
		b1.text = "Tentar de novo"
		b1.pressed.connect(batalha.tentar_de_novo)
		h.add_child(b1)
		var b2 := Button.new()
		b2.text = "Voltar ao mapa"
		b2.pressed.connect(func():
			campanha.derrota()
			batalha.voltar_ao_mapa())
		h.add_child(b2)
		b1.grab_focus()
