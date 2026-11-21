@tool
class_name Unidade3D
extends Node3D
## Personagem 3D na grade. Escolha o `modelo` (um .glb de assets/diorge/rigged),
## o lado (inimigo), o nome e os atributos D&D no Inspector.
## Arraste no editor: encaixa no centro da casa e sobe/desce até o piso dela.
## A ordem de turno da batalha usa a Destreza.

@export var modelo: PackedScene:
	set(v):
		modelo = v
		_queue()

@export var display_name := "Unidade":
	set(v):
		display_name = v
		_queue()

@export var classe := "guerreiro"

@export var enemy := false:
	set(v):
		enemy = v
		_queue()

## Animação que fica tocando parada (idle, walk, attack, hurt, die).
@export_enum("idle", "walk", "attack", "hurt", "die") var animacao := "idle"

## Tamanho do modelo (1 = altura original, ~1 casa).
@export_range(0.3, 3.0, 0.05) var escala := 1.0:
	set(v):
		escala = v
		_queue()

@export_group("Campanha")
## Espécie em DadosAto1.ESPECIES (inimigos) ou id do herói (vazio = unidade de teste).
@export var especie := ""
@export_range(1, 30) var nivel := 1
## "" = comum, "lider" = vencer ele encerra a batalha, "chefe" = boss.
@export var papel := ""

@export_group("Atributos (D&D)")
@export_range(1, 30) var forca := 10
@export_range(1, 30) var destreza := 10
@export_range(1, 30) var constituicao := 10
@export_range(1, 30) var inteligencia := 10
@export_range(1, 30) var sabedoria := 10
@export_range(1, 30) var carisma := 10

var _pending := false
var _anim: AnimationPlayer


func _ready() -> void:
	set_notify_transform(true)
	_rebuild()
	if not Engine.is_editor_hint():
		tocar(animacao)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint():
		_queue()


func grid() -> Vector2i:
	return Vector2i(floori(position.x), floori(position.z))


func stats_text() -> String:
	return "FOR %d  DES %d  CON %d  INT %d  SAB %d  CAR %d" % [forca, destreza, constituicao, inteligencia, sabedoria, carisma]


## Toca uma animação; as que não repetem (attack, hurt) voltam para o idle.
func tocar(nome: String) -> void:
	if _anim == null or not _anim.has_animation(nome):
		return
	_anim.play(nome)
	if nome in ["attack", "hurt"]:
		_anim.queue("idle")


## Altura do piso (Peca3D) mais alto na casa desta unidade, procurando na cena.
func altura_do_piso() -> float:
	var root := get_tree().edited_scene_root if Engine.is_editor_hint() else get_tree().current_scene
	if root == null:
		return position.y
	var best := -INF
	for p in root.find_children("*", "Peca3D", true, false):
		if p.piso and grid() in p.casas():
			best = maxf(best, p.topo_global())
	return position.y if best == -INF else best


func _queue() -> void:
	if is_inside_tree() and not _pending:
		_pending = true
		_rebuild.call_deferred()


func _rebuild() -> void:
	_pending = false
	if Engine.is_editor_hint():
		var g := grid()
		var want := Vector3(g.x + 0.5, altura_do_piso(), g.y + 0.5)
		if not position.is_equal_approx(want):
			set_notify_transform(false)
			position = want
			set_notify_transform(true)
	# Partes geradas (modelo, anel, nome) não são salvas na cena: sem owner.
	for c in get_children():
		if c.has_meta("_gerado"):
			c.free()
	_anim = null
	if modelo:
		var m := modelo.instantiate()
		m.name = "Modelo"
		m.scale = Vector3.ONE * escala
		_add(m)
		_anim = m.find_child("AnimationPlayer", true, false)
		if _anim:
			# mistura uma animação na outra (parado -> andar -> atacar) em vez de pular de pose
			_anim.playback_default_blend_time = 0.12
	var anel := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.38
	cyl.bottom_radius = 0.38
	cyl.height = 0.02
	anel.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.3, 0.25, 0.55) if enemy else Color(0.3, 0.65, 1.0, 0.55)
	anel.material_override = mat
	anel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	anel.position.y = 0.02
	_add(anel)
	var l := Label3D.new()
	l.text = display_name
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.pixel_size = 0.0009
	l.font_size = 26
	l.outline_size = 8
	l.modulate = Color(1, 0.65, 0.6) if enemy else Color(0.85, 0.95, 1)
	l.position.y = 1.02 * escala
	_add(l)


func _add(n: Node) -> void:
	n.set_meta("_gerado", true)
	add_child(n)
