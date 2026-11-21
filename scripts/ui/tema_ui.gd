class_name TemaUI
extends RefCounted
## Visual da interface: pergaminho com molduras de grafismo marajoara e botões de
## madeira, pintados pelo Diorge (peças em ArteHud). Texto em tinta escura sobre o
## pergaminho; rotulo() converte as cores claras antigas (creme, ouro) para tinta.

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


## Moldura de pergaminho pintada (os parâmetros ficam pela compatibilidade).
static func aplicar_painel(p: Control, _clara := false, _borda := VERMELHO) -> void:
	p.add_theme_stylebox_override("panel", ArteHud.estilo("painel"))


## Cor de texto legível no pergaminho: creme vira tinta, ouro vira terracota etc.
static func no_papel(c: Color) -> Color:
	var base := Color(c, 1.0)
	var trocas := [[CREME, ArteHud.TINTA], [OURO, ArteHud.TINTA_OURO], [INIMIGO, ArteHud.TINTA_INIMIGO], [ALIADO, ArteHud.TINTA_ALIADO]]
	for t in trocas:
		if base.is_equal_approx(t[0]):
			return Color(t[1], c.a)
	if base.get_luminance() > 0.6:
		return Color(base.darkened(0.55), c.a)
	return c


static func tema() -> Theme:
	var t := Theme.new()
	t.default_font_size = 18
	t.set_color("font_color", "Label", ArteHud.TINTA)
	t.set_color("font_outline_color", "Label", Color(CREME, 0.8))
	t.set_constant("outline_size", "Label", 3)
	# botão de madeira do painel de comandos; hover clareia, pressed avermelha
	var cores := {"normal": Color.WHITE, "hover": Color(1.0, 0.92, 0.74), "pressed": Color(1.0, 0.8, 0.72),
		"disabled": Color(0.85, 0.82, 0.78, 0.6)}
	for estado in cores:
		t.set_stylebox(estado, "Button", ArteHud.estilo("botao", cores[estado]))
	var foco := StyleBoxEmpty.new()
	t.set_stylebox("focus", "Button", foco)
	t.set_color("font_color", "Button", ArteHud.TINTA)
	t.set_color("font_hover_color", "Button", ArteHud.TINTA_OURO)
	t.set_color("font_pressed_color", "Button", ArteHud.TINTA_INIMIGO)
	t.set_color("font_focus_color", "Button", ArteHud.TINTA_OURO)
	t.set_color("font_disabled_color", "Button", Color(ArteHud.TINTA, 0.45))
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = PRETO
	fundo.set_corner_radius_all(2)
	t.set_stylebox("background", "ProgressBar", fundo)
	t.set_stylebox("panel", "PanelContainer", ArteHud.estilo("painel"))
	t.set_stylebox("panel", "Panel", ArteHud.estilo("painel"))
	t.set_color("font_color", "TooltipLabel", ArteHud.TINTA)
	t.set_stylebox("panel", "TooltipPanel", ArteHud.estilo("painel_p"))
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
	l.add_theme_color_override("font_color", no_papel(cor))
	return l


## Ícone de unidade: losango com a inicial (retrato simples, sem imagem pronta).
static func icone(nome: String, cor: Color, tamanho := 40.0, destaque := false) -> Control:
	var c := IconeUnidade.new()
	c.nome = nome
	c.cor = cor
	c.destaque = destaque
	c.custom_minimum_size = Vector2(tamanho, tamanho)
	return c
