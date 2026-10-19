extends Node

# Inventaire automatique des défauts des cartes (0.17, lot « cartes »), sans rendu.
#   godot --headless -- --tool map_audit [--audit-map school,forest,snow] [--audit-out DOSSIER]
#        [--audit-no-fall] [--audit-list 30]
# Chaque carte est reconstruite dans un monde 3D isolé, décor NON regroupé, et chaque pièce visible
# (boîte, cylindre, boule, rampe, arbre, archive) reçoit une forme de contrôle sur une couche privée.
# Contrôles :
#   flottant     : groupe de pièces qui ne touche rien qui le relie au sol (marge 4 cm) ;
#   suspendu     : pièce massive basse, tenue seulement par un contact de côté (meuble qui plane) ;
#   enterré      : pièce cachée sous le sol, ou enfoncée aux trois quarts ;
#   traverse     : deux objets différents qui s'interpénètrent de plus de 12 cm ;
#   arbre        : arbre qui pousse dans un bâtiment, un toit, un chemin bloqué ;
#   porte        : objet dans le passage d'une porte, porte qui donne sur un mur ou sur le vide ;
#   escalier     : rampe dont un bout ne donne sur aucun sol ;
#   texte        : panneau qui flotte loin de tout mur, ou tourné face au mur ;
#   acces        : point important (apparitions, archives, prises, sortie…) loin du graphe des bots ;
#   trou         : vide atteignable (à pied ou en sautant 3,2 m) depuis une zone jouable ;
#   chute        : test physique, un acteur poussé vers chaque bord (marche, course, saut) ne doit
#                  jamais tomber ni sortir des limites.
# Journal : « AUDIT <carte> <contrôle> … » puis « AUDIT_SUMMARY <carte> {…} ». Avec --audit-out,
# un fichier <carte>.json et <carte>_views.txt (vues de chaque défaut pour tools/map_shots.gd).

class AuditSchool extends PaperSchool:
	# Carte construite comme en jeu, mais sans regroupement du décor ; chaque pièce garde la ligne
	# du constructeur de carte qui l'a créée (« map_school.gd:160 desk »).
	var trees: Array[Dictionary] = []

	static func site() -> String:
		var frames: Array = get_stack()
		var kit: String = ""
		for frame: Dictionary in frames:
			var source: String = str(frame.source).get_file()
			if source == "map_kit.gd" and kit.is_empty(): kit = str(frame.function)
			if source.begins_with("map_") and source != "map_kit.gd" and source != "map_audit.gd":
				return "%s:%d%s" % [source, int(frame.line), (" " + kit) if not kit.is_empty() else ""]
		for frame: Dictionary in frames:
			var source: String = str(frame.source).get_file()
			if source not in ["school.gd", "map_audit.gd", "om_maps.gd", "map_kit.gd"]:
				return "%s:%d" % [source, int(frame.line)]
		return "?"

	func _box(size: Vector3, pos: Vector3, material: Material, collision: bool = false, nav: bool = true) -> MeshInstance3D:
		var node: MeshInstance3D = super(size, pos, material, collision, nav)
		node.set_meta("audit_site", site())
		return node

	func _cylinder(pos: Vector3, radius: float, height: float, material: Material, top_radius: float = -1.0) -> MeshInstance3D:
		var node: MeshInstance3D = super(pos, radius, height, material, top_radius)
		node.set_meta("audit_site", site())
		return node

	func _organic(pos: Vector3, radii: Vector3, material: Material) -> MeshInstance3D:
		var node: MeshInstance3D = super(pos, radii, material)
		node.set_meta("audit_site", site())
		return node

	func _label(text_value: String, pos: Vector3, size: int = 38, color: Color = Color("e7e0d1"), rotate_y: float = 0.0) -> Label3D:
		var node: Label3D = super(text_value, pos, size, color, rotate_y)
		node.set_meta("audit_site", site())
		return node

	func _forest_tree(pos: Vector3, height: float, style: int, collidable: bool = true) -> void :
		var kind: String = "round" if style % 5 == 0 and not _snow else "pine"
		trees.append({"kind": kind, "transform": Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * height), pos), "site": site(), "collidable": collidable})
		super(pos, height, style, collidable)

	func _batch_static_details(_sector_size: float = BATCH_SECTOR, _flat_sector: float = -1.0) -> void :
		_flush_tree_batches()

const CoreArchives = preload("res://core_archives.gd")
const PROXY_LAYER: int = 1 << 15
const ACTOR_MASK: int = 3
const MARGIN: float = 0.04
const JUMP_HEIGHT: float = 3.2
const CAPSULE_RADIUS: float = 0.38
const CAPSULE_HEIGHT: float = 1.75

# [carte, contrôle, extrait du texte, raison] : vérifiés en capture, ce ne sont pas des défauts.
const ALLOWED: Array = []

var world: Node
var maps: Array[String] = ["school", "forest", "snow"]
var out_dir: String = ""
var fall_test: bool = true
var list_limit: int = 30
var totals: Dictionary = {}

# état de la carte en cours
var school: AuditSchool
var layout: RefCounted
var space: PhysicsDirectSpaceState3D
var space_rid: RID
var pieces: Array[Dictionary] = []
var by_rid: Dictionary = {}
var findings: Array[Dictionary] = []
var views: Array[String] = []

