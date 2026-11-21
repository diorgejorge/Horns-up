extends Node
## Autoload "Campanha": estado do jogo do Ato I. É a ÚNICA fonte dos dados do
## grupo (nível, XP, HP, MP, atributos, equipamento), do inventário e do
## progresso — a batalha, o mapa-múndi e os menus leem e escrevem aqui.
## Salva em user://horny_up_ato1.json.

signal mudou

const ARQUIVO := "user://horny_up_ato1.json"
const D := preload("res://scripts/campanha/dados_ato1.gd")

var herois := {}          # id -> {nivel, xp, hp, mp, atributos{}, equipamento{}, recrutado}
var inventario := {}      # id do item -> quantidade
var vencidas: Array = []  # números das batalhas vencidas
var regiao_atual := "vila"
var batalha_atual := 0    # batalha em andamento (0 = nenhuma)


var _teste := false  # --auto: não lê nem grava o save do jogador


func _ready() -> void:
	_teste = "--auto" in OS.get_cmdline_user_args()
	if _teste or not carregar():
		novo_jogo()


func novo_jogo() -> void:
	herois.clear()
	for id in D.HEROIS:
		var h: Dictionary = D.HEROIS[id]
		var e := {
			"nivel": h["nivel"], "xp": 0,
			"atributos": h["atributos"].duplicate(),
			"equipamento": h["equipamento"].duplicate(),
			"recrutado": h["entra_apos"] == 0,
		}
		herois[id] = e
		e["hp"] = hp_max(id)
		e["mp"] = mp_max(id)
	inventario = D.INVENTARIO_INICIAL.duplicate()
	vencidas = []
	regiao_atual = "vila"
	batalha_atual = 0
	mudou.emit()


# --- progresso -----------------------------------------------------------------------

func proxima_batalha() -> int:
	for n in range(1, 13):
		if not n in vencidas:
			return n
	return 0


func ato_concluido() -> bool:
	return proxima_batalha() == 0


## Regiões já alcançadas (as anteriores e a da próxima batalha).
func regiao_desbloqueada(id: String) -> bool:
	var prox := proxima_batalha()
	var limite := D.REGIOES.size() - 1 if prox == 0 else D.indice_regiao(D.BATALHAS[prox]["regiao"])
	return D.indice_regiao(id) <= limite


func objetivo_atual() -> String:
	var prox := proxima_batalha()
	if prox == 0:
		return "Ato I concluído. O selo foi estabilizado, mas quem retirou a pedra continua desconhecido."
	var b: Dictionary = D.BATALHAS[prox]
	return "Batalha %02d — %s: %s" % [prox, b["nome"], b["objetivo"]]


func etapa_texto() -> String:
	return "Ato I · %d de 12 batalhas" % vencidas.size()


## Heróis que lutam na batalha n (o Búfalo sempre; a Tartaruga depois da 03).
func grupo_da_batalha(n: int) -> Array:
	var out := []
	for id in D.HEROIS:
		if D.HEROIS[id]["entra_apos"] < n:
			out.append(id)
	return out


func grupo() -> Array:
	var out := []
	for id in D.HEROIS:
		if herois[id]["recrutado"]:
			out.append(id)
	return out


# --- números do personagem (base + equipamento) --------------------------------------

func atributos(id: String) -> Dictionary:
	var h: Dictionary = herois[id]
	var a: Dictionary = h["atributos"].duplicate()
	for slot in h["equipamento"]:
		var item: String = h["equipamento"][slot]
		if item != "":
			for k in D.ITENS[item].get("bonus", {}):
				a[k] += D.ITENS[item]["bonus"][k]
	return a


func classe(id: String) -> String:
	return D.HEROIS[id]["classe"]


func hp_max(id: String) -> int:
	return Regras.hp_max(atributos(id), herois[id]["nivel"], Regras.FATOR_HEROI)


func mp_max(id: String) -> int:
	return Regras.mp_max(atributos(id), herois[id]["nivel"], classe(id))


func ataque_bonus(id: String) -> int:
	var arma: String = herois[id]["equipamento"].get("arma", "")
	return D.ITENS[arma].get("ataque", 0) if arma != "" else 0


func defesa_bonus(id: String) -> int:
	var t := 0
	for slot in herois[id]["equipamento"]:
		var item: String = herois[id]["equipamento"][slot]
		if item != "":
			t += D.ITENS[item].get("defesa", 0)
	return t


# --- inventário e equipamento (só fora da batalha) -------------------------------------

func fora_da_batalha() -> bool:
	return batalha_atual == 0


func adicionar_item(id: String, qtd := 1) -> void:
	inventario[id] = inventario.get(id, 0) + qtd
	mudou.emit()


func remover_item(id: String, qtd := 1) -> void:
	inventario[id] = inventario.get(id, 0) - qtd
	if inventario[id] <= 0:
		inventario.erase(id)
	mudou.emit()


func pode_usar(item: String, heroi: String) -> bool:
	return fora_da_batalha() and inventario.get(item, 0) > 0 and D.ITENS[item]["tipo"] == "consumivel" \
		and herois[heroi]["hp"] < hp_max(heroi)


func usar_item(item: String, heroi: String) -> bool:
	if not pode_usar(item, heroi):
		return false
	var h: Dictionary = herois[heroi]
	h["hp"] = mini(hp_max(heroi), h["hp"] + D.ITENS[item].get("cura", 0))
	remover_item(item)
	salvar()
	return true


