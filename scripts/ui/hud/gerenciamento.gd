extends Control
## Tela de gerenciamento fora da batalha (seção 7.2 do roteiro), organizada
## como em Ogre Battle: grupo à esquerda, personagem selecionado no centro,
## abas à direita (Status, Equipamento, Inventário, Habilidades), missão embaixo
## e atalho para o mapa. Tudo lido e escrito no autoload Campanha.
## Teclas: ↑/↓ troca o herói, 1-4 troca a aba, M ou Esc volta ao mapa.

const D := preload("res://scripts/campanha/dados_ato1.gd")
const MAPA := "res://scenes/3d/ato1/mapa_arua.tscn"
const ABAS := ["Status", "Equipamento", "Inventário", "Habilidades"]
const SLOTS_INV := 24

## Autoload Campanha (por get_node: o script compila também no modo headless).
var campanha: Node:
	get: return get_node("/root/Campanha")

var _sel := ""          # herói selecionado
var _aba := "Status"
var _item := ""         # item selecionado no inventário
var _ordem_inv: Array = []  # ordem de exibição do inventário (Organizar ordena)

var _regiao: Label
var _etapa: Label
var _lista: VBoxContainer
var _vitrine: VitrineModelo
var _info: VBoxContainer
var _abas_bar: HBoxContainer
var _conteudo: VBoxContainer
var _missao: VBoxContainer
var _confirmar: ConfirmationDialog
var _pendente := false


func _ready() -> void:
	theme = TemaUI.tema()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_sel = _protagonista()
	_montar()
	campanha.mudou.connect(_agendar)
	_atualizar()


func _protagonista() -> String:
	for id in D.HEROIS:
		if D.HEROIS[id].get("protagonista", false):
			return id
	return campanha.grupo()[0]


# --- montagem --------------------------------------------------------------------------

func _montar() -> void:
	var fundo := ColorRect.new()
	fundo.color = Color(0.06, 0.04, 0.03)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)

	var raiz := VBoxContainer.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.offset_left = 14
	raiz.offset_top = 10
	raiz.offset_right = -14
	raiz.offset_bottom = -10
	raiz.add_theme_constant_override("separation", 8)
	add_child(raiz)

	# Barra superior: região, etapa e acesso ao mapa (não há ouro nem dias no jogo ainda).
	var topo := PainelMarajoara.new(10.0)
	raiz.add_child(topo)
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 20)
	topo.add_child(th)
	var titulo := TemaUI.rotulo("Grupo · Arquipélago de Aruã", 24, TemaUI.OURO)
	th.add_child(titulo)
	_regiao = TemaUI.rotulo("", 19)
	_regiao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	th.add_child(_regiao)
	_etapa = TemaUI.rotulo("", 17, Color(TemaUI.CREME, 0.8))
	th.add_child(_etapa)
	var bm := Button.new()
	bm.text = "Mapa (M)"
	bm.tooltip_text = "Voltar ao mapa-múndi"
	bm.pressed.connect(_ir_mapa)
	th.add_child(bm)

	var meio := HBoxContainer.new()
	meio.size_flags_vertical = Control.SIZE_EXPAND_FILL
	meio.add_theme_constant_override("separation", 8)
	raiz.add_child(meio)

	# Esquerda: lista do grupo
	var esq := PainelMarajoara.new()
	esq.custom_minimum_size.x = 370
	meio.add_child(esq)
	var ev := VBoxContainer.new()
	ev.add_theme_constant_override("separation", 6)
	esq.add_child(ev)
	ev.add_child(TemaUI.rotulo("Grupo", 22, TemaUI.OURO))
	ev.add_child(FaixaMarajoara.new())
	_lista = VBoxContainer.new()
	_lista.add_theme_constant_override("separation", 6)
	ev.add_child(_lista)

	# Centro: personagem selecionado
	var centro := PainelMarajoara.new(12.0, TemaUI.OURO)
	centro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meio.add_child(centro)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 8)
	centro.add_child(cv)
	_vitrine = VitrineModelo.new()
	_vitrine.custom_minimum_size = Vector2(0, 330)
	_vitrine.tooltip_text = "Arraste para girar"
	cv.add_child(_vitrine)
	_info = VBoxContainer.new()
	_info.add_theme_constant_override("separation", 4)
	cv.add_child(_info)

	# Direita: abas
	var dir := PainelMarajoara.new()
	dir.custom_minimum_size.x = 560
	meio.add_child(dir)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 8)
	dir.add_child(dv)
	_abas_bar = HBoxContainer.new()
	_abas_bar.add_theme_constant_override("separation", 6)
	dv.add_child(_abas_bar)
	dv.add_child(FaixaMarajoara.new())
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dv.add_child(sc)
	_conteudo = VBoxContainer.new()
	_conteudo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_conteudo.add_theme_constant_override("separation", 8)
	sc.add_child(_conteudo)

	# Baixo: painel de missão
	var baixo := PainelMarajoara.new(10.0)
	raiz.add_child(baixo)
	_missao = VBoxContainer.new()
	baixo.add_child(_missao)

	# Entrada em cascata dos painéis.
	var atraso := 0.0
	for p in [topo, esq, centro, dir, baixo]:
		p.entrar(atraso)
		atraso += 0.06

	_confirmar = ConfirmationDialog.new()
	_confirmar.ok_button_text = "Descartar"
	_confirmar.cancel_button_text = "Cancelar"
	_confirmar.confirmed.connect(_descartar_confirmado)
	add_child(_confirmar)


