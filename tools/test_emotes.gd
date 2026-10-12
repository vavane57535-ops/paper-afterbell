extends Node

# Vérification des émotes et danses 0.16.
#
# Rendu (planches de captures, un fichier par émote/danse) :
#   xvfb-run -a -s "-screen 0 1280x800x24" godot --rendering-driver opengl3 -- --tool test_emotes \
#     --emotes clap,dance_sixseven --people Simon,Lysia,Bleuette --times 0.5,1.0,1.5,2.0 --out /tmp/x
#   (--times en secondes ; --beats 0,1,2,3 pour des temps musicaux ; --view front|side|three)
# Synchronisation (headless, partie simulée) :
#   godot --headless -- --simulate Simon --duration 40 --tool test_emotes --sync --out /tmp/x

const CELL: Vector2i = Vector2i(960, 540)
const AnimLibrary = preload("res://anim_library.gd")
const AnimClip = preload("res://anim_clip.gd")

var world: Node
var args: Dictionary = {}
var viewport: SubViewport
var camera: Camera3D
var stage: Node3D
var visuals: Array[PaperVisual] = []
var report: Array[String] = []

func setup(owner_world: Node) -> void :
	world = owner_world
	var raw: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(raw.size()):
		if raw[i].begins_with("--"):
			var value: String = raw[i + 1] if i + 1 < raw.size() and not raw[i + 1].begins_with("--") else "1"
			args[raw[i].substr(2)] = value
	if args.has("sync"): _run_sync.call_deferred()
	else: _run_render.call_deferred()

func _out(file_name: String) -> String:
	var dir: String = str(args.get("out", "user://test_emotes"))
	DirAccess.make_dir_recursive_absolute(dir)
	return dir.path_join(file_name)

func _log(line: String) -> void :
	print("TEST_EMOTES ", line)
	report.append(line)



func _build_stage() -> void :
	viewport = SubViewport.new()
	viewport.size = CELL
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	add_child(viewport)
	stage = Node3D.new()
	viewport.add_child(stage)
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("d9d2c3")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("8d8aa0")
	e.ambient_light_energy = 0.55
	env.environment = e
	stage.add_child(env)
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.rotation = Vector3(-0.8, 0.5, 0.0)
	key.light_energy = 0.75
	key.shadow_enabled = true
	stage.add_child(key)
	var floor_mesh: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(30, 30)
	floor_mesh.mesh = plane
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color("6f6a62")
	floor_mesh.material_override = mat
	stage.add_child(floor_mesh)
	camera = Camera3D.new()
	camera.fov = 30.0
	stage.add_child(camera)
	camera.current = true

func _place_camera(count: int, view: String) -> void :
	var width: float = maxf(1.4, float(count - 1) * 1.35 + 1.2)
	var aspect: float = float(CELL.x) / float(CELL.y)
	var half: float = tan(deg_to_rad(camera.fov * 0.5))
	var distance: float = maxf((width + 0.5) / (2.0 * half * aspect), 2.15 / (2.0 * half)) * float(args.get("zoom", "1.0"))
	var yaw: float = 0.0
	match view:
		"side": yaw = deg_to_rad(80.0)
		"three": yaw = deg_to_rad(35.0)
		"back": yaw = deg_to_rad(180.0)
	var target: Vector3 = Vector3(0.0, float(args.get("look_y", "0.92")), 0.0)
	camera.position = target + Vector3(sin(yaw), 0.12, cos(yaw)).normalized() * distance
	camera.look_at(target, Vector3.UP)

func _spawn(people: Array) -> void :
	for v: PaperVisual in visuals: v.queue_free()
	visuals.clear()
	for i: int in range(people.size()):
		var visual: PaperVisual = PaperVisual.new()
		visual.lod_enabled = false
		stage.add_child(visual)
		visual.setup(str(people[i]))
		visual.position = Vector3((float(i) - float(people.size() - 1) * 0.5) * 1.35, 0.0, 0.0)
		visual.rotation.y = PI
		visuals.append(visual)

func _drive(id: String, t: float, dt: float) -> void :
	for v: PaperVisual in visuals:
		v.set_combat_state({"emote_id": id, "emote_time": t} if not id.is_empty() else {})
		v.animate(dt, Vector3.ZERO, false, false)