func pode_equipar(item: String, heroi: String) -> bool:
	var it: Dictionary = D.ITENS[item]
	if not D.SLOTS.has(it["tipo"]):
		return false
	var so: Array = it.get("so", [])
	return so.is_empty() or classe(heroi) in so


## Troca o item do slot pelo item do inventário (o antigo volta ao inventário).
func equipar(item: String, heroi: String) -> bool:
	if not fora_da_batalha() or inventario.get(item, 0) <= 0 or not pode_equipar(item, heroi):
		return false
	var slot: String = D.ITENS[item]["tipo"]
	desequipar(slot, heroi, false)
	herois[heroi]["equipamento"][slot] = item
	remover_item(item)
	_limitar(heroi)
	salvar()
	return true


func desequipar(slot: String, heroi: String, salvar_ := true) -> void:
	if not fora_da_batalha():
		return
	var atual: String = herois[heroi]["equipamento"].get(slot, "")
	if atual != "":
		herois[heroi]["equipamento"][slot] = ""
		adicionar_item(atual)
	_limitar(heroi)
	if salvar_:
		salvar()


func _limitar(heroi: String) -> void:
	var h: Dictionary = herois[heroi]
	h["hp"] = mini(h["hp"], hp_max(heroi))
	h["mp"] = mini(h["mp"], mp_max(heroi))
	mudou.emit()


## Descansar na Vila de Aruã recupera HP e MP do grupo.
func descansar() -> void:
	for id in herois:
		herois[id]["hp"] = hp_max(id)
		herois[id]["mp"] = mp_max(id)
	salvar()
	mudou.emit()


# --- batalha ------------------------------------------------------------------------------

func iniciar_batalha(n: int) -> void:
	batalha_atual = n
	regiao_atual = D.BATALHAS[n]["regiao"]


## Fim da batalha: grava HP/MP, dá XP por inimigo derrotado e as recompensas.
## `estado` = id -> {hp, mp, xp}. Devolve um resumo para a tela de resultado.
func concluir_batalha(n: int, estado: Dictionary) -> Dictionary:
	var resumo := {"niveis": [], "itens": {}, "recruta": ""}
	# XP dividido: o grupo soma o XP dos inimigos derrotados e reparte igual (+10 por lutar).
	var total := 0
	for id in estado:
		total += estado[id]["xp"]
	var parte: int = total / maxi(1, estado.size()) + 10
	resumo["xp"] = parte
	for id in estado:
		var h: Dictionary = herois[id]
		h["hp"] = maxi(1, estado[id]["hp"])  # quem caiu volta com 1 HP
		h["mp"] = mp_max(id)
		h["xp"] += parte
		while h["xp"] >= Regras.XP_POR_NIVEL:
			h["xp"] -= Regras.XP_POR_NIVEL
			h["nivel"] += 1
			var cres := Regras.crescimento(classe(id))
			for k in cres:
				h["atributos"][k] += cres[k]
			h["hp"] = hp_max(id)
			h["mp"] = mp_max(id)
			resumo["niveis"].append([id, h["nivel"]])
	var b: Dictionary = D.BATALHAS[n]
	for item in b.get("recompensa", {}):
		adicionar_item(item, b["recompensa"][item])
		resumo["itens"][item] = b["recompensa"][item]
	if b.has("recruta") and not herois[b["recruta"]]["recrutado"]:
		herois[b["recruta"]]["recrutado"] = true
		resumo["recruta"] = b["recruta"]
	if not n in vencidas:
		vencidas.append(n)
	batalha_atual = 0
	var prox := proxima_batalha()
	if prox > 0:
		regiao_atual = D.BATALHAS[prox]["regiao"]
	salvar()
	mudou.emit()
	return resumo


## Derrota: o grupo se recupera e a batalha pode ser tentada de novo.
func derrota() -> void:
	batalha_atual = 0
	descansar()


# --- salvar / carregar --------------------------------------------------------------------

func salvar() -> void:
	if _teste:
		return
	var f := FileAccess.open(ARQUIVO, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"herois": herois, "inventario": inventario, "vencidas": vencidas, "regiao": regiao_atual}, "\t"))


func tem_jogo_salvo() -> bool:
	return FileAccess.file_exists(ARQUIVO)


func carregar() -> bool:
	if not tem_jogo_salvo():
		return false
	var dados = JSON.parse_string(FileAccess.get_file_as_string(ARQUIVO))
	if not dados is Dictionary or not dados.has("herois"):
		return false
	novo_jogo()  # garante todas as chaves; depois sobrescreve com o salvo
	for id in dados["herois"]:
		if herois.has(id):
			var h: Dictionary = dados["herois"][id]
			for k in h:
				herois[id][k] = int(h[k]) if (h[k] is float) else h[k]
			for k in herois[id]["atributos"]:
				herois[id]["atributos"][k] = int(herois[id]["atributos"][k])
	inventario = {}
	for k in dados.get("inventario", {}):
		inventario[k] = int(dados["inventario"][k])
	vencidas = []
	for n in dados.get("vencidas", []):
		vencidas.append(int(n))
	regiao_atual = dados.get("regiao", "vila")
	mudou.emit()
	return true
