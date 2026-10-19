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

const FA = preload("res://anim_set_film_alice.gd")
const CharProps = preload("res://char_props.gd")

const FILM_STYLE: Dictionary = {"contra": 0.0, "shift_rate": 0.0, "idle_sway": 0.0, "idle_bounce": 0.0, "look_rate": 0.0}
# bruitages des exécutions (audio/sfx/kill_*.wav), ajoutés à la banque au besoin (comme kill_scenes.gd)
const KILL_SFX: Dictionary = {"kill_punch": 2, "kill_stab": 2, "kill_clang": 2, "kill_rip": 2, "kill_zap": 2, "kill_beep": 1, "kill_boom": 1, "kill_crunch": 2, "kill_slam": 2}
const INK: Color = Color("ff5a78")

var film: PaperCinema
var _saved: Array = []
# objets du film : {"node": Node3D, "track": [[t, mode, data], ...]}
var _items: Array = []


static func duration_for(person: String) -> float:
	return float(FA.LENGTH.get(person, 12.0))


static func write(cinema: PaperCinema) -> PaperFilmAliceKill:
	var node: PaperFilmAliceKill = PaperFilmAliceKill.new()
	node.name = "AliceFilm"
	node.process_priority = 100
	cinema.add_child(node)
	node.film = cinema
	node.hold_bodies()
	node._ensure_sfx()
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
func _path(i: int, path: Array) -> void :
	film._put(i, path[0][1])
	for k: int in range(1, path.size()):
		film._move(i, float(path[k - 1][0]), float(path[k][0]), path[k][1], "linear")


# ------------------------------------------------------------------ OBJETS --
# Piste d'un objet : [t, "off"] caché ; [t, "floor", Vector3 (film), lacet] posé au
# sol ; [t, "fly", de, vers, durée, hauteur d'arc, tours] lancé (de / vers : Vector3
# du film ou {"a": acteur, "s": prise}) ; [t, "fall", Vector3 sol, durée] tombe de
# la dernière position jusqu'au sol.

