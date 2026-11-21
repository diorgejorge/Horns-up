extends Node
## Autoload `Dialogo`: toca uma cena de diálogo pelo id, com as falas em
## scripts/dialogo/falas_ato1.json ("b01_antes", "b12_durante", "b07_depois"...).
##   await Dialogo.tocar("b01_antes")
## Enquanto a cena roda o jogo fica pausado (get_tree().paused); quem precisar
## saber disso escuta `comecou` / `terminou` ou consulta `ativo()`.
## A caixa em si é scripts/ui/caixa_dialogo.gd (CaixaDialogo).

signal comecou(id: String)
signal terminou(id: String)

const ARQUIVO := "res://scripts/dialogo/falas_ato1.json"

var auto := false  # avança sozinho (testes automáticos)
var _cenas := {}
var _caixa: CaixaDialogo


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	auto = "--auto" in OS.get_cmdline_user_args()
	var json: Variant = JSON.parse_string(FileAccess.get_file_as_string(ARQUIVO))
	if json is Dictionary:
		_cenas = json.get("cenas", {})
	else:
		push_error("Dialogo: não consegui ler " + ARQUIVO)


## Falas de uma cena: [[falante, texto], ...]. Id desconhecido = [].
func falas(id: String) -> Array:
	return _cenas.get(id, [])


func existe(id: String) -> bool:
	return _cenas.has(id)


func ativo() -> bool:
	return _caixa != null and _caixa.ativo()


## Toca a cena e devolve quando o jogador passar a última fala.
func tocar(id: String) -> void:
	var linhas := falas(id)
	if linhas.is_empty():
		push_warning("Dialogo: cena sem falas: " + id)
		return
	if _caixa == null:
		_caixa = CaixaDialogo.new()
		add_child(_caixa)
	_caixa.auto = auto
	comecou.emit(id)
	await _caixa.mostrar(linhas)
	terminou.emit(id)
