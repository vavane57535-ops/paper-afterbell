extends Node

# Vérification du prologue « Yiero » (film du premier lancement).
#   -- --tool test_intro --intro-mode scan                 lecture complète sans rendu (erreurs, dialogues)
#   -- --tool test_intro --intro-mode capture [--intro-out DIR] [--intro-from S] [--intro-to S] [--intro-step S]
#        lecture réelle (lancer avec --fixed-fps 15 pour un pas de temps fixe) et une capture toutes les
#        ~2 s + des captures rapprochées sur les moments clés
#   -- --tool test_intro --intro-mode gallery              lecture depuis la cinémathèque (avance, pause, retour)
#   -- --tool test_intro --intro-mode first --first-launch premier lancement : le film démarre seul, se passe en
#        maintenant Échap, et le drapeau [story] intro_seen est écrit (utiliser un XDG_DATA_HOME de test !)
#   -- --tool test_intro --intro-mode second --first-launch lancement suivant (même dossier) : le menu s'ouvre directement

const KEY_MOMENTS: Array[float] = [9.6, 18.5, 31.8, 35.6, 37.4, 39.2, 43.0, 47.5, 50.45, 55.15, 59.0, 63.35, 66.5, 68.7, 69.6, 70.5, 74.0, 75.3, 76.1, 78.3, 79.1, 79.6, 82.6, 84.0, 85.5, 88.0, 89.95, 92.95, 93.8, 97.0, 98.5, 100.0, 102.0, 105.0, 110.5, 114.5, 115.5, 116.6, 119.6, 123.0, 127.5, 132.1, 133.7, 136.8, 141.5, 146.0, 148.5, 150.2, 152.0, 154.6, 155.9, 158.0, 159.7, 161.0, 162.3, 163.5, 165.2, 167.0, 169.8, 171.8, 174.6, 177.2, 177.7, 179.2, 180.0, 183.5, 185.2, 187.6, 189.8, 193.0]

var world: Node
var mode: String = "capture"
var out_dir: String = "user://intro_caps"
var from_t: float = 0.0
var to_t: float = 196.0
var step: float = 2.0
var failures: Array[String] = []

func setup(owner: Node) -> void :
	world = owner
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(args.size()):
		if i + 1 >= args.size(): continue
		match args[i]:
			"--intro-mode": mode = args[i + 1]
			"--intro-out": out_dir = args[i + 1]
			"--intro-from": from_t = float(args[i + 1])
			"--intro-to": to_t = float(args[i + 1])
			"--intro-step": step = float(args[i + 1])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir) if out_dir.begins_with("user://") else out_dir)
	_run.call_deferred()

func _frames(count: int) -> void :
	for i: int in range(count): await get_tree().process_frame

func _save(label: String) -> void :
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var path: String = out_dir.path_join(label + ".png")
	var image: Image = world.get_viewport().get_texture().get_image() if DisplayServer.get_name() != "headless" else null
	if image == null: return
	image.save_png(path)
	print("INTRO_CAPTURE ", path)

func _check(ok: bool, what: String) -> void :
	print("INTRO_CHECK ", "OK   " if ok else "FAIL ", what)
	if not ok: failures.append(what)

func _run() -> void :
	await _frames(4)
	match mode:
		"scan": await _scan()
		"capture": await _capture()
		"gallery": await _gallery()
		"first": await _first()
		"second": await _second()
	print("INTRO_RESULT ", "OK" if failures.is_empty() else "FAIL " + ", ".join(failures))
	get_tree().quit()




func _scan() -> void :
	world.play_prologue()
	_check(world.phase == "prologue", "play_prologue() passe en phase prologue")
	world.set_process(false)
	var film: Node = world.prologue
	var seen: Dictionary = {}
	var t: float = 0.0
	var started: int = Time.get_ticks_msec()
	while t <= film.duration:
		film.update(t, 1.0 / 30.0)
		var line: Array = film._line_at(t)
		if not line.is_empty(): seen[str(line[2])] = true
		t += 1.0 / 30.0
	print("INTRO_SCAN durée=", film.duration, " lignes=", film._lines.size(), " vues=", seen.size(), " plans=", film._shots.size(), " temps_ms=", Time.get_ticks_msec() - started)
	_check(seen.size() == film._lines.size(), "toutes les répliques s'affichent")
	_check(absf(film.duration - PaperCinema.duration_for("intro_yiero")) < 0.01, "durée catalogue = durée du film")
	for back: float in [150.0, 20.0, 115.0, 0.0]:
		film.seek(back)
	_check(true, "retours en arrière sans erreur")
	world.set_process(true)
	world.end_prologue()
	_check(world.phase == "menu", "retour au menu après le film")


