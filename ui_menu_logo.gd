extends Control





const T = preload("res://ui_theme.gd")
const Sound = preload("res://ui_sound.gd")
const TITLE: String = "AFTERBELL"

var reduced_motion: bool = false
var compact: bool = false

static var intro_seen: bool = false

var _time: float = 0.0
var _duration: float = 1.35
var _glitch_wait: float = 5.0
var _glitch: float = 0.0
var _glitch_seed: int = 0
var _strip: PackedVector2Array = PackedVector2Array()
var _tear: PackedVector2Array = PackedVector2Array()
var _tagline: Label
var _tag_clip: Control
var _stamped: bool = false
var _intro_done: bool = false

func _init() -> void :
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func configure(tagline_text: String, is_compact: bool, reduced: bool) -> void :
	compact = is_compact
	reduced_motion = reduced
	custom_minimum_size = Vector2(500 if compact else 580, 170 if compact else 212)
	_tag_clip = Control.new()
	_tag_clip.clip_contents = true
	_tag_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tag_clip)
	_tagline = Label.new()
	_tagline.text = tagline_text
	_tagline.add_theme_font_override("font", T.font("hand"))
	_tagline.add_theme_font_size_override("font_size", 30 if compact else 36)
	_tagline.add_theme_color_override("font_color", T.RED)
	_tagline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tag_clip.add_child(_tagline)
	_tag_clip.rotation_degrees = -2.2
	if reduced or intro_seen:
		_duration = 0.45 if not reduced else 0.0
	intro_seen = true
	resized.connect(_build)
	_build()
	set_process(true)

func _title_size() -> int:
	return 84 if compact else 104

func _strip_rect() -> Rect2:
	var top: float = 38.0 if compact else 46.0
	var height: float = 96.0 if compact else 118.0
	return Rect2(Vector2(0, top), Vector2(size.x * 0.97, height))

func _build() -> void :
	_strip.clear()
	_tear.clear()
	var r: Rect2 = _strip_rect()
	var steps: int = 36

	for i: int in range(steps + 1):
		var t: float = float(i) / float(steps)
		_strip.append(Vector2(r.position.x + r.size.x * t, r.position.y + (T.noise(13, i) - 0.5) * 5.0 + t * -6.0))
	for i: int in range(6):
		_strip.append(Vector2(r.end.x + (T.noise(19, i) - 0.5) * 14.0, r.position.y - 6.0 + r.size.y * float(i + 1) / 7.0))
	for i: int in range(steps, -1, -1):
		var t: float = float(i) / float(steps)
		_strip.append(Vector2(r.position.x + r.size.x * t, r.end.y + (T.noise(29, i) - 0.5) * 9.0 + t * -6.0))

	for i: int in range(9):
		_tear.append(Vector2((T.noise(31, i) - 0.5) * 16.0, r.position.y - 8.0 + (r.size.y + 16.0) * float(i) / 8.0))
	_tear.append(Vector2(-10, r.end.y + 8.0))
	_tear.append(Vector2(-10, r.position.y - 8.0))
	if _tagline:
		_tag_clip.position = Vector2(8, r.end.y + 6.0)
		_tagline.position = Vector2.ZERO
		_tagline.size = _tagline.get_combined_minimum_size()
	queue_redraw()

func _process(delta: float) -> void :
	_time += delta
	var intro: bool = _time <= _duration + 0.05
	if intro:
		var tagline_t: float = clampf((_time - _duration * 0.62) / maxf(0.01, _duration * 0.38), 0.0, 1.0) if _duration > 0.0 else 1.0
		if _tagline:
			var full: Vector2 = _tagline.get_combined_minimum_size()
			_tag_clip.size = Vector2(full.x * ease(tagline_t, 0.7) + 4.0, full.y + 6.0)
		if not _stamped and _progress(0.55) >= 1.0:
			_stamped = true
			if _duration > 0.5: Sound.play("click")
		queue_redraw()
		return
	if not _intro_done:

		_intro_done = true
		if _tagline: _tag_clip.size = _tagline.get_combined_minimum_size() + Vector2(60.0, 6.0)
	if reduced_motion:
		set_process(false)
		return
	_glitch_wait -= delta
	if _glitch_wait <= 0.0:
		_glitch_wait = randf_range(4.5, 9.0)
		_glitch = randf_range(0.1, 0.2)
	if _glitch > 0.0:
		_glitch -= delta
		_glitch_seed = int(_time * 30.0)
		queue_redraw()
		if _glitch <= 0.0: queue_redraw()


