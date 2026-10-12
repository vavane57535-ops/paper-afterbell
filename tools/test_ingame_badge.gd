extends Node

# Bandeau « CAMÉRA : … » et plans cinématiques en jeu (exécutions) — sans rendu.
#   godot --headless -- --simulate Simon --duration 60 --tool test_ingame_badge [--badge-script res://chemin.gd]
# C est pressé (bandeau affiché), puis un plan prend la caméra (take_control, comme une exécution) :
# le bandeau doit s'effacer en moins de 0,3 s au lieu de rester par-dessus le plan, et la touche C
# doit rester sans effet tant que le plan tient la caméra.
# --badge-script : script de bandeau à comparer (par exemple une copie de l'ancienne version).
# Imprime « BADGE … » puis « BADGE_RESULT OK|FAIL ».

var world: Node
var _script_path: String = ""

func setup(game_world: Node) -> void :
	world = game_world
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i in range(args.size()):
		if args[i] == "--badge-script" and i + 1 < args.size(): _script_path = args[i + 1]
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func _wait(seconds: float) -> void :
	var goal: float = float(world.clock) + seconds
	while float(world.clock) < goal: await get_tree().process_frame

func _alpha(badge: Variant) -> float:
	if badge == null or not is_instance_valid(badge) or not (badge as Control).visible: return 0.0
	return (badge as Control).modulate.a

func _run() -> void :
	while world.phase != "playing": await get_tree().process_frame
	await _wait(0.8)
	for a: PaperActor in world.actors.values(): a.bot = false
	var rig = world.camera_rig
	rig.persist = false
	rig.set_mode("free", false)
	var failures: Array[String] = []
	rig.toggle_mode()
	var badge: Variant = rig.get("_badge")
	if _script_path != "":
		# bandeau de comparaison : même mise en place que le rig, autre script
		var other: Control = (load(_script_path) as GDScript).new()
		world.ui.root.add_child(other)
		other.setup(world)
		other.show_mode(rig.mode)
		badge.hide()
		badge = other
	await _wait(0.15)
	var shown: float = _alpha(badge)
	var holder: Node = Node.new()
	add_child(holder)
	rig.take_control(holder)
	await _wait(0.3)
	var during: float = _alpha(badge)
	var mode_before: String = rig.mode
	rig.toggle_mode()
	var mode_after: String = rig.mode
	rig.release_control(holder, 0.0)
	holder.queue_free()
	print("BADGE shown=%.2f during_shot=%.2f mode %s -> %s (C pendant le plan)" % [shown, during, mode_before, mode_after])
	if shown < 0.5: failures.append("bandeau non affiché avant le plan")
	if during > 0.05: failures.append("bandeau encore visible 0,3 s après la prise de caméra (%.2f)" % during)
	if mode_after != mode_before: failures.append("C a changé le mode pendant le plan")
	print("BADGE_RESULT ", "OK" if failures.is_empty() else "FAIL", " ", JSON.stringify(failures))
	get_tree().quit()