func setup(owner: Node) -> void :
	world = owner
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(args.size()):
		var value: String = args[i + 1] if i + 1 < args.size() else ""
		match args[i]:
			"--audit-map": maps.assign(Array(value.split(",")))
			"--audit-out": out_dir = value
			"--audit-no-fall": fall_test = false
			"--audit-list": list_limit = int(value)
	_run.call_deferred()

func _run() -> void :
	for i: int in range(4): await get_tree().process_frame
	if not out_dir.is_empty(): DirAccess.make_dir_recursive_absolute(out_dir)
	for map_id: String in maps:
		await _audit_map(map_id)
	print("AUDIT_TOTALS ", JSON.stringify(totals))
	get_tree().quit()

# ---------------------------------------------------------------- construction

func _audit_map(map_id: String) -> void :
	var started: int = Time.get_ticks_msec()
	findings.clear();views.clear();pieces.clear();by_rid.clear()
	var viewport: SubViewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.size = Vector2i(8, 8)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	school = AuditSchool.new()
	viewport.add_child(school)
	school.build(map_id, "om")
	layout = school.om_layout
	var interactables: PaperMapInteractables = PaperMapInteractables.new()
	school.add_child(interactables)
	interactables.build(school)
	var center: Vector3 = Vector3.ZERO
	for point: Vector3 in school.objectives: center += point
	center /= maxf(1.0, school.objectives.size())
	CoreArchives.new().build(school, school.objectives, center)
	await get_tree().physics_frame
	space = school.get_world_3d().direct_space_state
	space_rid = school.get_world_3d().space
	_collect_pieces()
	await get_tree().physics_frame
	await get_tree().physics_frame
	space = school.get_world_3d().direct_space_state
	_contacts()
	_floating()
	_sunk()
	_crossing()
	_trees()
	_doors()
	_stairs()
	_labels()
	_access()
	_holes()
	if fall_test: await _fall()
	var summary: Dictionary = {"pieces": pieces.size(), "trees": school.trees.size(), "nav_nodes": layout.graph.get_point_count(), "ms": Time.get_ticks_msec() - started}
	var counts: Dictionary = {}
	for finding: Dictionary in findings:
		counts[finding.check] = int(counts.get(finding.check, 0)) + 1
	summary["counts"] = counts
	totals[map_id] = counts
	var printed: Dictionary = {}
	for finding: Dictionary in findings:
		var shown: int = int(printed.get(finding.check, 0))
		if shown < list_limit:
			print("AUDIT ", map_id, " ", finding.check, " ", finding.text)
		printed[finding.check] = shown + 1
	print("AUDIT_SUMMARY ", map_id, " ", JSON.stringify(summary))
	if not out_dir.is_empty():
		var file: FileAccess = FileAccess.open(out_dir.path_join(map_id + ".json"), FileAccess.WRITE)
		file.store_string(JSON.stringify({"summary": summary, "findings": findings.map(_plain)}, "  "))
		var view_file: FileAccess = FileAccess.open(out_dir.path_join(map_id + "_views.txt"), FileAccess.WRITE)
		for line: String in views: view_file.store_line(line)
	for piece: Dictionary in pieces:
		PhysicsServer3D.free_rid(piece.rid)
	pieces.clear();by_rid.clear()
	viewport.queue_free()
	await get_tree().process_frame

