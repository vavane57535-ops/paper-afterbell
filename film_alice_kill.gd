class_name PaperFilmAliceKill
extends Node

# Films « Alice · X rattrapé(e) » (ending_killer, 0.17) : une fuite, une chute,
# une défense propre à chaque élève, puis la mise à mort, montrée ou laissée
# hors champ. Tous les corps suivent des clips écrits pour ces plans
# (anim_set_film_alice.gd) : pendant le film, ce nœud coupe l'attente du jeu
# (transferts de poids, regards au hasard, gestes d'attente) et la démarche
# (acteurs « en l'air » pour le moteur : pas de pas comptés par la vitesse).
# Tout est rendu quand le film s'arrête (le nœud est retiré par PaperCinema.stop).
# Les objets (chocolat, fusil, grenade, drone…) sont posés image par image dans
# _process, après la mise à jour du film.
# Même film chez tous les joueurs : tout est déterministe, rien n'est tiré au sort.
# L'épilogue d'exécution (film_execution_end.gd) se sert du même nœud pour tenir Alice.

const FA = preload("res://anim_set_film_alice.gd")
const CharProps = preload("res://char_props.gd")
const CharMaterials = preload("res://char_materials.gd")

const FILM_STYLE: Dictionary = {"contra": 0.0, "shift_rate": 0.0, "idle_sway": 0.0, "idle_bounce": 0.0, "look_rate": 0.0}
# bruitages des exécutions (audio/sfx/kill_*.wav), ajoutés à la banque au besoin (comme kill_scenes.gd)
const KILL_SFX: Dictionary = {"kill_punch": 2, "kill_stab": 2, "kill_clang": 2, "kill_rip": 2, "kill_zap": 2, "kill_beep": 1, "kill_boom": 1, "kill_crunch": 2, "kill_slam": 2}
const INK: Color = Color("ff5a78")
const PAPER: Color = Color("fff6e4")

var film: PaperCinema
var _saved: Array = []
# objets du film : {"node": Node3D, "track": [[t, mode, data], ...]}
var _items: Array = []


static func duration_for(person: String) -> float:
	return float(FA.LENGTH.get(person, 12.0))


# Nœud qui tient les corps du film (sans démarche ni attente du jeu) jusqu'à son arrêt.
static func hold(cinema: PaperCinema) -> PaperFilmAliceKill:
	var node: PaperFilmAliceKill = PaperFilmAliceKill.new()
	node.name = "AliceFilm"
	node.process_priority = 100
	cinema.add_child(node)
	node.film = cinema
	node.hold_bodies()
	node._ensure_sfx()
	return node


static func write(cinema: PaperCinema) -> PaperFilmAliceKill:
	var node: PaperFilmAliceKill = hold(cinema)
	match str(cinema.people[0]) if not cinema.people.is_empty() else "Bleuette":
		"Simon": node._simon()
		_: node._bleuette()
	return node


# ------------------------------------------------------------------- CORPS --

func hold_bodies() -> void :
	_saved.clear()
	for take: Variant in film.takes:
		var visual: PaperVisual = take.visual
		var style: Variant = visual.get("_style")
		var saved: Dictionary = {}
		if style is Dictionary:
			for key: String in FILM_STYLE:
				saved[key] = (style as Dictionary).get(key)
				(style as Dictionary)[key] = FILM_STYLE[key]
		_saved.append([visual, saved, visual.fidgets])
		visual.fidgets = false
	for i: int in range(film.takes.size()): film._do(i, 0.0, "state", {"grounded": false})


func _exit_tree() -> void :
	for entry: Array in _saved:
		var visual: Variant = entry[0]
		if not is_instance_valid(visual): continue
		var style: Variant = (visual as PaperVisual).get("_style")
		if style is Dictionary:
			for key: Variant in (entry[1] as Dictionary):
				if entry[1][key] == null: (style as Dictionary).erase(key)
				else: (style as Dictionary)[key] = entry[1][key]
		(visual as PaperVisual).fidgets = bool(entry[2])
	_saved.clear()


