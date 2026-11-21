class_name TemaUI
extends RefCounted
## Visual da interface: painéis de madeira escura com molduras de grafismo
## marajoara (vermelho, preto e creme). Tudo com StyleBoxFlat e _draw — sem imagens.

const MADEIRA := Color(0.2, 0.12, 0.07, 0.94)
const MADEIRA_CLARA := Color(0.32, 0.2, 0.11, 0.96)
const VERMELHO := Color(0.66, 0.18, 0.1)
const PRETO := Color(0.08, 0.05, 0.04)
const CREME := Color(0.94, 0.87, 0.7)
const OURO := Color(1.0, 0.78, 0.35)
const HP := Color(0.78, 0.2, 0.14)
const MP := Color(0.2, 0.45, 0.85)
const XP := Color(0.85, 0.7, 0.25)
const ALIADO := Color(0.45, 0.75, 1.0)
const INIMIGO := Color(1.0, 0.5, 0.42)


static func painel(clara := false, borda := VERMELHO) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = MADEIRA_CLARA if clara else MADEIRA
	s.border_color = borda
	s.set_border_width_all(3)
	s.set_corner_radius_all(4)
	s.set_content_margin_all(12)
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 6
	return s


static func aplicar_painel(p: Control, clara := false, borda := VERMELHO) -> void:
	p.add_theme_stylebox_override("panel", painel(clara, borda))


static func tema() -> Theme:
	var t := Theme.new()
	t.default_font_size = 18
	t.set_color("font_color", "Label", CREME)
	t.set_color("font_outline_color", "Label", PRETO)
	t.set_constant("outline_size", "Label", 4)
	for estado in ["normal", "hover", "pressed", "disabled", "focus"]:
		var s := StyleBoxFlat.new()
		s.bg_color = {"normal": MADEIRA_CLARA, "hover": Color(0.45, 0.27, 0.13), "pressed": VERMELHO,
			"disabled": Color(0.18, 0.13, 0.1, 0.8), "focus": Color(0, 0, 0, 0)}[estado]
		s.border_color = OURO if estado == "focus" else (VERMELHO if estado != "disabled" else Color(0.3, 0.2, 0.15))
		s.set_border_width_all(2)
		s.set_corner_radius_all(3)
		s.set_content_margin_all(8)
		t.set_stylebox(estado, "Button", s)
	t.set_color("font_color", "Button", CREME)
	t.set_color("font_hover_color", "Button", OURO)
	t.set_color("font_pressed_color", "Button", CREME)
	t.set_color("font_disabled_color", "Button", Color(0.55, 0.48, 0.4))
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = PRETO
	fundo.set_corner_radius_all(2)
	t.set_stylebox("background", "ProgressBar", fundo)
	t.set_stylebox("panel", "PanelContainer", painel())
	t.set_stylebox("panel", "Panel", painel())
	return t


## Barra de HP/MP/XP com texto "atual/máx".
static func barra(cor: Color, atual: int, maximo: int, largura := 160.0, altura := 14.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(largura, altura)
	b.max_value = maxi(maximo, 1)
	b.value = atual
	b.show_percentage = false
	var f := StyleBoxFlat.new()
	f.bg_color = cor
	f.set_corner_radius_all(2)
	b.add_theme_stylebox_override("fill", f)
	return b


static func rotulo(texto: String, tamanho := 18, cor := CREME) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	return l


## Ícone de unidade: losango com a inicial (retrato simples, sem imagem pronta).
static func icone(nome: String, cor: Color, tamanho := 40.0, destaque := false) -> Control:
	var c := IconeUnidade.new()
	c.nome = nome
	c.cor = cor
	c.destaque = destaque
	c.custom_minimum_size = Vector2(tamanho, tamanho)
	return c
