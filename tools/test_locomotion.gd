extends Node

# Banc d'essai de la locomotion des survivants (marche, footing, sprint, boost).
# Lancement (rendu) :
#   xvfb-run -a -s "-screen 0 1280x800x24" godot --rendering-driver opengl3 -- --tool test_locomotion --loco-out /tmp/loco
# Options : --loco-chars Simon,Ashura  --loco-gaits walk,jog,sprint,boost,pocket  --loco-views side,front,three
#           --loco-metrics (mesures de glissement des pieds / genoux, sans capture ; marche aussi en --headless)
#           --loco-sequence (enchaînement arrêt → marche → course → sprint → saut → arrêt, planche de vignettes)
# Les images sont écrites dans --loco-out ; le tool quitte le jeu à la fin.

const NAMES: Array[String] = ["Ashura", "Usayuko", "Simon", "Lysia", "Elly", "Bleuette"]
const GAITS: Dictionary = {
	"walk": {"speed": 1.5, "state": {"sprinting": false}},
	"jog": {"speed": 6.3, "state": {"sprinting": false}},
	"sprint": {"speed": 10.2, "state": {"sprinting": true}},
	"boost": {"speed": 20.4, "state": {"sprinting": true, "speed_boost": 4.0, "boost_time": 4.0}},
	"killer_walk": {"speed": 7.0, "state": {"sprinting": false}},
	"killer_sprint": {"speed": 12.2, "state": {"sprinting": true}},
	"trueform": {"speed": 20.7, "state": {"sprinting": true, "phase6": 4.0}},
	"injured": {"speed": 10.2, "state": {"sprinting": true, "second_life": true}},
	"lms": {"speed": 10.2, "state": {"sprinting": true, "lms": true}},
	"chased": {"speed": 10.2, "state": {"sprinting": true, "chased": true}},
}
const PHASES: int = 8
const DT: float = 1.0 / 120.0

var world: Node
var out_dir: String = "user://loco"
var chars: Array[String] = []
var gaits: Array[String] = ["walk", "jog", "sprint"]
var views: Array[String] = ["side", "front"]
var metrics_only: bool = false
var no_clips: bool = false
var trace: bool = false
var charge: bool = false
var sequence: bool = false

var viewport: SubViewport
var stage: Node3D
var camera: Camera3D
var sun: DirectionalLight3D
var floor_mesh: MeshInstance3D
var hosts: Array[Node3D] = []
var visuals: Array[PaperVisual] = []


func setup(w: Node) -> void :
	world = w
	var args: PackedStringArray = OS.get_cmdline_user_args()
	chars.assign(NAMES)
	for i in range(args.size()):
		var next: String = args[i + 1] if i + 1 < args.size() else ""
		match args[i]:
			"--loco-out": out_dir = next
			"--loco-chars": chars.assign(Array(next.split(",", false)))
			"--loco-gaits": gaits.assign(Array(next.split(",", false)))
			"--loco-views": views.assign(Array(next.split(",", false)))
			"--loco-metrics": metrics_only = true
			"--loco-sequence": sequence = true
			"--loco-noclips": no_clips = true
			"--loco-trace": trace = true
			"--loco-charge": charge = true
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void :
	if no_clips:
		var library: GDScript = load("res://anim_library.gd")
		library.call("names")
		var all: Dictionary = library.get("_all")
		for person in NAMES:
			for clip in ["walk", "run", "sprint", "boost", "pocket"]: all.erase(clip + "@" + person)
		(library.get("_cache") as Dictionary).clear()
	_build_stage()
	for i in range(8): await get_tree().process_frame
	if not metrics_only:
		_layout("side")
		await _capture("")
	if metrics_only:
		for person in chars:
			for gait in gaits:
				if gait == "boost" and person != "Simon" and person != "Bleuette": continue
				_metrics(person, gait)
	elif sequence:
		for person in chars: await _sequence(person)
	elif charge:
		for person in chars: await _charge_sheet(person)
	else:
		for person in chars:
			for gait in gaits:
				if gait == "boost" and person != "Simon" and person != "Bleuette": continue
				await _sheet(person, gait)
	print("LOCO_DONE")
	get_tree().quit()


