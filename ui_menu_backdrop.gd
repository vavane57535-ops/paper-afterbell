extends Control












const T = preload("res://ui_theme.gd")
const W = preload("res://ui_widgets.gd")
const Sound = preload("res://ui_sound.gd")
const BG_SHADER: Shader = preload("res://ui_menu_bg.gdshader")
const CUT_SHADER: Shader = preload("res://ui_menu_cutout.gdshader")
const ART_DIR: String = "res://ui/art/"


const LINEUP: Array[String] = ["Bleuette", "Usayuko", "Ashura", "Simon", "Elly", "Lysia"]

const ACCENTS: Dictionary = {
	"Ashura": Color("a47cff"), 
	"Usayuko": Color("f2a93b"), 
	"Simon": Color("7fd3ff"), 
	"Lysia": Color("5fe0c0"), 
	"Elly": Color("9ff08a"), 
	"Bleuette": Color("7e9dff"), 
	"Alice": Color("e0314f"), 
}


const SLOTS: Array = [[-0.45, 0.06, 0.84], [-0.31, 0.03, 0.92], [-0.165, 0.0, 1.0], [0.165, 0.0, 1.0], [0.31, 0.03, 0.92], [0.45, 0.06, 0.84]]
const DRAW_ORDER: Array[int] = [0, 5, 1, 4, 2, 3]
const P_PARALLAX: StringName = &"parallax"
const P_LAMP: StringName = &"lamp"
const P_ALICE: StringName = &"alice"
const P_MOTION: StringName = &"motion"
const P_DIM: StringName = &"dim"
const P_ACCENT: StringName = &"accent"
const P_SIZE: StringName = &"rect_size"
const P_REVEAL: StringName = &"reveal"
const P_GLITCH: StringName = &"glitch"
const P_EDGE: StringName = &"edge_color"

signal character_chosen(person: String)
signal character_hovered(person: String)

static var _art: Dictionary = {}

var ui: Node
var mode: String = "hidden"
var mobile: bool = false
var hero_person: String = ""
var _bg: ColorRect
var _bg_mat: ShaderMaterial
var _lineup: Control
var _cutouts: Array = []
var _alice_cut: Control
var _tags: Control
var _band: HeroBand
var _heroes: Array = []
var _hero_front: int = 0
var _scraps: Scraps
var _mouse: Vector2 = Vector2.ZERO
var _clock: float = 0.0
var _lamp: float = 1.0
var _lamp_wait: float = 4.0
var _lamp_flicker: float = 0.0
var _alice_mix: float = 0.0
var _alice_goal: float = 0.0
var _dim: float = 0.0
var _dim_goal: float = 0.0
var _accent: Color = Color("87c9c4")
var _accent_goal: Color = Color("87c9c4")
var _lineup_alpha: float = 0.0
var _lineup_alpha_goal: float = 1.0
var _lineup_shift: Vector2 = Vector2.ZERO
var _lineup_shift_goal: Vector2 = Vector2.ZERO
var _lineup_scale: float = 1.0
var _lineup_scale_goal: float = 1.0
var _glitch_wait: float = 3.0
var _glitch_time: float = 0.0
var _hovered: String = ""
var _look_sent: Vector4 = Vector4(-1, -1, -1, -1)
var _aura: TextureRect
var _hop_wait: float = 4.0



static func art(person: String, kind: String = "") -> Texture2D:
	var key: String = person + kind
	if _art.has(key): return _art[key]
	var path: String = ART_DIR + key + ".png"
	var texture: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_art[key] = texture
	return texture

static func accent_for(person: String) -> Color:
	return ACCENTS.get(person, T.TEAL)


static func bust_square(person: String) -> Texture2D:
	var key: String = person + "_square"
	if _art.has(key): return _art[key]
	var bust: Texture2D = art(person, "_bust")
	var result: Texture2D = null
	if bust:
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = bust
		var side: float = float(bust.get_width())
		atlas.region = Rect2(Vector2(0.0, 0.0), Vector2(side, minf(side, float(bust.get_height()))))
		result = atlas
	_art[key] = result
	return result


