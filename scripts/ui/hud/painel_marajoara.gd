class_name PainelMarajoara
extends PanelContainer
## Painel de madeira escura com moldura marajoara desenhada por shader
## (painel_marajoara.gdshader). Funciona como um PanelContainer comum: os filhos
## ficam dentro da moldura, com margem. `destaque` troca a cor da faixa
## (vermelho por padrão; ouro para o protagonista ou o elemento ativo).

const SHADER := preload("res://scripts/ui/hud/painel_marajoara.gdshader")

var borda := 12.0
var margem := 10.0
var destaque := TemaUI.VERMELHO:
	set(v):
		destaque = v
		if _mat:
			_mat.set_shader_parameter("destaque", v)

var _mat: ShaderMaterial


func _init(borda_px := 12.0, cor := TemaUI.VERMELHO) -> void:
	borda = borda_px
	destaque = cor
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("borda", borda)
	_mat.set_shader_parameter("destaque", destaque)
	_mat.set_shader_parameter("semente", randf() * 50.0)
	material = _mat
	# StyleBoxTexture com textura branca: o shader recebe UV de 0 a 1 no painel inteiro.
	var tex := GradientTexture2D.new()
	tex.width = 4
	tex.height = 4
	var g := Gradient.new()
	g.colors = PackedColorArray([Color.WHITE, Color.WHITE])
	tex.gradient = g
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.set_content_margin_all(borda + margem)
	add_theme_stylebox_override("panel", sb)
	resized.connect(func(): _mat.set_shader_parameter("tamanho", size))


func _ready() -> void:
	_mat.set_shader_parameter("tamanho", size)
