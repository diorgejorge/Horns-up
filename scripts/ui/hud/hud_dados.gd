class_name HudDados
extends RefCounted
## Consultas que os menus fazem nos dados reais do jogo: a prévia de atributos
## ao trocar equipamento. Habilidades e MP vêm da API Combate (scripts/combate/).

const D := preload("res://scripts/campanha/dados_ato1.gd")


## Números do herói com `slot` trocado por `item` ("" = tirar; slot "" = como está).
## Mesmo cálculo de Campanha.atributos/hp_max/mp_max/ataque_bonus/defesa_bonus.
static func previa(campanha: Node, heroi: String, slot := "", item := "") -> Dictionary:
	var h: Dictionary = campanha.herois[heroi]
	var eq: Dictionary = h["equipamento"].duplicate()
	if slot != "":
		eq[slot] = item
	var a: Dictionary = h["atributos"].duplicate()
	var ataque := 0
	var defesa := 0
	for s in eq:
		var it: String = eq[s]
		if it == "":
			continue
		var d: Dictionary = D.ITENS[it]
		for k in d.get("bonus", {}):
			a[k] += d["bonus"][k]
		defesa += d.get("defesa", 0)
		if s == "arma":
			ataque += d.get("ataque", 0)
	var classe: String = D.HEROIS[heroi]["classe"]
	return {
		"atributos": a, "ataque": ataque, "defesa": defesa,
		"hp_max": Regras.hp_max(a, h["nivel"], Regras.FATOR_HEROI),
		"mp_max": Regras.mp_max(a, h["nivel"], classe),
	}


const SIGLAS := {"forca": "FOR", "destreza": "DES", "constituicao": "CON", "inteligencia": "INT", "sabedoria": "SAB", "carisma": "CAR"}
const NOMES_ATR := {"forca": "Força", "destreza": "Destreza", "constituicao": "Constituição", "inteligencia": "Inteligência", "sabedoria": "Sabedoria", "carisma": "Carisma"}


## Texto com as diferenças entre duas prévias ("Ataque +1 · HP máx -3 · SAB +2").
static func diferenca(antes: Dictionary, depois: Dictionary) -> String:
	var p := PackedStringArray()
	for k in [["ataque", "Ataque"], ["defesa", "Defesa"], ["hp_max", "HP máx"], ["mp_max", "MP máx"]]:
		var d: int = depois[k[0]] - antes[k[0]]
		if d != 0:
			p.append("%s %+d" % [k[1], d])
	for k in SIGLAS:
		var d: int = depois["atributos"][k] - antes["atributos"][k]
		if d != 0:
			p.append("%s %+d" % [SIGLAS[k], d])
	return "sem mudança" if p.is_empty() else " · ".join(p)
