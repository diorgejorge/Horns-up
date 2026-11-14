class_name CharacterSprite
extends AnimatedSprite3D
## Personagem em sprite 2D dentro do mundo 3D (visual 2.5D).
## Os quadros vêm de arte/blender/renderizar_sprites.py: a origem (pés) fica
## no centro da borda de baixo, FOOT_MARGIN_PX acima do fim da imagem.
## Só visual: nunca tem colisão e nenhuma regra de jogo lê o sprite.

const PX_PER_METER := 160.0
const FOOT_MARGIN_PX := 16


func _ready() -> void:
	billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	shaded = false
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	pixel_size = pixel_size_for(PX_PER_METER)
	var tex := sprite_frames.get_frame_texture(animation, 0) if sprite_frames else null
	if tex:
		offset = feet_offset(tex.get_height())
	play()


static func pixel_size_for(px_per_meter: float) -> float:
	return 1.0 / px_per_meter


## Desloca a imagem (centrada) para a linha da origem cair em y = 0.
static func feet_offset(frame_height_px: int) -> Vector2:
	return Vector2(0, frame_height_px / 2.0 - FOOT_MARGIN_PX)