func _build_stage() -> void :
	if not DisplayServer.get_name() == "headless": get_viewport().disable_3d = true
	viewport = SubViewport.new()
	viewport.size = Vector2i(1600, 720)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	add_child(viewport)
	stage = Node3D.new()
	viewport.add_child(stage)
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.36, 0.4, 0.46)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.75, 0.8)
	env.ambient_light_energy = 0.45
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	stage.add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-55.0), deg_to_rad(35.0), 0.0)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 30.0
	stage.add_child(sun)
	floor_mesh = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(80, 80)
	floor_mesh.mesh = plane
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	var img: Image = Image.create(8, 8, false, Image.FORMAT_RGB8)
	for x in range(8):
		for y in range(8):
			var dark: bool = (int(x / 4.0) + int(y / 4.0)) % 2 == 0
			img.set_pixel(x, y, Color(0.55, 0.57, 0.6) if dark else Color(0.68, 0.7, 0.73))
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3(1.0, 1.0, 1.0)
	mat.roughness = 1.0
	floor_mesh.material_override = mat
	stage.add_child(floor_mesh)
	camera = Camera3D.new()
	stage.add_child(camera)
	camera.current = true


func _clear() -> void :
	for host in hosts: host.queue_free()
	hosts.clear()
	visuals.clear()


func _spawn(person: String, count: int) -> void :
	_clear()
	for i in range(count):
		var host: Node3D = Node3D.new()
		stage.add_child(host)
		var visual: PaperVisual = PaperVisual.new()
		visual.lod_enabled = false
		visual.blob_shadow = false
		host.add_child(visual)
		visual.setup(person)
		hosts.append(host)
		visuals.append(visual)


func _state(gait: String) -> Dictionary:
	var state: Dictionary = (GAITS[gait].state as Dictionary).duplicate()
	state["grounded"] = true
	state["vertical_speed"] = 0.0
	state["ruleset_om"] = true
	return state


func _step(visual: PaperVisual, speed: float, state: Dictionary, seconds: float) -> void :
	visual.set_combat_state(state)
	var steps: int = maxi(1, int(round(seconds / DT)))
	for i in range(steps): visual.animate(DT, Vector3(0, 0, - speed), false, false)


# Une planche : PHASES copies du même personnage réparties sur un cycle complet (deux rangées de 4 images).
# Rangée du haut : pose du pied gauche (phase 0) → mi-cycle ; rangée du bas : pose du pied droit → fin du cycle.
func _sheet(person: String, gait: String) -> void :
	var speed: float = float(GAITS[gait].speed)
	var state: Dictionary = _state(gait)
	_spawn(person, PHASES)
	for v in visuals: _step(v, speed, state, 1.6)
	for k in range(PHASES):
		visuals[k].set("_gait_phase", fposmod(float(k) / float(PHASES), 1.0))
	var cadence: float = float(visuals[0].get("_g_cadence"))
	var settle: float = round(0.5 * cadence) / maxf(cadence, 0.01)
	for v in visuals: _step(v, speed, state, maxf(settle, 1.0 / maxf(cadence, 0.01)))
	var phase0: float = float(visuals[0].get("_gait_phase"))
	print("SHEET %s %s speed=%.1f cadence=%.2f duty=%.2f phase0=%.3f" % [person, gait, speed, cadence, float(visuals[0].get("_g_stance")), phase0])
	for view in views:
		if view in ["three", "back", "close", "closeside", "feet"]:
			await _solo_sheet(person, gait, view)
			continue
		var halves: Array[Image] = []
		for half in range(2):
			for k in range(hosts.size()): hosts[k].visible = (k < PHASES / 2) == (half == 0)
			_layout(view, half)
			await _capture("")
			halves.append(viewport.get_texture().get_image())
		var sheet: Image = Image.create(halves[0].get_width(), halves[0].get_height() * 2, false, halves[0].get_format())
		sheet.blit_rect(halves[0], Rect2i(Vector2i.ZERO, halves[0].get_size()), Vector2i.ZERO)
		sheet.blit_rect(halves[1], Rect2i(Vector2i.ZERO, halves[1].get_size()), Vector2i(0, halves[0].get_height()))
		var path: String = "%s/%s_%s_%s.png" % [out_dir, person, gait, view]
		sheet.save_png(path)
		print("CAPTURE ", path)


