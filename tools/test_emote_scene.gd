extends Node

# Captures EN JEU (vraie carte, éclairage, effets BD, HUD) d'un groupe de survivants qui font la
# même émote ou la même danse : le premier commence, les deux autres le rejoignent --offset s
# plus tard. Chaque planche montre plusieurs instants ; les temps d'émote de chacun sont écrits
# dans le journal (ils doivent être identiques après la jonction).
#   xvfb-run -a -s "-screen 0 1280x800x24" godot --rendering-driver opengl3 -- --simulate Simon \
#     --duration 90 --tool test_emote_scene --ids heart,dance_pikki --offset 0.7 --times 1.0,1.6,2.2,2.8 --out /tmp/x
#   (--beats 1,5,9,13 à la place de --times pour les danses ; --people Lysia,Bleuette ; --dist 4.6)

var world: Node
var args: Dictionary = {}
var group: Array[PaperActor] = []
var framing: bool = false
var cam_tf: Transform3D

func setup(owner_world: Node) -> void :
	world = owner_world
	var raw: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(raw.size()):
		if raw[i].begins_with("--"):
			args[raw[i].substr(2)] = raw[i + 1] if i + 1 < raw.size() and not raw[i + 1].begins_with("--") else "1"
	_run.call_deferred()

func _out(file_name: String) -> String:
	var dir: String = str(args.get("out", "user://test_emote_scene"))
	DirAccess.make_dir_recursive_absolute(dir)
	return dir.path_join(file_name)

func _wait_clock(seconds: float) -> void :
	var goal: float = world.clock + seconds
	while world.clock < goal: await get_tree().physics_frame

func _process(_delta: float) -> void :
	if not framing: return
	world.camera.global_transform = cam_tf
	for a: PaperActor in group: a.visual.visible = true

func _run() -> void :
	while world.phase != "playing": await get_tree().physics_frame
	for i: int in range(30): await get_tree().physics_frame
	for a: PaperActor in world.actors.values(): a.bot = false;a.move_input = Vector3.ZERO;a.sprint = false;a.visual.lod_enabled = false
	var local: PaperActor = world.local_actor()
	var wanted: Array = str(args.get("people", "")).split(",", false)
	group = [local]
	for a: PaperActor in world.actors.values():
		if group.size() >= 3: break
		if a == local or a.killer or not a.active(): continue
		if not wanted.is_empty() and not wanted.has(a.character): continue
		group.append(a)
	# Les autres (tueuse comprise) s'écartent du champ de la caméra.
	var away: int = 0
	for a: PaperActor in world.actors.values():
		if group.has(a): continue
		away += 1
		a.position = local.position + Vector3(0.0, 0.0, -30.0 - 6.0 * float(away)) if not a.killer else local.position + Vector3(90.0, 0.0, 0.0)
		a.net_position = a.position
	var base: Vector3 = local.position
	var slots: Array[float] = [0.0, -1.45, 1.45]
	for i: int in range(group.size()):
		group[i].position = base + Vector3(slots[i], 0.0, 0.0)
		group[i].net_position = group[i].position
		group[i].aim = Vector3(0.0, 0.0, 1.0)
	var dist: float = float(args.get("dist", "5.2"))
	var height: float = float(args.get("height", "1.55"))
	cam_tf = Transform3D(Basis.IDENTITY, base + Vector3(0.0, height, dist)).looking_at(base + Vector3(0.0, 0.95, 0.0), Vector3.UP)
	framing = true
	world.camera.fov = float(args.get("fov", "52"))
	await _wait_clock(1.0)
	var ids: Array = str(args.get("ids", "clap")).split(",", false)
	var offset: float = float(args.get("offset", "0.7"))
	for id: String in ids:
		for a: PaperActor in group: world.emote_sync.cancel(a);a.effects.erase("last_emote")
		await _wait_clock(0.8)
		var times: Array[float] = []
		if args.has("beats"):
			var bpm: float = float(PaperDances.info(id).get("bpm", 120.0))
			for b: String in str(args.beats).split(",", false): times.append(float(b) * 60.0 / bpm)
		else:
			for s: String in str(args.get("times", "1.0,1.6,2.2,2.8")).split(",", false): times.append(float(s))
		var start: float = world.clock
		world._start_emote(group[0], id)
		await _wait_clock(offset)
		for i: int in range(1, group.size()): world._start_emote(group[i], id)
		var frames: Array[Image] = []
		for t: float in times:
			while world.clock < start + t: await get_tree().physics_frame
			await RenderingServer.frame_post_draw
			var img: Image = get_viewport().get_texture().get_image()
			img.convert(Image.FORMAT_RGB8)
			frames.append(img)
			var line: String = "%s t=%.2f :" % [id, t]
			for a: PaperActor in group: line += " %s=%.3f/%.3f" % [a.character, float(a.effects.get("emote_time", -1.0)), float(a.visual.get("_emote_clip_time"))]
			print("TEST_EMOTE_SCENE ", line)
		var sheet: Image = _sheet(frames)
		var path: String = _out("%s_scene.png" % id)
		sheet.save_png(path)
		print("TEST_EMOTE_SCENE SHEET ", path)
	framing = false
	get_tree().quit()

# Planche : le centre de chaque image à pleine résolution (--crop 0.5 = la moitié centrale),
# ou l'image entière réduite (--crop 1).
func _sheet(frames: Array[Image]) -> Image:
	var full: Vector2i = Vector2i(frames[0].get_width(), frames[0].get_height())
	var crop: float = clampf(float(args.get("crop", "0.5")), 0.2, 1.0)
	var cell: Vector2i = Vector2i(full.x / 2, full.y / 2)
	var area: Rect2i = Rect2i(Vector2i((Vector2(full) * (1.0 - crop) * Vector2(0.5, 0.42))), Vector2i(Vector2(full) * crop))
	var columns: int = 2 if frames.size() > 1 else 1
	var rows: int = ceili(frames.size() / float(columns))
	var sheet: Image = Image.create(cell.x * columns, cell.y * rows, false, Image.FORMAT_RGB8)
	for i: int in range(frames.size()):
		var small: Image = frames[i].get_region(area)
		small.resize(cell.x, cell.y, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(small, Rect2i(Vector2i.ZERO, cell), Vector2i((i % columns) * cell.x, (i / columns) * cell.y))
	return sheet
