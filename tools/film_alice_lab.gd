extends Node

# Labo des films « Alice · X rattrapé(e) » et de l'épilogue (0.17).
#   godot --headless -- --tool film_alice_lab --fal-mode measure
#     mesures du squelette de chaque perso (mètres) : jambe, bras, hauteur du bassin, pied
#   godot --headless -- --tool film_alice_lab --fal-mode space
#     place libre et sol autour de l'ancre des films, sur les trois cartes
#   godot --headless -- --tool film_alice_lab --fal-mode check --fal-film ending_killer --fal-people Simon [--fal-map snow]
#     joue le film à 60 i/s et relève, pour chaque corps : glissement des pieds posés (cm), pieds
#     ou mains sous le sol, os qui sortent du décor, et les clips joués (aucun clip du jeu permis)
#   xvfb-run … godot --rendering-driver opengl3 -- --tool film_alice_lab --fal-mode shots --fal-film ending_killer
#     --fal-people Simon --fal-from 2 --fal-to 4 --fal-step 0.1 [--fal-times 1,2] [--fal-out DIR]
#     [--fal-size 640x360] [--fal-witness side|side-|front|back|top --fal-who 0|1|pair --fal-dist 4]
#     images du film (cadrage du film, ou caméra témoin fixe pour juger le mouvement)

var world: Node
var mode: String = "measure"
var film_kind: String = "ending_killer"
var people: Array = ["Simon"]
var map_id: String = "school"
var times: Array[float] = []
var from_t: float = 0.0
var to_t: float = -1.0
var step: float = 0.25
var out_dir: String = "/tmp/film_alice_lab"
var size: Vector2i = Vector2i(960, 540)
var witness: String = ""
var who: String = "0"
var dist: float = 4.2
var height: float = 0.95
var pose_set: String = "axes"
var views: Array = ["front", "side", "three"]
var each: bool = false
const AnimLibrary = preload("res://anim_library.gd")
const Poses = preload("res://tools/film_alice_poses.gd")


func setup(owner: Node) -> void :
	world = owner
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(args.size()):
		var value: String = args[i + 1] if i + 1 < args.size() else ""
		match args[i]:
			"--fal-mode": mode = value
			"--fal-film": film_kind = value
			"--fal-people": people = Array(value.split(","))
			"--fal-map": map_id = value
			"--fal-times":
				for part: String in value.split(","): times.append(float(part))
			"--fal-from": from_t = float(value)
			"--fal-to": to_t = float(value)
			"--fal-step": step = float(value)
			"--fal-out": out_dir = value
			"--fal-size":
				var parts: PackedStringArray = value.split("x")
				size = Vector2i(int(parts[0]), int(parts[1]))
			"--fal-witness": witness = value
			"--fal-who": who = value
			"--fal-dist": dist = float(value)
			"--fal-height": height = float(value)
			"--fal-pose": pose_set = value
			"--fal-views": views = Array(value.split(","))
			"--fal-each": each = true
	_run.call_deferred()


func _run() -> void :
	for i: int in range(3): await get_tree().process_frame
	match mode:
		"measure": await _measure()
		"space":
			for map_name: String in ["school", "forest", "snow"]:
				if map_name != "school": world._rebuild_map(map_name)
				for i: int in range(4): await get_tree().physics_frame
				_space(map_name)
		"check": await _check()
		"shots": await _shots()
		"pose": await _poses()
	get_tree().quit()


func _entry() -> Dictionary:
	return {"id": "lab", "title": "lab", "category": "fins", "kind": film_kind, "participants": people, "focus": str(people[0]) if not people.is_empty() else "Ashura", "duration": PaperCinema.duration_for(film_kind, people), "description": ""}


func _open_film() -> PaperCinema:
	world.gallery.open()
	if map_id != "school": world._rebuild_map(map_id)
	for i: int in range(4): await get_tree().physics_frame
	world.gallery.play_entry(_entry())
	world.gallery.playing = false
	world.ui.hide_gallery_transport()
	return world.film


# ------------------------------------------------------------------ IMAGES --

