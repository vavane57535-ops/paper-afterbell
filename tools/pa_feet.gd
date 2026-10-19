extends Node

# Pieds posés du prologue (lot prologue_a), mesurés sur le vrai squelette : le film est joué image par
# image (60 i/s, sans rendu) et, pour chaque appui écrit dans anim_set_film_prologue_a.gd, on relève la
# position des chevilles pendant qu'elles portent. Glissement = écart horizontal maximal autour de la
# position moyenne ; flottement = hauteur de la cheville au-dessus de sa hauteur de repos.
#   godot --headless -- --tool pa_feet [--pa-from 0] [--pa-to 104] [--pa-fps 60]

const PA = preload("res://anim_set_film_prologue_a.gd")

func setup(owner: Node) -> void :
	var from_t: float = 0.0
	var to_t: float = PA.HANDOFF
	var fps: float = 60.0
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(args.size() - 1):
		match args[i]:
			"--pa-from": from_t = float(args[i + 1])
			"--pa-to": to_t = float(args[i + 1])
			"--pa-fps": fps = float(args[i + 1])
	owner.play_prologue()
	owner.set_process(false)
	var film: Node = owner.prologue
	var samples: Dictionary = {}
	var t: float = from_t
	film.update(t, 0.0)
	while t <= to_t:
		film.update(t, 1.0 / fps)
		for index: int in [0, 1]:
			var visual: PaperVisual = film.takes[index].visual
			for side: int in [-1, 1]:
				var key: String = "%d_%d" % [index, side]
				if not samples.has(key): samples[key] = []
				(samples[key] as Array).append([t, (visual.get("_ankles")[side] as Node3D).global_position])
		t += 1.0 / fps
	var worst_all: float = 0.0
	for index: int in [0, 1]:
		var person: String = "Simon" if index == 0 else "Ashura"
		var actor: RefCounted = PA.actor(person)
		var rest_y: Dictionary = {-1: (actor.rest[-1] as Vector3).y * actor.scale, 1: (actor.rest[1] as Vector3).y * actor.scale}
		var report: Array = []
		for side: int in [-1, 1]:
			var rows: Array = actor.feet[side]
			var list: Array = samples["%d_%d" % [index, side]]
			for row: Array in rows:
				if str(row[2]) != "plant": continue
				var t0: float = maxf(float(row[0]) + 0.1, from_t)
				var t1: float = minf(float(row[1]) - 0.32, to_t)
				if t1 - t0 < 0.05: continue
				var points: Array = []
				var high: float = -INF
				for sample: Array in list:
					if float(sample[0]) < t0 or float(sample[0]) > t1: continue
					points.append(sample[1])
					high = maxf(high, (sample[1] as Vector3).y - float(rest_y[side]))
				if points.is_empty(): continue
				var mean: Vector3 = Vector3.ZERO
				for p: Vector3 in points: mean += p
				mean /= float(points.size())
				var slide: float = 0.0
				for p: Vector3 in points: slide = maxf(slide, Vector2(p.x - mean.x, p.z - mean.z).length())
				var target: Vector3 = film.DIM + (row[3].at as Vector3)
				var offset: float = Vector2(mean.x - target.x, mean.z - target.z).length()
				report.append([slide, float(row[0]), side, high, offset])
		report.sort_custom( func(x: Array, y: Array) -> bool: return float(x[0]) > float(y[0]))
		var floating: float = 0.0
		var off: float = 0.0
		for row: Array in report:
			floating = maxf(floating, float(row[3]))
			off = maxf(off, float(row[4]))
		print("PA_FEET ", person, " appuis=", report.size(), " glissement_max_cm=", "%.2f" % (100.0 * float(report[0][0]) if not report.is_empty() else 0.0), " flottement_max_cm=", "%.2f" % (100.0 * floating), " écart_cible_max_cm=", "%.2f" % (100.0 * off))
		for k: int in range(mini(6, report.size())):
			var row: Array = report[k]
			print("PA_FEET   ", person, " t=", "%.2f" % float(row[1]), " pied=", "G" if int(row[2]) < 0 else "D", " glisse_cm=", "%.2f" % (100.0 * float(row[0])), " haut_cm=", "%.2f" % (100.0 * float(row[3])), " écart_cm=", "%.2f" % (100.0 * float(row[4])))
		if not report.is_empty(): worst_all = maxf(worst_all, float(report[0][0]))
	print("PA_FEET RESULT ", "OK" if worst_all < 0.02 else "GLISSE", " (", "%.2f" % (100.0 * worst_all), " cm)")
	owner.set_process(true)
	owner.end_prologue()
	get_tree().quit()
