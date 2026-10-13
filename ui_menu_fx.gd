extends Node

# Animation commune des menus (esprit Persona, version papier) :
# - l'élément sélectionné (souris, clavier ou manette) grossit avec un léger
#   dépassement et tremble un instant, puis son trait « frémit » (boil) ;
# - la ligne de réglage qui le contient s'allume (bande de surligneur) ;
# - les entrées d'une page arrivent en cascade (décalées, inclinées, avec
#   dépassement) ;
# - Decor : bande diagonale déchirée, mot géant incliné et ruban qui défile.
# Tout passe par des fonctions communes (ui.gd : _end_page, _form_panel,
# _setting_row…) : les boutons et lignes ajoutés plus tard héritent du style.
# « Réduire les flashs » : pas de tremblement, de boil ni de glissement,
# seulement des fondus courts.

const T = preload("res://ui_theme.gd")
const G = preload("res://ui_paper_geom.gd")
const C = preload("res://ui_collage.gd")
const Sound = preload("res://ui_sound.gd")

const BOIL_STEP: float = 0.125

var ui: Node
var reduced: bool = false
var _lit: WeakRef = weakref(null)
var _row: WeakRef = weakref(null)
var _springs: Dictionary = {}
var _entering: Array[Dictionary] = []
var _hooked: Dictionary = {}
var _boil_clock: float = 0.0
var _clock: float = 0.0


func setup(owner_ui: Node) -> void :
	ui = owner_ui
	name = "MenuFx"
	process_mode = Node.PROCESS_MODE_ALWAYS


func _scopes() -> Array:
	var result: Array = []
	if ui == null: return result
	for key: String in ["page", "overlay"]:
		var node: Variant = ui.get(key)
		if is_instance_valid(node): result.append(node)
	var world: Node = ui.get("world")
	if is_instance_valid(world):
		for key: String in ["controls_menu", "online_menu"]:
			var node: Variant = world.get(key)
			if is_instance_valid(node) and (node as Control).visible: result.append(node)
	return result


func _in_scope(control: Control) -> bool:
	for scope: Node in _scopes():
		if scope.is_ancestor_of(control): return true
	return false


func _pickable(control: Control) -> Control:
	var node: Node = control
	var depth: int = 0
	while node != null and depth < 4:
		if node is BaseButton or node is Range or node is LineEdit: return node as Control
		node = node.get_parent()
		depth += 1
	return control


func _process(delta: float) -> void :
	if ui == null: return
	reduced = bool(ui.get("reduced_motion"))
	G.calm = reduced
	_clock += delta
	var viewport: Viewport = get_viewport()
	var target: Control = null
	if viewport:
		target = viewport.gui_get_hovered_control() if T.pointer_mode else viewport.gui_get_focus_owner()
	if target != null:
		target = _pickable(target)
		if not target.is_visible_in_tree() or not _in_scope(target): target = null
	var current: Control = _lit.get_ref() as Control
	if target != current: _set_lit(current, target)
	_boil_clock += delta
	if _boil_clock >= BOIL_STEP:
		_boil_clock = fmod(_boil_clock, BOIL_STEP)
		if not reduced:
			G.boil_frame += 1
			if is_instance_valid(target) and target is BaseButton: target.queue_redraw()
	_update_springs(delta)
	_update_entering(delta)


func _owns_motion(control: Control) -> bool:
	return control.has_meta("fx_own") or control.has_method("refresh_highlight")