func _ensure_sfx() -> void :
	var audio: Variant = film.world.get("audio") if film.world else null
	if audio == null: return
	var bank: Variant = audio.get("effects")
	if not bank is Dictionary or bool(audio.get("_silent")): return
	for kind: String in KILL_SFX:
		if (bank as Dictionary).has(kind): continue
		var variants: Array[AudioStream] = []
		for index: int in range(int(KILL_SFX[kind])):
			var path: String = "res://audio/sfx/%s_%02d.wav" % [kind, index]
			if ResourceLoader.exists(path):
				var stream: AudioStream = load(path) as AudioStream
				if stream: variants.append(stream)
		(bank as Dictionary)[kind] = variants


# Programme d'orientation écrit (anim_set_film_alice.gd, facing_at) donné tel quel au film.
func facing(i: int, schedule: Array) -> void :
	for entry: Array in schedule: film._face(i, float(entry[0]), "dir", entry[1])


# Un trajet écrit (anim_set_film_alice.gd) donné tel quel au corps : segments linéaires.
func path(i: int, points: Array) -> void :
	film._put(i, points[0][1])
	for k: int in range(1, points.size()):
		film._move(i, float(points[k - 1][0]), float(points[k][0]), points[k][1], "linear")


# ------------------------------------------------------------------ OBJETS --
# Piste d'un objet : [t, "off"] caché ; [t, "floor", Vector3 (film), lacet] posé au
# sol ; [t, "fly", de, vers, durée, hauteur d'arc, tours] lancé (de / vers : Vector3
# du film ou {"a": acteur, "s": prise}) ; [t, "fall", Vector3 sol, durée] tombe de
# la dernière position jusqu'au sol ; [t, "slide", de, vers, durée, lacet] glisse au sol ;
# [t, "hold", acteur, "r"|"l", décalage, rotation] dans une main ; [t, "grip", acteur, main
# arrière, main avant, recul] à deux mains ; [t, "point", acteur, main, cible, recul] pointé.

func item(node: Node3D, track: Array) -> void :
	add_child(node)
	node.visible = false
	track.sort_custom( func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	_items.append({"node": node, "track": track, "last": Vector3.ZERO})


func prop_mesh(prop_name: String, size: float = 1.0) -> Node3D:
	var root: Node3D = Node3D.new()
	var info: Dictionary = CharProps.prop(prop_name)
	if info.is_empty(): return root
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh = info.mesh
	mesh.scale = Vector3.ONE * size
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mesh)
	return root


