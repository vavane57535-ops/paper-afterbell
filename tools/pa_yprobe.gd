extends Node

# Repères de Yiero (lot prologue_a) aux instants demandés : yeux, bouche, menton, mains, pince
# (repère du film). Sert à caler les cadrages et les contacts.
#   godot --headless -- --tool pa_yprobe --pa-times "63.2,79.0,99.5"

func setup(owner: Node) -> void :
	var times: Array[float] = []
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(args.size() - 1):
		if args[i] == "--pa-times":
			for part: String in args[i + 1].split(","): times.append(float(part))
	owner.play_prologue()
	owner.set_process(false)
	var film: Node = owner.prologue
	var d: Vector3 = film.DIM
	for t: float in times:
		film.update(t, 0.0)
		var y: Node3D = film.yiero
		var line: String = "YPROBE t=%.2f" % t
		for socket: String in ["eyes", "mouth", "chin", "hand_l", "hand_r", "pinch_l"]:
			var p: Vector3 = y.socket(socket) - d
			line += " %s=(%.1f,%.1f,%.1f)" % [socket, p.x, p.y, p.z]
		print(line)
	owner.set_process(true)
	owner.end_prologue()
	get_tree().quit()
