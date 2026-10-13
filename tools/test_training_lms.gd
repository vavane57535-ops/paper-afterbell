extends Node

# Terrain d'essai : bouton LMS pour chaque survivant (+65 PV, plafond 150), courage de Bleuette (180),
# Encourager de Bleuette sur le mannequin Simon. Imprime des lignes « TRAIN » puis quitte.
#   godot --headless -- --tool test_training_lms

var world: Node
var _failures: Array[String] = []


func setup(owner: Node) -> void :
	world = owner
	_run()


func _run() -> void :
	for _i: int in range(30): await get_tree().process_frame
	world.selected = "Bleuette"
	world.start_training(true)
	await _wait_frames(30)
	for name: String in PaperData.NAMES:
		world.training_action("character", name)
		await _wait_frames(10)
		var me: PaperActor = world.local_actor()
		me.hp = 40.0
		world.training_action("lms")
		await _wait_frames(5)
		print("TRAIN lms ", name, " hp=", me.hp, " max=", me.max_hp, " cap=", me.effects.get("lms_hp_cap", 0.0), " lms=", me.lms)
		var expected_max: float = maxf(150.0, float(PaperData.STATS[name][0]))
		_check(me.lms and absf(float(me.max_hp) - expected_max) < 0.01 and absf(float(me.hp) - expected_max) < 0.01, "terrain d'essai LMS %s : %.0f / %.0f attendu" % [name, expected_max, expected_max])
		if name == "Bleuette":
			me.cooldowns[3] = 0.0
			var used: bool = world.combat.use(me, 3)
			print("TRAIN courage used=", used, " hp=", me.hp, " max=", me.max_hp)
			_check(used and float(me.max_hp) == 180.0 and float(me.hp) == 180.0, "terrain d'essai : courage de Bleuette à 180 / 180")
	world.training_action("character", "Bleuette")
	await _wait_frames(10)
	var bleuette: PaperActor = world.local_actor()
	var simon: PaperActor = null
	for actor: PaperActor in world.actors.values():
		if actor != bleuette and actor.character == "Simon": simon = actor
	if simon == null:
		world.training_action("dummy_character", "Simon")
		await _wait_frames(10)
		for actor: PaperActor in world.actors.values():
			if actor != bleuette and actor.character == "Simon": simon = actor
	if simon != null:
		var spot: Vector3 = bleuette.global_position + bleuette.aim.normalized() * 2.5
		simon.global_position = spot
		simon.net_position = spot
		await _wait_frames(5)
		bleuette.cooldowns[0] = 0.0
		var ok: bool = world.combat.use(bleuette, 0, simon.id)
		await _wait_frames(3)
		world.practice.update_labels()
		print("TRAIN boost simon used=", ok, " sprint_bonus=", simon.effects.get("sprint_bonus", 0.0))
		_check(ok and float(simon.effects.get("sprint_bonus", 0.0)) > 0.0, "terrain d'essai : Encourager sur le mannequin Simon")
	else:
		print("TRAIN boost simon : pas de mannequin Simon trouvé")
	print("TRAIN_RESULT ", "OK" if _failures.is_empty() else "FAILED " + str(_failures))
	get_tree().quit()


func _wait_frames(count: int) -> void :
	for _i: int in range(count): await get_tree().physics_frame


func _check(ok: bool, message: String) -> void :
	if not ok: _failures.append(message)
	print("TRAIN_CHECK ", "OK " if ok else "FAIL ", message)
