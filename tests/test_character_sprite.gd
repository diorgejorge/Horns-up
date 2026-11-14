extends TestCase

const FRAME := preload("res://assets/sprites/bode/parado_00.png")


func _make() -> CharacterSprite:
	var frames := SpriteFrames.new()
	frames.add_frame("default", FRAME)
	var s := CharacterSprite.new()
	s.sprite_frames = frames
	return s


func test_pixel_size() -> void:
	check(is_equal_approx(CharacterSprite.pixel_size_for(160.0), 0.00625), "160 px/m -> 0,00625")


func test_feet_offset() -> void:
	check_eq(CharacterSprite.feet_offset(384), Vector2(0, 176), "pés na origem num quadro de 384")


func test_ready_config() -> void:
	var s := _make()
	tree.root.add_child(s)
	await tree.process_frame
	check_eq(s.billboard, BaseMaterial3D.BILLBOARD_FIXED_Y, "billboard só no Y")
	check_eq(s.alpha_cut, SpriteBase3D.ALPHA_CUT_DISCARD, "recorte de alfa")
	check(not s.shaded, "sem sombreamento (a luz já está no desenho)")
	check(is_equal_approx(s.pixel_size, 0.00625), "pixel_size")
	check_eq(s.offset, Vector2(0, 176), "offset dos pés")
	s.queue_free()
	await tree.process_frame


func test_feet_at_origin_in_world() -> void:
	var s := _make()
	tree.root.add_child(s)
	await tree.process_frame
	var aabb := s.get_aabb()
	var expected := -CharacterSprite.FOOT_MARGIN_PX * s.pixel_size
	check(absf(aabb.position.y - expected) < 0.01, "borda de baixo %.3f perto de %.3f" % [aabb.position.y, expected])
	check(absf(aabb.get_center().x) < 0.01, "centrado em x")
	s.queue_free()
	await tree.process_frame
