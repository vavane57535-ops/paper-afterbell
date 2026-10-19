extends Node

# Trajets écrits des acteurs du prologue (lot prologue_a) : position de la racine (repère du film) et
# orientation voulue aux instants demandés, sans jouer le film.
#   godot --headless -- --tool pa_roots --pa-times "61,62.9,63.2"

const PA = preload("res://anim_set_film_prologue_a.gd")

func setup(_owner: Node) -> void :
	var times: Array[float] = []
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(args.size() - 1):
		if args[i] == "--pa-times":
			for part: String in args[i + 1].split(","): times.append(float(part))
	PA.build()
	for t: float in times:
		var line: String = "ROOT t=%.2f" % t
		for person: String in ["Simon", "Ashura"]:
			var a: RefCounted = PA.actor(person)
			var p: Vector3 = PA.root_at(a, t)
			line += "  %s=(%.2f, %.2f, %.2f) yaw=%.2f" % [person.substr(0, 1), p.x, p.y, p.z, PA.yaw_at(a, t)]
		print(line)
	get_tree().quit()
