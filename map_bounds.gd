extends RefCounted

# Bords des cartes (0.17, lot « cartes »).
# - Forêt et neige : le sol jouable s'arrêtait 1 m avant les anciens murs du pourtour. Dans cette fente,
#   joueurs, bots et Alice tombaient sous la carte (et passaient sous les murs). Des murs invisibles
#   (collision seule, couche 1 comme le décor) sont maintenant collés au bord du sol, de 6 m sous la dalle
#   à 30 m de haut : rien ne passe dessous, rien ne saute par-dessus.
# - Un sol de décor (sans collision) prolonge le terrain au-delà, pour que les rochers et les arbres du
#   pourtour reposent sur quelque chose au lieu de flotter au-dessus du vide ; à l'école, il entoure le
#   parvis (pelouse, trottoir, rue) qui donnait sur le vide.
# - Garde-fou, chez l'hôte : un acteur vivant qui passerait quand même sous la carte ou hors des limites
#   est reposé sur le nœud du graphe des bots le plus proche.
# Les sorties et la place où courent les élèves pendant les films ne sont pas touchées.

const SLAB_BOTTOM: float = -6.0
const WALL_TOP: float = 30.0
const WALL: float = 2.0
const REACH: float = 170.0

var L: RefCounted
var S: Node3D

func build(layout: RefCounted) -> void :
	L = layout
	S = layout.school
	match S.map_id:
		"forest":
			_edge_walls(Rect2(-74, -70, 148, 134))
			_skirt([[Rect2(-REACH, -REACH, REACH * 2.0, REACH - 70.0), 4.0], [Rect2(-REACH, -70, REACH - 74.0, 26), 4.0], [Rect2(74, -70, REACH - 74.0, 26), 4.0],
				[Rect2(-REACH, -44, REACH - 74.0, REACH + 44.0), 0.0], [Rect2(74, -44, REACH - 74.0, REACH + 44.0), 0.0], [Rect2(-74, 64, 148, REACH - 64.0), 0.0]])
		"snow":
			_edge_walls(Rect2(-70, -68, 140, 128))
			_skirt([[Rect2(-REACH, -REACH, REACH * 2.0, REACH - 68.0), 5.0], [Rect2(-REACH, -68, REACH - 70.0, 30), 5.0], [Rect2(70, -68, REACH - 70.0, 30), 5.0],
				[Rect2(-REACH, -38, REACH - 70.0, REACH + 38.0), 0.0], [Rect2(70, -38, REACH - 70.0, REACH + 38.0), 0.0], [Rect2(-70, 60, 140, REACH - 60.0), 0.0]])
		_:
			_school_grounds()
	var guard: FallGuard = FallGuard.new()
	guard.name = "Garde-fou des bords"
	guard.school = S
	guard.bounds = L.bounds
	S.add_child(guard)

# Murs invisibles juste à l'extérieur du rectangle jouable (leur face intérieure suit le bord du sol).
func _edge_walls(rect: Rect2) -> void :
	var height: float = WALL_TOP - SLAB_BOTTOM
	var mid: float = (WALL_TOP + SLAB_BOTTOM) * 0.5
	var span_x: float = rect.size.x + WALL * 2.0
	var span_z: float = rect.size.y + WALL * 2.0
	for wall: Array in [[Vector3(rect.position.x - WALL * 0.5, mid, rect.get_center().y), Vector3(WALL, height, span_z)], [Vector3(rect.end.x + WALL * 0.5, mid, rect.get_center().y), Vector3(WALL, height, span_z)],
		[Vector3(rect.get_center().x, mid, rect.position.y - WALL * 0.5), Vector3(span_x, height, WALL)], [Vector3(rect.get_center().x, mid, rect.end.y + WALL * 0.5), Vector3(span_x, height, WALL)]]:
		var body: StaticBody3D = StaticBody3D.new()
		body.name = "Mur invisible"
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = wall[0]
		var shape: CollisionShape3D = CollisionShape3D.new()
		var box: BoxShape3D = BoxShape3D.new()
		box.size = wall[1]
		shape.shape = box
		body.add_child(shape)
		S.add_child(body)
		S.collision_audit.append({"kind": "edge_wall", "position": wall[0], "size": wall[1]})