func _shots() -> void :
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = size
	for i: int in range(6): await get_tree().process_frame
	var film: PaperCinema = await _open_film()
	if not witness.is_empty(): film._shots.clear()
	if times.is_empty():
		var end: float = film.duration if to_t < 0.0 else minf(to_t, film.duration)
		var t: float = from_t
		while t <= end + 0.0001:
			times.append(t)
			t += step
	print("FAL_SHOTS kind=", film_kind, " people=", people, " duration=", film.duration, " frames=", times.size())
	var index: int = 0
	for t: float in times:
		for k: int in range(2):
			world.gallery.seek(t)
			if not witness.is_empty(): _witness(film)
			await get_tree().process_frame
		if not witness.is_empty(): _witness(film)
		RenderingServer.force_draw()
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		var path: String = "%s/f%03d_%05.2f.png" % [out_dir, index, t]
		img.save_png(path)
		index += 1
	print("FAL_SHOTS_DONE ", out_dir)


func _witness(film: PaperCinema) -> void :
	if film.takes.is_empty(): return
	var target: Vector3
	if who == "pair" and film.takes.size() > 1:
		target = (film.takes[0].visual.global_position + film.takes[film.takes.size() - 1].visual.global_position) * 0.5
	else:
		target = film.takes[clampi(int(who), 0, film.takes.size() - 1)].visual.global_position
	target += Vector3.UP * height
	var offset: Vector3
	match witness:
		"side": offset = film.right * dist
		"side-": offset = - film.right * dist
		"front": offset = film.forward * dist
		"back": offset = - film.forward * dist
		"top": offset = Vector3.UP * dist + film.forward * 0.01
		"three": offset = (film.right * 0.75 + film.forward * 0.65).normalized() * dist
		_: offset = film.right * dist
	var camera: Camera3D = world.camera
	camera.global_position = target + offset + Vector3.UP * 0.15
	camera.look_at(target)
	camera.fov = 40.0
	world.ui.update_film("", "", 0.0)


# -------------------------------------------------------------------- POSES --
# Rangée de corps posés (tools/film_alice_poses.gd), photographiée sous plusieurs angles.

