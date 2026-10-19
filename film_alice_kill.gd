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


# Un trajet écrit (anim_set_film_alice.gd) donné tel quel au corps : segments linéaires.
func path(i: int, points: Array) -> void :
	film._put(i, points[0][1])
	for k: int in range(1, points.size()):
		film._move(i, float(points[k - 1][0]), float(points[k][0]), points[k][1], "linear")


# ------------------------------------------------------------------ OBJETS --
# Piste d'un objet : [t, "off"] caché ; [t, "floor", Vector3 (film), lacet] posé au
# sol ; [t, "fly", de, vers, durée, hauteur d'arc, tours] lancé (de / vers : Vector3
# du film ou {"a": acteur, "s": prise}) ; [t, "fall", Vector3 sol, durée] tombe de
# la dernière position jusqu'au sol ; [t, "slide", de, vers, durée, lacet] glisse au sol.

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
	if str(step[1]) != "fall": entry["last"] = node.global_position


# ----------------------------------------------------------------- BLEUETTE --

func _bleuette() -> void :
	pass
