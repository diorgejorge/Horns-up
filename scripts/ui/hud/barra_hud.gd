class_name BarraHud
extends Control
## Barra de HP/MP/XP no estilo de RPG moderno: fundo afundado, preenchimento
## com gradiente e brilho de vidro, marcas a cada 10% e "rastro" que desce
## devagar quando o valor cai (mostra o dano recebido). Texto atual/máx dentro.

var cor := TemaUI.HP
var maximo := 1
var valor := 0
var texto := true
var _rastro := 0.0   # valor mostrado pelo rastro (anima até `valor`)


static func criar(c: Color, v: int, m: int, largura := 160.0, altura := 14.0, com_texto := true) -> BarraHud:
	var b := BarraHud.new()
	b.cor = c
	b.maximo = maxi(m, 1)
	b.valor = clampi(v, 0, b.maximo)
	b._rastro = b.valor
	b.texto = com_texto
	b.custom_minimum_size = Vector2(largura, altura)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return b


## Atualiza o valor; se caiu, o rastro claro desce atrás em meio segundo.
func definir(v: int, m := -1) -> void:
	if m > 0:
		maximo = m
	var antes := valor
	valor = clampi(v, 0, maximo)
	if valor < antes:
		var tw := create_tween()
		tw.tween_interval(0.25)
		tw.tween_method(func(x): _rastro = x; queue_redraw(), float(antes), float(valor), 0.5)
	else:
		_rastro = valor
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var raio := size.y * 0.5
	# fundo afundado (sombra em cima, luz embaixo)
	_caixa(r, TemaUI.PRETO, raio)
	_caixa(r.grow(-1.0), Color(0.16, 0.1, 0.07), raio)
	draw_rect(Rect2(r.position + Vector2(raio, 1), Vector2(r.size.x - raio * 2, 1.5)), Color(0, 0, 0, 0.5))
	var dentro := r.grow(-2.0)
	var f := float(valor) / maximo
	var fr := float(_rastro) / maximo
	if fr > f:
		_caixa(Rect2(dentro.position, Vector2(dentro.size.x * fr, dentro.size.y)), Color(1, 0.95, 0.8, 0.75), raio)
	if f > 0.0:
		var w := maxf(dentro.size.x * f, dentro.size.y)
		var cheio := Rect2(dentro.position, Vector2(w, dentro.size.y))
		_caixa(cheio, cor.darkened(0.25), raio)
		# metade de cima mais clara + reflexo de vidro
		_caixa(Rect2(cheio.position, Vector2(w, cheio.size.y * 0.55)), cor.lightened(0.12), raio)
		draw_rect(Rect2(cheio.position + Vector2(raio * 0.6, 1.0), Vector2(maxf(w - raio * 1.2, 0), maxf(cheio.size.y * 0.18, 1.0))), Color(1, 1, 1, 0.35))
	# marcas a cada 10%
	for i in range(1, 10):
		var x := dentro.position.x + dentro.size.x * i / 10.0
		draw_line(Vector2(x, dentro.position.y + 1), Vector2(x, dentro.end.y - 1), Color(0, 0, 0, 0.25), 1.0)
	if texto and size.y >= 11.0:
		var fonte := ThemeDB.fallback_font
		var fs := int(size.y * 0.82)
		var t := "%d/%d" % [valor, maximo]
		var tw := fonte.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var p := Vector2(size.x - tw - raio * 0.8, size.y * 0.5 + fs * 0.36)
		draw_string_outline(fonte, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, TemaUI.PRETO)
		draw_string(fonte, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, TemaUI.CREME)


## Retângulo de pontas arredondadas (cápsula).
func _caixa(r: Rect2, c: Color, raio: float) -> void:
	raio = minf(raio, r.size.y * 0.5)
	if r.size.x <= raio * 2.0:
		draw_circle(r.get_center(), r.size.y * 0.5, c)
		return
	draw_rect(Rect2(r.position + Vector2(raio, 0), Vector2(r.size.x - raio * 2, r.size.y)), c)
	draw_circle(r.position + Vector2(raio, r.size.y * 0.5), raio, c)
	draw_circle(Vector2(r.end.x - raio, r.position.y + r.size.y * 0.5), raio, c)
