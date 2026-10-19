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
		"defauts": [
			["lampe_biblio", Vector3(-37.5, 2.6, -26.5), Vector3(-42, 4.3, -30), 50.0],
			["compas", Vector3(-12.5, 2.2, -34.5), Vector3(-16.8, 2.0, -37), 55.0],
			["table_cantine", Vector3(30.5, 0.9, -28.8), Vector3(26, 0.45, -32), 55.0],
			["affiche_porte_thavel", Vector3(-40, 1.8, -6.5), Vector3(-40, 2.2, 0), 55.0],
			["rideaux_infirmerie", Vector3(-45.5, 1.8, 8.5), Vector3(-48.4, 1.2, 14), 55.0],
			["bancs_vestiaires", Vector3(31.5, 1.4, 9.2), Vector3(28, 0.4, 7.5), 55.0],
			["panier_gymnase", Vector3(-26, 2.6, 23.5), Vector3(-19.9, 2.6, 28.5), 55.0],
			["pomme_guirlande", Vector3(-7, 5.4, 5), Vector3(0, 5.0, -2), 60.0],
			["piano_pupitres", Vector3(36.5, 7.6, -21.5), Vector3(33.5, 5.8, -30), 58.0],
			["limons_escalier", Vector3(-9.5, 7.2, -17), Vector3(-6.5, 5.4, -12), 55.0],
			["rampe_gymnase", Vector3(-41, 3.2, 31), Vector3(-47, 2.4, 27), 58.0],
			["graffiti_bureau", Vector3(-36, 7.0, -35.5), Vector3(-36, 7.3, -41.5), 55.0],
			["parvis_sud", Vector3(0, 2.6, 44.5), Vector3(0, 1.0, 62), 62.0],
			["affiches_couloir", Vector3(0, 2.0, -9.5), Vector3(-8, 2.4, -17.7), 58.0],
		],
		"retouches": [
			["infirmerie_armoire", Vector3(-37, 1.8, 11), Vector3(-27, 1.2, 17.6), 60.0],
			["labo_tableau", Vector3(25, 1.8, 27), Vector3(18.3, 2.0, 24.0), 62.0],
			["archive_cantine", Vector3(37.6, 1.0, -32.2), Vector3(36, 0.25, -35.5), 50.0],
			["jonction_retenue", Vector3(-46, 6.6, 12), Vector3(-53.4, 5.8, 17.6), 58.0],
			["chapiteaux_hall", Vector3(4, 1.8, 31), Vector3(12, 9.4, 26), 64.0],
		],
		"objets": [
			["compas", Vector3(-13.5, 2.3, -35.5), Vector3(-17.7, 2.3, -37.0), 52.0],
			["guirlande", Vector3(-10, 6.2, 9), Vector3(0, 8.4, 0), 64.0],
			["piano_pupitres", Vector3(34.5, 7.3, -24.5), Vector3(36, 5.6, -31), 56.0],
			["rideaux", Vector3(-46.5, 1.7, 9.5), Vector3(-48.4, 1.2, 14), 56.0],
			["banc_casiers", Vector3(30.5, 1.1, 9.0), Vector3(28.5, 0.4, 7.0), 56.0],
			["panier_gymnase", Vector3(-37.5, 2.2, 24.0), Vector3(-45.6, 4.6, 27.5), 62.0],
			["lampe_tiges", Vector3(-33.5, 3.2, -27.5), Vector3(-36, 4.3, -30), 56.0],
			["limons", Vector3(-11.5, 1.8, 7.5), Vector3(-8, 3.0, -3), 60.0],
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
		"defauts": [
			["balancoire", Vector3(-21.5, 2.4, 38.5), Vector3(-28, 1.6, 44), 55.0],
			["dome_toboggan", Vector3(-25.5, 4.4, 43.5), Vector3(-31, 1.0, 52.5), 68.0],
			["panier", Vector3(30.5, 2.8, 43.5), Vector3(36.5, 3.0, 47), 55.0],
			["portail_lampe", Vector3(5.5, 6.6, -48.5), Vector3(0, 7.6, -57.5), 55.0],
			["serre_toit", Vector3(-24.5, 7.2, -7.5), Vector3(-30.5, 6.6, -18), 55.0],
			["cabane_toit", Vector3(40.5, 11.2, -31.5), Vector3(31, 10.6, -38), 55.0],
			["abribus", Vector3(-5.5, 6.2, -48.5), Vector3(-10, 7.0, -55.2), 55.0],
			["preau_panneau", Vector3(0, 2.4, 31), Vector3(0, 3.9, 37.3), 55.0],
			["potager", Vector3(59.5, 2.6, 30.5), Vector3(66, 1.2, 28), 55.0],
			["bord_est_sol", Vector3(63, 21, 4), Vector3(75, 0.0, 10), 58.0],
			["fosse_rocher", Vector3(-7, 3.2, -27.5), Vector3(-2, 1.4, -34), 55.0],
			["arbre_muret", Vector3(-31.5, 9.5, -44.5), Vector3(-39, 5.5, -52), 58.0],
		],
		"retouches": [
			["archive_potager", Vector3(61.6, 1.0, 43.0), Vector3(60, 0.25, 40), 50.0],
			["archive_serre", Vector3(-36.4, 5.0, -29.0), Vector3(-38, 4.25, -32), 50.0],
			["couronne_est", Vector3(64, 3.0, -12), Vector3(80, 4.0, -4), 64.0],
			["cloture_rocher", Vector3(67, 6.8, -53), Vector3(74, 5.0, -58), 58.0],
			["couronne_nord", Vector3(10, 8.5, -63), Vector3(14, 8.0, -78), 64.0],
		],
		"objets": [
			["dome", Vector3(-31.5, 2.6, 49.0), Vector3(-36, 1.0, 52), 58.0],
			["toboggan", Vector3(-27.5, 2.6, 50.0), Vector3(-24.5, 1.3, 54), 60.0],
			["balancoires", Vector3(-28, 2.0, 38.5), Vector3(-28, 1.6, 44), 60.0],
			["panier_cour", Vector3(32.0, 2.4, 44.5), Vector3(36.6, 3.0, 47), 56.0],
			["potager_panneau", Vector3(66.5, 1.6, 22.0), Vector3(66, 1.3, 25.8), 56.0],
			["portail_sortie", Vector3(0, 6.6, -51.5), Vector3(0, 7.2, -58), 60.0],
			["preau_panneau", Vector3(0, 2.2, 31.0), Vector3(0, 4.3, 37), 56.0],
			["abribus", Vector3(-10, 5.8, -51.0), Vector3(-10, 6.6, -55.5), 60.0],
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
		"defauts": [
			["toit_chalet", Vector3(21, 9.4, 20.5), Vector3(12, 8.8, 12), 55.0],
			["fenetre_porte_dortoir", Vector3(-4, 6.8, 19), Vector3(-6, 7.0, 12.2), 55.0],
			["skis_dortoir", Vector3(-4.2, 6.9, -9.2), Vector3(-9, 6.0, -11.7), 58.0],
			["gare_lampe", Vector3(-24, 8.2, -45.5), Vector3(-30, 9.2, -53.5), 55.0],
			["telepherique", Vector3(-36.5, 9.0, -58.8), Vector3(-44, 7.4, -63), 62.0],
			["porte_cabane_rampe", Vector3(59, 2.2, -14.5), Vector3(52.5, 1.2, -24), 55.0],
			["skis_location", Vector3(40, 2.0, 47.5), Vector3(40, 1.4, 44.5), 58.0],
			["glace_fragile", Vector3(-23.5, 2.0, 4.5), Vector3(-30, 1.6, 0), 55.0],
			["porte_cabane_peche", Vector3(-56.5, 2.2, -17), Vector3(-50, 1.5, -22.5), 55.0],
			["arbre_remonte_pente", Vector3(38.5, 9.0, -51.5), Vector3(49.5, 7.5, -57.5), 60.0],
			["bord_est_sol", Vector3(59, 21, 2), Vector3(71, 0.0, 8), 58.0],
			["remonte_pente_panneau", Vector3(50, 7.2, -41.5), Vector3(50, 7.9, -48), 55.0],
		],
		"retouches": [
			["porte_dortoir_dedans", Vector3(-3.0, 6.7, 1.0), Vector3(-4.5, 6.3, 12), 66.0],
			["porte_dortoir_dehors", Vector3(-1.5, 6.9, 15.6), Vector3(-5, 6.4, 11), 66.0],
			["lanterne_crete", Vector3(-2, 7.0, -38.5), Vector3(-6, 6.4, -44), 60.0],
			["pignon_chalet", Vector3(4, 7.5, 30), Vector3(0, 11.0, 14.8), 60.0],
			["archive_cabane", Vector3(45.6, 1.0, 3.0), Vector3(44, 0.25, 0), 50.0],
			["couronne_ouest", Vector3(-62, 3.0, 4), Vector3(-80, 4.0, -8), 64.0],
		],
		"objets": [
			["telepherique", Vector3(-37.5, 7.6, -57.5), Vector3(-44, 7.6, -63), 62.0],
			["skis_dortoir", Vector3(-7.5, 6.6, -8.0), Vector3(-9, 6.0, -11.7), 56.0],
			["skis_location", Vector3(41, 1.9, 38.5), Vector3(40, 1.0, 43.5), 62.0],
			["glace_fragile", Vector3(-23.5, 1.8, 3.5), Vector3(-29.2, 1.3, 0), 56.0],
			["gare_sortie", Vector3(-30, 6.8, -46.5), Vector3(-30, 7.4, -54), 60.0],
			["remonte_pente", Vector3(50, 6.8, -42.5), Vector3(50, 7.6, -47.6), 58.0],
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
