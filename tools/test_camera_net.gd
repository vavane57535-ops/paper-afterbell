extends Node

# Banc réseau du mode de caméra (commande « camera_mode » client → hôte, effet « cam_facing » renvoyé
# par les instantanés). Deux processus sur la même machine (port LAN du jeu) :
#   hôte   : godot --headless -- --host-test --duration 30 --tool test_camera_net
#   client : (moins de 3 s après) godot --headless -- --join-test --duration 27 --tool test_camera_net
# Le client passe en « Derrière » puis en « Libre 360° » et vérifie que l'hôte a bien appliqué chaque
# mode (valeur relue dans son propre acteur, synchronisée par l'hôte) et que son perso regarde où
# regarde la caméra en « Derrière ». L'hôte affiche l'effet qu'il voit sur l'acteur du client.

const Rig = preload("res://core_camera_rig.gd")

var world: Node
var rig: Variant

func setup(owner: Node) -> void :
	world = owner
	rig = world.camera_rig
	rig.persist = false
	_run.call_deferred()

func _wait(seconds: float) -> void :
	var elapsed: float = 0.0
	while elapsed < seconds:
		await get_tree().process_frame
		elapsed += get_process_delta_time()

func _effect() -> int:
	var me: PaperActor = world.local_actor()
	return int(me.effects.get("cam_facing", 0)) if me else -1

func _await_effect(code: int, timeout: float) -> float:
	var elapsed: float = 0.0
	while elapsed < timeout:
		if _effect() == code: return elapsed
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	return -1.0

func _run() -> void :
	var waited: float = 0.0
	while str(world.phase) != "playing" and waited < 20.0:
		await _wait(0.25)
		waited += 0.25
	if world.authoritative():
		for i: int in range(14):
			await _wait(1.0)
			var line: Array[String] = []
			for actor: PaperActor in world.actors.values():
				if int(actor.id) != world.local_id() and not actor.bot: line.append("%d:%s cam_facing=%d" % [actor.id, actor.character, int(actor.effects.get("cam_facing", 0))])
			print("CAMERA_NET host t=", i, " ", ", ".join(line) if not line.is_empty() else "aucun client")
		return
	var me: PaperActor = world.local_actor()
	if me == null:
		print("CAMERA_NET FAIL le client n'a pas d'acteur (rejoint trop tard ?)")
		get_tree().quit(1)
		return
	await _wait(1.0)
	var start: float = await _await_effect(Rig.FACING_FREE if rig.mode == Rig.MODE_FREE else Rig.FACING_BEHIND, 3.0)
	rig.set_mode(Rig.MODE_BEHIND, false)
	var behind: float = await _await_effect(Rig.FACING_BEHIND, 3.0)
	await _wait(0.6)
	me = world.local_actor()
	var facing: float = absf(rad_to_deg(angle_difference(me.visual.rotation.y, float(world.yaw)))) if me else 180.0
	rig.set_mode(Rig.MODE_FREE, false)
	var free: float = await _await_effect(Rig.FACING_FREE, 3.0)
	var ok: bool = start >= 0.0 and behind >= 0.0 and free >= 0.0 and facing < 5.0
	print("CAMERA_NET ", "OK" if ok else "FAIL", " mode initial confirmé : ", start >= 0.0, " · Derrière confirmé par l'hôte en ", snappedf(behind, 0.01), " s (perso aligné sur la caméra à ", snappedf(facing, 0.1), "°) · Libre 360° confirmé en ", snappedf(free, 0.01), " s")
	await _wait(0.5)
	get_tree().quit(0 if ok else 1)