func _poses() -> void :
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = size
	for i: int in range(6): await get_tree().process_frame
	var film: PaperCinema = await _open_film()
	world.gallery.seek(minf(2.0, film.duration * 0.5))
	film._shots.clear()
	for take: Variant in film.takes: take.shown = false
	for take: Variant in film.takes: take.visual.visible = false
	var entries: Array = Poses.sets().get(pose_set, [])
	var bodies: Array[PaperVisual] = []
	var longest: float = 0.0
	for index: int in range(entries.size()):
		var entry: Dictionary = entries[index]
		var clip_name: String = "fal_lab_%d" % index
		AnimLibrary._all[clip_name] = {"len": float(entry.t) + 2.0, "in": 0.0, "out": 0.0, "face": str(entry.get("face", "")), "keys": entry["keys"]}
		AnimLibrary._cache.clear()
		var visual: PaperVisual = PaperVisual.new()
		visual.lod_enabled = false
		film.add_child(visual)
		visual.setup(str(entry.person))
		visual.fidgets = false
		var facing: Vector3 = film._world_direction(entry.get("dir", Vector3(0, 0, 1)))
		visual.global_position = film._world_spot(_lane(entry, 0.0))
		visual.rotation = Vector3(0.0, atan2( - facing.x, - facing.z), 0.0)
		visual.set_combat_state({"grounded": false})
		visual.play(clip_name)
		bodies.append(visual)
		longest = maxf(longest, float(entry.t))
	# sans --fal-times : une seule image à la fin de chaque clip ; sinon une image par instant
	var stops: Array[float] = times.duplicate()
	if stops.is_empty(): stops = [longest]
	var clock: float = 0.0
	var index_frame: int = 0
	var slides: Array = []
	for visual: PaperVisual in bodies: slides.append({-1: [], 1: [], "worst": 0.0, "count": 0, "float": 0.0})
	for stop: float in stops:
		while clock < stop - 0.0001:
			var dt: float = minf(1.0 / 60.0, stop - clock)
			clock += dt
			for index: int in range(bodies.size()):
				if times.is_empty() and clock > float(entries[index].t) + 0.0001: continue
				bodies[index].global_position = film._world_spot(_lane(entries[index], clock))
				bodies[index].animate(dt, Vector3.ZERO, false, false)
				_track_feet(bodies[index], str(entries[index].person), slides[index], clock)
		if DisplayServer.get_name() == "headless":
			index_frame += 1
			continue
		var groups: Array = []
		if each:
			for visual: PaperVisual in bodies: groups.append([visual])
		else: groups.append(bodies)
		for group_index: int in range(groups.size()):
			var center: Vector3 = Vector3.ZERO
			for visual: PaperVisual in groups[group_index]: center += visual.global_position
			center = center / float(maxi(1, (groups[group_index] as Array).size())) + Vector3.UP * height
			for view: String in views:
				var offset: Vector3
				match view:
					"front": offset = film.forward * dist
					"back": offset = - film.forward * dist
					"side": offset = film.right * dist
					"side-": offset = - film.right * dist
					"top": offset = Vector3.UP * dist + film.forward * 0.4
					"low": offset = film.forward * dist * 0.8 + Vector3.DOWN * (height - 0.25)
					_: offset = (film.right * 0.7 + film.forward * 0.7).normalized() * dist
				for visual: PaperVisual in bodies: visual.visible = not each or visual in groups[group_index]
				for k: int in range(2):
					world.camera.global_position = center + offset + Vector3.UP * 0.1
					world.camera.look_at(center)
					world.camera.fov = 40.0
					world.ui.update_film("", "", 0.0)
					await get_tree().process_frame
				RenderingServer.force_draw()
				await RenderingServer.frame_post_draw
				var tag: String = ("%s_" % str(entries[group_index].person)) if each else ""
				var path: String = "%s/%s_%s%s_%03d_%05.2f.png" % [out_dir, pose_set, tag, view, index_frame, stop]
				get_viewport().get_texture().get_image().save_png(path)
		index_frame += 1
	for index: int in range(bodies.size()):
		var info: Dictionary = slides[index]
		print("FAL_FEET %s appuis=%d glissement_max=%.1fcm pied_en_l_air_max=%.1fcm" % [entries[index].person, int(info.count), float(info.worst), float(info.float)])
	print("FAL_POSE_DONE ", out_dir)


# Appuis d'un corps du labo : cheville à moins de 2,5 cm de sa hauteur de repos = pied posé ;
# on relève le plus grand déplacement au sol pendant un appui.
func _track_feet(visual: PaperVisual, person: String, info: Dictionary, clock: float = 0.0) -> void :
	var ankles: Dictionary = visual.get("_ankles")
	var floor_y: float = visual.global_position.y
	for side: int in [-1, 1]:
		var rest: float = float((Poses.FA.RIG[person].feet[0 if side < 0 else 1] as Vector3).y)
		var p: Vector3 = (ankles[side] as Node3D).global_position
		var list: Array = info[side]
		if OS.get_cmdline_user_args().has("--fal-debug") and person == "Elly": print("FAL_DBG %s side=%d root=%s ankle=%s h=%.3f" % [person, side, str(visual.global_position), str(p), p.y - floor_y - rest])
		if p.y - floor_y < rest + 0.025:
			list.append(p)
		elif not list.is_empty():
			if list.size() >= 3:
				var most: float = 0.0
				for q: Vector3 in list: most = maxf(most, Vector2(q.x - list[0].x, q.z - list[0].z).length())
				info.worst = maxf(float(info.worst), most * 100.0)
				if most > 0.03: print("FAL_SLIDE %s %s %.2f-%.2f %.1fcm (%d images)" % [person, "G" if side < 0 else "D", clock - list.size() / 60.0, clock, most * 100.0, list.size()])
				info.count = int(info.count) + 1
			list.clear()


