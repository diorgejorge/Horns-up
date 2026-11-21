extends Node3D
## Mapa-múndi do Arquipélago de Aruã (Ato I). Editável no editor:
##   Terreno/ Cenario/   peças
##   Locais/             um Marker3D por região (meta "regiao"); o Igarapé é sub-área
##   Grupo               o Búfalo representa o grupo
## Mostra só regiões já alcançadas; a próxima batalha ganha o marcador de missão.
## Setas/clique escolhem a região, Enter viaja ou luta, G abre o Grupo.

const D := preload("res://scripts/campanha/dados_ato1.gd")
const GERENCIAMENTO := "res://scenes/ui/hud/gerenciamento.tscn"

## Autoload Campanha (por get_node: o script compila também no gerador headless).
var campanha: Node:
	get: return get_node("/root/Campanha")

@export var grupo: NodePath

var _sel := 0            # índice da região selecionada
var _andando := false
var _marcador: Label3D
var _hud: HudMapa
var _dialogo: CaixaDialogo


func _ready() -> void:
	_sel = maxi(0, D.indice_regiao(campanha.regiao_atual))
	var g := _grupo()
	if g:
		g.position = _pos_regiao(campanha.regiao_atual)
		g.rotation_degrees.y = 180.0
	_atualizar_locais()
	_progressao_visual()
	_hud = HudMapa.new()
	add_child(_hud)
	_hud.selecionou.connect(_selecionar)
	_hud.viajar.connect(_viajar)
	_hud.lutar.connect(_lutar)
	_hud.abrir_grupo.connect(_abrir_grupo)
	_hud.atualizar(_sel, _andando)
	_musica()
	if campanha.vencidas.is_empty() and campanha.proxima_batalha() == 1:
		_dialogo = CaixaDialogo.new()
		add_child(_dialogo)
		_dialogo.mostrar([["", "Arquipélago de Aruã. A cheia chegou fora de época: os peixes sumiram dos igarapés e a água ficou turva."],
			["", "Nos campos de Marajó, a comunidade do Búfalo Guerreiro é atacada por criaturas que antes eram vizinhas."]])


## Trilha do mapa-múndi (carimbó, em loop).
func _musica() -> void:
	var caminho := "res://assets/diorge/audio/trilhas/exploracao_carimbo.wav"
	if not ResourceLoader.exists(caminho):
		return
	var p := AudioStreamPlayer.new()
	p.name = "Musica"
	p.stream = load(caminho)
	p.volume_db = -8.0
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(p)
	p.play()


func _grupo() -> Unidade3D:
	return get_node_or_null(grupo) as Unidade3D


func _local(id: String) -> Node3D:
	for l in get_node("Locais").get_children():
		if l.get_meta("regiao", "") == id:
			return l
	return null


func _pos_regiao(id: String) -> Vector3:
	var l := _local(id)
	return l.position if l else Vector3.ZERO


## Esconde regiões ainda não alcançadas; o Igarapé aparece depois da batalha 04.
func _atualizar_locais() -> void:
	for l in get_node("Locais").get_children():
		var id: String = l.get_meta("regiao", "")
		if id == "":
			l.visible = D.IGARAPE["aparece_apos"] in campanha.vencidas
		else:
			l.visible = campanha.regiao_desbloqueada(id)
	if _marcador == null:
		_marcador = Label3D.new()
		_marcador.text = "!"
		_marcador.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_marcador.no_depth_test = true
		_marcador.fixed_size = true
		_marcador.pixel_size = 0.0016
		_marcador.font_size = 44
		_marcador.outline_size = 12
		_marcador.modulate = TemaUI.OURO
		add_child(_marcador)
	var prox = campanha.proxima_batalha()
	_marcador.visible = prox > 0
	if prox > 0:
		_marcador.position = _pos_regiao(D.BATALHAS[prox]["regiao"]) + Vector3(0, 3.0, 0)