# Charge du boost (Simon / Ashura, capacité 2) à 8 instants : position de départ en starting-blocks.
func _charge_sheet(person: String) -> void :
	var times: Array[float] = [0.15, 0.45, 0.9, 1.3, 1.9, 2.6, 3.1, 3.45]
	_spawn(person, PHASES)
	for k in range(PHASES):
		var held: float = 0.0
		var visual: PaperVisual = visuals[k]
		while held < times[k]:
			held += DT
			var state: Dictionary = _state("walk")
			state["boost_charging"] = true
			state["charging_boost"] = held
			state["boost_charge"] = held
			visual.set_combat_state(state)
			visual.animate(DT, Vector3.ZERO, false, false)
	print("SHEET %s charge" % person)
	for view in views:
		if view in ["three", "back", "close", "closeside", "feet"]:
			await _solo_sheet(person, "charge", view)
			continue
		var halves: Array[Image] = []
		for half in range(2):
			for k in range(hosts.size()): hosts[k].visible = (k < PHASES / 2) == (half == 0)
			_layout(view, half)
			await _capture("")
			halves.append(viewport.get_texture().get_image())
		var sheet: Image = Image.create(halves[0].get_width(), halves[0].get_height() * 2, false, halves[0].get_format())
		sheet.blit_rect(halves[0], Rect2i(Vector2i.ZERO, halves[0].get_size()), Vector2i.ZERO)
		sheet.blit_rect(halves[1], Rect2i(Vector2i.ZERO, halves[1].get_size()), Vector2i(0, halves[0].get_height()))
		var path: String = "%s/%s_charge_%s.png" % [out_dir, person, view]
		sheet.save_png(path)
		print("CAPTURE ", path)


# Vue 3/4 en perspective (comme la caméra du jeu), une image par phase, assemblées en grille 4 × 2.
func _solo_sheet(person: String, gait: String, view: String) -> void :
	var cell: Vector2i = Vector2i(400, 460)
	viewport.size = cell
	var grid: Image = null
	for k in range(hosts.size()):
		for j in range(hosts.size()):
			hosts[j].visible = j == k
			hosts[j].position = Vector3.ZERO
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = 30.0
		var eye: Vector3 = Vector3(3.6, 1.5, -2.6) if view == "three" else Vector3(2.2, 1.6, 3.8)
		var aim: Vector3 = Vector3(0, 0.82, 0)
		if view == "close":
			eye = Vector3(1.2, 1.0, -2.7)
			aim = Vector3(0, 0.78, 0)
		elif view == "closeside":
			eye = Vector3(3.0, 0.95, -0.2)
			aim = Vector3(0, 0.78, 0)
		elif view == "feet":
			eye = Vector3(2.4, 0.32, -0.1)
			aim = Vector3(0, 0.3, 0)
		camera.position = eye
		camera.look_at(aim)
		sun.rotation = Vector3(deg_to_rad(-45.0), deg_to_rad(120.0 if view == "three" else 30.0), 0.0)
		floor_mesh.scale = Vector3.ONE
		await _capture("")
		var image: Image = viewport.get_texture().get_image()
		if grid == null: grid = Image.create(cell.x * 4, cell.y * 2, false, image.get_format())
		grid.blit_rect(image, Rect2i(Vector2i.ZERO, cell), Vector2i((k % 4) * cell.x, (k / 4) * cell.y))
	viewport.size = Vector2i(1600, 720)
	var path: String = "%s/%s_%s_%s.png" % [out_dir, person, gait, view]
	grid.save_png(path)
	print("CAPTURE ", path)


func _layout(view: String, half: int = 0) -> void :
	var spacing: float = 1.3
	var row: int = PHASES / 2
	for k in range(hosts.size()):
		var slot: int = k % row
		var offset: float = (float(slot) - float(row - 1) * 0.5) * spacing
		match view:
			"side": hosts[k].position = Vector3(0, 0, - offset)
			"front": hosts[k].position = Vector3(- offset, 0, 0)
			"three": hosts[k].position = Vector3(offset * 0.8, 0, - offset * 0.6)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.45
	match view:
		"side":
			camera.position = Vector3(12.0, 1.05 + 12.0 * tan(deg_to_rad(5.0)), 0.0)
			camera.rotation = Vector3(deg_to_rad(-5.0), deg_to_rad(90.0), 0.0)
			sun.rotation = Vector3(deg_to_rad(-40.0), deg_to_rad(110.0), 0.0)
			floor_mesh.scale = Vector3(0.05, 1.0, 1.0)
		"front":
			camera.position = Vector3(0.0, 1.05 + 12.0 * tan(deg_to_rad(5.0)), -12.0)
			camera.rotation = Vector3(deg_to_rad(-5.0), deg_to_rad(180.0), 0.0)
			sun.rotation = Vector3(deg_to_rad(-40.0), deg_to_rad(200.0), 0.0)
			floor_mesh.scale = Vector3(1.0, 1.0, 0.05)
		"three":
			camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			camera.fov = 32.0
			camera.position = Vector3(7.5, 2.4, -7.5)
			camera.look_at(Vector3(0, 0.9, 0))