# position de la racine d'un essai à l'instant t (couloir x, trajet facultatif)
func _lane(entry: Dictionary, t: float) -> Vector3:
	var base: Vector3 = Vector3(float(entry.get("x", 0.0)), 0.0, float(entry.get("z", 0.0)))
	if entry.has("path"): return base + Poses.FA.at(entry.path, t)
	return base


# ------------------------------------------------------------- VÉRIFICATION --

func _check() -> void :
	var film: PaperCinema = await _open_film()
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var dt: float = 1.0 / 60.0
	var report: Array = []
	for take: Variant in film.takes: report.append({"person": take.person, "slides": [], "under": [], "clips": {}, "contact": {-1: [], 1: []}, "floor": INF})
	var t: float = 0.0
	film.seek(0.0)
	while t <= film.duration + 0.0001:
		film.update(t, dt)
		for index: int in range(film.takes.size()):
			var take: Variant = film.takes[index]
			var visual: PaperVisual = take.visual
			var info: Dictionary = report[index]
			var action: String = str(visual.get("_action"))
			if not action.is_empty() and float(visual.get("_action_time")) > 0.0: info.clips[action] = true
			if not visual.visible: continue
			var root: Vector3 = visual.global_position
			var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(root + Vector3.UP * 0.6, root + Vector3.DOWN * 2.0, 1))
			var floor_y: float = float(hit.position.y) if not hit.is_empty() else root.y
			info.floor = minf(float(info.floor), floor_y - root.y)
			var ankles: Dictionary = visual.get("_ankles")
			var toes: Dictionary = visual.get("_toes")
			for side: int in [-1, 1]:
				var ankle: Vector3 = (ankles[side] as Node3D).global_position
				var toe: Vector3 = (toes[side] as Node3D).global_position
				var low: float = minf(ankle.y, toe.y) - floor_y
				if OS.get_cmdline_user_args().has("--fal-debug") and absf(fposmod(t, 0.5)) < dt * 0.5: print("FAL_DEBUG %.2f %s %s ankle=%.3f toe=%.3f root=%.3f" % [t, take.person, "G" if side < 0 else "D", ankle.y - floor_y, toe.y - floor_y, root.y - floor_y])
				var list: Array = info.contact[side]
				# appui : cheville à moins de 2,5 cm de sa hauteur au repos (au-dessus de la racine)
				var rest: float = float((Poses.FA.RIG[take.person].feet[0 if side < 0 else 1] as Vector3).y) if Poses.FA.RIG.has(take.person) else 0.1
				var planted: bool = ankle.y - root.y < rest + 0.025
				if planted:
					list.append([t, ankle])
				elif not list.is_empty():
					_close_contact(info, side, list)
				if ankle.y - root.y < rest - 0.06: info.under.append("%.2f %s %.0fcm" % [t, "pied G" if side < 0 else "pied D", low * 100.0])
			for socket: String in ["hand_l", "hand_r", "head"]:
				var p: Vector3 = visual.socket_position(socket)
				if p.y - floor_y < -0.04: info.under.append("%.2f %s %.0fcm" % [t, socket, (p.y - floor_y) * 100.0])
		t += dt
	for info: Dictionary in report:
		for side: int in [-1, 1]:
			if not (info.contact[side] as Array).is_empty(): _close_contact(info, side, info.contact[side])
		var worst: float = 0.0
		var lines: Array = []
		for slide: Array in info.slides:
			worst = maxf(worst, float(slide[2]))
			if float(slide[2]) > 2.5: lines.append("%.2f-%.2f %s %.1fcm" % [float(slide[0]), float(slide[1]), "G" if int(slide[3]) < 0 else "D", float(slide[2])])
		print("FAL_CHECK %s appuis=%d glissement_max=%.1fcm floor=%.3f clips=%s" % [info.person, (info.slides as Array).size(), worst, float(info.floor), str((info.clips as Dictionary).keys())])
		if not lines.is_empty(): print("  glisse : ", ", ".join(PackedStringArray(lines.slice(0, 14))))
		var under: Array = info.under
		if not under.is_empty(): print("  sous le sol (%d) : %s" % [under.size(), ", ".join(PackedStringArray(_thin(under).slice(0, 14)))])
	print("FAL_CHECK_DONE")


