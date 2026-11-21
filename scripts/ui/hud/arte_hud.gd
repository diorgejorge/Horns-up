class_name ArteHud
extends RefCounted
## Peças 2D da HUD marajoara, cortadas da arte do Diorge (assets/diorge/HUD/*.jpeg)
## por tools/cortar_hud.py para assets/ui/hud_marajoara/. Molduras, botões e barras
## viram StyleBoxTexture em 9 fatias (os cantos nunca esticam); ícones viram TextureRect.
##   ArteHud.estilo("painel")      moldura de pergaminho com faixa marajoara
##   ArteHud.estilo("painel_p")    a mesma, com faixa fina (cards e caixas pequenas)
##   ArteHud.estilo("botao")       botão de madeira do painel de comandos
##   ArteHud.estilo("barra")       barra de turnos (pontas ornamentadas)
##   ArteHud.estilo("casa")        casa quadrada da barra de turnos (retrato da fila)
##   ArteHud.estilo("placa")       placa de borda vermelha (unidade da vez, ouro, títulos)
##   ArteHud.icone("moeda" | "pocao" | "pocao_mana" | "urna_hp" | "pena" | "d20" | ...)

const PASTA := "res://assets/ui/hud_marajoara/"

## Texto escuro sobre o pergaminho (a arte é clara; o creme antigo some nela).
const TINTA := Color(0.25, 0.13, 0.07)
const TINTA_OURO := Color(0.62, 0.25, 0.06)
const TINTA_INIMIGO := Color(0.68, 0.12, 0.08)
const TINTA_ALIADO := Color(0.12, 0.33, 0.62)

## nome -> [fatia esq, cima, dir, baixo, conteúdo esq, cima, dir, baixo] em pixels da textura.
## As fatias do painel entram 2 px no pergaminho limpo: o miolo repete sem emenda.
const FATIAS := {
	"painel": [27, 35, 25, 27, 24, 28, 22, 22],
	"painel_p": [17, 22, 16, 17, 14, 16, 13, 13],
	"botao": [14, 12, 14, 12, 14, 7, 14, 7],
	"barra": [67, 18, 69, 18, 72, 14, 66, 14],
	"casa": [12, 12, 12, 12, 6, 6, 6, 6],
	"placa": [18, 16, 18, 16, 16, 8, 16, 8],
	"barra_titulo": [135, 18, 135, 18, 128, 14, 128, 14],
}
## Estilos com faixa de grafismo: o padrão repete (não estica) ao longo das bordas.
const REPETE := ["painel", "painel_p", "barra", "barra_titulo"]

## Item do jogo (DadosAto1.ITENS) -> ícone pintado.
const ICONE_ITEM := {"pocao": "pocao", "pocao_mana": "pocao_mana"}

static var _cache := {}


static func textura(nome: String) -> Texture2D:
	if not _cache.has(nome):
		if nome == "vazio":  # transparente no tamanho da pena: guarda o lugar do cursor
			_cache[nome] = ImageTexture.create_from_image(Image.create_empty(160, 60, false, Image.FORMAT_RGBA8))
		else:
			_cache[nome] = load(PASTA + nome + ".png")
	return _cache[nome]


static func estilo(nome: String, cor := Color.WHITE) -> StyleBoxTexture:
	var m: Array = FATIAS[nome]
	var sb := StyleBoxTexture.new()
	sb.texture = textura(nome)
	sb.texture_margin_left = m[0]
	sb.texture_margin_top = m[1]
	sb.texture_margin_right = m[2]
	sb.texture_margin_bottom = m[3]
	sb.content_margin_left = m[4]
	sb.content_margin_top = m[5]
	sb.content_margin_right = m[6]
	sb.content_margin_bottom = m[7]
	if nome in REPETE:
		sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
		sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	sb.modulate_color = cor
	return sb


## Ícone pintado, centralizado e sem distorcer, num quadrado de `lado` pixels.
static func icone(nome: String, lado := 32.0) -> TextureRect:
	var r := TextureRect.new()
	r.texture = textura(nome)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(lado, lado)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return r


## Nome do ícone pintado do item, ou "" se ele ainda não tem arte.
static func icone_item(item: String) -> String:
	return ICONE_ITEM.get(item, "")


## Placa vermelha com a moeda e o valor em ouro (loja, resultado, mapa).
static func placa_ouro(valor: int, tamanho := 20) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", estilo("placa"))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	p.add_child(h)
	h.add_child(icone("moeda", tamanho * 1.5))
	var l := Label.new()
	l.name = "Valor"
	l.text = str(valor)
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", TINTA_OURO)
	h.add_child(l)
	return p


## Retrato redondo: recorta `conteudo` num círculo e põe o anel de cerâmica por cima
## (o anel do card do personagem / da janela de diálogo).
static func retrato_redondo(conteudo: Control, lado := 72.0) -> Control:
	var caixa := Control.new()
	caixa.custom_minimum_size = Vector2(lado, lado)
	caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caixa.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var mascara := Control.new()
	mascara.set_anchors_preset(Control.PRESET_FULL_RECT)
	mascara.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mascara.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	mascara.draw.connect(func(): mascara.draw_circle(mascara.size / 2.0, mascara.size.x * 0.46, Color.WHITE))
	caixa.add_child(mascara)
	var fundo := ColorRect.new()
	fundo.color = Color(0.86, 0.78, 0.64)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mascara.add_child(fundo)
	conteudo.set_anchors_preset(Control.PRESET_FULL_RECT)
	mascara.add_child(conteudo)
	var anel := icone("anel", lado)
	anel.set_anchors_preset(Control.PRESET_FULL_RECT)
	caixa.add_child(anel)
	return caixa