func _capture(path: String) -> void :
	for i in range(3): await RenderingServer.frame_post_draw
	if path.is_empty(): return
	var image: Image = viewport.get_texture().get_image()
	if image: image.save_png(path)
	print("CAPTURE ", path)


# Mesures sur un personnage qui avance vraiment : glissement des pieds au sol, flexion des genoux.
func _metrics(person: String, gait: String) -> void :
	var speed: float = float(GAITS[gait].speed)
	var state: Dictionary = _state(gait)
	_spawn(person, 1)
	var host: Node3D = hosts[0]
	var visual: PaperVisual = visuals[0]
	host.position = Vector3.ZERO
	visual.set_combat_state(state)
	var ankles: Dictionary = visual.get("_ankles")
	var toes: Dictionary = visual.get("_toes")
	var knees: Dictionary = {-1: visual.get("_left_knee"), 1: visual.get("_right_knee")}
	var legs: Dictionary = {-1: visual.get("_left_leg"), 1: visual.get("_right_leg")}
	var track: Dictionary = {-1: [], 1: []}
	var knee_min: float = 99.0
	var knee_max: float = -99.0
	var backward: int = 0
	var body_min: float = 99.0
	var body_max: float = -99.0
	var frames: int = int(2.4 / DT)
	for f in range(frames):
		host.position += Vector3(0, 0, - speed) * DT
		visual.animate(DT, Vector3(0, 0, - speed), false, false)
		if f < int(1.0 / DT): continue
		var body_y: float = (visual.get("_body") as Node3D).global_position.y
		body_min = minf(body_min, body_y)
		body_max = maxf(body_max, body_y)
		for side in [-1, 1]:
			var toe: Vector3 = (toes[side] as Node3D).global_position
			var ankle: Vector3 = (ankles[side] as Node3D).global_position
			(track[side] as Array).append([toe, ankle])
			if trace and side < 0 and f < int(1.0 / DT) + int(0.8 / DT):
				var target: Vector3 = visual.global_transform * (visual.get("_foot_target")[side] as Vector3)
				print("TRACE f=%d phase=%.3f duty=%.2f target=(%.3f, %.3f) ankle=(%.3f, %.3f) toe=(%.3f, %.3f) pitch=%.2f" % [f, float(visual.get("_gait_phase")), float(visual.get("_g_stance")), target.y, target.z, ankle.y, ankle.z, toe.y, toe.z, float(visual.get("_foot_pitch")[side])])
			var hip: Vector3 = (legs[side] as Node3D).global_position
			var knee: Vector3 = (knees[side] as Node3D).global_position
			var thigh: Vector3 = (knee - hip).normalized()
			var shin: Vector3 = (ankle - knee).normalized()
			var flex: float = rad_to_deg(acos(clampf(thigh.dot(shin), -1.0, 1.0)))
			knee_min = minf(knee_min, flex)
			knee_max = maxf(knee_max, flex)
			# Le genou doit plier vers l'avant (produit vectoriel cuisse × tibia orienté vers -X).
			if flex > 8.0 and thigh.cross(shin).dot(host.global_transform.basis.x) > 0.02: backward += 1
	# Un pied est « au sol » quand sa cheville ou ses orteils sont à moins d'1 cm de leur plus bas.
	var slide_sum: float = 0.0
	var slide_max: float = 0.0
	var contact: int = 0
	var flight: int = 0
	var count: int = (track[-1] as Array).size()
	var grounded: Array = []
	for side in [-1, 1]:
		var list: Array = track[side]
		var toe_min: float = 99.0
		var ankle_min: float = 99.0
		for entry: Array in list:
			toe_min = minf(toe_min, (entry[0] as Vector3).y)
			ankle_min = minf(ankle_min, (entry[1] as Vector3).y)
		var flags: Array = []
		for i in range(list.size()):
			var toe: Vector3 = list[i][0]
			var ankle: Vector3 = list[i][1]
			var on_toe: bool = toe.y - toe_min < 0.004
			var on_heel: bool = ankle.y - ankle_min < 0.004
			flags.append(on_toe or on_heel)
			if i == 0 or not (on_toe or on_heel): continue
			var point: Vector3 = ankle if on_heel else toe
			var before: Vector3 = list[i - 1][1] if on_heel else list[i - 1][0]
			var drift: Vector3 = point - before
			drift.y = 0.0
			var slide: float = drift.length() / DT
			slide_sum += slide
			slide_max = maxf(slide_max, slide)
			contact += 1
		grounded.append(flags)
	for i in range(count):
		if not grounded[0][i] and not grounded[1][i]: flight += 1
	var mean: float = slide_sum / maxf(float(contact), 1.0)
	var line: String = "METRIC %-8s %-7s v=%5.1f cad=%.2f duty=%.2f slide_mean=%.2f slide_max=%.2f contact=%d flight=%.0f%% knee=[%.0f..%.0f] backward=%d bob=%.3f" % [person, gait, speed, float(visual.get("_g_cadence")), float(visual.get("_g_stance")), mean, slide_max, contact, 100.0 * float(flight) / maxf(float(count), 1.0), knee_min, knee_max, backward, body_max - body_min]
	print(line)
	var log_path: String = out_dir + "/metrics.txt"
	var file: FileAccess = FileAccess.open(log_path, FileAccess.READ_WRITE if FileAccess.file_exists(log_path) else FileAccess.WRITE)
	if file:
		file.seek_end()
		file.store_line(line)
		file.close()


