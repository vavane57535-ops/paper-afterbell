extends Node3D

# Scène de survol de l'écran titre (ui_menu_vignettes.gd) : un décor, des acteurs et des
# « temps forts » (beats) de 20 à 40 s, chacun une petite histoire complète. Chaque temps fort
# joue pour chaque acteur un clip écrit à la main pour lui (anim_menu_<scène>.gd, réunis par
# anim_set_menu.gd), une piste de caméra et des événements (lumières, accessoires). Les temps
# forts s'enchaînent au hasard, jamais deux fois le même de suite ; ils partent de la même
# composition et y reviennent, et le retour est caché par un fondu ou un changement de plan.
#
# Clés d'un temps fort :
#   id, len, weight (0 = jamais tiré au hasard), next (id ou liste d'ids à enchaîner),
#   clips {acteur: clip}, homes {acteur: [position, lacet]}, hidden [acteurs absents],
#   vis {acteur: [[t, visible], ...]}, reach [[acteur, côté, t0, t1, cible, {in, out, w, offset}], ...],
#   fade_in / fade_out (secondes de fondu au noir au début / à la fin), cam, events.
# Un clip peut porter la piste de sa racine (« root », anim_menu_take.gd) : l'acteur suit alors
# cette piste dans le décor, pieds plantés par le clip.
#
# Piste de caméra : [t, œil, cible, fov, options] ; options : "cut" (nouveau plan),
# "stop" (arrêt net sur la clé), "linear", "shake" (caméra à l'épaule), "x" (place de la
# cible dans l'image, 0.5 = centre), "roll", et la mise au point : "focus" (point ou prise
# d'acteur net, la cible par défaut), "blur" (flou maximal hors du net, en pixels), "frad"
# (rayon de la zone nette), "btop" (flou en plus vers le haut de l'image).
# Œil ou cible peuvent être "acteur:prise" (prises de PaperVisual.socket_position)
# + décalage : ["simon:head", Vector3(0, 0, 0.1)].

const MenuKit = preload("res://menu_scene_kit.gd")
const AnimTake = preload("res://anim_menu_take.gd")
const AnimSetMenu = preload("res://anim_set_menu.gd")


var engine: Node
var id: String = ""
var accent: Color = Color.WHITE
var styled: bool = true
var masked: bool = true
var actors: Dictionary = {}
var homes: Dictionary = {}
var beats: Array = []
var grade: Dictionary = {}
var env: Environment
var built: bool = false
var beat: Dictionary = {}
var beat_time: float = 0.0
var beat_count: int = 0
var forced_beat: String = ""
# Fondu au noir des raccords de boucle (0 = image, 1 = noir), ajouté au « dip » de l'étalonnage.
var fade_dip: float = 0.0
# Sources des clips de la scène (nom complet « clip@Perso » → source), générées à la construction.
var sources: Dictionary = {}
var _steps: Array = []
var _event_cursor: int = 0
var _last_beat: String = ""
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _shown: bool = false
var _first_beat: bool = true
var _roots: Dictionary = {}

# --- À redéfinir --------------------------------------------------------------

# Étapes de construction (une par image) : décor, acteurs, accessoires.
func build_steps() -> Array:
	return []

# Remise à zéro de l'état du décor au début de chaque temps fort.
func reset_state() -> void :
	pass

# Logique image par image du temps fort en cours (accessoires, lumières).
func update(_beat_id: String, _t: float, _dt: float) -> void :
	pass

# Après l'animation des acteurs (accessoires posés sur une main, par exemple).
func after_animate(_beat_id: String, _t: float, _dt: float) -> void :
	pass

# --- Construction -------------------------------------------------------------

func setup(owner_engine: Node) -> void :
	engine = owner_engine
	_rng.randomize()
	visible = false
	_steps = build_steps()
	# Les clips se génèrent une fois les acteurs construits (mesures du squelette), un par image.
	_steps.append(_queue_clips)
	_steps.append(_finish_build)

