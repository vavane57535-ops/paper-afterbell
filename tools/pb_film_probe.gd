extends Node

# Sonde du prologue (partie B) : positions des acteurs, des prises de Yiero et de la caméra à des
# instants donnés du film, sans rendu.
#   godot --headless -- --tool pb_film_probe --pb-times "104,110,114.6" [--pb-sockets "hand_r,head"]
# Sert à poser la mise en scène sur des mesures (regards, contacts des mains, cadrages).

var world: Node
var times: Array[float] = [104.0]
var sockets: PackedStringArray = PackedStringArray(["hand_r", "hand_l", "head"])

func setup(owner: Node) -> void :
	world = owner
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(args.size() - 1):
		match args[i]:
			"--pb-times":
				times.clear()
				for part: String in args[i + 1].split(","): times.append(float(part))
			"--pb-sockets": sockets = args[i + 1].split(",")
	_run.call_deferred()

func _local(film: Node, at: Vector3) -> Vector3:
	var d: Vector3 = at - film.anchor
	return Vector3(d.dot(film.right), d.y, d.dot(film.forward))

func _run() -> void :
	await get_tree().process_frame
	world.play_prologue()
	world.set_process(false)
	var film: Node = world.prologue
	for t: float in times:
		film.seek(t)
		print("PB_T ", t, " plan=", film.last_shot, " cam=", _local(film, world.camera.global_position))
		for i: int in range(film.takes.size()):
			var take: Variant = film.takes[i]
			var visual: PaperVisual = take.visual
			if not take.shown: continue
			var row: String = "  %-8s pos=%s yaw=%.2f" % [take.person, str(_local(film, visual.global_position)), visual.rotation.y]
			for socket: String in sockets: row += " %s=%s" % [socket, str(_local(film, visual.socket_position(socket)))]
			print(row)
		if film._stage_at(t) == "void" and is_instance_valid(film.yiero):
			var y: Node3D = film.yiero
			var row: String = "  Yiero    pos=%s" % str(_local(film, y.global_position))
			for socket: String in ["pinch_l", "hand_l", "hand_r", "mouth", "face", "eyes"]: row += " %s=%s" % [socket, str(_local(film, y.socket(socket)))]
			print(row)
	world.set_process(true)
	get_tree().quit()