func _close_contact(info: Dictionary, side: int, list: Array) -> void :
	if list.size() >= 4:
		var start: Vector3 = list[0][1]
		var most: float = 0.0
		for entry: Array in list:
			var p: Vector3 = entry[1]
			most = maxf(most, Vector2(p.x - start.x, p.z - start.z).length())
		info.slides.append([float(list[0][0]), float(list[list.size() - 1][0]), most * 100.0, side])
	list.clear()


# une ligne sur six, pour garder un relevé lisible
func _thin(list: Array) -> Array:
	var out: Array = []
	for i: int in range(list.size()):
		if i % 6 == 0: out.append(list[i])
	return out


# ------------------------------------------------------------------ MESURES --

# Place libre autour de l'ancre des films (coordonnées du film : x à droite, z vers la sortie).
func _space(map_name: String) -> void :
	var anchor: Vector3 = world.school.cinematic_anchor
	var finish: Vector3 = world.school.cinematic_exit
	var forward: Vector3 = finish - anchor
	forward.y = 0.0
	forward = forward.normalized()
	var right: Vector3 = Vector3.UP.cross(forward).normalized()
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var line: String = "SPACE %s anchor=%s length=%.2f" % [map_name, str(anchor), anchor.distance_to(finish)]
	for z: float in [-8.0, -4.0, 0.0, 4.0]:
		for dir: Vector2 in [Vector2(0, 1), Vector2(0, -1), Vector2(1, 0), Vector2(-1, 0)]:
			var from: Vector3 = anchor + forward * z + Vector3.UP * 1.0
			var to: Vector3 = from + (right * dir.x + forward * dir.y) * 30.0
			var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1)
			var hit: Dictionary = space.intersect_ray(query)
			var free: float = from.distance_to(hit.position) if not hit.is_empty() else 30.0
			line += " z%+.0f%s=%.1f" % [z, {Vector2(0, 1): "+z", Vector2(0, -1): "-z", Vector2(1, 0): "+x", Vector2(-1, 0): "-x"}[dir], free]
	print(line)
	var ground: String = "GROUND %s" % map_name
	for z: float in [-9.0, -6.0, -3.0, 0.0, 3.0, 6.0]:
		for x: float in [-3.0, 0.0, 3.0]:
			var top: Vector3 = anchor + forward * z + right * x + Vector3.UP * 3.0
			var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(top, top + Vector3.DOWN * 8.0, 1))
			ground += " (%+.0f,%+.0f)=%s" % [x, z, ("%+.2f" % (float(hit.position.y) - anchor.y)) if not hit.is_empty() else "--"]
	print(ground)


func _measure() -> void :
	for person: String in ["Simon", "Usayuko", "Ashura", "Lysia", "Elly", "Bleuette", "Alice"]:
		var visual: PaperVisual = PaperVisual.new()
		add_child(visual)
		visual.setup(person)
		await get_tree().process_frame
		var s: float = float(visual.get("_model_scale"))
		var arm: Dictionary = visual.get("_arm_length")
		var foot: Dictionary = visual.get("_foot_rest")
		var shoulder: Dictionary = visual.get("_shoulder_rest")
		var style: Dictionary = visual.get("_style")
		var hip_rest: Dictionary = visual.get("_hip_rest")
		print("MEASURE %s scale=%.3f leg=%.3f arm=%.3f base=%.3f toe=%.3f foot_l=%s foot_r=%s hip_r=%s shoulder_r=%s stance=%.3f height=%.3f" % [person, s,
			float(visual.get("_leg_reach")) * s, float(arm[1]) * s, float(visual.get("_base_height")) * s,
			float(visual.get("_toe_length")) / maxf(float(visual.get("_leg_reach")), 0.001),
			str((foot[-1] as Vector3) * s), str((foot[1] as Vector3) * s), str((hip_rest[1] as Vector3) * s), str((shoulder[1] as Vector3) * s), float(style.get("stance", 1.0)), visual.visual_height()])
		visual.queue_free()
