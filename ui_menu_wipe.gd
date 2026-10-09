extends Control





const T = preload("res://ui_theme.gd")

signal covered

var duration: float = 0.5
var _t: float = 1.0
var _dir: float = -1.0
var _covered_sent: bool = true
var _body: Color = Color("0b0d14")
var _edge: Color = T.RED
var _lead: PackedVector2Array = PackedVector2Array()
var _lead_paper: PackedVector2Array = PackedVector2Array()
var _trail: PackedVector2Array = PackedVector2Array()
var _trail_paper: PackedVector2Array = PackedVector2Array()
var _lead_line: PackedVector2Array = PackedVector2Array()
var _trail_line: PackedVector2Array = PackedVector2Array()

func _init() -> void :
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_process(false)

func _notification(what: int) -> void :
	if what == NOTIFICATION_RESIZED: _build()

func _build() -> void :
	_lead.clear()
	_lead_paper.clear()
	_trail.clear()
	_trail_paper.clear()
	var h: float = maxf(size.y, 1.0)
	var steps: int = 26


	for i: int in range(steps + 1):
		var y: float = h * float(i) / float(steps) - 10.0
		_lead.append(Vector2((T.noise(7, i) - 0.5) * 34.0 - 10.0 * sin(float(i) * 0.9), y))
	_lead_line = _lead.duplicate()
	_lead.append(Vector2(40, h + 10.0))
	_lead.append(Vector2(40, -10))

	for i: int in range(steps + 1):
		var y: float = h * float(i) / float(steps) - 10.0
		_lead_paper.append(Vector2((T.noise(7, i) - 0.5) * 34.0 - 10.0 * sin(float(i) * 0.9) - 9.0 - T.noise(3, i) * 6.0, y))
	for i: int in range(steps, -1, -1):
		var y: float = h * float(i) / float(steps) - 10.0
		_lead_paper.append(Vector2((T.noise(7, i) - 0.5) * 34.0 - 10.0 * sin(float(i) * 0.9) + 2.0, y))

	for i: int in range(steps + 1):
		var y: float = h * float(i) / float(steps) - 10.0
		_trail.append(Vector2((T.noise(23, i) - 0.5) * 28.0, y))
	_trail_line = _trail.duplicate()
	_trail.append(Vector2(-40, h + 10.0))
	_trail.append(Vector2(-40, -10))
	for i: int in range(steps + 1):
		var y: float = h * float(i) / float(steps) - 10.0
		_trail_paper.append(Vector2((T.noise(23, i) - 0.5) * 28.0 + 7.0 + T.noise(9, i) * 5.0, y))
	for i: int in range(steps, -1, -1):
		var y: float = h * float(i) / float(steps) - 10.0
		_trail_paper.append(Vector2((T.noise(23, i) - 0.5) * 28.0 - 2.0, y))


func play(direction: float, alice: bool = false) -> void :
	if _lead.is_empty(): _build()
	_dir = direction
	_body = Color("140a10") if alice else Color("0b0d14")
	_edge = T.RED if alice else T.TEAL
	_t = 0.0
	_covered_sent = false
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)
	queue_redraw()

func busy() -> bool:
	return visible and _t < 1.0


func stop() -> void :
	if not visible: return
	_t = 1.0
	visible = false
	set_process(false)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not _covered_sent:
		_covered_sent = true
		covered.emit()

func _process(delta: float) -> void :
	_t = minf(1.0, _t + delta / duration)
	if not _covered_sent and _t >= 0.5:
		_covered_sent = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		covered.emit()
	queue_redraw()
	if _t >= 1.0:
		visible = false
		set_process(false)

func _draw() -> void :
	var w: float = size.x
	var h: float = size.y
	var span: float = w * 1.25


	var travel: float = _t + 0.035 * sin(_t * TAU)

	var lead: float = lerpf(w + 40.0, - span + w * -0.02, travel * 1.0)
	var start: float = lead
	var end: float = lead + span
	if _dir > 0.0:

		draw_set_transform(Vector2(w, 0), 0.0, Vector2(-1, 1))
	draw_rect(Rect2(Vector2(start + 30.0, -10.0), Vector2(end - start - 60.0, h + 20.0)), _body)

	var y: float = 30.0
	while y < h:
		draw_line(Vector2(start + 40.0, y), Vector2(end - 40.0, y), Color(0.3, 0.45, 0.75, 0.08), 1.0)
		y += 34.0
	var base_transform: Transform2D = Transform2D(0.0, Vector2(w, 0)).scaled_local(Vector2(-1, 1)) if _dir > 0.0 else Transform2D.IDENTITY
	draw_set_transform_matrix(base_transform * Transform2D(0.0, Vector2(start, 0)))
	draw_colored_polygon(_lead_paper, T.CREAM)
	draw_colored_polygon(_lead, _body)
	draw_polyline(_lead_line, Color(_edge, 0.9), 2.0, true)
	draw_set_transform_matrix(base_transform * Transform2D(0.0, Vector2(end, 0)))
	draw_colored_polygon(_trail_paper, T.CREAM)
	draw_colored_polygon(_trail, _body)
	draw_polyline(_trail_line, Color(_edge, 0.55), 1.5, true)
	draw_set_transform(Vector2.ZERO)

	var mid: float = (start + end) * 0.5
	if _dir > 0.0: mid = w - mid
	var font: Font = T.font("logo")
	var fs: int = int(h * 0.16)
	var label: String = "AFTERBELL"
	var width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, Vector2(mid - width * 0.5, h * 0.5 + fs * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.035))
	draw_set_transform(Vector2.ZERO)