func _limpar(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()


## Várias mudanças seguidas na Campanha viram uma atualização só.
func _agendar() -> void:
	if not _pendente:
		_pendente = true
		_atualizar.call_deferred()


func _atualizar() -> void:
	_pendente = false
	if not _sel in campanha.grupo():
		_sel = _protagonista()
	var r: Dictionary = D.regiao(campanha.regiao_atual)
	_regiao.text = "Região atual: " + r.get("nome", "?")
	_etapa.text = campanha.etapa_texto()
	_preencher_lista()
	_preencher_personagem()
	_preencher_abas()
	_preencher_missao()


# --- grupo -----------------------------------------------------------------------------

func _preencher_lista() -> void:
	_limpar(_lista)
	for id in campanha.grupo():
		var h: Dictionary = campanha.herois[id]
		var prota: bool = D.HEROIS[id].get("protagonista", false)
		var sel: bool = id == _sel
		var card := PainelMarajoara.new(6.0, TemaUI.OURO if sel else (TemaUI.VERMELHO if prota else TemaUI.PRETO))
		card.margem = 6.0
		card.pulso = sel
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT: _selecionar(id))
		_lista.add_child(card)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(hb)
		var ret := RetratoModelo.new()
		ret.custom_minimum_size = Vector2(72, 72)
		ret.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(ret)
		ret.mostrar(D.HEROIS[id]["modelo"])
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 1)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(col)
		var nome: String = ("▶ " if sel else "") + D.HEROIS[id]["nome"] + ("  ★" if prota else "")
		col.add_child(TemaUI.rotulo(nome, 18, TemaUI.OURO if (sel or prota) else TemaUI.CREME))
		col.add_child(TemaUI.rotulo("%s · Nível %d" % [Regras.classe(campanha.classe(id))["nome"], h["nivel"]], 14))
		col.add_child(_barra("HP", TemaUI.HP, h["hp"], campanha.hp_max(id), 150.0))
		if campanha.mp_max(id) > 0:
			col.add_child(_barra("MP", TemaUI.MP, h["mp"], campanha.mp_max(id), 150.0))
	var n: int = campanha.grupo().size()
	_lista.add_child(TemaUI.rotulo("%d de 8 vagas na batalha" % n if n > 1 else "Os aliados entram para o grupo pela história.", 13, Color(TemaUI.CREME, 0.55)))


func _selecionar(id: String) -> void:
	_sel = id
	_atualizar()


