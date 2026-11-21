class_name Regras
extends RefCounted
## Regras de combate e de crescimento, usadas pela batalha E pelos menus
## (uma fonte só para HP, MP, dano, alcance, habilidades e nível).
##
## Regras do Diorge (2026-11-20):
## - Magos e rangers atacam de longe: ranger com flecha, mago com magia que tem
##   um efeito próprio do animal.
## - Paladino: aumenta a defesa e cura pouco. Clérigo: ataca de longe com luz,
##   cura muito e cura em área.
## - Magia (mago, clérigo, paladino) gasta MP. Guerreiro não usa MP.

## Por classe: movimento, alcance do ataque básico, atributo de ataque,
## se usa MP, o tipo do ataque básico ("corpo", "flecha", "magia") e a armadura
## natural ("arm", só para adversários: heróis usam a armadura do equipamento).
const CLASSES := {
	"guerreiro": {"nome": "Guerreiro", "mov": 4, "alc": 1, "atk": "forca", "mp": false, "tipo": "corpo", "arm": 1},
	"paladino": {"nome": "Paladino", "mov": 3, "alc": 1, "atk": "forca", "mp": true, "tipo": "corpo", "arm": 2},
	"mago": {"nome": "Mago", "mov": 3, "alc": 4, "atk": "inteligencia", "mp": true, "tipo": "magia", "arm": 0},
	"ranger": {"nome": "Ranger", "mov": 4, "alc": 5, "atk": "destreza", "mp": false, "tipo": "flecha", "arm": 0},
	"clerigo": {"nome": "Clérigo", "mov": 3, "alc": 3, "atk": "sabedoria", "mp": true, "tipo": "magia", "arm": 0},
	"assassino": {"nome": "Assassino", "mov": 5, "alc": 1, "atk": "destreza", "mp": false, "tipo": "corpo", "arm": 0},
	"tanque": {"nome": "Tanque", "mov": 3, "alc": 1, "atk": "forca", "mp": false, "tipo": "corpo", "arm": 3},
	"batedor": {"nome": "Batedor", "mov": 6, "alc": 1, "atk": "destreza", "mp": false, "tipo": "corpo", "arm": 0},
	"lanceiro": {"nome": "Lanceiro", "mov": 4, "alc": 2, "atk": "forca", "mp": false, "tipo": "corpo", "arm": 1},
	"lutador": {"nome": "Lutador", "mov": 4, "alc": 1, "atk": "forca", "mp": false, "tipo": "corpo", "arm": 1},
	"chefe": {"nome": "Guardião", "mov": 3, "alc": 1, "atk": "forca", "mp": false, "tipo": "corpo", "arm": 3},
}

## Ataques e habilidades usados na batalha vêm de scripts/combate/ (API Combate).
## A tabela abaixo fica só como referência do teste tools/testar_combate.gd.
## Custo de MP do ataque básico mágico (sem MP, o mago/clérigo bate com o cajado).
const MP_MAGIA := 2

## Habilidades. tipo: "dano" (alvo inimigo), "cura" (aliado), "cura_area"
## (aliados num raio em volta do alvo), "defesa" (o usuário e aliados vizinhos),
## "area" (todos os inimigos vizinhos). `recarga` = turnos de espera (sem MP).
const HABILIDADES := {
	"golpe": {"nome": "Golpe Pesado", "tipo": "dano", "alc": 1, "mult": 1.6, "mp": 0, "recarga": 3,
		"desc": "Golpe com 1,6x de dano. Recarrega em 3 turnos."},
	"casco_firme": {"nome": "Casco Firme", "tipo": "defesa", "alc": 0, "raio": 1, "bonus": 3, "turnos": 2, "mp": 4, "recarga": 0,
		"desc": "+3 de defesa para ela e aliados vizinhos por 2 turnos."},
	"cura_leve": {"nome": "Cura Leve", "tipo": "cura", "alc": 1, "poder": 0.6, "mp": 3, "recarga": 0,
		"desc": "Cura pouco um aliado vizinho (ou ela mesma)."},
	"cura_forte": {"nome": "Bênção das Águas", "tipo": "cura", "alc": 3, "poder": 1.6, "mp": 4, "recarga": 0,
		"desc": "Cura forte num aliado a até 3 casas."},
	"mare_curativa": {"nome": "Maré Curativa", "tipo": "cura_area", "alc": 3, "raio": 1, "poder": 0.9, "mp": 6, "recarga": 0,
		"desc": "Cura todos os aliados em volta de um ponto a até 3 casas."},
	"area": {"nome": "Pancada no chão", "tipo": "area", "alc": 1, "mult": 0.85, "mp": 0, "recarga": 0,
		"desc": "Atinge todos os adversários vizinhos."},
}

