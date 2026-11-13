extends SceneTree
## Runner: `godot --headless --path . -s tests/run_tests.gd`
## Roda todo `tests/test_*.gd` e sai com código 1 se algo falhar.
## Um teste que não executa nenhum `check` conta como falha
## (pega erros de script que abortam o teste no meio).

const TEST_DIR := "res://tests"
const SKIP := ["test_case.gd"]


func _initialize() -> void:
	_run()


func _run() -> void:
	var passed := 0
	var failed := 0
	var files: Array[String] = []
	for f in DirAccess.get_files_at(TEST_DIR):
		if f.begins_with("test_") and f.ends_with(".gd") and not SKIP.has(f):
			files.append(f)
	files.sort()
	for f in files:
		var script: Script = load(TEST_DIR.path_join(f))
		if script == null:
			print("FAIL %s: não carregou" % f)
			failed += 1
			continue
		for m in script.get_script_method_list():
			var name: String = m["name"]
			if not name.begins_with("test_"):
				continue
			var t = script.new()
			t.tree = self
			await t.call(name)
			if t.has_method("after_each"):
				await t.after_each()
			if t.checks_run == 0:
				t.failures.append("nenhum check rodou (erro de script?)")
			if t.failures.is_empty():
				passed += 1
				print("ok   %s::%s" % [f, name])
			else:
				failed += 1
				for msg in t.failures:
					print("FAIL %s::%s: %s" % [f, name, msg])
	print("%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
