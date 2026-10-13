extends Node
# Échantillonne les canaux d'un clip des victoires LMS sans rendu.
#   godot --headless -- --tool film_victory_probe --probe fv_simon_rain --probe-times 5.0,5.1 --probe-channels body,ik_l
# Les instants sont en temps du clip ; --probe-film ajoute le "at" du clip (temps du film).

func setup(_world: Node) -> void :
	_run.call_deferred()


func _run() -> void :
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var clip_name: String = "fv_simon_rain"
	var times: Array[float] = []
	var channels: PackedStringArray = PackedStringArray(["body", "chest", "head", "ik_l", "ik_r", "hips", "foot_l", "foot_r"])
	var film_time: bool = false
	for i: int in range(args.size()):
		var value: String = args[i + 1] if i + 1 < args.size() else ""
		match args[i]:
			"--probe": clip_name = value
			"--probe-times":
				for item: String in value.split(",", false): times.append(float(item))
			"--probe-channels": channels = value.split(",", false)
			"--probe-film": film_time = true
	var library: GDScript = load("res://anim_library.gd")
	var clip: Dictionary = library.clip(clip_name, "")
	var source: Dictionary = library.source(clip_name)
	var at: float = float(source.get("at", 0.0))
	print("PROBE ", clip_name, " len=", clip.get("len"), " at=", at, " keys=", (source.get("keys", []) as Array).size(), " channels=", (clip.get("channels", {}) as Dictionary).keys())
	var AnimClip: GDScript = load("res://anim_clip.gd")
	for t: float in times:
		var local: float = t - at if film_time else t
		var line: PackedStringArray = []
		for channel: String in channels:
			if clip.channels.has(channel):
				line.append("%s=%s" % [channel, str(AnimClip.sample(clip.channels[channel], local, false, float(clip.len)))])
			elif clip.strings.has(channel):
				line.append("%s=%s" % [channel, AnimClip.sample_string(clip.strings[channel], local)])
			else:
				line.append("%s=-" % channel)
		print("PROBE t=%.3f %s" % [t, " ".join(line)])
	get_tree().quit()
