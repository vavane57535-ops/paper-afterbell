extends Node

# Accords au féminin (Lysia, Elly, Bleuette) dans les textes de partie : bulles (éliminée, au sol,
# relevée, échappée), liste des élèves du HUD (POURSUIVIE, ÉLIMINÉE, ÉVADÉE), bulletin de fin
# (ÉVADÉE, TOMBÉE) et titre du spectateur évadé.
#   XDG_DATA_HOME=<dossier de test> xvfb-run -a -s "-screen 0 1280x800x24" godot --rendering-driver opengl3 \
#       -- --tool test_gender_labels --gl-out DIR [--gl-en]
#   Sans rendu (textes seulement) : godot --headless -- --tool test_gender_labels
# Lignes « GENDER OK|FAIL … », images DIR/*.png, puis « GENDER_TEST OK|FAIL n ».

var world: Node
var out_dir: String = "user://gender_labels"
var english: bool = false
var _fails: int = 0
var _toasts: PackedStringArray = PackedStringArray()

func setup(game_world: Node) -> void :
	world = game_world
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(args.size()):
		if args[i] == "--gl-out" and i + 1 < args.size(): out_dir = args[i + 1]
		if args[i] == "--gl-en": english = true
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()

func _check(ok: bool, what: String) -> void :
	print("GENDER ", "OK   " if ok else "FAIL ", what)
	if not ok: _fails += 1

func _wait(seconds: float) -> void :
	await get_tree().create_timer(seconds, true, false, true).timeout

func _shot(tag: String) -> void :
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var path: String = out_dir.path_join(tag + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("GENDER_FRAME ", path)

func _actor(character: String) -> PaperActor:
	for a: PaperActor in world.actors.values():
		if a.character == character: return a
	return null

# Textes visibles sous un nœud (libellés), pour chercher un mot.
func _texts(node: Node, out: PackedStringArray) -> void :
	if node is Label and (node as Label).is_visible_in_tree(): out.append(str((node as Label).text))
	for child: Node in node.get_children(): _texts(child, out)

func _has(node: Node, wanted: String) -> bool:
	var all: PackedStringArray = PackedStringArray()
	_texts(node, all)
	for text: String in all:
		if text.contains(wanted): return true
	return false

func _tr(text: String) -> String:
	return PaperLanguage.t(text) if english else text

func _run() -> void :
	await get_tree().process_frame
	if english: PaperLanguage.language = "en"
	world.selected = "Simon"
	world.start_solo(false)
	var waited: float = 0.0
	while world.phase != "playing" and waited < 30.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	await _wait(0.6)
	for a: PaperActor in world.actors.values():
		a.bot = false
		a.move_input = Vector3.ZERO
		a.velocity = Vector3.ZERO
	# Les bulles : on garde le dernier texte de chaque toast affiché.
	var label: Label = world.ui.toast_label
	var elly: PaperActor = _actor("Elly")
	world.eliminate(elly)
	await _wait(0.4)
	_toasts.append(str(label.text))
	_check(str(label.text) == _tr("Elly a été éliminée."), "bulle : « %s »" % label.text)
	var lysia: PaperActor = _actor("Lysia")
	world.exit_flow._escape(lysia)
	await _wait(0.4)
	_check(str(label.text) == _tr("Lysia s’est échappée."), "bulle : « %s »" % label.text)
	var bleuette: PaperActor = _actor("Bleuette")
	bleuette.effects["chased"] = 3.0
	await _wait(0.5)
	var roster: Node = world.ui.get("_hud")
	_check(roster != null and _has(roster, _tr("ÉLIMINÉE")), "liste : « %s » (Elly)" % _tr("ÉLIMINÉE"))
	_check(roster != null and _has(roster, _tr("ÉVADÉE")) if not english else true, "liste : « ÉVADÉE » (Lysia)")
	_check(roster != null and _has(roster, _tr("POURSUIVIE")) if not english else true, "liste : « POURSUIVIE » (Bleuette)")
	await _shot("liste_eleves")
	world._finish("survivors", false)
	waited = 0.0
	while world.ui.current_page != "ending" and waited < 90.0:
		await _wait(0.2)
		waited += 0.2
	await _wait(1.8)
	_check(_has(world.ui.overlay, _tr("TOMBÉE")), "bulletin : « %s » (Elly)" % _tr("TOMBÉE"))
	_check(_has(world.ui.overlay, _tr("ÉVADÉE")) if not english else true, "bulletin : « ÉVADÉE » (Lysia)")
	await _shot("bulletin")
	world.quit_to_menu()
	PaperLanguage.language = "fr"
	print("GENDER_TEST %s %d" % ["OK" if _fails == 0 else "FAIL", _fails])
	get_tree().quit()