func _bpm(id: String) -> float:
	return float(PaperDances.info(id).get("bpm", 120.0))

func _run_render() -> void :
	if world.get("ui"): world.ui.visible = false
	get_tree().root.disable_3d = true
	_build_stage()
	var people: Array = str(args.get("people", "Simon,Lysia,Bleuette")).split(",", false)
	var ids: Array = str(args.get("emotes", "clap")).split(",", false)
	if ids.size() == 1 and ids[0] == "all_new":
		ids = ["clap", "facepalm", "sulk", "heart", "taunt", "salute", "selfie", "bow", "beg", "sit"]
	elif ids.size() == 1 and ids[0] == "all_dances":
		ids = PaperDances.LIST.map( func(entry: Dictionary) -> String: return str(entry.id))
	var view: String = str(args.get("view", "three"))
	_spawn(people)
	_place_camera(people.size(), view)
	for i: int in range(20):
		_drive("", 0.0, 1.0 / 30.0)
		await get_tree().process_frame
	for id: String in ids:
		var times: Array[float] = []
		if args.has("beats"):
			for b: String in str(args.beats).split(",", false): times.append(float(b) * 60.0 / _bpm(id))
		else:
			for s: String in str(args.get("times", "0.4,0.9,1.4,1.9")).split(",", false): times.append(float(s))
		var frames: Array[Image] = []
		var t: float = 0.0
		var dt: float = 1.0 / 30.0
		_drive("", 0.0, dt)
		for target: float in times:
			while t + dt < target:
				t += dt
				_drive(id, t, dt)
			_drive(id, target, maxf(target - t, 0.001))
			t = target
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var img: Image = viewport.get_texture().get_image()
			frames.append(img)
		var sheet: Image = _sheet(frames)
		var path: String = _out("%s_%s.png" % [id, view])
		sheet.save_png(path)
		_log("SHEET %s %s" % [id, path])
		for v: PaperVisual in visuals: v.set_combat_state({})
		for i: int in range(12):
			_drive("", 0.0, 1.0 / 30.0)
	get_tree().quit()

func _sheet(frames: Array[Image]) -> Image:
	var columns: int = 2 if frames.size() > 1 else 1
	var rows: int = ceili(frames.size() / float(columns))
	var sheet: Image = Image.create(CELL.x * columns, CELL.y * rows, false, Image.FORMAT_RGB8)
	sheet.fill(Color.BLACK)
	for i: int in range(frames.size()):
		var frame: Image = frames[i]
		frame.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(frame, Rect2i(Vector2i.ZERO, CELL), Vector2i((i % columns) * CELL.x, (i / columns) * CELL.y))
	return sheet



# Test de synchronisation dans une vraie partie simulée (logique hôte + visuels).
func _run_sync() -> void :
	while world.phase != "playing":
		await get_tree().physics_frame
	for i: int in range(30): await get_tree().physics_frame
	var survivors: Array[PaperActor] = []
	var killer: PaperActor = null
	for a: PaperActor in world.actors.values():
		if a.killer: killer = a
		elif a.active(): survivors.append(a)
	if survivors.size() < 3:
		_log("FAIL pas assez de survivants")
		_finish(false)
		return
	# Tout le monde immobile, la tueuse loin : les survivants testés ne bougent plus.
	for a: PaperActor in world.actors.values(): a.bot = false;a.move_input = Vector3.ZERO;a.sprint = false;a.visual.lod_enabled = false
	var origin: Vector3 = survivors[0].position
	if killer: killer.position = origin + Vector3(80.0, 0.0, 0.0);killer.net_position = killer.position
	for i: int in range(survivors.size()):
		survivors[i].position = origin + Vector3(float(i) * 1.6, 0.0, 0.0)
		survivors[i].net_position = survivors[i].position
	var ok: bool = true
	ok = await _case("emote rejointe à 0,7 s (wave)", survivors[0], survivors[1], "wave", 0.7, "join") and ok
	ok = await _case("émote rejointe tard à 1,6 s (clap) -> tout le groupe repart", survivors[0], survivors[1], "clap", 1.6, "restart") and ok
	ok = await _case("danse rejointe à 0,7 s (dance_floss)", survivors[0], survivors[1], "dance_floss", 0.7, "join") and ok
	ok = await _case("danse rejointe à 0,7 s (nouvelle danse)", survivors[1], survivors[2], str(PaperDances.LIST[PaperDances.LIST.size() - 1].id), 0.7, "join") and ok
	ok = await _case_far("même émote hors de portée : pas de synchro", survivors[0], survivors[2], "heart") and ok
	ok = await _case_music("la musique continue sans coupure quand un danseur rejoint puis quitte le groupe", survivors[0], survivors[1], survivors[2]) and ok
	ok = await _case_long("danse rejointe tard : le nouveau venu garde toute sa durée", survivors[0], survivors[1]) and ok
	ok = await _case_sit("en tailleur rejoint tard : le nouveau venu s'assoit à son rythme, le groupe reste assis", survivors[0], survivors[1]) and ok
	ok = await _bot_join(survivors[0], survivors[1]) and ok
	_finish(ok)

