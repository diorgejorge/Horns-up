class_name Combate
extends RefCounted
## API de habilidades, magias e MP para a batalha e o HUD.
## Sem estado: HP, MP, recargas e efeitos ficam na batalha; aqui só se
## consulta o que cada espécie sabe fazer, quanto custa e até onde alcança.
## Fórmulas de dano, cura e MP máximo continuam em Regras.
##
## Uso típico na batalha:
##   Combate.info(especie, "ataque", mp_atual)   # dicionário igual ao info_acao()
##   Combate.acoes(especie)                      # ["ataque", "golpe", ...]
##   Combate.pode_usar(info, mp_atual, recargas)
##   await VfxCombate.lancar(self, info, de, para, rapido)
##   VfxCombate.acertar(self, info, pos)

const PASTA := "res://scripts/combate/habilidades/"

## Habilidades (além do ataque básico) de cada espécie ou herói.
## O ataque básico de cada um fica em habilidades/ataques/<especie>.tres.
const KIT := {
	"bufalo": ["golpe"],
	"tartaruga": ["casco_firme", "cura_leve"],
	"tartaruga_paladina": ["casco_firme", "cura_leve"],
	"boto": ["cura_forte", "mare_curativa"],
	"tartaruga_amazonia": ["cura_forte", "mare_curativa"],
	"mapinguari": ["area"],
}

## Quando falta MP para a magia, o mago/clérigo bate com o cajado.
const SEM_MP := "golpe_cajado"

static var _cache := {}


## Habilidade pelo id (arquivo em habilidades/). null se não existir.
static func hab(id: String) -> Habilidade:
	return _carregar(PASTA + id + ".tres")


## Ataque básico da espécie. Espécie sem arquivo: soco genérico.
static func ataque(especie: String) -> Habilidade:
	var h := _carregar(PASTA + "ataques/" + especie + ".tres")
	if h == null:
		h = Habilidade.new()
		h.id = especie
		h.nome = "Ataque"
	return h


## Ids das ações da espécie, na ordem do menu: "ataque" e depois as habilidades.
static func acoes(especie: String) -> Array:
	return ["ataque"] + KIT.get(especie, [])


## Habilidades (sem o ataque básico).
static func habilidades(especie: String) -> Array[Habilidade]:
	var out: Array[Habilidade] = []
	for id in KIT.get(especie, []):
		out.append(hab(id))
	return out


## Dados da ação para a batalha, no formato que info_acao() já usa
## (nome, tipo, alc, mp, recarga, mult, poder, raio, bonus, turnos, efeito, visual, cor).
## `acao` = "ataque" ou id de habilidade. Com `mp_atual` abaixo do custo do
## ataque mágico, devolve o Golpe de cajado.
## `quem` (opcional) = estado da unidade na batalha, com "attrs", "nivel" e
## "classe": com ele, o "mult" das habilidades de dano cresce com o nível e o
## atributo (regra do Diorge, 2026-11-21) e "mult_base" guarda o valor do .tres.
static func info(especie: String, acao: String, mp_atual := 999, quem := {}) -> Dictionary:
	var h: Habilidade = ataque(especie) if acao == "ataque" else hab(acao)
	if h == null:
		push_error("Combate: habilidade desconhecida '%s'" % acao)
		return {}
	if acao == "ataque" and h.mp > mp_atual:
		h = hab(SEM_MP)
	var d := h.como_dict()
	d["id"] = acao
	d["mult_base"] = h.mult
	if not quem.is_empty() and escala(h, acao):
		var attr: String = h.atributo if h.atributo != "" else Regras.classe(quem.get("classe", ""))["atk"]
		d["mult"] = h.mult * fator(quem.get("attrs", {}).get(attr, 10), quem.get("nivel", 1))
		d["atributo"] = attr
	return d


## Quais ações crescem com nível e atributo: habilidades de dano e as magias
## básicas. Golpe corpo a corpo e flecha básicos já crescem em Regras.dano().
static func escala(h: Habilidade, acao: String) -> bool:
	if h.tipo not in ["dano", "area"]:
		return false
	return acao != "ataque" or h.visual not in ["corpo", "flecha"]


## Multiplicador extra por nível e atributo. Nível 1 com atributo 10 = 1,0.
## Ex.: Búfalo nível 4, Força 16 → 1 + 0,03×3 + 0,04×3 = 1,21 (Golpe Pesado 1,6 → 1,94).
## TODO(human): ajuste o quanto cada nível e cada ponto de modificador pesam.
static func fator(valor_atributo: int, nivel: int) -> float:
	return 1.0 + POR_NIVEL * (nivel - 1) + POR_MOD * maxi(0, Regras.mod(valor_atributo))


const POR_NIVEL := 0.03
const POR_MOD := 0.04


static func custo_mp(especie: String, acao: String) -> int:
	return info(especie, acao).get("mp", 0)


static func alcance(especie: String, acao: String) -> int:
	return info(especie, acao).get("alc", 0)


## `recargas`: id da ação -> turnos que faltam (o dicionário "recarga" da batalha).
static func pode_usar(i: Dictionary, mp_atual: int, recargas: Dictionary) -> bool:
	return mp_atual >= i.get("mp", 0) and recargas.get(i.get("id", ""), 0) <= 0


## Rótulo do menu: "Bote Arcano (2 MP)", "Golpe Pesado · 2".
static func rotulo(i: Dictionary, recargas := {}) -> String:
	var t: String = i["nome"]
	if i["mp"] > 0:
		t += " (%d MP)" % i["mp"]
	var r: int = recargas.get(i.get("id", ""), 0)
	if r > 0:
		t += " · %d" % r
	return t


static func _carregar(caminho: String) -> Habilidade:
	if not _cache.has(caminho):
		_cache[caminho] = load(caminho) if ResourceLoader.exists(caminho) else null
	return _cache[caminho]
