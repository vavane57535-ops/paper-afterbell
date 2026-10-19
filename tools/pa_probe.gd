extends Node

# Sonde du lot prologue_a : joue le film sans rendu (pas de 1/30 s) et, aux instants demandés, affiche
# pour Simon et Ashura la position (repère du film), l'orientation, la hauteur des yeux et des
# chevilles, plus la caméra. Sert à caler les cadrages et les contacts.
#   godot --headless -- --tool pa_probe --pa-times "26.6,27.5,30.5"

var times: Array[float] = []

func setup(owner: Node) -> void :
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(args.size() - 1):
		if args[i] == "--pa-times":
			for part: String in args[i + 1].split(","): times.append(float(part))
	times.sort()
	owner.play_prologue()
	owner.set_process(false)
	var film: Node = owner.prologue
	var d: Vector3 = film.DIM
	var clock: float = 0.0
	film.update(0.0, 0.0)
	for t: float in times:
		while clock < t - 1.0 / 30.0:
			clock = minf(t - 1.0 / 30.0, clock + 1.0 / 30.0)
			film.update(clock, 1.0 / 30.0)
		clock = t
		film.update(clock, 1.0 / 30.0)
		var cam: Camera3D = owner.camera
		print("PROBE t=%.2f cam=%s look=%s fov=%.1f" % [t, cam.global_position - d, film.camera_focus - d, cam.fov])
		for index: int in [0, 1]:
			var visual: PaperVisual = film.takes[index].visual
			var ankles: Dictionary = visual.get("_ankles")
			print("  %s pos=%s yaw=%.2f eyes=%s head=%s ank_l=%s ank_r=%s hand_r=%s" % [visual.person if "person" in visual else str(index), visual.global_position - d, visual.rotation.y, visual.socket_position("eyes") - d, visual.socket_position("head") - d, (ankles[-1] as Node3D).global_position - d, (ankles[1] as Node3D).global_position - d, visual.socket_position("hand_r") - d])
			var body: Node3D = visual.get("_body")
			print("    body_local=%s base_h=%.3f leg_reach=%.3f scale=%s model_scale=%s knee_l=%s" % [body.position, float(visual.get("_base_height")), float(visual.get("_leg_reach")), visual.scale, (body.get_parent() as Node3D).global_transform.basis.get_scale(), (visual.get("_left_knee") as Node3D).global_position - d])
	owner.set_process(true)
	owner.end_prologue()
	get_tree().quit()
