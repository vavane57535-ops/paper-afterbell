extends Control
class_name PaperIntroOverlay

# Calque 2D du prologue : boîte de dialogue façon Undertale (portrait, nom, texte tapé lettre par
# lettre avec un « blip » synthétisé par lettre et par personnage), carton de chapitre, éclairs plein
# écran, jauge « Maintenir pour passer » et carton-titre final (logo du jeu + visage de Yiero).
# Le film appelle les setters à chaque image ; tout l'affichage est fonction du temps du film.

const T = preload("res://ui_theme.gd")
const Logo = preload("res://ui_menu_logo.gd")

const NAMES: Dictionary = {"Simon": "SIMON", "Ashura": "ASHURA", "Yiero": "YIERO", "Usayuko": "USAYUKO", "Elly": "ELLY", "Bleuette": "BLEUETTE", "Lysia": "LYSIA", "Alice": "ALICE"}
const TINTS: Dictionary = {"Simon": Color("dccbff"), "Ashura": Color("9fe0ee"), "Yiero": Color("ff4a3a"), "Usayuko": Color("ffd98a"), "Elly": Color("b9f3f5"), "Bleuette": Color("a9c8ff"), "Lysia": Color("a6f0d8"), "Alice": Color("ff5a78")}

# Voix synthétisées (pas de voix humaines) : [fréquence Hz, durée s, forme, variation de hauteur]
const VOICES: Dictionary = {
	"Simon": [640.0, 0.034, "square", 0.09],
	"Ashura": [300.0, 0.052, "triangle", 0.05],
	"Yiero": [72.0, 0.12, "demon", 0.12],
	"Usayuko": [250.0, 0.044, "square", 0.08],
	"Elly": [540.0, 0.048, "sine", 0.04],
	"Bleuette": [860.0, 0.036, "sine", 0.1],
	"Lysia": [430.0, 0.045, "robot", 0.03],
	"Alice": [180.0, 0.06, "triangle", 0.06],
}

var _line_who: String = ""
var _line_text: String = ""
var _line_shown: int = 0
var _line_alpha: float = 0.0
var _line_shout: bool = false
var _raise: float = 0.0
var _chapter_text: String = ""
var _chapter_alpha: float = 0.0
var _flash: Color = Color(0, 0, 0, 0)
var _skip_progress: float = 0.0
var _skip_alpha: float = 0.0
var _title_alpha: float = 0.0
var _face_alpha: float = 0.0
var _face_grin: float = 0.0
var _face_look: Vector2 = Vector2.ZERO
var _sub_text: String = ""
var _sub_shown: int = 0
var _sub_alpha: float = 0.0
var _clock: float = 0.0
var _logo: Control
var _portraits: Dictionary = {}
var _blips: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var volume: float = 1.0
var muted: bool = false
var bar: float = 0.0

func setup() -> void :
	name = "PrologueOverlay"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_logo = Logo.new()
	add_child(_logo)
	_logo.configure("", false, true)
	_logo.set_process(false)
	_logo.set("_duration", 1.35)
	_logo.hide()
	var bus: StringName = &"PaperFeedback" if AudioServer.get_bus_index(&"PaperFeedback") >= 0 else &"Master"
	for i: int in range(8):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = bus
		add_child(player)
		_players.append(player)
	for who: String in VOICES:
		_blips[who] = _make_blips(who)
	for person: String in NAMES:
		var texture: Texture2D = PaperStatusIcon.portrait_for(person) if person != "Yiero" else null
		if texture: _portraits[person] = texture
	hide()




