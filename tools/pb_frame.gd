extends Node

# Contrôle des cadrages du prologue (partie B), sans rendu : à chaque instant demandé, où tombent la tête,
# le bassin et les pieds de chaque personnage visible dans l'image (coordonnées 0..1, « hors » sinon),
# la hauteur du personnage à l'écran et la distance de la caméra à la tête la plus proche.
#   godot --headless --resolution 1280x720 -- --tool pb_frame --pb-ranges "104-122:0.5,153-182:0.5"
# Sert à repérer les plans ratés (sujet hors champ, caméra dans une tête) avant de rendre des planches.

const DT: float = 1.0 / 30.0

var world: Node
var ranges: Array = []

func setup(owner: Node) -> void :
	world = owner
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(args.size() - 1):
		if args[i] == "--pb-ranges":
			for part: String in args[i + 1].split(","):
				var span: PackedStringArray = part.split(":")
				var bounds: PackedStringArray = span[0].split("-")
				if bounds.size() == 2: ranges.append([float(bounds[0]), float(bounds[1]), float(span[1]) if span.size() > 1 else 0.5])
	_run.call_deferred()

func _screen(camera: Camera3D, size: Vector2, at: Vector3) -> String:
	if camera.is_position_behind(at): return "derrière"
	var p: Vector2 = camera.unproject_position(at) / size
	# Image finale en 16:10 (1280 × 800) : la fenêtre de test n'a pas forcément ce format (fov vertical).
	p.x = 0.5 + (p.x - 0.5) * (size.x / size.y) / 1.6
	if p.x < 0.0 or p.x > 1.0 or p.y < 0.0 or p.y > 1.0: return "hors(%.2f,%.2f)" % [p.x, p.y]
	return "(%.2f,%.2f)" % [p.x, p.y]

func _run() -> void :
	for i: int in range(3): await get_tree().process_frame
	world.play_prologue()
	world.set_process(false)
	var film: Node = world.prologue
	var camera: Camera3D = world.camera
	var size: Vector2 = camera.get_viewport().get_visible_rect().size
	print("PB_F taille ", size)
	for span: Array in ranges:
		var t: float = float(span[0])
		film.seek(maxf(0.0, t - 1.0))
		var clock: float = maxf(0.0, t - 1.0)
		while t <= float(span[1]) + 0.0001:
			while clock < t - 0.0001:
				var next: float = minf(t, clock + DT)
				film.update(next, next - clock)
				clock = next
			var row: String = "PB_F %.2f plan=%d fov=%.0f" % [t, film.last_shot, camera.fov]
			var nearest: float = 999.0
			for take: Variant in film.takes:
				var visual: PaperVisual = take.visual
				if not take.shown or not visual.visible: continue
				var head: Vector3 = visual.socket_position("head")
				var foot: Vector3 = visual.global_position
				nearest = minf(nearest, camera.global_position.distance_to(head))
				if camera.is_position_behind(head) and camera.is_position_behind(foot): continue
				var h: float = 0.0
				if not camera.is_position_behind(head) and not camera.is_position_behind(foot):
					h = absf(camera.unproject_position(head).y - camera.unproject_position(foot).y) / size.y
				row += " | %s tête%s pieds%s h=%.2f" % [take.person.substr(0, 3), _screen(camera, size, head), _screen(camera, size, foot), h]
			if film._stage_at(t) == "void" and is_instance_valid(film.yiero) and film.yiero.visible:
				row += " | Yie yeux%s gueule%s pince%s" % [_screen(camera, size, film.yiero.socket("eyes")), _screen(camera, size, film.yiero.socket("mouth")), _screen(camera, size, film.yiero.socket("pinch_l"))]
			row += " | proche=%.2f" % nearest
			print(row)
			t += float(span[2])
	world.set_process(true)
	get_tree().quit()
