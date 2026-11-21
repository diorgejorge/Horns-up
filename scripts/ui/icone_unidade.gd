class_name IconeUnidade
extends Control
## Retrato simples de unidade: losango marajoara com a inicial do nome.

var nome := ""
var cor := Color.WHITE
var destaque := false


func _draw() -> void:
	var s := size
	var c := s / 2.0
	var r := minf(s.x, s.y) / 2.0 - 1.0
	var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
	draw_colored_polygon(pts, TemaUI.PRETO)
	var r2 := r - 3.0
	var pts2 := PackedVector2Array([c + Vector2(0, -r2), c + Vector2(r2, 0), c + Vector2(0, r2), c + Vector2(-r2, 0)])
	draw_colored_polygon(pts2, cor.darkened(0.35))
	pts.append(pts[0])
	draw_polyline(pts, TemaUI.OURO if destaque else TemaUI.CREME, 2.5 if destaque else 1.5)
	var f := ThemeDB.fallback_font
	var fs := int(r * 0.95)
	var letra := nome.substr(0, 1).to_upper()
	var tw := f.get_string_size(letra, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	draw_string_outline(f, c + Vector2(-tw.x / 2.0, fs * 0.36), letra, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, TemaUI.PRETO)
	draw_string(f, c + Vector2(-tw.x / 2.0, fs * 0.36), letra, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, TemaUI.CREME)
