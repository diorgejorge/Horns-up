class_name Loja
extends CanvasLayer
## Loja da cidade (Vila de Aruã no Ato I): compra poções com o ouro das lutas.
## Abre pelo mapa-múndi quando o grupo está numa região com loja (DadosAto1.LOJAS).
## Os dados (ouro, preços, inventário) vêm do autoload Campanha.

signal fechou

const D := preload("res://scripts/campanha/dados_ato1.gd")

var campanha: Node:
	get: return get_node("/root/Campanha")

var _lista: VBoxContainer
var _ouro: Label


func _ready() -> void:
	layer = 18
	var raiz := Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.theme = TemaUI.tema()
	add_child(raiz)
	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.5)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.add_child(fundo)
	var p := PanelContainer.new()
	TemaUI.aplicar_painel(p, false, TemaUI.OURO)
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.custom_minimum_size = Vector2(560, 0)
	raiz.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var t := TemaUI.rotulo("Loja — " + D.regiao(campanha.regiao_atual).get("nome", ""), 26, TemaUI.OURO)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	v.add_child(FaixaMarajoara.new())
	_ouro = TemaUI.rotulo("", 19, TemaUI.OURO)
	v.add_child(_ouro)
	_lista = VBoxContainer.new()
	_lista.add_theme_constant_override("separation", 8)
	v.add_child(_lista)
	var fechar := Button.new()
	fechar.text = "Fechar (Esc)"
	fechar.pressed.connect(_fechar)
	v.add_child(fechar)
	_atualizar()


func _atualizar() -> void:
	_ouro.text = "Ouro: %d" % campanha.ouro
	for c in _lista.get_children():
		c.queue_free()
	var loja: Dictionary = campanha.loja_aqui()
	for item in loja:
		var it: Dictionary = D.ITENS[item]
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(TemaUI.rotulo("%s  (você tem %d)" % [it["nome"], campanha.inventario.get(item, 0)], 18))
		var d := TemaUI.rotulo(it["desc"], 14, Color(TemaUI.CREME, 0.75))
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(d)
		h.add_child(col)
		var bt := Button.new()
		bt.text = "Comprar · %d ouro" % loja[item]
		bt.disabled = not campanha.pode_comprar(item)
		bt.pressed.connect(func():
			campanha.comprar(item)
			_atualizar())
		h.add_child(bt)
		_lista.add_child(h)


func _fechar() -> void:
	fechou.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_fechar()
