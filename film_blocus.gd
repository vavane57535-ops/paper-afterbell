class_name PaperFilmBlocus
extends Node3D

# « Le blocus » : fin jouée quand le joueur humain qui incarne Alice quitte la manche.
# Les survivants encore là font un blocus de lycée devant l'entrée de l'école.
# Film volontairement nul : plans fixes de travers, chorégraphies raides calées sur la
# flûte à bec (100 BPM), banderoles mal écrites, montage de caméscope (film_blocus_overlay.gd).
# Il s'écrit avec la timeline de PaperCinema (_put/_move/_do/_ramp/_cue/_shot) ; PaperCinema
# l'instancie pour le genre KIND et lui délègue update().

const AnimSet = preload("res://anim_set_blocus.gd")
const AnimLibrary = preload("res://anim_library.gd")
const T = preload("res://ui_theme.gd")

const KIND: String = "ending_blocus"
const DURATION: float = 38.6
const MUSIC: String = "res://audio/cinematic/blocus.ogg"
# Grille de la musique : premier temps à 0,58 s, 100 BPM ; la flûte entre au temps 16.
const KICK: float = 0.58
const BEAT: float = 0.6

const LEAD_ORDER: Array[String] = ["Usayuko", "Simon", "Ashura", "Lysia", "Elly", "Bleuette"]
const SLOGANS: Dictionary = {
	"Usayuko": "ALICE, REVIENS SI T'ES CAP !",
	"Simon": "PAS DE COURS, PAS DE COURSE-POURSUITE !",
	"Ashura": "ROLLERS AUTORISÉS DANS LES COULOIRS !",
	"Lysia": "UNE PRISE ÉLECTRIQUE PAR ÉLÈVE !",
	"Elly": "DES PANSEMENTS GRATUITS POUR TOUT LE MONDE !",
	"Bleuette": "DU CHOCOLAT À LA CANTINE !!!",
}
# Pancartes : texte (avec ses fautes), tenue au-dessus de la tête ou sur un bâton.
const SIGNS: Array = [["ON A GAGNÉ\nPAR FORFAIT", "over"], ["PAS DE\nCOURS", "stick"], ["ALICE =\nFORFÉ", "stick"], ["ON VEUT DES\nVACANSES", "over"], ["RENDEZ-NOUS\nLA RÉCRÉ", "stick"]]
const BANNER_TEXT: String = "ALICE A RAGE QUIT"

const CARDBOARD: Color = Color("b98f58")
const CARDBOARD_DARK: Color = Color("8d6a3d")
const MARKER: Color = Color("17141a")
const PAINT_RED: Color = Color("cf2233")

var film: PaperCinema
var world: Node
var overlay: PaperBlocusOverlay
var door: float = 15.0
var lead: int = 0
var others: Array[int] = []
var cardboard_school: bool = false

var _set: Node3D
var _banner: Node3D
var _banner_fall: float = 20.38
var _signs: Array = []
var _megaphone: Node3D
var _mega_mouth: Vector2 = Vector2(9.4, 33.75)
var _tumble: Array = []
var _smoke: Array = []
var _smoke_at: float = 33.6
var _mats: Dictionary = {}
var _exit_sign: Node3D
var _exit_sign_shown: bool = false


static func b(n: float) -> float:
	return KICK + BEAT * n


static func title() -> String:
	return "Le blocus · Alice a quitté la partie"


static func description() -> String:
	return "Alice a quitté la manche : les survivants bloquent l’entrée de l’école avec des poubelles, des chaises et des banderoles mal écrites. Victoire par forfait."


# Les clips du blocus ne sont pas dans AnimLibrary.SETS : on les ajoute une fois, à la demande.
static func register_clips() -> void :
	if AnimLibrary.has_clip("dance_blocus_chant"): return
	var clips: Dictionary = {}
	AnimSet.add(clips)
	for key: Variant in clips: AnimLibrary._all[key] = clips[key]


# Le mégaphone revient à la personne mise en avant (meilleur score en partie), sinon
# à la plus bruyante de la bande.
static func pick_lead(people: Array, focus: String) -> int:
	if focus in people: return people.find(focus)
	for person: String in LEAD_ORDER:
		if person in people: return people.find(person)
	return 0


func write(cinema: PaperCinema) -> void :
	film = cinema;world = cinema.world;name = "Blocus"
	register_clips()
	cardboard_school = not (is_instance_valid(world.school) and str(world.school.get("map_id")) == "school")
	if cardboard_school:
		# Hors de l'école : décor en carton monté au-dessus de la carte, façon kermesse.
		film.anchor = film.finish + Vector3.UP * 60.0 - film.forward * 15.0
		door = 15.0
	else: door = film._length
	lead = pick_lead(film.people, film.focus_name)
	film.focus_name = film.people[lead]
	others.clear()
	for i: int in range(film.people.size()):
		if i != lead: others.append(i)
	_set = Node3D.new();_set.name = "BlocusSet";add_child(_set)
	_set.global_transform = Transform3D(Basis(film.right, Vector3.UP, film.forward), film.anchor)
	_build_set()
	_write_cast()
	_write_shots()
	_build_overlay()
	# Le panneau « SORTIE · À 01:20 » du jeu flotte devant la porte : on le cache pendant le film.
	var marks: Variant = world.get("map_interactables")
	var sign: Variant = marks.get("exit_sign") if is_instance_valid(marks) else null
	if sign is Node3D:
		_exit_sign = sign;_exit_sign_shown = _exit_sign.visible;_exit_sign.visible = false