func _wait_clock(seconds: float) -> void :
	var goal: float = world.clock + seconds
	while world.clock < goal: await get_tree().physics_frame

func _reset(list: Array[PaperActor]) -> void :
	for a: PaperActor in list: world.emote_sync.cancel(a);a.effects.erase("last_emote")
	await _wait_clock(0.5)

func _clip_time(a: PaperActor) -> float:
	return float(a.visual.get("_emote_clip_time"))

func _case(label: String, a: PaperActor, b: PaperActor, id: String, offset: float, expect: String) -> bool:
	await _reset([a, b])
	world._start_emote(a, id)
	await _wait_clock(offset)
	var a_before: float = float(a.effects.get("emote_time", -1.0))
	world._start_emote(b, id)
	var phases: Array[String] = []
	var worst: float = 0.0
	var worst_visual: float = 0.0
	for k: int in range(6):
		await _wait_clock(0.15)
		var ta: float = float(a.effects.get("emote_time", -1.0))
		var tb: float = float(b.effects.get("emote_time", -1.0))
		var clip: Dictionary = AnimLibrary.clip(id, a.character)
		var pa: float = -1.0 if clip.is_empty() else AnimClip.wrap_time(clip, ta) / maxf(float(clip.len), 0.001)
		var pb: float = -1.0 if clip.is_empty() else AnimClip.wrap_time(clip, tb) / maxf(float(clip.len), 0.001)
		worst = maxf(worst, absf(ta - tb))
		worst_visual = maxf(worst_visual, absf(_clip_time(a) - _clip_time(b)))
		phases.append("t=%.3f/%.3f phase=%.3f/%.3f" % [ta, tb, pa, pb])
	var a_after: float = float(a.effects.get("emote_time", -1.0))
	var same_epoch: bool = absf(float(a.effects.get("emote_epoch", 0.0)) - float(b.effects.get("emote_epoch", 1.0))) < 0.0001
	var restarted: bool = a_after < a_before
	var pass_case: bool = same_epoch and worst < 0.001 and worst_visual < 0.05 and (restarted if expect == "restart" else not restarted)
	_log("%s %s : écart max emote_time=%.4f s, écart max temps de clip visuel=%.4f s, temps de A avant=%.3f, A redémarré=%s" % ["OK" if pass_case else "FAIL", label, worst, worst_visual, a_before, str(restarted)])
	for line: String in phases: _log("    " + line)
	return pass_case

func _case_far(label: String, a: PaperActor, b: PaperActor, id: String) -> bool:
	await _reset([a, b])
	var keep: Vector3 = b.position
	b.position = a.position + Vector3(PaperEmotes.SYNC_RANGE + 6.0, 0.0, 0.0)
	world._start_emote(a, id)
	await _wait_clock(0.7)
	world._start_emote(b, id)
	await _wait_clock(0.3)
	var gap: float = absf(float(a.effects.get("emote_time", 0.0)) - float(b.effects.get("emote_time", 0.0)))
	var pass_case: bool = gap > 0.5
	_log("%s %s : écart=%.3f s (attendu ~0,7)" % ["OK" if pass_case else "FAIL", label, gap])
	b.position = keep
	await _reset([a, b])
	return pass_case

