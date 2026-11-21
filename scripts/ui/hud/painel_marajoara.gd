class_name PainelMarajoara
extends PanelContainer
## Painel de pergaminho com moldura marajoara pintada (arte 2D do Diorge, em 9 fatias
## por ArteHud: os cantos não distorcem). Funciona como um PanelContainer comum: os
## filhos ficam dentro da moldura, com margem. `destaque` desenha um filete da cor
## pedida por dentro da moldura (ouro para o protagonista ou o elemento ativo, azul
## para aliados, vermelho para inimigos); `pulso` faz o filete pulsar (unidade da vez).

## Texturas de argila (a vitrine de modelos usa no pedestal).
const ARGILA := preload("res://assets/diorge/ui/texturas/clay_plaster_diff_1k.jpg")
const ARGILA_NOR := preload("res://assets/diorge/ui/texturas/clay_plaster_nor_gl_1k.jpg")

var borda := 12.0
## Peça da arte usada como fundo: "painel", "painel_p" (fina) ou "casa" (slot da fila).
var estilo := ""
var margem := 0.0:
	set(v):
		margem = v
		_aplicar_estilo()
var destaque := TemaUI.VERMELHO:
	set(v):
		destaque = v
		queue_redraw()

## Brilho pulsante na moldura (painel selecionado / unidade da vez).
var pulso := false:
	set(v):
		pulso = v
		set_process(v)
		queue_redraw()

var _t := 0.0
## Onde fica o filete de destaque em cada peça: recuo esq, cima, dir, baixo e raio.
const RECUO := {"painel": [17, 22, 15, 16, 10], "painel_p": [10, 13, 9, 9, 6], "casa": [2, 2, 2, 2, 9]}


func _init(borda_px := 12.0, cor := TemaUI.VERMELHO, peca := "") -> void:
	borda = borda_px
	estilo = peca if peca != "" else ("painel" if borda_px >= 10.0 else "painel_p")
	destaque = cor
	set_process(false)
	_aplicar_estilo()


func _aplicar_estilo() -> void:
	var sb := ArteHud.estilo(estilo)
	for lado in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		sb.set_content_margin(lado, sb.get_content_margin(lado) + margem * 0.5)
	add_theme_stylebox_override("panel", sb)


func _process(dt: float) -> void:
	_t += dt
	queue_redraw()


## Filete de destaque por dentro da moldura (a faixa vermelha da arte já é o padrão).
func _draw() -> void:
	if destaque in [TemaUI.VERMELHO, TemaUI.PRETO] and not pulso:
		return
	var m: Array = RECUO.get(estilo, RECUO["painel"])
	var dentro := Rect2(Vector2.ZERO, size).grow_individual(-m[0], -m[1], -m[2], -m[3])
	if dentro.size.x <= 4.0 or dentro.size.y <= 4.0:
		return
	var a := 0.9
	var largura := 2.0
	if pulso:
		var k := 0.5 + 0.5 * sin(_t * 5.0)
		a = 0.55 + 0.45 * k
		largura = 2.0 + 1.5 * k
	var c := destaque if destaque != TemaUI.VERMELHO else TemaUI.OURO
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = Color(c, a)
	sb.set_border_width_all(int(round(largura)))
	sb.set_corner_radius_all(m[4])
	sb.anti_aliasing = true
	draw_style_box(sb, dentro)


## Entrada animada: aparece e "assenta" com um leve zoom (escala no centro).
func entrar(atraso := 0.0) -> void:
	modulate.a = 0.0
	scale = Vector2(0.96, 0.96)
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): pivot_offset = size / 2.0).set_delay(atraso)
	tw.tween_property(self, "modulate:a", 1.0, 0.22).set_delay(atraso)
	tw.tween_property(self, "scale", Vector2.ONE, 0.32).set_delay(atraso)