func _set_lit(previous: Control, next: Control) -> void :
	_lit = weakref(next)
	if is_instance_valid(previous) and _springs.has(previous.get_instance_id()):
		_springs[previous.get_instance_id()].target = 1.0
	var row: Control = _row.get_ref() as Control
	var next_row: Control = _row_of(next) if is_instance_valid(next) else null
	if row != next_row:
		if is_instance_valid(row): row.call("set_row_lit", false, reduced)
		if is_instance_valid(next_row):
			next_row.call("set_row_lit", true, reduced)
			# Survol d'une ligne à la souris : petit « tic » de curseur.
			if T.pointer_mode and not (next is BaseButton): Sound.play("hover")
		_row = weakref(next_row)
	if not is_instance_valid(next) or reduced: return
	if _owns_motion(next) or not (next is BaseButton) or (next is BaseButton and (next as BaseButton).disabled): return
	var id: int = next.get_instance_id()
	var grow: float = clampf(18.0 / maxf(next.size.x, 1.0), 0.02, 0.1)
	if not _springs.has(id): _springs[id] = {"node": weakref(next), "s": 1.0, "v": 0.0, "target": 1.0, "shake": 0.0}
	var spring: Dictionary = _springs[id]
	spring.target = 1.0 + grow
	spring.v = float(spring.v) + 2.2 * grow * 10.0
	spring.shake = 1.0


func _row_of(control: Control) -> Control:
	var node: Node = control
	var depth: int = 0
	while node != null and depth < 6:
		if node.has_method("set_row_lit"): return node as Control
		node = node.get_parent()
		depth += 1
	return null


func _update_springs(delta: float) -> void :
	if _springs.is_empty(): return
	var step: float = minf(delta, 1.0 / 30.0)
	for id: int in _springs.keys():
		var spring: Dictionary = _springs[id]
		var node: Control = (spring.node as WeakRef).get_ref() as Control
		if not is_instance_valid(node) or not node.is_inside_tree():
			_springs.erase(id)
			continue
		if reduced:
			node.scale = Vector2.ONE
			node.rotation = 0.0
			_springs.erase(id)
			continue
		var s: float = float(spring.s)
		var v: float = float(spring.v)
		var goal: float = float(spring.target)
		v += ((goal - s) * 520.0 - v * 24.0) * step
		s += v * step
		spring.s = s
		spring.v = v
		spring.shake = maxf(0.0, float(spring.shake) - delta / 0.16)
		var shake: float = float(spring.shake)
		node.pivot_offset = node.size * 0.5
		node.scale = Vector2(s, s)
		node.rotation = sin(_clock * 95.0) * 0.014 * shake * shake
		if is_equal_approx(goal, 1.0) and absf(s - 1.0) < 0.002 and absf(v) < 0.01 and shake <= 0.0:
			node.scale = Vector2.ONE
			node.rotation = 0.0
			_springs.erase(id)


# Fait entrer les enfants d'un conteneur en cascade.
func cascade_children(container: Node, delay: float = 0.0, step: float = 0.032, from: Vector2 = Vector2(-64, 0), tilt: float = -0.07, duration: float = 0.26, limit: int = 22) -> float:
	if not is_instance_valid(container): return delay
	var items: Array = []
	for child: Node in container.get_children():
		var control: Control = child as Control
		if control and control.visible and not control.has_meta("fx_no_cascade"): items.append(control)
	return cascade(items, delay, step, from, tilt, duration, limit)


func cascade(items: Array, delay: float = 0.0, step: float = 0.032, from: Vector2 = Vector2(-64, 0), tilt: float = -0.07, duration: float = 0.26, limit: int = 22) -> float:
	var at: float = delay
	var count: int = 0
	for item: Variant in items:
		var control: Control = item as Control
		if not is_instance_valid(control): continue
		for entry: Dictionary in _entering:
			if (entry.node as WeakRef).get_ref() == control: entry.done = true
		control.modulate.a = 0.0
		_entering.append({"node": weakref(control), "delay": at, "t": 0.0, "frames": 0, "from": from if not reduced else Vector2.ZERO, "tilt": tilt if not reduced else 0.0, "dur": duration if not reduced else 0.14, "base": Vector2.ZERO, "ready": false, "done": false})
		_hook(control.get_parent())
		count += 1
		if count < limit: at += step if not reduced else step * 0.4
	return at


