extends Node

# Captures des cartes depuis des points de vue fixes (0.17, lot « cartes ») : mêmes vues avant et après
# les retouches, pour comparer. Les vues d'une liste (--shots-preset) sont rangées par carte.
#   xvfb-run -a -s "-screen 0 1280x800x24" godot --rendering-driver opengl3 -- --tool map_shots \
#       --shots-map forest --shots-preset tour --shots-out DOSSIER [--shots-only 0,3,5]
#   Vue libre : --view "x,y,z>cx,cy,cz[>fov]" (répétable), --shots-top (vue de dessus orthogonale).
# Les images sont nommées <carte>_<liste>_<NN>.png ; le journal imprime « SHOT chemin · nom ».

var world: Node
var map_id: String = "school"
var preset: String = ""
var out_dir: String = "/tmp/map_shots"
var only: Array[int] = []
var views: Array = []
var top: bool = false

const PRESETS: Dictionary = {
	"school": {
		"tour": [
			["hall", Vector3(0, 3.4, 40.5), Vector3(0, 1.4, 20), 62.0],
			["atrium", Vector3(-15, 3.2, 15), Vector3(0, 1.6, -3), 62.0],
			["bibliotheque", Vector3(-20, 3.6, -21), Vector3(-40, 0.8, -33), 62.0],
			["classe_circle", Vector3(15, 3.6, -20), Vector3(-2, 0.8, -35), 62.0],
			["cantine", Vector3(20, 3.6, -20), Vector3(40, 0.8, -33), 62.0],
			["gymnase", Vector3(-20, 4.2, 21), Vector3(-40, 0.8, 34), 64.0],
			["labo", Vector3(20, 4.2, 21), Vector3(40, 0.8, 34), 64.0],
			["thavel", Vector3(-20, 3.6, -16), Vector3(-40, 0.8, -6), 62.0],
			["infirmerie", Vector3(-20, 3.6, 2), Vector3(-42, 0.8, 12), 62.0],
			["atelier", Vector3(20, 3.6, -16), Vector3(40, 0.8, -6), 62.0],
			["vestiaires", Vector3(20, 3.6, 2), Vector3(42, 0.8, 12), 62.0],
			["bureau", Vector3(-20, 8.4, -20), Vector3(-40, 5.4, -34), 62.0],
			["portraits", Vector3(0, 8.6, -19.5), Vector3(0, 5.6, -38), 62.0],
			["musique", Vector3(20, 8.4, -20), Vector3(40, 5.4, -34), 62.0],
			["retenue", Vector3(-20, 8.4, 16), Vector3(-40, 5.4, 2), 62.0],
			["copies", Vector3(20, 8.4, 16), Vector3(40, 5.4, 2), 62.0],
			["galeries", Vector3(-15, 8.2, -15), Vector3(10, 4.0, 10), 64.0],
			["parvis", Vector3(0, 3.0, 56.5), Vector3(0, 2.4, 42), 62.0],
		],
	},
	"forest": {
		"tour": [
			["preau", Vector3(0, 3.2, 61), Vector3(0, 1.2, 40), 62.0],
			["fosse_pont", Vector3(0, 9.0, 8), Vector3(0, 2.0, -20), 64.0],
			["serre", Vector3(-20, 9.5, -4), Vector3(-38, 4.5, -24), 62.0],
			["cabane", Vector3(46, 13, -8), Vector3(31, 8.0, -30), 62.0],
			["portail", Vector3(0, 9.5, -40), Vector3(0, 4.0, -60), 62.0],
			["arret_bus", Vector3(-24, 7.5, -48), Vector3(-10, 5.0, -57), 62.0],
			["remise", Vector3(-48, 4.5, 20), Vector3(-64, 1.0, 15), 62.0],
			["potager", Vector3(44, 4.5, 40), Vector3(62, 1.0, 40), 62.0],
			["jeux", Vector3(-12, 4.5, 50), Vector3(-30, 1.0, 50), 62.0],
			["bord_est", Vector3(64, 3.6, -4), Vector3(76, 0.6, 4), 66.0],
			["bord_ouest", Vector3(-64, 3.6, 4), Vector3(-76, 0.6, -4), 66.0],
			["bord_sud", Vector3(52, 3.6, 54), Vector3(62, 0.6, 66), 66.0],
			["coin_nord_est", Vector3(62, 8.5, -56), Vector3(76, 4.0, -68), 66.0],
			["terrasse_est", Vector3(60, 9.0, -20), Vector3(40, 4.0, -30), 62.0],
		],
	},
	"snow": {
		"tour": [
			["arrivee", Vector3(0, 3.6, 58), Vector3(0, 1.2, 40), 62.0],
			["chalet", Vector3(24, 8.5, 32), Vector3(0, 4.0, 0), 62.0],
			["grande_salle", Vector3(8, 3.2, 9), Vector3(-6, 0.8, -6), 66.0],
			["dortoir", Vector3(8, 8.2, 9), Vector3(-6, 5.6, -4), 66.0],
			["passerelle", Vector3(10, 9.5, -8), Vector3(0, 5.0, -30), 62.0],
			["chalets_eleves", Vector3(26, 4.5, 10), Vector3(44, 1.0, 0), 62.0],
			["etang_peche", Vector3(-28, 5.0, 10), Vector3(-46, 1.0, -20), 62.0],
			["skis", Vector3(28, 4.5, 30), Vector3(43, 1.0, 43), 62.0],
			["gare", Vector3(-30, 9.5, -40), Vector3(-30, 5.0, -58), 62.0],
			["telepherique", Vector3(-34, 9.5, -52), Vector3(-44, 7.0, -66), 62.0],
			["remonte_pente", Vector3(40, 9.5, -40), Vector3(50, 5.0, -54), 62.0],
			["bord_est", Vector3(60, 3.6, -4), Vector3(72, 0.6, 4), 66.0],
			["bord_sud", Vector3(40, 3.6, 50), Vector3(52, 0.6, 62), 66.0],
			["bord_ouest_crete", Vector3(-58, 9.0, -48), Vector3(-72, 5.0, -60), 66.0],
		],
	},
}

