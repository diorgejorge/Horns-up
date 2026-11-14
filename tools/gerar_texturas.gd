extends SceneTree
## Gera as texturas do cenário (ruído sem emenda, 2048 px) em assets/texturas.
## godot --headless --path . -s tools/gerar_texturas.gd
## As cores ficam nos shaders; as texturas são relevo e variação em cinza.

const OUT := "res://assets/texturas/"
const SIZE := 2048


func _initialize() -> void:
	# rocha: relevo grosso fractal + grão fino
	var rocha := _noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 3, 0.004, 6)
	_save(rocha, "rocha_ruido", false)
	_save(_noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 11, 0.012, 6), "rocha_normal", true, 6.0)
	# neve: ondulação suave, e grão para o brilho
	_save(_noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 5, 0.006, 4), "neve_normal", true, 2.0)
	_save(_noise(FastNoiseLite.TYPE_VALUE, 21, 0.35, 1), "neve_brilho", false)
	# gelo: células (rachaduras nas bordas) e relevo
	var cel := FastNoiseLite.new()
	cel.noise_type = FastNoiseLite.TYPE_CELLULAR
	cel.seed = 8
	cel.frequency = 0.006
	cel.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	cel.fractal_type = FastNoiseLite.FRACTAL_FBM
	cel.fractal_octaves = 3
	var img := cel.get_seamless_image(SIZE, SIZE)
	img.convert(Image.FORMAT_L8)
	_save_img(img, "gelo_rachaduras")
	_save(_noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 13, 0.003, 5), "gelo_normal", true, 3.0)
	# água: ondas pequenas
	_save(_noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 17, 0.01, 4), "agua_normal", true, 4.0)
	print("texturas em ", OUT)
	quit()


func _noise(kind: int, seed: int, freq: float, octaves: int) -> Image:
	var n := FastNoiseLite.new()
	n.noise_type = kind
	n.seed = seed
	n.frequency = freq
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = octaves
	var img := n.get_seamless_image(SIZE, SIZE)
	img.convert(Image.FORMAT_L8)
	return img


func _save(img: Image, name: String, as_normal: bool, strength := 1.0) -> void:
	if as_normal:
		img.convert(Image.FORMAT_RGBA8)
		img.bump_map_to_normal_map(strength)
	_save_img(img, name)


func _save_img(img: Image, name: String) -> void:
	img.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