func build_next() -> bool:
	if built: return true
	if _steps.is_empty(): return true
	var step: Callable = _steps.pop_front()
	step.call()
	return built

func _queue_clips() -> void :
	var rigs: Dictionary = {}
	for key: String in actors: rigs[key] = AnimTake.rig_of(actors[key])
	var writers: Array = AnimSetMenu.writers(id, rigs)
	var at: int = 0
	for writer: Callable in writers:
		_steps.insert(at, _write_clips.bind(writer))
		at += 1

func _write_clips(writer: Callable) -> void :
	var made: Dictionary = writer.call()
	AnimSetMenu.install(made)
	sources.merge(made, true)

func _finish_build() -> void :
	built = true

func actor(key: String, person: String, at: Vector3, yaw_deg: float = 0.0) -> PaperVisual:
	var visual: PaperVisual = PaperVisual.new()
	visual.lod_enabled = false
	visual.fidgets = false
	add_child(visual)
	visual.setup(person)
	visual.position = at
	visual.rotation.y = deg_to_rad(yaw_deg)
	_quiet_idle(visual)
	actors[key] = visual
	homes[key] = [at, deg_to_rad(yaw_deg)]
	return visual

# La pose de repos du jeu (balancement, report du poids, petits sauts de Simon) reste
# sous les clips : on la fige pour que seuls les clips écrits pour la scène bougent le corps.
static func _quiet_idle(visual: PaperVisual) -> void :
	var style: Variant = visual.get("_style")
	if style is Dictionary:
		var quiet: Dictionary = (style as Dictionary).duplicate()
		quiet["contra"] = 0.0
		quiet["idle_sway"] = 0.0
		quiet["idle_bounce"] = 0.0
		quiet["head_tilt"] = 0.0
		quiet["look_rate"] = 0.0
		visual.set("_style", quiet)
	visual.set("_weight_side", 0.0)
	visual.set("_weight_target", 0.0)

static func set_layers(node: Node, mask: int) -> void :
	if node is VisualInstance3D: (node as VisualInstance3D).layers = mask
	for child: Node in node.get_children(): set_layers(child, mask)

# --- Temps forts --------------------------------------------------------------

func enter() -> void :
	_shown = true
	_first_beat = true
	_start_beat(_pick_beat())

func leave() -> void :
	_shown = false

func _pick_beat(among: Array = []) -> Dictionary:
	if beats.is_empty(): return {}
	if not forced_beat.is_empty():
		for candidate: Dictionary in beats:
			if str(candidate.id) == forced_beat: return candidate
	var pool: Array = []
	if among.is_empty(): pool = beats.filter(func(b: Dictionary) -> bool: return str(b.id) != _last_beat and float(b.get("weight", 1.0)) > 0.0)
	else: pool = beats.filter(func(b: Dictionary) -> bool: return among.has(str(b.id)) and (str(b.id) != _last_beat or among.size() == 1))
	if pool.is_empty(): pool = beats.filter(func(b: Dictionary) -> bool: return float(b.get("weight", 1.0)) > 0.0)
	if pool.is_empty(): pool = beats.duplicate()
	var total: float = 0.0
	for candidate: Dictionary in pool: total += maxf(float(candidate.get("weight", 1.0)), 0.001)
	var roll: float = _rng.randf() * total
	for candidate: Dictionary in pool:
		roll -= maxf(float(candidate.get("weight", 1.0)), 0.001)
		if roll <= 0.0: return candidate
	return pool[pool.size() - 1]

func _start_beat(next: Dictionary) -> void :
	beat = next
	beat_time = 0.0
	beat_count += 1
	_event_cursor = 0
	_roots.clear()
	if beat.is_empty(): return
	_last_beat = str(beat.id)
	reset_state()
	var places: Dictionary = beat.get("homes", {})
	var clips: Dictionary = beat.get("clips", {})
	for key: String in actors:
		var visual: PaperVisual = actors[key]
		var home: Array = places.get(key, homes[key])
		visual.position = home[0]
		visual.rotation.y = float(home[1])
		visual.visible = not (beat.get("hidden", []) as Array).has(key)
		if clips.has(key):
			var full: String = str(clips[key]) + "@" + str(visual.character_name)
			var source: Dictionary = sources.get(full, {})
			if source.has("root"): _roots[key] = source.root
			visual.play(str(clips[key]))
	_place_roots()
	_apply_visibility()
	_update_fade()

