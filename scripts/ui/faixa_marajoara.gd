class_name FaixaMarajoara
extends Control
## Faixa decorativa com grafismo geométrico marajoara (degraus e triângulos em
## vermelho, preto e creme), desenhada em código para molduras e divisórias.

@export var altura_faixa := 14.0


func _ready() -> void:
	custom_minimum_size.y = altura_faixa
	resized.connect(queue_redraw)


func _draw() -> void:
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), TemaUI.PRETO)
	draw_rect(Rect2(0, 0, size.x, 2), TemaUI.CREME)
	draw_rect(Rect2(0, h - 2, size.x, 2), TemaUI.CREME)
	var passo := h * 1.6
	var x := 0.0
	var i := 0
	while x < size.x:
		var cor := TemaUI.VERMELHO if i % 2 == 0 else TemaUI.CREME
		# triângulo escalonado: três degraus subindo e descendo
		var base := h - 3.0
		var topo := 3.0
		var w := passo / 2.0
		var pts := PackedVector2Array([
			Vector2(x, base), Vector2(x, base - (base - topo) / 3.0), Vector2(x + w / 3.0, base - (base - topo) / 3.0),
			Vector2(x + w / 3.0, base - 2.0 * (base - topo) / 3.0), Vector2(x + 2.0 * w / 3.0, base - 2.0 * (base - topo) / 3.0),
			Vector2(x + 2.0 * w / 3.0, topo), Vector2(x + w, topo), Vector2(x + w, base)])
		if i % 2 == 1:  # invertido
			for j in pts.size():
				pts[j].y = h - pts[j].y
		draw_colored_polygon(pts, cor)
		x += w
		i += 1
