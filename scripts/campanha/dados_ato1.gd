class_name DadosAto1
extends RefCounted
## Banco de dados do Ato I — O Despertar do Mapinguari.
## Fonte: HornyUP_Ato_I_Mapinguari_Roteiro_LevelDesign.md (diálogos literais).
## Só usa modelos que existem em assets/diorge/ (ver ESPECIES).
## As falas das batalhas ficam em scripts/dialogo/falas_ato1.json (autoload Dialogo).

const RIG := "res://assets/diorge/rigged/"

# --- personagens ----------------------------------------------------------------

## Heróis do grupo. `entra_apos`: número da batalha depois da qual o herói entra.
const HEROIS := {
	"bufalo": {
		"nome": "Búfalo Guerreiro", "curto": "Búfalo", "classe": "guerreiro",
		"modelo": RIG + "buffalo.glb", "escala": 1.0, "protagonista": true, "entra_apos": 0,
		"nivel": 4,
		"atributos": {"forca": 16, "destreza": 12, "constituicao": 15, "inteligencia": 9, "sabedoria": 11, "carisma": 13},
		"equipamento": {"arma": "espada_bronze", "armadura": "couro_bufalo", "acessorio": ""},
	},
	"tartaruga": {
		"nome": "Tartaruga Paladina", "curto": "Tartaruga", "classe": "paladino",
		"modelo": RIG + "herois/tartaruga_paladina.glb", "escala": 1.0, "protagonista": false, "entra_apos": 3,
		"nivel": 4,
		"atributos": {"forca": 13, "destreza": 8, "constituicao": 17, "inteligencia": 10, "sabedoria": 14, "carisma": 12},
		"equipamento": {"arma": "maca_pedra", "armadura": "escudo_madeira", "acessorio": ""},
	},
}

