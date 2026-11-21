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

## Brilho pulsante na moldura (painel selecionado / unidade da vez).
var pulso := false:
	set(v):
		pulso = v
		if _mat:
			_mat.set_shader_parameter("pulso", 1.0 if v else 0.0)

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


## Entrada animada: aparece e "assenta" com um leve zoom (escala no centro).
func entrar(atraso := 0.0) -> void:
	modulate.a = 0.0
	scale = Vector2(0.96, 0.96)
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): pivot_offset = size / 2.0).set_delay(atraso)
	tw.tween_property(self, "modulate:a", 1.0, 0.22).set_delay(atraso)
	tw.tween_property(self, "scale", Vector2.ONE, 0.32).set_delay(atraso)