func _plain(finding: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: String in finding:
		var value: Variant = finding[key]
		result[key] = [value.x, value.y, value.z] if value is Vector3 else value
	return result

func _collect_pieces() -> void :
	for node: Node in school.find_children("*", "MeshInstance3D", true, false):
		var mesh_node: MeshInstance3D = node
		if mesh_node.mesh == null or not mesh_node.is_visible_in_tree(): continue
		if mesh_node.mesh is TorusMesh or mesh_node.name in ["Seal", "ProgressRing"]: continue
		var kind: String = "archive" if mesh_node.name == "Cabinet" else "mesh"
		_add_piece(mesh_node, kind)
	for tree: Dictionary in school.trees:
		_add_tree(tree)

func _describe(node: Node3D, aabb: AABB) -> String:
	var material: Material = null
	if node is GeometryInstance3D: material = (node as GeometryInstance3D).material_override
	var color: String = (material as StandardMaterial3D).albedo_color.to_html(false) if material is StandardMaterial3D else "-"
	var mesh_name: String = node.mesh.get_class().trim_suffix("Mesh") if node is MeshInstance3D and (node as MeshInstance3D).mesh != null else "?"
	return "[%s] %s #%s centre %s taille %s" % [str(node.get_meta("audit_site", node.name)), mesh_name, color, _v(aabb.get_center()), _v(aabb.size)]

func _v(p: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [p.x, p.y, p.z]

func _add_piece(node: MeshInstance3D, kind: String) -> void :
	var xform: Transform3D = node.global_transform
	var aabb: AABB = xform * node.mesh.get_aabb()
	var shape: Shape3D
	var shape_xform: Transform3D
	var basis_scale: Vector3 = xform.basis.get_scale()
	var rigid: bool = basis_scale.is_equal_approx(Vector3.ONE)
	var flat: bool = aabb.size.y < 0.05 and xform.basis.y.y > 0.99
	if node.mesh is BoxMesh and rigid:
		var box: BoxShape3D = BoxShape3D.new()
		box.size = ((node.mesh as BoxMesh).size).max(Vector3(0.012, 0.012, 0.012))
		shape = box
		shape_xform = Transform3D(xform.basis.orthonormalized(), xform.origin)
	elif flat:
		var slab: BoxShape3D = BoxShape3D.new()
		slab.size = Vector3(maxf(aabb.size.x, 0.02), 0.02, maxf(aabb.size.z, 0.02))
		shape = slab
		shape_xform = Transform3D(Basis.IDENTITY, aabb.get_center())
	else:
		var points: PackedVector3Array = PackedVector3Array()
		for surface: int in range(node.mesh.get_surface_count()):
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
				points.append(xform.basis * vertex)
		if points.size() > 400:
			var step: int = ceili(points.size() / 400.0)
			var thinned: PackedVector3Array = PackedVector3Array()
			for index: int in range(0, points.size(), step): thinned.append(points[index])
			points = thinned
		var hull: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
		hull.points = points
		shape = hull
		shape_xform = Transform3D(Basis.IDENTITY, xform.origin)
	var ground: bool = _is_ground(node, aabb)
	_register({"node": node, "kind": kind, "aabb": aabb, "shape": shape, "xform": shape_xform, "ground": ground, "flat": flat, "group": -1, "label": _describe(node, aabb), "order": pieces.size()})

func _add_tree(tree: Dictionary) -> void :
	var placement: Transform3D = tree.transform
	var height: float = placement.basis.get_scale().y
	var base: Vector3 = placement.origin
	var trunk: CylinderShape3D = CylinderShape3D.new()
	trunk.radius = 0.04 * height
	trunk.height = 0.68 * height
	var trunk_aabb: AABB = AABB(base + Vector3(-trunk.radius, 0, -trunk.radius), Vector3(trunk.radius * 2, trunk.height, trunk.radius * 2))
	var label: String = "[%s] arbre %s h=%.1f pied %s" % [str(tree.get("site", "?")), tree.kind, height, _v(base)]
	_register({"node": null, "kind": "tree_trunk", "aabb": trunk_aabb, "shape": trunk, "xform": Transform3D(Basis.IDENTITY, base + Vector3(0, trunk.height * 0.5, 0)), "ground": false, "flat": false, "group": -1, "label": label, "order": pieces.size(), "base": base, "height": height})
	var crown: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
	var points: PackedVector3Array = PackedVector3Array()
	if tree.kind == "round":
		for i: int in range(10):
			var angle: float = i * TAU / 10.0
			for y: float in [0.5, 0.75, 1.0]:
				var r: float = 0.26 * height * sin(PI * (y - 0.45) / 0.6)
				points.append(Vector3(cos(angle) * r, y * height * 0.92, sin(angle) * r))
	else:
		for i: int in range(10):
			var angle: float = i * TAU / 10.0
			points.append(Vector3(cos(angle) * 0.24 * height, 0.22 * height, sin(angle) * 0.24 * height))
		points.append(Vector3(0, 0.98 * height, 0))
	crown.points = points
	var crown_aabb: AABB = AABB(base + Vector3(-0.26 * height, 0.22 * height, -0.26 * height), Vector3(0.52 * height, 0.76 * height, 0.52 * height))
	_register({"node": null, "kind": "tree_crown", "aabb": crown_aabb, "shape": crown, "xform": Transform3D(Basis.IDENTITY, base), "ground": false, "flat": false, "group": -1, "label": label + " (feuillage)", "order": pieces.size(), "base": base, "height": height})

func _register(piece: Dictionary) -> void :
	var rid: RID = PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_mode(rid, PhysicsServer3D.BODY_MODE_STATIC)
	PhysicsServer3D.body_add_shape(rid, piece.shape.get_rid(), piece.xform)
	PhysicsServer3D.body_set_collision_layer(rid, PROXY_LAYER)
	PhysicsServer3D.body_set_collision_mask(rid, 0)
	PhysicsServer3D.body_set_space(rid, space_rid)
	piece["rid"] = rid
	piece["contacts"] = []
	by_rid[rid] = pieces.size()
	pieces.append(piece)

func _is_ground(node: MeshInstance3D, aabb: AABB) -> bool:
	if node.mesh is ArrayMesh and node.get_child_count() > 0:
		for ramp: Dictionary in layout.ramps:
			if Rect2(aabb.position.x, aabb.position.z, aabb.size.x, aabb.size.z).grow(0.1).encloses(ramp.rect):
				return true
	if not node.mesh is BoxMesh: return false
	var footprint: Rect2 = Rect2(aabb.position.x, aabb.position.z, aabb.size.x, aabb.size.z)
	for surface: Dictionary in layout.surfaces:
		if surface.has("start"): continue
		if absf(aabb.end.y - float(surface.height)) < 0.006 and surface.rect.grow(0.05).encloses(footprint) and aabb.size.y >= 0.25:
			return true
	return false

# ---------------------------------------------------------------- graphe de contacts

func _query(shape: Shape3D, xform: Transform3D, exclude: Array[RID], margin: float = MARGIN, mask: int = PROXY_LAYER, limit: int = 96) -> Array[Dictionary]:
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = xform
	query.margin = margin
	query.collision_mask = mask
	query.collide_with_areas = false
	query.exclude = exclude
	return space.intersect_shape(query, limit)

func _contacts() -> void :
	for index: int in range(pieces.size()):
		var piece: Dictionary = pieces[index]
		for hit: Dictionary in _query(piece.shape, piece.xform, [piece.rid]):
			var other: int = int(by_rid.get(hit.rid, -1))
			if other < 0 or other == index: continue
			if not piece.contacts.has(other): piece.contacts.append(other)
			if not pieces[other].contacts.has(index): pieces[other].contacts.append(index)
	# objets : pièces créées à la suite par la même ligne du constructeur et qui se touchent
	var group: int = 0
	var members: Dictionary = {}
	var current_site: String = ""
	for index: int in range(pieces.size()):
		var piece: Dictionary = pieces[index]
		if piece.kind == "tree_crown":
			piece.group = pieces[index - 1].group
			continue
		var site: String = _site_of(piece)
		var joined: bool = false
		if not piece.ground and site == current_site:
			for other: int in piece.contacts:
				if members.has(other):
					joined = true
					break
		if not joined:
			group += 1
			members.clear()
			current_site = site
		piece.group = group
		members[index] = true

func _site_of(piece: Dictionary) -> String:
	if piece.node != null: return str(piece.node.get_meta("audit_site", "?")).get_slice(" ", 0)
	return str(piece.label).get_slice("]", 0)

func _floor_below(p: Vector3, above: float = 0.3) -> float:
	var best: float = -INF
	for surface: Dictionary in layout.surfaces:
		if not surface.rect.grow(0.02).has_point(Vector2(p.x, p.z)): continue
		var height: float = layout._height(surface, Vector2(p.x, p.z))
		if height <= p.y + above and height > best: best = height
	return best

func _finding(check: String, where: Vector3, text: String, extra: Dictionary = {}) -> void :
	# défauts examinés à l'œil et gardés exprès (assemblages voulus) : comptés à part, sous « voulu »
	for allowed: Array in ALLOWED:
		if allowed[0] == school.map_id and check == allowed[1] and text.contains(allowed[2]):
			check = "voulu"
			break
	var entry: Dictionary = {"check": check, "position": where, "text": "à " + _v(where) + " · " + text}
	entry.merge(extra)
	findings.append(entry)
	var eye: Vector3 = _view_eye(where)
	views.append("%s_%03d|%f,%f,%f|%f,%f,%f|58" % [check, findings.size() - 1, eye.x, eye.y, eye.z, where.x, where.y, where.z])

func _view_eye(target: Vector3) -> Vector3:
	# point de vue dégagé à 4-7 m, hauteur d'épaule : rayons contre les murs et les feuillages
	var best: Vector3 = target + Vector3(0, 3, 5)
	var best_score: float = -1.0
	for step: int in range(12):
		var angle: float = step * TAU / 12.0
		for distance: float in [6.0, 4.0]:
			for rise: float in [1.6, 3.0]:
				var eye: Vector3 = target + Vector3(cos(angle) * distance, rise, sin(angle) * distance)
				var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(target + (eye - target).normalized() * 0.6, eye, 1 | PROXY_LAYER)
				var hit: Dictionary = space.intersect_ray(query)
				var score: float = distance + rise * 0.2 if hit.is_empty() else (Vector3(hit.position) - target).length() * 0.5
				if score > best_score:
					best_score = score
					best = eye
	return best

# ---------------------------------------------------------------- contrôles

func _floating() -> void :
	var reached: Dictionary = {}
	var queue: Array[int] = []
	for index: int in range(pieces.size()):
		if pieces[index].ground:
			reached[index] = true
			queue.append(index)
	while not queue.is_empty():
		var index: int = queue.pop_back()
		for other: int in pieces[index].contacts:
			if not reached.has(other):
				reached[other] = true
				queue.append(other)
	var seen: Dictionary = {}
	for index: int in range(pieces.size()):
		if reached.has(index) or seen.has(index): continue
		var cluster: Array[int] = [index]
		seen[index] = true
		var cursor: int = 0
		while cursor < cluster.size():
			for other: int in pieces[cluster[cursor]].contacts:
				if not seen.has(other) and not reached.has(other):
					seen[other] = true
					cluster.append(other)
			cursor += 1
		var bounds: AABB = pieces[cluster[0]].aabb
		for member: int in cluster: bounds = bounds.merge(pieces[member].aabb)
		var bottom: Vector3 = Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
		var floor_y: float = _floor_below(bottom, 0.05)
		var outside: bool = not layout.bounds.has_point(Vector2(bottom.x, bottom.z))
		var gap: String = "pas de sol dessous" if floor_y == -INF else "%.2f m au-dessus du sol" % (bounds.position.y - floor_y)
		_finding("flottant_hors_carte" if outside else "flottant", bounds.get_center(), "%d pièce(s), %s · %s" % [cluster.size(), gap, pieces[cluster[0]].label], {"pieces": cluster.size()})
	# meubles qui planent : massifs, bas, sans rien dessous ni dedans, tenus par le côté
	for index: int in range(pieces.size()):
		var piece: Dictionary = pieces[index]
		if piece.ground or piece.flat or not reached.has(index) or piece.kind != "mesh": continue
		var aabb: AABB = piece.aabb
		var thin: float = minf(aabb.size.x, minf(aabb.size.y, aabb.size.z))
		if thin < 0.1: continue
		var floor_y: float = _floor_below(Vector3(aabb.get_center().x, aabb.position.y, aabb.get_center().z), 0.05)
		if floor_y == -INF or aabb.position.y - floor_y < 0.06 or aabb.position.y - floor_y > 1.6: continue
		var supported: bool = false
		for other: int in piece.contacts:
			var o: AABB = pieces[other].aabb
			if o.end.y <= aabb.position.y + 0.07 or (o.position.y < aabb.position.y - 0.02 and o.end.y > aabb.position.y + 0.02 and _xz_overlap(o, aabb) > 0.0):
				supported = true
				break
			if o.position.y >= aabb.end.y - 0.07:
				supported = true
				break
		if not supported:
			_finding("suspendu", aabb.get_center(), "%.2f m au-dessus du sol, tenu par le côté · %s" % [aabb.position.y - floor_y, piece.label])

func _xz_overlap(a: AABB, b: AABB) -> float:
	var x: float = minf(a.end.x, b.end.x) - maxf(a.position.x, b.position.x)
	var z: float = minf(a.end.z, b.end.z) - maxf(a.position.z, b.position.z)
	return minf(x, z)

func _sunk() -> void :
	var masses: Array[AABB] = []
	for piece: Dictionary in pieces:
		if piece.ground and piece.aabb.size.y > 1.0: masses.append(piece.aabb)
	for piece: Dictionary in pieces:
		if piece.ground or piece.kind != "mesh": continue
		var aabb: AABB = piece.aabb
		var center: Vector3 = aabb.get_center()
		var buried: bool = false
		for mass: AABB in masses:
			if mass.grow(0.02).encloses(aabb): buried = true
		if buried:
			_finding("enterre", center, "caché dans un bloc de terrain · %s" % piece.label)
			continue
		var floor_y: float = _floor_below(Vector3(center.x, aabb.end.y, center.z), 0.0)
		if floor_y == -INF or aabb.size.y < 0.03: continue
		if aabb.end.y < floor_y - 0.005 and aabb.end.y > floor_y - 1.5:
			_finding("enterre", center, "entièrement sous le sol (%.2f m) · %s" % [floor_y - aabb.end.y, piece.label])
		elif aabb.position.y < floor_y - 0.12 and (aabb.end.y - floor_y) < aabb.size.y * 0.35 and aabb.size.y > 0.2:
			_finding("enfonce", center, "%.0f %% sous le sol · %s" % [100.0 * (floor_y - aabb.position.y) / aabb.size.y, piece.label])

func _crossing() -> void :
	var reported: Dictionary = {}
	for index: int in range(pieces.size()):
		var piece: Dictionary = pieces[index]
		if piece.ground or piece.flat or piece.kind == "tree_crown": continue
		for other: int in piece.contacts:
			if other <= index: continue
			var o: Dictionary = pieces[other]
			if o.ground or o.flat or o.group == piece.group or o.kind == "tree_crown": continue
			var a: AABB = piece.aabb
			var b: AABB = o.aabb
			var overlap: AABB = a.intersection(b)
			if overlap.size.x < 0.12 or overlap.size.y < 0.12 or overlap.size.z < 0.12: continue
			# assemblages voulus : coin de deux planches, moulure ou montant qui dépasse des deux faces d'un mur,
			# angle de deux murs
			var smaller: float = minf(a.get_volume(), b.get_volume())
			if overlap.get_volume() < smaller * 0.2 and overlap.get_volume() < 0.6: continue
			if _molding(a, b) or _molding(b, a): continue
			if _wall_like(a) and _wall_like(b) and overlap.size.x <= 0.75 and overlap.size.z <= 0.75: continue
			if not _deep(piece, o, 0.12): continue
			var key: Vector2i = Vector2i(piece.group, o.group)
			if reported.has(key): continue
			reported[key] = true
			_finding("traverse", overlap.get_center(), "%s ⟷ %s" % [piece.label, o.label])

func _wall_like(box: AABB) -> bool:
	return box.size.y >= 1.0 and (box.size.x <= 0.75 or box.size.z <= 0.75)

func _molding(trim: AABB, wall: AABB) -> bool:
	# la pièce « trim » traverse le mur de part en part dans son épaisseur (montant, plinthe, cadre)
	if wall.size.x <= 0.7 and wall.size.z > wall.size.x * 3.0:
		return trim.position.x <= wall.position.x + 0.005 and trim.end.x >= wall.end.x - 0.005 and trim.size.x <= wall.size.x + 0.5
	if wall.size.z <= 0.7 and wall.size.x > wall.size.z * 3.0:
		return trim.position.z <= wall.position.z + 0.005 and trim.end.z >= wall.end.z - 0.005 and trim.size.z <= wall.size.z + 0.5
	return false

func _deep(a: Dictionary, b: Dictionary, depth: float) -> bool:
	# la forme de a, rétrécie de « depth », touche-t-elle encore b ?
	var shrunk: Shape3D
	if a.shape is BoxShape3D:
		var box: BoxShape3D = BoxShape3D.new()
		box.size = (a.shape.size - Vector3.ONE * depth * 2.0).max(Vector3(0.01, 0.01, 0.01))
		shrunk = box
	elif a.shape is CylinderShape3D:
		var cylinder: CylinderShape3D = CylinderShape3D.new()
		cylinder.radius = maxf(0.01, a.shape.radius - depth)
		cylinder.height = maxf(0.02, a.shape.height - depth * 2.0)
		shrunk = cylinder
	else:
		var points: PackedVector3Array = a.shape.points
		var centroid: Vector3 = Vector3.ZERO
		for p: Vector3 in points: centroid += p / points.size()
		var smaller: PackedVector3Array = PackedVector3Array()
		for p: Vector3 in points:
			var offset: Vector3 = p - centroid
			smaller.append(centroid + offset * maxf(0.05, 1.0 - depth / maxf(0.05, offset.length())))
		var hull: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
		hull.points = smaller
		shrunk = hull
	for hit: Dictionary in _query(shrunk, a.xform, [a.rid], 0.0):
		if hit.rid == b.rid: return true
	return false

func _trees() -> void :
	for index: int in range(pieces.size()):
		var piece: Dictionary = pieces[index]
		if piece.kind != "tree_trunk": continue
		var base: Vector3 = piece.base
		var floor_y: float = _floor_below(base, 0.05)
		var outside: bool = not layout.bounds.has_point(Vector2(base.x, base.z))
		if floor_y == -INF:
			_finding("arbre_sans_sol" if not outside else "arbre_hors_carte_sans_sol", base, piece.label)
		elif absf(base.y - floor_y) > 0.08:
			_finding("arbre_flottant" if base.y > floor_y else "arbre_enfonce", base, "%.2f m · %s" % [base.y - floor_y, piece.label])
		for part: int in [index, index + 1]:
			for other: int in pieces[part].contacts:
				var o: Dictionary = pieces[other]
				if o.ground or o.flat or o.kind.begins_with("tree"): continue
				if o.aabb.size.y < 0.3 and o.aabb.end.y < base.y + 0.5: continue
				# un feuillage peut frôler un rocher ou une lanterne ; il ne doit pas entrer dans un bâtiment
				if part == index + 1 and o.node is MeshInstance3D and (o.node as MeshInstance3D).mesh is SphereMesh: continue
				if part == index + 1 and maxf(o.aabb.size.x, maxf(o.aabb.size.y, o.aabb.size.z)) < 1.5: continue
				if _deep(pieces[part], o, 0.15):
					_finding("arbre_traverse", o.aabb.get_center(), "%s ⟷ %s" % [piece.label, o.label])
					break

func _doors() -> void :
	for door: Dictionary in school.doors:
		var p: Vector3 = door.position
		var along_x: bool = door.axis == "x"
		var width: float = float(door.get("width", 6.0))
		var normal: Vector3 = Vector3(0, 0, 1) if along_x else Vector3(1, 0, 0)
		# les cloisons de l'étage partent du dessous de la dalle : le seuil est au niveau du sol réel
		var sill: float = _floor_below(p + Vector3.UP * 0.6, 0.0)
		if sill != -INF: p.y = sill
		var passage: BoxShape3D = BoxShape3D.new()
		passage.size = Vector3(width - 0.5, 2.1, 3.2) if along_x else Vector3(3.2, 2.1, width - 0.5)
		var xform: Transform3D = Transform3D(Basis.IDENTITY, p + Vector3(0, 1.2, 0))
		var blockers: Array[String] = []
		for hit: Dictionary in _query(passage, xform, [], 0.0):
			var other: int = int(by_rid.get(hit.rid, -1))
			if other < 0: continue
			var o: Dictionary = pieces[other]
			if o.ground or o.flat or o.aabb.size.y < 0.08: continue
			# montants et linteau du cadre de la porte, murs de part et d'autre
			if o.aabb.size.y > 2.4 and (o.aabb.size.x < 0.7 or o.aabb.size.z < 0.7) and _outside_opening(o.aabb, p, along_x, width): continue
			blockers.append(o.label)
		if not blockers.is_empty():
			_finding("porte_encombree", p, "porte %d (%s, %.0f m) : %s" % [int(door.id), door.axis, width, " ; ".join(blockers.slice(0, 3))])
		for side: float in [-1.0, 1.0]:
			var probe: Vector3 = p + normal * side * 1.3
			var floor_y: float = _floor_below(probe + Vector3.UP * 0.2, 0.4)
			if floor_y == -INF or absf(floor_y - p.y) > 0.6:
				_finding("porte_vide", probe, "porte %d : pas de sol de l'autre côté (%s)" % [int(door.id), "vide" if floor_y == -INF else "%.1f m" % (floor_y - p.y)])
				continue
			var body: CapsuleShape3D = CapsuleShape3D.new()
			body.radius = CAPSULE_RADIUS
			body.height = CAPSULE_HEIGHT
			if not _query(body, Transform3D(Basis.IDENTITY, Vector3(probe.x, floor_y + 0.06 + CAPSULE_HEIGHT * 0.5, probe.z)), [], 0.0, 1).is_empty():
				_finding("porte_sur_mur", probe, "porte %d : un obstacle bouche la sortie de la porte" % int(door.id))

func _outside_opening(aabb: AABB, door: Vector3, along_x: bool, width: float) -> bool:
	var half: float = width * 0.5 - 0.3
	if along_x: return aabb.end.x <= door.x - half or aabb.position.x >= door.x + half
	return aabb.end.z <= door.z - half or aabb.position.z >= door.z + half

func _stairs() -> void :
	for ramp: Dictionary in layout.ramps:
		var start: Vector3 = ramp.start
		var finish: Vector3 = ramp.finish
		var direction: Vector3 = Vector3(finish.x - start.x, 0, finish.z - start.z).normalized()
		for end: Array in [[start, -direction, "bas"], [finish, direction, "haut"]]:
			var p: Vector3 = end[0] + end[1] * 1.0
			var landing: bool = layout._surface_at(Vector2(p.x, p.z), float(end[0].y), 0.2)
			if not landing:
				_finding("escalier", p, "rampe %s → %s : le %s ne donne sur aucun sol" % [_v(start), _v(finish), end[2]])
		var body: CapsuleShape3D = CapsuleShape3D.new()
		body.radius = 0.3
		body.height = 1.7
		for t: float in [0.2, 0.5, 0.8]:
			var q: Vector3 = start.lerp(finish, t)
			if not _query(body, Transform3D(Basis.IDENTITY, q + Vector3.UP * 1.05), [], 0.0, 1).is_empty():
				_finding("escalier", q, "rampe %s → %s : passage bouché ou plafond trop bas" % [_v(start), _v(finish)])
				break

func _labels() -> void :
	for node: Node in school.find_children("*", "Label3D", true, false):
		var label: Label3D = node
		if label.billboard != BaseMaterial3D.BILLBOARD_DISABLED or label.fixed_size or not label.is_visible_in_tree(): continue
		var xform: Transform3D = label.global_transform
		var front: Vector3 = xform.basis.z.normalized()
		var p: Vector3 = xform.origin
		var back_hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(p + front * 0.02, p - front * 0.4, PROXY_LAYER | 1))
		var front_hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(p + front * 0.01, p + front * 0.3, PROXY_LAYER | 1))
		var text: String = label.text.replace("\n", " / ")
		if not front_hit.is_empty() and (Vector3(front_hit.position) - p).length() < 0.12:
			_finding("texte_face_mur", p, "« %s » : écrit contre un mur" % text)
		elif back_hit.is_empty():
			var below: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(p, p + Vector3.DOWN * 0.25, PROXY_LAYER | 1))
			if below.is_empty():
				_finding("texte_flottant", p, "« %s » : rien derrière à moins de 40 cm" % text)