## Espécies de adversários: modelo (arquivo real), nome, classe, atributos base,
## Ataques e habilidades de cada espécie ficam em scripts/combate/ (API Combate).
## Jacaretinga = jacare_ladino.glb; Murucututu = coruja.glb (nomes de arquivo diferentes).
## Regra do Diorge (2026-11-21): inimigos das batalhas são SÓ mobs e minions (mais o
## boss Mapinguari). Os modelos de rigged/ (búfalo, coruja, guará, boto, onça) são de
## heróis e não entram como inimigos. Única exceção: a Tartaruga Paladina na batalha 03,
## antes de ser recrutada. O gerador recusa qualquer outra espécie.
const ESPECIES := {
	"murucututu": {"nome": "Murucututu", "modelo": "coruja", "classe": "mago", "a": [8, 11, 9, 14, 12, 10],},
	"guara": {"nome": "Guará", "modelo": "guara", "classe": "ranger", "a": [10, 14, 9, 10, 11, 10],},
	"boto": {"nome": "Boto-cor-de-rosa", "modelo": "boto", "classe": "clerigo", "a": [9, 9, 11, 11, 14, 13],},
	"onca": {"nome": "Onça-pintada", "modelo": "onca", "classe": "assassino", "a": [12, 15, 9, 9, 10, 10],},
	"acaizeiro": {"nome": "Guerreiro Açaizeiro", "modelo": "minions/acaizeiro", "classe": "guerreiro", "a": [13, 9, 12, 6, 8, 6],},
	"vitoria_regia": {"nome": "Criatura Vitória-régia", "modelo": "minions/vitoria_regia", "classe": "tanque", "a": [10, 7, 16, 6, 9, 6],},
	"carnivora": {"nome": "Bruto Planta-carnívora", "modelo": "minions/carnivora", "classe": "lutador", "a": [15, 8, 13, 5, 7, 5],},
	"cogumelo": {"nome": "Diabrete Cogumelo", "modelo": "minions/cogumelo", "classe": "mago", "a": [7, 12, 9, 13, 12, 8],},
	"golem_toco": {"nome": "Golem de Toco", "modelo": "minions/golem_toco", "classe": "tanque", "a": [13, 6, 17, 5, 8, 5],},
	"bromelia": {"nome": "Arqueira Bromélia", "modelo": "minions/bromelia", "classe": "ranger", "a": [9, 13, 9, 8, 10, 8],},
	"aninga": {"nome": "Lanceiro Aninga", "modelo": "minions/aninga", "classe": "lanceiro", "a": [12, 11, 11, 6, 8, 6],},
	"buriti": {"nome": "Batedor Buriti", "modelo": "minions/buriti", "classe": "batedor", "a": [10, 15, 9, 7, 9, 7],},
	"sapo_dardo": {"nome": "Sapo-dardo", "modelo": "mobs/sapo_dardo", "classe": "assassino", "a": [9, 16, 8, 9, 10, 8],},
	"tartaruga_amazonia": {"nome": "Tartaruga-da-amazônia", "modelo": "mobs/tartaruga", "classe": "clerigo", "a": [9, 7, 14, 10, 14, 10],},
	"iguana": {"nome": "Iguana", "modelo": "mobs/iguana", "classe": "ranger", "a": [10, 13, 10, 9, 10, 9],},
	"teiu": {"nome": "Teiú", "modelo": "mobs/teiu", "classe": "lutador", "a": [13, 11, 12, 7, 8, 8],},
	"naga": {"nome": "Naga", "modelo": "mobs/naga", "classe": "mago", "a": [8, 10, 10, 15, 12, 11],},
	"coral": {"nome": "Cobra-coral", "modelo": "mobs/coral", "classe": "assassino", "a": [11, 16, 9, 9, 9, 9],},
	"cobra_cavaleira": {"nome": "Cobra cavaleira", "modelo": "mobs/cobra_cavaleira", "classe": "lanceiro", "a": [13, 10, 14, 8, 9, 9],},
	"jacare_acu": {"nome": "Jacaré-açu", "modelo": "mobs/jacare_acu", "classe": "guerreiro", "a": [16, 7, 16, 6, 8, 7],},
	"jacaretinga": {"nome": "Jacaretinga", "modelo": "mobs/jacare_ladino", "classe": "batedor", "a": [11, 14, 10, 8, 9, 8],},
	"cururu": {"nome": "Sapo-cururu", "modelo": "mobs/cururu", "classe": "mago", "a": [9, 8, 13, 13, 14, 10],},
	"perereca": {"nome": "Perereca-macaco", "modelo": "mobs/perereca", "classe": "assassino", "a": [10, 16, 9, 8, 9, 9],},
	"tartaruga_paladina": {"nome": "Tartaruga Paladina", "modelo": "herois/tartaruga_paladina", "classe": "paladino", "a": [13, 8, 17, 10, 14, 12], "so_antes_de": 4},
	"mapinguari": {"nome": "Mapinguari", "modelo": "bosses/mapinguari", "classe": "chefe", "a": [20, 8, 18, 6, 10, 8],},
}

## Nomes de quem fala nos diálogos. O Pajé não tem falas no roteiro.
const FALANTES := {
	"bufalo": "Búfalo", "tartaruga": "Tartaruga", "morador": "Moradora",
	"voz": "Voz distante", "mapinguari": "Mapinguari", "": "",
}

## Retrato nos diálogos (estilo Final Fantasy) feito do próprio modelo 3D.
## Morador e Voz distante não têm modelo: aparecem com o losango.
## A moradora da Vila de Aruã usa o modelo cuca.glb. No Ato I ninguém sabe que
## ela é a Cuca (pedido do Diorge): o jogo só a chama de "Moradora".
const MODELO_MORADORA := "res://assets/diorge/npcs/cuca.glb"

const RETRATOS := {
	"morador": MODELO_MORADORA,
	"bufalo": RIG + "buffalo.glb",
	"tartaruga": RIG + "herois/tartaruga_paladina.glb",
	"mapinguari": RIG + "bosses/mapinguari.glb",
}

# --- itens e equipamento -----------------------------------------------------------

