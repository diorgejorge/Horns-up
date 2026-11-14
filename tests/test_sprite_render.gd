extends TestCase
## Quadro renderizado por arte/blender/renderizar_sprites.py.
## Lê o PNG direto (sem depender do import do Godot).

const FRAMES := ["res://assets/sprites/bode/parado_00.png", "res://assets/sprites/ovelha/parado_00.png"]
const W := 512
const H := 384
const MARGIN := 16
## Com a câmera inclinada, o pé mais perto da câmera desce uns pixels abaixo
## da linha da origem; nada pode passar desta folga.
const NEAR_FOOT_SLACK := 10
const PX_PER_M := 160.0


static func load_frame(path: String) -> Image:
	return Image.load_from_file(ProjectSettings.globalize_path(path))


## Linha com algum pixel opaco (alfa > 0,5) a até `half` px do centro.
static func row_has_opaque(img: Image, y: int, half: int) -> bool:
	for x in range(img.get_width() / 2 - half, img.get_width() / 2 + half):
		if img.get_pixel(x, y).a > 0.5:
			return true
	return false


static func row_is_clear(img: Image, y: int) -> bool:
	for x in img.get_width():
		if img.get_pixel(x, y).a > 0.05:
			return false
	return true


static func top_opaque_row(img: Image) -> int:
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				return y
	return -1


func test_frame_size() -> void:
	for f in FRAMES:
		var img := load_frame(f)
		check(img != null, "%s existe" % f)
		if img:
			check_eq(img.get_size(), Vector2i(W, H), "%s tem 512x384" % f)


func test_corners_transparent() -> void:
	for f in FRAMES:
		var img := load_frame(f)
		for p in [Vector2i(0, 0), Vector2i(W - 1, 0), Vector2i(0, H - 1), Vector2i(W - 1, H - 1)]:
			check(img.get_pixelv(p).a == 0.0, "%s canto %s transparente" % [f, p])


func test_feet_on_bottom_center() -> void:
	for f in FRAMES:
		var img := load_frame(f)
		check(row_has_opaque(img, H - MARGIN - 2, 60), "%s: pés logo acima da margem, no centro" % f)
		check(row_is_clear(img, H - MARGIN + NEAR_FOOT_SLACK), "%s: nada abaixo dos pés" % f)


func test_height_matches_capsule() -> void:
	# o bode tem 1,6 m de cápsula e os chifres passam dela
	var img := load_frame(FRAMES[0])
	var h := (H - MARGIN - top_opaque_row(img)) / PX_PER_M
	check(h > 1.4 and h < 2.2, "altura do bode %.2f m entre 1,4 e 2,2" % h)