func _access() -> void :
	var graph: AStar3D = layout.graph
	var spawn_id: int = layout._closest_point(school.spawn_points[0])
	var points: Array = []
	for i: int in range(school.spawn_points.size()): points.append(["apparition %d" % i, school.spawn_points[i]])
	points.append(["Alice", school.killer_spawn])
	for i: int in range(school.objectives.size()): points.append(["archive %d" % (i + 1), school.objectives[i]])
	for i: int in range(layout.outlets.size()): points.append(["prise %d" % (i + 1), layout.outlets[i]])
	points.append(["sortie", layout.exit_point])
	for i: int in range(school.patrol_points.size()): points.append(["ronde %d" % i, school.patrol_points[i]])
	for i: int in range(layout.upper_targets.size()): points.append(["étage %d" % i, layout.upper_targets[i]])
	points.append(["menu", school.menu_spawn])
	for entry: Array in points:
		var target: Vector3 = entry[1]
		var id: int = layout._closest_point(target)
		var node: Vector3 = graph.get_point_position(id)
		var flat: float = Vector2(node.x - target.x, node.z - target.z).length()
		var path: PackedInt64Array = graph.get_id_path(spawn_id, id)
		if flat > 2.2 or absf(node.y - target.y) > 1.2 or path.is_empty():
			_finding("acces", target, "%s : nœud le plus proche à %.1f m (dy %.1f), chemin %s" % [entry[0], flat, node.y - target.y, "OK" if not path.is_empty() else "AUCUN"])
	# prises : posées sur le sol, pas dans un meuble
	for i: int in range(layout.outlets.size()):
		var outlet: Vector3 = layout.outlets[i]
		var floor_y: float = _floor_below(outlet + Vector3.UP * 0.2, 0.4)
		if floor_y == -INF or absf(floor_y - outlet.y) > 0.1:
			_finding("acces", outlet, "prise %d : pas posée sur le sol (%s)" % [i + 1, "vide" if floor_y == -INF else "%.2f" % (outlet.y - floor_y)])