func setup(owner_ui: Node, is_mobile: bool) -> void :
	ui = owner_ui
	mobile = is_mobile
	name = "MenuBackdrop"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg = ColorRect.new()
	_bg.name = "Paper"
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_mat = ShaderMaterial.new()
	_bg_mat.shader = BG_SHADER
	_bg_mat.set_shader_parameter("doodles", art("chalk_doodles"))
	_bg_mat.set_shader_parameter("grain", T.grain())
	_bg.material = _bg_mat
	add_child(_bg)
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_band = HeroBand.new()
	add_child(_band)
	for i: int in range(2):
		var hero: Hero = Hero.new()
		add_child(hero)
		hero.modulate.a = 0.0
		hero.visible = false
		_heroes.append(hero)

	_lineup = Control.new()
	_lineup.name = "Lineup"
	_lineup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lineup)
	_lineup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_aura = TextureRect.new()
	_aura.name = "AliceAura"
	_aura.texture = art("Alice_idle", "_glow")
	_aura.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_aura.stretch_mode = TextureRect.STRETCH_SCALE
	_aura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aura.modulate = Color(0.95, 0.08, 0.22, 0.35)
	_lineup.add_child(_aura)
	_alice_cut = _make_cutout("Alice", "Alice_idle", -1)
	for index: int in DRAW_ORDER:
		_make_cutout(LINEUP[index], LINEUP[index], index)
	_tags = TagLayer.new()
	_tags.cuts = _cutouts
	_lineup.add_child(_tags)
	_tags.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scraps = Scraps.new()
	_scraps.count = 9 if mobile else 16
	add_child(_scraps)
	_scraps.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_layout)
	_layout()
	visible = false

func _make_cutout(person: String, art_key: String, slot: int) -> Control:
	var cut: Cutout = Cutout.new()
	cut.person = person
	cut.title_text = person.to_upper()
	cut.slot = slot
	cut.tex = art(art_key)
	cut.glow = art(art_key, "_glow")
	cut.accent = accent_for(person)
	var stats: Array = PaperData.STATS.get(person, [])
	cut.role_text = str(stats[3]) if stats.size() > 3 else ""
	cut.phase = float(absi(person.hash()) % 100) * 0.0628
	cut.glitchy = person == "Alice"
	_lineup.add_child(cut)
	cut.pressed.connect(_on_cut_pressed.bind(person))
	cut.hover_changed.connect(_on_cut_hover)
	_cutouts.append(cut)
	return cut

func _on_cut_pressed(person: String) -> void :
	if mode != "main": return
	Sound.play("confirm")
	character_chosen.emit(person)

func _on_cut_hover(person: String, on: bool) -> void :
	if on: _hovered = person
	elif _hovered == person:

		_hovered = ""
		for other: Cutout in _cutouts:
			if other.person != person and other.highlighted(): _hovered = other.person
	for cut: Cutout in _cutouts:
		cut.dim_goal = 1.0 if not _hovered.is_empty() and cut.person != _hovered else 0.0
		cut.set_process(true)
	character_hovered.emit(_hovered)



func _layout() -> void :
	var view: Vector2 = size
	if view.x < 10.0 or view.y < 10.0: return
	_bg_mat.set_shader_parameter(P_SIZE, view)

	var left: float = view.x * (0.4 if mobile else 0.34)

	var width: float = minf(view.x - left - view.x * 0.1, view.y * 1.35)
	var center: float = left + (view.x - left) * 0.48
	var unit: float = view.y * (0.5 if mobile else 0.52)
	var feet: float = view.y * 0.975
	for cut: Cutout in _cutouts:
		var height: float = float(PaperData.HEIGHTS.get(cut.person, 1.75)) / 1.75
		if cut.slot < 0:
			cut.fit(unit * 1.3 * 1.06)
			cut.base = Vector2(center + width * 0.005, feet - view.y * 0.1)
			cut.depth = 0.45
		else:
			var slot: Array = SLOTS[cut.slot]
			cut.fit(unit * height * float(slot[2]) * 1.06)
			cut.base = Vector2(center + width * float(slot[0]), feet - view.y * float(slot[1]))
			cut.depth = 0.75 + float(slot[2]) * 0.25
	_lineup.pivot_offset = Vector2(view.x, view.y)

	var hero_left: float = 920.0 + (ui.mobile_safe_edges().x if ui else 0.0)
	var hero_center: float = hero_left + maxf(0.0, view.x - hero_left) * 0.5
	for hero: Hero in _heroes:
		hero.area_center = hero_center
		hero.area_height = view.y
		hero.refit()
	_band.area_left = hero_left - 60.0
	_band.rebuild()



