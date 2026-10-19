class_name PaperFilmEscape
extends Node3D

# Fuites en équipe (« ending_survivors », 63 combinaisons d'élèves), 0.17 : film écrit de A à Z.
# Alice condamne la sortie avec ses piques d'encre ; chacun la retient avec sa capacité puis
# passe la haie de piques (courte échelle, saut, on tire un ami) ; ceux qui sont passés se
# retournent et attendent les autres ; Alice traverse ses propres piques et arrive trop tard.
# Dehors, chacun craque à sa façon.
# PaperCinema délègue l'écriture (write) et appelle update() à chaque image. Tous les gestes
# viennent de anim_set_film_escape.gd (un clip par acteur, écrit pour ce film).

const Anim = preload("res://anim_set_film_escape.gd")
const AnimClip = preload("res://anim_clip.gd")
const AnimLibrary = preload("res://anim_library.gd")

# ordre de passage : soutiens d'abord, puis ceux qui retiennent Alice (Usayuko ferme la marche)
const ORDER: Array[String] = ["Bleuette", "Elly", "Simon", "Ashura", "Lysia", "Usayuko"]

static var _serial: int = 0

var film: PaperCinema
var world: Node
var door_z: float = 12.0
var cast: Array = []
var alice: int = -1
var plan_data: Dictionary = {}
var clip_keys: Array[String] = []
var _cue_links: Array = []


static func duration_for(names: Array) -> float:
	return float(plan(names).duration)


# Distribution et minutage, sans carte ni acteur (sert aussi au catalogue de la cinémathèque).
static func plan(names: Array) -> Dictionary:
	var team: Array[String] = []
	for person: String in ORDER:
		if person in names: team.append(person)
	if team.is_empty(): team.append("Ashura")
	var data: Dictionary = {"team": team}
	data["brake"] = 2.3
	data["duration"] = 6.0
	return data


func write(cinema: PaperCinema) -> void :
	film = cinema;world = cinema.world;name = "Escape"
	door_z = film._length - 3.0
	plan_data = plan(film.people)
	_serial += 1
	alice = film.alice_index
	var length: float = float(plan_data.duration)
	cast.clear()
	for i: int in range(film.takes.size()):
		var take: PaperCinema.Take = film.takes[i]
		var p: Anim.Performer = Anim.Performer.new()
		p.setup(take.visual, take.person, i, length)
		cast.append(p)
		_calm_idle(take.visual)
	_write_story()
	_finish()


# ------------------------------------------------------------------ histoire

func _write_story() -> void :
	var team: Array = film.people
	var brake: float = float(plan_data.brake)
	var n: int = team.size()
	for i: int in range(n):
		var p: Anim.Performer = cast[i]
		var lane: float = (float(i) - float(n - 1) * 0.5) * 1.15
		var start: Vector3 = Vector3(lane, 0.0, -13.5 + 0.5 * float(i % 2))
		var stop_at: Vector3 = Vector3(lane * 0.9, 0.0, -1.6 - 0.25 * float(i % 3))
		var cruise: float = 5.4
		p.start(0.0, start, Vector3(0, 0, cruise))
		p.turn(0.0, 0.0)
		var mid: Vector3 = stop_at + Vector3(0, 0, -2.6)
		var t_mid: float = brake - 0.5
		p.go(t_mid, mid, Vector3(0, 0, cruise * 0.9))
		p.go(brake, stop_at, Vector3.ZERO)
		p.hold(float(plan_data.duration))
		p.pose(0.0, Anim.base_pose())
		Anim.run(p, 0.0, float(plan_data.duration), {"first": 1 if i % 2 == 0 else -1, "seed": i * 13, "moving": true})
		p.face(0.0, "panic")
	if alice >= 0:
		var a: Anim.Performer = cast[alice]
		a.start(0.0, Vector3(0, 0, -19.0), Vector3(0, 0, 4.6))
		a.turn(0.0, 0.0)
		a.go(brake, Vector3(0, 0, -9.0), Vector3(0, 0, 0.0))
		a.hold(float(plan_data.duration))
		a.pose(0.0, Anim.base_pose())
		Anim.run(a, 0.0, float(plan_data.duration), {"first": 1, "moving": true})
		a.face(0.0, "menace")
	# plans
	film._shot(0.0, {"rel": _film_point(Vector3(2.2, 0.0, -1.0)), "eye": Vector3(0, 0.75, 0), "look": _film_point(Vector3(0, 1.0, -9.0)), "fov": 40.0, "hand": 0.3, "safe": false})
	film._shot(1.6, {"rel": _film_point(Vector3(-3.4, 0.0, -2.0)), "eye": Vector3(0, 1.1, 0), "look": _film_point(Vector3(0, 0.6, -1.6)), "fov": 46.0, "hand": 0.2, "safe": false})


# ------------------------------------------------------------------ assemblage

func _film_point(e: Vector3) -> Vector3:
	return Vector3(e.x, e.y, door_z + e.z)


func _finish() -> void :
	for i: int in range(cast.size()):
		var p: Anim.Performer = cast[i]
		# racine : échantillons serrés, reliés en ligne droite par la timeline du film
		var length: float = p.duration
		film._put(i, _film_point(p.at(0.0)))
		var t: float = Anim.GRID
		while t <= length + 0.0001:
			film._move(i, t - Anim.GRID, t, _film_point(p.at(t)), "linear")
			t += Anim.GRID
		film._face(i, 0.0, "dir", Vector3(0, 0, 1))
		var clip_name: String = "fesc%d_%s" % [_serial, p.person]
		var source: Dictionary = p.compile_source(clip_name)
		var compiled: Dictionary = AnimClip.compile(source)
		var cache_key: String = clip_name + "@" + p.person
		AnimLibrary._cache[cache_key] = compiled
		clip_keys.append(cache_key)
		film._do(i, 0.0, "play", clip_name)
		if OS.is_debug_build() and p.overreach > 0.02:
			print("FILM_ESCAPE overreach %s %.3f m at %.2f s" % [p.person, p.overreach, p.overreach_t])


# Pas de transfert de poids aléatoire pendant le film : les pieds de base restent fixes.
func _calm_idle(visual: PaperVisual) -> void :
	visual.set("_weight_side", 0.0)
	visual.set("_weight_target", 0.0)
	visual.set("_shift_timer", 1.0e9)
	var feet: Dictionary = visual.get("_idle_feet")
	var rest: Dictionary = visual.get("_foot_rest")
	var look: Dictionary = visual.get("_style")
	for side: int in [-1, 1]:
		var r: Vector3 = rest[side]
		feet[side] = Vector3(r.x * float(look.get("stance", 1.0)), r.y, r.z)
	var yaw: Dictionary = visual.get("_idle_foot_yaw")
	yaw[-1] = 0.0;yaw[1] = 0.0


func update(_t: float, _delta: float) -> void :
	pass


func _exit_tree() -> void :
	for cache_key: String in clip_keys: AnimLibrary._cache.erase(cache_key)
	clip_keys.clear()
	for i: int in range(film.takes.size() if film else 0):
		var visual: PaperVisual = film.takes[i].visual
		if is_instance_valid(visual): visual.set("_shift_timer", 3.0)