func _hook(parent: Node) -> void :
	if not (parent is Container): return
	var id: int = parent.get_instance_id()
	if _hooked.has(id) and is_instance_valid(instance_from_id(id)): return
	if _hooked.size() > 160:
		for key: int in _hooked.keys():
			if not is_instance_valid(instance_from_id(key)): _hooked.erase(key)
	_hooked[id] = true
	(parent as Container).sort_children.connect(_on_sorted.bind(parent))


func _on_sorted(container: Node) -> void :
	for entry: Dictionary in _entering:
		if not bool(entry.ready) or bool(entry.done): continue
		var node: Control = (entry.node as WeakRef).get_ref() as Control
		if is_instance_valid(node) and node.get_parent() == container:
			entry.base = node.position
			entry.base_rot = 0.0 if not node.has_method("_apply_pose") else float(entry.get("base_rot", 0.0))
			_apply_entry(entry, node)


func _update_entering(delta: float) -> void :
	if _entering.is_empty(): return
	var keep: Array[Dictionary] = []
	for entry: Dictionary in _entering:
		var node: Control = (entry.node as WeakRef).get_ref() as Control
		if not is_instance_valid(node) or not node.is_inside_tree():
			continue
		if bool(entry.done):
			continue
		entry.frames = int(entry.frames) + 1
		entry.t = float(entry.t) + delta
		if int(entry.frames) < 2 or float(entry.t) < float(entry.delay):
			node.modulate.a = 0.0
			keep.append(entry)
			continue
		if not bool(entry.ready):
			entry.ready = true
			entry.base = node.position
			entry.base_rot = node.rotation
		_apply_entry(entry, node)
		if float(entry.t) - float(entry.delay) >= float(entry.dur):
			_finish_entry(entry, node)
			continue
		keep.append(entry)
	_entering = keep


func _apply_entry(entry: Dictionary, node: Control) -> void :
	var p: float = clampf((float(entry.t) - float(entry.delay)) / maxf(0.001, float(entry.dur)), 0.0, 1.0)
	var back: float = 1.0 + 2.4 * pow(p - 1.0, 3.0) + 1.4 * pow(p - 1.0, 2.0)
	var smooth: float = 1.0 - pow(1.0 - p, 3.0)
	node.modulate.a = clampf(p * 3.0, 0.0, 1.0)
	node.position = entry.base + (entry.from as Vector2) * (1.0 - back)
	if not node.has_method("_apply_pose"): node.pivot_offset = Vector2(0.0, node.size.y * 0.5)
	node.rotation = float(entry.get("base_rot", 0.0)) + float(entry.tilt) * (1.0 - smooth)


func _finish_entry(entry: Dictionary, node: Control) -> void :
	if bool(entry.ready): node.position = entry.base
	node.rotation = float(entry.get("base_rot", 0.0))
	node.modulate.a = 1.0
	# Widgets qui gèrent leur propre pose (cartes de personnage…).
	if node.has_method("_apply_pose"): node.call("_apply_pose")


# Termine immédiatement toutes les entrées (changement de page brutal).
func finish_all() -> void :
	for entry: Dictionary in _entering:
		var node: Control = (entry.node as WeakRef).get_ref() as Control
		if is_instance_valid(node): _finish_entry(entry, node)
	_entering.clear()