## Efeitos que os ataques deixam (duram alguns turnos do alvo).
const EFEITOS := {
	"veneno": {"nome": "Envenenado", "turnos": 3, "dano": 3, "cor": Color(0.5, 0.9, 0.3)},
	"lento": {"nome": "Lento", "turnos": 2, "mov": -2, "cor": Color(0.4, 0.7, 1.0)},
	"fraco": {"nome": "Enfraquecido", "turnos": 2, "dano_feito": -3, "cor": Color(0.7, 0.45, 1.0)},
	"defesa": {"nome": "Casco Firme", "turnos": 2, "cor": Color(0.95, 0.85, 0.4)},
}

const XP_POR_NIVEL := 100
## Balanceamento (2026-11-21, "heróis com HP demais"): 2,5 -> 2,2.
const FATOR_HEROI := 2.2
## Chefe 4 -> 5 (o Mapinguari caía em 6 rodadas).
const FATOR_CHEFE := 5.0
## Adversário comum e líder (sem mudança).
const FATOR_COMUM := 1.0
const FATOR_LIDER := 1.5

## Armadura (regra do Diorge, 2026-11-21: armadura reduz o dano recebido).
## Cada ponto de armadura tira 12% do dano, até 60%. Ex.: placas de bronze (2) = -24%;
## Tartaruga com escudo (3) = -36%, e com Casco Firme (+3) chega ao máximo, -60%.
## Adversários têm armadura natural pela classe ("arm" em CLASSES).
const REDUCAO_POR_ARMADURA := 0.12
const REDUCAO_MAX := 0.6

## Dano crítico (pedido do Diorge, 2026-11-21): cada golpe tem uma chance de
## crítico. Base 5%; a classe e o tipo de arma aumentam a chance.
## Arma leve (adaga, arco, presas, dardos): +3% de chance.
## Arma pesada (espadão, maça, clava): a chance não sobe, mas o crítico bate mais forte.
const CRITICO_BASE := 0.05
const CRITICO_CLASSE := {"assassino": 0.05}
const CRITICO_ARMA := {"leve": 0.03}
const CRITICO_MULT := 1.5
const CRITICO_MULT_PESADA := 1.75
## Tipo de arma de quem não usa item (adversários), pela classe.
## Heróis: campo "peso" da arma em DadosAto1.ITENS. Sem tipo = arma média.
const ARMA_DA_CLASSE := {
	"assassino": "leve", "batedor": "leve", "ranger": "leve",
	"guerreiro": "pesada", "tanque": "pesada", "lutador": "pesada", "chefe": "pesada",
}


static func chance_critico(classe_id: String, peso_arma: String) -> float:
	return CRITICO_BASE + CRITICO_CLASSE.get(classe_id, 0.0) + CRITICO_ARMA.get(peso_arma, 0.0)


static func mult_critico(peso_arma: String) -> float:
	return CRITICO_MULT_PESADA if peso_arma == "pesada" else CRITICO_MULT


static func peso_arma_da_classe(classe_id: String) -> String:
	return ARMA_DA_CLASSE.get(classe_id, "")