var void_cells: Dictionary = {}
var near_void: Dictionary = {}

func _holes() -> void :
	# colonnes de vide (aucun sol jusqu'à -40 m) proches de la zone jouable…
	var bounds: Rect2 = layout.bounds.grow(4.0)
	void_cells.clear();near_void.clear()
	var x: float = bounds.position.x
	while x <= bounds.end.x:
		var z: float = bounds.position.y
		while z <= bounds.end.y:
			if not _has_floor_column(Vector3(x, 0, z)): void_cells[Vector2i(roundi(x * 2.0), roundi(z * 2.0))] = true
			z += 0.5
		x += 0.5
	# zone « près du vide » : les cases de vide dilatées de 3 m (en deux passes)
	var band: Dictionary = {}
	for cell: Vector2i in void_cells:
		for dx: int in range(-6, 7): band[cell + Vector2i(dx, 0)] = true
	for cell: Vector2i in band:
		for dz: int in range(-6, 7): near_void[cell + Vector2i(0, dz)] = true
	# … qu'un acteur peut atteindre depuis un nœud du graphe (à pied ou en sautant par-dessus)
	var graph: AStar3D = layout.graph
	var body: CapsuleShape3D = CapsuleShape3D.new()
	body.radius = CAPSULE_RADIUS
	body.height = CAPSULE_HEIGHT
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = body
	query.collision_mask = ACTOR_MASK
	var reported: Dictionary = {}
	var count: int = 0
	for id: int in graph.get_point_ids():
		var node: Vector3 = graph.get_point_position(id)
		for step: int in range(16):
			var direction: Vector3 = Vector3(cos(step * TAU / 16.0), 0, sin(step * TAU / 16.0))
			var probe: Vector3 = node + direction * 2.4
			if not near_void.has(Vector2i(roundi(probe.x * 2.0), roundi(probe.z * 2.0))): continue
			for lift: float in [0.12, JUMP_HEIGHT]:
				var origin: Vector3 = node + Vector3.UP * (lift + CAPSULE_HEIGHT * 0.5)
				query.transform = Transform3D(Basis.IDENTITY, origin)
				query.motion = direction * 4.5
				var fraction: PackedFloat32Array = space.cast_motion(query)
				var travel: float = 4.5 * (fraction[0] if not fraction.is_empty() else 1.0)
				var d: float = 0.5
				while d <= travel:
					var spot: Vector3 = node + direction * d
					# le centre de la capsule au-dessus d'une case de vide (≥ 25 cm du bord) : elle glisse et tombe
					if void_cells.has(Vector2i(roundi(spot.x * 2.0), roundi(spot.z * 2.0))):
						var bucket: Vector2i = Vector2i(floori(spot.x / 4.0), floori(spot.z / 4.0))
						if not reported.has(bucket):
							reported[bucket] = true
							count += 1
							_finding("trou", spot, "vide atteignable %s depuis le nœud %s" % ["en sautant" if lift > 1.0 else "à pied", _v(node)])
						break
					d += 0.5

