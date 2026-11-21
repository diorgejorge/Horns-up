@tool
class_name TerrenoMolhado
extends Node3D
## Deixa um tile de terreno molhado SEM mexer no GLB original.
## Uso: arraste esta cena (scenes/3d/pecas/efeitos/terreno_molhado.tscn) para
## DENTRO de uma peça de piso (filho da Peca3D). Para voltar ao normal, é só
## apagar o nó. Ele não altera o modelo nem salva nada no tile.
##
## O que ele cria (só em memória, nunca salvo na cena):
##  - "Brilho": uma cópia da MESMA malha do tile (sem duplicar o GLB) com um
##    material escuro e liso por cima, que dá o aspecto de chão encharcado.
##  - "Lamina": um plano com shader de líquido (água ou lama) na altura do topo,
##    com ondulação, gotas de chuva e borda suave onde encosta no chão.

enum Estado { MOLHADO, POCAS, ALAGADO }
enum Liquido { AGUA_BARRENTA, AGUA_ESCURA, LAMA }

const SH_BRILHO := preload("res://shaders/molhado_brilho.gdshader")
const SH_LAMINA := preload("res://shaders/lamina_liquida.gdshader")

## MOLHADO = só brilho. POCAS = brilho + poças espalhadas. ALAGADO = lâmina cobrindo o tile.
@export var estado := Estado.POCAS:
	set(v): estado = v; _refazer()
@export var liquido := Liquido.AGUA_BARRENTA:
	set(v): liquido = v; _refazer()
## Quanto o chão fica escuro e brilhante.
@export_range(0.0, 1.0, 0.01) var umidade := 0.9:
	set(v): umidade = v; _refazer()
## Ajuste fino da altura do líquido (negativo = mais baixo, mais relevo aparece).
## No ALAGADO o líquido já fica um pouco acima do topo da peça.
@export_range(-0.3, 0.3, 0.005) var nivel := 0.0:
	set(v): nivel = v; _refazer()
## 0 a 1: quanto do tile as poças cobrem (só no estado POCAS).
@export_range(0.0, 1.0, 0.01) var cobertura_pocas := 0.6:
	set(v): cobertura_pocas = v; _refazer()
## Anéis de gotas de chuva na superfície.
@export_range(0.0, 1.0, 0.01) var chuva := 0.0:
	set(v): chuva = v; _refazer()

var _criados: Array[Node] = []


func _ready() -> void:
	_refazer.call_deferred()


func _exit_tree() -> void:
	_limpar()


func _limpar() -> void:
	for n in _criados:
		if is_instance_valid(n):
			n.queue_free()
	_criados.clear()


func _refazer() -> void:
	if not is_inside_tree():
		return
	_limpar()
	var peca := get_parent()
	if peca == null:
		return
	# Brilho molhado: mesma malha, mesmo lugar, material por cima.
	if umidade > 0.0:
		var mat := ShaderMaterial.new()
		mat.shader = SH_BRILHO
		mat.set_shader_parameter("umidade", umidade)
		if liquido == Liquido.LAMA:
			mat.set_shader_parameter("cor_molhada", Color(0.09, 0.055, 0.03))
		for mi in _malhas(peca):
			var c := MeshInstance3D.new()
			c.name = "Brilho"
			c.mesh = mi.mesh # mesma malha: nada é duplicado
			c.skeleton = NodePath()
			c.material_override = mat
			c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(c)
			c.global_transform = mi.global_transform
			_criados.append(c)
	# Lâmina de líquido.
	if estado != Estado.MOLHADO:
		var topo: float = peca.get("altura_topo") if peca.get("altura_topo") != null else 0.3
		var tam: Vector2i = peca.get("tamanho") if peca.get("tamanho") != null else Vector2i(1, 1)
		var plano := PlaneMesh.new()
		plano.size = Vector2(tam.x, tam.y) * 0.98
		var lam := MeshInstance3D.new()
		lam.name = "Lamina"
		lam.mesh = plano
		lam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lam.material_override = _material_lamina()
		add_child(lam)
		var extra := 0.06 if estado == Estado.ALAGADO else 0.0
		lam.position = Vector3(0.0, topo + extra + nivel, 0.0) - position
		_criados.append(lam)


func _material_lamina() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SH_LAMINA
	match liquido:
		Liquido.AGUA_BARRENTA:
			m.set_shader_parameter("cor_rasa", Color(0.45, 0.33, 0.15))
			m.set_shader_parameter("cor_funda", Color(0.20, 0.14, 0.05))
			m.set_shader_parameter("opacidade", 0.75)
		Liquido.AGUA_ESCURA:
			m.set_shader_parameter("cor_rasa", Color(0.16, 0.20, 0.14))
			m.set_shader_parameter("cor_funda", Color(0.03, 0.05, 0.04))
			m.set_shader_parameter("opacidade", 0.8)
		Liquido.LAMA:
			m.set_shader_parameter("cor_rasa", Color(0.33, 0.21, 0.10))
			m.set_shader_parameter("cor_funda", Color(0.22, 0.13, 0.06))
			m.set_shader_parameter("opacidade", 0.95)
			m.set_shader_parameter("rugosidade", 0.16)
			m.set_shader_parameter("forca_ondas", 0.25)
			m.set_shader_parameter("velocidade", 0.08)
			m.set_shader_parameter("borda_suave", 0.006)
	m.set_shader_parameter("chuva", chuva)
	m.set_shader_parameter("pocas", 1.0 if estado == Estado.ALAGADO else cobertura_pocas)
	return m


func _malhas(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for c in n.get_children():
		if c == self:
			continue
		if c is MeshInstance3D and c.mesh:
			out.append(c)
		out.append_array(_malhas(c))
	return out