func _barra(rot: String, cor: Color, v: int, m: int, larg := 170.0) -> Control:
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(TemaUI.rotulo(rot, 13))
	h.add_theme_constant_override("separation", 6)
	h.add_child(BarraHud.criar(cor, v, m, larg, 15.0))
	return h


# --- personagem selecionado ------------------------------------------------------------------

func _preencher_personagem() -> void:
	var id := _sel
	var h: Dictionary = campanha.herois[id]
	var dados: Dictionary = D.HEROIS[id]
	var prota: bool = dados.get("protagonista", false)
	_vitrine.mostrar(dados["modelo"], TemaUI.OURO if prota else TemaUI.ALIADO)
	_limpar(_info)
	var nome := TemaUI.rotulo(dados["nome"], 30, TemaUI.OURO if prota else TemaUI.CREME)
	nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.add_child(nome)
	if prota:
		var p := TemaUI.rotulo("★ Protagonista", 15, TemaUI.OURO)
		p.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_info.add_child(p)
	var cl := TemaUI.rotulo("Classe: %s  ·  Nível %d" % [Regras.classe(campanha.classe(id))["nome"], h["nivel"]], 18)
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.add_child(cl)
	_info.add_child(FaixaMarajoara.new())
	var bars := VBoxContainer.new()
	bars.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_info.add_child(bars)
	bars.add_child(_barra("HP", TemaUI.HP, h["hp"], campanha.hp_max(id), 240.0))
	if campanha.mp_max(id) > 0:
		bars.add_child(_barra("MP", TemaUI.MP, h["mp"], campanha.mp_max(id), 240.0))
	bars.add_child(_barra("XP", TemaUI.XP, h["xp"], Regras.XP_POR_NIVEL, 240.0))
	# Atributos D&D: total (base + equipamento) e modificador.
	var total: Dictionary = campanha.atributos(id)
	var g := GridContainer.new()
	g.columns = 2
	g.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	g.add_theme_constant_override("h_separation", 34)
	g.add_theme_constant_override("v_separation", 2)
	_info.add_child(g)
	for k in HudDados.NOMES_ATR:
		var base: int = h["atributos"][k]
		var t: int = total[k]
		var txt := "%s  %d  (%+d)" % [HudDados.NOMES_ATR[k], t, Regras.mod(t)]
		if t != base:
			txt += "  equip. %+d" % (t - base)
		var l := TemaUI.rotulo(txt, 17, TemaUI.OURO if k == "destreza" else TemaUI.CREME)
		if k == "destreza":
			l.tooltip_text = "Destreza define a ordem dos turnos na batalha."
			l.mouse_filter = Control.MOUSE_FILTER_PASS
		g.add_child(l)


# --- abas ---------------------------------------------------------------------------------

func _preencher_abas() -> void:
	_limpar(_abas_bar)
	for i in ABAS.size():
		var a: String = ABAS[i]
		var bt := Button.new()
		bt.text = ("▶ " if a == _aba else "") + "%s [%d]" % [a, i + 1]
		bt.focus_mode = Control.FOCUS_NONE
		if a == _aba:
			bt.add_theme_color_override("font_color", TemaUI.OURO)
			bt.add_theme_color_override("font_hover_color", TemaUI.OURO)
		bt.pressed.connect(_trocar_aba.bind(a))
		_abas_bar.add_child(bt)
	_limpar(_conteudo)
	match _aba:
		"Status": _aba_status()
		"Equipamento": _aba_equipamento()
		"Inventário": _aba_inventario()
		"Habilidades": _aba_habilidades()


func _trocar_aba(a: String) -> void:
	_aba = a
	_preencher_abas()


func _titulo(t: String) -> void:
	_conteudo.add_child(TemaUI.rotulo(t, 21, TemaUI.OURO))


func _texto(t: String, tam := 16, cor := TemaUI.CREME) -> Label:
	var l := TemaUI.rotulo(t, tam, cor)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 480
	_conteudo.add_child(l)
	return l