func set_mode(next: String, person: String = "", delay: float = 0.0) -> void :
	var previous: String = mode
	mode = next
	var motion: bool = not _reduced()
	match next:
		"main":
			_set_lineup(1.0, Vector2.ZERO, 1.0)
			_dim_goal = 0.0
			_alice_goal = 0.0
			_accent_goal = T.TEAL
		"panel":
			_set_lineup(0.5, Vector2(size.x * 0.1, 0.0), 0.9)
			_dim_goal = 0.1
			_alice_goal = 0.0
			_accent_goal = T.TEAL
		"settings":
			_set_lineup(0.0, Vector2(size.x * 0.02, 0.0), 0.95)
			_dim_goal = 0.25
			_alice_goal = 0.0
		"setup", "alice":
			_set_lineup(0.0, Vector2(size.x * 0.06, size.y * 0.06), 0.96)
			_dim_goal = 0.0
			_alice_goal = 1.0 if next == "alice" else 0.0
		_:
			_set_lineup(0.0, Vector2.ZERO, 1.0)
	var interactive: bool = next == "main"
	for cut: Cutout in _cutouts:
		cut.set_interactive(interactive)
		cut.dim_goal = 0.0
	if next in ["setup", "alice"]: show_hero("Alice" if next == "alice" else person, delay)
	else: show_hero("")
	if not motion or previous == "hidden":
		_snap()


# Opacité de la rangée de personnages voulue par le mode courant (les scènes
# animées du menu la masquent puis la rendent).
func lineup_goal_for_mode() -> float:
	match mode:
		"main": return 1.0
		"panel": return 0.5
		_: return 0.0

func set_spotlight(people: Array) -> void :
	for cut: Cutout in _cutouts:
		var goal: float = 0.0 if people.is_empty() or people.has(cut.person) else 1.0
		if not is_equal_approx(goal, cut.dim_goal):
			cut.dim_goal = goal
			cut.set_process(true)

func _set_lineup(alpha: float, shift: Vector2, scale_value: float) -> void :
	_lineup_alpha_goal = alpha
	_lineup_shift_goal = shift
	_lineup_scale_goal = scale_value


func _snap() -> void :
	_lineup_alpha = _lineup_alpha_goal
	_lineup_shift = _lineup_shift_goal
	_lineup_scale = _lineup_scale_goal
	_dim = _dim_goal
	_alice_mix = _alice_goal
	_accent = _accent_goal
	_apply_lineup()


func show_hero(person: String, delay: float = 0.0) -> void :
	if person == hero_person: return
	hero_person = person
	var instant: bool = _reduced() or not visible
	var old: Hero = _heroes[_hero_front]
	if old.visible:
		old.leave(instant)
	if person.is_empty():
		_band.set_color(Color(0, 0, 0, 0), instant)
		return
	_hero_front = 1 - _hero_front
	var hero: Hero = _heroes[_hero_front]
	hero.present(person, art(person), accent_for(person), instant, delay)
	move_child(hero, _band.get_index() + 2)
	_band.set_color(accent_for(person), instant)
	_band.set_title(person)
	_accent_goal = accent_for(person)

func _reduced() -> bool:
	return ui != null and bool(ui.reduced_motion)