func _make_blips(who: String) -> Array:
	var voice: Array = VOICES[who]
	var out: Array = []
	var rate: int = 22050
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(who)
	for variant: int in range(4):
		var freq: float = float(voice[0]) * (1.0 + (float(variant) - 1.5) * float(voice[3]) * 0.66)
		var length: float = float(voice[1])
		var samples: int = int(rate * length)
		var data: PackedByteArray = PackedByteArray()
		data.resize(samples * 2)
		var phase: float = 0.0
		var phase2: float = 0.0
		for i: int in range(samples):
			var t: float = float(i) / float(rate)
			var env: float = minf(1.0, t / 0.003) * pow(1.0 - float(i) / float(samples), 1.6)
			phase += freq / float(rate)
			var v: float = 0.0
			match str(voice[2]):
				"square": v = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0;v *= 0.42
				"triangle": v = (absf(fmod(phase, 1.0) * 4.0 - 2.0) - 1.0) * 0.6
				"sine": v = sin(phase * TAU) * 0.7
				"robot":
					var sq: float = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
					v = sq * sin(t * TAU * 61.0) * 0.55
					v = floor(v * 4.0) / 4.0
				"demon":
					phase2 += freq * 0.5 / float(rate)
					var saw: float = fmod(phase, 1.0) * 2.0 - 1.0
					var sub: float = sin(phase2 * TAU)
					var growl: float = 1.0 + 0.5 * sin(t * TAU * 23.0)
					v = (saw * 0.55 + sub * 0.7) * growl + (rng.randf() - 0.5) * 0.35
					v = clampf(v * 1.8, -1.0, 1.0) * 0.75
					env = minf(1.0, t / 0.008) * pow(1.0 - float(i) / float(samples), 0.9)
			var s: int = int(clampf(v * env, -1.0, 1.0) * 30000.0)
			data.encode_s16(i * 2, s)
		var stream: AudioStreamWAV = AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = rate
		stream.stereo = false
		stream.data = data
		out.append(stream)
	return out

func blip(who: String) -> void :
	if muted or volume <= 0.001 or not _blips.has(who) or _players.is_empty(): return
	var variants: Array = _blips[who]
	var player: AudioStreamPlayer = _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	player.stream = variants[_rng.randi_range(0, variants.size() - 1)]
	player.volume_db = linear_to_db(maxf(0.0001, volume * (0.55 if who != "Yiero" else 0.95)))
	player.pitch_scale = _rng.randf_range(0.97, 1.03)
	player.play()




func set_line(who: String, text: String, shown: int, alpha: float, shout: bool = false) -> void :
	_line_who = who;_line_text = text;_line_shown = shown;_line_alpha = alpha;_line_shout = shout

func set_raise(pixels: float) -> void :
	_raise = pixels

func set_chapter(text: String, alpha: float) -> void :
	_chapter_text = text;_chapter_alpha = alpha

func set_flash(color: Color) -> void :
	_flash = color

func set_skip(progress: float, alpha: float) -> void :
	_skip_progress = progress;_skip_alpha = alpha

func set_title(title_alpha: float, logo_time: float, face_alpha: float, grin: float, sub_text: String, sub_shown: int, sub_alpha: float, look: Vector2 = Vector2.ZERO) -> void :
	_title_alpha = title_alpha;_face_alpha = face_alpha;_face_grin = grin
	_sub_text = sub_text;_sub_shown = sub_shown;_sub_alpha = sub_alpha;_face_look = look
	_logo.visible = title_alpha > 0.001
	if _logo.visible:
		_logo.set("_time", logo_time)
		_logo.modulate.a = title_alpha
		var view: Vector2 = size
		var scale_value: float = clampf(view.x / 1280.0, 0.6, 1.6) * 1.25
		_logo.scale = Vector2(scale_value, scale_value)
		_logo.size = _logo.custom_minimum_size
		_logo.position = Vector2(view.x * 0.5 - _logo.size.x * scale_value * 0.5 + 10.0 * scale_value, view.y * 0.5 - _logo.size.y * scale_value * 0.62)
		_logo.queue_redraw()

func tick(delta: float) -> void :
	_clock += delta
	queue_redraw()