func _progress(start: float, length: float = 0.3) -> float:
	if _duration <= 0.0: return 1.0
	return clampf((_time / _duration - start) / length, 0.0, 1.0)

func _draw() -> void :
	var r: Rect2 = _strip_rect()
	var unroll: float = ease(_progress(0.0, 0.5), 0.35)
	var front: float = r.size.x * unroll
	var angle: float = deg_to_rad(-1.2)
	draw_set_transform(Vector2(0, 0), angle, Vector2.ONE)


	if unroll > 0.0:
		draw_set_transform(Vector2(4, 8), angle, Vector2(unroll, 1.0))
		draw_colored_polygon(_strip, Color(0, 0, 0, 0.4))
		draw_set_transform(Vector2.ZERO, angle, Vector2(unroll, 1.0))
		draw_colored_polygon(_strip, T.CREAM)

		var y: float = r.position.y + 26.0
		while y < r.end.y - 6.0:
			draw_line(Vector2(6, y), Vector2(r.size.x - 8.0, y), Color(0.2, 0.32, 0.45, 0.13), 1.0)
			y += 22.0
		draw_line(Vector2(34, r.position.y + 2.0), Vector2(34, r.end.y - 2.0), Color(0.78, 0.2, 0.28, 0.35), 1.5)
		draw_set_transform(Vector2.ZERO, angle, Vector2.ONE)

	var font: Font = T.font("logo")
	var fs: int = _title_size()
	var baseline: float = r.position.y + r.size.y * 0.5 + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5 + 2.0
	var x: float = 46.0
	var glitch: bool = _glitch > 0.0
	for i: int in range(TITLE.length()):
		var ch: String = TITLE[i]
		var advance: float = font.get_char_size(TITLE.unicode_at(i), fs).x + 3.0
		var local: float = _progress(0.12 + float(i) * 0.035, 0.18)
		if local > 0.0 and x < front + 20.0:
			var drop: float = (1.0 - ease(local, 0.4)) * -26.0
			var pos: Vector2 = Vector2(x, baseline + drop)
			if glitch:
				var off: float = (T.noise(_glitch_seed, i) - 0.5) * 10.0
				draw_string(font, pos + Vector2(off + 4.0, 0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.9, 0.12, 0.25, 0.7))
				draw_string(font, pos + Vector2(off - 4.0, 1), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.2, 0.85, 0.95, 0.55))
			draw_string(font, pos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(T.INK_TEXT, ease(local, 0.5)))
		x += advance

	if unroll > 0.0 and unroll < 1.0:
		draw_set_transform(Vector2(front, 0), angle, Vector2.ONE)
		draw_colored_polygon(_tear, Color("fbf6ea"))
		draw_set_transform(Vector2.ZERO, angle, Vector2.ONE)

	var stamp: float = _progress(0.55, 0.18)
	if stamp > 0.0:
		var s: float = lerpf(1.8, 1.0, ease(stamp, 0.35))
		var center: Vector2 = Vector2(118.0 if not compact else 100.0, r.position.y - 4.0)
		draw_set_transform(center, deg_to_rad(-6.0), Vector2(s, s))
		var caps: Font = T.font("caps_wide")
		var cs: int = 24 if compact else 28
		var text_w: float = caps.get_string_size("PAPER", HORIZONTAL_ALIGNMENT_LEFT, -1, cs).x
		var box: Rect2 = Rect2(Vector2( - text_w * 0.5 - 14.0, - cs * 0.8), Vector2(text_w + 28.0, cs * 1.6))
		var ink: Color = Color(T.RED, 0.95 * stamp)
		draw_rect(box, Color(0.06, 0.04, 0.07, 0.85 * stamp))
		draw_rect(box, ink, false, 3.0)
		draw_rect(box.grow(-4.0), Color(ink, ink.a * 0.6), false, 1.0)
		draw_string(caps, Vector2( - text_w * 0.5, (caps.get_ascent(cs) - caps.get_descent(cs)) * 0.5), "PAPER", HORIZONTAL_ALIGNMENT_LEFT, -1, cs, ink)
	draw_set_transform(Vector2.ZERO)
