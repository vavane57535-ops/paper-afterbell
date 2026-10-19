extends Node

# Planches serrées du prologue (partie B) sans rendre chaque image : le film avance au 1/30 s (comme en
# lecture réelle, effets BD compris) et seules les images demandées sont rendues.
#   xvfb-run -a -s "-screen 0 1280x800x24" godot --rendering-driver opengl3 --resolution 640x400 -- \
#       --tool pb_sheet --pb-ranges "104-110:0.25,113.5-118:0.2" [--pb-out DIR]
# Une image par instant : DIR/f_<instant>.png (à assembler ensuite avec ffmpeg tile).

const DT: float = 1.0 / 30.0

var world: Node
var ranges: Array = []
var out_dir: String = "/tmp/pb_sheet"

func setup(owner: Node) -> void :
	world = owner
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(args.size() - 1):
		match args[i]:
			"--pb-out": out_dir = args[i + 1]
			"--pb-ranges":
				for part: String in args[i + 1].split(","):
					var span: PackedStringArray = part.split(":")
					var bounds: PackedStringArray = span[0].split("-")
					if bounds.size() != 2: continue
					ranges.append([float(bounds[0]), float(bounds[1]), float(span[1]) if span.size() > 1 else 0.25])
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()

func _run() -> void :
	for i: int in range(4): await get_tree().process_frame
	world.play_prologue()
	world.set_process(false)
	var film: Node = world.prologue
	for span: Array in ranges:
		var a: float = float(span[0])
		var b: float = float(span[1])
		var step: float = float(span[2])
		film.seek(maxf(0.0, a - 1.0))
		var t: float = maxf(0.0, a - 1.0)
		var shot: float = a
		while shot <= b + 0.0001:
			while t < shot - 0.0001:
				var next: float = minf(shot, t + DT)
				film.update(next, next - t)
				world.presentation.update_visuals(next - t)
				t = next
			film.clock = t
			world.ui.update_film("", "", film.black)
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var path: String = out_dir.path_join("f_%06.2f.png" % shot)
			get_viewport().get_texture().get_image().save_png(path)
			shot += step
	print("PB_SHEET OK")
	world.set_process(true)
	get_tree().quit()