func _has_floor_column(p: Vector3) -> bool:
	var from: Vector3 = Vector3(p.x, 40.0, p.z)
	var exclude: Array[RID] = []
	for attempt: int in range(12):
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, Vector3(p.x, -40.0, p.z), 1)
		query.exclude = exclude
		query.hit_from_inside = false
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty(): return false
		if Vector3(hit.normal).y > 0.6: return true
		exclude.append(hit.rid)
	return false

# ---------------------------------------------------------------- test de chute

func _fall() -> void :
	var graph: AStar3D = layout.graph
	var bounds: Rect2 = layout.bounds
	var center: Vector2 = bounds.get_center()
	var starts: Array[Dictionary] = []
	for id: int in graph.get_point_ids():
		var node: Vector3 = graph.get_point_position(id)
		var edge_distance: float = minf(minf(node.x - bounds.position.x, bounds.end.x - node.x), minf(node.z - bounds.position.y, bounds.end.y - node.z))
		var by_void: bool = near_void.has(Vector2i(roundi(node.x * 2.0), roundi(node.z * 2.0)))
		if edge_distance > 7.0 and not by_void: continue
		if edge_distance <= 7.0 and fposmod(node.x + node.z, 4.0) > 0.5 and not by_void: continue
		var outward: Vector2 = Vector2.ZERO
		if edge_distance <= 7.0:
			if node.x - bounds.position.x == edge_distance: outward = Vector2(-1, 0)
			elif bounds.end.x - node.x == edge_distance: outward = Vector2(1, 0)
			elif node.z - bounds.position.y == edge_distance: outward = Vector2(0, -1)
			else: outward = Vector2(0, 1)
		else:
			outward = (Vector2(node.x, node.z) - center).normalized()
		for spread: float in [-0.6, 0.0, 0.6]:
			var direction: Vector2 = outward.rotated(spread)
			for mode: String in ["course", "saut"]:
				starts.append({"node": node, "direction": Vector3(direction.x, 0, direction.y), "mode": mode})
	var bodies: Array[CharacterBody3D] = []
	for start: Dictionary in starts:
		var body: CharacterBody3D = CharacterBody3D.new()
		body.collision_layer = 0
		body.collision_mask = ACTOR_MASK
		body.floor_snap_length = 0.55
		body.floor_max_angle = deg_to_rad(48.0)
		var shape: CollisionShape3D = CollisionShape3D.new()
		var capsule: CapsuleShape3D = CapsuleShape3D.new()
		capsule.radius = CAPSULE_RADIUS
		capsule.height = CAPSULE_HEIGHT
		shape.shape = capsule
		shape.position.y = CAPSULE_HEIGHT * 0.5 + 0.01
		body.add_child(shape)
		school.add_child(body)
		body.global_position = start.node + Vector3.UP * 0.05
		bodies.append(body)
	var speed_for: Dictionary = {"course": 21.0, "saut": 12.2}
	for frame: int in range(240):
		await get_tree().physics_frame
		var delta: float = 1.0 / 60.0
		for index: int in range(bodies.size()):
			var body: CharacterBody3D = bodies[index]
			var start: Dictionary = starts[index]
			var speed: float = float(speed_for[start.mode])
			body.velocity.x = start.direction.x * speed
			body.velocity.z = start.direction.z * speed
			if body.is_on_floor():
				body.velocity.y = PaperRules.OM_JUMP_VELOCITY if start.mode == "saut" else -0.2
			else:
				body.velocity.y -= PaperRules.OM_GRAVITY * delta
			body.move_and_slide()
	var failures: int = 0
	var reported: Dictionary = {}
	for index: int in range(bodies.size()):
		var body: CharacterBody3D = bodies[index]
		var p: Vector3 = body.global_position
		var start: Dictionary = starts[index]
		var floor_y: float = _floor_below(p + Vector3.UP * 0.3, 0.5)
		var outside: bool = not bounds.grow(-0.2).has_point(Vector2(p.x, p.z))
		var fell: bool = p.y < start.node.y - 6.0 or floor_y == -INF or p.y < floor_y - 1.0
		if outside or fell:
			failures += 1
			var bucket: Vector2i = Vector2i(floori(p.x / 6.0), floori(p.z / 6.0))
			if not reported.has(bucket):
				reported[bucket] = true
				_finding("chute", start.node, "%s vers %s : fini en %s (%s)" % [start.mode, _v(start.direction), _v(p), "hors limites" if outside else "tombé"])
		body.queue_free()
	print("AUDIT_FALL ", layout.school.map_id, " essais ", starts.size(), " échecs ", failures)
