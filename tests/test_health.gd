extends TestCase


func test_damage_reduces_hp() -> void:
	var h := Health.new(5)
	check(h.take_damage(1), "dano aplicado")
	check_eq(h.hp, 4, "5 - 1 = 4")


func test_never_below_zero() -> void:
	var h := Health.new(5)
	h.take_damage(99)
	check_eq(h.hp, 0, "vida não fica negativa")
	check(h.is_dead(), "morto")


func test_died_emitted_once() -> void:
	var h := Health.new(5)
	var count := [0]
	h.died.connect(func(): count[0] += 1)
	h.take_damage(99)
	h.take_damage(99)
	check_eq(count[0], 1, "died sai uma vez só")


func test_invulnerable_ignores_damage() -> void:
	var h := Health.new(5, 1.0)
	check(h.take_damage(1), "primeiro dano vale")
	check(not h.take_damage(1), "segundo dano ignorado")
	check_eq(h.hp, 4, "vida 4")
	h.tick(1.0)
	check(h.take_damage(1), "dano volta a valer após invulnerabilidade")
	check_eq(h.hp, 3, "vida 3")


func test_heal_full_restores_max() -> void:
	var h := Health.new(5, 1.0)
	h.take_damage(3)
	var seen := [-1]
	h.changed.connect(func(v): seen[0] = v)
	h.heal_full()
	check_eq(h.hp, 5, "vida cheia")
	check_eq(seen[0], 5, "changed emitido com a vida cheia")
	check(h.take_damage(1), "cura zera a invulnerabilidade")


func test_dead_ignores_damage() -> void:
	var h := Health.new(5)
	h.take_damage(5)
	check(not h.take_damage(1), "morto não leva dano")
	check_eq(h.hp, 0, "vida continua 0")


func test_heal_full_after_death_rearms_died() -> void:
	var h := Health.new(5)
	var count := [0]
	h.died.connect(func(): count[0] += 1)
	h.take_damage(5)
	h.heal_full()
	check(not h.is_dead(), "cura explícita revive")
	h.take_damage(5)
	check_eq(count[0], 2, "died sai de novo na segunda morte")