# boîte colorée (objets du film), centrée en `at`, tournée de `turn` (radians, euler)
func box(root: Node3D, size: Vector3, color: Color, at: Vector3 = Vector3.ZERO, turn: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = CharMaterials.flat(color)
	node.position = at
	node.rotation = turn
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(node)
	return node


# Tablette de chocolat lisible à l'écran : papier bleu à bande blanche, un bout déballé où
# l'on voit les carrés. Longueur sur x (13 cm), épaisseur sur y.
func bar_mesh() -> Node3D:
	var root: Node3D = Node3D.new()
	box(root, Vector3(0.085, 0.016, 0.062), Color("4d7fd1"), Vector3(-0.022, 0.0, 0.0))
	box(root, Vector3(0.086, 0.017, 0.016), Color("f4f1ea"), Vector3(-0.022, 0.0, 0.0))
	box(root, Vector3(0.05, 0.012, 0.058), Color("5a2c1d"), Vector3(0.045, 0.0, 0.0))
	for i: int in range(2):
		for j: int in range(2):
			box(root, Vector3(0.021, 0.006, 0.025), Color("6e3a26"), Vector3(0.033 + 0.024 * float(i), 0.008, -0.014 + 0.028 * float(j)))
	box(root, Vector3(0.012, 0.02, 0.066), Color("c9c3cf"), Vector3(0.018, 0.0, 0.0))
	return root


func _process(_delta: float) -> void :
	if film == null or film.kind.is_empty(): return
	var t: float = film.elapsed
	for entry: Dictionary in _items: _place(entry, t)


# lacet (monde) d'un objet tourné de `local` radians par rapport à l'axe du film
func _yaw(local: float) -> float:
	return atan2( - film.forward.x, - film.forward.z) + local


func _place(entry: Dictionary, t: float) -> void :
	var node: Node3D = entry.node
	var track: Array = entry.track
	var index: int = -1
	for k: int in range(track.size()):
		if float(track[k][0]) <= t: index = k
	if index < 0:
		node.visible = false
		return
	var step: Array = track[index]
	var start: float = float(step[0])
	match str(step[1]):
		"off":
			node.visible = false
		"floor":
			node.visible = true
			node.global_position = film._world_spot(step[2])
			node.global_basis = Basis(Vector3.UP, _yaw(float(step[3]))) * Basis(Vector3.RIGHT, PI * 0.5)
		"slide":
			node.visible = true
			var u: float = clampf((t - start) / maxf(0.01, float(step[4])), 0.0, 1.0)
			var eased: float = 1.0 - (1.0 - u) * (1.0 - u)
			node.global_position = film._world_spot((step[2] as Vector3).lerp(step[3], eased))
			node.global_basis = Basis(Vector3.UP, _yaw(float(step[5]) * (0.4 + 0.6 * eased))) * Basis(Vector3.RIGHT, PI * 0.5)
		"fly":
			node.visible = true
			var u: float = clampf((t - start) / maxf(0.01, float(step[4])), 0.0, 1.0)
			var from: Vector3 = film._spot(step[2])
			var to: Vector3 = film._spot(step[3])
			node.global_position = from.lerp(to, u) + Vector3.UP * sin(u * PI) * float(step[5])
			node.global_basis = Basis(film.right, u * TAU * float(step[6])) * Basis(Vector3.UP, _yaw(0.0))
		"fall":
			node.visible = true
			var u: float = clampf((t - start) / maxf(0.01, float(step[3])), 0.0, 1.0)
			var from: Vector3 = entry.get("last", node.global_position)
			var to: Vector3 = film._world_spot(step[2])
			node.global_position = from.lerp(to, u * u)
		"hold":
			# tenu dans une main : [t, "hold", acteur, "r" | "l", décalage (repère de la main), rotation]
			var visual: PaperVisual = film.takes[clampi(int(step[2]), 0, film.takes.size() - 1)].visual
			var hand: Variant = visual.get("_right_hand" if str(step[3]) == "r" else "_left_hand")
			if not hand is Node3D:
				node.visible = false
				return
			var frame: Transform3D = (hand as Node3D).global_transform.orthonormalized()
			node.global_transform = frame * Transform3D(Basis.from_euler(step[5] if step.size() > 5 else Vector3.ZERO), step[4] if step.size() > 4 else Vector3.ZERO)
			node.visible = visual.visible
		"grip":
			# tenu à deux mains : [t, "grip", acteur, main arrière, main avant, recul (m)] ; l'objet
			# (axe -z vers l'avant) va de la main arrière vers la main avant
			var visual: PaperVisual = film.takes[clampi(int(step[2]), 0, film.takes.size() - 1)].visual
			var rear: Vector3 = visual.socket_position("hand_r" if str(step[3]) == "r" else "hand_l")
			var front: Vector3 = visual.socket_position("hand_r" if str(step[4]) == "r" else "hand_l")
			var axis: Vector3 = front - rear
			if axis.length_squared() < 0.0004: axis = film.forward
			var basis: Basis = Basis.looking_at(axis.normalized(), Vector3.UP if absf(axis.normalized().y) < 0.95 else film.forward)
			node.global_transform = Transform3D(basis, rear - axis.normalized() * float(step[5] if step.size() > 5 else 0.0))
			node.visible = visual.visible
		"point":
			# tenu d'une main et pointé : [t, "point", acteur, main, cible (spot du film), recul (m)]
			var visual: PaperVisual = film.takes[clampi(int(step[2]), 0, film.takes.size() - 1)].visual
			var at: Vector3 = visual.socket_position("hand_r" if str(step[3]) == "r" else "hand_l")
			var axis: Vector3 = film._spot(step[4]) - at
			if axis.length_squared() < 0.0004: axis = film.forward
			var basis: Basis = Basis.looking_at(axis.normalized(), Vector3.UP if absf(axis.normalized().y) < 0.95 else film.forward)
			node.global_transform = Transform3D(basis, at - axis.normalized() * float(step[5] if step.size() > 5 else 0.0))
			node.visible = visual.visible
	if str(step[1]) != "fall": entry["last"] = node.global_position


# ----------------------------------------------------------------- BLEUETTE --

func _bleuette() -> void :
	var c: PaperCinema = film
	var s: int = 0
	var a: int = c.alice_index
	path(s, FA.bleuette_path())
	path(a, FA.bleuette_alice_path())
	c._face(s, 0.0, "dir", Vector3(0, 0, 1))
	c._face(s, FA.B_FLIP, "dir", Vector3(0, 0, -1))
	c._face(a, 0.0, "dir", Vector3(0.04, 0, 1))
	c._do(s, 0.0, "play", "fa_bleuette")
	c._do(a, 0.0, "play", "fa_bleuette_alice")

	# 1 · elle court vers nous en serrant sa barre ; Alice, loin derrière, dans le noir
	c._shot(0.0, {"rel": {"a": s}, "eye": [Vector3(1.05, 0.62, 3.6), Vector3(0.9, 0.6, 3.1)], "look": {"a": s, "h": 0.75, "o": Vector3(-0.3, 0, -1.3)}, "fov": [42, 40], "hand": 0.5})
	# 2 · de profil, au ras du sol : le pied accroche, elle s'étale
	c._shot(1.62, {"eye": Vector3(2.5, 0.5, 3.9), "look": [Vector3(0.37, 0.45, 4.0), Vector3(0.37, 0.25, 4.6)], "fov": [42, 40], "hand": 0.3})
	c._cue(FA.B_TRIP, "sound", "step", {"a": s}, 0.9, 0.7)
	c._cue(FA.B_TRIP + 0.44, "sound", "ground_impact", {"a": s}, 0.5, 1.3)
	c._cue(FA.B_TRIP + 0.62, "sound", "ground_impact", {"a": s}, 0.75, 1.1)
	c._cue(FA.B_TRIP + 0.62, "shake", 0.22)
	# 3 · au sol, face à elle : la barre au premier plan ; elle relève la tête et tend la main
	c._shot(2.75, {"eye": [Vector3(-0.45, 0.17, 7.65), Vector3(-0.42, 0.18, 7.5)], "look": [Vector3(0.32, 0.16, 5.45), Vector3(0.32, 0.2, 5.5)], "fov": 34, "hand": 0.2})
	# 4 · elle reprend la barre… les pas d'Alice ; elle regarde derrière elle
	c._shot(3.95, {"eye": [Vector3(-1.65, 0.5, 6.85), Vector3(-1.6, 0.52, 6.75)], "look": [Vector3(0.3, 0.42, 4.6), Vector3(0.28, 0.5, 4.2)], "fov": 42, "hand": 0.3})
	c._cue(4.0, "sound", "step", {"a": a}, 1.2, 0.8)
	c._cue(4.15, "sound", "presence", {"a": a}, 0.6, 0.85)
	c._cue(4.45, "sweat", {"a": s, "s": "head"}, 3)
	# 5 · ce qu'elle voit : Alice qui arrive, immense, et s'arrête au-dessus d'elle
	c._shot(4.95, {"eye": [Vector3(0.37, 0.42, 5.4), Vector3(0.37, 0.7, 5.05)], "look": [{"a": a, "h": 1.42}, {"a": a, "h": 1.5}], "fov": [48, 40], "hand": 0.6})
	c._do(s, 4.95, "show", false)
	c._do(s, 6.05, "show", true)
	# 6 · de profil : à genoux, elle lui tend la barre à deux mains, tête baissée
	c._shot(6.05, {"eye": [Vector3(3.7, 1.05, 4.5), Vector3(3.4, 1.05, 4.5)], "look": Vector3(0.33, 1.0, 4.5), "fov": [42, 40], "hand": 0.25})
	c._cue(FA.B_TAKE, "sound", "grab", {"a": a, "s": "hand_r"}, 0.45, 1.3)
	# 7 · Alice regarde la barre de près
	c._shot(7.65, {"eye": [Vector3(1.05, 1.0, 5.15), Vector3(0.95, 1.05, 5.05)], "look": [{"a": a, "h": 1.35}, {"a": a, "h": 1.45}], "fov": [36, 34], "hand": 0.25})
	# 8 · en plongée : la petite à genoux, Alice penchée sur elle, la griffe levée
	c._shot(8.65, {"eye": [Vector3(2.3, 2.55, 6.35), Vector3(2.2, 2.6, 6.2)], "look": [Vector3(0.33, 0.75, 4.55), Vector3(0.33, 0.85, 4.5)], "fov": [40, 38], "hand": 0.3})
	c._cue(8.9, "sound", "presence", {"a": a}, 0.7, 0.75)
	# mise à mort hors champ : noir
	var kill: float = FA.B_KILL
	c._blackouts.append([kill, kill + 0.12])
	c._cue(kill, "sound", "slash", {"a": s}, 0.8, 0.85)
	c._cue(kill + 0.02, "sound", "kill_stab", {"a": s}, 1.0, 0.9)
	c._cue(kill + 0.12, "frame", Color(0.55, 0.0, 0.08, 0.3), 0.12)
	c._cue(kill + 0.12, "splash", 1.1)
	c._cue(kill + 0.02, "shake", 0.45)
	c._cue(kill + 0.4, "sound", "ground_impact", {"a": s}, 0.4, 0.8)
	# 9 · Alice seule croque dans la barre en nous regardant
	c._shot(kill + 0.12, {"eye": [Vector3(0.55, 1.05, 6.05), Vector3(0.42, 1.22, 5.55)], "look": [{"a": a, "h": 1.32}, {"a": a, "h": 1.46}], "fov": [36, 28], "hand": 0.25, "roll": [0, -2]})
	c._cue(FA.B_BITE, "sound", "kill_crunch", {"a": a, "s": "head"}, 0.35, 1.4)
	c._cue(11.3, "sound", "presence", {"a": a}, 0.5, 0.7)

	# la barre : dans la main droite, s'échappe à la chute, glisse, reprise, puis donnée à Alice
	var bar: Node3D = bar_mesh()
	var grip: Vector3 = Vector3(0.0, -0.075, -0.035)
	item(bar, [
		[0.0, "hold", s, "r", grip, Vector3.ZERO],
		[FA.B_DROP, "fly", {"a": s, "s": "hand_r"}, Vector3(0.27, 0.02, 5.6), 0.32, 0.25, 1.5],
		[FA.B_DROP + 0.32, "slide", Vector3(0.27, 0.02, 5.6), Vector3(0.24, 0.02, 5.86), 0.4, 0.7],
		[FA.B_GRAB, "hold", s, "r", grip, Vector3.ZERO],
		[FA.B_TAKE, "hold", a, "r", Vector3(0.0, -0.08, -0.02), Vector3(0.0, 0.0, 0.3)],
	])


# anneau de goupille (lisible de près : un peu plus gros que le vrai)
func ring_mesh() -> Node3D:
	var root: Node3D = Node3D.new()
	var mesh: TorusMesh = TorusMesh.new()
	mesh.inner_radius = 0.016
	mesh.outer_radius = 0.025
	mesh.rings = 12
	mesh.ring_segments = 6
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = CharMaterials.flat(Color("f1f4f8"))
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# couché à plat quand l'objet est « au sol » (la piste tourne les objets posés d'un quart de tour)
	node.rotation.x = - PI * 0.5
	root.add_child(node)
	return root


# ------------------------------------------------------------------- SIMON --

func _simon() -> void :
	var c: PaperCinema = film
	var s: int = 0
	var a: int = c.alice_index
	path(s, FA.simon_path())
	path(a, FA.simon_alice_path())
	c._face(s, 0.0, "dir", Vector3(0, 0, 1))
	c._face(a, 0.0, "dir", Vector3(0.02, 0, 1))
	c._face(a, 1.0, "dir", Vector3(0, 0, -1))
	c._face(a, 6.4, "dir", Vector3(0, 0, 1))
	c._do(s, 0.0, "play", "fa_simon")
	c._do(a, 0.0, "play", "fa_simon_alice")

	# 1 · face à lui, au ras du sol : la Course éclair ; derrière, Alice immobile dans le noir
	c._shot(0.0, {"rel": {"a": s}, "eye": [Vector3(1.75, 0.62, 2.0), Vector3(1.55, 0.6, 1.7)], "look": {"a": s, "h": 0.85, "o": Vector3(0, 0, -0.6)}, "fov": [44, 40], "hand": 0.5})
	c._cue(0.05, "rush", 0.5)
	c._cue(0.0, "sound", "boost", {"a": s}, 0.6, 1.1)
	c._cue(0.93, "sound", "shadow", {"a": a}, 0.8, 0.9)
	c._do(a, 0.98, "show", false)
	# 2 · de profil : elle est devant lui ; il freine, ses pieds partent, il tombe à ses pieds
	c._do(a, FA.S_SEEN, "show", true)
	c._cue(FA.S_SEEN, "sound", "shadow", {"a": a}, 1.0, 0.8)
	c._cue(FA.S_SEEN + 0.05, "sound", "presence", {"a": a}, 0.7, 0.9)
	c._shot(FA.S_SEEN + 0.04, {"eye": Vector3(3.3, 0.95, 4.2), "look": [Vector3(0.25, 0.85, 4.35), Vector3(0.25, 0.75, 4.6)], "fov": 42, "hand": 0.3})
	c._cue(FA.S_BRAKE, "sound", "step", {"a": s}, 1.0, 0.7)
	c._cue(1.5, "sound", "step", {"a": s}, 0.9, 0.65)
	c._cue(FA.S_SIT, "sound", "ground_impact", {"a": s}, 0.8, 1.1)
	c._cue(FA.S_SIT, "shake", 0.25)
	# 3 · au ras du sol, à côté de lui : il recule sur les mains, elle avance, immense
	c._shot(2.4, {"eye": [Vector3(2.0, 0.5, 3.25), Vector3(1.9, 0.52, 3.1)], "look": [Vector3(0.24, 0.85, 4.75), Vector3(0.24, 0.9, 4.6)], "fov": [42, 40], "hand": 0.3})
	for t: float in [2.7, 3.22, 3.74]: c._cue(t, "sound", "step", {"a": s}, 0.5, 0.8)
	# 4 · de près : la flashbang, la goupille aux dents
	c._shot(3.95, {"eye": [Vector3(-0.4, 0.9, 4.75), Vector3(-0.34, 0.88, 4.65)], "look": [Vector3(0.18, 0.72, 4.0), Vector3(0.18, 0.75, 4.0)], "fov": [38, 36], "hand": 0.35})
	c._cue(FA.S_GRAB, "sound", "grab", {"a": s, "s": "hand_r"}, 0.5, 1.2)
	c._cue(FA.S_PIN, "sound", "camera_place", {"a": s, "s": "head"}, 0.6, 1.7)
	c._cue(FA.S_CATCH, "sound", "camera_place", {"a": a, "s": "hand_r"}, 0.35, 2.0)
	# 5 · le lancer, de profil
	c._shot(FA.S_THROW - 0.12, {"eye": Vector3(3.0, 1.15, 4.4), "look": Vector3(0.24, 0.95, 4.55), "fov": 44, "hand": 0.25})
	c._cue(FA.S_THROW, "sound", "grenade_throw", {"a": s, "s": "hand_r"}, 0.9, 1.0)
	# flash
	var burst: Vector3 = Vector3(0.2, 1.05, 4.86)
	c._cue(FA.S_FLASH, "event", "grenade", {"action": "explode", "id": -7, "position": burst})
	c._cue(FA.S_FLASH, "sound", "flash", burst, 1.0, 1.0)
	c._cue(FA.S_FLASH, "frame", Color(1.0, 1.0, 0.96, 0.95), 0.16)
	c._cue(FA.S_FLASH, "pulse", Color(1.0, 0.98, 0.9, 0.85), 1.1)
	c._cue(FA.S_FLASH, "impact", 0.7, false)
	c._cue(FA.S_FLASH, "shake", 0.4)
	c._do(a, FA.S_FLASH + 0.02, "show", false)
	# 6 · plus large : il est seul au milieu du couloir, la fumée retombe
	c._shot(FA.S_FLASH + 0.05, {"eye": [Vector3(1.75, 1.3, 6.1), Vector3(1.65, 1.25, 5.95)], "look": Vector3(0.26, 0.55, 4.25), "fov": 44, "hand": 0.35})
	# 7 · de trois quarts : il souffle, il rit… derrière lui, elle sort du noir ; la griffe sur l'épaule
	c._shot(6.98, {"eye": [Vector3(0.95, 0.85, 5.7), Vector3(0.85, 0.86, 5.55)], "look": [Vector3(0.25, 0.85, 3.85), Vector3(0.25, 0.9, 3.85)], "fov": [42, 38], "hand": 0.3})
	c._do(a, FA.S_BACK, "show", true)
	c._cue(FA.S_BACK, "sound", "shadow", {"a": a}, 0.5, 0.75)
	c._cue(FA.S_TOUCH, "sound", "grab", {"a": s, "s": "head"}, 0.35, 0.8)
	c._cue(FA.S_TOUCH + 0.1, "sound", "presence", {"a": a}, 0.6, 0.8)
	# 8 · de profil, tout près : il lève la tête vers elle, penchée au-dessus de lui
	c._shot(8.2, {"eye": [Vector3(0.8, 0.55, 4.95), Vector3(0.76, 0.56, 4.82)], "look": [Vector3(0.25, 0.9, 3.9), Vector3(0.25, 0.92, 3.88)], "fov": [40, 37], "hand": 0.25})
	c._cue(8.3, "sweat", {"a": s, "s": "head"}, 3)
	# mise à mort : noir
	var kill: float = FA.S_KILL
	c._blackouts.append([kill, kill + 0.45])
	c._cue(kill, "sound", "slash", {"a": s}, 0.9, 0.85)
	c._cue(kill + 0.03, "sound", "kill_stab", {"a": s}, 1.0, 0.95)
	c._cue(kill + 0.02, "shake", 0.5)
	c._cue(kill + 0.45, "frame", Color(0.55, 0.0, 0.08, 0.3), 0.12)
	c._cue(kill + 0.3, "sound", "ground_impact", {"a": s}, 0.35, 0.8)
	# 9 · Alice se redresse derrière lui, la goupille entre deux griffes
	c._shot(kill + 0.45, {"eye": [Vector3(0.05, 1.3, 5.0), Vector3(0.08, 1.32, 4.85)], "look": [{"a": a, "h": 1.3, "o": Vector3(0, 0, 0.15)}, {"a": a, "h": 1.34, "o": Vector3(0, 0, 0.15)}], "fov": [40, 36], "hand": 0.25, "roll": [0, -2]})
	# 10 · au ras du sol : la goupille tombe, rebondit, s'immobilise ; derrière, lui, et ses pieds à elle
	var land: Vector3 = Vector3(-0.28, 0.02, 3.8)
	var hop: Vector3 = Vector3(-0.37, 0.02, 3.92)
	var rest: Vector3 = Vector3(-0.46, 0.02, 4.05)
	c._shot(FA.S_DROP + 0.02, {"eye": [Vector3(-0.86, 0.1, 4.5), Vector3(-0.82, 0.09, 4.46)], "look": [Vector3(-0.32, 0.12, 3.86), Vector3(-0.36, 0.08, 3.92)], "fov": [36, 34], "hand": 0.15})
	c._cue(FA.S_DROP + 0.24, "sound", "camera_place", land, 0.5, 2.1)
	c._cue(FA.S_DROP + 0.41, "sound", "camera_place", hop, 0.3, 2.3)
	c._cue(FA.S_DROP + 0.5, "sound", "grenade_bounce", rest, 0.15, 2.4)
	c._cue(11.3, "sound", "presence", {"a": a}, 0.45, 0.7)

	# la flashbang : dans la main droite, lancée, éclate devant Alice
	var grenade: Node3D = prop_mesh("flash")
	item(grenade, [
		[0.0, "off"],
		[FA.S_GRAB, "hold", s, "r", Vector3(0.0, -0.06, -0.035), Vector3.ZERO],
		[FA.S_THROW, "fly", {"a": s, "s": "hand_r"}, burst, 0.46, 0.3, 2.5],
		[FA.S_FLASH, "off"],
	])
	# la goupille : arrachée aux dents, crachée sur Alice, qui l'attrape au vol et la garde
	var pin: Node3D = ring_mesh()
	item(pin, [
		[0.0, "off"],
		[FA.S_SPIT, "fly", {"a": s, "s": "mouth"}, {"a": a, "s": "hand_r"}, FA.S_CATCH - FA.S_SPIT, 0.12, 2.0],
		[FA.S_CATCH, "hold", a, "r", Vector3(0.0, 0.13, 0.0), Vector3(0.0, 0.0, 0.0)],
		[FA.S_DROP, "fall", land, 0.24],
		[FA.S_DROP + 0.24, "fly", land, hop, 0.17, 0.05, 0.5],
		[FA.S_DROP + 0.41, "slide", hop, rest, 0.4, 1.4],
		[FA.S_DROP + 0.81, "floor", rest, 1.4],
	])