func _process(delta: float) -> void :
	if not visible: return
	_clock += delta
	var reduced: bool = _reduced()
	var ease_k: float = 1.0 - exp( - delta * 7.0)

	var goal: Vector2 = Vector2.ZERO
	if not reduced and not mobile:
		var view: Vector2 = get_viewport_rect().size
		var mouse: Vector2 = get_viewport().get_mouse_position()
		if view.x > 0.0 and view.y > 0.0:
			goal = Vector2(clampf(mouse.x / view.x * 2.0 - 1.0, -1.0, 1.0), clampf(mouse.y / view.y * 2.0 - 1.0, -1.0, 1.0))
	_mouse = _mouse.lerp(goal, 1.0 - exp( - delta * 3.0))

	_lineup_alpha = lerpf(_lineup_alpha, _lineup_alpha_goal, ease_k)
	_lineup_shift = _lineup_shift.lerp(_lineup_shift_goal, ease_k)
	_lineup_scale = lerpf(_lineup_scale, _lineup_scale_goal, ease_k)
	_dim = lerpf(_dim, _dim_goal, ease_k)
	_alice_mix = lerpf(_alice_mix, _alice_goal, 1.0 - exp( - delta * 4.0))
	_accent = _accent.lerp(_accent_goal, 1.0 - exp( - delta * 4.0))
	_apply_lineup()

	if reduced:
		_lamp = 1.0
	else:
		_lamp_wait -= delta
		if _lamp_wait <= 0.0:
			_lamp_wait = randf_range(3.5, 9.0)
			_lamp_flicker = randf_range(0.18, 0.4)
		if _lamp_flicker > 0.0:
			_lamp_flicker -= delta
			_lamp = 0.35 + 0.65 * float(fmod(_clock * 37.0, 1.0) > 0.45)
		else:
			_lamp = lerpf(_lamp, 1.0, ease_k)
	_bg_mat.set_shader_parameter(P_PARALLAX, _mouse * -14.0)
	_bg_mat.set_shader_parameter(P_LAMP, _lamp)

	var look: Vector4 = Vector4(_alice_mix, _dim, 0.0 if reduced else 1.0, _accent.r + _accent.g * 3.0 + _accent.b * 7.0)
	if not look.is_equal_approx(_look_sent):
		_look_sent = look
		_bg_mat.set_shader_parameter(P_ALICE, _alice_mix)
		_bg_mat.set_shader_parameter(P_MOTION, 0.0 if reduced else 1.0)
		_bg_mat.set_shader_parameter(P_DIM, _dim)
		_bg_mat.set_shader_parameter(P_ACCENT, _accent)

	if not reduced and mode == "main":
		_hop_wait -= delta
		if _hop_wait <= 0.0:
			_hop_wait = randf_range(3.5, 7.0)
			var pick: Cutout = _cutouts[1 + randi() % (_cutouts.size() - 1)]
			if pick.hover_amount() < 0.01: pick.hop = 1.0
	if _lineup.visible: _animate_cast(reduced, delta)

	if not reduced and _lineup_alpha > 0.1:
		_glitch_wait -= delta
		if _glitch_wait <= 0.0:
			_glitch_wait = randf_range(3.0, 7.5)
			_glitch_time = randf_range(0.12, 0.22)
		if _glitch_time > 0.0:
			_glitch_time -= delta
			_alice_cut.set_glitch(1.0 if _glitch_time > 0.0 else 0.0, _clock)
	for hero: Hero in _heroes:
		if hero.visible: hero.tick(delta, _clock, _mouse * (0.0 if reduced else 1.0), reduced)
	_band.position = _mouse * -5.0
	_scraps.tick(delta, _mouse, reduced)


func _animate_cast(reduced: bool, delta: float) -> void :
	var sway: float = 0.0 if reduced else 1.0
	for cut: Cutout in _cutouts:
		var t: float = _clock * (0.9 + 0.1 * cut.depth) + cut.phase
		var breathe: float = sin(t * 1.7) * 0.007 * sway
		var lift: float = cut.lift_px()

		var hop_y: float = 0.0
		var squash: float = 0.0
		if cut.hop > 0.0:
			cut.hop = maxf(0.0, cut.hop - delta / 0.55)
			var k: float = 1.0 - cut.hop
			hop_y = sin(clampf((k - 0.12) / 0.76, 0.0, 1.0) * PI) * 22.0
			squash = (1.0 - smoothstep(0.0, 0.12, k)) * 0.05 + smoothstep(0.86, 0.93, k) * (1.0 - smoothstep(0.93, 1.0, k)) * 0.06
		cut.position = cut.base - Vector2(cut.size.x * 0.5, cut.size.y) + _mouse * -18.0 * cut.depth * sway + Vector2(0.0, - lift - hop_y)
		cut.scale = Vector2(1.0 - breathe * 0.4 + squash * 0.6, 1.0 + breathe - squash) * (1.0 + 0.025 * cut.hover_amount())
		cut.rotation = sin(t * 0.63) * 0.006 * sway

	var alice: Cutout = _alice_cut as Cutout
	var grow: float = 1.12 + 0.03 * sin(_clock * 1.3) * sway
	_aura.size = alice.size * grow
	_aura.position = alice.position + alice.size * Vector2(0.5, 0.55) - _aura.size * Vector2(0.5, 0.55)
	_aura.modulate.a = 0.3 + 0.12 * sin(_clock * 1.3) * sway

func _apply_lineup() -> void :
	_lineup.modulate.a = _lineup_alpha
	_lineup.position = _lineup_shift
	_lineup.scale = Vector2.ONE * _lineup_scale
	var shown: bool = _lineup_alpha > 0.01
	if _lineup.visible != shown: _lineup.visible = shown


func cutout_for(person: String) -> Control:
	for cut: Cutout in _cutouts:
		if cut.person == person: return cut
	return null






