class_name IconeItem
extends Control
## Ícone de item desenhado em código (sem imagem pronta), pelo tipo do item em
## DadosAto1.ITENS: frasco (consumível), lâmina (arma), escudo (armadura) e
## pingente (acessório). Mostra a quantidade empilhada no canto.

var tipo := ""
var qtd := 0
var vazio := false


func _draw() -> void:
	var s := size
	var c := s / 2.0
	var r := minf(s.x, s.y) * 0.34
	if vazio or tipo == "":
		draw_circle(c, 2.0, Color(TemaUI.CREME, 0.15))
		return
	match tipo:
		"consumivel":  # frasco de poção
			draw_rect(Rect2(c + Vector2(-r * 0.22, -r), Vector2(r * 0.44, r * 0.5)), TemaUI.CREME)
			draw_circle(c + Vector2(0, r * 0.25), r * 0.72, TemaUI.PRETO)
			draw_circle(c + Vector2(0, r * 0.25), r * 0.6, TemaUI.HP)
			draw_circle(c + Vector2(-r * 0.2, r * 0.05), r * 0.16, Color(1, 1, 1, 0.6))
		"arma":  # lâmina inclinada
			var a := c + Vector2(-r, r)
			var b := c + Vector2(r, -r)
			draw_line(a, b, TemaUI.PRETO, r * 0.5)
			draw_line(a + Vector2(r * 0.4, -r * 0.4), b, TemaUI.CREME, r * 0.3)
			draw_line(c + Vector2(-r * 0.9, 0), c + Vector2(0, r * 0.9), TemaUI.VERMELHO, r * 0.22)
		"armadura":  # escudo
			var pts := PackedVector2Array([c + Vector2(-r, -r), c + Vector2(r, -r), c + Vector2(r, 0), c + Vector2(0, r * 1.1), c + Vector2(-r, 0)])
			draw_colored_polygon(pts, TemaUI.PRETO)
			var p2 := PackedVector2Array()
			for p in pts:
				p2.append(c + (p - c) * 0.78)
			draw_colored_polygon(p2, TemaUI.VERMELHO)
			draw_line(c + Vector2(0, -r * 0.7), c + Vector2(0, r * 0.75), TemaUI.CREME, 2.0)
		"acessorio":  # pingente (muiraquitã)
			draw_arc(c + Vector2(0, -r * 0.5), r * 0.55, PI, TAU, 16, TemaUI.CREME, 2.0)
			var q := PackedVector2Array([c + Vector2(0, -r * 0.4), c + Vector2(r * 0.6, r * 0.3), c + Vector2(0, r), c + Vector2(-r * 0.6, r * 0.3)])
			draw_colored_polygon(q, TemaUI.PRETO)
			var q2 := PackedVector2Array()
			for p in q:
				q2.append(c + Vector2(0, r * 0.3) + (p - c - Vector2(0, r * 0.3)) * 0.72)
			draw_colored_polygon(q2, Color(0.3, 0.75, 0.5))
		_:
			draw_circle(c, r, TemaUI.CREME)
	if qtd > 1:
		var f := ThemeDB.fallback_font
		var t := "x%d" % qtd
		var fs := int(maxf(12.0, s.y * 0.26))
		var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var p := Vector2(s.x - w - 4, s.y - 5)
		draw_string_outline(f, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, TemaUI.PRETO)
		draw_string(f, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, TemaUI.OURO)