# Décor de fond d'une page de menu : bande diagonale déchirée, mot géant qui
# dérive, ruban de scotch qui défile. Entre en balayant ; immobile seulement
# avec « Réduire les flashs ».
class Decor extends Control:
	var title: String = ""
	var accent: Color = T.RED
	var ribbon_text: String = "PAPER AFTERBELL"
	var reduced: bool = false
	var side: float = 1.0
	var giant_alpha: float = 0.085
	var band_alpha: float = 0.55
	var band_low: float = 0.18
	# Bande personnalisée (fractions de l'écran) ; band_fill.a > 0 remplace
	# la couleur dérivée de l'accent.
	var band_a: Vector2 = Vector2(-1, -1)
	var band_b: Vector2 = Vector2(-1, -1)
	var band_width: float = 250.0
	var band_fill: Color = Color(0, 0, 0, 0)
	# Attente avant l'entrée (le temps que la transition couvre l'écran).
	var start_delay: float = 0.0
	var _time: float = 0.0
	var _enter: float = 0.0

	func _init() -> void :
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void :
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_enter = 1.0 if reduced else 0.0

	# Même page reconstruite : le décor reprend où il en était (déjà entré,
	# ruban et mot géant à la même position).
	func resume_at(time: float) -> void :
		_time = time
		_enter = 1.0
		start_delay = 0.0
		queue_redraw()

	func _process(delta: float) -> void :
		if start_delay > 0.0:
			start_delay -= delta
			queue_redraw()
			return
		_time += delta
		if _enter < 1.0: _enter = minf(1.0, _enter + delta / 0.38)
		queue_redraw()
		# Immobile avec « Réduire les flashs » : inutile de redessiner.
		if (reduced or G.calm) and _enter >= 1.0: set_process(false)

	func _draw() -> void :
		var view: Vector2 = size
		if view.x < 10.0 or start_delay > 0.0: return
		var k: float = view.y / 900.0
		var e: float = 1.0 - pow(1.0 - _enter, 3.0)
		var motion: float = 0.0 if reduced or G.calm else 1.0
		var item: RID = get_canvas_item()
		# Bande diagonale déchirée (couleur de la page), balaie depuis le bas.
		var from: Vector2 = Vector2(view.x * (band_low if side > 0.0 else 1.0 - band_low), view.y + 90.0)
		var to: Vector2 = Vector2(view.x * (1.1 if side > 0.0 else -0.1), - view.y * 0.05)
		if band_a.x > -0.5:
			from = band_a * view
			to = band_b * view
		var tip: Vector2 = from.lerp(to, e)
		if band_alpha > 0.0 and tip.distance_to(from) > 4.0:
			var shape: PackedVector2Array = G.band(from, tip, band_width * k, 61, 20.0)
			G.polygon(item, G.offset(shape, Vector2(14, 18) * k), Color(0, 0, 0, 0.4 * band_alpha))
			G.polygon(item, shape, band_fill if band_fill.a > 0.0 else Color(accent.darkened(0.5), band_alpha))
			var normal: Vector2 = (to - from).normalized().orthogonal()
			var half: float = band_width * k * 0.5
			G.polygon(item, G.band(from + normal * (half + 12.0 * k), tip + normal * (half + 12.0 * k), 12.0 * k, 67, 4.0), Color(T.CREAM, minf(0.5, 0.22 * band_alpha / 0.55)))
			G.polygon(item, G.band(from - normal * (half + 8.0 * k), tip - normal * (half + 8.0 * k), 18.0 * k, 71, 5.0), Color(accent, minf(0.95, 0.75 * band_alpha / 0.55)))
		# Ruban de scotch qui défile en continu.
		if not ribbon_text.is_empty():
			var ribbon_from: Vector2 = Vector2(-60.0, view.y * 0.075 + 70.0 * k)
			var ribbon_to: Vector2 = Vector2(view.x + 60.0, view.y * 0.075 - 60.0 * k)
			C.draw_ribbon(self, ribbon_from, ribbon_from.lerp(ribbon_to, e), 28.0 * k, T.tr_text(ribbon_text), _time * 52.0 * motion, Color(T.CREAM, 0.12), Color(T.CREAM, 0.42), 9)
		# Mot géant incliné qui dérive lentement.
		if not title.is_empty() and giant_alpha > 0.0:
			var fs: int = int(290.0 * k)
			var drift: float = sin(_time * 0.33) * 24.0 * motion - (1.0 - e) * 300.0 * side
			var shown: String = T.tr_text(title).to_upper()
			var at: Vector2 = Vector2(view.x * (0.36 if side > 0.0 else 0.02) + drift, view.y * 1.0)
			C.draw_giant(self, shown, at + Vector2(12, 14) * k, fs, -0.11, Color(accent, giant_alpha * 0.9 * e))
			C.draw_giant(self, shown, at, fs, -0.11, Color(T.CREAM, giant_alpha * e))