class Cutout extends Button:
	signal hover_changed(person: String, on: bool)
	var person: String = ""
	var slot: int = 0
	var tex: Texture2D
	var glow: Texture2D
	var accent: Color = T.TEAL
	var role_text: String = ""

	var title_text: String = ""
	var phase: float = 0.0
	var depth: float = 1.0
	var base: Vector2 = Vector2.ZERO
	var glitchy: bool = false

	var hop: float = 0.0
	var dim_goal: float = 0.0
	var _dim: float = 0.0
	var _hover: float = 0.0
	var _target: float = 0.0
	var _glitch: float = 0.0
	var _glitch_seed: float = 0.0
	var _track: W.Hover = W.Hover.new()

	func _init() -> void :
		flat = true
		focus_mode = Control.FOCUS_ALL
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]: add_theme_stylebox_override(state, T.empty_style())
		_track.attach(self, refresh_highlight)
		set_process(false)


	func fit(height: float) -> void :
		if tex == null: return
		var ratio: float = height / float(tex.get_height())
		size = Vector2(float(tex.get_width()) * ratio, height)
		pivot_offset = Vector2(size.x * 0.5, size.y)

	func set_interactive(on: bool) -> void :
		mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_ALL if on else Control.FOCUS_NONE
		if not on:
			if has_focus(): release_focus()
			_track.inside = false
			dim_goal = 0.0
			refresh_highlight()
			set_process(true)

	func set_glitch(amount: float, clock: float) -> void :
		if is_equal_approx(amount, _glitch) and amount <= 0.0: return
		_glitch = amount
		_glitch_seed = floor(clock * 30.0)
		queue_redraw()

	func hover_amount() -> float:
		return ease(_hover, 0.5)

	func lift_px() -> float:
		return 16.0 * ease(_hover, 0.4)


	func _has_point(point: Vector2) -> bool:
		return Rect2(Vector2(size.x * 0.26, size.y * 0.04), Vector2(size.x * 0.48, size.y * 0.9)).has_point(point)


	func highlighted() -> bool:
		return _target > 0.5



	func refresh_highlight() -> void :
		var on: bool = mouse_filter != Control.MOUSE_FILTER_IGNORE and _track.lit(self)
		var want: float = 1.0 if on else 0.0
		if want == _target:
			queue_redraw()
			return
		if on: Sound.play("hover")
		_target = want
		hover_changed.emit(person, on)
		set_process(true)

	func _notification(what: int) -> void :
		if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree() and (_track.inside or _target > 0.0):
			_track.inside = false
			refresh_highlight()

	func _process(delta: float) -> void :

		if _track.inside and not _track.still_over(self): refresh_highlight()
		_hover = move_toward(_hover, _target, delta * 5.5)
		_dim = move_toward(_dim, dim_goal, delta * 4.0)
		var shade: float = 1.0 - 0.38 * _dim
		self_modulate = Color(shade, shade, shade * 1.04, 1.0)
		queue_redraw()
		if is_equal_approx(_hover, _target) and is_equal_approx(_dim, dim_goal) and not _track.inside: set_process(false)

	func _draw() -> void :
		if tex == null: return
		var r: Rect2 = Rect2(Vector2.ZERO, size)
		var h: float = hover_amount()
		if h > 0.01 and glow:

			var pad: float = 48.0 * size.y / float(tex.get_height())
			draw_texture_rect(glow, r.grow(pad * (1.0 + 0.25 * h)), false, Color(accent, 0.85 * h))
		if _glitch > 0.0:
			var jitter: float = (T.noise(int(_glitch_seed), 3) - 0.5) * 14.0
			draw_texture_rect(tex, Rect2(r.position + Vector2(8.0 + jitter, 0), r.size), false, Color(1.0, 0.1, 0.25, 0.55))
			draw_texture_rect(tex, Rect2(r.position + Vector2(-7.0, 2.0), r.size), false, Color(0.2, 0.95, 1.0, 0.35))
		draw_texture_rect(tex, r, false)
		if _glitch > 0.0:

			for k: int in range(2):
				var band_y: float = T.noise(int(_glitch_seed) + k * 17, 1) * 0.8
				var band_h: float = 0.03 + T.noise(int(_glitch_seed) + k, 2) * 0.05
				var src: Rect2 = Rect2(Vector2(0, band_y * float(tex.get_height())), Vector2(float(tex.get_width()), band_h * float(tex.get_height())))
				var dst: Rect2 = Rect2(Vector2((T.noise(int(_glitch_seed) + k, 4) - 0.5) * 40.0, band_y * size.y), Vector2(size.x, band_h * size.y))
				draw_texture_rect_region(tex, dst, src, Color(1.0, 0.75, 0.8, 0.95))