## Água turva, luz mais baixa e energia no covil conforme a campanha avança.
func _progressao_visual() -> void:
	var we := get_node_or_null("WorldEnvironment") as WorldEnvironment
	var sol := get_node_or_null("Sol") as DirectionalLight3D
	if we == null or sol == null:
		return
	var env := we.environment
	var v = campanha.vencidas.size()
	if v >= 5:  # depois da várzea: água turva, mais névoa
		env.fog_enabled = true
		env.fog_light_color = Color(0.55, 0.6, 0.5)
		env.fog_density = 0.002
		env.adjustment_saturation = 1.05
	if v >= 7:  # depois da floresta: luz mais baixa
		sol.light_energy *= 0.8
		env.ambient_light_energy *= 0.85
	if v >= 10:  # perto do covil: energia violeta no norte
		var l := OmniLight3D.new()
		l.light_color = Color(0.6, 0.35, 1.0)
		l.light_energy = 3.0
		l.omni_range = 7.0
		l.position = _pos_regiao("covil") + Vector3(0, 2, 0)
		add_child(l)
	if v >= 12:  # selo estabilizado
		sol.light_energy = 1.7


func _process(delta: float) -> void:
	if _marcador and _marcador.visible:
		_marcador.position.y += sin(Time.get_ticks_msec() / 250.0) * delta * 0.6


func _selecionar(i: int) -> void:
	_sel = i
	_hud.atualizar(_sel, _andando)


func _unhandled_input(event: InputEvent) -> void:
	if _andando or (_dialogo and _dialogo.ativo()):
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_LEFT, KEY_UP:
			_mover_sel(-1)
		KEY_RIGHT, KEY_DOWN:
			_mover_sel(1)
		KEY_G:
			_abrir_grupo()
		KEY_ENTER, KEY_KP_ENTER:
			var r: Dictionary = D.REGIOES[_sel]
			var prox = campanha.proxima_batalha()
			if r["id"] != campanha.regiao_atual:
				_viajar(r["id"])
			elif prox in r["batalhas"]:
				_lutar(prox)


func _mover_sel(d: int) -> void:
	var i := _sel
	for k in D.REGIOES.size():
		i = posmod(i + d, D.REGIOES.size())
		if campanha.regiao_desbloqueada(D.REGIOES[i]["id"]):
			break
	_sel = i
	_hud.atualizar(_sel, _andando)


## Anda pela rota (casas de DadosAto1.ROTA) até a região escolhida.
func _viajar(id: String) -> void:
	if _andando or not campanha.regiao_desbloqueada(id) or id == campanha.regiao_atual:
		return
	var rota: Array = D.ROTA
	var a: int = rota.find(D.regiao(campanha.regiao_atual)["pos"])
	var b := rota.find(D.regiao(id)["pos"])
	var g := _grupo()
	_andando = true
	_hud.atualizar(_sel, _andando)
	if g and a >= 0 and b >= 0:
		g.tocar("walk")
		var passo := 1 if b > a else -1
		var i: int = a
		while i != b:
			i += passo
			var c: Vector2i = rota[i]
			var alvo := Vector3(c.x + 0.5, 0.0, c.y + 0.5)
			alvo.y = _altura(c)
			var d := alvo - g.position
			g.rotation.y = atan2(d.x, d.z)
			var tw := create_tween()
			tw.tween_property(g, "position", alvo, 0.12 * d.length())
			await tw.finished
		g.tocar("idle")
	campanha.regiao_atual = id
	campanha.salvar()
	_andando = false
	_hud.atualizar(_sel, _andando)


func _altura(c: Vector2i) -> float:
	var best := 0.3
	for p in get_node("Terreno").get_children():
		if p is Peca3D and p.piso and Vector2i(floori(p.position.x), floori(p.position.z)) == c:
			best = maxf(best, p.position.y + p.altura_topo * p.scale.y)
	return best


func _lutar(n: int) -> void:
	if n != campanha.proxima_batalha():
		return
	get_tree().change_scene_to_file(D.cena_batalha(n))


func _abrir_grupo() -> void:
	get_tree().change_scene_to_file(GERENCIAMENTO)
