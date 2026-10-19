extends Node

# Vérification rapide des scènes de survol de l'écran titre (headless, sans rendu) :
# construit chaque scène étape par étape (durée de chaque étape : une étape = une image),
# puis joue tous ses temps forts en accéléré et mesure le coût moyen d'une image d'animation.
#   godot --headless -- --tool menu_scene_check [--scenes play,quit] [--loops 2]

const MenuVignettes = preload("res://ui_menu_vignettes.gd")

var world: Node
var scenes: PackedStringArray = PackedStringArray(["play", "training", "friends", "gallery", "settings", "credits", "quit", "shop"])
var loops: int = 1

func setup(game_world: Node) -> void :
	world = game_world
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(args.size()):
		var value: String = args[i + 1] if i + 1 < args.size() else ""
		match args[i]:
			"--scenes": scenes = value.split(",")
			"--loops": loops = maxi(1, int(value))
	_run.call_deferred()

func _run() -> void :
	for i: int in range(4): await get_tree().process_frame
	var stage: Node3D = Node3D.new()
	add_child(stage)
	for id: String in scenes:
		var script: GDScript = MenuVignettes.SCENE_SCRIPTS.get(id)
		if script == null:
			print("CHECK %s : scène inconnue" % id)
			continue
		var scene: Node3D = script.new()
		scene.set("id", id)
		stage.add_child(scene)
		var t0: int = Time.get_ticks_usec()
		scene.call("setup", self)
		var worst: float = 0.0
		var steps: int = 0
		while not bool(scene.get("built")):
			var a: int = Time.get_ticks_usec()
			scene.call("build_next")
			var cost: float = float(Time.get_ticks_usec() - a) / 1000.0
			worst = maxf(worst, cost)
			if cost > 8.0: print("CHECK %s : étape %d lente, %.1f ms" % [id, steps, cost])
			steps += 1
			if steps > 400: break
		var build_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
		var beats: Array = scene.get("beats")
		var total: float = 0.0
		for beat: Dictionary in beats: total += float(beat.get("len", 0.0))
		print("CHECK %s : %d étapes, %.1f ms au total, pire étape %.1f ms, %d temps forts, %.1f s" % [id, steps, build_ms, worst, beats.size(), total])
		scene.call("enter")
		var frames: int = 0
		var spent: float = 0.0
		var peak: float = 0.0
		var dt: float = 1.0 / 60.0
		var length: float = total * float(loops) if total < 1.0e6 else 20.0
		var played: Dictionary = {}
		var t: float = 0.0
		while t < length:
			var a: int = Time.get_ticks_usec()
			scene.call("tick", dt)
			var cost: float = float(Time.get_ticks_usec() - a) / 1000.0
			spent += cost
			peak = maxf(peak, cost)
			if cost > 6.0: print("CHECK %s : image lente à %.2f s (%s), %.1f ms" % [id, float(scene.get("beat_time")), str((scene.get("beat") as Dictionary).get("id", "")), cost])
			frames += 1
			t += dt
			var beat: Dictionary = scene.get("beat")
			if not beat.is_empty(): played[str(beat.get("id", ""))] = int(played.get(str(beat.get("id", "")), 0)) + 1
		print("CHECK %s : %d images, animation moyenne %.3f ms, pointe %.2f ms, temps forts joués %s" % [id, frames, spent / maxf(1.0, float(frames)), peak, str(played.keys())])
		scene.queue_free()
		await get_tree().process_frame
	print("CHECK fin")
	get_tree().quit()
