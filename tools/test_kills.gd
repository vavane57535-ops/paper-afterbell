extends Node

# Banc d'essai des exécutions d'Alice.
#   godot -- --tool test_kills --kill Usayuko|Elly|Lysia|Simon|Ashura|Bleuette|all
#         [--phase6 | --both] [--view killer|victim|world] [--frames 0.2,0.6,...] [--out dir]
#         [--cam cine,side,other,af,vf,top,x:...] [--scale 0.4] [--map school|forest|snow]
#         [--time 70 (chrono avant le kill : vérifie que la sortie reste ouverte)]
# Sans rendu (--headless) : déroule chaque exécution, vérifie la mort, le verrou
# d'Alice, le stun de Lysia et le bonus de +45 s, puis affiche KILL_TEST.

const NAMES: Array[String] = ["Usayuko", "Elly", "Lysia", "Simon", "Ashura", "Bleuette"]

var world
var targets: Array[String] = []
var phase6_modes: Array[bool] = [false]
var view: String = "killer"
var frames: Array[float] = []
var out_dir: String = "user://kill_frames"
var time_scale: float = 0.4
var preset_time: float = -1.0
var cams: Array[String] = ["cine"]
var headless: bool = false
var failures: Array[String] = []
var results: Array[String] = []

func setup(w) -> void:
	world = w
	headless = DisplayServer.get_name() == "headless"
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i in range(args.size()):
		var next: String = args[i + 1] if i + 1 < args.size() else ""
		match args[i]:
			"--kill":
				if next == "all": targets.assign(NAMES)
				else:
					for part: String in next.split(",", false): targets.append(part)
			"--phase6": phase6_modes = [true]
			"--both": phase6_modes = [false, true]
			"--view": view = next
			"--frames":
				for part: String in next.split(",", false): frames.append(float(part))
			"--out": out_dir = next
			"--scale": time_scale = float(next)
			"--time": preset_time = float(next)
			"--cam": cams.assign(next.split(",", false))
	if targets.is_empty(): targets.assign(NAMES)
	if frames.is_empty() and not headless: frames.assign([0.15, 0.6, 1.2, 1.9, 2.6, 3.4])
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	for phase6: bool in phase6_modes:
		for victim_name: String in targets:
			await _scene(victim_name, phase6)
	print("KILL_TEST ", "OK" if failures.is_empty() else "FAIL", " ", JSON.stringify({"results": results, "failures": failures}))
	get_tree().quit()


func o_eye(show: Dictionary, cam: String) -> Array:
	var o: Vector3 = show.o
	var f: Vector3 = show.f
	var r: Vector3 = show.r
	var half: float = float(show.gap) * 0.5
	var alice: PaperActor = world.actors.get(int(show.killer))
	var victim: PaperActor = world.actors.get(int(show.victim))
	var a_head: Vector3 = alice.visual.fx_source().socket_position("head") if alice else o
	var v_head: Vector3 = victim.visual.socket_position("head") if victim else o
	# Caméra libre : « x:v.head:0.4/-0.5/0.8>v.eyes:0/0/0@34 » (décalages dans le repère de la scène).
	if cam.begins_with("x:") and alice and victim:
		var spec: String = cam.substr(2)
		var fov: float = float(spec.get_slice("@", 1)) if spec.contains("@") else 40.0
		var ends: PackedStringArray = spec.get_slice("@", 0).split(">")
		var points: Array[Vector3] = []
		for part: String in ends:
			var bits: PackedStringArray = part.split(":")
			var who: PaperVisual = alice.visual.fx_source() if bits[0].begins_with("a") else victim.visual
			var at: Vector3 = who.socket_position(bits[0].get_slice(".", 1))
			var n: PackedStringArray = bits[1].split("/") if bits.size() > 1 else PackedStringArray(["0", "0", "0"])
			points.append(at + r * float(n[0]) + Vector3.UP * float(n[1]) + f * float(n[2]))
		return [points[0], points[1] if points.size() > 1 else o, fov]
	match cam:
		"other": return [o - r * 3.2 + Vector3.UP * 1.2, o + Vector3.UP * 0.95, 44.0]
		"af": return [o + r * 1.25 + Vector3.UP * 1.45 - f * 0.15 + f * half, a_head - Vector3.UP * 0.12, 40.0]
		"vf": return [o - r * 1.25 + Vector3.UP * 1.4 + f * 0.15 - f * half, v_head - Vector3.UP * 0.12, 40.0]
		"top": return [o + r * 0.9 + Vector3.UP * 4.0 + f * 0.2, o, 52.0]
	return [o + r * 3.2 + Vector3.UP * 1.2, o + Vector3.UP * 0.95, 44.0]