func _capture() -> void :
	if world.phase != "prologue": world.play_prologue()
	var film: Node = world.prologue
	if from_t > 0.0:
		film.clock = from_t
	var times: Array[float] = []
	var t: float = ceilf(from_t / step) * step
	while t <= to_t:
		times.append(t)
		t += step
	for moment: float in KEY_MOMENTS:
		if moment >= from_t and moment <= to_t: times.append(moment)
	times.sort()
	var index: int = 0
	while index < times.size() and world.phase == "prologue":
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var clock: float = float(film.clock)
		if clock + 0.001 >= times[index]:
			var path: String = out_dir.path_join("intro_%06.2f.png" % clock)
			world.get_viewport().get_texture().get_image().save_png(path)
			print("INTRO_CAPTURE ", path)
			while index < times.size() and times[index] <= clock + 0.001: index += 1
		if clock >= to_t: break
	_check(true, "captures %.1f → %.1f" % [from_t, to_t])


func _gallery() -> void :
	world.gallery.open()
	await _frames(3)
	var entries: Array = world.gallery.entries
	var ids: Array = entries.map( func(item: Dictionary) -> String: return str(item.id))
	_check(str(ids[0]) == "intro_yiero", "le prologue est la première entrée de la cinémathèque")
	_check(not ids.has("intro_survivors") and not ids.has("intro_alice"), "les introductions des survivants et d'Alice ne sont plus listées")
	world.gallery.category = "intro"
	var intro: Array = world.gallery.filtered_entries()
	_check(intro.size() == 1, "catégorie Prologue : 1 scène")
	world.gallery.play_entry(entries[0])
	await _frames(30)
	_check(world.prologue.kind == "intro_yiero", "lecture du prologue depuis la cinémathèque")
	await _save("gallery_play")
	world.gallery.seek(56.0)
	await _frames(20)
	await _save("gallery_seek56")
	world.gallery.toggle_pause()
	await _frames(10)
	_check(world.prologue.paused and not world.gallery.playing, "pause")
	await _save("gallery_pause")
	world.gallery.toggle_pause()
	world.gallery.seek(187.5)
	await _frames(40)
	await _save("gallery_title")
	world.gallery.seek(20.0)
	await _frames(20)
	await _save("gallery_back20")
	world.gallery.browse()
	await _frames(10)
	_check(world.prologue.kind.is_empty(), "retour à la liste : le prologue est arrêté")
	_check(world.school.visible, "retour à la liste : l'école est réaffichée")
	await _save("gallery_list")
	var other: Dictionary = {}
	for item: Dictionary in entries:
		if str(item.id) == "lms_win_Simon": other = item
	world.gallery.play_entry(other)
	await _frames(20)
	_check(world.film.kind == "ending_lms" and world.prologue.kind.is_empty(), "une autre scène se lit toujours")
	await _save("gallery_other")
	world.gallery.close()
	await _frames(5)
	_check(world.phase == "menu", "fermeture de la cinémathèque")


func _first() -> void :
	_check(world.phase == "prologue", "premier lancement : le prologue démarre avant le menu")
	var config: ConfigFile = ConfigFile.new()
	_check(config.load("user://settings.cfg") == OK and bool(config.get_value("story", "intro_seen", false)), "intro_seen écrit dans user://settings.cfg dès le début du film")
	if world.phase != "prologue": return
	await _frames(40)
	await _save("first_launch")
	var press: InputEventKey = InputEventKey.new()
	press.keycode = KEY_ESCAPE;press.physical_keycode = KEY_ESCAPE;press.pressed = true
	Input.parse_input_event(press)
	var waited: int = 0
	while world.phase == "prologue" and waited < 400:
		await get_tree().process_frame
		waited += 1
		if waited == 20: await _save("first_skip_gauge")
	var release: InputEventKey = InputEventKey.new()
	release.keycode = KEY_ESCAPE;release.physical_keycode = KEY_ESCAPE;release.pressed = false
	Input.parse_input_event(release)
	_check(world.phase == "menu", "maintenir Échap passe le film et ouvre le menu")
	await _frames(30)
	await _save("first_menu_after")


func _second() -> void :
	_check(world.phase == "menu" and bool(world.intro_seen), "lancement suivant : pas de prologue automatique, menu direct")
