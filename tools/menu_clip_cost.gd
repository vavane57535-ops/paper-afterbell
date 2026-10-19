extends Node

# Coût de génération et de compilation des clips de l'écran titre (headless) :
#   godot --headless -- --tool menu_clip_cost

const AnimClip = preload("res://anim_clip.gd")

var world: Node

func setup(game_world: Node) -> void :
	world = game_world
	_run.call_deferred()

func _run() -> void :
	for i: int in range(4): await get_tree().process_frame
	var t0: int = Time.get_ticks_usec()
	var c: Dictionary = {}
	(load("res://anim_set_menu.gd") as GDScript).call("add", c)
	var t1: int = Time.get_ticks_usec()
	var keys: int = 0
	var compile_us: int = 0
	for clip_name: String in c:
		keys += (c[clip_name].get("keys", []) as Array).size()
		var a: int = Time.get_ticks_usec()
		AnimClip.compile(c[clip_name])
		compile_us += Time.get_ticks_usec() - a
	print("MENU_CLIPS %d clips, %d clés, génération %.1f ms, compilation %.1f ms" % [c.size(), keys, (t1 - t0) / 1000.0, compile_us / 1000.0])
	for clip_name: String in c:
		print("MENU_CLIP %s : %.1f s, %d clés" % [clip_name, float(c[clip_name].get("len", 0.0)), (c[clip_name].get("keys", []) as Array).size()])
	# Toutes les bibliothèques du jeu, pour comparaison.
	var library: GDScript = load("res://anim_library.gd")
	for set_name: String in library.get("SETS"):
		var path: String = "res://anim_set_%s.gd" % set_name
		if not ResourceLoader.exists(path): continue
		var a: int = Time.get_ticks_usec()
		var d: Dictionary = {}
		(load(path) as GDScript).call("add", d)
		print("SET %s : %d clips, %.1f ms" % [set_name, d.size(), (Time.get_ticks_usec() - a) / 1000.0])
	get_tree().quit()