# Sol de décor autour de la zone jouable : bloc de pierre pour les parties hautes (comme les plateaux),
# dalle de terrain pour le reste. Ni collision ni ombre ; une seule pièce par bloc (pas de découpe).
func _skirt(regions: Array) -> void :
	for region: Array in regions:
		var rect: Rect2 = region[0]
		var height: float = region[1]
		var center: Vector2 = rect.get_center()
		if height > 0.0:
			_ground_piece(Vector3(rect.size.x, height + 0.7, rect.size.y), Vector3(center.x, (height - 0.7) * 0.5, center.y), L._stone)
			_ground_piece(Vector3(rect.size.x, 0.012, rect.size.y), Vector3(center.x, height + 0.009, center.y), L._ground_material)
		else:
			_ground_piece(Vector3(rect.size.x, 0.7, rect.size.y), Vector3(center.x, -0.35, center.y), L._ground_material)

func _ground_piece(size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var piece: MeshInstance3D = L._box(size, pos, material, false)
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	piece.set_meta("paper_unbatched", true)
	return piece

# École : le parvis donnait sur le vide derrière les haies et la grille. Pelouse autour du bâtiment,
# trottoir devant la grille et une rue (sans collision : on ne peut pas y aller).
func _school_grounds() -> void :
	var grass: StandardMaterial3D = S._mat(Color("2b3a30"))
	S._finish(grass, "stone", 0.92, Vector3(5, 5, 5))
	for rect: Rect2 in [Rect2(-REACH, 42.25, REACH - 14.0, REACH - 42.25), Rect2(14, 42.25, REACH - 14.0, REACH - 42.25), Rect2(-14, 58.25, 28, REACH - 58.25),
		Rect2(-REACH, -REACH, REACH - 54.25, REACH + 42.25), Rect2(54.25, -REACH, REACH - 54.25, REACH + 42.25), Rect2(-54.25, -REACH, 108.5, REACH - 42.25)]:
		_ground_piece(Vector3(rect.size.x, 0.6, rect.size.y), Vector3(rect.get_center().x, -0.3, rect.get_center().y), grass)
	var paving: StandardMaterial3D = S._mat(Color("777a82"))
	S._finish(paving, "stone", 0.85, Vector3(4, 4, 4))
	var asphalt: StandardMaterial3D = S._mat(Color("2c2e36"))
	S._finish(asphalt, "stone", 0.9, Vector3(4, 4, 4))
	_ground_piece(Vector3(84, 0.02, 3.4), Vector3(0, 0.01, 59.95), paving)
	_ground_piece(Vector3(REACH * 2.0, 0.02, 8.0), Vector3(0, 0.012, 65.65), asphalt)
	var line: StandardMaterial3D = S._mat(Color("d6cfb8"))
	for x: int in range(-60, 61, 6):
		L._box(Vector3(3.0, 0.012, 0.18), Vector3(x, 0.028, 65.65), line, false)


# Garde-fou (hôte seulement) : vérifie quatre fois par seconde qu'aucun acteur vivant n'est sous la carte
# ou hors des limites ; sinon il le repose sur le graphe des bots. Avec les murs, il ne devrait jamais servir.
class FallGuard extends Node:
	var school: Node3D
	var bounds: Rect2
	var _clock: float = 0.0

	func _physics_process(delta: float) -> void :
		_clock += delta
		if _clock < 0.25: return
		_clock = 0.0
		var world: Node = school.get_parent() if is_instance_valid(school) else null
		if world == null or not ("actors" in world) or str(world.get("phase")) != "playing": return
		if world.has_method("authoritative") and not world.authoritative(): return
		var layout: Variant = school.get("om_layout")
		if layout == null or layout.graph.get_point_count() == 0: return
		for actor: Variant in world.actors.values():
			if not is_instance_valid(actor) or not actor.alive or bool(actor.effects.get("escaped", false)): continue
			var p: Vector3 = actor.global_position
			if p.y > -8.0 and bounds.grow(2.0).has_point(Vector2(p.x, p.z)): continue
			var probe: Vector3 = Vector3(clampf(p.x, bounds.position.x, bounds.end.x), 0.0, clampf(p.z, bounds.position.y, bounds.end.y))
			var safe: Vector3 = layout.graph.get_point_position(layout._closest_point(probe)) + Vector3.UP * 0.1
			actor.global_position = safe
			actor.velocity = Vector3.ZERO
			actor.reset_physics_interpolation()
			print("CARTE_GARDE_FOU ", actor.character, " repêché en ", safe, " (était en ", p, ")")
