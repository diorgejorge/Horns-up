class_name CaixaDialogo
extends CanvasLayer
## Caixa de diálogo na parte de baixo da tela. Uso:
##   await dialogo.mostrar([["bufalo", "texto"], ["", "narração"]])
## Clique, Enter ou Espaço avança (o primeiro toque completa o texto).
## Clima de drama: o jogo fica PAUSADO (get_tree().paused) enquanto a caixa está
## aberta, entram faixas de cinema e um escurecimento nas bordas, o rosto de quem
## fala aproxima devagar e o texto respira nas pontuações.

signal comecou
signal terminou

const FAIXA := 72.0  # altura das faixas de cinema
const PAUSAS := {".": 0.28, "!": 0.3, "?": 0.3, ",": 0.1, ";": 0.14, ":": 0.14, "…": 0.4}

const D := preload("res://scripts/campanha/dados_ato1.gd")
const CPS := 55.0  # letras por segundo

var _linhas: Array = []
var _i := 0
var _painel: PanelContainer
var _nome: Label
var _texto: Label
var _dica: Label
var _icone: IconeUnidade
var _retrato: RetratoModelo
var _moldura: Control
var _t := 0.0
var _letra_t := 0.0  # tempo acumulado até a próxima letra
var _cima: ColorRect
var _baixo: ColorRect
var _sombra: ColorRect
var _pausou := false
var _anim: Tween
var auto := false  # avança sozinho (testes automáticos)


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var raiz := Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.theme = TemaUI.tema()
	add_child(raiz)
	_sombra = ColorRect.new()
	_sombra.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sombra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := ShaderMaterial.new()
	sh.shader = Shader.new()
	sh.shader.code = """shader_type canvas_item;
uniform float forca = 1.0;
void fragment() {
	vec2 d = (UV - vec2(0.5, 0.42)) * vec2(1.0, 1.25);
	float v = smoothstep(0.25, 0.85, length(d));
	COLOR = vec4(0.02, 0.0, 0.03, (0.22 + 0.55 * v) * forca);
}"""
	_sombra.material = sh
	raiz.add_child(_sombra)
	_cima = _faixa(raiz, true)
	_baixo = _faixa(raiz, false)
	_painel = PanelContainer.new()
	_painel.anchor_left = 0.15
	_painel.anchor_right = 0.85
	_painel.anchor_top = 1.0
	_painel.anchor_bottom = 1.0
	_painel.offset_top = -210
	_painel.offset_bottom = -24
	TemaUI.aplicar_painel(_painel)
	raiz.add_child(_painel)
	var v := VBoxContainer.new()
	_painel.add_child(v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(h)
	_retrato = RetratoModelo.new()
	_retrato.custom_minimum_size = Vector2(128, 128)
	_moldura = ArteHud.retrato_redondo(_retrato, 136.0)  # anel de cerâmica da arte
	h.add_child(_moldura)
	_icone = TemaUI.icone("?", TemaUI.ALIADO, 96.0)
	_icone.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(_icone)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(col)
	_nome = TemaUI.rotulo("", 22, TemaUI.OURO)
	col.add_child(_nome)
	_texto = TemaUI.rotulo("", 21)
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_texto)
	_dica = TemaUI.rotulo("▼ clique / Enter", 14, Color(TemaUI.CREME, 0.6))
	_dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(_dica)
	_painel.hide()
	_cena(0.0, 0.0)


func _faixa(raiz: Control, em_cima: bool) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color.BLACK
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.anchor_right = 1.0
	r.anchor_top = 0.0 if em_cima else 1.0
	r.anchor_bottom = r.anchor_top
	raiz.add_child(r)
	return r


## Aplica o quanto o "modo cinema" está ligado (0 = jogo, 1 = drama).
func _cena(k: float, _x := 0.0) -> void:
	_cima.offset_bottom = FAIXA * k
	_baixo.offset_top = -FAIXA * k
	(_sombra.material as ShaderMaterial).set_shader_parameter("forca", k)
	_sombra.visible = k > 0.0
	_painel.modulate.a = clampf(k * 1.5 - 0.3, 0.0, 1.0)


func mostrar(linhas: Array) -> void:
	if linhas.is_empty():
		return
	_linhas = linhas
	_i = 0
	_pausou = not get_tree().paused
	get_tree().paused = true
	_painel.show()
	_exibir()
	comecou.emit()
	_animar(1.0, 0.45)
	await terminou


func _animar(alvo: float, dur: float) -> Tween:
	if _anim:
		_anim.kill()
	var de: float = _sombra.material.get_shader_parameter("forca")
	_anim = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_anim.tween_method(_cena, de, alvo, dur if not auto else 0.01)
	return _anim


func ativo() -> bool:
	return _painel.visible


func _exibir() -> void:
	var l: Array = _linhas[_i]
	var quem: String = l[0]
	_nome.text = D.FALANTES.get(quem, quem)
	_texto.text = l[1]
	_texto.visible_characters = 0
	_t = 0.0
	_letra_t = 0.0
	var tem_modelo: bool = D.RETRATOS.has(quem)
	_moldura.visible = tem_modelo
	if tem_modelo:
		_retrato.mostrar(D.RETRATOS[quem])
	_icone.visible = quem != "" and not tem_modelo
	_icone.nome = _nome.text
	_icone.cor = TemaUI.INIMIGO if quem in ["mapinguari", "voz"] else (TemaUI.OURO if quem == "bufalo" else TemaUI.ALIADO)
	_icone.destaque = quem == "bufalo"
	_icone.queue_redraw()
	_texto.add_theme_color_override("font_color", ArteHud.TINTA if quem != "" else Color(ArteHud.TINTA, 0.7))


func _process(delta: float) -> void:
	if not _painel.visible:
		return
	_t += delta
	_letra_t += delta
	var total := _texto.text.length()
	# Letra a letra, com respiro depois de cada pontuação.
	while _texto.visible_characters < total:
		var c := _texto.text[_texto.visible_characters - 1] if _texto.visible_characters > 0 else ""
		var custo: float = 1.0 / CPS + PAUSAS.get(c, 0.0)
		if _letra_t < custo:
			break
		_letra_t -= custo
		_texto.visible_characters += 1
	_dica.visible = _texto.visible_characters >= total
	if auto and _t > 0.15:
		_avancar()


func _avancar() -> void:
	if _texto.visible_characters < _texto.text.length():
		_texto.visible_characters = _texto.text.length()
		return
	_i += 1
	if _i >= _linhas.size():
		_painel.hide()
		await _animar(0.0, 0.35).finished
		if _pausou:
			get_tree().paused = false
		terminou.emit()
	else:
		_exibir()


func _input(event: InputEvent) -> void:
	if not _painel.visible:
		return
	var ok := false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		ok = true
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE]:
		ok = true
	if ok:
		get_viewport().set_input_as_handled()
		_avancar()
