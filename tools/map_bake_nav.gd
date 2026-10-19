extends Node

# Caches de navigation des cartes OM (0.17, lot « cartes »).
# Cuisson : reconstruit le graphe des bots de chaque carte à partir de la géométrie et l'écrit dans
# res://maps/om_<carte>_navigation.res (révision om_maps.NAV_REVISION).
#   godot --headless -- --tool map_bake_nav --maps-rebuild-nav [--bake-map school,forest,snow]
# Vérification (sans --maps-rebuild-nav) : charge chaque carte comme le jeu et dit si le cache est relu.
#   godot --headless -- --tool map_bake_nav --bake-check
# À relancer après toute retouche qui change un sol, un mur, une rampe ou un obstacle, en montant NAV_REVISION.

var world: Node
var maps: Array[String] = ["school", "forest", "snow"]
var check_only: bool = false

func setup(owner: Node) -> void :
	world = owner
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(args.size()):
		if args[i] == "--bake-map" and i + 1 < args.size(): maps.assign(Array(args[i + 1].split(",")))
		if args[i] == "--bake-check": check_only = true
	_run.call_deferred()

func _run() -> void :
	var rebuild: bool = OS.get_cmdline_user_args().has("--maps-rebuild-nav")
	if not check_only and not rebuild:
		push_error("map_bake_nav : ajoute --maps-rebuild-nav (sinon le graphe est relu depuis l'ancien cache) ou --bake-check")
		get_tree().quit(1)
		return
	for i: int in range(3): await get_tree().process_frame
	var failures: int = 0
	for map_id: String in maps:
		var viewport: SubViewport = SubViewport.new()
		viewport.own_world_3d = true
		viewport.size = Vector2i(8, 8)
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(viewport)
		var school: PaperSchool = PaperSchool.new()
		viewport.add_child(school)
		school.build(map_id, "om")
		var layout: RefCounted = school.om_layout
		var report: Dictionary = layout.navigation_report
		var edges: int = 0
		for id: int in layout.graph.get_point_ids(): edges += layout.graph.get_point_connections(id).size()
		var line: Dictionary = {"nodes": layout.graph.get_point_count(), "edges": edges / 2, "build_ms": report.get("build_ms"), "baked": report.get("baked"), "jump_links": report.get("jump_links"), "revision": layout.NAV_REVISION}
		if check_only:
			if not bool(report.get("baked", false)): failures += 1
			print("NAV_CHECK ", map_id, " ", JSON.stringify(line))
		else:
			var error: Error = layout.save_navigation_cache()
			line["pruned"] = report.get("pruned")
			line["saved"] = error == OK
			if error != OK: failures += 1
			print("BAKE_NAV ", map_id, " ", JSON.stringify(line))
		viewport.queue_free()
		await get_tree().process_frame
	print("NAV_DONE ", "OK" if failures == 0 else "ÉCHEC %d" % failures)
	get_tree().quit(0 if failures == 0 else 1)
