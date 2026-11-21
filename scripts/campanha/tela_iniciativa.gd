class_name TelaIniciativa
extends CanvasLayer
## Tela de iniciativa no começo da batalha (pedido do Diorge): cada unidade
## rola um d20 e soma a Destreza. O total define a ordem dos turnos.
##   var ordem = await tela.rolar(unidades, rng)   # devolve {unidade: total}
## Clique, Enter ou Espaço fecha depois que os dados param.

signal fechou

var auto := false
var _linhas := []        # [unidade, rótulo do dado, rótulo do total, valor do dado]
var _pronto := false
var _raiz: Control


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS


## Rola os dados de todas as unidades com animação e devolve {Unidade3D: total}.
func rolar(unidades: Array, rng: RandomNumberGenerator) -> Dictionary:
	var totais := {}
	var lista := unidades.duplicate()
	lista.sort_custom(func(a, b): return (not a.enemy and b.enemy) or (a.enemy == b.enemy and a.destreza > b.destreza))
	for u in lista:
		var d := rng.randi_range(1, 20)
		totais[u] = d + u.destreza
		_linhas.append([u, null, null, d])
	if auto:
		return totais
	_montar()
	# Dados girando por um tempo, depois param um a um.
	var t := 0.0
	var parado := 0
	while parado < _linhas.size():
		await get_tree().process_frame
		t += get_process_delta_time()
		for i in _linhas.size():
			var l: Array = _linhas[i]
			if i < parado:
				continue
			l[1].text = str(rng.randi_range(1, 20))
		if t > 0.9 + parado * 0.18:
			var l: Array = _linhas[parado]
			l[1].text = str(l[3])
			l[1].add_theme_color_override("font_color", ArteHud.TINTA_INIMIGO)
			l[2].text = "%d + %d = %d" % [l[3], l[0].destreza, totais[l[0]]]
			parado += 1
	_mostrar_ordem(totais)
	_pronto = true
	await fechou
	queue_free()
	return totais


func _montar() -> void:
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.theme = TemaUI.tema()
	add_child(_raiz)
	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.55)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.add_child(fundo)
	var p := PainelMarajoara.new(12.0, TemaUI.OURO)
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.custom_minimum_size = Vector2(640, 0)
	_raiz.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var topo := HBoxContainer.new()
	topo.alignment = BoxContainer.ALIGNMENT_CENTER
	topo.add_theme_constant_override("separation", 14)
	v.add_child(topo)
	topo.add_child(ArteHud.icone("d20", 64.0))
	var placa := PanelContainer.new()
	placa.add_theme_stylebox_override("panel", ArteHud.estilo("placa"))
	placa.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	topo.add_child(placa)
	var t := TemaUI.rotulo("Iniciativa · d20 + Destreza", 28, TemaUI.OURO)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placa.add_child(t)
	v.add_child(FaixaMarajoara.new())
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 40)
	g.add_theme_constant_override("v_separation", 6)
	v.add_child(g)
	for l in _linhas:
		var u: Unidade3D = l[0]
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		var prota: bool = u.especie == "bufalo"
		h.add_child(TemaUI.icone(u.display_name, TemaUI.INIMIGO if u.enemy else (TemaUI.OURO if prota else TemaUI.ALIADO), 34.0, prota))
		var nome := TemaUI.rotulo(u.display_name, 17, TemaUI.INIMIGO if u.enemy else TemaUI.CREME)
		nome.custom_minimum_size.x = 170
		h.add_child(nome)
		var dado := _dado()
		h.add_child(dado)
		var tot := TemaUI.rotulo("", 16, Color(TemaUI.CREME, 0.85))
		h.add_child(tot)
		g.add_child(h)
		l[1] = dado.get_child(0)
		l[2] = tot
	var dica := TemaUI.rotulo("", 15, Color(TemaUI.CREME, 0.7))
	dica.name = "Dica"
	dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(dica)
	var ordem := TemaUI.rotulo("", 16)
	ordem.name = "Ordem"
	ordem.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ordem.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(ordem)


## d20 pintado (cerâmica marajoara) com o número rolado na face da frente.
func _dado() -> TextureRect:
	var d := ArteHud.icone("d20", 46.0)
	var n := TemaUI.rotulo("?", 17)
	n.set_anchors_preset(Control.PRESET_FULL_RECT)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	d.add_child(n)
	return d


func _mostrar_ordem(totais: Dictionary) -> void:
	var o := totais.keys()
	o.sort_custom(func(a, b): return totais[a] > totais[b] or (totais[a] == totais[b] and a.destreza > b.destreza))
	var nomes := PackedStringArray()
	for u in o:
		nomes.append(u.display_name)
	_raiz.find_child("Ordem", true, false).text = "Ordem dos turnos: " + " → ".join(nomes)
	_raiz.find_child("Dica", true, false).text = "Clique ou Enter para começar a batalha"


func _input(event: InputEvent) -> void:
	if not _pronto:
		return
	var ok: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE])
	if ok:
		get_viewport().set_input_as_handled()
		_pronto = false
		fechou.emit()