## Cobertura: ataque à distância (flecha, magia, luz...) precisa de linha de visão.
## Árvore, muro, rocha e outros objetos do Cenário no meio do caminho bloqueiam.


static func classe(id: String) -> Dictionary:
	return CLASSES.get(id, CLASSES["guerreiro"])


## Casas que a unidade anda: base da classe + 1 a cada 4 pontos de Destreza acima
## de 10 (regra do Diorge: Destreza aumenta o movimento; não há atributo Agilidade
## separado, a Destreza faz esse papel).
static func movimento(classe_id: String, destreza: int) -> int:
	return classe(classe_id)["mov"] + maxi(0, floori((destreza - 10) / 4.0))


## Terreno (regra do Diorge, 2026-11-21), pelo nome da peça de piso:
## custo 2 = terreno difícil (cada casa vale 2 de movimento; quem voa paga 1).
const TERRENO_DIFICIL := [
	"m05_lama_furos", "m03_lama_cupins", "m09_brejo_capim", "m12_lodo_ouricos", "m28_lodo_ouricos_b",
	"m17_agua_rasa_pedras", "m23_riacho_pedras", "t04_agua_rasa_pedras", "s10_poca_agua",
	"s04_lama_juncos", "s08_lama_fungos", "t06_pantano_raizes", "t10_lama_raizes",
	"m08_raizes_terra",  # raízes altas; o chão de musgo (m01) e o de raízes (f12) são normais
]
## Parte molhada do terreno difícil (lama, brejo, juncos, água rasa, riacho).
const TERRENO_MOLHADO := [
	"m05_lama_furos", "m03_lama_cupins", "m09_brejo_capim", "m12_lodo_ouricos", "m28_lodo_ouricos_b",
	"m17_agua_rasa_pedras", "m23_riacho_pedras", "t04_agua_rasa_pedras", "s10_poca_agua",
	"s04_lama_juncos", "s08_lama_fungos", "t06_pantano_raizes", "t10_lama_raizes",
]
## Chão de mata (floresta, raízes, folhas): o terreno dos animais "da mata".
const TERRENO_MATA := [
	"m01_raizes_musgo", "m08_raizes_terra", "f11_chao_folhas", "f12_chao_raizes", "t12_chao_floresta",
	"m20_folhas_secas_pedra", "m22_folhas_ouricos", "m26_arbustos_ouricos",
]
## Água funda e vitórias-régias: casas onde os nadadores entram.
const TERRENO_AGUA := ["m24_agua_funda", "t05_agua_escura", "m04_agua_vitorias_regias", "t14_agua_vitorias_regias", "s01_vitorias_regias"]

## Terreno do ambiente de cada animal (plano aprovado pelo Diorge, 2026-11-21).
## No próprio terreno: anda com custo 1; ofensivo bate +25%; defensivo ganha +3 de armadura.
const AFINIDADE := {
	"bufalo": "molhado", "tartaruga_amazonia": "molhado", "jacare_acu": "molhado", "jacaretinga": "molhado",
	"naga": "molhado", "cururu": "molhado", "aninga": "molhado", "buriti": "molhado", "vitoria_regia": "molhado",
	"tartaruga": "mata", "tartaruga_paladina": "mata", "coral": "mata", "cobra_cavaleira": "mata",
	"golem_toco": "mata", "acaizeiro": "mata", "carnivora": "mata", "cogumelo": "mata", "bromelia": "mata",
	"mapinguari": "mata",
}
## Defensivos: no próprio terreno ganham armadura em vez de dano.
const DEFENSIVOS := ["tartaruga", "tartaruga_paladina", "tartaruga_amazonia", "jacare_acu", "golem_toco", "vitoria_regia"]
## Nadadores: também entram em água funda e vitórias-régias (a corredeira segue fechada).
const NADADORES := ["jacare_acu", "jacaretinga", "naga", "tartaruga_amazonia", "vitoria_regia"]
const BONUS_DANO_TERRENO := 1.25
const BONUS_ARMADURA_TERRENO := 3