## Itens do jogo. Equipamentos só mudam números (o visual é o do modelo).
## `so`: classes que podem equipar (vazio = todas).
const ITENS := {
	"pocao": {"nome": "Poção de cura", "tipo": "consumivel", "cura": 30,
		"desc": "Recupera 30 HP de um herói. Na batalha, gasta a ação do turno (alcance 1)."},
	"pocao_mana": {"nome": "Poção de mana", "tipo": "consumivel", "mana": 12,
		"desc": "Recupera 12 MP de um herói que usa magia. Na batalha, gasta a ação do turno (alcance 1)."},
	# Equipamento aprovado pelo Diorge (2026-11-21). Búfalo (Tauá) e Tartaruga (Ituaçu).
	"espada_bronze": {"nome": "Espada de bronze", "tipo": "arma", "ataque": 2, "so": ["guerreiro"],
		"desc": "Espada leve de bronze. +2 de ataque."},
	"espadao_marajoara": {"nome": "Espadão marajoara", "tipo": "arma", "ataque": 5, "so": ["guerreiro"], "exige": {"forca": 16},
		"desc": "Espadão de duas mãos com grafismo marajoara. +5 de ataque. Exige Força 16."},
	"couro_bufalo": {"nome": "Couro de búfalo", "tipo": "armadura", "defesa": 2, "so": ["guerreiro"],
		"desc": "Gibão de couro curtido. +2 de armadura."},
	"peitoral_marajoara": {"nome": "Peitoral de placas marajoara", "tipo": "armadura", "defesa": 4, "so": ["guerreiro"],
		"desc": "Placas de bronze pintadas em vermelho e preto. +4 de armadura."},
	"maca_pedra": {"nome": "Maça de pedra", "tipo": "arma", "ataque": 2, "so": ["paladino"],
		"desc": "Maça simples de pedra. +2 de ataque."},
	"maca_marajoara": {"nome": "Maça de pedra marajoara", "tipo": "arma", "ataque": 4, "so": ["paladino"],
		"contra": ["naga", "coral", "cobra_cavaleira", "acaizeiro", "vitoria_regia", "carnivora", "cogumelo", "golem_toco", "bromelia", "aninga", "buriti"],
		"desc": "Maça entalhada pelos Ceramistas. +4 de ataque e +50% de dano contra cobras e plantas."},
	"escudo_madeira": {"nome": "Escudo de madeira", "tipo": "armadura", "defesa": 2, "so": ["paladino"],
		"desc": "Escudo de madeira de lei. +2 de armadura."},
	"escudo_marajoara": {"nome": "Escudo de pedra marajoara", "tipo": "armadura", "defesa": 4, "so": ["paladino"], "bloqueio_flecha": 0.3,
		"desc": "Escudo de pedra com grafismo. +4 de armadura e 30% de chance de bloquear flechas."},
	"muiraquita": {"nome": "Muiraquitã", "tipo": "acessorio", "bonus": {"sabedoria": 2, "constituicao": 1}, "so": [],
		"desc": "Amuleto de pedra verde encontrado no círculo de raízes. +2 SAB, +1 CON."},
}

## Itens que mudaram de id (saves antigos são convertidos ao carregar).
const ITENS_RENOMEADOS := {"espadao_bronze": "espada_bronze", "placas_bronze": "couro_bufalo", "escudo_pedra": "escudo_madeira"}

## Slots que o sistema de equipamento suporta.
const SLOTS := {"arma": "Arma", "armadura": "Armadura", "acessorio": "Acessório"}

const INVENTARIO_INICIAL := {"pocao": 2, "pocao_mana": 1}

## Modelo 3D da poção de cura (aparece quando alguém bebe uma na batalha).
const MODELO_POCAO := "res://assets/diorge/itens/itensCura.glb"

# --- ouro e lojas ------------------------------------------------------------------

const OURO_INICIAL := 30
## Ouro por inimigo derrotado numa vitória: base + por nível do inimigo.
const OURO_POR_INIMIGO := 6
const OURO_POR_NIVEL := 3

## Lojas das cidades: região -> {item: preço}. No Ato I só a Vila de Aruã é cidade.
const LOJAS := {
	"vila": {"pocao": 25, "pocao_mana": 35,
		"espada_bronze": 60, "espadao_marajoara": 150, "couro_bufalo": 80, "peitoral_marajoara": 220,
		"maca_pedra": 60, "maca_marajoara": 160, "escudo_madeira": 70, "escudo_marajoara": 200},
}

