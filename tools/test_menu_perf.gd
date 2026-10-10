extends Node

# Coût CPU des menus (headless) : temps de traitement moyen par image sur le
# menu principal, les réglages et le menu pause.
# godot --headless -- --tool test_menu_perf [--perf-split]

var world: Node

func setup(game_world: Node) -> void :
	world = game_world
	var starter: Starter = Starter.new()
	starter.owner_tool = self
	starter.process_priority = -100000
	world.add_child(starter)
	if DisplayServer.get_name() == "headless":
		OS.low_processor_usage_mode = false
		OS.low_processor_usage_mode_sleep_usec = 0
		Engine.max_fps = 0
		get_tree().process_frame.connect(_frame_tick)
	else: RenderingServer.frame_pre_draw.connect(_on_pre_draw)
	_run.call_deferred()

# Travail CPU d'une image : du début du traitement (nœud prioritaire) jusqu'à
# frame_pre_draw (après les _process et les redessins en attente).
var _frame_start: int = 0
var _works: Array[float] = []
var _measuring: bool = false

class Starter extends Node:
	var owner_tool: Node
	func _process(_delta: float) -> void :
		owner_tool.set("_frame_start", Time.get_ticks_usec())

func _on_pre_draw() -> void :
	if _measuring and _frame_start > 0: _works.append(float(Time.get_ticks_usec() - _frame_start) / 1000.0)

var _last_start: int = 0

func _frame_tick() -> void :
	# Headless : pas de frame_pre_draw ; on mesure la durée totale de l'image
	# (sommeil du mode basse consommation désactivé).
	var now: int = Time.get_ticks_usec()
	if _measuring and _last_start > 0: _works.append(float(now - _last_start) / 1000.0)
	_last_start = now

func _sample(label: String, frames: int = 150) -> void :
	_works.clear()
	_measuring = true
	for i: int in range(frames): await get_tree().process_frame
	_measuring = false
	if _works.is_empty():
		print("[perf] %s : pas de mesure (frame_pre_draw absent)" % label)
		return
	_works.sort()
	print("[perf] %s : médiane %.2f ms de travail / image, 90e centile %.2f ms (%d images)" % [label, _works[_works.size() / 2], _works[int(_works.size() * 0.9)], _works.size()])

func _nodes_of(root: Node, script_path: String, out: Array) -> void :
	for child: Node in root.get_children():
		var script: Script = child.get_script() as Script
		if script and script.resource_path.ends_with(script_path): out.append(child)
		_nodes_of(child, script_path, out)

func _run() -> void :
	for i: int in range(30): await get_tree().process_frame
	await _sample("menu principal")
	if "--perf-split" in OS.get_cmdline_user_args():
		var decors: Array = []
		for child: Node in world.ui.root.find_children("*", "Control", true, false):
			if child.get_class() == "Control" and child.has_method("_draw") and "ribbon_text" in child: decors.append(child)
		print("[perf] décors trouvés : ", decors.size())
		for d: Node in decors:
			(d as Control).visible = false
			d.set_process(false)
		await _sample("menu principal sans décors")
		world.ui.fx.set_process(false)
		await _sample("menu principal sans décors ni fx")
		for item: Node in world.ui.page.find_children("*", "Button", true, false):
			(item as Control).visible = false
		await _sample("menu principal sans boutons")
		world.ui.fx.set_process(true)
	world.ui.show_settings()
	for i: int in range(40): await get_tree().process_frame
	await _sample("réglages")
	if "--perf-split" in OS.get_cmdline_user_args():
		var decors: Array = world.ui.root.find_children("*", "Control", true, false).filter(func(n: Node) -> bool: return "ribbon_text" in n)
		for d: Node in decors:
			(d as Control).visible = false
			d.set_process(false)
		await _sample("réglages sans décors (%d)" % decors.size())
		world.ui.fx.set_process(false)
		await _sample("réglages sans décors ni fx")
		world.ui.fx.set_process(true)
	world.ui.show_main()
	for i: int in range(40): await get_tree().process_frame
	world.selected = "Simon"
	world.start_solo(false)
	while world.phase != "playing": await get_tree().process_frame
	for i: int in range(60): await get_tree().process_frame
	await _sample("partie (sans pause)")
	world.pause_open = true
	world.ui.show_pause(true)
	for i: int in range(30): await get_tree().process_frame
	await _sample("partie + menu pause")
	if "--perf-split" in OS.get_cmdline_user_args():
		var pause: Node = world.ui.get("_pause_menu")
		if pause:
			pause.get("_back").visible = false
			await _sample("pause sans calque du fond")
			pause.get("_front").visible = false
			await _sample("pause sans calques")
			for item: Node in pause.get("_entries"): (item as Control).visible = false
			await _sample("pause sans calques ni commandes")
	get_tree().quit()