func _aba_status() -> void:
	var id := _sel
	var h: Dictionary = campanha.herois[id]
	var cls := Regras.classe(campanha.classe(id))
	_titulo("Status de " + D.HEROIS[id]["curto"])
	var linhas := [
		["Ataque da arma", "%+d" % campanha.ataque_bonus(id)],
		["Defesa do equipamento", "%+d" % campanha.defesa_bonus(id)],
		["Movimento", "%d casas" % cls["mov"]],
		["Alcance do ataque básico", "%d casa%s" % [cls["alc"], "" if cls["alc"] == 1 else "s"]],
		["Atributo de ataque", HudDados.NOMES_ATR.get(cls["atk"], cls["atk"])],
		["Usa MP", "sim" if cls["mp"] else "não"],
		["Experiência", "%d / %d para o nível %d" % [h["xp"], Regras.XP_POR_NIVEL, h["nivel"] + 1]],
	]
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 24)
	_conteudo.add_child(g)
	for l in linhas:
		g.add_child(TemaUI.rotulo(l[0], 16, Color(TemaUI.CREME, 0.75)))
		g.add_child(TemaUI.rotulo(l[1], 16))
	var cres := Regras.crescimento(campanha.classe(id))
	var p := PackedStringArray()
	for k in cres:
		p.append("%s +%d" % [HudDados.SIGLAS[k], cres[k]])
	_texto("Ao subir de nível: " + ", ".join(p) + ".", 15, Color(TemaUI.CREME, 0.7))
	if id == "bufalo" or D.HEROIS[id].get("protagonista", false):
		_texto("Se o Búfalo cair na batalha, a batalha está perdida.", 15, TemaUI.INIMIGO)


func _aba_equipamento() -> void:
	var id := _sel
	_titulo("Equipamento de " + D.HEROIS[id]["curto"])
	if not campanha.fora_da_batalha():
		_texto("O equipamento só pode ser trocado fora da batalha.", 16, TemaUI.INIMIGO)
	var agora := HudDados.previa(campanha, id)
	for slot in D.SLOTS:
		var item: String = campanha.herois[id]["equipamento"].get(slot, "")
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_conteudo.add_child(row)
		row.add_child(_icone(D.ITENS[item]["tipo"] if item != "" else "", 0, 48.0))
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		col.add_child(TemaUI.rotulo(D.SLOTS[slot], 14, Color(TemaUI.CREME, 0.65)))
		col.add_child(TemaUI.rotulo(D.ITENS[item]["nome"] if item != "" else "— vazio —", 18, TemaUI.CREME if item != "" else Color(TemaUI.CREME, 0.45)))
		if item != "":
			var bt := Button.new()
			bt.text = "Tirar"
			bt.disabled = not campanha.fora_da_batalha()
			bt.tooltip_text = HudDados.diferenca(agora, HudDados.previa(campanha, id, slot, ""))
			bt.pressed.connect(func(): campanha.desequipar(slot, id))
			row.add_child(bt)
	_conteudo.add_child(FaixaMarajoara.new())
	_titulo("Trocar por (inventário)")
	var algum := false
	for item in _itens_ordenados():
		if D.ITENS[item]["tipo"] == "consumivel" or not campanha.pode_equipar(item, id):
			continue
		algum = true
		var slot: String = D.ITENS[item]["tipo"]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_conteudo.add_child(row)
		row.add_child(_icone(slot, campanha.inventario[item], 40.0))
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		col.add_child(TemaUI.rotulo("%s (%s)" % [D.ITENS[item]["nome"], D.SLOTS[slot]], 16))
		var dif := HudDados.diferenca(agora, HudDados.previa(campanha, id, slot, item))
		col.add_child(TemaUI.rotulo(dif, 14, TemaUI.OURO))
		var bt := Button.new()
		bt.text = "Equipar"
		bt.disabled = not campanha.fora_da_batalha()
		bt.pressed.connect(func(): campanha.equipar(item, id))
		row.add_child(bt)
	if not algum:
		_texto("Nenhum item do inventário serve para %s agora." % D.HEROIS[id]["curto"], 15, Color(TemaUI.CREME, 0.6))