func reset() -> void :
	_line_alpha = 0.0;_chapter_alpha = 0.0;_flash = Color(0, 0, 0, 0);_skip_alpha = 0.0
	_title_alpha = 0.0;_face_alpha = 0.0;_sub_alpha = 0.0
	if _logo: _logo.hide()
	queue_redraw()




func _draw() -> void :
	var view: Vector2 = size
	if _flash.a > 0.002: draw_rect(Rect2(Vector2(0, bar), Vector2(view.x, maxf(0.0, view.y - bar * 2.0))), _flash)
	if _face_alpha > 0.002: _draw_yiero_face(Vector2(view.x * 0.5, view.y * 0.4), view.y * 0.0009, _face_alpha, _face_grin, _face_look)
	if _sub_alpha > 0.002 and not _sub_text.is_empty(): _draw_subtitle(view)
	if _chapter_alpha > 0.002 and not _chapter_text.is_empty(): _draw_chapter(view)
	if _line_alpha > 0.002 and not _line_text.is_empty(): _draw_box(view)
	if _skip_alpha > 0.002: _draw_skip(view)


func _draw_chapter(view: Vector2) -> void :
	var font: Font = T.font("hand")
	var fs: int = int(clampf(view.y * 0.06, 28.0, 64.0))
	var text: String = PaperLanguage.t(_chapter_text)
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, Vector2(view.x * 0.5 - width * 0.5, view.y * 0.5 + fs * 0.3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.92, 0.86, 0.78, _chapter_alpha))


