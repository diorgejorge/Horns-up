extends Node3D
## Batalha 3D EDITÁVEL NO EDITOR. Tudo no campo é nó da cena:
##   Terreno/      pisos (Peca3D)      -> arraste das cenas em scenes/3d/pecas/
##   Cenario/      árvores, casas, muros (Peca3D com piso desligado)
##   Personagens/  aliados e inimigos (Unidade3D) com atributos D&D
## Este script mostra o alcance de movimento, a ordem de turno e o HUD.
## Tab troca o aliado selecionado; Espaço faz ele atacar. Ainda sem combate.

## Personagem selecionado (mostra alcance e atributos no HUD).
@export var selected_unit: NodePath
## Alcance de movimento (casas).
@export var move_range := 4
## Maior degrau que uma unidade sobe ou desce num passo.
@export var salto := 0.45
@export var show_ranges := true

var _units: Array = []
var _sel: Unidade3D
var _overlays: Node3D
var _hud: Label
var _pisos := {}     # casa -> altura do topo
var _bloqueio := {}  # casa -> true


func _ready() -> void:
	_units = find_children("*", "Unidade3D", true, false)
	_ler_terreno()
	_sel = get_node_or_null(selected_unit) as Unidade3D
	if _sel == null:
		for u in _units:
			if not u.enemy:
				_sel = u
				break
	_overlays = Node3D.new()
	_overlays.name = "Destaques"
	add_child(_overlays)
	_hud = _make_hud()
	_atualizar()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_TAB:
		var allies := _units.filter(func(u): return not u.enemy)
		if allies.size() > 0:
			_sel = allies[(allies.find(_sel) + 1) % allies.size()]
			_atualizar()
	elif event.keycode == KEY_SPACE and _sel:
		_sel.tocar("attack")


func _ler_terreno() -> void:
	for p in find_children("*", "Peca3D", true, false):
		for c in p.casas():
			if p.piso:
				if not _pisos.has(c) or p.topo_global() > _pisos[c]:
					_pisos[c] = p.topo_global()
			if not p.andavel:
				_bloqueio[c] = true


## Casas alcançáveis andando (busca em largura): respeita degraus, água,
## obstáculos e não atravessa inimigos.
func alcance(u: Unidade3D) -> Dictionary:
	var ocupado := {}
	for o in _units:
		if o != u:
			ocupado[o.grid()] = o.enemy != u.enemy  # true = inimigo bloqueia
	var dist := {u.grid(): 0}
	var fila: Array[Vector2i] = [u.grid()]
	while fila.size() > 0:
		var c: Vector2i = fila.pop_front()
		if dist[c] >= move_range:
			continue
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if dist.has(n) or not _pisos.has(n) or _bloqueio.has(n):
				continue
			if absf(_pisos[n] - _pisos.get(c, _pisos[n])) > salto:
				continue
			if ocupado.get(n, false):
				continue
			dist[n] = dist[c] + 1
			fila.append(n)
	for o in ocupado:  # pode passar por aliado, mas não parar em cima
		dist.erase(o)
	dist.erase(u.grid())
	return dist


func _atualizar() -> void:
	for c in _overlays.get_children():
		c.free()
	if show_ranges and _sel:
		for c in alcance(_sel):
			_add_overlay(c, Color(0.3, 0.6, 1.0), 0.4)
		for u in _units:
			if u.enemy:
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var c: Vector2i = u.grid() + d
					if _pisos.has(c) and not _bloqueio.has(c):
						_add_overlay(c, Color(1.0, 0.25, 0.2), 0.3)
	var order := _units.duplicate()
	order.sort_custom(func(a, b): return a.destreza > b.destreza)
	var line := PackedStringArray()
	for u in order.slice(0, 8):
		line.append("%s %d" % [u.display_name, u.destreza])
	var info := ""
	if _sel:
		info = "\nSelecionado: %s (%s)   %s" % [_sel.display_name, _sel.classe, _sel.stats_text()]
	_hud.text = "BATALHA 3D   F1 batalha · F2 mapa-múndi · Tab troca aliado · Espaço ataca\n" \
		+ "Próximos turnos (Destreza): " + " → ".join(line) + " …" + info


func _add_overlay(c: Vector2i, color: Color, alpha: float) -> void:
	var q := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(0.86, 0.86)
	q.mesh = pm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(color * 1.3, alpha)
	q.material_override = m
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	q.position = Vector3(c.x + 0.5, _pisos[c] + 0.1, c.y + 0.5)
	_overlays.add_child(q)


func _make_hud() -> Label:
	var layer := CanvasLayer.new()
	add_child(layer)
	var l := Label.new()
	l.position = Vector2(20, 16)
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	layer.add_child(l)
	return l