func _scene(victim_name: String, phase6: bool) -> void:
	var local_name: String = victim_name if view == "victim" else ("Ashura" if victim_name != "Ashura" else "Simon")
	world.selected = local_name
	world.start_solo(view == "killer")
	while world.phase != "playing": await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	var alice: PaperActor = world.killer_actor()
	var victim: PaperActor = null
	var observer: PaperActor = null
	for a: PaperActor in world.actors.values():
		a.bot = false
		a.move_input = Vector3.ZERO
		a.velocity = Vector3.ZERO
		if a.character == victim_name: victim = a
		if view == "world" and a.character == local_name: observer = a
	if victim == null or alice == null:
		failures.append(victim_name + ": acteurs introuvables")
		return
	var base: Vector3 = world.school.spawn_points[1] + Vector3(0, 0, -9)
	var slot: int = 0
	for a: PaperActor in world.actors.values():
		if a == victim or a == alice or a == observer: continue
		a.global_position = world.school.spawn_points[1] + Vector3(-9.0 + 3.6 * slot, 0, 4.0)
		a.reset_physics_interpolation()
		slot += 1
	victim.global_position = base
	victim.aim = Vector3.BACK
	victim.reset_physics_interpolation()
	alice.global_position = base + Vector3(0.6, 0, -2.4)
	alice.aim = (base - alice.global_position).normalized()
	alice.reset_physics_interpolation()
	if observer:
		observer.global_position = base + Vector3(4.2, 0, 1.5)
		observer.reset_physics_interpolation()
		var look: Vector3 = (base + Vector3(0, 0, -1.2) - observer.global_position)
		world.yaw = atan2(-look.x, -look.z)
		world.pitch = -0.12
	elif view == "killer":
		world.yaw = atan2(-alice.aim.x, -alice.aim.z)
	else:
		world.yaw = atan2(alice.global_position.x - base.x, alice.global_position.z - base.z) + PI
	if victim_name != "Lysia": victim.effects["revived"] = true
	victim.hp = 1.0
	if phase6:
		alice.effects["phase6"] = 30.0
		alice.effects["true_form_used"] = true
		world.event("phase6", {"actor": alice.id, "active": true, "true_form": true, "duration": 30.0, "position": alice.position})
		await get_tree().create_timer(2.2).timeout
	if preset_time >= 0.0: world.time_left = preset_time
	await get_tree().create_timer(0.6).timeout
	var exit_before: bool = world.exit_flow.opened
	var before: float = float(world.time_left)
	var clock0: float = float(world.clock)
	var tag: String = victim_name + ("_tf" if phase6 else "")
	for attempt in range(8):
		world.combat.damage(victim, 999.0, alice, false, "slash")
		if bool(victim.effects.get("dying", false)): break
	var scene: Dictionary = {}
	for s: Dictionary in world.kill_scenes._scenes.values(): scene = s
	if scene.is_empty():
		failures.append(tag + ": pas d'exécution déclenchée (dying=%s)" % str(victim.effects.get("dying", false)))
		return
	var total: float = float(scene.lead) + float(scene.length)
	var stun_seen: float = 0.0
	var lock_seen: bool = false
	if not headless: Engine.time_scale = time_scale
	var index: int = 0
	var shots: Array[float] = frames.duplicate()
	while float(world.clock) - clock0 < total + 1.2:
		var t: float = float(world.clock) - clock0
		if float(alice.effects.get("kill_lock", 0.0)) > 0.0: lock_seen = true
		stun_seen = maxf(stun_seen, float(alice.effects.get("stun", 0.0)))
		if index < shots.size() and t >= shots[index]:
			Engine.time_scale = 0.0
			for cam: String in cams:
				var show: Dictionary = {}
				for sh: Dictionary in world.kill_scenes._shows.values(): show = sh
				var rig = world.camera_rig
				world.kill_scenes.camera_enabled = cam == "cine"
				if cam == "cine": await get_tree().process_frame
				if cam != "cine" and not show.is_empty():
					world.camera_rig = null
					world.kill_scenes.camera_enabled = false
					var spec: Array = o_eye(show, cam)
					world.camera.global_position = spec[0]
					world.camera.look_at(spec[1])
					world.camera.fov = float(spec[2])
				await get_tree().process_frame
				await RenderingServer.frame_post_draw
				var image: Image = world.get_viewport().get_texture().get_image()
				var cam_tag: String = ("x%d" % cams.find(cam)) if cam.begins_with("x:") else cam
				var path: String = "%s/%s_%s_%s_%02d_%.2f.png" % [out_dir, tag, view, cam_tag, index, float(world.clock) - clock0]
				image.save_png(path)
				print("KILL_FRAME ", path)
				world.camera_rig = rig
			world.kill_scenes.camera_enabled = true
			Engine.time_scale = time_scale
			index += 1
			continue
		await get_tree().physics_frame
	Engine.time_scale = 1.0
	await get_tree().create_timer(0.2).timeout
	var gained: float = float(world.time_left) - before + (float(world.clock) - clock0)
	var line: String = "%s alive=%s lock=%s stun=%.1f time+%.1f alice_lock_now=%.2f" % [tag, str(victim.alive), str(lock_seen), stun_seen, gained, float(alice.effects.get("kill_lock", 0.0))]
	if preset_time >= 0.0:
		line += " exit=%s->%s time_left=%.1f" % [str(exit_before), str(world.exit_flow.opened), float(world.time_left)]
		if exit_before and not world.exit_flow.opened and not phase6: failures.append(tag + ": la sortie s'est refermée après le bonus")
	results.append(line)
	print("KILL_RESULT ", line)
	if victim.alive: failures.append(tag + ": la victime est encore vivante")
	if not lock_seen: failures.append(tag + ": Alice jamais verrouillée")
	if float(alice.effects.get("kill_lock", 0.0)) > 0.0: failures.append(tag + ": Alice toujours verrouillée")
	if victim_name == "Lysia" and not phase6 and stun_seen < 4.0: failures.append(tag + ": pas de stun de 5 s")
	if gained < 40.0: failures.append(tag + ": bonus de temps absent (%.1f)" % gained)
