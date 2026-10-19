extends Node

# Banc du lot prologue_a : construit les acteurs du prologue (anim_set_film_prologue_a.gd), mesure le
# temps, vérifie les clips (valeurs finies, longueurs, raccords entre clips) et les glissements des
# pieds posés (écart, dans le film, entre deux instants d'un même appui).
#   godot --headless -- --tool pa_bench

const PA = preload("res://anim_set_film_prologue_a.gd")
const AnimClip = preload("res://anim_clip.gd")

func setup(_owner: Node) -> void :
	var started: int = Time.get_ticks_usec()
	PA.build()
	print("PA_BENCH build_ms=", (Time.get_ticks_usec() - started) / 1000.0)
	var bad: int = 0
	for person: String in ["Simon", "Ashura"]:
		var actor: RefCounted = PA.actor(person)
		var keys: int = 0
		for row: Array in actor.clips:
			var source: Dictionary = row[2]
			keys += (source.keys as Array).size()
			for key: Array in source.keys:
				for channel: String in key[1]:
					var value: Variant = key[1][channel]
					if (value is float and not is_finite(value)) or (value is Vector3 and not (value as Vector3).is_finite()):
						bad += 1
						if bad < 8: print("PA_BENCH NaN ", row[0], " ", channel, " t=", key[0])
		var compile_started: int = Time.get_ticks_usec()
		for row: Array in actor.clips: AnimClip.compile(row[2])
		print("PA_BENCH ", person, " clips=", actor.clips.size(), " keys=", keys, " root=", actor.root.size(), " falls=", actor.falls.size(), " compile_ms=", (Time.get_ticks_usec() - compile_started) / 1000.0)
		# Glissement des pieds : pendant un appui, la cheville reste au même endroit du film.
		var worst: float = 0.0
		var worst_t: float = 0.0
		for side: int in [-1, 1]:
			for row: Array in actor.feet[side]:
				if str(row[2]) != "plant": continue
				var t0: float = float(row[0]) + 0.02
				var t1: float = minf(float(row[1]) - 0.02, PA.HANDOFF)
				var t: float = t0
				while t < t1:
					var state: Array = PA.foot_at(actor, side, t)
					var world: Vector3 = PA.world_of(actor, t, state[0])
					var d: float = Vector2(world.x - (row[3].at as Vector3).x, world.z - (row[3].at as Vector3).z).length()
					if d > worst:
						worst = d
						worst_t = t
					t += 0.1
		print("PA_BENCH ", person, " glissement_max=", worst, " à t=", worst_t)
	print("PA_BENCH valeurs_non_finies=", bad)
	get_tree().quit()