func _music_players() -> Array:
	var result: Array = []
	for entry: Dictionary in world.emote_sync._music: result.append((entry.player as Node).get_instance_id())
	return result

func _case_music(label: String, a: PaperActor, b: PaperActor, c: PaperActor) -> bool:
	await _reset([a, b, c])
	var keep: Vector3 = c.position
	c.position = a.position + Vector3(0.0, 0.0, 1.6)
	world._start_emote(b, "dance_golden")
	await _wait_clock(0.6)
	var first: Array = _music_players()
	world._start_emote(a, "dance_golden")
	await _wait_clock(0.4)
	world._start_emote(c, "dance_golden")
	await _wait_clock(0.4)
	var joined: Array = _music_players()
	world.emote_sync.cancel(b)
	await _wait_clock(0.4)
	var left: Array = _music_players()
	var pass_case: bool = first.size() == 1 and joined == first and left == first
	_log("%s %s : lecteurs %s -> %s -> %s" % ["OK" if pass_case else "FAIL", label, str(first), str(joined), str(left)])
	c.position = keep
	await _reset([a, b, c])
	return pass_case

func _case_long(label: String, a: PaperActor, b: PaperActor) -> bool:
	await _reset([a, b])
	world._start_emote(a, "dance_floss")
	# A danse depuis presque PaperDances.MAX_SECONDS.
	var shift: float = PaperDances.MAX_SECONDS - 1.0
	a.effects["emote_epoch"] = float(a.effects.emote_epoch) - shift
	a.effects["last_emote"] = float(a.effects.last_emote) - shift
	await _wait_clock(0.2)
	world._start_emote(b, "dance_floss")
	var same_epoch: bool = absf(float(a.effects.get("emote_epoch", 0.0)) - float(b.effects.get("emote_epoch", 1.0))) < 0.0001
	await _wait_clock(1.6)
	var a_done: bool = not a.effects.has("emote_id")
	var b_dancing: bool = str(b.effects.get("emote_id", "")) == "dance_floss"
	var pass_case: bool = same_epoch and a_done and b_dancing
	_log("%s %s : même époque=%s, A arrêté à sa limite=%s, B danse encore=%s" % ["OK" if pass_case else "FAIL", label, str(same_epoch), str(a_done), str(b_dancing)])
	await _reset([a, b])
	return pass_case

func _case_sit(label: String, a: PaperActor, b: PaperActor) -> bool:
	await _reset([a, b])
	world._start_emote(a, "sit")
	await _wait_clock(3.0)
	var a_before: float = float(a.effects.get("emote_time", 0.0))
	world._start_emote(b, "sit")
	await _wait_clock(0.2)
	var a_after: float = float(a.effects.get("emote_time", 0.0))
	var tb: float = float(b.effects.get("emote_time", -1.0))
	var pass_case: bool = a_after > a_before and tb < 0.5
	_log("%s %s : A %.2f -> %.2f (pas de redémarrage), B commence à %.2f s" % ["OK" if pass_case else "FAIL", label, a_before, a_after, tb])
	await _reset([a, b])
	return pass_case

func _bot_join(human: PaperActor, bot: PaperActor) -> bool:
	await _reset([human, bot])
	bot.bot = true
	world.emote_sync.rng.seed = 7
	var joined: bool = false
	for attempt: int in range(6):
		world._start_emote(human, "cheer")
		await _wait_clock(1.6)
		if str(bot.effects.get("emote_id", "")) == "cheer":
			joined = absf(float(bot.effects.get("emote_epoch", 0.0)) - float(human.effects.get("emote_epoch", 1.0))) < 0.0001
			break
		await _reset([human, bot])
	bot.bot = false
	_log("%s un bot proche rejoint l'émote du joueur, synchronisé" % ("OK" if joined else "FAIL"))
	return joined

func _finish(ok: bool) -> void :
	_log("RESULT " + ("PASS" if ok else "FAIL"))
	var file: FileAccess = FileAccess.open(_out("sync_report.txt"), FileAccess.WRITE)
	if file: file.store_string("\n".join(report) + "\n")
	get_tree().quit()
