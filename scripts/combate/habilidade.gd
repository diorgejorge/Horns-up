class_name Habilidade
extends Resource
## Uma ação de combate: ataque básico ou habilidade. Cada uma é um .tres em
## scripts/combate/habilidades/ (edite os números no Inspector).
## Regras (Diorge, 2026-11-20): magia de mago, clérigo e paladino gasta MP;
## guerreiro e ranger não usam MP; o Golpe Pesado usa recarga.

## Id usado pela batalha e pelo HUD (igual ao nome do arquivo).
@export var id := ""
@export var nome := ""
@export_multiline var desc := ""

## dano: um inimigo · area: todos os inimigos vizinhos de quem usa ·
## cura: um aliado · cura_area: aliados num raio em volta do alvo ·
## defesa: quem usa e aliados no raio ganham bônus de defesa.
@export_enum("dano", "area", "cura", "cura_area", "defesa") var tipo := "dano"

@export_group("Números")
## Alcance em casas (distância de Manhattan). 0 = só em si mesmo.
@export_range(0, 10) var alcance := 1
## Raio da área (cura_area e defesa), em casas.
@export_range(0, 5) var raio := 0
## Multiplicador do dano (tipo dano/area).
@export_range(0.0, 4.0, 0.05) var mult := 1.0
## Multiplicador da cura (tipo cura/cura_area), aplicado em Regras.cura().
@export_range(0.0, 4.0, 0.05) var poder := 1.0
@export_range(0, 30) var mp := 0
## Turnos de espera depois de usar (0 = sem recarga).
@export_range(0, 9) var recarga := 0
## Defesa extra (tipo defesa) e por quantos turnos.
@export_range(0, 10) var bonus := 0
@export_range(0, 9) var turnos := 0
## Estado que o golpe deixa no alvo: vazio, veneno, lento ou fraco (Regras.EFEITOS).
@export var efeito := ""

## Atributo que faz o dano crescer (forca, destreza, inteligencia, sabedoria...).
## Vazio = o atributo de ataque da classe (Regras.CLASSES "atk").
@export var atributo := ""

@export_group("Visual")
## Como a ação viaja até o alvo (ver VfxCombate):
## corpo (sem projétil), flecha, magia (orbe), luz (raio), penas, esporos,
## bote (orbe serpenteando), fumaca, cura, mare, escudo.
@export var visual := "corpo"
@export var cor := Color.WHITE


## Mesmo formato do dicionário que batalha_campanha.gd já usa em info_acao().
## "alc" duplica "alcance" de propósito (compatibilidade com Regras.HABILIDADES).
func como_dict() -> Dictionary:
	return {
		"id": id, "nome": nome, "desc": desc, "tipo": tipo,
		"alc": alcance, "raio": raio, "mult": mult, "poder": poder,
		"mp": mp, "recarga": recarga, "bonus": bonus, "turnos": turnos,
		"efeito": efeito, "visual": visual, "cor": cor,
	}