class TagLayer extends Control:
	var cuts: Array = []
	var _tag: PackedVector2Array = PackedVector2Array()

	func _init() -> void :
		mouse_filter = Control.MOUSE_FILTER_IGNORE

		_tag.append(Vector2(0, 0))
		_tag.append(Vector2(196, -4))
		for i: int in range(7):
			_tag.append(Vector2(196 + (T.noise(5, i) - 0.5) * 8.0, -4.0 + float(i + 1) * 9.5))
		_tag.append(Vector2(198, 66))
		_tag.append(Vector2(2, 70))

	var _was_shown: bool = false

	func _process(_delta: float) -> void :
		var shown: bool = false
		for cut: Cutout in cuts:
			if cut.hover_amount() > 0.01:
				shown = true
				break
		if shown or _was_shown: queue_redraw()
		_was_shown = shown

	func _draw() -> void :
		for cut: Cutout in cuts:
			var h: float = cut.hover_amount()
			if h > 0.01: _draw_tag(cut, h)
		draw_set_transform(Vector2.ZERO)



	func _draw_tag(cut: Cutout, h: float) -> void :
		var pop: float = clampf(1.0 + 2.2 * pow(h - 1.0, 3.0) + 1.2 * pow(h - 1.0, 2.0), 0.0, 1.2)
		var local: Vector2 = Vector2(cut.size.x * 0.5 - 98.0 * pop, -80.0 * pop)
		if cut.slot < 0: local = Vector2(cut.size.x * 0.66, cut.size.y * 0.08)
		var anchor: Vector2 = cut.position + local * cut.scale
		var angle: float = deg_to_rad(-3.0 if cut.slot < 3 else 3.0)
		var accent: Color = cut.accent
		draw_set_transform(anchor + Vector2(3, 6), angle, Vector2(pop, pop))
		draw_colored_polygon(_tag, Color(0, 0, 0, 0.35 * h))
		draw_set_transform(anchor, angle, Vector2(pop, pop))
		var alice: bool = cut.person == "Alice"
		var paper: Color = Color("16111a") if alice else T.CREAM
		draw_colored_polygon(_tag, Color(paper, h))
		draw_rect(Rect2(Vector2(0, 0), Vector2(8, 70)), Color(accent, h))
		var title: Font = T.font("title")
		var caps: Font = T.font("caps")
		var ink: Color = Color(T.PAPER, h) if alice else Color(T.INK_TEXT, h)
		draw_string(title, Vector2(20, 36), cut.title_text, HORIZONTAL_ALIGNMENT_LEFT, 172, 28, ink)
		draw_string(caps, Vector2(21, 57), T.tr_text(cut.role_text), HORIZONTAL_ALIGNMENT_LEFT, 172, 12, Color(accent if alice else accent.darkened(0.45), h))
		draw_circle(Vector2(184, 12), 5.0, Color(T.RED, h))
		if cut.has_focus() and not T.pointer_mode:
			for corner: Vector2 in [Vector2(-6, -8), Vector2(204, -8), Vector2(-6, 76), Vector2(204, 76)]:
				var dx: float = 10.0 if corner.x < 0 else -10.0
				var dy: float = 8.0 if corner.y < 0 else -8.0
				draw_line(corner, corner + Vector2(dx, 0), T.GOLD, 2.0)
				draw_line(corner, corner + Vector2(0, dy), T.GOLD, 2.0)