func _item(node: Node3D, track: Array) -> void :
	add_child(node)
	node.visible = false
	track.sort_custom( func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	_items.append({"node": node, "track": track, "last": Vector3.ZERO})


func _prop_mesh(prop_name: String, size: float = 1.0) -> Node3D:
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
	for item: Dictionary in _items: _place(item, t)


# lacet (monde) d'un objet tourné de `local` radians par rapport à l'axe du film
func _yaw(local: float) -> float:
	return atan2( - film.forward.x, - film.forward.z) + local


func _place(item: Dictionary, t: float) -> void :
	var node: Node3D = item.node
	var track: Array = item.track
	var index: int = -1
	for k: int in range(track.size()):
		if float(track[k][0]) <= t: index = k
	if index < 0:
		node.visible = false
		return
	var entry: Array = track[index]
	var start: float = float(entry[0])
	match str(entry[1]):
		"off":
			node.visible = false
		"floor":
			node.visible = true
			node.global_position = film._world_spot(entry[2])
			node.global_basis = Basis(Vector3.UP, _yaw(float(entry[3]))) * Basis(Vector3.RIGHT, PI * 0.5)
		"fly":
			node.visible = true
			var u: float = clampf((t - start) / maxf(0.01, float(entry[4])), 0.0, 1.0)
			var from: Vector3 = film._spot(entry[2])
			var to: Vector3 = film._spot(entry[3])
			node.global_position = from.lerp(to, u) + Vector3.UP * sin(u * PI) * float(entry[5])
			node.global_basis = Basis(film.right, u * TAU * float(entry[6])) * Basis(Vector3.UP, _yaw(0.0))
		"fall":
			node.visible = true
			var u: float = clampf((t - start) / maxf(0.01, float(entry[3])), 0.0, 1.0)
			var from: Vector3 = item.get("last", node.global_position)
			var to: Vector3 = film._world_spot(entry[2])
			node.global_position = from.lerp(to, u * u)
	if str(entry[1]) != "fall": item["last"] = node.global_position


# ----------------------------------------------------------------- BLEUETTE --

func _bleuette() -> void :
	var c: PaperCinema = film
	var s: int = 0
	var a: int = c.alice_index
	_path(s, FA.bleuette_path())
	_path(a, FA.bleuette_alice_path())
	c._face(s, 0.0, "dir", Vector3(0, 0, 1))
	c._face(a, 0.0, "dir", Vector3(0.04, 0, 1))
	c._do(s, 0.0, "play", "fa_bleuette")
	c._do(a, 0.0, "play", "fa_bleuette_alice")
	# elle se retourne sur les fesses vers Alice (par sa gauche)
	c._face(s, 4.3, "dir", Vector3(0.7, 0, 0.7))
	c._face(s, 4.42, "dir", Vector3(1, 0, -0.2))
	c._face(s, 4.55, "dir", Vector3(0.15, 0, -1))

	# 1 · elle court vers nous, Alice marche derrière elle dans le noir
	c._shot(0.0, {"rel": {"a": s}, "eye": [Vector3(-0.35, 0.95, 2.5), Vector3(-0.3, 0.9, 2.2)], "look": {"a": s, "h": 0.95}, "fov": [42, 40], "hand": 0.6})
	# 2 · Alice, de dos, et la petite qui s'éloigne
	c._shot(1.45, {"rel": {"a": a}, "eye": [Vector3(0.75, 1.25, -1.6), Vector3(0.7, 1.2, -1.35)], "look": [{"a": s, "h": 0.8}, {"a": s, "h": 0.7}], "fov": [38, 36], "hand": 0.4})
	# 3 · au ras du sol : elle s'étale vers nous, la barre glisse jusqu'à l'objectif
	c._shot(2.32, {"eye": [Vector3(0.75, 0.22, 5.6), Vector3(0.72, 0.2, 5.5)], "look": [Vector3(0.3, 0.45, 3.0), Vector3(0.3, 0.3, 3.8)], "fov": [44, 42], "hand": 0.3})
	c._cue(2.84, "sound", "ground_impact", {"a": s}, 0.7, 1.2)
	c._cue(2.84, "shake", 0.25)
	c._cue(3.0, "dust_ring", {"a": s}, 0.7)
	# 4 · par terre, elle relève la tête… et regarde derrière elle
	c._shot(3.42, {"rel": {"a": s}, "eye": [Vector3(-1.25, 0.45, 0.85), Vector3(-1.15, 0.5, 0.75)], "look": {"a": s, "h": 0.35, "o": Vector3(0, 0, 0.35)}, "fov": [40, 38], "hand": 0.4})
	c._cue(3.95, "sound", "step", {"a": a}, 0.9, 0.8)
	c._cue(4.15, "sweat", {"a": s, "s": "head"}, 3)
	# 5 · par-dessus son épaule : Alice approche, grande, sans se presser
	c._shot(4.62, {"rel": {"a": s}, "eye": [Vector3(0.45, 0.55, 0.9), Vector3(0.38, 0.5, 0.75)], "look": [{"a": a, "h": 1.25}, {"a": a, "h": 1.45}], "fov": [44, 40], "hand": 0.35})
	# 6 · de profil : elle lance la barre, Alice l'attrape au vol
	c._shot(5.82, {"rel": {"mid": [s, a]}, "eye": [Vector3(2.35, 0.75, 0.0), Vector3(2.2, 0.75, 0.0)], "look": {"mid": [s, a], "h": 0.85}, "fov": [42, 40], "hand": 0.3})
	c._cue(FA.B_THROW, "sound", "grenade_throw", {"a": s}, 0.6, 1.3)
	c._cue(FA.B_CATCH, "sound", "grab", {"a": a, "s": "hand_r"}, 0.8, 1.15)
	# 7 · contre-plongée sur Alice, la barre à la main ; elle la regarde
	c._shot(6.95, {"rel": {"a": a}, "eye": [Vector3(-0.55, 0.75, 1.35), Vector3(-0.5, 0.78, 1.2)], "look": {"a": a, "h": 1.42}, "fov": [38, 35], "hand": 0.25, "roll": [0, -3]})
	# 8 · elle s'accroupit à sa hauteur, la griffe monte
	c._shot(7.72, {"rel": {"a": s}, "eye": [Vector3(0.95, 0.75, -0.55), Vector3(0.82, 0.72, -0.45)], "look": [{"mid": [s, a], "h": 0.75}, {"a": s, "h": 0.7}], "fov": [40, 37], "hand": 0.3})
	c._cue(8.5, "sound", "presence", {"a": a}, 0.7, 0.8)
	# 9 · hors champ : la barre tombée par terre, la main qui retombe à côté
	var kill: float = FA.B_KILL
	c._shot(kill - 0.06, {"eye": [Vector3(1.05, 0.16, 3.95), Vector3(1.0, 0.15, 3.98)], "look": [Vector3(0.62, 0.05, 4.3), Vector3(0.62, 0.04, 4.32)], "fov": [34, 33], "hand": 0.15})
	c._cue(kill, "sound", "kill_stab", {"a": s}, 1.0, 0.9)
	c._cue(kill, "sound", "slash", {"a": s}, 0.7, 0.8)
	c._cue(kill, "splash", 1.2)
	c._cue(kill, "frame", Color(0.55, 0.0, 0.08, 0.25), 0.1)
	c._cue(kill, "shake", 0.5)
	c._cue(kill + 0.4, "sound", "ground_impact", {"a": s}, 0.45, 0.8)
	# 10 · Alice se relève et croque dans le chocolat en nous regardant
	c._shot(9.82, {"rel": {"a": a}, "eye": [Vector3(0.4, 0.55, 1.75), Vector3(0.3, 0.7, 1.45)], "look": [{"a": a, "h": 1.15}, {"a": a, "h": 1.5}], "fov": [40, 36], "hand": 0.25})
	c._cue(10.95, "sound", "kill_crunch", {"a": a, "s": "head"}, 0.3, 1.35)

	# la barre : dans la main en courant (clip), s'échappe à la chute, glisse, est ramassée,
	# vole jusqu'à Alice (clip ensuite)
	var bar: Node3D = _prop_mesh("chocolate", 1.25)
	_item(bar, [
		[2.72, "fly", {"a": s, "s": "hand_r"}, Vector3(0.62, 0.03, 4.25), 0.42, 0.35, 1.3],
		[3.14, "floor", Vector3(0.62, 0.03, 4.25), 0.6],
		[5.95, "off"],
		[FA.B_THROW, "fly", {"a": s, "s": "hand_r"}, {"a": a, "s": "hand_r"}, FA.B_CATCH - FA.B_THROW, 0.25, 1.1],
		[FA.B_CATCH, "off"],
	])