# Enchaînement : arrêt → marche → footing → sprint → saut → footing → arrêt (vue 3/4 qui suit).
func _sequence(person: String) -> void :
	_spawn(person, 1)
	var host: Node3D = hosts[0]
	var visual: PaperVisual = visuals[0]
	# [vitesse visée, durée, sprint] ; vitesse -1 = saut (vitesse du jeu en mode OM, accélération quasi instantanée).
	var plan: Array = [[0.0, 0.5, false], [1.5, 0.9, false], [6.3, 0.9, false], [10.2, 1.0, true], [-1.0, 1.1, true], [6.3, 0.8, false], [0.0, 1.0, false]]
	var cell: Vector2i = Vector2i(300, 330)
	viewport.size = cell
	var shot: int = 0
	var sheet: Image = null
	var page: int = 0
	var time: float = 0.0
	var next_shot: float = 0.0
	var speed: float = 0.0
	var vertical: float = 0.0
	var height: float = 0.0
	var state: Dictionary = _state("jog")
	for entry: Array in plan:
		var target: float = float(entry[0])
		var duration: float = float(entry[1])
		state["sprinting"] = bool(entry[2])
		if target < 0.0:
			vertical = 12.4
			height = 0.001
			target = speed
		var elapsed: float = 0.0
		while elapsed < duration:
			speed = move_toward(speed, target, DT * (2000.0 if height <= 0.0 else 90.0))
			if height > 0.0:
				vertical -= 24.0 * DT
				height += vertical * DT
				if height <= 0.0:
					height = 0.0
					vertical = 0.0
			state["grounded"] = height <= 0.0
			state["vertical_speed"] = vertical
			visual.set_combat_state(state)
			host.position += Vector3(0, 0, - speed) * DT
			host.position.y = height
			visual.animate(DT, Vector3(0, vertical, - speed), false, false)
			elapsed += DT
			time += DT
			if time + 0.0001 >= next_shot:
				next_shot += 0.1
				camera.projection = Camera3D.PROJECTION_PERSPECTIVE
				camera.fov = 34.0
				var focus: Vector3 = Vector3(host.position.x, 0.85 + height * 0.8, host.position.z)
				camera.position = focus + Vector3(4.2, 0.9, -1.6)
				camera.look_at(focus)
				sun.rotation = Vector3(deg_to_rad(-45.0), deg_to_rad(120.0), 0.0)
				await _capture("")
				var image: Image = viewport.get_texture().get_image()
				if sheet == null: sheet = Image.create(cell.x * 6, cell.y * 4, false, image.get_format())
				var slot: int = shot % 24
				sheet.blit_rect(image, Rect2i(Vector2i.ZERO, cell), Vector2i((slot % 6) * cell.x, (slot / 6) * cell.y))
				shot += 1
				if shot % 24 == 0:
					sheet.save_png("%s/seq_%s_%d.png" % [out_dir, person, page])
					print("CAPTURE seq ", person, " ", page)
					page += 1
					sheet = null
	if sheet != null:
		sheet.save_png("%s/seq_%s_%d.png" % [out_dir, person, page])
		print("CAPTURE seq ", person, " ", page)
	viewport.size = Vector2i(1600, 720)