class Hero extends Control:
	var person: String = ""
	var tex: Texture2D
	var accent: Color = T.TEAL
	var area_center: float = 1200.0
	var area_height: float = 900.0
	var _mat: ShaderMaterial
	var _reveal: float = 1.0
	var _tween: Tween
	var _slide: float = 0.0
	var _glitch_wait: float = 2.0
	var _glitch: float = 0.0

	func _init() -> void :
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_mat = ShaderMaterial.new()
		_mat.shader = CUT_SHADER
		_mat.set_shader_parameter("mask", load("res://ui/art/ink_noise.png") if ResourceLoader.exists("res://ui/art/ink_noise.png") else null)
		material = _mat

	func refit() -> void :
		if tex == null: return
		var height: float = area_height * (1.02 if person == "Alice" else 0.96) * float(PaperData.HEIGHTS.get(person, 1.75)) / 1.8
		var ratio: float = height / float(tex.get_height())
		size = Vector2(float(tex.get_width()) * ratio, height)
		pivot_offset = Vector2(size.x * 0.5, size.y)

	func present(next: String, texture: Texture2D, color: Color, instant: bool, delay: float = 0.0) -> void :
		person = next
		tex = texture
		accent = color
		refit()
		visible = true
		_mat.set_shader_parameter(P_EDGE, color if next != "Alice" else Color("ff2d4d"))
		_mat.set_shader_parameter("seed", float(absi(next.hash()) % 97))
		if _tween: _tween.kill()
		queue_redraw()
		if instant:
			_reveal = 1.0
			_slide = 0.0
			modulate.a = 1.0
			_mat.set_shader_parameter(P_REVEAL, 1.0)
			return
		_reveal = 0.0
		_slide = 70.0
		modulate.a = 1.0
		_mat.set_shader_parameter(P_REVEAL, 0.0)
		_tween = create_tween()
		if delay > 0.0: _tween.tween_interval(delay)
		_tween.tween_method(_set_reveal, 0.0, 1.0, 0.48).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_tween.parallel().tween_property(self, "_slide", 0.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	func leave(instant: bool) -> void :
		if _tween: _tween.kill()
		if instant:
			visible = false
			modulate.a = 0.0
			return
		_tween = create_tween().set_parallel()
		_tween.tween_property(self, "modulate:a", 0.0, 0.22)
		_tween.tween_property(self, "_slide", -60.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		_tween.chain().tween_callback(hide)

	func _set_reveal(value: float) -> void :
		_reveal = value
		_mat.set_shader_parameter(P_REVEAL, value)

	func tick(delta: float, clock: float, mouse: Vector2, reduced: bool) -> void :
		var breathe: float = 0.0 if reduced else sin(clock * 1.5) * 0.006
		position = Vector2(area_center - size.x * 0.5 + _slide + mouse.x * -10.0, area_height * 1.005 - size.y + mouse.y * -6.0)
		scale = Vector2(1.0 - breathe * 0.4, 1.0 + breathe)
		if person != "Alice" or reduced:
			if _glitch > 0.0:
				_glitch = 0.0
				_mat.set_shader_parameter(P_GLITCH, 0.0)
			return
		_glitch_wait -= delta
		if _glitch_wait <= 0.0:
			_glitch_wait = randf_range(2.5, 6.0)
			_glitch = randf_range(0.12, 0.24)
		if _glitch > 0.0:
			_glitch = maxf(0.0, _glitch - delta)
			_mat.set_shader_parameter(P_GLITCH, 1.0 if _glitch > 0.0 else 0.0)

	func _draw() -> void :
		if tex: draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false)



class HeroBand extends Control:
	var area_left: float = 900.0
	var color: Color = Color(0, 0, 0, 0)
	var title: String = ""
	var _title_x: float = 0.0
	var _a: Vector2 = Vector2.ZERO
	var _b: Vector2 = Vector2.ZERO
	var _goal: Color = Color(0, 0, 0, 0)
	var _shape: PackedVector2Array = PackedVector2Array()
	var _stripe: PackedVector2Array = PackedVector2Array()

	func _init() -> void :
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(false)


	func set_title(value: String) -> void :
		title = value.to_upper()
		_title_x = 0.0
		queue_redraw()

	func set_color(next: Color, instant: bool) -> void :
		_goal = next
		if instant:
			color = next
			queue_redraw()
			return
		set_process(true)

	func _process(delta: float) -> void :
		color = color.lerp(_goal, 1.0 - exp( - delta * 6.0))
		var gap: Vector4 = Vector4(color.r - _goal.r, color.g - _goal.g, color.b - _goal.b, color.a - _goal.a)
		if gap.length() < 0.004:
			color = _goal
			set_process(false)
		queue_redraw()

	func rebuild() -> void :
		var parent: Control = get_parent() as Control
		if parent == null: return
		size = parent.size
		var w: float = size.x
		var h: float = size.y
		_shape.clear()
		_stripe.clear()

		var a: Vector2 = Vector2(area_left + 40.0, h + 20.0)
		var b: Vector2 = Vector2(w + 40.0, h * 0.18)
		_a = a
		_b = b
		var normal: Vector2 = (b - a).normalized().orthogonal()
		var half: float = h * 0.17
		var steps: int = 28
		for i: int in range(steps + 1):
			var t: float = float(i) / float(steps)
			_shape.append(a.lerp(b, t) + normal * (half + (T.noise(41, i) - 0.5) * 16.0))
		for i: int in range(steps, -1, -1):
			var t: float = float(i) / float(steps)
			_shape.append(a.lerp(b, t) - normal * (half + (T.noise(77, i) - 0.5) * 16.0))
		for i: int in range(steps + 1):
			var t: float = float(i) / float(steps)
			_stripe.append(a.lerp(b, t) - normal * (half * 0.55))
		queue_redraw()

	func _draw() -> void :
		if color.a <= 0.01 or _shape.size() < 3: return
		draw_colored_polygon(_shape, Color(color.darkened(0.35), color.a * 0.55))
		draw_polyline(_stripe, Color(color, color.a * 0.5), 3.0, true)
		if title.is_empty(): return

		var font: Font = T.font("display")
		var fs: int = int(size.y * 0.2)
		var direction: Vector2 = (_b - _a).normalized()
		var start: Vector2 = _a.lerp(_b, 0.2) + direction.orthogonal() * (fs * 0.3)
		draw_set_transform(start, direction.angle(), Vector2.ONE)
		draw_string_outline(font, Vector2(_title_x, 0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(color.lightened(0.25), color.a * 0.4))
		draw_set_transform(Vector2.ZERO)





class Scraps extends Control:
	var count: int = 16
	var _pos: PackedVector2Array = PackedVector2Array()
	var _vel: PackedVector2Array = PackedVector2Array()
	var _info: PackedFloat32Array = PackedFloat32Array()
	var _seeded: bool = false
	var _shape: PackedVector2Array = PackedVector2Array()

	func _init() -> void :
		mouse_filter = Control.MOUSE_FILTER_IGNORE

		var points: Array = [Vector2(-13, -8), Vector2(-4, -10), Vector2(5, -7), Vector2(13, -9), Vector2(11, -1), Vector2(14, 7), Vector2(3, 9), Vector2(-6, 7), Vector2(-14, 9), Vector2(-12, 0)]
		for point: Vector2 in points: _shape.append(point)

	func _seed() -> void :
		_pos.resize(count)
		_vel.resize(count)
		_info.resize(count * 4)
		for i: int in range(count):
			_pos[i] = Vector2(randf() * maxf(size.x, 1.0), randf() * maxf(size.y, 1.0))
			_vel[i] = Vector2(randf_range(-8.0, 8.0), randf_range(6.0, 18.0))
			_info[i * 4] = randf() * TAU
			_info[i * 4 + 1] = randf_range(-0.8, 0.8)
			_info[i * 4 + 2] = randf_range(0.55, 1.9)
			_info[i * 4 + 3] = randf()
		_seeded = true

	func tick(delta: float, mouse: Vector2, reduced: bool) -> void :
		if size.x < 10.0: return
		if not _seeded or _pos.size() != count: _seed()
		var speed: float = 0.3 if reduced else 1.0
		for i: int in range(count):
			var p: Vector2 = _pos[i] + _vel[i] * delta * speed
			p.x += sin(_info[i * 4] + p.y * 0.01) * 12.0 * delta * speed
			if p.y > size.y + 30.0:
				p.y = -30.0
				p.x = randf() * size.x
			if p.x < -40.0: p.x = size.x + 30.0
			elif p.x > size.x + 40.0: p.x = -30.0
			_pos[i] = p
			_info[i * 4] += _info[i * 4 + 1] * delta * speed
		position = mouse * -26.0 * (0.0 if reduced else 1.0)
		queue_redraw()

	func _draw() -> void :
		for i: int in range(_pos.size()):
			var s: float = _info[i * 4 + 2]
			var kind: float = _info[i * 4 + 3]

			var flip: Vector2 = Vector2(s, s * (0.35 + 0.65 * absf(sin(_info[i * 4] * 1.7))))
			var near: float = clampf((s - 0.55) / 1.35, 0.0, 1.0)
			draw_set_transform(_pos[i] + Vector2(3, 7) * s, _info[i * 4], flip)
			draw_colored_polygon(_shape, Color(0, 0, 0, 0.18 * near))
			draw_set_transform(_pos[i], _info[i * 4], flip)
			var paper: Color = Color(0.93, 0.9, 0.83, 0.28 + 0.45 * near) if kind > 0.18 else Color(0.84, 0.27, 0.36, 0.3 + 0.4 * near)
			draw_colored_polygon(_shape, paper)
			if kind > 0.55: draw_line(Vector2(-11, -2), Vector2(11, -2), Color(0.3, 0.45, 0.7, 0.45 * near + 0.1), 1.0)
		draw_set_transform(Vector2.ZERO)