static func afinidade(especie: String) -> String:
	return AFINIDADE.get(especie, "")


static func defensivo(especie: String) -> bool:
	return especie in DEFENSIVOS


static func nadador(especie: String) -> bool:
	return especie in NADADORES


## Casas que só quem salta ("salto") ou voa ("voo") acessa. "salto" também vale para quem voa.
const TERRENO_ESPECIAL := {
	"m21_tronco_caido_grama": "salto", "s14_monte_lama": "salto",
	"m04_agua_vitorias_regias": "salto", "t14_agua_vitorias_regias": "salto", "s01_vitorias_regias": "salto",
	"m15_raiz_tronco": "salto", "m16_raizes_grama": "salto",
	"m24_agua_funda": "voo", "t05_agua_escura": "voo", "m30_corredeira_pedras": "voo",
}
## Mobilidade especial por espécie (as demais andam normal).
const MOBILIDADE := {"perereca": "salto", "sapo_dardo": "salto", "cururu": "salto", "iguana": "salto"}
## Maior degrau num passo para quem salta (quem voa ignora a altura).
const DEGRAU_SALTO := 0.9


static func mobilidade(especie: String) -> String:
	return MOBILIDADE.get(especie, "")


static func mod(valor: int) -> int:
	return floori((valor - 10) / 2.0)


## XP que um herói ganha ao derrotar um inimigo de certo nível.
static func xp_derrota(nivel_inimigo: int) -> int:
	return 6 + nivel_inimigo * 2


## `fator`: heróis 2,5 (são poucos contra muitos), chefe 4, demais 1.
static func hp_max(attrs: Dictionary, nivel: int, fator := 1.0) -> int:
	return roundi((attrs.get("constituicao", 10) + nivel * 3) * fator)


static func mp_max(attrs: Dictionary, nivel: int, classe_id: String) -> int:
	if not classe(classe_id)["mp"]:
		return 0
	return 4 + maxi(attrs.get("inteligencia", 10), attrs.get("sabedoria", 10)) / 2 + nivel * 2


## Dano de um ataque ANTES da armadura: atributo de ataque + bônus de arma
## - modificador de Constituição do alvo, mais bônus de altura (atacar de cima).
## A armadura (equipamento, natural ou Casco Firme) entra depois, em absorver().
static func dano(atk_attrs: Dictionary, classe_id: String, nivel: int, def_attrs: Dictionary, bonus_arma: int, dif_altura: float, rng: RandomNumberGenerator) -> int:
	var a: int = atk_attrs.get(classe(classe_id)["atk"], 10)
	var base := 2 + mod(a) * 2 + nivel / 2 + bonus_arma
	var d := base - mod(def_attrs.get("constituicao", 10)) + rng.randi_range(-1, 2)
	if dif_altura > 0.2:
		d += 2
	return maxi(1, d)


## Fração do dano que a armadura segura (0 a REDUCAO_MAX).
static func reducao(armadura: int) -> float:
	return clampf(armadura * REDUCAO_POR_ARMADURA, 0.0, REDUCAO_MAX)


## Dano depois da armadura (mínimo 1).
static func absorver(d: int, armadura: int) -> int:
	return maxi(1, roundi(d * (1.0 - reducao(armadura))))


## Armadura natural de um adversário da classe.
static func armadura_natural(classe_id: String) -> int:
	return classe(classe_id).get("arm", 0)


static func cura(attrs: Dictionary, nivel: int, poder := 1.0) -> int:
	return roundi((8 + mod(attrs.get("sabedoria", 10)) * 2 + nivel) * poder)


## Atributos que sobem por nível (crescimento da classe).
static func crescimento(classe_id: String) -> Dictionary:
	match classe_id:
		"guerreiro":
			return {"forca": 1, "constituicao": 1, "destreza": 1}
		"paladino":
			return {"constituicao": 2, "sabedoria": 1, "forca": 1}
	return {"forca": 1, "constituicao": 1}
