extends Node

# Captures du prologue (lot prologue_a) à des instants choisis : entre deux captures, le film avance par
# pas de 1/30 s sans rendu, puis une image est rendue. Bien plus rapide que la lecture en temps réel
# pour une vue d'ensemble ou une planche serrée sur un plan.
#   xvfb-run -a -s "-screen 0 1280x800x24" godot --rendering-driver opengl3 -- --tool pa_shots \
#     --pa-out DIR --pa-times "12-17:0.2,30.4,33.1"   (début-fin:pas, ou instants isolés)

var world: Node
var out_dir: String = "user://pa_shots"
var times: Array[float] = []

func setup(owner: Node) -> void :
	world = owner
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(args.size() - 1):
		match args[i]:
			"--pa-out": out_dir = args[i + 1]
			"--pa-times":
				for part: String in args[i + 1].split(","):
					if part.contains("-"):
						var span: PackedStringArray = part.split(":")
						var bounds: PackedStringArray = span[0].split("-")
						var step: float = float(span[1]) if span.size() > 1 else 0.5
						var t: float = float(bounds[0])
						while t <= float(bounds[1]) + 0.0001:
							times.append(snappedf(t, 0.001))
							t += step
					elif not part.is_empty():
						times.append(float(part))
	times.sort()
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()

func _run() -> void :
	for i: int in range(4): await get_tree().process_frame
	world.play_prologue()
	world.set_process(false)
	var film: Node = world.prologue
	var clock: float = 0.0
	film.update(0.0, 0.0)
	for t: float in times:
		# Avance par petits pas (comme la lecture), puis deux images à 1/30 s pour poser les ressorts.
		while clock < t - 1.0 / 30.0:
			clock = minf(t - 1.0 / 30.0, clock + 1.0 / 30.0)
			film.update(clock, 1.0 / 30.0)
		clock = t
		film.update(clock, 1.0 / 30.0)
		world.ui.update_film("", "", film.black)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path: String = out_dir.path_join("pa_%06.2f.png" % t)
		world.get_viewport().get_texture().get_image().save_png(path)
	print("PA_SHOTS ", times.size(), " images dans ", out_dir)
	world.set_process(true)
	world.end_prologue()
	get_tree().quit()
