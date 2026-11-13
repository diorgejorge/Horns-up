extends TestCase


func test_actions_exist() -> void:
	for a in ["move_left", "move_right", "jump", "attack"]:
		check(InputMap.has_action(a), "ação %s existe" % a)
		if InputMap.has_action(a):
			check(InputMap.action_get_events(a).size() >= 1, "ação %s tem tecla" % a)