func tick(dt: float) -> void :
	if beat.is_empty(): return
	beat_time += dt
	var length: float = float(beat.len)
	if beat_time >= length:
		var carry: float = beat_time - length
		var following: Variant = beat.get("next", "")
		var chosen: Dictionary = {}
		if following is Array and not (following as Array).is_empty(): chosen = _pick_beat(following)
		elif following is String and not (following as String).is_empty():
			for candidate: Dictionary in beats:
				if str(candidate.id) == following: chosen = candidate
		_first_beat = false
		_start_beat(chosen if not chosen.is_empty() else _pick_beat())
		beat_time = carry
	var events: Array = beat.get("events", [])
	while _event_cursor < events.size() and float(events[_event_cursor][0]) <= beat_time:
		(events[_event_cursor][1] as Callable).call()
		_event_cursor += 1
	update(str(beat.id), beat_time, dt)
	_place_roots()
	_apply_visibility()
	var hidden: Array = beat.get("hidden", [])
	for key: String in actors:
		# Un acteur caché le temps d'un plan continue son clip (il réapparaît au bon instant).
		if hidden.has(key): continue
		(actors[key] as PaperVisual).animate(dt, Vector3.ZERO, false, false)
	_apply_reaches()
	after_animate(str(beat.id), beat_time, dt)
	_update_fade()

# Avance sans rendu (captures, retour sur un temps fort précis).
func fast_forward(seconds: float, step: float = 1.0 / 30.0) -> void :
	var left: float = seconds
	while left > 0.0001:
		var dt: float = minf(step, left)
		tick(dt)
		left -= dt

func _place_roots() -> void :
	for key: String in _roots:
		var visual: PaperVisual = actors[key]
		var at: Array = AnimTake.root_sample(_roots[key], beat_time)
		visual.position = at[0]
		visual.rotation.y = float(at[1])

func _apply_visibility() -> void :
	var vis: Dictionary = beat.get("vis", {})
	for key: String in vis:
		if not actors.has(key): continue
		var shown: bool = (actors[key] as Node3D).visible
		for entry: Array in vis[key]:
			if float(entry[0]) <= beat_time: shown = bool(entry[1])
			else: break
		(actors[key] as Node3D).visible = shown

func _update_fade() -> void :
	var length: float = float(beat.get("len", 1.0))
	var fade_in: float = float(beat.get("fade_in", 0.0))
	var fade_out: float = float(beat.get("fade_out", 0.0))
	var dip: float = 0.0
	# Premier temps fort après le survol : la vignette apparaît déjà en fondu.
	if fade_in > 0.0 and not _first_beat: dip = 1.0 - smoothstep(0.0, fade_in, beat_time)
	if fade_out > 0.0: dip = maxf(dip, smoothstep(length - fade_out, length, beat_time))
	fade_dip = dip