func setup(owner: Node) -> void :
	world = owner
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(args.size()):
		var value: String = args[i + 1] if i + 1 < args.size() else ""
		match args[i]:
			"--shots-map": map_id = value
			"--shots-preset": preset = value
			"--shots-out": out_dir = value
			"--shots-only":
				for part: String in value.split(","): only.append(int(part))
			"--shots-top": top = true
			"--view":
				var parts: PackedStringArray = value.split(">")
				views.append(["vue%02d" % views.size(), _vec(parts[0]), _vec(parts[1]), float(parts[2]) if parts.size() > 2 else 60.0])
	if not preset.is_empty():
		var listed: Array = PRESETS.get(map_id, {}).get(preset, [])
		for index: int in range(listed.size()):
			if only.is_empty() or only.has(index): views.append(listed[index])
	_run.call_deferred()

func _vec(text: String) -> Vector3:
	var p: PackedStringArray = text.split(",")
	return Vector3(float(p[0]), float(p[1]), float(p[2]))

func _run() -> void :
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1280, 720)
	for i: int in range(6): await get_tree().process_frame
	world.gallery.open()
	if map_id != str(world.selected_map): world._rebuild_map(map_id)
	world.film.stop();world.ui.hide_film();world.ui.page.hide();world.ui.overlay.hide();world.ui.hud.hide()
	var stem: String = map_id + "_" + (preset if not preset.is_empty() else "vue")
	var index: int = 0
	for view: Array in views:
		world.camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		world.camera.position = view[1];world.camera.look_at(view[2]);world.camera.fov = float(view[3])
		for k: int in range(3): await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path: String = "%s/%s_%02d.png" % [out_dir, stem, index if only.is_empty() else int(only[index])]
		get_viewport().get_texture().get_image().save_png(path)
		print("SHOT ", path, " · ", view[0])
		index += 1
	if top:
		var rect: Rect2 = world.school._bounds
		var levels: Array = [[60.0, "dessus"]] if map_id != "school" else [[9.3, "etage"], [4.4, "rdc"]]
		for level: Array in levels:
			world.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			world.camera.size = maxf(rect.size.x * 720.0 / 1280.0, rect.size.y) + 4.0
			world.camera.near = 0.05;world.camera.far = 200.0
			world.camera.position = Vector3(rect.get_center().x, float(level[0]), rect.get_center().y)
			world.camera.rotation = Vector3(-PI * 0.5, 0, 0)
			for k: int in range(3): await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var path: String = "%s/%s_%s.png" % [out_dir, map_id, level[1]]
			get_viewport().get_texture().get_image().save_png(path)
			print("SHOT ", path, " · ", level[1])
	get_tree().quit()