# --- mapa-múndi ----------------------------------------------------------------------

## As 5 regiões em ordem de progressão. `pos` = casa no mapa-múndi (x, z; norte = z baixo).
const REGIOES := [
	{"id": "vila", "nome": "Vila de Aruã", "pos": Vector2i(5, 19), "batalhas": [1, 2],
		"resumo": "A comunidade do Búfalo, nos campos alagáveis à margem do rio. Palafitas, cais e canoas."},
	{"id": "varzea", "nome": "Várzea das Águas", "pos": Vector2i(19, 20), "batalhas": [3, 4, 5],
		"resumo": "Terras alagadas com lama, juncos e passarelas. A água sobe e desce fora do ciclo. Ao norte, o Igarapé dos Ossos."},
	{"id": "floresta", "nome": "Floresta das Sapopemas", "pos": Vector2i(15, 10), "batalhas": [6, 7],
		"resumo": "Mata fechada e úmida, dominada por samaúmas. As plantas começaram a se mover."},
	{"id": "ruinas", "nome": "Ruínas dos Ceramistas", "pos": Vector2i(25, 5), "batalhas": [8, 9, 10],
		"resumo": "Complexo ritual de pedra e cerâmica no alto da floresta: urnas, totens e o altar do selo."},
	{"id": "covil", "nome": "Covil do Mapinguari", "pos": Vector2i(13, 2), "batalhas": [11, 12],
		"resumo": "O trecho mais fechado da mata profunda, onde a energia do selo se concentra."},
]

## Caminho do grupo no mapa-múndi entre as regiões (casas, em ordem).
const ROTA := [
	Vector2i(5, 19), Vector2i(9, 19), Vector2i(12, 20), Vector2i(16, 20), Vector2i(19, 20),
	Vector2i(19, 17), Vector2i(19, 14), Vector2i(17, 12), Vector2i(15, 10),
	Vector2i(18, 8), Vector2i(21, 7), Vector2i(25, 5),
	Vector2i(22, 3), Vector2i(18, 3), Vector2i(13, 2),
]
## Subárea de travessia (não é cenário principal): aparece depois da batalha 04.
const IGARAPE := {"nome": "Igarapé dos Ossos", "pos": Vector2i(19, 14), "aparece_apos": 4}

# --- batalhas --------------------------------------------------------------------------