# Contacts précis : la main d'un acteur rejoint une cible (prise d'un autre acteur, accessoire,
# point du décor) après l'animation, avec un fondu d'entrée et de sortie.
func _apply_reaches() -> void :
	for entry: Array in beat.get("reach", []):
		var visual: PaperVisual = actors.get(str(entry[0]))
		if visual == null or not visual.visible: continue
		var opts: Dictionary = entry[5] if entry.size() > 5 else {}
		var t0: float = float(entry[2])
		var t1: float = float(entry[3])
		if beat_time < t0 or beat_time > t1: continue
		var fade_in: float = float(opts.get("in", 0.15))
		var fade_out: float = float(opts.get("out", 0.15))
		var w: float = (1.0 if fade_in <= 0.0 else smoothstep(t0, t0 + fade_in, beat_time)) * (1.0 if fade_out <= 0.0 else 1.0 - smoothstep(t1 - fade_out, t1, beat_time))
		w *= float(opts.get("w", 1.0))
		if w <= 0.001: continue
		var target: Vector3 = _reach_point(entry[4], opts)
		if not target.is_finite(): continue
		var side: int = int(entry[1])
		var hand_node: Node3D = visual.get("_right_hand" if side > 0 else "_left_hand")
		var body: Node3D = visual.get("_body")
		if hand_node == null or body == null: continue
		var local: Vector3 = body.global_transform.affine_inverse() * target
		var wrist: Quaternion = hand_node.quaternion
		if opts.has("wrist"): wrist = wrist.slerp(Quaternion.from_euler(opts.wrist as Vector3), w)
		visual._hand_target_weighted(side, local, clampf(w, 0.0, 1.0), wrist, 1.0)
		visual._sync_now()

func _reach_point(target: Variant, opts: Dictionary) -> Vector3:
	var offset: Vector3 = _offset_at(opts.get("offset", Vector3.ZERO))
	if target is Vector3: return global_transform * ((target as Vector3) + offset)
	if target is Node3D: return (target as Node3D).global_transform * offset
	if target is Callable: return (target as Callable).call()
	if target is String:
		var parts: PackedStringArray = (target as String).split(":")
		var other: PaperVisual = actors.get(parts[0])
		if other == null: return Vector3.INF
		var base: Vector3 = other.socket_position(parts[1] if parts.size() > 1 else "chest")
		return base + other.global_transform.basis.orthonormalized() * offset
	return Vector3.INF

# Décalage fixe, ou piste [[t, décalage], ...] interpolée (les doigts qui travaillent sur un lacet).
func _offset_at(value: Variant) -> Vector3:
	if value is Vector3: return value
	if not value is Array or (value as Array).is_empty(): return Vector3.ZERO
	var keys: Array = value
	if beat_time <= float(keys[0][0]): return keys[0][1]
	for i: int in range(keys.size() - 1):
		var a: Array = keys[i]
		var b: Array = keys[i + 1]
		if beat_time < float(b[0]):
			var u: float = (beat_time - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.001)
			u = u * u * (3.0 - 2.0 * u)
			return (a[1] as Vector3).lerp(b[1] as Vector3, u)
	return keys[keys.size() - 1][1]

# --- Caméra -------------------------------------------------------------------

func camera() -> Dictionary:
	var keys: Array = beat.get("cam", [])
	if keys.is_empty(): return {}
	return sample_camera(keys, beat_time)

const NUMERIC: Dictionary = {"shake": 0.25, "x": 0.56, "roll": 0.0, "blur": 2.2, "frad": 0.3, "btop": 0.8}

func _resolve(value: Variant) -> Vector3:
	if value is Vector3: return value
	if value is Array:
		var base: Vector3 = _resolve((value as Array)[0])
		return base + ((value as Array)[1] as Vector3 if (value as Array).size() > 1 else Vector3.ZERO)
	if value is String:
		var parts: PackedStringArray = (value as String).split(":")
		var visual: PaperVisual = actors.get(parts[0])
		if visual == null: return Vector3.ZERO
		return to_local(visual.socket_position(parts[1] if parts.size() > 1 else "chest"))
	return Vector3.ZERO