func _icone(tipo: String, qtd: int, tam: float) -> IconeItem:
	var ic := IconeItem.new()
	ic.tipo = tipo
	ic.qtd = qtd
	ic.vazio = tipo == ""
	ic.custom_minimum_size = Vector2(tam, tam)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return ic


## Itens na ordem de exibição: a ordem guardada (Organizar) e os novos no fim.
func _itens_ordenados() -> Array:
	var out := []
	for k in _ordem_inv:
		if campanha.inventario.has(k):
			out.append(k)
	for k in campanha.inventario:
		if not k in out:
			out.append(k)
	_ordem_inv = out
	return out


func _organizar() -> void:
	var tipos := ["consumivel", "arma", "armadura", "acessorio"]
	_ordem_inv = campanha.inventario.keys()
	_ordem_inv.sort_custom(func(a, b):
		var ta := tipos.find(D.ITENS[a]["tipo"])
		var tb := tipos.find(D.ITENS[b]["tipo"])
		return ta < tb if ta != tb else D.ITENS[a]["nome"] < D.ITENS[b]["nome"])
	_preencher_abas()


func _aba_inventario() -> void:
	_titulo("Inventário")
	if not campanha.fora_da_batalha():
		_texto("O inventário só pode ser usado fora da batalha.", 16, TemaUI.INIMIGO)
	var itens := _itens_ordenados()
	if _item != "" and not campanha.inventario.has(_item):
		_item = ""
	var g := GridContainer.new()
	g.columns = 6
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	_conteudo.add_child(g)
	for i in SLOTS_INV:
		var item: String = itens[i] if i < itens.size() else ""
		var bt := Button.new()
		bt.custom_minimum_size = Vector2(76, 76)
		bt.focus_mode = Control.FOCUS_NONE
		if item != "":
			bt.tooltip_text = D.ITENS[item]["nome"]
			bt.pressed.connect(func():
				_item = item
				_preencher_abas())
			if item == _item:
				var st := TemaUI.painel(true, TemaUI.OURO)
				st.set_content_margin_all(2)
				bt.add_theme_stylebox_override("normal", st)
				bt.add_theme_stylebox_override("hover", st)
		else:
			bt.disabled = true
		var ic := _icone(D.ITENS[item]["tipo"] if item != "" else "", campanha.inventario.get(item, 0), 76.0)
		ic.set_anchors_preset(Control.PRESET_FULL_RECT)
		bt.add_child(ic)
		g.add_child(bt)
	_conteudo.add_child(FaixaMarajoara.new())
	if _item == "":
		_texto("Selecione um item para ver a descrição." if not itens.is_empty() else "O inventário está vazio.", 15, Color(TemaUI.CREME, 0.6))
	else:
		var it: Dictionary = D.ITENS[_item]
		var tipo_txt: String = D.SLOTS.get(it["tipo"], "Consumível")
		_conteudo.add_child(TemaUI.rotulo("%s  ×%d" % [it["nome"], campanha.inventario[_item]], 20, TemaUI.OURO))
		_texto(tipo_txt + " · " + it.get("desc", ""), 15)
	var acoes := HBoxContainer.new()
	acoes.add_theme_constant_override("separation", 8)
	_conteudo.add_child(acoes)
	if _item != "":
		var tipo: String = D.ITENS[_item]["tipo"]
		if tipo == "consumivel":
			var bu := Button.new()
			bu.text = "Usar em " + D.HEROIS[_sel]["curto"]
			bu.disabled = not campanha.pode_usar(_item, _sel)
			if bu.disabled and campanha.herois[_sel]["hp"] >= campanha.hp_max(_sel):
				bu.tooltip_text = "%s já está com o HP cheio." % D.HEROIS[_sel]["curto"]
			bu.pressed.connect(func(): campanha.usar_item(_item, _sel))
			acoes.add_child(bu)
		elif campanha.pode_equipar(_item, _sel):
			var be := Button.new()
			be.text = "Equipar em " + D.HEROIS[_sel]["curto"]
			be.disabled = not campanha.fora_da_batalha()
			be.pressed.connect(func(): campanha.equipar(_item, _sel))
			acoes.add_child(be)
		var bd := Button.new()
		bd.text = "Descartar"
		bd.disabled = not campanha.fora_da_batalha()
		bd.pressed.connect(func():
			_confirmar.dialog_text = "Descartar 1 × %s? Não dá para desfazer." % D.ITENS[_item]["nome"]
			_confirmar.popup_centered())
		acoes.add_child(bd)
	var bo := Button.new()
	bo.text = "Organizar"
	bo.disabled = itens.size() < 2
	bo.pressed.connect(_organizar)
	acoes.add_child(bo)
	var bf := Button.new()
	bf.text = "Fechar"
	bf.pressed.connect(func():
		_item = ""
		_trocar_aba("Status"))
	acoes.add_child(bf)