func _exit_tree() -> void :
	if is_instance_valid(overlay): overlay.queue_free()
	if is_instance_valid(_exit_sign): _exit_sign.visible = _exit_sign_shown


func L(x: float, y: float, z: float) -> Vector3:
	return Vector3(x, y, door + z)


# ---------------------------------------------------------------- décor

func _mat(color: Color) -> StandardMaterial3D:
	var key: String = color.to_html()
	if _mats.has(key): return _mats[key]
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color;material.roughness = 0.85
	_mats[key] = material
	return material


func _box(parent: Node3D, at: Vector3, size: Vector3, color: Color, rotation_value: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new();mesh.size = size
	node.mesh = mesh;node.material_override = _mat(color)
	node.position = at;node.rotation = rotation_value
	parent.add_child(node)
	return node


func _tube(parent: Node3D, at: Vector3, radius_top: float, radius_bottom: float, height: float, color: Color, rotation_value: Vector3 = Vector3.ZERO, sides: int = 10) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius_top;mesh.bottom_radius = radius_bottom;mesh.height = height;mesh.radial_segments = sides;mesh.rings = 1
	node.mesh = mesh;node.material_override = _mat(color)
	node.position = at;node.rotation = rotation_value
	parent.add_child(node)
	return node


func _write_text(parent: Node3D, text: String, at: Vector3, line_height: float, color: Color, font_kind: String = "hand", tilt: float = 0.0) -> Label3D:
	var label: Label3D = Label3D.new()
	label.text = PaperLanguage.t(text)
	label.font = T.font(font_kind)
	label.font_size = 96
	label.pixel_size = line_height / 96.0
	label.modulate = color
	label.outline_size = 0
	label.line_spacing = -18.0
	label.position = at
	label.rotation.z = tilt
	label.double_sided = false
	label.shaded = false
	label.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	parent.add_child(label)
	return label


func _node(parent: Node3D, at: Vector3, rotation_value: Vector3 = Vector3.ZERO) -> Node3D:
	var node: Node3D = Node3D.new()
	node.position = at;node.rotation = rotation_value
	parent.add_child(node)
	return node


func _bin(at: Vector3, body: Color, lid: Color, yaw: float, tilt: float = 0.0, lid_open: float = 0.0) -> Node3D:
	var root: Node3D = _node(_set, at, Vector3(tilt, yaw, 0.0))
	_box(root, Vector3(0, 0.5, 0), Vector3(0.62, 0.92, 0.7), body)
	_box(root, Vector3(0, 0.08, 0), Vector3(0.66, 0.14, 0.74), body.darkened(0.25))
	var hinge: Node3D = _node(root, Vector3(0, 0.97, -0.36), Vector3(- lid_open, 0, 0))
	_box(hinge, Vector3(0, 0.03, 0.38), Vector3(0.7, 0.07, 0.8), lid)
	_box(root, Vector3(0, 0.93, -0.4), Vector3(0.6, 0.05, 0.05), Color("2a2c31"))
	for side: float in [-1.0, 1.0]:
		_tube(root, Vector3(side * 0.3, 0.1, -0.3), 0.1, 0.1, 0.06, Color("1d1e22"), Vector3(0, 0, PI * 0.5), 12)
	return root


func _chair(parent: Node3D, at: Vector3, rotation_value: Vector3, seat: Color = Color("e07a2f")) -> Node3D:
	var root: Node3D = _node(parent, at, rotation_value)
	var frame: Color = Color("4f545c")
	_box(root, Vector3(0, 0.45, 0.02), Vector3(0.42, 0.035, 0.4), seat)
	_box(root, Vector3(0, 0.76, -0.19), Vector3(0.42, 0.24, 0.03), seat, Vector3(-0.08, 0, 0))
	for x: float in [-0.19, 0.19]:
		for z: float in [-0.17, 0.19]:
			_tube(root, Vector3(x, 0.225, z), 0.014, 0.014, 0.45, frame)
		_tube(root, Vector3(x, 0.62, -0.19), 0.013, 0.013, 0.36, frame)
	return root


func _desk(at: Vector3, rotation_value: Vector3) -> Node3D:
	var root: Node3D = _node(_set, at, rotation_value)
	var frame: Color = Color("4f545c")
	_box(root, Vector3(0, 0.71, 0), Vector3(1.2, 0.035, 0.55), Color("d8b07a"))
	_box(root, Vector3(0, 0.6, -0.05), Vector3(1.05, 0.02, 0.4), Color("7a7f87"))
	for x: float in [-0.55, 0.55]:
		for z: float in [-0.22, 0.22]:
			_tube(root, Vector3(x, 0.35, z), 0.016, 0.016, 0.7, frame)
	return root


func _cone(at: Vector3, rotation_value: Vector3 = Vector3.ZERO) -> Node3D:
	var root: Node3D = _node(_set, at, rotation_value)
	_box(root, Vector3(0, 0.02, 0), Vector3(0.38, 0.04, 0.38), Color("26272b"))
	_tube(root, Vector3(0, 0.3, 0), 0.03, 0.16, 0.52, Color("ff6a1a"), Vector3.ZERO, 14)
	_tube(root, Vector3(0, 0.36, 0), 0.075, 0.095, 0.08, Color("f4f1ea"), Vector3.ZERO, 14)
	_tube(root, Vector3(0, 0.2, 0), 0.115, 0.135, 0.07, Color("f4f1ea"), Vector3.ZERO, 14)
	return root


func _build_set() -> void :
	if cardboard_school: _cardboard_facade()

	# Banderole drap de lit scotchée en travers de l'entrée, lettres peintes à la main.
	_banner = _node(_set, L(-2.75, 3.05, 0.16), Vector3(0, 0, 0.035))
	_box(_banner, Vector3(2.75, -0.42, 0), Vector3(5.5, 0.84, 0.02), Color("f1ede2"))
	_box(_banner, Vector3(0.12, -0.05, 0.02), Vector3(0.3, 0.12, 0.01), Color("9fa3a8"), Vector3(0, 0, 0.5))
	_box(_banner, Vector3(5.38, -0.05, 0.02), Vector3(0.3, 0.12, 0.01), Color("9fa3a8"), Vector3(0, 0, -0.5))
	var font: Font = T.font("hand")
	var painted: String = PaperLanguage.t(BANNER_TEXT)
	var letter_size: float = 0.62
	var advance: Array[float] = []
	var total: float = 0.0
	for i: int in range(painted.length()):
		var w: float = font.get_string_size(painted[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 96).x * letter_size / 96.0 * 1.05
		advance.append(w);total += w
	var cursor: float = 2.75 - total * 0.5
	for i: int in range(painted.length()):
		var jitter: float = sin(float(i) * 12.9898) * 0.5
		if painted[i] != " ":
			var letter: Label3D = _write_text(_banner, painted[i], Vector3(cursor + advance[i] * 0.5, -0.42 + jitter * 0.06 - float(i) * 0.008, 0.016), letter_size * (1.0 + jitter * 0.12), PAINT_RED, "hand", jitter * 0.22)
			letter.render_priority = 1
		cursor += advance[i]

	# La barricade : poubelles, tables couchées, chaises empilées, plots.
	_bin(L(-2.15, 0, 0.75), Color("3f6b3a"), Color("335a2f"), 0.15)
	_bin(L(-0.55, 0, 0.6), Color("5a5f66"), Color("4a4e55"), -0.12, 0.0, 0.5)
	_bin(L(1.0, 0, 0.7), Color("40567d"), Color("e2c13a"), 0.25)
	_bin(L(2.5, 0, 0.62), Color("3f6b3a"), Color("335a2f"), -0.3)
	_desk(L(-1.35, 0.3, 1.45), Vector3(-PI * 0.5, 0.08, 0))
	_desk(L(1.75, 0.3, 1.5), Vector3(-PI * 0.5, -0.12, 0.04))
	_chair(_set, L(-2.15, 1.0, 0.7), Vector3(PI, 0.4, 0), Color("e07a2f"))
	_chair(_set, L(1.0, 1.0, 0.7), Vector3(PI, -0.3, 0.05), Color("2f8fd0"))
	_chair(_set, L(-3.3, 0, 1.05), Vector3(0, 0.6, PI * 0.5), Color("e07a2f"))
	_cone(L(-0.55, 0.93, 0.6), Vector3(0, 0, 0.18))
	_cone(L(3.6, 0, 1.4))
	_cone(L(-2.35, 0, 6.05))
	var broom: Node3D = _node(_set, L(-0.95, 0, 1.0), Vector3(0.12, 0, -0.18))
	_tube(broom, Vector3(0, 1.2, 0), 0.018, 0.018, 2.0, Color("8a5a2b"))
	_box(broom, Vector3(0, 2.25, 0.0), Vector3(0.45, 0.32, 0.01), Color("f1ede2"), Vector3(0, 0, -0.05))
	_write_text(broom, "BLOCUS !!!", Vector3(0, 2.25, 0.012), 0.11, MARKER, "caps")

	# La pile de chaises qui va s'écrouler à la fin.
	for k: int in range(4):
		var stacked: Node3D = _chair(_set, L(2.5, 0.97 + float(k) * 0.13, 0.62), Vector3(0, 0.12 * float(k) - 0.3, 0.0), Color("e07a2f") if k % 2 == 0 else Color("2f8fd0"))
		_tumble.append({"node": stacked, "from": stacked.transform, "t0": b(56.0) + 0.06 * float(k), "dir": Vector3(0.6 + 0.3 * float(k), 0, 1.0).normalized(), "spin": PI * 0.5 + (0.12 if k % 2 == 0 else -0.1)})

	# Le promontoire du mégaphone.
	_chair(_set, L(0.0, 0.0, 3.55), Vector3(0, PI, 0), Color("2f8fd0"))

	PaperToon.apply_tree(_set, false)

	# Fumigène artisanal (des boules roses qui gonflent, c'est tout).
	for k: int in range(7):
		var puff: MeshInstance3D = MeshInstance3D.new()
		var sphere: SphereMesh = SphereMesh.new();sphere.radius = 0.5;sphere.height = 1.0;sphere.radial_segments = 10;sphere.rings = 6
		puff.mesh = sphere
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = Color(1.0, 0.45, 0.75, 0.0);material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA;material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		puff.material_override = material
		puff.visible = false
		_set.add_child(puff)
		_smoke.append({"node": puff, "material": material, "at": L(-0.4 + sin(float(k) * 2.3) * 0.5, 1.1, 1.0), "drift": Vector3(sin(float(k) * 1.7) * 0.6, 0.55 + 0.1 * float(k % 3), 0.5 + cos(float(k) * 2.9) * 0.3), "delay": 0.07 * float(k)})

	# Pancartes en carton, mégaphone.
	for k: int in range(others.size()):
		if k >= SIGNS.size(): break
		var spec: Array = SIGNS[k]
		var over: bool = str(spec[1]) == "over"
		var holder: Node3D = _node(self, Vector3.ZERO)
		var board: Vector2 = Vector2(1.45, 0.62) if over else Vector2(0.78, 0.55)
		_box(holder, Vector3.ZERO, Vector3(board.x, board.y, 0.018), CARDBOARD)
		_box(holder, Vector3(0, - board.y * 0.5 + 0.01, 0.0), Vector3(board.x, 0.02, 0.022), CARDBOARD_DARK)
		_write_text(holder, str(spec[0]), Vector3(0, 0, 0.012), 0.2 if over else 0.17, MARKER, "hand", -0.03 if k % 2 == 0 else 0.04)
		if not over: _tube(holder, Vector3(0, - board.y * 0.5 - 0.42, -0.02), 0.016, 0.016, 0.95, Color("8a5a2b"))
		_signs.append({"node": holder, "take": others[k], "over": over, "board": board})
	_megaphone = _node(self, Vector3.ZERO)
	_tube(_megaphone, Vector3(0, 0, 0), 0.1, 0.035, 0.3, Color("f2f0ea"), Vector3.ZERO, 16)
	_tube(_megaphone, Vector3(0, 0.1, 0), 0.092, 0.086, 0.04, PAINT_RED, Vector3.ZERO, 16)
	_tube(_megaphone, Vector3(0, -0.17, 0), 0.04, 0.04, 0.05, Color("2a2c31"), Vector3.ZERO, 12)
	_box(_megaphone, Vector3(0, -0.06, 0.08), Vector3(0.035, 0.08, 0.13), Color("2a2c31"))
	PaperToon.apply_tree(_megaphone, false)
	for sign: Dictionary in _signs: PaperToon.apply_tree(sign.node, false)


func _cardboard_facade() -> void :
	# Sol de cour et façade d'école peinte sur des cartons (il n'y a pas d'école ici).
	_box(_set, L(0, -0.16, 3.0), Vector3(26.0, 0.3, 22.0), Color("8f8c84"))
	_box(_set, L(0, -0.005, 6.0), Vector3(2.4, 0.01, 14.0), Color("6f8a62"))
	_box(_set, L(0, 2.6, -0.15), Vector3(16.0, 5.2, 0.12), Color("e9dcc0"))
	_box(_set, L(0, 5.25, -0.15), Vector3(16.4, 0.18, 0.16), CARDBOARD_DARK)
	_box(_set, L(0, 1.6, -0.08), Vector3(3.6, 3.2, 0.02), Color("5d7f8c"))
	_box(_set, L(0, 1.6, -0.07), Vector3(0.06, 3.2, 0.02), MARKER)
	for x: float in [-5.5, -3.6, 3.6, 5.5]:
		_box(_set, L(x, 3.4, -0.08), Vector3(1.2, 1.0, 0.02), Color("7fb0d6"))
		_box(_set, L(x, 3.4, -0.07), Vector3(1.2, 0.04, 0.02), MARKER)
	_box(_set, L(0, 4.3, -0.07), Vector3(6.2, 0.7, 0.02), Color("b8323f"))
	_write_text(_set, "ÉCOLE FONDAMENTALE", L(0, 4.3, -0.05), 0.42, Color("fbf4e4"), "hand", 0.02)
	_write_text(_set, "(en carton)", L(4.4, 3.95, -0.05), 0.2, MARKER, "hand", -0.08)
	for x: float in [-8.0, 8.0]:
		_box(_set, L(x, 2.6, 0.6), Vector3(0.1, 5.2, 1.4), CARDBOARD_DARK)


# ---------------------------------------------------------------- distribution

func _loop(i: int, t0: float, t1: float, clip: String) -> void :
	film._do(i, t0, "state", {"emote_id": clip, "emote_time": 0.0})
	film._ramp(i, t0, t1 - 0.01, "emote_time", 0.0, t1 - 0.01 - t0)
	film._do(i, t1 - 0.01, "unset", ["emote_id", "emote_time"])


func _slots() -> Dictionary:
	var spots: Dictionary = {}
	spots[lead] = L(0.0, 0.0, 3.4)
	var left: int = int(ceil(float(others.size()) * 0.5))
	for k: int in range(others.size()):
		var x: float = -1.15 - 1.3 * float(k / 2) if k % 2 == 0 else 1.15 + 1.3 * float(k / 2)
		if others.size() == 1: x = -1.2
		spots[others[k]] = L(x, 0.0, 2.45 + (0.18 if k % 2 == 1 else 0.0))
	return spots


func _write_cast() -> void :
	var spots: Dictionary = _slots()
	var march: float = 5.3
	var halt: float = b(13.0)
	var turn: float = b(14.0)
	for i: int in range(film.people.size()):
		var spot: Vector3 = spots[i]
		film._put(i, spot - Vector3(8.5, 0, 0))
		film._do(i, 0.0, "show", false)
		film._do(i, march - 0.05, "show", true)
		film._face(i, 0.0, "dir", Vector3(1, 0, 0))
		film._move(i, march, halt, spot, "linear")
		# Arrêt pile, puis quart de tour tous ensemble, au temps.
		film._face(i, turn, "dir", Vector3(0, 0, 1))
		film._do(i, 0.0, "mood", "determined")
	# Le chef monte sur sa chaise et prend le mégaphone jusqu'au fumigène.
	var up: Vector3 = spots[lead] + Vector3(0, 0.47, 0.15)
	# Il grimpe pendant le plan large (en mouvement, la pose du mégaphone ne s'affiche pas),
	# puis le mégaphone monte à la bouche avec la pose avant la coupe du « Un, deux… ».
	var climb: float = b(16.0) - 1.0
	film._move(lead, climb, climb + 0.3, up, "out")
	_mega_mouth.x = climb + 0.34
	_loop(lead, climb + 0.32, b(55.0), "dance_blocus_megaphone")
	film._move(lead, b(55.6), b(56.2), spots[lead] + Vector3(0.45, 0, 0.75), "out")
	_loop(lead, b(56.3), b(57.0), "fear")
	_loop(lead, b(57.0), DURATION, "cheer")

	var g_start: float = b(43.0)
	var g_end: float = b(55.0)
	var speakers: Array[int] = []
	for i: int in others:
		if speakers.size() < 4: speakers.append(i)
	if speakers.is_empty(): speakers.append(lead)
	var turn_beats: float = clampf(floor(12.0 / float(speakers.size())), 3.0, 6.0)
	for k: int in range(others.size()):
		var i: int = others[k]
		var holds_over: bool = k < SIGNS.size() and str(SIGNS[k][1]) == "over"
		_loop(i, b(20.0), b(35.0), "dance_blocus_sign" if holds_over else "dance_blocus_chant")
		_loop(i, b(35.0), g_start, "dance_robot")
		var cursor: float = g_start
		var index: int = speakers.find(i)
		if index >= 0:
			var start: float = g_start + BEAT * turn_beats * float(index)
			var finish: float = start + BEAT * turn_beats
			if start > cursor + 0.05: _loop(i, cursor, start, "dance_blocus_sign" if holds_over else "dance_blocus_stomp")
			# Les pancartes tenues à deux mains restent au-dessus de la tête (sinon elles cachent le visage).
			_loop(i, start, finish, "dance_blocus_sign" if holds_over else "dance_blocus_chant" if k < SIGNS.size() else "point")
			cursor = finish
		if g_end > cursor + 0.05: _loop(i, cursor, g_end, "dance_blocus_sign" if holds_over else "dance_blocus_stomp")
		_loop(i, b(55.2), b(57.0), "fear")
		_loop(i, b(57.0) + 0.05 * float(k), DURATION, "cheer" if k % 2 == 0 else "thumbsup")
		film._do(i, b(57.0), "mood", "grin")
	film._do(lead, b(57.0), "mood", "grin")

	_write_story(speakers, turn_beats)


func _write_story(speakers: Array[int], turn_beats: float) -> void :
	var who: String = film.people[lead]
	var shout: String = who + " (" + PaperLanguage.t("mégaphone") + ")"
	var all: String = PaperLanguage.t("Tout le monde") if not others.is_empty() else who
	_cue_sound(0.1, "bell", L(0, 3, 0), 0.8)
	_caption(5.5, 7.5, "", "16 h 47. Alice a quitté la partie.")
	_caption(7.5, 9.45, "", "Les survivants décident alors de… bloquer l’école.")
	_caption(9.7, 11.3, shout, "Un, deux… un, deux… Ça marche, ce truc ?")
	film._cue(b(16.0) + 0.15, "word", "zap", {"a": lead, "s": "mouth", "o": Vector3(0, 0.15, 0.4)}, Color("ffe14d"), 0.8)
	_cue_sound(b(16.0) + 0.15, "stun", {"a": lead}, 0.45, 1.9)
	_caption(b(18.0), b(23.0), shout, "ALICE ! T’ES OÙ ?! ALICE ! T’ES OÙ ?!")
	_caption(b(23.0), b(27.0), all, "♪ ON EST LÀ ! ON EST LÀ ! ♪")
	_cue_sound(b(23.0), "encourage", L(0, 1.5, 2.5), 0.7)
	_caption(b(27.0), b(31.0), all, "♪ MÊME SI ALICE VEUT PAS, NOUS ON EST LÀ ! ♪")
	_cue_sound(b(27.0), "encourage", L(0, 1.5, 2.5), 0.7, 1.1)
	_caption(b(31.0), b(33.0), "", "[ ZOOM DRAMATIQUE ]")
	_caption(b(33.0), b(34.0), "", "[ LA BANDEROLE SE DÉCROCHE ]")
	_caption(b(34.0), b(35.0), who, "… Quelqu’un a du scotch ?")
	film._cue(_banner_fall + 0.05, "word", "break", L(3.0, 2.6, 0.6), Color("fbf4e4"), 0.8)
	_cue_sound(_banner_fall, "ground_impact", L(2.5, 2.5, 0.5), 0.35, 1.5)
	_caption(b(35.0), b(39.0), all, "♪ ET UN, ET DEUX, ET TROIS-ZÉRO ! ♪")
	_caption(b(39.0), b(43.0), all, "♪ FOR-FAIT ! FOR-FAIT ! FOR-FAIT ! ♪")
	for index: int in range(speakers.size()):
		var i: int = speakers[index]
		var start: float = b(43.0) + BEAT * turn_beats * float(index)
		var person: String = film.people[i]
		_caption(start + 0.05, start + BEAT * turn_beats - 0.02, person, str(SLOGANS.get(person, "VIVE LE BLOCUS !")))
		_cue_sound(start + 0.1, "encourage", {"a": i}, 0.5, 0.9 + 0.08 * float(index))
	# Seul ou à deux, les slogans s'arrêtent au temps 49 : silence gêné jusqu'au fumigène.
	if others.size() <= 1:
		_caption(b(49.0), b(55.0), "", "[ GRILLONS ]")
	_caption(b(55.0), b(57.0), "", "[ FUMIGÈNE ARTISANAL ]")
	film._cue(_smoke_at + 0.2, "word", "hot", L(-0.4, 2.0, 1.3), Color("ff8fc8"), 0.9)
	_cue_sound(_smoke_at, "boost", L(-0.4, 1.2, 1.0), 0.6, 0.7)
	_cue_sound(b(56.0) + 0.15, "block", L(3.2, 0.6, 1.0), 0.8, 0.85)
	_cue_sound(b(56.0) + 0.35, "ground_impact", L(3.4, 0.2, 1.6), 0.7, 1.2)
	film._cue(b(56.0) + 0.3, "word", "break", L(3.3, 1.2, 1.4), Color("fbf4e4"), 0.9)
	film._cue(b(56.0) + 0.3, "shake", 0.35)
	_caption(b(57.0), b(59.0), "", "[ CRIS DE VICTOIRE ]")
	_cue_sound(b(57.0), "encourage", L(0, 1.5, 2.5), 0.8, 1.15)
	_cue_sound(b(57.0) + 0.05, "bell", L(0, 3, 0), 0.5, 1.25)
	film._cue(b(57.2), "sparkles", L(0, 2.2, 2.6), Color("ffd24a"), 10, 1.4)


func _caption(t0: float, t1: float, speaker: String, text: String) -> void :
	if overlay == null: _pending_captions.append([t0, t1, speaker, text])
	else: overlay.caption(t0, t1, speaker, text)

var _pending_captions: Array = []


func _cue_sound(t: float, sound: String, at: Variant, gain: float = 1.0, pitch: float = 1.0) -> void :
	film._cue(t, "sound", sound, at, gain, pitch)


# ---------------------------------------------------------------- plans

func _write_shots() -> void :
	var base: Vector3 = L(0, 0, 0)
	# A. Plan d'ensemble fixe, un peu penché, pendant le générique.
	film._shot(0.0, {"rel": base, "eye": Vector3(0.7, 1.25, 12.5), "look": L(0, 1.9, 0.9), "fov": 60.0, "hand": 0.0, "roll": -3.0, "safe": false})
	# B. Arrivée en file indienne, caméra posée par terre sur le côté.
	film._shot(5.3, {"rel": base, "eye": Vector3(5.4, 0.8, 6.4), "look": L(-1.6, 1.15, 2.6), "fov": 50.0, "hand": 0.12, "roll": 7.0, "safe": false})
	# C. Contre-plongée sur le mégaphone.
	film._shot(b(16.0) - 0.4, {"rel": {"a": lead}, "eye": [Vector3(1.05, 0.5, 2.5), Vector3(0.95, 0.5, 2.35)], "look": {"a": lead, "h": 1.45}, "fov": 42.0, "hand": 0.2, "roll": -9.0, "safe": false})
	# D. Tableau frontal parfaitement symétrique (et trop large).
	film._shot(b(23.0), {"rel": base, "eye": Vector3(0.0, 1.5, 8.6), "look": L(0, 1.55, 2.3), "fov": 44.0, "hand": 0.0, "roll": 0.0, "safe": false})
	# E. Zoom brutal sur la banderole… qui se décroche.
	film._shot(b(31.0), {"rel": base, "eye": Vector3(-1.3, 1.7, 7.6), "look": L(0.0, 2.6, 0.2), "fov": [58.0, 19.0], "ease": "dash", "hand": 0.1, "roll": 2.0, "safe": false})
	film._shot(b(31.0) + 0.42, {"rel": base, "eye": Vector3(-1.3, 1.7, 7.6), "look": L(0.0, 2.6, 0.2), "fov": 19.0, "hand": 0.15, "roll": 2.0, "safe": false})
	# … et le caméraman dézoome en catastrophe pour voir la banderole pendouiller.
	film._shot(_banner_fall + 0.4, {"rel": base, "eye": Vector3(-1.3, 1.7, 7.6), "look": [L(0.0, 2.6, 0.2), L(-0.6, 1.9, 0.6)], "fov": [19.0, 52.0], "ease": "dash", "hand": 0.45, "roll": [2.0, -6.0], "safe": false})
	# F. Caméra au ras du sol derrière un plot de chantier.
	film._shot(b(35.0), {"rel": base, "eye": Vector3(-2.5, 0.3, 6.75), "look": L(-0.2, 1.25, 2.6), "fov": 56.0, "hand": 0.4, "roll": 11.0, "safe": false})
	# G. Faux raccords : même cadrage serré pour chaque slogan.
	var speakers: Array[int] = []
	for i: int in others:
		if speakers.size() < 4: speakers.append(i)
	if speakers.is_empty(): speakers.append(lead)
	var turn_beats: float = clampf(floor(12.0 / float(speakers.size())), 3.0, 6.0)
	for index: int in range(speakers.size()):
		var i: int = speakers[index]
		var side: float = 1.0 if index % 2 == 0 else -1.0
		var start: float = b(43.0) + BEAT * turn_beats * float(index)
		# Seul au mégaphone : plan de trois quarts, sinon le pavillon cache tout le visage.
		var lateral: float = 3.0 if i == lead else 1.0
		film._shot(start, {"rel": {"a": i}, "eye": [Vector3(0.35 * side * lateral, 1.0, 2.25), Vector3(0.3 * side * lateral, 1.02, 2.0)], "look": {"a": i, "h": 1.38}, "fov": 36.0, "hand": 0.25, "roll": 5.0 * side, "safe": false})
	# H. Plongée de « caméra de surveillance » pour le final.
	film._shot(b(55.0), {"rel": base, "eye": [Vector3(2.4, 3.3, 9.2), Vector3(2.2, 3.2, 8.8)], "look": L(0.4, 1.1, 2.0), "fov": 54.0, "hand": 0.1, "roll": 0.0, "safe": false})


func _build_overlay() -> void :
	overlay = PaperBlocusOverlay.new()
	var ui: Variant = world.get("ui")
	var layer: Variant = ui.get("film_layer") if is_instance_valid(ui) else null
	if not layer is Control:
		overlay = null
		return
	overlay.setup(world, DURATION)
	(layer as Control).add_child(overlay)
	for row: Array in _pending_captions: overlay.caption(float(row[0]), float(row[1]), str(row[2]), str(row[3]))
	_pending_captions.clear()
	# Générique WordArt avec faute de frappe corrigée au feutre (les fautes sont propres à chaque langue).
	var english: bool = PaperLanguage.language == "en"
	overlay.card("title", 0.3, 4.15, "THE BLOKCADE" if english else "LE BLOCSU", 118, Vector2(0.5, 0.4), {"rainbow": true, "wobble": 7.0, "spin": 1.0, "tilt": -4.0, "fly_out": true})
	overlay.correction("title", 1.7, 7, 9, "CK" if english else "US")
	overlay.card("subtitle", 2.3, 4.15, PaperLanguage.t("DE L’ÉCOLE FONDAMENTALE"), 46, Vector2(0.5, 0.58), {"font": "title", "color": Color("ffe14d"), "shadow": Color("b0306a"), "tilt": 3.0, "fly_out": true})
	overlay.card("subtitle2", 2.9, 4.15, PaperLanguage.t("(ALICE A RAGE QUIT)"), 30, Vector2(0.62, 0.67), {"font": "hand", "color": Color("ffffff"), "shadow": Color(0, 0, 0, 0.5), "tilt": -6.0, "fly_out": true})
	overlay.failed_fade(4.15, 5.3)
	overlay.cut(5.3, 0.25)
	overlay.cut(b(16.0) - 0.4)
	overlay.cut(b(23.0))
	overlay.cut(b(31.0))
	overlay.cut(b(35.0), 0.3)
	overlay.finger(b(36.5), b(41.5))
	var speakers: int = clampi(others.size(), 1, 4)
	var turn_beats: float = clampf(floor(12.0 / float(speakers)), 3.0, 6.0)
	for index: int in range(speakers):
		overlay.cut(b(43.0) + BEAT * turn_beats * float(index), 0.12)
	overlay.cut(b(55.0))
	overlay.card("victory", b(57.0), b(59.0) + 0.3, PaperLanguage.t("VICTOIRE PAR FORFAIT !!!"), 84, Vector2(0.5, 0.42), {"rainbow": true, "wobble": 10.0, "spin": 0.7, "pulse": 1.67, "tilt": 5.0})
	overlay.card("victory_small", b(57.6), b(59.0) + 0.3, PaperLanguage.t("(sans jouer)"), 36, Vector2(0.66, 0.56), {"font": "hand", "color": Color("ffffff"), "tilt": -8.0})
	overlay.star_wipe(b(59.0), b(59.0) + 0.75)
	overlay.end_background(b(59.0) + 0.37)
	overlay.card("end", b(59.0) + 0.37, DURATION + 1.0, "EDN" if english else "FNI", 170, Vector2(0.5, 0.4), {"rainbow": true, "wobble": 4.0, "tilt": -3.0})
	overlay.correction("end", 37.05, 1, 3, "ND" if english else "IN")
	overlay.card("end_note", 37.45, DURATION + 1.0, PaperLanguage.t("Aucune Alice n’a été blessée pendant ce blocus."), 30, Vector2(0.5, 0.7), {"font": "medium", "color": Color("ffffff"), "shadow": Color(0, 0, 0, 0.45), "outline": 6})
	overlay.card("end_note2", 37.85, DURATION + 1.0, PaperLanguage.t("(Elle était partie.)"), 34, Vector2(0.5, 0.77), {"font": "hand", "color": Color("ffe14d"), "shadow": Color(0, 0, 0, 0.45), "outline": 6, "tilt": -2.0})


# ---------------------------------------------------------------- animation des accessoires

func update(t: float, _delta: float) -> void :
	# L'anneau doré de la sortie est remis à jour par le jeu à chaque image : on le recache.
	var marks: Variant = world.get("map_interactables") if world else null
	var glow: Variant = marks.get("exit_glow") if is_instance_valid(marks) else null
	if glow is Node3D: (glow as Node3D).visible = false
	_update_banner(t)
	_update_hand_props(t)
	_update_tumble(t)
	_update_smoke(t)
	if is_instance_valid(overlay): overlay.update(t)


func _update_banner(t: float) -> void :
	if not is_instance_valid(_banner): return
	var angle: float = 0.035
	if t >= _banner_fall:
		# Le scotch de droite lâche : la banderole pivote sur son coin gauche et oscille.
		var u: float = t - _banner_fall
		var settle: float = deg_to_rad(-68.0)
		angle = settle * (1.0 - exp(-u * 3.2) * cos(u * 9.0)) + 0.035 * exp(-u * 3.0)
	_banner.rotation = Vector3(0, 0, angle)


func _hand(take: int, socket: String) -> Vector3:
	var visual: PaperVisual = film.takes[take].visual
	return visual.fx_source().socket_position(socket)


func _facing_basis(take: int) -> Basis:
	var visual: PaperVisual = film.takes[take].visual
	return Basis(Vector3.UP, visual.global_rotation.y + PI)


func _update_hand_props(t: float) -> void :
	for sign: Dictionary in _signs:
		var node: Node3D = sign.node
		var take: int = int(sign.take)
		var shown: bool = film.takes[take].visual.visible
		node.visible = shown
		if not shown: continue
		var basis: Basis = _facing_basis(take)
		var board: Vector2 = sign.board
		if bool(sign.over):
			var middle: Vector3 = (_hand(take, "hand_l") + _hand(take, "hand_r")) * 0.5
			node.global_transform = Transform3D(basis, middle + Vector3.UP * (board.y * 0.5 - 0.02) + basis.z * 0.05)
		else:
			var grip: Vector3 = _hand(take, "hand_r")
			node.global_transform = Transform3D(basis, grip + Vector3.UP * (board.y * 0.5 + 0.38) + basis.z * 0.04)
	if is_instance_valid(_megaphone):
		var visual: PaperVisual = film.takes[lead].visual
		_megaphone.visible = visual.visible
		if visual.visible:
			var basis: Basis = _facing_basis(lead)
			var front: Vector3 = basis.z
			if t >= _mega_mouth.x and t < _mega_mouth.y:
				# Un peu sous la bouche et pointé vers le bas : de face, les yeux restent visibles.
				var mouth: Vector3 = _hand(lead, "mouth")
				_megaphone.global_transform = Transform3D(basis * Basis(Vector3.RIGHT, PI * 0.5 + 0.22), mouth + front * 0.17 + Vector3.DOWN * 0.07)
			else:
				var grip: Vector3 = _hand(lead, "hand_r")
				_megaphone.global_transform = Transform3D(basis * Basis(Vector3.RIGHT, PI * 0.15), grip + front * 0.08 + Vector3.DOWN * 0.04)


func _update_tumble(t: float) -> void :
	for item: Dictionary in _tumble:
		var node: Node3D = item.node
		var from: Transform3D = item.from
		var u: float = t - float(item.t0)
		if u <= 0.0:
			node.transform = from
			continue
		var fall: float = minf(u, 0.55)
		var k: float = fall / 0.55
		var direction: Vector3 = item.dir
		var drop: float = from.origin.y
		var travel: Vector3 = direction * (1.8 * fall)
		# Chute raide, puis la chaise reste couchée sur le dos (posée sur le sol, pas enfoncée dedans).
		var spin: float = float(item.spin) * k
		var rest: float = 0.21 * absf(sin(spin))
		var height: float = maxf(rest, drop + 1.2 * fall - 9.0 * fall * fall)
		node.transform = Transform3D(from.basis.rotated(Vector3(direction.z, 0, - direction.x).normalized(), spin), Vector3(from.origin.x, height, from.origin.z) + travel)


func _update_smoke(t: float) -> void :
	for puff: Dictionary in _smoke:
		var node: MeshInstance3D = puff.node
		var material: StandardMaterial3D = puff.material
		var u: float = t - _smoke_at - float(puff.delay)
		node.visible = u > 0.0 and u < 3.2
		if not node.visible: continue
		var grow: float = 0.25 + 1.1 * (1.0 - exp(-u * 2.2))
		node.position = (puff.at as Vector3) + (puff.drift as Vector3) * u
		node.scale = Vector3.ONE * grow
		material.albedo_color.a = 0.55 * (1.0 - smoothstep(1.6, 3.2, u))