func sample_camera(keys: Array, t: float) -> Dictionary:
	# Plan en cours : de la dernière clé « cut » jusqu'à la suivante.
	var start: int = 0
	for i: int in range(keys.size()):
		if float(keys[i][0]) > t: break
		if i > 0 and _opt(keys[i], "cut", false): start = i
	var stop: int = keys.size() - 1
	for i: int in range(start + 1, keys.size()):
		if _opt(keys[i], "cut", false):
			stop = i - 1
			break
	var count: int = stop - start + 1
	var eyes: Array = []
	var targets: Array = []
	var times: Array = []
	for i: int in range(start, stop + 1):
		times.append(float(keys[i][0]))
		eyes.append(_resolve(keys[i][1]))
		targets.append(_resolve(keys[i][2]))
	var seg: int = count - 1
	for i: int in range(count - 1):
		if t < float(times[i + 1]):
			seg = i
			break
	var out: Dictionary = {}
	if count == 1 or t <= float(times[0]) or seg >= count - 1:
		var index: int = 0 if count == 1 or t <= float(times[0]) else count - 1
		var key: Array = keys[start + index]
		out = {"eye": eyes[index], "target": targets[index], "fov": float(key[3])}
		for name: String in NUMERIC: out[name] = float(_opt(key, name, NUMERIC[name]))
		out["focus"] = _resolve(_opt(key, "focus", key[2]))
		return out
	var a: int = seg
	var b: int = seg + 1
	var ta: float = times[a]
	var tb: float = times[b]
	var span: float = maxf(tb - ta, 0.0001)
	var u: float = clampf((t - ta) / span, 0.0, 1.0)
	var ka: Array = keys[start + a]
	var kb: Array = keys[start + b]
	var linear: bool = _opt(ka, "linear", false)
	out["eye"] = _hermite(eyes, times, a, u, ka, kb, linear)
	out["target"] = _hermite(targets, times, a, u, ka, kb, linear)
	var w: float = u if linear else u * u * (3.0 - 2.0 * u)
	out["fov"] = lerpf(float(ka[3]), float(kb[3]), w)
	for name: String in NUMERIC:
		var fallback: float = NUMERIC[name]
		out[name] = lerpf(float(_opt(ka, name, fallback)), float(_opt(kb, name, _opt(ka, name, fallback))), w)
	out["focus"] = _resolve(_opt(ka, "focus", ka[2])).lerp(_resolve(_opt(kb, "focus", kb[2])), w)
	return out

func _hermite(values: Array, times: Array, a: int, u: float, ka: Array, kb: Array, linear: bool) -> Vector3:
	var pa: Vector3 = values[a]
	var pb: Vector3 = values[a + 1]
	if linear: return pa.lerp(pb, u)
	var span: float = float(times[a + 1]) - float(times[a])
	var ma: Vector3 = Vector3.ZERO
	var mb: Vector3 = Vector3.ZERO
	if a > 0 and not _opt(ka, "stop", false):
		ma = (pb - (values[a - 1] as Vector3)) / maxf(float(times[a + 1]) - float(times[a - 1]), 0.001)
	if a + 2 < values.size() and not _opt(kb, "stop", false):
		mb = ((values[a + 2] as Vector3) - pa) / maxf(float(times[a + 2]) - float(times[a]), 0.001)
	var u2: float = u * u
	var u3: float = u2 * u
	return pa * (2.0 * u3 - 3.0 * u2 + 1.0) + ma * (u3 - 2.0 * u2 + u) * span + pb * (-2.0 * u3 + 3.0 * u2) + mb * (u3 - u2) * span

static func _opt(key: Array, name: String, fallback: Variant) -> Variant:
	if key.size() < 5 or not key[4] is Dictionary: return fallback
	return (key[4] as Dictionary).get(name, fallback)

# --- Aides pour les sous-classes ----------------------------------------------

func hand(key: String, side: String = "right") -> Node3D:
	var visual: PaperVisual = actors.get(key)
	if visual == null: return null
	return visual.get("_right_hand" if side == "right" else "_left_hand") as Node3D

func attach(key: String, prop: Node3D, side: String = "right") -> void :
	var node: Node3D = hand(key, side)
	if node == null: return
	if prop.get_parent(): prop.get_parent().remove_child(prop)
	node.add_child(prop)

func detach(prop: Node3D, keep_world: bool = true) -> void :
	if prop.get_parent() == self: return
	var xform: Transform3D = global_transform.affine_inverse() * prop.global_transform
	if prop.get_parent(): prop.get_parent().remove_child(prop)
	add_child(prop)
	if keep_world: prop.transform = xform

func ev(t: float, callable: Callable) -> Array:
	return [t, callable]