func _descartar_confirmado() -> void:
	if _item != "" and campanha.fora_da_batalha():
		campanha.remover_item(_item)
		campanha.salvar()


func _aba_habilidades() -> void:
	var id := _sel
	_titulo("Habilidades de " + D.HEROIS[id]["curto"])
	for acao in Combate.acoes(id):
		var i := Combate.info(id, acao)
		if not i.is_empty():
			_habilidade_linha("Ataque básico" if acao == "ataque" else "Habilidade", i)
	_texto("As habilidades são usadas na batalha. MP volta ao máximo ao fim de cada batalha e ao descansar na vila.", 14, Color(TemaUI.CREME, 0.6))


func _habilidade_linha(tipo: String, h: Dictionary) -> void:
	var p := PainelMarajoara.new(6.0, TemaUI.PRETO)
	p.margem = 6.0
	_conteudo.add_child(p)
	var v := VBoxContainer.new()
	p.add_child(v)
	var alc: int = h.get("alc", 0)
	var custo := PackedStringArray([tipo, "em si mesmo" if alc == 0 else "alcance %d" % alc])
	if h.get("raio", 0) > 0:
		custo.append("área %d" % h["raio"])
	if h.get("recarga", 0) > 0:
		custo.append("recarga %d turnos" % h["recarga"])
	v.add_child(TemaUI.rotulo(Combate.rotulo(h), 18, TemaUI.OURO))
	v.add_child(TemaUI.rotulo(" · ".join(custo), 14, Color(TemaUI.CREME, 0.7)))
	if h.get("desc", "") != "":
		var d := TemaUI.rotulo(h["desc"], 15)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size.x = 460
		v.add_child(d)


# --- missão e navegação ----------------------------------------------------------------------

func _preencher_missao() -> void:
	_limpar(_missao)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	_missao.add_child(h)
	h.add_child(TemaUI.rotulo("Missão principal", 18, TemaUI.OURO))
	var o := TemaUI.rotulo(campanha.objetivo_atual(), 17)
	o.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(o)
	var prox: int = campanha.proxima_batalha()
	if prox > 0:
		var r: Dictionary = D.regiao(D.BATALHAS[prox]["regiao"])
		var aqui: bool = r["id"] == campanha.regiao_atual
		h.add_child(TemaUI.rotulo("Destino: " + r["nome"] + (" (aqui)" if aqui else ""), 16, Color(TemaUI.CREME, 0.8)))


func _ir_mapa() -> void:
	get_tree().change_scene_to_file(MAPA)


func _unhandled_input(event: InputEvent) -> void:
	if _confirmar.visible or not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_M, KEY_ESCAPE:
			_ir_mapa()
		KEY_UP, KEY_DOWN:
			var g: Array = campanha.grupo()
			var i := g.find(_sel)
			_selecionar(g[posmod(i + (1 if event.keycode == KEY_DOWN else -1), g.size())])
		KEY_1, KEY_2, KEY_3, KEY_4:
			_trocar_aba(ABAS[event.keycode - KEY_1])