func _wrap(text: String, font: Font, fs: int, width: float) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var current: String = ""
	for word: String in text.split(" "):
		var attempt: String = word if current.is_empty() else current + " " + word
		if font.get_string_size(attempt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width and not current.is_empty():
			lines.append(current)
			current = word
		else:
			current = attempt
	if not current.is_empty(): lines.append(current)
	return lines


func _draw_box(view: Vector2) -> void :
	var alpha: float = _line_alpha
	var scale_value: float = clampf(view.y / 720.0, 0.75, 2.0)
	var width: float = minf(980.0 * scale_value, view.x - 60.0)
	var height: float = 132.0 * scale_value
	var shake: Vector2 = Vector2.ZERO
	if _line_shout: shake = Vector2(sin(_clock * 61.0), cos(_clock * 53.0)) * 3.0 * scale_value
	var box: Rect2 = Rect2(Vector2(view.x * 0.5 - width * 0.5, view.y - height - 16.0 * scale_value - _raise * scale_value) + shake, Vector2(width, height))
	draw_rect(box, Color(0, 0, 0, 0.93 * alpha))
	var border: float = 4.0 * scale_value
	draw_rect(box.grow(- border * 0.5), Color(1, 1, 1, alpha), false, border)
	var tint: Color = TINTS.get(_line_who, Color.WHITE)
	var portrait_size: float = height - 24.0 * scale_value
	var portrait: Rect2 = Rect2(box.position + Vector2(14.0, 12.0) * scale_value, Vector2(portrait_size, portrait_size))
	if _line_who == "Yiero":
		draw_rect(portrait, Color(0, 0, 0, alpha))
		_draw_yiero_face(portrait.get_center() + Vector2(0, - portrait_size * 0.06), portrait_size * 0.00104, alpha, 1.0, Vector2.ZERO)
	elif _portraits.has(_line_who):
		draw_texture_rect(_portraits[_line_who], portrait, false, Color(1, 1, 1, alpha))
	draw_rect(portrait, Color(1, 1, 1, 0.35 * alpha), false, 2.0 * scale_value)
	var name_font: Font = T.font("caps_wide")
	var nfs: int = int(15 * scale_value)
	var name_text: String = str(NAMES.get(_line_who, _line_who.to_upper()))
	var name_width: float = name_font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x
	var tab: Rect2 = Rect2(box.position + Vector2(portrait_size + 34.0 * scale_value, - 14.0 * scale_value), Vector2(name_width + 24.0 * scale_value, 26.0 * scale_value))
	draw_rect(tab, Color(0, 0, 0, alpha))
	draw_rect(tab.grow(-1.0), Color(tint, alpha), false, 2.0 * scale_value)
	draw_string(name_font, tab.position + Vector2(12.0 * scale_value, 19.0 * scale_value), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, Color(tint, alpha))

	var font: Font = T.font("semibold")
	var fs: int = int((30.0 if _line_shout else 27.0) * scale_value)
	var text_left: float = portrait.end.x + 26.0 * scale_value
	var text_width: float = box.end.x - text_left - 22.0 * scale_value
	var shown_text: String = PaperLanguage.t(_line_text)
	var full: String = "* " + shown_text
	var fraction: float = float(_line_shown) / float(maxi(1, _line_text.length()))
	var visible_count: int = full.length() if _line_shown >= _line_text.length() else 2 + int(round(fraction * float(shown_text.length())))
	var lines: PackedStringArray = _wrap(full, font, fs, text_width)
	var y: float = box.position.y + 24.0 * scale_value + fs * 0.85
	var index: int = 0
	var demon: bool = _line_who == "Yiero"
	var color: Color = Color(1.0, 0.36, 0.3, alpha) if demon else Color(1, 1, 1, alpha)
	for line: String in lines:
		if index >= visible_count: return
		var count: int = mini(line.length(), visible_count - index)
		if not demon:
			draw_string(font, Vector2(text_left, y), line.substr(0, count), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
		else:
			# Voix de Yiero : lettres qui tremblent (positions issues de la ligne entière, crénage conservé).
			var amp: float = 0.9 * scale_value
			for k: int in range(count):
				if line[k] == " ": continue
				var x: float = text_left + font.get_string_size(line.substr(0, k), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				var jitter: Vector2 = Vector2(sin(_clock * 29.0 + float(index + k) * 2.3), cos(_clock * 31.0 + float(index + k) * 1.7)) * amp
				draw_char(font, Vector2(x, y) + jitter, line[k], fs, color)
		index += line.length() + 1
		y += fs * 1.18


func _draw_skip(view: Vector2) -> void :
	var scale_value: float = clampf(view.y / 720.0, 0.75, 2.0)
	var font: Font = T.font("caps_wide")
	var fs: int = int(13 * scale_value)
	var text: String = PaperLanguage.t("Maintenir pour passer")
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var right: float = view.x - 34.0 * scale_value
	var base: float = view.y - 34.0 * scale_value
	var radius: float = 13.0 * scale_value
	var centre: Vector2 = Vector2(right - radius, base - fs * 0.35)
	draw_string(font, Vector2(right - radius * 2.0 - 12.0 * scale_value - width, base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.93, 0.9, 0.84, 0.85 * _skip_alpha))
	draw_arc(centre, radius, 0.0, TAU, 32, Color(1, 1, 1, 0.25 * _skip_alpha), 3.0 * scale_value)
	if _skip_progress > 0.001:
		draw_arc(centre, radius, - PI * 0.5, - PI * 0.5 + TAU * clampf(_skip_progress, 0.0, 1.0), 32, Color(T.RED, _skip_alpha), 3.5 * scale_value)


func _draw_subtitle(view: Vector2) -> void :
	var font: Font = T.font("title")
	var fs: int = int(clampf(view.y * 0.05, 22.0, 58.0))
	var text: String = PaperLanguage.t(_sub_text)
	var count: int = text.length() if _sub_shown >= _sub_text.length() else int(round(float(_sub_shown) / float(maxi(1, _sub_text.length())) * float(text.length())))
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x: float = view.x * 0.5 - width * 0.5
	var y: float = view.y * 0.9
	for k: int in range(count):
		var ch: String = text[k]
		if ch == " ": continue
		var at: Vector2 = Vector2(x + font.get_string_size(text.substr(0, k), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, y)
		var jitter: Vector2 = Vector2(sin(_clock * 23.0 + float(k) * 2.1), cos(_clock * 27.0 + float(k) * 1.3)) * 1.2
		draw_char(font, at + jitter + Vector2(3, 3), ch, fs, Color(0, 0, 0, 0.8 * _sub_alpha))
		draw_char(font, at + jitter, ch, fs, Color(0.88, 0.12, 0.14, _sub_alpha))


# Visage de Yiero en 2D (yeux ronds pâles cerclés, pupille minuscule, sourire immense) pour le
# portrait de la boîte de dialogue et la surimpression du titre.
func _draw_yiero_face(centre: Vector2, unit: float, alpha: float, grin: float, look: Vector2) -> void :
	var u: float = unit * 1000.0
	for side: int in [-1, 1]:
		var eye: Vector2 = centre + Vector2(side * 0.19, -0.2) * u
		draw_circle(eye, 0.072 * u, Color(0.05, 0.02, 0.015, alpha))
		for k: int in range(6):
			var f: float = 1.0 - float(k) / 6.0
			var shade: Color = Color(0.48, 0.42, 0.36).lerp(Color(1.0, 0.98, 0.93), float(k) / 5.0)
			draw_circle(eye, 0.052 * u * f, Color(shade, alpha))
		draw_arc(eye, 0.052 * u, 0.0, TAU, 40, Color(0.12, 0.06, 0.04, alpha), maxf(1.0, 0.007 * u))
		var pupil: Vector2 = eye + look * 0.018 * u
		draw_circle(pupil, 0.012 * u, Color(0.1, 0.05, 0.04, alpha))
		draw_circle(pupil, 0.0075 * u, Color(1, 1, 1, alpha))
	if grin <= 0.01: return
	var half: float = 0.44 * u * grin
	var steps: int = 30
	var upper: PackedVector2Array = PackedVector2Array()
	var lower: PackedVector2Array = PackedVector2Array()
	for i: int in range(steps + 1):
		var s: float = lerpf(-1.0, 1.0, float(i) / float(steps))
		upper.append(centre + Vector2(s * half, (0.1 + 0.16 * (1.0 - s * s)) * u))
		lower.append(centre + Vector2(s * half * 0.985, (0.1 + 0.34 * (1.0 - s * s)) * u))
	var mouth: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in upper: mouth.append(p)
	for i: int in range(lower.size() - 1, -1, -1): mouth.append(lower[i])
	var gums: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in upper: gums.append(p + Vector2(0, -0.028 * u))
	for i: int in range(lower.size() - 1, -1, -1): gums.append(lower[i] + Vector2(0, 0.03 * u))
	if Geometry2D.triangulate_polygon(gums).size() > 0: draw_colored_polygon(gums, Color(0.45, 0.03, 0.04, alpha))
	if Geometry2D.triangulate_polygon(mouth).size() > 0: draw_colored_polygon(mouth, Color(0.02, 0.0, 0.0, alpha))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new();rng.seed = 77
	for row: int in range(2):
		var line: PackedVector2Array = upper if row == 0 else lower
		var count: int = 22
		for i: int in range(count):
			var a: float = float(i) / float(count)
			var b: float = float(i + 1) / float(count)
			var pa: Vector2 = line[int(a * steps)]
			var pb: Vector2 = line[mini(steps, int(b * steps))]
			var mid: Vector2 = (pa + pb) * 0.5
			var span: float = 1.0 - pow((a + b) - 1.0, 2.0)
			var length: float = (0.045 + rng.randf() * 0.04) * u * (0.3 + 0.9 * span)
			var tip: Vector2 = mid + Vector2(rng.randf_range(-0.01, 0.01) * u, length if row == 0 else - length)
			var tooth: PackedVector2Array = PackedVector2Array([pa, pb, tip])
			draw_colored_polygon(tooth, Color(Color(0.93, 0.88, 0.72).lerp(Color(0.66, 0.53, 0.3), rng.randf() * 0.5), alpha))