## Cada batalha: cenário (região), nome, objetivo, tipo de vitória, ambiente (luz),
## inimigos [espécie, x, z, nível, (líder/chefe)], casas de início do grupo,
## e recompensas (diálogos no JSON do Dialogo).
## "trilha": música da batalha em assets/diorge/audio/trilhas/<trilha>.wav
## (geradas por audio/trilhas_batalha.py; a do chefe por audio/gerar_audio.py).
## Os mapas (casas) ficam em tools/gerar_ato1.gd; as cenas geradas são editáveis.
const BATALHAS := {
	1: {
		"regiao": "vila", "nome": "O ataque aos campos", "ambiente": "vila",
		"trilha": "batalha_vila",
		"objetivo": "Derrotar as criaturas que invadiram a área habitada.", "vitoria": "todos",
		"inicio": [Vector2i(7, 11), Vector2i(6, 11), Vector2i(5, 12)],
		"inimigos": [["teiu", 7, 3, 1], ["jacaretinga", 8, 2, 1], ["iguana", 11, 3, 1], ["perereca", 4, 3, 1], ["jacare_acu", 9, 3, 1]],
		"recompensa": {"pocao": 1},
	},
	2: {
		"regiao": "vila", "nome": "Rastros na margem", "ambiente": "vila",
		"trilha": "batalha_vila",
		"objetivo": "Derrotar o grupo que protege a trilha de saída da vila.", "vitoria": "todos",
		"inicio": [Vector2i(8, 13), Vector2i(9, 13), Vector2i(7, 14)],
		"inimigos": [["naga", 14, 1, 1], ["iguana", 15, 3, 1], ["tartaruga_amazonia", 10, 1, 2], ["coral", 9, 4, 1], ["sapo_dardo", 5, 3, 1]],
		"recompensa": {"pocao": 2},
	},
	3: {
		"regiao": "varzea", "nome": "A guardiã da passagem", "ambiente": "varzea",
		"trilha": "batalha_varzea",
		"objetivo": "Vencer a Tartaruga Paladina sem eliminá-la: deixe-a sem forças para lutar.", "vitoria": "lider",
		"inicio": [Vector2i(7, 11), Vector2i(8, 11), Vector2i(6, 12)],
		"inimigos": [["tartaruga_paladina", 8, 1, 3, "lider"], ["tartaruga_amazonia", 9, 2, 2], ["iguana", 4, 2, 2], ["teiu", 11, 2, 2]],
		"recompensa": {}, "recruta": "tartaruga",
	},
	4: {
		"regiao": "varzea", "nome": "A passarela rompida", "ambiente": "varzea",
		"trilha": "batalha_varzea",
		"objetivo": "Derrotar os inimigos que controlam as passarelas.", "vitoria": "todos",
		"inicio": [Vector2i(6, 13), Vector2i(8, 13), Vector2i(7, 14), Vector2i(9, 14)],
		"inimigos": [["acaizeiro", 5, 4, 3], ["vitoria_regia", 8, 4, 3], ["aninga", 5, 1, 3], ["buriti", 13, 4, 3], ["sapo_dardo", 2, 0, 3], ["jacaretinga", 10, 4, 3]],
		"recompensa": {"pocao": 1, "pocao_mana": 1},
	},
	5: {
		"regiao": "varzea", "nome": "O igarapé dos ossos", "ambiente": "igarape",
		"trilha": "batalha_igarape",
		"objetivo": "Derrotar a força que bloqueia a travessia.", "vitoria": "todos",
		"inicio": [Vector2i(4, 12), Vector2i(10, 12), Vector2i(3, 12), Vector2i(11, 12)],
		"inimigos": [["jacare_acu", 7, 1, 3], ["jacaretinga", 4, 2, 3], ["naga", 12, 2, 3], ["coral", 9, 4, 3], ["cururu", 3, 0, 3], ["perereca", 11, 4, 3]],
		"recompensa": {"pocao": 1},
	},
	6: {
		"regiao": "floresta", "nome": "A mata desperta", "ambiente": "floresta",
		"trilha": "batalha_floresta",
		"objetivo": "Derrotar as criaturas vegetais que defendem o caminho.", "vitoria": "todos",
		"inicio": [Vector2i(7, 12), Vector2i(8, 12), Vector2i(6, 13), Vector2i(9, 13)],
		"inimigos": [["golem_toco", 7, 2, 4], ["carnivora", 9, 3, 4], ["acaizeiro", 5, 3, 4], ["bromelia", 12, 2, 4], ["cogumelo", 8, 1, 4], ["buriti", 3, 2, 4]],
		"recompensa": {"pocao": 1},
	},
	7: {
		"regiao": "floresta", "nome": "O círculo de raízes", "ambiente": "floresta",
		"trilha": "batalha_floresta",
		"objetivo": "Derrotar os defensores de uma área ritual antiga.", "vitoria": "todos",
		"inicio": [Vector2i(7, 14), Vector2i(8, 14), Vector2i(7, 15), Vector2i(8, 15)],
		"inimigos": [["vitoria_regia", 7, 9, 4], ["aninga", 8, 9, 4], ["cogumelo", 8, 6, 4], ["golem_toco", 5, 7, 4], ["naga", 10, 6, 4], ["cururu", 7, 5, 4]],
		"recompensa": {"muiraquita": 1, "pocao": 1, "pocao_mana": 1},
	},
	8: {
		"regiao": "ruinas", "nome": "Guardiões das ruínas", "ambiente": "ruinas",
		"trilha": "batalha_ruinas",
		"objetivo": "Derrotar os defensores que ocupam o acesso ao complexo.", "vitoria": "todos",
		"inicio": [Vector2i(7, 13), Vector2i(8, 13), Vector2i(6, 14), Vector2i(9, 14)],
		"inimigos": [["jacare_acu", 7, 5, 4], ["cururu", 4, 2, 4], ["coral", 9, 6, 4], ["tartaruga_amazonia", 8, 3, 4], ["cobra_cavaleira", 6, 3, 4]],
		"recompensa": {"pocao": 2},
	},
	9: {
		"regiao": "ruinas", "nome": "A câmara das urnas", "ambiente": "ruinas",
		"trilha": "batalha_ruinas",
		"objetivo": "Derrotar as unidades que guardam a passagem para o altar.", "vitoria": "todos",
		"inicio": [Vector2i(7, 13), Vector2i(8, 13), Vector2i(6, 14), Vector2i(9, 14)],
		"inimigos": [["naga", 7, 2, 5], ["coral", 9, 5, 5], ["cururu", 6, 1, 5], ["jacare_acu", 7, 7, 5], ["cogumelo", 5, 3, 5], ["tartaruga_amazonia", 10, 3, 5]],
		"recompensa": {"pocao": 1, "pocao_mana": 1},
	},
	10: {
		"regiao": "ruinas", "nome": "O altar rompido", "ambiente": "ruinas",
		"trilha": "batalha_ruinas",
		"objetivo": "Derrotar a última defesa antes do caminho para o covil.", "vitoria": "todos",
		"inicio": [Vector2i(7, 13), Vector2i(8, 13), Vector2i(6, 14), Vector2i(9, 14)],
		"inimigos": [["golem_toco", 7, 9, 5], ["carnivora", 9, 9, 5], ["bromelia", 6, 5, 5], ["cogumelo", 8, 4, 5], ["jacare_acu", 5, 8, 5], ["naga", 10, 5, 5], ["sapo_dardo", 12, 8, 5]],
		"recompensa": {"pocao": 2},
	},
	11: {
		"regiao": "covil", "nome": "A trilha do guardião", "ambiente": "covil",
		"trilha": "batalha_covil",
		"objetivo": "Derrotar os defensores que protegem a aproximação ao covil.", "vitoria": "todos",
		"inicio": [Vector2i(7, 13), Vector2i(8, 13), Vector2i(6, 13), Vector2i(9, 13)],
		"inimigos": [["golem_toco", 7, 4, 6], ["acaizeiro", 5, 6, 6], ["vitoria_regia", 9, 6, 6], ["carnivora", 8, 5, 6], ["buriti", 3, 3, 6], ["jacare_acu", 8, 1, 6], ["perereca", 12, 3, 6]],
		"recompensa": {"pocao": 2, "pocao_mana": 1},
	},
	12: {
		"regiao": "covil", "nome": "O despertar do Mapinguari", "ambiente": "covil",
		"trilha": "chefe_mapinguari",
		"objetivo": "Enfrentar o Mapinguari e restaurar o selo.", "vitoria": "chefe",
		"inicio": [Vector2i(6, 12), Vector2i(9, 12), Vector2i(7, 13), Vector2i(8, 13)],
		"inimigos": [["mapinguari", 7, 4, 7, "chefe"]],
		"recompensa": {},
	},
}


static func regiao(id: String) -> Dictionary:
	for r in REGIOES:
		if r["id"] == id:
			return r
	return {}


## Casa da ROTA (índice) onde acontece a batalha n: o local da região dela,
## e o Igarapé dos Ossos para a batalha 05 (sub-área entre a várzea e a floresta).
static func indice_rota_batalha(n: int) -> int:
	if n == 5:
		return ROTA.find(IGARAPE["pos"])
	return ROTA.find(regiao(BATALHAS[n]["regiao"])["pos"])


static func indice_regiao(id: String) -> int:
	for i in REGIOES.size():
		if REGIOES[i]["id"] == id:
			return i
	return -1


static func cena_batalha(n: int) -> String:
	return "res://scenes/3d/ato1/batalha_%02d.tscn" % n


static func atributos_especie(id: String) -> Dictionary:
	var a: Array = ESPECIES[id]["a"]
	return {"forca": a[0], "destreza": a[1], "constituicao": a[2], "inteligencia": a[3], "sabedoria": a[4], "carisma": a[5]}
