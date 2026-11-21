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
## se usa MP e o tipo do ataque básico ("corpo", "flecha", "magia").
const CLASSES := {
	"guerreiro": {"nome": "Guerreiro", "mov": 4, "alc": 1, "atk": "forca", "mp": false, "tipo": "corpo"},
	"paladino": {"nome": "Paladino", "mov": 3, "alc": 1, "atk": "forca", "mp": true, "tipo": "corpo"},
	"mago": {"nome": "Mago", "mov": 3, "alc": 4, "atk": "inteligencia", "mp": true, "tipo": "magia"},
	"ranger": {"nome": "Ranger", "mov": 4, "alc": 5, "atk": "destreza", "mp": false, "tipo": "flecha"},
	"clerigo": {"nome": "Clérigo", "mov": 3, "alc": 3, "atk": "sabedoria", "mp": true, "tipo": "magia"},
	"assassino": {"nome": "Assassino", "mov": 5, "alc": 1, "atk": "destreza", "mp": false, "tipo": "corpo"},
	"tanque": {"nome": "Tanque", "mov": 3, "alc": 1, "atk": "forca", "mp": false, "tipo": "corpo"},
	"batedor": {"nome": "Batedor", "mov": 6, "alc": 1, "atk": "destreza", "mp": false, "tipo": "corpo"},
	"lanceiro": {"nome": "Lanceiro", "mov": 4, "alc": 2, "atk": "forca", "mp": false, "tipo": "corpo"},
	"lutador": {"nome": "Lutador", "mov": 4, "alc": 1, "atk": "forca", "mp": false, "tipo": "corpo"},
	"chefe": {"nome": "Guardião", "mov": 3, "alc": 1, "atk": "forca", "mp": false, "tipo": "corpo"},
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
const FATOR_HEROI := 2.5
const FATOR_CHEFE := 4.0


static func classe(id: String) -> Dictionary:
	return CLASSES.get(id, CLASSES["guerreiro"])


## Casas que a unidade anda: base da classe + 1 a cada 4 pontos de Destreza acima
## de 10 (regra do Diorge: Destreza aumenta o movimento; não há atributo Agilidade
## separado, a Destreza faz esse papel).
static func movimento(classe_id: String, destreza: int) -> int:
	return classe(classe_id)["mov"] + maxi(0, floori((destreza - 10) / 4.0))


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


## Dano de um ataque: atributo de ataque + bônus de arma - defesa do alvo,
## mais bônus de altura (atacar de cima).
static func dano(atk_attrs: Dictionary, classe_id: String, nivel: int, def_attrs: Dictionary, bonus_arma: int, def_armadura: int, dif_altura: float, rng: RandomNumberGenerator) -> int:
	var a: int = atk_attrs.get(classe(classe_id)["atk"], 10)
	var base := 2 + mod(a) * 2 + nivel / 2 + bonus_arma
	var defesa := mod(def_attrs.get("constituicao", 10)) + def_armadura
	var d := base - defesa + rng.randi_range(-1, 2)
	if dif_altura > 0.2:
		d += 2
	return maxi(1, d)


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
