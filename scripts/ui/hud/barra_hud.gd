class_name BarraHud
extends Control
## Barra de HP/MP/XP no estilo de RPG moderno: fundo afundado, preenchimento
## com gradiente e brilho de vidro, marcas a cada 10% e "rastro" que desce
## devagar quando o valor cai (mostra o dano recebido). Texto atual/máx dentro.
## Com `arte` (padrão), o fundo é o tubo de cerâmica pintado (tubo_hp / tubo_mp do
## ArteHud): tampa marajoara à esquerda e o líquido correndo no canal.

## Tubo pintado (191 x 46 px): tampa até x=30, ponta a partir de x=176, canal em
## x 29..177 e y 15..31.
const TUBO_TAMPA := 30.0
const TUBO_PONTA := 15.0
const TUBO_CANAL := Rect2(29, 15, 148, 16)
static var arte := true

var cor := TemaUI.HP
var maximo := 1
var valor := 0
var texto := true
var icone := ""      # "hp" (coração), "mp" (gota), "xp" (estrela) ou "" (sem ícone)
var _rastro := 0.0   # valor mostrado pelo rastro (anima até `valor`)


static func criar(c: Color, v: int, m: int, largura := 160.0, altura := 14.0, com_texto := true, ic := "") -> BarraHud:
	var b := BarraHud.new()
	b.cor = c
	b.maximo = maxi(m, 1)
	b.valor = clampi(v, 0, b.maximo)
	b._rastro = b.valor
	b.texto = com_texto
	b.icone = ic
	b.custom_minimum_size = Vector2(largura, maxf(altura, 22.0) if arte else altura)
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
	if arte:
		_draw_tubo()
		return
	var r := Rect2(Vector2.ZERO, size)
	if icone != "":
		var lado := size.y * 1.25
		_desenhar_icone(Vector2(lado * 0.5, size.y * 0.5), size.y * 0.62)
		r = Rect2(Vector2(lado + 2.0, 0), Vector2(size.x - lado - 2.0, size.y))
	var raio := size.y * 0.5
	# fundo afundado (sombra em cima, luz embaixo)
	_caixa(r, TemaUI.PRETO, raio)
	_caixa(r.grow(-1.0), Color(0.16, 0.1, 0.07), raio)
	draw_rect(Rect2(r.position + Vector2(raio, 1), Vector2(r.size.x - raio * 2, 1.5)), Color(0, 0, 0, 0.5))
	var dentro := r.grow(-2.0)
	var base_x := r.position.x
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
		var p := Vector2(maxf(size.x - tw - raio * 0.8, base_x + 2.0), size.y * 0.5 + fs * 0.36)
		draw_string_outline(fonte, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, TemaUI.PRETO)
		draw_string(fonte, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, TemaUI.CREME)


## Tubo de cerâmica em 3 fatias (tampa e ponta mantêm a proporção; o meio estica).
func _draw_tubo() -> void:
	var tex := ArteHud.textura("tubo_mp" if icone == "mp" else "tubo_hp")
	var ts := tex.get_size()
	var k := size.y / ts.y
	var tampa := TUBO_TAMPA * k
	var ponta := TUBO_PONTA * k
	draw_texture_rect_region(tex, Rect2(0, 0, tampa, size.y), Rect2(0, 0, TUBO_TAMPA, ts.y))
	draw_texture_rect_region(tex, Rect2(tampa, 0, size.x - tampa - ponta, size.y), Rect2(TUBO_TAMPA, 0, ts.x - TUBO_TAMPA - TUBO_PONTA, ts.y))
	draw_texture_rect_region(tex, Rect2(size.x - ponta, 0, ponta, size.y), Rect2(ts.x - TUBO_PONTA, 0, TUBO_PONTA, ts.y))
	var dentro := Rect2(TUBO_CANAL.position.x * k, TUBO_CANAL.position.y * k,
		size.x - TUBO_CANAL.position.x * k - (ts.x - TUBO_CANAL.end.x) * k, TUBO_CANAL.size.y * k)
	var raio := dentro.size.y * 0.5
	var f := float(valor) / maximo
	var fr := float(_rastro) / maximo
	if fr > f:
		_caixa(Rect2(dentro.position, Vector2(dentro.size.x * fr, dentro.size.y)), Color(1, 0.95, 0.8, 0.8), raio)
	if f > 0.0:
		var w := maxf(dentro.size.x * f, dentro.size.y)
		var cheio := Rect2(dentro.position, Vector2(w, dentro.size.y))
		_caixa(cheio, cor.darkened(0.15), raio)
		_caixa(Rect2(cheio.position, Vector2(w, cheio.size.y * 0.55)), cor.lightened(0.2), raio)
		draw_rect(Rect2(cheio.position + Vector2(raio * 0.6, 1.0), Vector2(maxf(w - raio * 1.2, 0), maxf(cheio.size.y * 0.2, 1.0))), Color(1, 1, 1, 0.4))
	if texto:
		var fonte := ThemeDB.fallback_font
		var fs := int(clampf(size.y * 0.6, 11.0, 18.0))
		var t := "%d/%d" % [valor, maximo]
		var tw := fonte.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var p := Vector2(dentro.end.x - tw - raio * 0.5, dentro.get_center().y + fs * 0.36)
		draw_string_outline(fonte, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, TemaUI.PRETO)
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


## Ícone da barra: coração (HP), gota (MP) ou estrela (XP), com contorno preto.
func _desenhar_icone(c: Vector2, r: float) -> void:
	var pts := PackedVector2Array()
	match icone:
		"hp":
			for i in 32:
				var t := TAU * i / 32.0
				var x := 16.0 * pow(sin(t), 3)
				var y := 13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t)
				pts.append(c + Vector2(x, -y - 2.0) * r / 17.0)
		"mp":
			for i in 24:
				var t := TAU * i / 24.0
				var k := sin(t * 0.5)
				pts.append(c + Vector2(sin(t) * r * 0.62 * k, -cos(t) * r) + Vector2(0, r * 0.15))
		_:
			for i in 10:
				var raio := r if i % 2 == 0 else r * 0.45
				var t := TAU * i / 10.0
				pts.append(c + Vector2(sin(t), -cos(t)) * raio)
	var contorno := PackedVector2Array()
	for p in pts:
		contorno.append(c + (p - c) * 1.25)
	draw_colored_polygon(contorno, TemaUI.PRETO)
	draw_colored_polygon(pts, cor.lightened(0.1))
	draw_circle(c + Vector2(-r * 0.25, -r * 0.25), r * 0.16, Color(1, 1, 1, 0.55))
